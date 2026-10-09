import '../widgets/app_scaffold.dart';
import '../widgets/help_action.dart';
import '../widgets/user_action.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../models/print_server.dart';
import '../services/api_error.dart';
import '../services/api_service.dart';
import '../services/order_recovery_service.dart';
import '../widgets/invoice_preview_dialog.dart';
import '../widgets/ui_state.dart';
import 'upload_screen.dart';

class OtpReleaseScreen extends StatefulWidget {
  final String orderId;
  final PrintOrder? order;
  final List<UploadedDocument>? documents;
  final List<DocumentPrintConfig>? configs;
  final String? paymentId;
  final Future<PrintOrder> Function()? loadOrder;
  final Future<OrderOtp> Function()? loadOtp;

  const OtpReleaseScreen({
    super.key,
    required this.orderId,
    this.order,
    this.documents,
    this.configs,
    this.paymentId,
    this.loadOrder,
    this.loadOtp,
  });

  @override
  State<OtpReleaseScreen> createState() => _OtpReleaseScreenState();
}

class _OtpReleaseScreenState extends State<OtpReleaseScreen> {
  final ApiService _apiService = ApiService();
  OrderOtp? _otpData;
  PrintOrder? _order;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _pollingTimer;
  bool _pollingInFlight = false;

  String? _selectedPrinterName;
  bool _isPrinterLocked = false;
  bool _isSubmittingPrinter = false;
  bool _otpRevealed = false;
  bool _isCancelling = false;

  // 'WAITING', 'PRINTING', 'COMPLETED'
  String _printStatus = 'WAITING';
  double _printProgress = 0.0;

  List<Printer> _availablePrinters = [];
  DateTime? _lastPrinterRefresh;

