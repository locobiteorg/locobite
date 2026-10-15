import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../shared/models/order.dart' as model;
import 'login_screen.dart';
import 'order_status_screen.dart';

/// The customer's order history, kept in sync with what the merchant does:
/// it re-fetches every few seconds while open, so an accept / preparing /
/// out-for-delivery from the merchant app appears here without a reload.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _refreshEvery = Duration(seconds: 6);
  List<model.Order> _orders = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (ApiService.currentCustomer != null) {
      _load();
      _timer = Timer.periodic(_refreshEvery, (_) => _load(silent: true));
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final customer = ApiService.currentCustomer;
    if (customer == null) return;
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final list = await ApiService.getOrders(customer.id, limit: 50);
      if (!mounted) return;
      setState(() { _orders = list; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      // A failed background refresh keeps what's on screen.
      if (!silent || _orders.isEmpty) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  static (String, Color, Color) _status(String s) => switch (s) {
        'requested' => ('Waiting for vendor', const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
        'accepted' => ('Accepted', AppColors.primary, AppColors.primaryLight),
        'preparing' => ('Preparing', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
        'ready' => ('Ready', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
        'out_for_delivery' => ('On the way', AppColors.green, const Color(0xFFF0FDF4)),
        'delivered' => ('Delivered', AppColors.muted, AppColors.surface),
        'cancelled' => ('Cancelled', AppColors.muted, AppColors.surface),
        'rejected' => ('Rejected', AppColors.red, const Color(0xFFFEF2F2)),
        'disputed' => ('Disputed', AppColors.amber, const Color(0xFFFFFBEB)),
        'refunded' => ('Refunded', AppColors.muted, AppColors.surface),
        _ => (s, AppColors.muted, AppColors.surface),
      };

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static String _when(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    return '${d.day} ${_months[d.month - 1]}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Orders', style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (ApiService.currentCustomer == null) {
      return _message(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to see your orders',
        sub: 'Your orders are saved to your account.',
        action: ElevatedButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          child: const Text('Sign in'),
        ),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) {
      return _message(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load your orders",
        sub: 'Check your connection and try again.',
        action: OutlinedButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    if (_orders.isEmpty) {
      return _message(
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
        sub: 'Pick a vendor at your next station and order.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(_orders[i]),
      ),
    );
  }

  Widget _card(model.Order o) {
    final (label, color, bg) = _status(o.status);
    final vendor = LocoBiteApp.repo.vendorNameFor(o.vendorId) ?? 'Vendor';
    final summary = o.items.isEmpty
        ? ''
        : o.items.length == 1
            ? '${o.items[0].quantity}× ${o.items[0].name}'
            : '${o.items[0].quantity}× ${o.items[0].name} +${o.items.length - 1} more';
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderStatusScreen(order: o)));
        if (mounted) _load(silent: true);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryLight),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(vendor, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.foreground))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
              child: Text(label, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(summary, style: GoogleFonts.nunito(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 10),
          Row(children: [
            Text('₹${(o.amountPaise / 100).toStringAsFixed(0)}',
              style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
            const Spacer(),
            Text('LB-${o.id.length >= 6 ? o.id.substring(0, 6).toUpperCase() : o.id} · ${_when(o.createdAt)}',
              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
          ]),
        ]),
      ),
    );
  }

  Widget _message({required IconData icon, required String title, required String sub, Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.foreground)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 13, color: AppColors.muted)),
          if (action != null) ...[const SizedBox(height: 16), action],
        ]),
      ),
    );
  }
}
