import '../widgets/app_scaffold.dart';
import '../widgets/help_action.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_error.dart';

import 'package:file_picker/file_picker.dart';

import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/print_server.dart';
import '../services/api_service.dart';
import '../services/document_bytes_cache.dart';
import '../services/order_recovery_service.dart';
import '../widgets/server_config_dialog.dart';
import 'otp_release_screen.dart';
import 'payment_screen.dart';
import 'print_options_screen.dart';
import 'print_progress_screen.dart';
import '../widgets/ui_state.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

// ---------------------------------------------------------------------------
// Security: dangerous extensions that must never be uploaded
// ---------------------------------------------------------------------------
const _kDangerousExtensions = [
  'exe',
  'bat',
  'sh',
  'js',
  'vbs',
  'ps1',
  'psm1',
  'psd1',
  'jar',
  'html',
  'htm',
  'php',
  'py',
  'rb',
  'pl',
  'cmd',
  'com',
  'msi',
  'dll',
  'scr',
  'hta',
  'wsf',
  'wsh',
];

/// Returns a non-null error string if the file fails security checks.
String? _validateFileBytes(String filename, List<int> bytes) {
  final ext = filename.contains('.')
      ? filename.split('.').last.toLowerCase()
      : '';

  const allowed = ['pdf', 'jpg', 'jpeg', 'png'];
  if (!allowed.contains(ext)) {
    if (_kDangerousExtensions.contains(ext)) {
      return '"$filename" is not allowed — potentially dangerous file type.';
    }
    return '"$filename" must be a PDF, JPG, or PNG file.';
  }

  if (bytes.length < 4) {
    return '"$filename" appears to be empty or corrupted.';
  }

  if (ext == 'pdf') {
    if (bytes[0] != 0x25 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x44 ||
        bytes[3] != 0x46) {
      return '"$filename" does not appear to be a valid PDF — content mismatch.';
    }
  } else if (ext == 'jpg' || ext == 'jpeg') {
    if (bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF) {
      return '"$filename" does not appear to be a valid JPEG image.';
    }
  } else if (ext == 'png') {
    if (bytes[0] != 0x89 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x4E ||
        bytes[3] != 0x47) {
      return '"$filename" does not appear to be a valid PNG image.';
    }
  }

  return null;
}

class SelectedDocItem {
  final String name;
  final int size;
  final List<int> bytes;
  bool isCompleted;
  String? error;

  SelectedDocItem({
    required this.name,
    required this.size,
    required this.bytes,
    this.isCompleted = false,
    this.error,
  });

