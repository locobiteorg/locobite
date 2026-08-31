import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../shared/models/models.dart';
import '../shared/models/order.dart' as model;
import '../services/api_service.dart';
import 'order_status_screen.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> cart;
  final TrainInfo train;
  final ValueChanged<List<CartItem>> onCartChanged;

  const CartScreen({
    super.key, required this.cart,
    required this.train, required this.onCartChanged,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const int _convFee = 15;
  bool _placing = false;

  int get _subtotal => widget.cart.fold(0, (s, i) => s + i.price * i.qty);
  int get _total => _subtotal + _convFee;

  void _placeOrder() async {
    final customer = ApiService.currentCustomer;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first before placing an order.')),
      );
      return;
    }
    
    if (customer.isBlockedForDues) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dues Blocked! Outstanding balance: ₹${customer.duesBalancePaise / 100}'),
          action: SnackBarAction(
            label: 'Clear',
            onPressed: () async {
              try {
                await ApiService.clearDues(customer.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dues cleared successfully!')),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
          ),
        ),
      );
      return;
    }

    setState(() => _placing = true);
    try {
      final items = widget.cart.map((item) => {
        'menu_item_id': ApiService.mapMenuItemId(item.menuItemId),
        'quantity': item.qty,
      }).toList();

      final arrivalTime = widget.train.arrival;
      final now = DateTime.now();
      final scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(arrivalTime.split(':')[0]),
        int.parse(arrivalTime.split(':')[1]),
      ).toUtc().toIso8601String();

      final order = await ApiService.placeOrder(
        customerId: customer.id,
        vendorId: ApiService.mapVendorId(widget.cart.first.vendorId),
        trainNumber: widget.train.number,
        direction: 'up',
        seatCoach: '${widget.train.coach} ${widget.train.seat}',
        scheduledArrival: scheduled,
        items: items,
      );

      widget.cart.clear();
      widget.onCartChanged(widget.cart);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OrderStatusScreen(order: order)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _adjust(CartItem item, int delta) {
    setState(() {
      final newQty = item.qty + delta;
      if (newQty <= 0) widget.cart.remove(item);
      else item.qty = newQty;
    });
    widget.onCartChanged(widget.cart);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          style: IconButton.styleFrom(backgroundColor: AppColors.surface),
        ),
        title: Text('Your Cart',
          style: GoogleFonts.nunito(
            fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.foreground)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('${widget.cart.fold(0, (s, i) => s + i.qty)} items',
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.muted,
                fontWeight: FontWeight.w700))),
          ),
        ],
      ),
      body: widget.cart.isEmpty
        ? _buildEmptyCart()
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDeliveryCard(),
                      const SizedBox(height: 12),
                      _buildItemsCard(),
                      const SizedBox(height: 12),
                      _buildBillCard(),
                      const SizedBox(height: 12),
                      _buildReassuranceCard(),
                    ],
                  ),
                ),
              ),
              _buildPlaceOrderBar(),
            ],
          ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🛍', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        Text('Your cart is empty',
          style: GoogleFonts.nunito(
            fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.foreground)),
        const SizedBox(height: 4),
        Text('Browse vendors at upcoming stations.',
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.muted)),
      ]),
    );
  }

  Widget _buildDeliveryCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.train_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('DELIVERY DETAILS',
            style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w900,
              color: AppColors.foreground, letterSpacing: 1)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _DeliveryChip('Train', widget.train.number),
          const SizedBox(width: 8),
          _DeliveryChip('Coach', widget.train.coach),
          const SizedBox(width: 8),
          _DeliveryChip('Seat', widget.train.seat),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DELIVERY AT', style: GoogleFonts.nunito(
                fontSize: 8, color: AppColors.muted, fontWeight: FontWeight.w800,
                letterSpacing: 1)),
              Text('Nagpur Jn · ${widget.train.arrival}',
                style: GoogleFonts.nunito(
                  fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.foreground)),
            ])),
            const Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
          ]),
        ),
      ]),
    );
  }

  Widget _buildItemsCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ITEMS', style: GoogleFonts.nunito(
          fontSize: 10, fontWeight: FontWeight.w900,
          color: AppColors.muted, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        ...widget.cart.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.foreground)),
              Text('₹${item.price} each', style: GoogleFonts.nunito(
                fontSize: 11, color: AppColors.muted)),
            ])),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _QtyIconBtn(Icons.remove, () => _adjust(item, -1)),
                SizedBox(width: 28, child: Center(child: Text('${item.qty}',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w900,
                    color: AppColors.primary)))),
                _QtyIconBtn(Icons.add, () => _adjust(item, 1)),
              ]),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 48, child: Text('₹${item.price * item.qty}',
              textAlign: TextAlign.right,
              style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.foreground))),
          ]),
        )),
      ]),
    );
  }

  Widget _buildBillCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BILL SUMMARY', style: GoogleFonts.nunito(
          fontSize: 10, fontWeight: FontWeight.w900,
          color: AppColors.muted, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        _BillRow('Subtotal', '₹$_subtotal'),
        const SizedBox(height: 8),
        _BillRow('Convenience Fee (flat, itemised)', '₹$_convFee',
          valueColor: AppColors.muted),
        const Divider(color: AppColors.primaryLight, height: 24),
        _BillRow('Total', '₹$_total', bold: true, valueColor: AppColors.primary),
      ]),
    );
  }

  Widget _buildReassuranceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(AppStrings.noPrepayCopy,
            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.primary,
              height: 1.5, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildPlaceOrderBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.primaryLight))),
      child: _placing
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ElevatedButton(
              onPressed: _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 8,
                shadowColor: AppColors.primary.withOpacity(0.4),
              ),
              child: Text('Place Order · ₹$_total',
                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
    );
  }
}

class _QtyIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyIconBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26, height: 28,
      decoration: BoxDecoration(
        color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 13, color: Colors.white),
    ),
  );
}

class _DeliveryChip extends StatelessWidget {
  final String label;
  final String value;
  const _DeliveryChip(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: GoogleFonts.nunito(
          fontSize: 8, color: AppColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1)),
        Text(value, style: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.foreground)),
      ]),
    ),
  );
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _BillRow(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: GoogleFonts.nunito(
        fontSize: bold ? 14 : 13, color: bold ? AppColors.foreground : AppColors.muted,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
      Text(value, style: GoogleFonts.nunito(
        fontSize: bold ? 14 : 13, color: valueColor ?? AppColors.foreground,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
    ],
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.primaryLight),
    ),
    child: child,
  );
}
