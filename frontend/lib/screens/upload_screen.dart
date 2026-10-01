import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_error.dart';

import 'package:file_picker/file_picker.dart';

import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/print_server.dart';
import '../services/api_service.dart';
import '../services/document_bytes_cache.dart';
import 'print_options_screen.dart';

import 'payment_screen.dart';
import 'otp_release_screen.dart';
import 'print_progress_screen.dart';

// ---------------------------------------------------------------------------
// Security: dangerous extensions that must never be uploaded
// ---------------------------------------------------------------------------
const _kDangerousExtensions = [
  'exe', 'bat', 'sh', 'js', 'vbs', 'ps1', 'psm1', 'psd1',
  'jar', 'html', 'htm', 'php', 'py', 'rb', 'pl', 'cmd',
  'com', 'msi', 'dll', 'scr', 'hta', 'wsf', 'wsh',
];

/// Returns a non-null error string if the file fails security checks.
/// Checks:
///  1. Extension allowlist (pdf, jpg, jpeg, png)
///  2. Dangerous-extension blocklist
///  3. Magic-byte validation (PDF, JPEG, PNG)
String? _validateFileBytes(String filename, List<int> bytes) {
  final ext = filename.contains('.')
      ? filename.split('.').last.toLowerCase()
      : '';

  // 1 – Allowlist check
  const allowed = ['pdf', 'jpg', 'jpeg', 'png'];
  if (!allowed.contains(ext)) {
    if (_kDangerousExtensions.contains(ext)) {
      return '"$filename" is not allowed — potentially dangerous file type.';
    }
    return '"$filename" must be a PDF, JPG, or PNG file.';
  }

  // 2 – Magic-byte validation
  if (bytes.length < 4) {
    return '"$filename" appears to be empty or corrupted.';
  }

  if (ext == 'pdf') {
    // PDF magic: %PDF  (0x25 0x50 0x44 0x46)
    if (bytes[0] != 0x25 || bytes[1] != 0x50 ||
        bytes[2] != 0x44 || bytes[3] != 0x46) {
      return '"$filename" does not appear to be a valid PDF — content mismatch.';
    }
  } else if (ext == 'jpg' || ext == 'jpeg') {
    // JPEG magic: FF D8 FF
    if (bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF) {
      return '"$filename" does not appear to be a valid JPEG image.';
    }
  } else if (ext == 'png') {
    // PNG magic: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] != 0x89 || bytes[1] != 0x50 ||
        bytes[2] != 0x4E || bytes[3] != 0x47) {
      return '"$filename" does not appear to be a valid PNG image.';
    }
  }

  return null; // Passed all checks
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
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  final List<SelectedDocItem> _selectedFiles = [];
  bool _isUploading = false;
  String _uploadStatusText = '';
  String? _uploadError;
  // Track per-upload progress: 0.0 → 1.0 across all files
  double _uploadProgress = 0.0;

  PrintServer? _selectedStation;
  bool _isLoadingStations = true;

  Future<void> _resumeOrder() async {
    try {
      final orders = await _apiService.listOrders();
      if (!mounted) return;
      if (orders.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No orders yet.')));
        return;
      }
      final order = await showDialog<dynamic>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Your orders'),
          children: orders
              .map(
                (order) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, order),
                  child: Text(
                    '${order.currency} ${order.amount.toStringAsFixed(2)} - ${order.statusLabel}\n${order.id}',
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (order == null || !mounted) return;
      final Widget screen;
      if (order.status == 'CREATED') {
        screen = PaymentScreen(order: order);
      } else if (order.status == 'WAITING_FOR_OTP') {
        screen = OtpReleaseScreen(orderId: order.id);
      } else {
        screen = PrintProgressScreen(
          orderId: order.id,
          otp: '',
          printServerId: order.printServerId,
        );
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userError(e))));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      final stations = await _apiService.fetchPrintServers();
      if (!mounted) return;
      setState(() {
        if (stations.isNotEmpty) {
          _selectedStation = stations.firstWhere(
            (s) => s.status.toLowerCase() == 'online',
            orElse: () => stations.first,
          );
        }
        _isLoadingStations = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingStations = false;
        _uploadError = userError(e, fallback: 'Unable to reach print server.');
      });
    }
  }

  Future<void> _showServerConfigDialog() async {
    final controller = TextEditingController(text: ApiConfig.backendUrl);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dns_outlined, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Server Configuration',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the backend API server URL (IP or domain):',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'http://10.11.6.148:8000',
                labelText: 'Backend URL',
                labelStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: const TextStyle(fontSize: 13),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            const Text(
              'Quick Presets:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPresetChip('PC Wi-Fi (10.11.6.148)', 'http://10.11.6.148:8000', controller),
                _buildPresetChip('Localhost (127.0.0.1)', 'http://127.0.0.1:8000', controller),
                _buildPresetChip('Emulator (10.0.2.2)', 'http://10.0.2.2:8000', controller),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      final newUrl = controller.text.trim();
      await ApiConfig.updateBackendUrl(newUrl);
      if (mounted) {
        setState(() {
          _uploadError = null;
        });
        await _loadStations();
      }
    }
  }

  Widget _buildPresetChip(String label, String url, TextEditingController controller) {
    return InkWell(
      onTap: () => controller.text = url,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int get _totalSizeBytes => _selectedFiles.fold(0, (sum, f) => sum + f.size);

  Future<void> _pickFiles() async {
    setState(() {
      _uploadError = null;
    });

    try {
      // file_picker v13: static FilePicker.pickFiles() returns List<PlatformFile>
      // No allowMultiple param — the method inherently allows multi-select.
      // We use webOptions to pre-load bytes for the security check.
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (files.isNotEmpty) {
        for (final file in files) {
          // file_picker v13: PlatformFile has readAsBytes() method, not .bytes property
          final Uint8List rawBytes = await file.readAsBytes();

          if (rawBytes.isEmpty) {
            setState(
              () => _uploadError =
                  'Cannot read "${file.name}" — please try again.',
            );
            continue;
          }

          final List<int> fileBytes = rawBytes;

          // ── Security gate: validate before queuing ──────────────────────
          final secError = _validateFileBytes(file.name, fileBytes);
          if (secError != null) {
            setState(() => _uploadError = secError);
            continue; // Skip this file, process others
          }

          // Avoid exact duplicates (same name + same byte count)
          if (!_selectedFiles.any(
            (f) => f.name == file.name && f.size == fileBytes.length,
          )) {
            _selectedFiles.add(
              SelectedDocItem(
                name: file.name,
                size: fileBytes.length,
                bytes: fileBytes,
              ),
            );
          }
        }
        setState(() {});
      }

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

  Future<void> _handleNext() async {
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
          _uploadStatusText =
              'Uploading ${i + 1} of $total: ${item.name}';
          // Progress reflects completed files; current one counts as 50% done
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

      // Navigate to Step 2: Print Settings with all uploaded documents
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
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
        titleSpacing: 20,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.print_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Autonomous Printer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_apiService.hasSession)
            TextButton(
              onPressed: _resumeOrder,
              child: const Text('Your orders'),
            ),
          IconButton(
            onPressed: _showServerConfigDialog,
            icon: const Icon(
              Icons.dns_outlined,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            tooltip: 'Server Settings',
          ),
          _isLoadingStations
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _loadStations,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppTheme.textSecondary,
                  ),
                  tooltip: 'Refresh station',
                ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // WorkflowStepper removed — no top flow bar on any page
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Printer Station Banner
                      _buildStationCard(),

                      const SizedBox(height: 20),

                      // Section Title & File Count (always visible)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Documents',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          // File count badge — always visible
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedFiles.isEmpty
                                  ? AppTheme.surfaceSubtle
                                  : AppTheme.primarySurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _selectedFiles.isEmpty
                                    ? AppTheme.border
                                    : AppTheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.insert_drive_file_rounded,
                                  size: 13,
                                  color: _selectedFiles.isEmpty
                                      ? AppTheme.textMuted
                                      : AppTheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${_selectedFiles.length} file${_selectedFiles.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedFiles.isEmpty
                                        ? AppTheme.textMuted
                                        : AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Error message banner
                      if (_uploadError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.danger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppTheme.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _uploadError!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.danger,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppTheme.danger,
                                ),
                                onPressed: () =>
                                    setState(() => _uploadError = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Dropzone Card
                      _buildDropzoneCard(),

                      // Upload progress — visible when uploading
                      if (_isUploading) ...[
                        const SizedBox(height: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    _uploadStatusText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _uploadProgress,
                                minHeight: 8,
                                backgroundColor: AppTheme.primarySurface,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Uploaded Files Progress Listing (Inspired by Image 1 & Image 2)
                      if (_selectedFiles.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Selected files',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Total: ${_formatFileSize(_totalSizeBytes)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _selectedFiles.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, index) {
                            final file = _selectedFiles[index];
                            return _buildFileItemCard(file, index);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final summary = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedFiles.isEmpty
                                ? 'No documents selected'
                                : '${_selectedFiles.length} ${_selectedFiles.length == 1 ? 'file' : 'files'} ready',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedFiles.isEmpty
                                ? 'PDF, PNG or JPG'
                                : 'Total size: ${_formatFileSize(_totalSizeBytes)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      );
                      final action = ElevatedButton(
                        onPressed: (_selectedFiles.isEmpty || _isUploading)
                            ? null
                            : _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                        ),
                        child: _isUploading
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Uploading...',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Continue',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                      );
                      if (constraints.maxWidth < 440) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            summary,
                            const SizedBox(height: 12),
                            SizedBox(width: double.infinity, child: action),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: summary),
                          const SizedBox(width: 12),
                          action,
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

  Widget _buildStationCard() {
    final isOnline = _selectedStation?.status.toLowerCase() == 'online';
    return InkWell(
      onTap: _showServerConfigDialog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isOnline
                    ? AppTheme.successSurface
                    : AppTheme.warningSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.print_rounded,
                color: isOnline ? AppTheme.success : AppTheme.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _selectedStation?.name ?? 'Print Station',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? AppTheme.successSurface
                              : AppTheme.warningSurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (isOnline ? 'ONLINE' : 'CONNECTING').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isOnline
                                ? const Color(0xFF047857)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedStation?.location ?? (isOnline ? 'Available' : 'Tap to configure server IP'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOnline ? AppTheme.textSecondary : AppTheme.primary,
                      fontWeight: isOnline ? FontWeight.normal : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.tune_rounded,
              size: 16,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropzoneCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.25),
          width: 2,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: _isUploading ? null : _pickFiles,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          child: Column(
            children: [
              // Illustration / Custom Upload Icon Container (Inspired by Reference Images 1 & 2)
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        width: 2,
                      ),
                    ),
                  ),
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const SizedBox(height: 20),

              // Browse Files Button — pure blue/white, no accent color
              ElevatedButton(
                onPressed: _isUploading ? null : _pickFiles,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.35),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Browse Files',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),


            ],
          ),
        ),
      ),
    );
  }


  Widget _buildFileItemCard(SelectedDocItem file, int index) {
    // All file types use blue shades for consistent blue/white theme
    final badgeColor = file.isPdf ? AppTheme.primary : AppTheme.primaryLight;
    final badgeIcon = file.isPdf
        ? Icons.picture_as_pdf_rounded
        : Icons.image_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // File Type Badge Icon (Reference Image 1 & 2)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                ),
                child: Icon(badgeIcon, color: badgeColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatFileSize(file.size)} \u2022 ${file.fileExtension}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Percentage indicator text (Reference Image 1)
              Text(
                file.isCompleted ? 'Uploaded' : 'Selected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: file.isCompleted
                      ? AppTheme.accent
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isUploading ? null : () => _removeFile(index),
                icon: const Icon(
                  Icons.cancel_rounded,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
                tooltip: 'Remove file',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (_isUploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: file.isCompleted ? 1 : null,
                minHeight: 6,
                backgroundColor: AppTheme.surfaceSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(
                  file.isCompleted ? AppTheme.accent : AppTheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
