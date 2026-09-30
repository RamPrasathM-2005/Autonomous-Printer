import 'package:flutter/material.dart';

import '../services/api_error.dart';
import '../config/theme.dart';

import '../models/document.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../services/razorpay_web_service.dart';
import 'payment_success_screen.dart';

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
  bool _testPaymentMode = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _loadCapabilities();
  }

  Future<void> _loadCapabilities() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final capabilities = await _api.paymentCapabilities();
      if (mounted) {
        setState(() {
          _testPaymentMode = capabilities['paymentMode'] == 'test';
        });
      }
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

  Future<void> _showConfirmedOrder({String? paymentId}) async {
    final order = await _api.getOrder(widget.order.id);
    if (!mounted) return;
    if (order.status == 'WAITING_FOR_OTP' || order.status == 'PAID') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            order: order,
            configs: widget.configs,
            documents: widget.documents,
            paymentId: paymentId,
          ),
        ),
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
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final payment =
          _payment ?? await _api.createPaymentOrder(widget.order.id);
      _payment = payment;
      if (!mounted) return;
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
      await _showConfirmedOrder(paymentId: result.razorpayPaymentId);
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

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _panel(List<Widget> children) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.surfaceWhite,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _heading(String text) => Text(
    text,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
  );


  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final settings = order.printSettings;
    final amount = '${order.currency} ${order.amount.toStringAsFixed(2)}';
    final items = settings.items;
    final details = _panel([
      _heading('Documents'),
      const SizedBox(height: 20),
      if (items.isNotEmpty)
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.filename,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${item.pages} ${item.pages == 1 ? 'page' : 'pages'} \u00b7 ${item.copies} ${item.copies == 1 ? 'copy' : 'copies'} \u00b7 ${item.colour ? 'Color' : 'B&W'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.amount.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    item.amount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          )
      else if (widget.documents?.isNotEmpty == true)
        for (final document in widget.documents!)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              document.filename,
              style: const TextStyle(fontSize: 14),
            ),
          ),
      const Divider(height: 24),
      _heading('Print settings'),
      const SizedBox(height: 12),
      _detail('Paper', settings.paperSize),
      _detail(
        'Orientation',
        settings.orientation == 'landscape' ? 'Landscape' : 'Portrait',
      ),
      _detail(
        'Sides',
        settings.sides == 'one-sided' ? 'Single-sided' : 'Double-sided',
      ),
      _detail('Station', order.printServerId),
    ]);
    final summary = _panel([
      Row(
        children: [
          Expanded(child: _heading('Order summary')),
          if (_testPaymentMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Test mode',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
      const SizedBox(height: 20),
      if (items.isNotEmpty) _detail('Documents', '${items.length}'),
      _detail('Printed pages', '${order.totalPages}'),
      const Divider(height: 28),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Total',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Flexible(
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      if (_testPaymentMode)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'No charge in test mode',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _message!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 24),
      if (_busy)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      ElevatedButton(
        onPressed: _busy ? null : _pay,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Pay with Razorpay',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: _busy ? null : _check,
        child: const Text(
          'Check payment status',
          style: TextStyle(fontSize: 13),
        ),
      ),
      const Divider(height: 24),
      const Text(
        'Order reference',
        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
      const SizedBox(height: 4),
      SelectableText(
        order.id,
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
    ]);
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          details,
                          const SizedBox(height: 16),
                          summary,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: details),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: summary),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