  String get fileExtension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'DOC';
  }

  bool get isPdf => fileExtension == 'PDF';
  bool get isImage => ['JPG', 'JPEG', 'PNG'].contains(fileExtension);
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final OrderRecoveryService _orderRecovery = OrderRecoveryService();

  final List<SelectedDocItem> _selectedFiles = [];
  bool _isUploading = false;
  bool _isDragging = false;
  String _uploadStatusText = '';
  String? _uploadError;
  double _uploadProgress = 0.0;

  PrintServer? _selectedStation;
  List<PrintServer> _stations = [];
  bool _isLoadingStations = true;

  bool _isCheckingOrderRecovery = false;
  OrderRecoveryResult? _activeRecovery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRestoreExistingOrder();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Force-navigate only when UploadScreen is the topmost route.
      // If the user is already on PaymentScreen or OtpReleaseScreen, skip to
      // avoid pushing a duplicate screen on top of the existing one.
      final isTopRoute = ModalRoute.of(context)?.isCurrent ?? false;
      _checkAndRestoreExistingOrder(forceNavigate: isTopRoute);
    }
  }

  Future<void> _checkAndRestoreExistingOrder({bool forceNavigate = true}) async {
    if (_isCheckingOrderRecovery) return;
    setState(() => _isCheckingOrderRecovery = true);

    try {
      final recovery = await _orderRecovery.checkRecovery();
      if (!mounted) return;

      setState(() {
        // Only update _activeRecovery when we got a real response.
        // On a network error the result stage is 'none' but canUploadNew is true —
        // we intentionally do NOT clear _activeRecovery so any previously loaded
        // order banner stays visible until a successful check confirms the order is gone.
        if (!recovery.networkError) {
          _activeRecovery = recovery;
        }
        _isCheckingOrderRecovery = false;
      });

      // Warn the user when the backend is unreachable rather than silently
      // pretending there is no active order (which could hide a paid order).
      if (recovery.networkError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not reach the server. Check your connection — any active orders will resume once you reconnect.',
            ),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      if (!forceNavigate) return;

      if (recovery.stage == RecoveryStage.unpaid && recovery.order != null) {
        // Before routing to PaymentScreen, reconcile to catch the race condition
        // where Razorpay captured the payment but the verify API call didn't
        // complete before the user navigated away. If payment was actually captured,
        // route directly to OtpReleaseScreen instead of asking to pay again.
        final orderId = recovery.order!.id;
        OrderRecoveryResult updatedRecovery = recovery;
        try {
          await _apiService.reconcilePayment(orderId);
          // Re-check backend state after reconcile.
          final recheckRecovery = await _orderRecovery.checkRecovery();
          if (!recheckRecovery.networkError) {
            updatedRecovery = recheckRecovery;
            if (!recovery.networkError) {
              setState(() => _activeRecovery = updatedRecovery);
            }
          }
        } catch (_) {
          // Reconcile failed — proceed with original recovery result.
        }

        if (!mounted) return;

        if (updatedRecovery.stage == RecoveryStage.waitingOtp &&
            updatedRecovery.order != null) {
          // Payment was actually confirmed — go straight to OTP, never show payment again.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpReleaseScreen(
                orderId: updatedRecovery.order!.id,
                order: updatedRecovery.order!,
              ),
            ),
          ).then((_) {
            if (mounted) _checkAndRestoreExistingOrder(forceNavigate: false);
          });
        } else {
          // Genuinely unpaid — show payment screen.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentScreen(order: recovery.order!),
            ),
          ).then((_) {
            if (mounted) _checkAndRestoreExistingOrder(forceNavigate: false);
          });
        }
      } else if (recovery.stage == RecoveryStage.waitingOtp && recovery.order != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpReleaseScreen(
              orderId: recovery.order!.id,
              order: recovery.order!,
            ),
          ),
        ).then((_) {
          if (mounted) _checkAndRestoreExistingOrder(forceNavigate: false);
        });
      } else if (recovery.stage == RecoveryStage.printing && recovery.order != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PrintProgressScreen(
              orderId: recovery.order!.id,
              otp: '',
              printServerId: recovery.order!.printServerId,
            ),
          ),
        ).then((_) {
          if (mounted) _checkAndRestoreExistingOrder(forceNavigate: false);
        });
      } else if (recovery.stage == RecoveryStage.completed && recovery.order != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpReleaseScreen(
              orderId: recovery.order!.id,
              order: recovery.order!,
            ),
          ),
        ).then((_) {
          if (mounted) _checkAndRestoreExistingOrder(forceNavigate: false);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingOrderRecovery = false);
    }
  }

  Future<void> _handleCancelActiveOrder() async {
    final order = _activeRecovery?.order;
    if (order == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text(
          'Are you sure you want to cancel this unpaid order and start a new print job?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _apiService.cancelOrder(order.id);
      OrderRecoveryService().clearActiveOrder();
      if (!mounted) return;
      setState(() {
        _activeRecovery = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled. You can now start fresh.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userError(e, fallback: 'Could not cancel order. Try again.'),
            ),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      final stations = await _apiService.fetchPrintServers();
      if (!mounted) return;
      setState(() {
        _stations = stations;
        _selectedStation = null;
        if (stations.isNotEmpty) {
          _selectedStation = stations.firstWhere(
            (s) => s.status.toLowerCase() == 'online',
            orElse: () => stations.first,
          );
        }
        _isLoadingStations = false;
        _uploadError = null;
      });
    } catch (e) {
      final recovered = await _apiService.probeAndSwitchWorkingBackend();
      if (recovered) {
        try {
          final stations = await _apiService.fetchPrintServers();
          if (!mounted) return;
          setState(() {
            _stations = stations;
            _selectedStation = null;
            if (stations.isNotEmpty) {
              _selectedStation = stations.firstWhere(
                (s) => s.status.toLowerCase() == 'online',
                orElse: () => stations.first,
              );
            }
            _isLoadingStations = false;
            _uploadError = null;
          });
          return;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _isLoadingStations = false;
        _uploadError = userError(e, fallback: 'Unable to reach print server.');
      });
    }
  }

  Future<void> _showServerConfigDialog() async {
    final changed = await showServerConfigModal(context);
    if (changed == true && mounted) {
      setState(() {
        _uploadError = null;
      });
      await _loadStations();
    }
  }

  Future<void> _downloadApk() async {
    final apkUrl = '${ApiConfig.baseUrl}/api/downloads/apk';
    try {
      final uri = Uri.parse(apkUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(
          Uri.parse('/downloads/autonomous-printer.apk'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Starting APK download... Check your browser downloads.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int get _totalSizeBytes => _selectedFiles.fold(0, (sum, f) => sum + f.size);

  void _processRawFile({required String name, required Uint8List rawBytes}) {
    if (rawBytes.isEmpty) {
      setState(
        () => _uploadError = 'Cannot read "$name" — please try again.',
      );
      return;
    }

    final List<int> fileBytes = rawBytes;

    final secError = _validateFileBytes(name, fileBytes);
    if (secError != null) {
      setState(() => _uploadError = secError);
      return;
    }

    if (!_selectedFiles.any(
      (f) => f.name == name && f.size == fileBytes.length,
    )) {
      _selectedFiles.add(
        SelectedDocItem(
          name: name,
          size: fileBytes.length,
          bytes: fileBytes,
        ),
      );
    }
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (_isUploading || files.isEmpty) return;
    setState(() => _uploadError = null);

    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        _processRawFile(name: file.name, rawBytes: bytes);
      } catch (e) {
        setState(() => _uploadError = 'Unable to read "${file.name}".');
      }
    }
    setState(() {});
  }

  Future<void> _pickFiles() async {
    if (_activeRecovery != null && _activeRecovery!.hasActiveUnfinishedOrder) {
      if (_activeRecovery!.stage == RecoveryStage.unpaid) {
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Unpaid Order Exists'),
            content: const Text(
              'You have an unpaid order in progress. Would you like to resume payment or cancel it to start fresh?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('cancel'),
                child: const Text(
                  'Cancel & Start Fresh',
                  style: TextStyle(color: AppTheme.danger),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop('resume'),
                child: const Text('Resume Order'),
              ),
            ],
          ),
        );

        if (choice == 'resume') {
          _checkAndRestoreExistingOrder(forceNavigate: true);
          return;
        } else if (choice == 'cancel') {
          final order = _activeRecovery?.order;
          if (order != null) {
            try {
              await _apiService.cancelOrder(order.id);
            } catch (_) {}
          }
          OrderRecoveryService().clearActiveOrder();
          if (mounted) {
            setState(() => _activeRecovery = null);
          }
        } else {
          return;
        }
      } else {
        _checkAndRestoreExistingOrder(forceNavigate: true);
        return;
      }
    }

    setState(() {
      _uploadError = null;
    });

    try {
      // file_picker v13: pickFiles() returns List<PlatformFile> directly.
      // An empty list means the user dismissed the picker without selecting.
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      // User cancelled the picker — nothing to do.
      if (files.isEmpty) return;

      for (final file in files) {
        final Uint8List rawBytes = await file.readAsBytes();
        _processRawFile(name: file.name, rawBytes: rawBytes);
      }
      setState(() {});
    } catch (e) {
      setState(() {
        _uploadError = 'Unable to open this file. Choose another.';
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _clearAllFiles() {
    if (_isUploading) return;
    setState(() {
      _selectedFiles.clear();
      _uploadError = null;
    });
  }

  Future<void> _handleNext() async {
    if (_activeRecovery != null && _activeRecovery!.hasActiveUnfinishedOrder) {
      _checkAndRestoreExistingOrder(forceNavigate: true);
      return;
    }

    if (_selectedFiles.isEmpty) {
      setState(() {
        _uploadError = 'Select a document.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
      _uploadProgress = 0.0;
      for (final item in _selectedFiles) {
        item.isCompleted = false;
      }
    });

    try {
      final List<UploadedDocument> uploadedDocs = [];
      final total = _selectedFiles.length;

      for (int i = 0; i < total; i++) {
        final item = _selectedFiles[i];
        setState(() {
          _uploadStatusText = 'Uploading ${i + 1} of $total: ${item.name}';
          _uploadProgress = (i + 0.5) / total;
        });

        final doc = await _apiService.uploadDocumentBytes(
          bytes: item.bytes,
          filename: item.name,
        );
        DocumentBytesCache.put(doc.id, Uint8List.fromList(item.bytes));

        setState(() {
          item.isCompleted = true;
          _uploadProgress = (i + 1) / total;
        });

        uploadedDocs.add(doc);
      }

      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PrintOptionsScreen(
            documents: uploadedDocs,
            selectedStationId: _selectedStation?.id ?? 'PRINT-SERVER-001',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = userError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: _buildAppBar(),
      body: UiProcessingOverlay(
        isProcessing: _isUploading,
        title: 'Uploading Files',
        message: _uploadStatusText,
        progress: _uploadProgress,
        child: Column(
          children: [
            // Station status bar
            _buildStatusBar(),
            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Error banner
                        if (_uploadError != null) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 16),
                        ],

                        // Order Recovery banner
                        if (_activeRecovery != null && _activeRecovery!.hasActiveUnfinishedOrder) ...[
                          _buildActiveOrderBanner(),
                          const SizedBox(height: 16),
                        ] else if (_activeRecovery != null && _activeRecovery!.stage == RecoveryStage.completed) ...[
                          _buildCompletedOrderBanner(),
                          const SizedBox(height: 16),
                        ],


                        // Upload zone
                        _buildDropzone(),
                        const SizedBox(height: 20),

                        // File list
                        if (_selectedFiles.isNotEmpty) ...[_buildFileList()],

                        // Upload progress
                        if (_isUploading) ...[
                          const SizedBox(height: 16),
                          _buildUploadProgress(),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.surfaceWhite,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppTheme.border),
      ),
      titleSpacing: 16,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.jpg',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.print_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'Autonomous Printer',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (kIsWeb)
          IconButton(
            onPressed: _downloadApk,
            icon: const Icon(Icons.android_rounded, size: 20, color: Color(0xFF059669)),
            tooltip: 'Download Android App',
          ),
        const HelpAction(),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: PopupMenuButton<String>(
              tooltip: 'Check nearby stations',
              enabled: !_isLoadingStations,
              itemBuilder: (_) => _stations.isEmpty
                  ? [
                      const PopupMenuItem(
                        enabled: false,
                        value: '',
                        child: Text('No stations available'),
                      ),
                    ]
                  : _stations
                        .map(
                          (s) => PopupMenuItem<String>(
                            enabled: false,
                            value: s.id,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.print_outlined,
                                color: s.canAcceptJobs
                                    ? AppTheme.success
                                    : AppTheme.textMuted,
                              ),
                              title: Text(s.name),
                              subtitle: Text(
                                '${s.location} \u00b7 ${s.canAcceptJobs ? 'Available' : 'Unavailable'}',
                              ),
                            ),
                          ),
                        )
                        .toList(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.near_me_outlined,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _isLoadingStations
                            ? 'Loading stations...'
                            : 'Nearby stations',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: OutlinedButton(
              onPressed: _isUploading ? null : _showServerConfigDialog,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppTheme.surfaceWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                side: const BorderSide(color: AppTheme.primaryBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.dns_outlined, size: 15),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${ApiConfig.isTunneled ? 'Cloud' : 'Local'} connection',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildActiveOrderBanner() {
    final order = _activeRecovery?.order;
    if (order == null) return const SizedBox.shrink();

    final isUnpaid = _activeRecovery!.stage == RecoveryStage.unpaid;
    final isWaitingOtp = _activeRecovery!.stage == RecoveryStage.waitingOtp;
    final statusText = isUnpaid
        ? 'Awaiting Payment'
        : isWaitingOtp
            ? 'Ready to Release (OTP)'
            : 'Printing in Progress';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.pending_actions_rounded,
            color: AppTheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order in progress (#${order.id})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUnpaid) ...[
            OutlinedButton(
              onPressed: _handleCancelActiveOrder,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: const BorderSide(color: AppTheme.dangerBorder),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6),
          ],
          FilledButton(
            onPressed: () => _checkAndRestoreExistingOrder(forceNavigate: true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Resume',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedOrderBanner() {
    final order = _activeRecovery?.order;
    if (order == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.successSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.success,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.id} complete',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.totalPages} pages · ₹${order.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _checkAndRestoreExistingOrder(forceNavigate: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primaryBorder),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Receipt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () {
              _orderRecovery.printAgain();
              setState(() => _activeRecovery = null);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.success,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Print Again', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }


  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.dangerSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dangerBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.danger,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _uploadError!,
              style: const TextStyle(fontSize: 13, color: AppTheme.danger),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  setState(() => _uploadError = null);
                  await _loadStations();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.dangerBorder),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.danger,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _uploadError = null),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropzone() {
    return DropTarget(
      onDragEntered: (detail) => setState(() => _isDragging = true),
      onDragExited: (detail) => setState(() => _isDragging = false),
      onDragDone: (detail) async {
        setState(() => _isDragging = false);
        await _handleDroppedFiles(detail.files);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 400;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.all(isNarrow ? 20 : 28),
            decoration: BoxDecoration(
              color: _isDragging ? AppTheme.primarySurface : AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isDragging ? AppTheme.primary : AppTheme.border,
                width: _isDragging ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: _isDragging ? 0.12 : 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isDragging ? 'Drop Files Here' : 'Ready to Print?',
                  style: TextStyle(
                    fontSize: isNarrow ? 20 : 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: _isDragging ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickFiles,
                  icon: Icon(
                    _isDragging ? Icons.file_download_rounded : Icons.file_upload_outlined,
                    size: 22,
                  ),
                  label: Text(_isDragging ? 'Drop to Upload' : 'Upload File'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(isNarrow ? 54 : 64),
                    backgroundColor: _isDragging ? Colors.white : AppTheme.primarySurface,
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(
                      color: _isDragging ? AppTheme.primary : AppTheme.primaryBorder,
                      width: _isDragging ? 1.5 : 1.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isDragging
                      ? 'Release mouse to add files'
                      : 'Supported formats: PDF, JPG, PNG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDragging ? AppTheme.primary : AppTheme.textSecondary,
                    fontWeight: _isDragging ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedFiles.length} file${_selectedFiles.length == 1 ? '' : 's'} selected',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatFileSize(_totalSizeBytes),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                if (!_isUploading) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _clearAllFiles,
                    behavior: HitTestBehavior.opaque,
                    child: const Text(
                      'Clear all',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedFiles.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, index) {
            return _buildFileRow(_selectedFiles[index], index);
          },
        ),
      ],
    );
  }

  Widget _buildFileRow(SelectedDocItem file, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: file.isCompleted ? AppTheme.successBorder : AppTheme.border,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // File type indicator
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: file.isPdf
                      ? AppTheme.primarySurface
                      : AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: file.isPdf
                        ? AppTheme.primaryBorder
                        : AppTheme.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    file.fileExtension,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: file.isPdf
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      letterSpacing: 0.5,
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
                      file.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFileSize(file.size),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (file.isCompleted) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: _isUploading ? null : () => _removeFile(index),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: _isUploading ? AppTheme.border : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          if (_isUploading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: file.isCompleted ? 1.0 : null,
                minHeight: 3,
                backgroundColor: AppTheme.surfaceLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  file.isCompleted ? AppTheme.success : AppTheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryBorder),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _uploadStatusText,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${(_uploadProgress * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasFiles = _selectedFiles.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: const Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(
                children: [
                  // Status label — always shrinks, never wraps
                  Expanded(
                    child: Text(
                      hasFiles
                          ? '${_selectedFiles.length} ${_selectedFiles.length == 1 ? 'file' : 'files'} ready'
                          : 'No files selected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasFiles
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Cancel button — only when there are files
                  if (hasFiles && !_isUploading) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clearAllFiles,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // Continue / Upload button
                  GestureDetector(
                    onTap: (_selectedFiles.isEmpty || _isUploading)
                        ? null
                        : _handleNext,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: hasFiles && !_isUploading
                            ? AppTheme.primary
                            : AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasFiles && !_isUploading
                              ? AppTheme.primary
                              : AppTheme.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isUploading) ...[
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _isUploading ? 'Uploading' : 'Continue',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: hasFiles && !_isUploading
                                  ? Colors.white
                                  : AppTheme.textMuted,
                            ),
                          ),
                          if (!_isUploading) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: hasFiles
                                  ? Colors.white
                                  : AppTheme.textMuted,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
