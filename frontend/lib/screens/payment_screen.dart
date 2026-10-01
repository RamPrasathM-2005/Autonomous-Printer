import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../widgets/workflow_stepper.dart';
import '../services/razorpay_web_service.dart';
import '../widgets/server_config_dialog.dart';
import 'otp_release_screen.dart';

class PaymentScreen extends StatefulWidget {
  final PrintOrder order;
  final List<UploadedDocument>? documents;
  final List<DocumentPrintConfig>? configs;

  const PaymentScreen({
    super.key,
    required this.order,
    this.documents,
    this.configs,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _apiService = ApiService();

  bool _isCreatingPayment = true;
  bool _isVerifying = false;
  PaymentOrderResponse? _paymentData;
  String? _paymentError;
  String _selectedPaymentMethod = 'upi';

  @override
  void initState() {
    super.initState();
    _initiatePayment();
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _isCreatingPayment = true;
      _paymentError = null;
    });

    try {
      final paymentOrder = await _apiService.createPaymentOrder(widget.order.id);
      setState(() {
        _paymentData = paymentOrder;
        _isCreatingPayment = false;
      });
    } catch (e) {
      setState(() {
        _paymentError = e.toString().replaceAll('Exception: ', '');
        _isCreatingPayment = false;
      });
    }
  }

  Future<void> _openRazorpayCheckout() async {
    final rawOrderId = _paymentData?.razorpayOrderId ?? '';
    final rzpOrderId = rawOrderId.isNotEmpty ? rawOrderId : 'order_rzp_${widget.order.id}';
    final rawKeyId = _paymentData?.keyId ?? '';
    final keyId = rawKeyId.isNotEmpty ? rawKeyId : 'rzp_test_RFxhjAiTxwrpAJ';

    setState(() {
      _isVerifying = true;
      _paymentError = null;
    });

    final result = await RazorpayWebService.openCheckout(
      keyId: keyId,
      orderId: rzpOrderId,
      amount: widget.order.amount,
    );

    if (!result.success) {
      setState(() {
        _isVerifying = false;
        if (result.errorMessage != null && result.errorMessage != 'DISMISSED') {
          _paymentError = 'Payment notice: ${result.errorMessage}';
        }
      });
      return;
    }

    try {
      await _apiService.verifyPayment(
        orderId: widget.order.id,
        razorpayOrderId: result.razorpayOrderId,
        razorpayPaymentId: result.razorpayPaymentId,
        razorpaySignature: result.razorpaySignature,
      );

      setState(() => _isVerifying = false);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) => OtpReleaseScreen(orderId: widget.order.id),
        ),
      );
    } catch (_) {
      setState(() => _isVerifying = false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) => OtpReleaseScreen(orderId: widget.order.id),
        ),
      );
    }
  }

  Future<void> _proceedToOtpRelease() async {
    setState(() {
      _isVerifying = true;
      _paymentError = null;
    });

    try {
      await _apiService.verifyPayment(
        orderId: widget.order.id,
        razorpayOrderId: _paymentData?.razorpayOrderId ?? 'order_rzp_${widget.order.id}',
        razorpayPaymentId: 'pay_rzp_${DateTime.now().millisecondsSinceEpoch}',
        razorpaySignature: 'test_sig',
      );

      await _apiService.simulatePaymentVerification(
        orderId: widget.order.id,
        razorpayOrderId: _paymentData?.razorpayOrderId ?? 'order_sim_${widget.order.id}',
        amount: widget.order.amount,
      );

      setState(() => _isVerifying = false);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) => OtpReleaseScreen(orderId: widget.order.id),
        ),
      );
    } catch (_) {
      setState(() => _isVerifying = false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) => OtpReleaseScreen(orderId: widget.order.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Checkout & Payment'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: () => showServerConfigModal(context),
              icon: const Icon(Icons.dns_rounded, size: 15, color: Colors.white),
              label: const Text(
                'Server',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 3),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review Invoice & Pay',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Confirm details and proceed with instant digital payment.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),

                      const SizedBox(height: 20),

                      // High Trust Security Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.successSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: AppTheme.success, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '100% Encrypted Payment',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                  Text(
                                    'Instant 6-digit release OTP generated immediately after payment.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Select Payment Method Card (Matches React Web PaymentStep)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Payment Method',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPaymentMethodTile(
                              id: 'upi',
                              title: 'UPI Instant Payment • QR Code',
                              subtitle: 'Google Pay, PhonePe, Paytm, BHIM UPI',
                              icon: Icons.qr_code_scanner_rounded,
                            ),
                            const SizedBox(height: 8),
                            _buildPaymentMethodTile(
                              id: 'card',
                              title: 'Debit / Credit Card • Net Banking',
                              subtitle: 'Visa, MasterCard, RuPay, All Major Banks',
                              icon: Icons.credit_card_rounded,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Order Summary Invoice Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Invoice Summary',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primarySurface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#${widget.order.id.takeLast(8).toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 28),

                            if (widget.configs != null && widget.configs!.isNotEmpty) ...[
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: widget.configs!.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (ctx, idx) {
                                  final cfg = widget.configs![idx];
                                  return Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceSubtle,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          cfg.document.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                                          size: 18,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cfg.document.filename,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${cfg.copies} copy • ${cfg.calculatedPages} pg • ${cfg.isColor ? "Color" : "B&W"}',
                                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '₹${cfg.estimatedCost.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const Divider(height: 28),
                            ],

                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Print Subtotal',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('₹${widget.order.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Platform & Convenience Fee',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('₹0.00 (FREE)', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total Payable',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '₹${widget.order.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (_paymentError != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                          ),
                          child: Text(
                            _paymentError!,
                            style: const TextStyle(color: AppTheme.danger, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: (_isCreatingPayment || _isVerifying) ? null : _openRazorpayCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          shadowColor: AppTheme.primary.withOpacity(0.4),
                        ),
                        child: _isVerifying
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  ),
                                  SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      'Verifying Payment & Generating OTP...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.payment_rounded, size: 20),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      'Pay ₹${widget.order.amount.toStringAsFixed(2)} via Razorpay',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: (_isCreatingPayment || _isVerifying) ? null : _proceedToOtpRelease,
                        child: const Text(
                          'Test Demo Pay (Skip Razorpay Modal)',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedPaymentMethod == id;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = id;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySurface : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppTheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String takeLast(int n) {
    if (length <= n) return this;
    return substring(length - n);
  }
}
