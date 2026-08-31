import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../shared/models/models.dart';
import '../main.dart';
import 'cart_screen.dart';

class VendorScreen extends StatefulWidget {
  final Vendor vendor;
  final List<CartItem> cart;
  final ValueChanged<List<CartItem>> onCartChanged;

  const VendorScreen({
    super.key,
    required this.vendor,
    required this.cart,
    required this.onCartChanged,
  });

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  int get _cartCount => widget.cart.fold(0, (s, i) => s + i.qty);
  int get _cartTotal => widget.cart.fold(0, (s, i) => s + i.price * i.qty);

  int _getQty(int menuItemId) =>
    widget.cart.firstWhere((c) => c.menuItemId == menuItemId,
      orElse: () => CartItem(menuItemId: -1, vendorId: -1, name: '', price: 0, qty: 0)).qty;

  void _adjust(MenuItem item, int delta) {
    setState(() {
      final idx = widget.cart.indexWhere((c) => c.menuItemId == item.id);
      if (idx == -1) {
        if (delta > 0) widget.cart.add(CartItem(
          menuItemId: item.id, vendorId: widget.vendor.id,
          name: item.name, price: item.price, qty: 1));
      } else {
        final newQty = widget.cart[idx].qty + delta;
        if (newQty <= 0) widget.cart.removeAt(idx);
        else widget.cart[idx].qty = newQty;
      }
    });
    widget.onCartChanged(widget.cart);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.primary,
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.foreground,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(widget.vendor.imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: AppColors.primaryLight)),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12, left: 16, right: 16,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.vendor.name,
                            style: GoogleFonts.nunito(
                              fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                          Text(widget.vendor.cuisineTags.join(' · '),
                            style: GoogleFonts.nunito(
                              fontSize: 12, color: Colors.white70)),
                        ]),
                      ),
                      Positioned(
                        top: 16, right: 60,
                        child: SafeArea(child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: widget.vendor.isOpen ? AppColors.green : Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(widget.vendor.isOpen ? 'OPEN' : 'CLOSED',
                            style: GoogleFonts.nunito(
                              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                        )),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    _infoBadge('⭐ ${widget.vendor.rating} (${widget.vendor.reviewCount})',
                      const Color(0xFFF0FDF4), AppColors.green),
                    if (widget.vendor.trusted)
                      _infoBadge('✓ Trusted Vendor', AppColors.primaryLight, AppColors.primary),
                    if (widget.vendor.fssai)
                      _infoBadge('🛡 FSSAI', AppColors.surface, AppColors.muted),
                    if (widget.vendor.zeroCommission)
                      _infoBadge('🏆 Zero Commission',
                        AppColors.amber.withOpacity(0.1), AppColors.amber),
                  ]),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text('MENU',
                            style: GoogleFonts.nunito(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: AppColors.muted, letterSpacing: 1.5)),
                        );
                      }
                      final item = widget.vendor.menu[i - 1];
                      final qty = _getQty(item.id);
                      return _MenuItemRow(
                        item: item, qty: qty,
                        isOpen: widget.vendor.isOpen,
                        onAdjust: (delta) => _adjust(item, delta),
                      );
                    },
                    childCount: widget.vendor.menu.length + 1,
                  ),
                ),
              ),
            ],
          ),

          if (_cartCount > 0)
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CartScreen(
                    cart: widget.cart,
                    train: LocoBiteApp.repo.getCurrentTrain(),
                    onCartChanged: widget.onCartChanged,
                  ),
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$_cartCount items',
                          style: GoogleFonts.nunito(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                      const Spacer(),
                      Text('View Cart',
                        style: GoogleFonts.nunito(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Text('₹$_cartTotal',
                        style: GoogleFonts.nunito(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
        style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final MenuItem item;
  final int qty;
  final bool isOpen;
  final ValueChanged<int> onAdjust;

  const _MenuItemRow({
    required this.item, required this.qty,
    required this.isOpen, required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isOpen ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.primaryLight))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                border: Border.all(
                  color: item.isVeg ? AppColors.green : AppColors.red, width: 2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: item.isVeg ? AppColors.green : AppColors.red,
                    shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name,
                  style: GoogleFonts.nunito(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: AppColors.foreground)),
                const SizedBox(height: 2),
                Text(item.desc,
                  style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text('₹${item.price}',
                  style: GoogleFonts.nunito(
                    fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary)),
              ]),
            ),
            const SizedBox(width: 12),
            if (qty == 0)
              GestureDetector(
                onTap: isOpen ? () => onAdjust(1) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Add',
                    style: GoogleFonts.nunito(
                      fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _QtyBtn(icon: Icons.remove, onTap: () => onAdjust(-1)),
                    SizedBox(width: 28,
                      child: Center(child: Text('$qty',
                        style: GoogleFonts.nunito(
                          fontSize: 13, fontWeight: FontWeight.w900,
                          color: AppColors.primary)))),
                    _QtyBtn(icon: Icons.add, onTap: () => onAdjust(1)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 30,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}
