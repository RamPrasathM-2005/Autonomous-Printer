import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/api_error.dart';
import '../services/api_service.dart';
import '../services/razorpay_web_service.dart';
import '../widgets/workflow_stepper.dart';
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
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Order Summary'),
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 3),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 780;

                      final itemsWidget = _buildDocumentItemsList();
                      final summaryWidget = _buildSummaryCard(finalAmount);

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: itemsWidget),
                            const SizedBox(width: 24),
                            Expanded(flex: 2, child: summaryWidget),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          itemsWidget,
                          const SizedBox(height: 16),
                          summaryWidget,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItemsList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Documents for Printing',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${widget.configs.length} ${widget.configs.length == 1 ? 'file' : 'files'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          for (int i = 0; i < widget.configs.length; i++)
            _buildDocumentItemRow(widget.configs[i], i + 1),

          const SizedBox(height: 6),
          const Divider(height: 14),
          const SizedBox(height: 4),

          // Station Details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.print_outlined, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pickup Station',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        widget.selectedStationId,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItemRow(DocumentPrintConfig c, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: c.isColor ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: c.isColor ? const Color(0xFFBFDBFE) : AppTheme.border,
              ),
            ),
            child: Icon(
              c.document.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined,
              size: 15,
              color: c.isColor ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.document.filename,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${c.pageRangeDescription} · ${c.isColor ? 'Color' : 'B&W'} · ${c.copies}c · ${c.sides == 'one-sided' ? '1-Sided' : '2-Sided'} · ${c.calculatedPages * c.copies} pgs',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${c.estimatedCost.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String amount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Price Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (_testPaymentMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'Test Gateway',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          _buildSummaryLine('Total Documents', '${widget.configs.length}'),
          _buildSummaryLine('Total Copies', '$_totalCopies'),
          _buildSummaryLine('Total Billable Pages', '$_totalCalculatedPages'),

          const Divider(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Final Payable',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),

          if (_testPaymentMode)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Test mode active: no live charges will occur.',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ),

          if (_message != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                _message!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ),
          ],

          const SizedBox(height: 22),

          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          ElevatedButton(
            onPressed: _busy ? null : _proceedToPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.lock_outline, size: 18),
                SizedBox(width: 8),
                Text(
                  'Proceed to Payment',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          if (_currentOrder != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : _checkPaymentStatus,
              child: const Text(
                'Check Payment Status',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: AppTheme.textSecondary),
              SizedBox(width: 6),
              Text(
                'Secured with 256-bit Razorpay Checkout',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value) {
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
