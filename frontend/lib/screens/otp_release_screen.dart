import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../services/api_error.dart';
import '../services/api_service.dart';
import '../services/invoice_service.dart';
import '../widgets/workflow_stepper.dart';
import 'upload_screen.dart';

class OtpReleaseScreen extends StatefulWidget {
  final String orderId;
  final PrintOrder? order;
  final List<UploadedDocument>? documents;
  final List<DocumentPrintConfig>? configs;
  final String? paymentId;

  const OtpReleaseScreen({
    super.key,
    required this.orderId,
    this.order,
    this.documents,
    this.configs,
    this.paymentId,
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
  Timer? _countdownTimer;

  int _secondsLeft = 900; // 15 mins

  String? _selectedPrinterName;
  bool _isPrinterLocked = false;
  bool _isSubmittingPrinter = false;
  bool _otpRevealed = false;
  bool _isGeneratingInvoice = false;

  // 'WAITING', 'PRINTING', 'COMPLETED'
  String _printStatus = 'WAITING';
  double _printProgress = 0.0;

  static const String _kPrinter1Id = 'HP_LaserJet_400_M401dn_F36EC0';
  static const String _kPrinter2Id = 'Printer_2';

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
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startPolling({int intervalMs = 700}) {
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
      final order = await _apiService.getOrder(widget.orderId);
      final otp = await _apiService.getOrderOtp(widget.orderId);

      DateTime? expiry;
      if (otp.expiresAt.isNotEmpty) {
        try {
          expiry = DateTime.tryParse(
            otp.expiresAt.endsWith('Z') ? otp.expiresAt : '${otp.expiresAt}Z',
          );
        } catch (_) {}
      }
      final diff = expiry != null
          ? expiry.difference(DateTime.now()).inSeconds
          : 900;

      final existingPrinter = order.printSettings.toJson()['printer_name'] ??
          order.printSettings.toJson()['cups_printer_name'] ??
          otp.selectedPrinter;

      final isLocked = otp.printerSelectionLocked ||
          (order.printSettings.toJson()['printer_selection_locked'] == true);

      final statusUpper = order.status.toUpperCase();
      String currentPrintStatus = 'WAITING';
      double currentProgress = 0.0;
      if (statusUpper == 'PRINTING') {
        currentPrintStatus = 'PRINTING';
        currentProgress = 0.70;
      } else if (statusUpper == 'COMPLETED' || statusUpper == 'SUCCESS') {
        currentPrintStatus = 'COMPLETED';
        currentProgress = 1.0;
      }

      setState(() {
        _order = order;
        _otpData = otp;
        _secondsLeft = diff > 0 ? diff : 0;
        if (existingPrinter != null && existingPrinter.toString().isNotEmpty) {
          _selectedPrinterName = existingPrinter.toString();
        }
        _isPrinterLocked = isLocked && _selectedPrinterName != null;
        if (_isPrinterLocked) {
          _otpRevealed = true;
        }
        _printStatus = currentPrintStatus;
        _printProgress = currentProgress;
        _isLoading = false;
      });

      _startCountdown();
      _startPolling();
    } catch (e) {
      setState(() {
        _errorMessage = userError(e);
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _pollOrderStatus() async {
    try {
      final updated = await _apiService.getOrder(widget.orderId);
      final status = updated.status.toUpperCase();

      if (status == 'PRINTING' || status == 'RELEASED') {
        if (_printStatus != 'PRINTING') {
          setState(() {
            _printStatus = 'PRINTING';
            _printProgress = status == 'RELEASED' ? 0.40 : 0.75;
          });
          _startPolling(intervalMs: 400);
        }
      } else if (status == 'COMPLETED' || status == 'SUCCESS') {
        if (_printStatus != 'COMPLETED') {
          setState(() {
            _printStatus = 'COMPLETED';
            _printProgress = 1.0;
          });
          _pollingTimer?.cancel();
          _countdownTimer?.cancel();
        }
      }
    } catch (_) {}
  }

  String _formatTimer(int totalSecs) {
    if (totalSecs <= 0) return '00:00';
    final hours = totalSecs ~/ 3600;
    final minutes = (totalSecs % 3600) ~/ 60;
    final seconds = totalSecs % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard() {
    final otpStr = _otpData?.otpCode ?? '';
    if (otpStr.isEmpty) return;
    Clipboard.setData(ClipboardData(text: otpStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('OTP code copied to clipboard!'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF16A34A),
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

      final updatedOtp = await _apiService.getOrderOtp(widget.orderId);

      setState(() {
        _selectedPrinterName = printerName;
        _isPrinterLocked = true;
        _otpRevealed = true;
        _otpData = updatedOtp;
        _isSubmittingPrinter = false;
      });

      if (mounted) {
        final friendly = _selectedPrinterName == _kPrinter1Id
            ? 'HP LaserJet 400'
            : 'Secondary Printer';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('$friendly locked. OTP ready.'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF16A34A),
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
          content: Text('Please select a destination printer first.'),
          backgroundColor: Color(0xFFDC2626),
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

  Future<void> _downloadInvoice() async {
    final order = _order;
    if (order == null) return;
    setState(() => _isGeneratingInvoice = true);
    try {
      await InvoiceService.generateAndDownloadInvoice(
        order: order,
        configs: widget.configs,
        documents: widget.documents,
        paymentId: widget.paymentId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice downloaded successfully.'),
            backgroundColor: Color(0xFF15803D),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to generate invoice: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingInvoice = false);
    }
  }

  void _shareReceipt() {
    final order = _order;
    if (order == null) return;
    final buffer = StringBuffer();
    buffer.writeln('=== AUTONOMOUS PRINTER RECEIPT ===');
    buffer.writeln('Order ID: ${order.id}');
    buffer.writeln('Station ID: ${order.printServerId}');
    buffer.writeln('Status: PAID (Verified)');
    buffer.writeln('Assigned Printer: ${_selectedPrinterName == _kPrinter1Id ? 'HP LaserJet 400 M401dn' : 'Secondary Printer'}');
    buffer.writeln('Release OTP: ${_otpData?.otpCode ?? '------'}');
    buffer.writeln('Total Pages: ${order.totalPages}');
    buffer.writeln('Total Amount Paid: ${order.formattedAmount}');
    if (widget.paymentId != null) {
      buffer.writeln('Transaction ID: ${widget.paymentId}');
    }
    buffer.writeln('===================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt details copied to clipboard!'),
        backgroundColor: Color(0xFF15803D),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _printAnotherDocument() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const UploadScreen()),
      (route) => false,
    );
  }

  // 1. Payment Summary Card (Placed at the top)
  Widget _buildPaymentSummary() {
    final order = _order;
    if (order == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF16A34A),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      'PAID (Verified)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Order Reference', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
              Text('#${order.id}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount Paid', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
              Text(
                '${order.currency} ${order.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Document Volume', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
              Text('${order.totalPages} pages', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ],
          ),
          if (widget.paymentId != null && widget.paymentId!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Transaction ID', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                Text(widget.paymentId!, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: AppTheme.textPrimary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 2. Destination Printer Selection Card (Placed below Payment Summary)
  Widget _buildPrinterSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isPrinterLocked ? const Color(0xFF86EFAC) : AppTheme.border,
          width: _isPrinterLocked ? 1.5 : 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.print_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Destination Printer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _isPrinterLocked
                          ? 'Printer locked for this job.'
                          : 'Select a printer below, then tap View OTP.',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (_isPrinterLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 12, color: Color(0xFF166534)),
                      SizedBox(width: 4),
                      Text(
                        'LOCKED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Two Printer Options
          Row(
            children: [
              Expanded(
                child: _buildPrinterCard(
                  name: _kPrinter1Id,
                  title: 'HP LaserJet 400',
                  subtitle: 'Duplex • B&W • Fast',
                  trayLabel: 'Tray 1 • Standard',
                  icon: Icons.print_rounded,
                  accentColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPrinterCard(
                  name: _kPrinter2Id,
                  title: 'Secondary Printer',
                  subtitle: 'Color / Media',
                  trayLabel: 'Tray 2 • Special',
                  icon: Icons.color_lens_outlined,
                  accentColor: const Color(0xFF059669),
                ),
              ),
            ],
          ),

          // VIEW OTP BUTTON directly below the select of the printer
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isSubmittingPrinter
                ? null
                : () => _viewOtp(),
            icon: _isSubmittingPrinter
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    _isPrinterLocked ? Icons.visibility_rounded : Icons.lock_outline_rounded,
                    size: 18,
                  ),
            label: Text(
              _isSubmittingPrinter
                  ? 'Locking & Generating OTP...'
                  : (_selectedPrinterName == null
                      ? 'Select Printer to View OTP'
                      : (_isPrinterLocked
                          ? 'View Release OTP'
                          : 'View OTP (${_selectedPrinterName == _kPrinter1Id ? 'HP LaserJet 400' : 'Secondary Printer'})')),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedPrinterName == null
                  ? Colors.grey.shade400
                  : AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterCard({
    required String name,
    required String title,
    required String subtitle,
    required String trayLabel,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _selectedPrinterName == name;
    final isLocked = _isPrinterLocked;

    return InkWell(
      onTap: isLocked
          ? null
          : () {
              setState(() {
                _selectedPrinterName = name;
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isLocked ? const Color(0xFFF0FDF4) : accentColor.withValues(alpha: 0.06))
              : (isLocked ? const Color(0xFFF8FAFC) : AppTheme.surfaceSubtle),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isLocked ? const Color(0xFF16A34A) : accentColor)
                : (isLocked ? const Color(0xFFE2E8F0) : AppTheme.border),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isLocked ? const Color(0xFF16A34A) : accentColor)
                        : AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : AppTheme.border,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
                if (isSelected)
                  Icon(
                    isLocked ? Icons.lock_rounded : Icons.check_circle_rounded,
                    color: isLocked ? const Color(0xFF16A34A) : accentColor,
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. OTP Section (Displayed once printer is confirmed and View OTP is clicked)
  Widget _buildOtpSection() {
    if (!_otpRevealed && !_isPrinterLocked) {
      return const SizedBox.shrink();
    }

    final otpStr = _otpData?.otpCode ?? '------';
    final targetPrinterTitle = _selectedPrinterName == _kPrinter1Id
        ? 'HP LaserJet 400 M401dn'
        : 'Secondary Printer';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF166534)),
                const SizedBox(width: 8),
                Text(
                  'Locked to $targetPrinterTitle',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'YOUR 6-DIGIT RELEASE OTP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 14),

          // Stylized individual digit boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              6,
              (i) {
                final char = i < otpStr.length ? otpStr[i] : '-';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 44,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      char,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Copy Code & Timer (Wrapped for responsive mobile alignment)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Copy Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warningSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, size: 15, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Text(
                      _secondsLeft <= 0 ? 'Expired' : 'Expires in ${_formatTimer(_secondsLeft)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Invoice Download and Share Receipt Options
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingInvoice ? null : _downloadInvoice,
                  icon: _isGeneratingInvoice
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareReceipt,
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    minimumSize: const Size.fromHeight(42),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Live Printing Progress & Completion Card
  Widget _buildProgressCard() {
    if (_printStatus == 'WAITING') {
      return const SizedBox.shrink();
    }

    final targetPrinterTitle = _selectedPrinterName == _kPrinter1Id
        ? 'HP LaserJet 400 M401dn'
        : 'Secondary Printer';

    final isCompleted = _printStatus == 'COMPLETED';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
          width: 1.5,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.print_rounded,
                  color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompleted ? 'Print Completed!' : 'Printing In Progress...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isCompleted ? const Color(0xFF166534) : const Color(0xFF1E40AF),
                      ),
                    ),
                    Text(
                      isCompleted
                          ? 'Please collect your printed document from $targetPrinterTitle.'
                          : 'Pages currently printing on $targetPrinterTitle.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _printProgress,
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
              ),
            ),
          ),

          // "Print Another Document" button only shown after success print!
          if (isCompleted) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _printAnotherDocument,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Print Another Document',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 5. Kiosk Instructions Guide
  Widget _buildInstructions() {
    final targetPrinterTitle = _selectedPrinterName == _kPrinter1Id
        ? 'HP LaserJet 400'
        : 'Secondary Printer';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to Release Your Print Job',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            step: '1',
            title: 'Walk to the Kiosk Terminal',
            subtitle: 'Locate Station 1 touchscreen terminal.',
          ),
          const SizedBox(height: 10),
          _buildInstructionStep(
            step: '2',
            title: 'Enter 6-Digit OTP',
            subtitle: 'Type the code on the screen and tap Print Document.',
          ),
          const SizedBox(height: 10),
          _buildInstructionStep(
            step: '3',
            title: 'Collect Pages from $targetPrinterTitle',
            subtitle: 'Your physical pages output immediately from the locked printer tray.',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep({
    required String step,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
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
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Order & Release'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 4),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.dangerSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.danger.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppTheme.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // 1. Payment Summary Card (Placed at the top)
                            _buildPaymentSummary(),

                            // 2. Destination Printer Selection Card (Only shown before printer is locked)
                            if (!_isPrinterLocked && !_otpRevealed) ...[
                              const SizedBox(height: 16),
                              _buildPrinterSelector(),
                            ],

                            // 3. OTP Section with Download Invoice & Share Receipt options (Revealed once locked)
                            if (_otpRevealed || _isPrinterLocked) ...[
                              const SizedBox(height: 16),
                              _buildOtpSection(),
                            ],

                            if (_printStatus != 'WAITING') ...[
                              const SizedBox(height: 16),
                              // 4. Live Printing Progress & Completion Card (shows Print Another Document on complete)
                              _buildProgressCard(),
                            ],

                            const SizedBox(height: 16),

                            // 5. Instructions Step Guide
                            _buildInstructions(),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
