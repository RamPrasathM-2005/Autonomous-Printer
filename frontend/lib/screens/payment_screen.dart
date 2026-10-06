import '../widgets/app_scaffold.dart';
import '../widgets/help_action.dart';
import '../widgets/user_action.dart';

import 'package:flutter/material.dart';

import '../services/api_error.dart';
import '../config/theme.dart';

import '../models/document.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../services/order_recovery_service.dart';
import '../services/razorpay_web_service.dart';
import 'otp_release_screen.dart';
import 'upload_screen.dart';
import '../widgets/payment_failed_dialog.dart';
import '../widgets/ui_state.dart';

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
    OrderRecoveryService().setActiveOrder(widget.order.id, stage: 'UNPAID');
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
    // Poll the backend for up to 2 seconds after verification — the order status
    // can still be CREATED briefly due to a webhook/DB lag after Razorpay confirms.
    PrintOrder? order;
    for (int attempt = 0; attempt < 5; attempt++) {
      order = await _api.getOrder(widget.order.id);
      final s = order.status.toUpperCase();
      if (s == 'WAITING_FOR_OTP' || s == 'PAID' || s == 'JOB_QUEUED') break;
      if (attempt < 4) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    if (!mounted || order == null) return;
    final s = order.status.toUpperCase();
    if (s == 'WAITING_FOR_OTP' || s == 'PAID' || s == 'JOB_QUEUED') {
      OrderRecoveryService().setActiveOrder(order.id, stage: 'WAITING_FOR_OTP');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpReleaseScreen(
            orderId: order!.id,
            order: order,
            documents: widget.documents,
            configs: widget.configs,
            paymentId: paymentId,
          ),
        ),
      );
    } else {
      setState(
        () => _message = s == 'CREATED'
            ? 'Payment unconfirmed. Tap "Check payment status" to verify.'
            : order!.statusLabel,
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
          setState(() {
            _busy = false;
            _message = result.errorMessage == 'DISMISSED'
                ? 'Checkout closed. You can try again.'
                : result.errorMessage ?? 'Payment was not completed.';
          });
          PaymentFailedDialog.show(
            context,
            message: _message,
            onCheckStatus: _check,
            onRetry: () => _pay(),
            onCancel: () => _handleCancelOrder(),
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
        setState(() {
          _busy = false;
          _message = userError(
            e,
            fallback: 'Payment unconfirmed. Check status before paying again.',
          );
        });
        PaymentFailedDialog.show(
          context,
          message: _message,
          onCheckStatus: _check,
          onRetry: () => _pay(),
          onCancel: () => _handleCancelOrder(),
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

  Future<void> _handleCancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text(
          'Are you sure you want to cancel this order? You can then start a fresh print job.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _api.cancelOrder(widget.order.id);
      OrderRecoveryService().clearActiveOrder();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UploadScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = userError(
            e,
            fallback: 'Could not cancel order. Please try again.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final statusUpper = order.status.toUpperCase();
    if (['COMPLETED', 'SUCCESS'].contains(statusUpper)) {
      return AppScaffold(
        appBar: AppBar(
          actions: const [HelpAction(), UserAction()],
          title: const Text('Payment'),
        ),
        body: UiSuccessView(
          title: 'Order Paid',
          message: 'This order has already been paid.',
          actionLabel: 'View Order',
          onAction: () => _showConfirmedOrder(),
        ),
      );
    }
    if (['CANCELLED', 'REFUNDED'].contains(statusUpper)) {
      return AppScaffold(
        appBar: AppBar(
          actions: const [HelpAction(), UserAction()],
          title: const Text('Payment'),
        ),
        body: UiDisabledView(
          title: 'Order Cancelled',
          message: 'This order was cancelled and cannot be paid.',
          actionLabel: 'New Print Job',
          onAction: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const UploadScreen()),
              (route) => false,
            );
          },
        ),
      );
    }

    final settings = order.printSettings;
    final amount = '${order.currency} ${order.amount.toStringAsFixed(2)}';
    final items = settings.items;

    return AppScaffold(
      appBar: AppBar(
        actions: const [HelpAction(), UserAction()],
        title: const Text('Payment'),
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
      ),
      body: UiProcessingOverlay(
        isProcessing: _busy,
        title: 'Processing Payment',
        message: 'Verifying payment with gateway...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 700;

                  final detailsCard = _buildDetailsCard(order, settings, items);
                  final summaryCard = _buildSummaryCard(order, amount, items);

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: detailsCard),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: summaryCard),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      detailsCard,
                      const SizedBox(height: 14),
                      summaryCard,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(
    PrintOrder order,
    PrintSettings settings,
    List items,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              'Documents',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Items
          if (items.isNotEmpty)
            ...List.generate(items.length, (i) {
              final item = items[i];
              final isLast = i == items.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: AppTheme.textMuted,
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${item.pages} ${item.pages == 1 ? 'page' : 'pages'} · ${item.copies} ${item.copies == 1 ? 'copy' : 'copies'} · ${item.colour ? 'Color' : 'B&W'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.amount.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Text(
                            item.amount,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(height: 1, color: AppTheme.border),
                ],
              );
            })
          else if (widget.documents?.isNotEmpty == true)
            ...widget.documents!.map(
              (doc) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  doc.filename,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),

          const Divider(height: 1, color: AppTheme.border),

          // Print settings
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Print Settings',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _detailRow('Paper', settings.paperSize),
                _detailRow(
                  'Orientation',
                  settings.orientation == 'landscape'
                      ? 'Landscape'
                      : 'Portrait',
                ),
                _detailRow(
                  'Sides',
                  settings.sides == 'one-sided'
                      ? 'Single-sided'
                      : 'Double-sided',
                ),
                _detailRow('Station', order.printServerId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(PrintOrder order, String amount, List items) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_testPaymentMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningSurface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppTheme.warningBorder),
                    ),
                    child: const Text(
                      'Test Mode',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items.isNotEmpty)
                  _summaryLine('Documents', '${items.length}'),
                _summaryLine('Printed pages', '${order.totalPages}'),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),

                if (_testPaymentMode)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'No charge in test mode',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      textAlign: TextAlign.right,
                    ),
                  ),

                if (_message != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.dangerBorder),
                    ),
                    child: Text(
                      _message!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppTheme.primary,
                      backgroundColor: AppTheme.surfaceLight,
                    ),
                  ),

                // Pay button
                GestureDetector(
                  onTap: _busy ? null : _pay,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _busy ? AppTheme.surfaceSubtle : AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: _busy ? AppTheme.textMuted : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pay with Razorpay',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _busy ? AppTheme.textMuted : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                TextButton(
                  onPressed: _busy ? null : _check,
                  child: const Text(
                    'Check payment status',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                TextButton.icon(
                  onPressed: _busy ? null : _handleCancelOrder,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppTheme.danger,
                  ),
                  label: const Text(
                    'Cancel Order',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.danger,
                    ),
                  ),
                ),

                const Divider(height: 24, color: AppTheme.border),

                const Text(
                  'Order reference',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  order.id,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
      ),
    );
  }
}
