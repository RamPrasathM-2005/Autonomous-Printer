import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../widgets/workflow_stepper.dart';
import 'otp_release_screen.dart';

class PaymentScreen extends StatefulWidget {
  final PrintOrder order;

  const PaymentScreen({super.key, required this.order});

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

  Future<void> _simulatePayAndConfirm() async {
    setState(() {
      _isVerifying = true;
      _paymentError = null;
    });

    try {
      // 1. Simulate webhook payment confirmation on FastAPI backend
      await _apiService.simulatePaymentVerification(
        orderId: widget.order.id,
        razorpayOrderId:
            _paymentData?.razorpayOrderId ?? 'order_sim_${widget.order.id}',
        amount: widget.order.amount,
      );

      // 2. Poll order status from backend until WAITING_FOR_OTP
      int attempts = 0;
      while (attempts < 5) {
        await Future.delayed(const Duration(milliseconds: 1000));
        final updatedOrder = await _apiService.getOrder(widget.order.id);
        if (updatedOrder.status.toUpperCase() == 'WAITING_FOR_OTP') {
          break;
        }
        attempts++;
      }

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
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _paymentError = 'Payment verification failed: $e';
      });
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
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
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

                  const SizedBox(height: 32),

                  // Pay Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isCreatingPayment || _isVerifying)
                          ? null
                          : _simulatePayAndConfirm,
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
                                Text('Verifying Payment...'),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Pay ₹${widget.order.amount.toStringAsFixed(2)} & Generate OTP',
                                ),
                              ],
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
}
