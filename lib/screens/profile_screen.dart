import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';
import '../shared/models/models.dart';
import '../shared/models/order.dart' as model;
import 'login_screen.dart';
import 'order_status_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifOrders = true;
  bool _notifOffers = false;
  bool _loading = false;
  List<model.Order> _orderHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  void _fetchHistory() async {
    final customer = ApiService.currentCustomer;
    if (customer == null) return;
    try {
      final list = await ApiService.getOrders(customer.id, limit: 10);
      setState(() {
        _orderHistory = list;
      });
    } catch (_) {}
  }

  void _clearDues() async {
    final customer = ApiService.currentCustomer;
    if (customer == null) return;
    setState(() => _loading = true);
    try {
      await ApiService.clearDues(customer.id);
      await ApiService.refreshCustomer(customer.id);
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dues cleared successfully!')),
      );
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear dues: $e')),
      );
    }
  }

  void _deleteAccount() async {
    final customer = ApiService.currentCustomer;
    if (customer == null) return;
    
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Delete Account?', style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
        content: const Text('Are you sure you want to delete your account? This action is compliant with RBI audit trail retention regulations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() => _loading = true);
              try {
                await ApiService.deleteAccount(customer.id);
                setState(() => _loading = false);
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              } catch (e) {
                setState(() => _loading = false);
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Deletion Blocked'),
                      content: Text(e.toString()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        )
                      ],
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = ApiService.currentCustomer;
    if (customer == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text('Go to Login'),
          ),
        ),
      );
    }

    final double duesRupees = customer.duesBalancePaise / 100;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(children: [
              _buildHeader(customer, duesRupees),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  if (customer.duesBalancePaise > 0) ...[
                    _buildDuesCard(duesRupees),
                    const SizedBox(height: 12),
                  ],
                  _buildOrderHistory(),
                  const SizedBox(height: 12),
                  _buildSavedRoutes(),
                  const SizedBox(height: 12),
                  _buildNotifications(),
                  const SizedBox(height: 12),
                  _buildSettingsCard(),
                  const SizedBox(height: 12),
                  _buildSignOut(),
                  const SizedBox(height: 12),
                  _buildDeleteAccount(),
                  const SizedBox(height: 24),
                ]),
              )),
            ]),
    );
  }

  Widget _buildHeader(Customer customer, double duesRupees) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MY ACCOUNT', style: GoogleFonts.nunito(
              fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w800,
              letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.person_outline_rounded,
                  color: Colors.white, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(customer.name, style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                Text('+91 ${customer.phone}',
                  style: GoogleFonts.nunito(fontSize: 12, color: Colors.white60)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.amber.withOpacity(0.4)),
                ),
                child: Column(children: [
                  Text('DUES', style: GoogleFonts.nunito(
                    fontSize: 8, color: Colors.white54, fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
                  Text('₹${duesRupees.toStringAsFixed(0)}', style: GoogleFonts.nunito(
                    fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white70)),
                ]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildDuesCard(double duesRupees) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.amber.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Outstanding Balance · ₹${duesRupees.toStringAsFixed(2)}', style: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w800,
            color: const Color(0xFF92400E))),
          Text('Pay outstanding balance to resume booking',
            style: GoogleFonts.nunito(fontSize: 11, color: const Color(0xFFB45309))),
        ])),
        ElevatedButton(
          onPressed: _clearDues,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.amber,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
          child: Text('Clear', style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }

  Widget _buildOrderHistory() {
    return _SectionCard(
      title: 'RECENT ORDERS HISTORY',
      children: _orderHistory.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('No orders placed yet',
                    style: GoogleFonts.nunito(color: AppColors.muted, fontSize: 13)),
              )
            ]
          : _orderHistory.map((o) {
              final double amt = o.amountPaise / 100;
              Color statusColor = AppColors.muted;
              if (o.status == 'delivered') statusColor = AppColors.green;
              if (o.status == 'cancelled' || o.status == 'rejected') statusColor = AppColors.red;
              
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderStatusScreen(order: o)),
                  );
                },
                child: _ListRow(
                  title: 'Order #${o.id.substring(0, 8).toUpperCase()}',
                  subtitle: '${o.trainNumber} · Coach ${o.seatCoach} · ${o.status.toUpperCase()}',
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('₹${amt.toStringAsFixed(2)}', style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.foreground)),
                      Text(o.status.toUpperCase(), style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                    ],
                  ),
                ),
              );
            }).toList(),
    );
  }

  Widget _buildSavedRoutes() {
    return _SectionCard(
      title: 'FREQUENT ROUTES',
      children: [
        _ListRow(
          icon: Icons.train_rounded,
          title: 'Nagpur Jn (NGP) → Raipur Jn (R)',
          subtitle: '12259 Duronto Exp',
        ),
      ],
    );
  }

  Widget _buildNotifications() {
    return _SectionCard(
      title: 'NOTIFICATIONS',
      children: [
        _ToggleRow(
          label: 'Order updates',
          value: _notifOrders,
          onChanged: (v) => setState(() => _notifOrders = v),
        ),
        _ToggleRow(
          label: 'Offers & promotions',
          value: _notifOffers,
          onChanged: (v) => setState(() => _notifOffers = v),
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return _SectionCard(
      children: [
        _ListRow(icon: Icons.settings_outlined, title: 'Settings',
          trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.primaryLight, size: 20)),
        _ListRow(icon: Icons.help_outline_rounded, title: 'Help & FAQ',
          trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.primaryLight, size: 20)),
      ],
    );
  }

  Widget _buildSignOut() {
    return OutlinedButton.icon(
      onPressed: () {
        ApiService.currentCustomer = null;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      },
      icon: const Icon(Icons.logout_rounded, size: 16),
      label: Text('Sign Out', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.muted,
        side: const BorderSide(color: AppColors.primaryLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(double.infinity, 52),
      ),
    );
  }

  Widget _buildDeleteAccount() {
    return OutlinedButton.icon(
      onPressed: _deleteAccount,
      icon: const Icon(Icons.delete_forever_rounded, size: 16),
      label: Text('Delete Account Compliantly', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.red,
        side: const BorderSide(color: AppColors.red, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(double.infinity, 52),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const _SectionCard({this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.primaryLight),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) ...[
        Text(title!, style: GoogleFonts.nunito(
          fontSize: 10, fontWeight: FontWeight.w900,
          color: AppColors.muted, letterSpacing: 1.5)),
        const SizedBox(height: 12),
      ],
      ...children,
    ]),
  );
}

class _ListRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const _ListRow({this.icon, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 12),
      ],
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.foreground)),
        if (subtitle != null)
          Text(subtitle!, style: GoogleFonts.nunito(
            fontSize: 11, color: AppColors.muted)),
      ])),
      if (trailing != null) trailing!,
    ]),
  );
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: GoogleFonts.nunito(
        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.foreground))),
      Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    ]),
  );
}
