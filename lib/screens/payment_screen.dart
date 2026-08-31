import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../shared/models/order.dart' as model;
import '../services/api_service.dart';
import 'rating_screen.dart';

class PaymentScreen extends StatefulWidget {
  final model.Order order;
  const PaymentScreen({super.key, required this.order});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  bool _paid = false;
  bool _loading = true;
  String _errorMessage = '';
  String _qrPayload = '';
  String _providerRef = '';
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _checkScale = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
    _generateQR();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  void _generateQR() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });
    try {
      final res = await ApiService.collectPayment(widget.order.id);
      setState(() {
        _qrPayload = res['qr_payload'] ?? 'upi://pay?pa=locobite@pay&pn=LocoBite';
        _providerRef = res['provider_ref'] ?? 'ref_default';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  void _confirmWithCash() async {
    setState(() => _loading = true);
    try {
      await ApiService.recordCashReceived(widget.order.id);
      setState(() {
        _paid = true;
        _loading = false;
      });
      _checkCtrl.forward();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to confirm cash: $e')),
      );
    }
  }

  void _simulateWebhookPayment() async {
    setState(() => _loading = true);
    try {
      final eventId = 'evt_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
      await ApiService.simulatePaymentWebhook(
        eventId: eventId,
        providerRef: _providerRef,
        status: 'confirmed',
      );
      setState(() {
        _paid = true;
        _loading = false;
      });
      _checkCtrl.forward();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Webhook simulation failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _paid ? null : AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          style: IconButton.styleFrom(backgroundColor: AppColors.surface),
        ),
        title: Text('Payment Collection', style: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.foreground)),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _paid 
              ? _buildSuccess() 
              : (_loading 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary)) 
                  : _buildQrView()),
        ),
      ),
    );
  }

  Widget _buildQrView() {
    final double amountRupees = widget.order.amountPaise / 100;
    
    return SingleChildScrollView(
      key: const ValueKey('qr'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Amount Due', style: GoogleFonts.nunito(
            fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text('₹${amountRupees.toStringAsFixed(2)}', style: GoogleFonts.nunito(
            fontSize: 44, fontWeight: FontWeight.w900, color: AppColors.foreground)),
          Text('Order ID: #${widget.order.id.substring(0, 8).toUpperCase()}',
            style: GoogleFonts.nunito(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 20),

          if (_errorMessage.isNotEmpty) ...[
            Text(_errorMessage, style: GoogleFonts.nunito(color: AppColors.red, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _generateQR,
              child: const Text('Retry QR Generation'),
            ),
          ] else ...[
            Container(
              width: 220, height: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primaryLight, width: 2),
                boxShadow: [BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 24, spreadRadius: 4)],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(12),
                child: CustomPaint(painter: _QrPainter()),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              _qrPayload,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 10, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
          ],

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(children: [
              const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(AppStrings.qrScanCopy,
                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.primary,
                  height: 1.5, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 12),
          Text('QR generated by delivery partner from backend',
            style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _confirmWithCash,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    side: const BorderSide(color: AppColors.primaryLight, width: 2),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Confirm Cash Received\n(Unverified Vendor)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _simulateWebhookPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Simulate Webhook UPI\n(Verified Sale)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final double amountRupees = widget.order.amountPaise / 100;
    
    return Center(
      key: const ValueKey('success'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: _checkScale,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4), shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: AppColors.green.withOpacity(0.2), blurRadius: 30)],
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                size: 56, color: AppColors.green),
            ),
          ),
          const SizedBox(height: 24),
          Text('Payment Received!', style: GoogleFonts.nunito(
            fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.foreground)),
          const SizedBox(height: 4),
          Text('₹${amountRupees.toStringAsFixed(2)} · Order #${widget.order.id.substring(0, 8).toUpperCase()}',
            style: GoogleFonts.nunito(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 8),
          Text('Enjoy your meal 🍽', style: GoogleFonts.nunito(
            fontSize: 16, color: AppColors.muted)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const RatingScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8, shadowColor: AppColors.primary.withOpacity(0.4),
            ),
            child: Text('Rate Your Experience',
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        ]),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary;
    const n = 10;
    final cell = size.width / n;
    const pattern = [
      [1,1,1,1,0,1,0,1,1,1],
      [1,0,0,1,1,0,1,0,0,1],
      [1,0,1,1,0,1,0,1,0,1],
      [1,1,1,1,0,0,1,1,1,1],
      [0,1,0,0,1,0,1,0,1,0],
      [1,0,1,0,0,1,1,0,0,1],
      [1,1,1,1,0,1,0,1,1,0],
      [1,0,0,1,1,0,1,0,0,1],
      [1,0,1,0,0,1,0,1,0,1],
      [1,1,0,1,1,0,1,0,1,1],
    ];
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (pattern[r][c] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cell + 1, r * cell + 1, cell - 2, cell - 2),
              const Radius.circular(2)),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