  Future<PrintOrder> _getOrder() =>
      widget.loadOrder?.call() ?? _apiService.getOrder(widget.orderId);
  Future<OrderOtp> _getOtp() =>
      widget.loadOtp?.call() ?? _apiService.getOrderOtp(widget.orderId);

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _order = widget.order;
    }
    _fetchOtpAndOrder();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling({int intervalMs = 2000}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      _pollOrderStatus();
    });
  }

  Future<void> _fetchOtpAndOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order = await _getOrder();
      if (!mounted) return;
      final statusUpper = order.status.toUpperCase();
      OrderOtp? otp;
      if (['WAITING_FOR_OTP', 'PAID', 'JOB_QUEUED'].contains(statusUpper)) {
        try {
          otp = await _getOtp();
        } catch (_) {}
      }

      if (!mounted) return;

      // Load active printers from database for this print station or department
      List<Printer> loadedPrinters = [];
      try {
        loadedPrinters = await _apiService.fetchPrinters(
          serverId: order.printServerId,
        );
      } catch (_) {}

      final existingPrinter =
          order.printSettings.toJson()['cups_printer_name'] ??
          order.printSettings.toJson()['selected_printer'] ??
          otp?.selectedPrinter;

      final isLocked =
          (otp?.printerSelectionLocked ?? false) ||
          (order.printSettings.toJson()['printer_selection_locked'] == true);

      String currentPrintStatus = 'WAITING';
      double currentProgress = 0.0;
      if (statusUpper == 'PRINTING' || statusUpper == 'RELEASED') {
        currentPrintStatus = 'PRINTING';
        currentProgress = statusUpper == 'RELEASED' ? 0.40 : 0.75;
        OrderRecoveryService().updateActiveStage('PRINTING');
      } else if (statusUpper == 'COMPLETED' || statusUpper == 'SUCCESS') {
        currentPrintStatus = 'COMPLETED';
        currentProgress = 1.0;
        OrderRecoveryService().markCompleted(order.id);
      } else {
        OrderRecoveryService().setActiveOrder(
          order.id,
          stage: 'WAITING_FOR_OTP',
        );
      }

      String? initialSelectedPrinter = _selectedPrinterName;
      if (existingPrinter != null && existingPrinter.toString().isNotEmpty) {
        initialSelectedPrinter = existingPrinter.toString();
      } else if (initialSelectedPrinter == null && loadedPrinters.isNotEmpty) {
        initialSelectedPrinter = loadedPrinters.first.cupsQueueName;
      }

      setState(() {
        _order = order;
        _otpData = otp;
        _availablePrinters = loadedPrinters;
        _errorMessage = order.errorMessage;
        _selectedPrinterName = initialSelectedPrinter;
        _isPrinterLocked = isLocked && _selectedPrinterName != null;
        if (_isPrinterLocked) {
          _otpRevealed = true;
        }
        _printStatus = currentPrintStatus;
        _printProgress = currentProgress;
        _isLoading = false;
      });

      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = userError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _pollOrderStatus() async {
    if (_pollingInFlight) return;
    _pollingInFlight = true;
    try {
      final updated = await _getOrder();
      if (!mounted) return;
      final status = updated.status.toUpperCase();
      if (widget.loadOrder == null && (_lastPrinterRefresh == null || DateTime.now().difference(_lastPrinterRefresh!).inSeconds >= 10)) {
        _lastPrinterRefresh = DateTime.now();
        try {
          final printers = await _apiService.fetchPrinters(serverId: updated.printServerId);
          if (!mounted) return;
          setState(() => _availablePrinters = printers);
        } catch (_) {}
      }
      setState(() {
        _order = updated;
        _errorMessage = updated.errorMessage;
      });

      if (status == 'PRINTING' || status == 'RELEASED') {
        OrderRecoveryService().updateActiveStage('PRINTING');
        if (_printStatus != 'PRINTING') {
          setState(() {
            _printStatus = 'PRINTING';
            _printProgress = status == 'RELEASED' ? 0.40 : 0.75;
          });
          _startPolling(intervalMs: 2000);
        }
      } else if (status == 'COMPLETED' || status == 'SUCCESS') {
        OrderRecoveryService().markCompleted(widget.orderId);
        if (_printStatus != 'COMPLETED') {
          setState(() {
            _printStatus = 'COMPLETED';
            _printProgress = 1.0;
          });
          _pollingTimer?.cancel();
        }
      } else if (['FAILED', 'REFUNDED', 'CANCELLED', 'EXPIRED'].contains(status)) {
        setState(() {
          _printStatus = status;
          _printProgress = 0;
          _errorMessage = updated.errorMessage ?? 'Order ${status.toLowerCase()}. Check your payment status or contact the attendant.';
          _otpData = null;
        });
        _pollingTimer?.cancel();
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Connection lost. Print status unconfirmed.');
    } finally {
      _pollingInFlight = false;
    }
  }

  String get _friendlyPrinterName {
    for (final printer in _availablePrinters) {
      if (printer.cupsQueueName == _selectedPrinterName) return printer.displayName;
    }
    return _selectedPrinterName ?? 'Station printer';
  }

  String get _fullPrinterWithHardwareTag => _friendlyPrinterName;

  String _getResolvedOtpCode() {
    if (_otpData == null) return '------';
    final info = _otpData!.printerOtps?[_selectedPrinterName];
    if (info is Map && info['otp'] != null) return info['otp'].toString();
    return _otpData!.otpCode;
  }

  void _copyToClipboard() {
    final otpStr = _getResolvedOtpCode();
    if (otpStr.isEmpty || otpStr == '------') return;
    Clipboard.setData(ClipboardData(text: otpStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OTP copied'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _selectAndLockPrinter(String printerName) async {
    if (_isSubmittingPrinter || _isPrinterLocked) return;

    setState(() {
      _isSubmittingPrinter = true;
      _errorMessage = null;
    });

    try {
      await _apiService.selectOrderPrinter(
        orderId: widget.orderId,
        cupsPrinterName: printerName,
      );

      final updatedOtp = await _getOtp();
      if (!mounted) return;

      setState(() {
        _selectedPrinterName = printerName;
        _isPrinterLocked = true;
        _otpRevealed = true;
        _otpData = updatedOtp;
        _isSubmittingPrinter = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_friendlyPrinterName locked. OTP ready.'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmittingPrinter = false;
        _errorMessage = userError(e);
      });
    }
  }

  Future<void> _viewOtp() async {
    if (_selectedPrinterName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a printer first.'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isPrinterLocked) {
      await _selectAndLockPrinter(_selectedPrinterName!);
    } else {
      setState(() {
        _otpRevealed = true;
      });
    }
  }

  void _showInvoicePreview() {
    final order = _order;
    if (order == null) return;
    final otpCode = _getResolvedOtpCode();
    InvoicePreviewDialog.show(
      context,
      order: order,
      configs: widget.configs,
      documents: widget.documents,
      paymentId: widget.paymentId,
      otp: otpCode.isNotEmpty ? otpCode : null,
    );
  }

  void _shareReceipt() {
    final order = _order;
    if (order == null) return;
    final buffer = StringBuffer();
    buffer.writeln('=== ACHUPPORI RECEIPT ===');
    buffer.writeln('Order ID: ${order.id}');
    buffer.writeln('Station ID: ${order.printServerId}');
    buffer.writeln('Status: PAID (Verified)');
    buffer.writeln('Assigned Printer: $_fullPrinterWithHardwareTag');
    buffer.writeln('Release OTP: ${_getResolvedOtpCode()}');
    buffer.writeln('Total Pages: ${order.totalPages}');
    buffer.writeln('Total Amount Paid: ${order.formattedAmount}');
    if (widget.paymentId != null) {
      buffer.writeln('Transaction ID: ${widget.paymentId}');
    }
    buffer.writeln('===================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt copied to clipboard.'),
        backgroundColor: AppTheme.success,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _printAnotherDocument() {
    _pollingTimer?.cancel();
    OrderRecoveryService().printAgain();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const UploadScreen()),
      (route) => false,
    );
  }

  Future<void> _handleCancelAndRefund() async {
    final refundAmount = _order?.formattedAmount ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order & Refund?'),
        content: Text(
          refundAmount.isNotEmpty
              ? 'Are you sure you want to cancel? Your release OTP will be permanently deactivated and $refundAmount will be refunded.'
              : 'Are you sure you want to cancel? Your release OTP will be permanently deactivated and your payment will be refunded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel & Refund'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      _pollingTimer?.cancel();
      await _apiService.cancelOrder(widget.orderId);
      OrderRecoveryService().clearAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled and refund initiated.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UploadScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('already cancelled') ||
            errStr.contains('already refunded') ||
            errStr.contains('refunded')) {
          OrderRecoveryService().clearAll();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const UploadScreen()),
            (route) => false,
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userError(
                e,
                fallback: 'Could not cancel order. It may already be printing.',
              ),
            ),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchOtpAndOrder();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        actions: const [HelpAction(), UserAction()],
        title: const Text('Order & Release'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
      ),
      body: _isLoading
          ? const UiLoadingView(message: 'Loading order details...')
          : _order == null && _errorMessage != null
          ? UiErrorView(message: _errorMessage!, onRetry: _fetchOtpAndOrder)
          : _order != null &&
                ['CANCELLED', 'REFUNDED'].contains(_order!.status.toUpperCase())
          ? UiDisabledView(
              title: 'Order ${_order!.status.toUpperCase()}',
              message: 'This order has been cancelled and refunded.',
              onAction: _printAnotherDocument,
              actionLabel: 'New Print Job',
            )
          : UiProcessingOverlay(
              isProcessing: _isCancelling || _isSubmittingPrinter,
              title: _isCancelling ? 'Cancelling Order' : 'Connecting Printer',
              message: _isCancelling
                  ? 'Processing cancellation...'
                  : 'Connecting to station...',
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error
                        if (_errorMessage != null) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 14),
                        ],

                        // 1. Payment confirmation
                        _buildPaymentSummary(),
                        const SizedBox(height: 14),

                        // 2. Printer selection (before lock - only when awaiting release)
                        if (!_isPrinterLocked &&
                            !_otpRevealed &&
                            _printStatus == 'WAITING') ...[
                          _buildPrinterSelector(),
                          const SizedBox(height: 14),
                        ],

                        // 3. OTP section (after lock - only when awaiting release, never when printing or completed)
                        if ((_otpRevealed || _isPrinterLocked) &&
                            _printStatus == 'WAITING') ...[
                          _buildOtpSection(),
                          const SizedBox(height: 14),
                        ],

                        // Cancel & Refund (only while waiting for release)
                        if (_printStatus == 'WAITING') ...[
                          Center(
                            child: TextButton.icon(
                              onPressed: _isCancelling
                                  ? null
                                  : _handleCancelAndRefund,
                              icon: const Icon(
                                Icons.cancel_outlined,
                                size: 16,
                                color: AppTheme.danger,
                              ),
                              label: Text(
                                _isCancelling
                                    ? 'Cancelling...'
                                    : 'Cancel Order & Request Refund',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.danger,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 4. Print progress (when printing/completed)
                        if (_printStatus != 'WAITING') ...[
                          _buildProgressSection(),
                          const SizedBox(height: 14),
                        ],

                        // 5. Steps guide
                        _buildStepsGuide(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.dangerSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dangerBorder),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(fontSize: 13, color: AppTheme.danger),
      ),
    );
  }

  // 1. Payment Summary
  Widget _buildPaymentSummary() {
    final order = _order;
    if (order == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successBorder),
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
                  'Payment Confirmed',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successSurface,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppTheme.successBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: AppTheme.success,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'PAID',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _receiptLine('Order', '#${order.id}'),
                _receiptLine(
                  'Amount',
                  '${order.currency} ${order.amount.toStringAsFixed(2)}',
                  valueStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
                _receiptLine('Pages', '${order.totalPages}'),
                if (widget.paymentId != null && widget.paymentId!.isNotEmpty)
                  _receiptLine('Transaction', widget.paymentId!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptLine(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  valueStyle ??
                  const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontFamily: 'monospace',
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 2. Printer Selection
  Widget _buildPrinterSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isPrinterLocked ? AppTheme.successBorder : AppTheme.border,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Printer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_isPrinterLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successSurface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppTheme.successBorder),
                    ),
                    child: const Text(
                      'Locked',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
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
              children: [
                if (_availablePrinters.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.print_disabled_outlined,
                          size: 36,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No Printers Found on this Station',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Printers configured by the administrator in the Admin Panel will appear here dynamically.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isWide = constraints.maxWidth > 400 && _availablePrinters.length > 1;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _availablePrinters.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final p = entry.value;
                          return SizedBox(
                            width: isWide ? (constraints.maxWidth - 12) / 2 : double.infinity,
                            child: _dynamicPrinterCard(
                              printer: p,
                              index: idx,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                const SizedBox(height: 14),
                // View OTP button
                GestureDetector(
                  onTap: _isSubmittingPrinter ? null : _viewOtp,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedPrinterName == null
                          ? AppTheme.surfaceSubtle
                          : AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedPrinterName == null
                            ? AppTheme.border
                            : AppTheme.primary,
                      ),
                    ),
                    child: _isSubmittingPrinter
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _selectedPrinterName == null
                                    ? 'Select a printer first'
                                    : 'Lock OTP',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedPrinterName == null
                                      ? AppTheme.textMuted
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dynamicPrinterCard({
    required Printer printer,
    required int index,
  }) {
    final name = printer.cupsQueueName;
    final isSelected = _selectedPrinterName == name;
    final isLocked = _isPrinterLocked;
    final accentColor = index % 2 == 0 ? AppTheme.primary : AppTheme.success;
    final tag = name.contains('_') ? name.split('_').last : (name.length > 8 ? name.substring(name.length - 6) : name);
    final isReady = printer.isAvailable;

    return GestureDetector(
      onTap: isLocked || !isReady
          ? null
          : () => setState(() => _selectedPrinterName = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isLocked
                    ? AppTheme.successSurface
                    : accentColor.withValues(alpha: 0.05))
              : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (isLocked ? AppTheme.successBorder : accentColor)
                : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.print_rounded,
                      size: 18,
                      color: isSelected
                          ? (isLocked ? AppTheme.success : accentColor)
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isReady ? AppTheme.success : AppTheme.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isLocked
                              ? AppTheme.successSurface
                              : accentColor.withValues(alpha: 0.1))
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? (isLocked ? AppTheme.success : accentColor)
                          : AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              printer.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(isReady ? (printer.state == 'BUSY' ? 'Busy' : 'Available') : printer.state.replaceAll('_', ' ').toLowerCase(),
              style: TextStyle(fontSize: 11, color: isReady ? AppTheme.success : AppTheme.danger)),
            const SizedBox(height: 2),
            Text(
              printer.model != null && printer.model!.isNotEmpty
                  ? printer.model!
                  : (printer.location != null && printer.location!.isNotEmpty ? printer.location! : 'Unit ${index + 1}'),
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? AppTheme.textSecondary : AppTheme.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (printer.supportsColor)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('Color', style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.w600)),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('B&W', style: TextStyle(fontSize: 9, color: Colors.black87, fontWeight: FontWeight.w600)),
                  ),
                if (printer.supportsDuplex)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('Duplex', style: TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 3. OTP Section
  Widget _buildOtpSection() {
    if (!_otpRevealed && !_isPrinterLocked) return const SizedBox.shrink();

    final otpStr = _getResolvedOtpCode();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Header with printer lock status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Release OTP',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Text(
                  'No expiry',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Printer lock indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: AppTheme.success,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _fullPrinterWithHardwareTag,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // OTP digit boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    final char = i < otpStr.length ? otpStr[i] : '-';
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 44,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          char,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Copy & share row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _copyToClipboard,
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Copy OTP',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showInvoicePreview,
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Invoice',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _shareReceipt,
                      child: Container(
                        height: 42,
                        width: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.share_rounded,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Progress Section
  Widget _buildProgressSection() {
    if (_printStatus == 'WAITING') return const SizedBox.shrink();

    final isCompleted = _printStatus == 'COMPLETED';
    final needsAttention = !isCompleted && _errorMessage != null;
    final isStopped = ['FAILED', 'REFUNDED', 'CANCELLED', 'EXPIRED'].contains(_printStatus);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? AppTheme.successBorder : AppTheme.primaryBorder,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.successSurface
                      : AppTheme.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.print_rounded,
                  color: isCompleted ? AppTheme.success : AppTheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompleted ? 'Print Complete' : (isStopped ? 'Order ${_printStatus.toLowerCase()}' : needsAttention ? 'Printing paused' : 'Printing...'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCompleted
                            ? AppTheme.success
                            : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      isCompleted
                          ? 'Collect your pages from $_friendlyPrinterName.'
                          : (isStopped || needsAttention ? (_errorMessage ?? 'Contact the attendant.') : 'Job running on $_friendlyPrinterName.'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _printProgress,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? AppTheme.success : AppTheme.primary,
              ),
            ),
          ),
          if (isCompleted) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _printAnotherDocument,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Print Another Document',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 5. Steps Guide
  Widget _buildStepsGuide() {
    final printerLabel = _selectedPrinterName != null
        ? 'the selected printer ($_selectedPrinterName)'
        : 'the station printer';

    const steps = [
      {
        'step': '1',
        'title': 'Walk to the kiosk terminal',
        'detail': 'Locate the Station 1 touchscreen.',
      },
      {
        'step': '2',
        'title': 'Enter the 6-digit OTP',
        'detail': 'Type the code and tap Print.',
      },
    ];

    final collectStep = {
      'step': '3',
      'title': 'Collect your pages',
      'detail': 'Pages output from $printerLabel.',
    };

    final allSteps = [...steps, collectStep];

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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              'How to collect',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(allSteps.length, (i) {
                final s = allSteps[i];
                final isLast = i == allSteps.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryBorder),
                        ),
                        child: Center(
                          child: Text(
                            s['step']!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
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
                              s['title']!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s['detail']!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
