import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../shared/models/order.dart' as model;
import '../services/api_service.dart';
import 'payment_screen.dart';

class OrderStatusScreen extends StatefulWidget {
  final model.Order? order;
  const OrderStatusScreen({super.key, this.order});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  model.Order? _order;
  Timer? _statusTimer;
  bool _loading = false;
  String _disputeType = 'not_collected';

  @override
  void initState() {
    super.initState();
    _order = widget.order ?? ApiService.currentOrder;
    _startPolling();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_order != null) {
        try {
          final history = await ApiService.getOrders(ApiService.currentCustomer!.id, limit: 5);
          final updated = history.firstWhere((o) => o.id == _order!.id, orElse: () => _order!);
          if (mounted && updated.status != _order!.status || updated.paymentVerified != _order!.paymentVerified || updated.delayUpdatedAt != _order!.delayUpdatedAt) {
            setState(() {
              _order = updated;
            });
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _refreshOrder() async {
    if (_order == null) return;
    setState(() => _loading = true);
    try {
      final history = await ApiService.getOrders(ApiService.currentCustomer!.id, limit: 10);
      final updated = history.firstWhere((o) => o.id == _order!.id);
      setState(() {
        _order = updated;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh: $e')),
      );
    }
  }

  void _cancel() async {
    if (_order == null) return;
    setState(() => _loading = true);
    try {
      final updated = await ApiService.cancelOrder(_order!.id);
      setState(() {
        _order = updated;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancel failed: $e')),
      );
    }
  }

  void _simulateVendorAccept() async {
    if (_order == null) return;
    setState(() => _loading = true);
    try {
      final updated = await ApiService.acceptOrder(_order!.id);
      setState(() {
        _order = updated;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept simulation failed: $e')),
      );
    }
  }

  void _simulateVendorReject(String reason) async {
    if (_order == null) return;
    setState(() => _loading = true);
    try {
      final updated = await ApiService.rejectOrder(_order!.id, reason);
      setState(() {
        _order = updated;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject simulation failed: $e')),
      );
    }
  }

  void _simulateVendorAdvance(String step) async {
    if (_order == null) return;
    setState(() => _loading = true);
    try {
      final updated = await ApiService.advanceOrder(_order!.id, step);
      setState(() {
        _order = updated;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Advance simulation failed: $e')),
      );
    }
  }

  void _applyDelay(String chip) async {
    if (_order == null) return;
    setState(() => _loading = true);
    try {
      await ApiService.delayOrder(_order!.id, chip);
      await _refreshOrder();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delay failed: $e')),
      );
    }
  }

  void _fileDispute() async {
    if (_order == null) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService.fileDispute(_order!.id, _disputeType);
      final refund = res['refund_tier_paise'] ?? 0;
      final waived = res['customer_waiver'] ?? false;
      
      await _refreshOrder();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Dispute Filed', style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
            content: Text(
              waived 
                ? 'Free Waiver applied! Refund of ₹${refund / 100} has been processed.' 
                : 'Free Waiver Limit Exceeded! Refund of ₹${refund / 100} processed, but a pending fine of ₹${refund / 100} has been added to your account ledger.',
              style: GoogleFonts.nunito(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispute failed: $e')),
      );
    }
  }

  // Pure cancellation logic checker
  bool _canCancel() {
    if (_order == null) return false;
    if (_order!.status != 'requested' && _order!.status != 'accepted') return false;
    if (_order!.hasTenMinItem) return false;
    if (_order!.delayUpdatedAt != null) return false;
    
    // Check if created_at <= 15 minutes
    try {
      final created = DateTime.parse(_order!.createdAt);
      final age = DateTime.now().toUtc().difference(created);
      if (age.inMinutes > 15) return false;
    } catch (_) {
      return false;
    }
    return true;
  }

  int _getStatusStepIndex(String status) {
    switch (status) {
      case 'requested':
        return 0;
      case 'accepted':
        return 1;
      case 'preparing':
        return 2;
      case 'ready':
        return 3;
      case 'out_for_delivery':
        return 4;
      case 'delivered':
        return 5;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Status')),
        body: const Center(child: Text('No active order. Please place an order first.')),
      );
    }

    final int currentStep = _getStatusStepIndex(_order!.status);
    final isTerminal = ['cancelled', 'rejected', 'disputed', 'refunded'].contains(_order!.status);
    final double rupees = _order!.amountPaise / 100;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          style: IconButton.styleFrom(backgroundColor: AppColors.surface),
        ),
        title: Text('Order Tracking',
          style: GoogleFonts.nunito(
            fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.foreground)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              label: Text('#${_order!.id.substring(0, 8).toUpperCase()}',
                style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
              backgroundColor: AppColors.primaryLight,
              side: BorderSide.none,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatusOverview(isTerminal, rupees),
                  const SizedBox(height: 12),
                  if (!isTerminal) ...[
                    _buildDelayChips(),
                    const SizedBox(height: 12),
                  ],
                  _buildStepper(currentStep, isTerminal),
                  const SizedBox(height: 12),
                  _buildSimulationControls(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomBar(isTerminal),
    );
  }

  Widget _buildStatusOverview(bool isTerminal, double rupees) {
    Color cardBg = AppColors.primary;
    String statusTitle = _order!.status.toUpperCase();
    String sub = 'Scheduled for ${_order!.scheduledArrival.substring(11, 16)} UTC';

    if (_order!.status == 'cancelled') {
      cardBg = AppColors.red;
      statusTitle = 'CANCELLED';
      sub = 'Customer cancelled the order';
    } else if (_order!.status == 'rejected') {
      cardBg = Colors.deepOrange;
      statusTitle = 'REJECTED BY VENDOR';
      sub = 'Reason: ${_order!.rejectionReason ?? "out_of_stock"}';
    } else if (_order!.status == 'disputed') {
      cardBg = AppColors.amber;
      statusTitle = 'DISPUTED';
      sub = 'Under investigation';
    } else if (_order!.paymentVerified) {
      statusTitle += ' (PAID - TRUSTED SALE)';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('STATUS', style: GoogleFonts.nunito(
            fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w800,
            letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(statusTitle, style: GoogleFonts.nunito(
            fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          Text(sub, style: GoogleFonts.nunito(fontSize: 11, color: Colors.white70)),
          if (_order!.delayUpdatedAt != null)
            Text('Delay tapped: +15m/30m (Cancel disabled)', style: GoogleFonts.nunito(fontSize: 10, color: Colors.yellowAccent)),
        ])),
        Column(children: [
          Text('₹${rupees.toStringAsFixed(2)}', style: GoogleFonts.nunito(
            fontSize: 24, color: Colors.white, fontWeight: FontWeight.w900)),
          Text(_order!.trainNumber, style: GoogleFonts.nunito(
            fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _buildDelayChips() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TAP TO ANNOUNCE TRAIN DELAY', style: GoogleFonts.nunito(
            fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.muted)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['on-time', '+15', '+30'].map((chip) => ElevatedButton(
              onPressed: () => _applyDelay(chip),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primary,
                elevation: 0,
              ),
              child: Text(chip),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(int currentStep, bool isTerminal) {
    final steps = [
      'Placed',
      'Accepted',
      'Preparing',
      'Ready',
      'Out for Delivery',
      'Delivered'
    ];

    if (isTerminal) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryLight),
        ),
        child: Center(
          child: Text(
            'Order execution finished under status: ${_order!.status.toUpperCase()}',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: AppColors.muted),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ORDER TRACKING TIMELINE', style: GoogleFonts.nunito(
            fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.muted, letterSpacing: 1)),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            final done = i < currentStep;
            final active = i == currentStep;
            final future = i > currentStep;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: done ? AppColors.primary : (active ? Colors.white : Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done || active ? AppColors.primary : const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : (active ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))) : null),
                  ),
                  if (i < steps.length - 1)
                    Container(width: 2, height: 24, color: done ? AppColors.primary : const Color(0xFFE8EEFF)),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      steps[i],
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                        color: future ? Colors.grey.shade300 : AppColors.foreground,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSimulationControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEMO SIMULATION CONTROLS', style: GoogleFonts.nunito(
            fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _simulateVendorAccept,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                child: const Text('Accept Order', style: TextStyle(fontSize: 11)),
              ),
              ElevatedButton(
                onPressed: () => _simulateVendorAdvance('preparing'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                child: const Text('Start Preparing', style: TextStyle(fontSize: 11)),
              ),
              ElevatedButton(
                onPressed: () => _simulateVendorAdvance('ready'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                child: const Text('Mark Ready', style: TextStyle(fontSize: 11)),
              ),
              ElevatedButton(
                onPressed: () => _simulateVendorAdvance('out-for-delivery'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                child: const Text('Ship (Out)', style: TextStyle(fontSize: 11)),
              ),
              ElevatedButton(
                onPressed: () => _simulateVendorAdvance('delivered'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                child: const Text('Deliver', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          Text('Simulate Vendor Rejection (requires reason):', style: GoogleFonts.nunito(fontSize: 11, color: Colors.blueGrey)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['out_of_stock', 'too_busy', 'closing_soon'].map((reason) => OutlinedButton(
              onPressed: () => _simulateVendorReject(reason),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.deepOrange),
              child: Text(reason, style: const TextStyle(fontSize: 10)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isTerminal) {
    if (_order!.status == 'out_for_delivery') {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        decoration: const BoxDecoration(color: Colors.white),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PaymentScreen(order: _order!))),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text('Collect Payment (₹${(_order!.amountPaise / 100).toStringAsFixed(2)})'),
              ),
            ),
            const SizedBox(width: 8),
            _buildDisputeTriggerButton(),
          ],
        ),
      );
    }

    if (_order!.status == 'delivered') {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        decoration: const BoxDecoration(color: Colors.white),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PaymentScreen(order: _order!))),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('UPI/Cash Received Screen'),
              ),
            ),
            const SizedBox(width: 8),
            _buildDisputeTriggerButton(),
          ],
        ),
      );
    }

    if (_canCancel()) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        decoration: const BoxDecoration(color: Colors.white),
        child: ElevatedButton(
          onPressed: _cancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Cancel Order (Free)', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDisputeTriggerButton() {
    return ElevatedButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (dialogCtx) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text('File a Dispute', style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Disputes must be filed within 30 min of QR generation. First 3 disputes in 5 days are free, after which refunds are charged as pending dues ledger.',
                    style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: _disputeType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'not_collected', child: Text('Food Not Collected')),
                      DropdownMenuItem(value: 'customer_not_at_seat', child: Text('Customer Not at Seat')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          _disputeType = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _fileDispute();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber),
                  child: const Text('Submit Dispute'),
                ),
              ],
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.amber,
        foregroundColor: Colors.white,
      ),
      child: const Text('Dispute'),
    );
  }
}
