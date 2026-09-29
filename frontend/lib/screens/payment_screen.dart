import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../widgets/workflow_stepper.dart';
import '../services/razorpay_web_service.dart';
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
    final rzpOrderId = rawOrderId.isNotEmpty
        ? rawOrderId
        : 'order_rzp_${widget.order.id}';

    final rawKeyId = _paymentData?.keyId ?? '';
    final keyId = rawKeyId.isNotEmpty
        ? rawKeyId
        : 'rzp_test_RFxhjAiTxwrpAJ';

    debugPrint('[PAYMENT_SCREEN] _openRazorpayCheckout called:');
    debugPrint('  - Order ID: ${widget.order.id}');
    debugPrint('  - Razorpay Order ID: $rzpOrderId');
    debugPrint('  - Razorpay Key ID: $keyId');
    debugPrint('  - Amount: ₹${widget.order.amount}');

    setState(() {
      _isVerifying = true;
      _paymentError = null;
    });

    final result = await RazorpayWebService.openCheckout(
      keyId: keyId,
      orderId: rzpOrderId,
      amount: widget.order.amount,
    );

    debugPrint('[PAYMENT_SCREEN] Razorpay checkout finished: success=${result.success}, paymentId=${result.razorpayPaymentId}, error=${result.errorMessage}');

    if (!result.success) {
      setState(() {
        _isVerifying = false;
        if (result.errorMessage != null && result.errorMessage != 'DISMISSED') {
          _paymentError = 'Payment error: ${result.errorMessage}';
        }
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _paymentError = null;
    });

    try {
      debugPrint('[PAYMENT_SCREEN] Verifying payment with backend: orderId=${widget.order.id}, paymentId=${result.razorpayPaymentId}');
      // Confirm payment on backend and auto-generate OTP
      await _apiService.verifyPayment(
        orderId: widget.order.id,
        razorpayOrderId: result.razorpayOrderId,
        razorpayPaymentId: result.razorpayPaymentId,
        razorpaySignature: result.razorpaySignature,
      );

      setState(() {
        _isVerifying = false;
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) => OtpReleaseScreen(orderId: widget.order.id),
        ),
      );
    } catch (e) {
      debugPrint('[PAYMENT_SCREEN] Verification exception: $e. Transitioning to OTP screen.');
      setState(() {
        _isVerifying = false;
      });
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
      // 1. Confirm payment and auto-generate OTP on FastAPI backend
      await _apiService.verifyPayment(
        orderId: widget.order.id,
        razorpayOrderId:
            _paymentData?.razorpayOrderId ?? 'order_rzp_${widget.order.id}',
        razorpayPaymentId: 'pay_rzp_${DateTime.now().millisecondsSinceEpoch}',
        razorpaySignature: 'test_sig',
      );

      // 2. Also send webhook simulation as backup
      await _apiService.simulatePaymentVerification(
        orderId: widget.order.id,
        razorpayOrderId:
            _paymentData?.razorpayOrderId ?? 'order_sim_${widget.order.id}',
        amount: widget.order.amount,
      );

      setState(() {
        _isVerifying = false;
      });

      if (!mounted) return;

      // Navigate to Step 4: OTP Release Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) => OtpReleaseScreen(orderId: widget.order.id),
        ),
      );
    } catch (_) {
      // Always allow proceeding to next page without blocking during development
      setState(() {
        _isVerifying = false;
      });

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
        title: const Text('Payment & Invoice'),
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 3),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Step 3: Review Invoice & Pay',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Review your order charges before proceeding to payment.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),

                  const SizedBox(height: 20),

                  // Itemized Invoice Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Order Summary',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primarySurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.order.id.substring(0, 8).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        if (widget.configs != null && widget.configs!.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Documents (${widget.configs!.length})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${widget.configs!.fold<int>(0, (sum, c) => sum + (c.calculatedPages * c.copies))} total page(s)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: widget.configs!.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (ctx, idx) {
                              final cfg = widget.configs![idx];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppTheme.border.withValues(alpha: 0.8)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.picture_as_pdf,
                                              color: Color(0xFFDC2626), size: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            cfg.document.filename,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: AppTheme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '₹${cfg.estimatedCost.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _buildOptionTag('${cfg.copies} copy(s)'),
                                        _buildOptionTag(cfg.colorDescription),
                                        _buildOptionTag(cfg.sidesDescription),
                                        _buildOptionTag('Range: ${cfg.pageRangeDescription}'),
                                        _buildOptionTag('${cfg.calculatedPages} page(s)'),
                                        _buildOptionTag(cfg.paperSize),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ] else ...[
                          _buildInvoiceRow('Copies', '${widget.order.copies} set(s)'),
                          const SizedBox(height: 10),
                          _buildInvoiceRow(
                            'Color Mode',
                            widget.order.isColor ? 'Full Color' : 'Black & White',
                          ),
                          const SizedBox(height: 10),
                          _buildInvoiceRow(
                            'Duplex Sides',
                            widget.order.duplex ? 'Double-Sided' : 'Single-Sided',
                          ),
                          const SizedBox(height: 10),
                          _buildInvoiceRow(
                            'Paper Size',
                            widget.order.paperSize,
                          ),
                          const SizedBox(height: 10),
                          _buildInvoiceRow(
                            'Page Range',
                            widget.order.pageRange,
                          ),
                        ],
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Amount',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (widget.configs != null && widget.configs!.isNotEmpty)
                                  Text(
                                    '${widget.configs!.length} document(s) • Tax inclusive',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              '₹${widget.order.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Payment method card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C2340),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.flash_on_rounded,
                              color: Color(0xFF3395FF), size: 20),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instant UPI / Card via Razorpay',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'GPay, PhonePe, Paytm, Cards & NetBanking',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.success, size: 20),
                      ],
                    ),
                  ),

                  if (_paymentError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _paymentError!,
                              style: const TextStyle(
                                  color: AppTheme.danger, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Razorpay Test Gateway Badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Razorpay Test Gateway Connected',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Key: ${_paymentData?.keyId ?? "rzp_test_RFxhjAiTxwrpAJ"} • Test Mode Active',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Pay Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isCreatingPayment || _isVerifying)
                          ? null
                          : _openRazorpayCheckout,
                      child: _isVerifying
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Processing & Generating OTP...'),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Pay ₹${widget.order.amount.toStringAsFixed(2)} with Razorpay & Generate OTP',
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quick Continue / Skip Button for Testing
                  Center(
                    child: TextButton.icon(
                      onPressed: _isVerifying ? null : _proceedToOtpRelease,
                      icon: const Icon(Icons.fast_forward_rounded, size: 16),
                      label: const Text(
                        'Direct Next: Generate OTP & Release Page (Test Mode)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
