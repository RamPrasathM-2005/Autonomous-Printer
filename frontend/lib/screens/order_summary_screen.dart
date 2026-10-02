import '../widgets/app_scaffold.dart';
import '../widgets/real_document_preview.dart';
import 'document_editor_screen.dart';
import '../widgets/help_action.dart';

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

  late List<DocumentPrintConfig> _configs;
  bool _filesExpanded = true;
  PrintOrder? _currentOrder;
  PaymentInitiateResponse? _payment;
  bool _busy = false;
  bool _testPaymentMode = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _configs = widget.configs.map((c) => c.copyWith()).toList();
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

  int get _totalCalculatedPages =>
      _configs.fold(0, (sum, c) => sum + (c.calculatedPages * c.copies));

  double get _totalEstimatedTotal =>
      _configs.fold(0.0, (sum, c) => sum + c.estimatedCost);

  Future<PrintOrder> _ensureOrderCreated() async {
    if (_currentOrder != null) return _currentOrder!;

    final primary = _configs.first;
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

    final List<Map<String, dynamic>> itemsPayload = _configs.map((c) {
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
      documentId: primary.document.id,
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
            configs: _configs,
            documents: _configs.map((c) => c.document).toList(),
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
              configs: _configs,
              documents: _configs.map((c) => c.document).toList(),
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

    return AppScaffold(
      appBar: AppBar(
        actions: const [HelpAction()],
        title: const Text(
          'Order Summary',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 18),
        ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Review Your Order',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildDocumentItemsList(),
                const SizedBox(height: 24),
                const Text(
                  'Order Summary',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _buildSummaryPanel(finalAmount),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canEdit => !_busy && _currentOrder == null;

  Future<void> _editDocument(int index) async {
    final updated = await Navigator.push<DocumentPrintConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentEditorScreen(initialConfig: _configs[index]),
      ),
    );
    if (updated != null && mounted) setState(() => _configs[index] = updated);
  }

  void _preview(DocumentPrintConfig config) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 780,
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  config.document.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Close preview',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RealDocumentPreview(
                    document: config.document,
                    isLandscape: config.orientation == 'landscape',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentItemsList() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppTheme.surfaceSubtle,
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Uploaded Files',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: _filesExpanded ? 'Collapse files' : 'Expand files',
                  onPressed: () =>
                      setState(() => _filesExpanded = !_filesExpanded),
                  icon: Icon(
                    _filesExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
              ],
            ),
          ),
          if (_filesExpanded)
            ...List.generate(
              _configs.length,
              (index) => _buildDocumentRow(index),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(int index) {
    final c = _configs[index];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                height: 76,
                child: IgnorePointer(
                  child: RealDocumentPreview(
                    document: c.document,
                    isThumbnail: true,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${c.document.pages} ${c.document.pages == 1 ? 'page' : 'pages'}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${c.copies} ${c.copies == 1 ? 'copy' : 'copies'} \u00b7 ${c.colorDescription} \u00b7 ${c.sidesDescription} \u00b7 ${c.paperSize}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      c.pageRangeDescription,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '\u20b9${c.estimatedCost.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Edit file settings',
                onPressed: _canEdit ? () => _editDocument(index) : null,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
              IconButton(
                tooltip: 'Preview file',
                onPressed: () => _preview(c),
                icon: const Icon(Icons.open_in_full, size: 19),
              ),
              IconButton(
                tooltip: 'Remove file',
                onPressed: _canEdit && _configs.length > 1
                    ? () => setState(() => _configs.removeAt(index))
                    : null,
                icon: const Icon(Icons.delete_outline, size: 19),
                color: AppTheme.danger,
              ),
            ],
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
                  'Bill Details',
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
                _summaryLine('Total Files', '${_configs.length}'),
                _summaryLine('Total Pages', '$_totalCalculatedPages'),
                _summaryLine('Total Cost', amount),
                _summaryLine('Handling Charges', 'FREE'),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          amount,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
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

                FilledButton(
                  onPressed: _busy ? null : _proceedToPayment,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pay $amount',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
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
