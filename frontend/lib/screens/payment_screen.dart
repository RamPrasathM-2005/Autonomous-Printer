import 'package:flutter/material.dart';

import '../services/api_error.dart';

import '../models/document.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
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
  final _api = ApiService();
  PaymentInitiateResponse? _payment;
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _initiate();
  }

  Future<void> _initiate() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final payment = await _api.createPaymentOrder(widget.order.id);
      if (mounted) setState(() => _payment = payment);
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = userError(
            e,
            fallback: 'Unable to check payment. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showConfirmedOrder() async {
    final order = await _api.getOrder(widget.order.id);
    if (!mounted) return;
    if (order.status == 'WAITING_FOR_OTP') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OtpReleaseScreen(orderId: order.id)),
      );
    } else {
      setState(
        () => _message = order.status == 'CREATED'
            ? 'Payment unconfirmed. Check status before paying again.'
            : order.statusLabel,
      );
    }
  }

  Future<void> _pay() async {
    final payment = _payment;
    if (payment == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await RazorpayWebService.openCheckout(
        keyId: payment.keyId,
        orderId: payment.razorpayOrderId,
        amount: payment.amount,
      );
      if (!result.success) {
        if (mounted) {
          setState(
            () => _message = result.errorMessage == 'DISMISSED'
                ? 'Checkout closed. Check payment status before paying again.'
                : result.errorMessage,
          );
        }
        return;
      }
      await _api.verifyPayment(
        orderId: widget.order.id,
        razorpayOrderId: result.razorpayOrderId,
        razorpayPaymentId: result.razorpayPaymentId,
        razorpaySignature: result.razorpaySignature,
      );
      await _showConfirmedOrder();
    } catch (e) {
      if (mounted) {
        setState(
          () => _message =
              'Payment unconfirmed. Check status before paying again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _api.reconcilePayment(widget.order.id);
      await _showConfirmedOrder();
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = userError(
            e,
            fallback: 'Unable to check payment. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payment')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text('Order: ${widget.order.id}'),
            Text(
              '${widget.order.totalPages} ${widget.order.totalPages == 1 ? 'page' : 'pages'}',
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.order.currency} ${widget.order.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 28),
            ),
            if (_payment?.keyId.startsWith('rzp_test_') == true)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Test mode - No charge'),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_message!),
              ),
            const SizedBox(height: 24),
            if (_busy) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy || _payment == null ? null : _pay,
              child: const Text('Pay with Razorpay'),
            ),
            TextButton(
              onPressed: _busy ? null : _check,
              child: const Text('Check payment status'),
            ),
            if (_payment == null)
              TextButton(
                onPressed: _busy ? null : _initiate,
                child: const Text('Retry checkout'),
              ),
          ],
        ),
      ),
    ),
  );
}
