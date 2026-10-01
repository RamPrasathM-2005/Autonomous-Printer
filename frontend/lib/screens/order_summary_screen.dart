import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/api_error.dart';
import '../services/api_service.dart';
import '../services/razorpay_web_service.dart';
import 'otp_release_screen.dart';

class OrderSummaryScreen extends StatefulWidget {
  final PrintOrder? order;
  final List<DocumentPrintConfig> configs;
  final String selectedStationId;
  final UploadedDocument primaryDocument;

  const OrderSummaryScreen({
    super.key,
    this.order,
    required this.configs,
    required this.selectedStationId,
    required this.primaryDocument,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  final ApiService _api = ApiService();

  PrintOrder? _currentOrder;
  PaymentInitiateResponse? _payment;
  bool _busy = false;
  bool _testPaymentMode = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _loadCapabilities();
  }

  Future<void> _loadCapabilities() async {
    try {
      final capabilities = await _api.paymentCapabilities();
      if (mounted) {
        setState(() {
          _testPaymentMode = capabilities['paymentMode'] == 'test';
        });
      }
    } catch (_) {}
  }

  int get _totalCopies =>
      widget.configs.fold(0, (sum, c) => sum + c.copies);

  int get _totalCalculatedPages =>
      widget.configs.fold(0, (sum, c) => sum + (c.calculatedPages * c.copies));

  double get _totalEstimatedTotal =>
      widget.configs.fold(0.0, (sum, c) => sum + c.estimatedCost);

  Future<PrintOrder> _ensureOrderCreated() async {
    if (_currentOrder != null) return _currentOrder!;

    final primary = widget.configs.first;
    final primarySettings = PrintSettings(
      copies: primary.copies,
      colour: primary.isColor,
      sides: primary.sides,
      paperSize: primary.paperSize,
      orientation: primary.orientation,
      pageRange: primary.isCustomRange && primary.customRange.trim().isNotEmpty
          ? primary.customRange.trim()
          : primary.rangeOption,
    );

    final List<Map<String, dynamic>> itemsPayload = widget.configs.map((c) {
      final pr = (c.isCustomRange && c.customRange.trim().isNotEmpty)
          ? c.customRange.trim()
          : c.rangeOption;
      return {
        'document_id': c.document.id,
        'settings': {
          'copies': c.copies,
          'colour': c.isColor,
          'sides': c.sides,
          'paper_size': c.paperSize,
          'orientation': c.orientation,
          'page_range': pr,
        },
      };
    }).toList();

    final order = await _api.createOrder(
      documentId: widget.primaryDocument.id,
      printServerId: widget.selectedStationId,
      printSettings: primarySettings,
      items: itemsPayload,
    );

    _currentOrder = order;
    return order;
  }

  Future<void> _proceedToPayment() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final order = await _ensureOrderCreated();
      final payment = _payment ?? await _api.createPaymentOrder(order.id);
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
                ? 'Checkout was dismissed. Check status or try again.'
                : result.errorMessage,
          );
        }
        return;
      }

      await _api.verifyPayment(
        orderId: order.id,
        razorpayOrderId: result.razorpayOrderId,
        razorpayPaymentId: result.razorpayPaymentId,
        razorpaySignature: result.razorpaySignature,
      );

      final confirmedOrder = await _api.getOrder(order.id);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpReleaseScreen(
            orderId: confirmedOrder.id,
            order: confirmedOrder,
            configs: widget.configs,
            documents: widget.configs.map((c) => c.document).toList(),
            paymentId: result.razorpayPaymentId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = userError(
            e,
            fallback: 'Payment verification failed. Check status before trying again.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkPaymentStatus() async {
    if (_currentOrder == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await _api.reconcilePayment(_currentOrder!.id);
      final order = await _api.getOrder(_currentOrder!.id);

      if (!mounted) return;

      if (order.status == 'WAITING_FOR_OTP' || order.status == 'PAID') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpReleaseScreen(
              orderId: order.id,
              order: order,
              configs: widget.configs,
              documents: widget.configs.map((c) => c.document).toList(),
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
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = userError(
            e,
            fallback: 'Unable to check payment status. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalAmount = _currentOrder != null
        ? '₹${_currentOrder!.amount.toStringAsFixed(2)}'
        : '₹${_totalEstimatedTotal.toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Order Summary'),
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                final itemsWidget = _buildDocumentItemsList();
                final summaryWidget = _buildSummaryPanel(finalAmount);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: itemsWidget),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: summaryWidget),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    itemsWidget,
                    const SizedBox(height: 14),
                    summaryWidget,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentItemsList() {
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Documents',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${widget.configs.length} ${widget.configs.length == 1 ? 'file' : 'files'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // Document rows
          ...List.generate(widget.configs.length, (i) {
            final c = widget.configs[i];
            final isLast = i == widget.configs.length - 1;
            return Column(
              children: [
                _buildDocumentRow(c),
                if (!isLast) const Divider(height: 1, color: AppTheme.border),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(DocumentPrintConfig c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // File type badge
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.isColor ? AppTheme.primarySurface : AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: c.isColor ? AppTheme.primaryBorder : AppTheme.border,
              ),
            ),
            child: Center(
              child: Text(
                c.document.isPdf ? 'PDF' : 'IMG',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: c.isColor ? AppTheme.primary : AppTheme.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.document.filename,
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
                  '${c.pageRangeDescription} · ${c.isColor ? 'Color' : 'B&W'} · ${c.copies}x · ${c.calculatedPages * c.copies} pgs',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₹${c.estimatedCost.toStringAsFixed(2)}',
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

  Widget _buildSummaryPanel(String amount) {
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_testPaymentMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                _summaryLine('Documents', '${widget.configs.length}'),
                _summaryLine('Copies', '$_totalCopies'),
                _summaryLine('Billable pages', '$_totalCalculatedPages'),
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

                if (_message != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  onTap: _busy ? null : _proceedToPayment,
                  child: Container(
                    height: 50,
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
                          'Pay Now',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _busy ? AppTheme.textMuted : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_currentOrder != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _checkPaymentStatus,
                    child: const Text(
                      'Check payment status',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
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
