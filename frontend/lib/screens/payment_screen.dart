import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import 'otp_release_screen.dart';

class PaymentScreen extends StatefulWidget {
  final PrintOrder order;
  final UploadedDocument document;

  const PaymentScreen({
    super.key,
    required this.order,
    required this.document,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _apiService = ApiService();
  bool _isInitiating = false;
  PaymentInitiateResponse? _paymentData;
  String? _errorMessage;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _initiatePayment();
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _isInitiating = true;
      _errorMessage = null;
    });

    try {
      final payment = await _apiService.createPayment(widget.order.id);
      setState(() {
        _paymentData = payment;
        _isInitiating = false;
      });
    } catch (e) {
      setState(() {
        _isInitiating = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _completePaymentSimulation() async {
    if (_paymentData == null) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // Simulate Razorpay webhook verification on FastAPI backend
      await _apiService.simulatePaymentVerification(
        orderId: widget.order.id,
        razorpayOrderId: _paymentData!.razorpayOrderId,
        amount: widget.order.amount,
      );

      // Verify order status from backend
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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (ctx) => OtpReleaseScreen(orderId: widget.order.id),
        ),
      );
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Payment confirmation error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.order.printSettings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order & Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Invoice Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PRINT JOB INVOICE',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.order.id,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 16),

                  _invoiceRow('Document', widget.document.originalFilename),
                  _invoiceRow('Station', widget.order.printServerId),
                  _invoiceRow('Pages per copy', '${widget.order.totalPages} pages'),
                  _invoiceRow('Number of copies', '${widget.order.copies}'),
                  _invoiceRow('Color Mode', settings.colour ? 'Full Color (₹10/pg)' : 'Monochrome B/W (₹2/pg)'),
                  _invoiceRow('Duplex Mode', settings.sides),
                  _invoiceRow('Paper Size & Layout', '${settings.paperSize} (${settings.orientation})'),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable Amount',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        widget.order.formattedAmount,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Razorpay Payment Details
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C2340),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.payment, color: Color(0xFF528FF0), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Razorpay Secure Payment',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                            ),
                            Text(
                              'UPI, Cards, NetBanking, Wallets',
                              style: TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified_user_rounded, color: AppTheme.success, size: 20),
                    ],
                  ),
                  if (_paymentData != null) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Razorpay Order ID:', style: TextStyle(fontSize: 12, color: Colors.white54)),
                        Text(
                          _paymentData!.razorpayOrderId,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Pay Button
            ElevatedButton(
              onPressed: (_isInitiating || _isVerifying) ? null : _completePaymentSimulation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF528FF0),
              ),
              child: _isVerifying
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Confirming Payment & Generating OTP...'),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Pay ${widget.order.formattedAmount} via Razorpay'),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Self-Hosted Safe Architecture: Backend validates HMAC signature',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _invoiceRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.white60)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
