import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_error.dart';

import 'package:file_picker/file_picker.dart';

import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/print_server.dart';
import '../services/api_service.dart';
import '../services/document_bytes_cache.dart';
import '../utils/download_helper.dart';
import '../widgets/workflow_stepper.dart';
import '../widgets/server_config_dialog.dart';
import 'print_options_screen.dart';


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
        _uploadError = null;
      });
    } catch (e) {
      // Auto-fallback: attempt to find reachable backend URL among known candidates
      final recovered = await _apiService.probeAndSwitchWorkingBackend();
      if (recovered) {
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
    final apkUrl = '${ApiConfig.baseUrl}/downloads/autonomous-printer.apk';
    try {
      final uri = Uri.parse(apkUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        triggerUrlDownload(apkUrl, filename: 'autonomous-printer.apk');
      }
    } catch (_) {
      triggerUrlDownload(apkUrl, filename: 'autonomous-printer.apk');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.download_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Downloading APK...'),
          ],
        ),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1E293B),
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
          IconButton(
            onPressed: _downloadApk,
            icon: const Icon(
              Icons.download_rounded,
              color: AppTheme.textPrimary,
              size: 22,
            ),
            tooltip: 'Download APK',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: _showServerConfigDialog,
              icon: Icon(
                ApiConfig.isTunneled ? Icons.cloud_done_rounded : Icons.dns_rounded,
                size: 14,
                color: Colors.white,
              ),
              label: Text(
                ApiConfig.isTunneled ? 'Cloudflare' : 'Server',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ApiConfig.isTunneled ? const Color(0xFF16A34A) : AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
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
          const WorkflowStepper(currentStep: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.danger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.cloud_off_rounded,
                                    color: AppTheme.danger,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _uploadError!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
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
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        setState(() => _uploadError = null);
                                        await _loadStations();
                                      },
                                      icon: const Icon(Icons.refresh_rounded, size: 14),
                                      label: const Text('Retry Connection', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.danger,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _showServerConfigDialog,
                                      icon: const Icon(Icons.settings_ethernet_rounded, size: 14),
                                      label: const Text('Server Settings', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.danger,
                                        side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.5)),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Station Live Hardware Status
                      // Dropzone Card
                      _buildDropzoneCard(),

                      // Upload progress — visible when uploading
                      
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

                      const SizedBox(height:12),
                      _buildHowItWorks(),
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


  Widget _buildStationStatusCard() {
    final station = _selectedStation;
    final isOnline = station == null || station.status.toLowerCase() == 'online';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? const Color(0xFF86EFAC) : AppTheme.border,
          width: 1.2,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFFDCFCE7) : AppTheme.surfaceSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.print_rounded,
              size: 18,
              color: isOnline ? const Color(0xFF16A34A) : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      station?.name ?? 'Station 1 · Autonomous Kiosk',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isOnline ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'HP LaserJet 400 (B&W) & Color Ready · A4 Paper Loaded',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Column(
            children: [
              // Custom Upload Icon Container
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 86,
                    height: 86,
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
                    width: 64,
                    height: 64,
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
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Drop your files here, or browse',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Supports multi-page documents and image files',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              // Browse Files Button
              ElevatedButton(
                onPressed: _isUploading ? null : _pickFiles,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 13,
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Format Chips & Size Limit
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildFormatPill('PDF', Icons.picture_as_pdf_outlined),
                  _buildFormatPill('PNG', Icons.image_outlined),
                  _buildFormatPill('JPG', Icons.photo_outlined),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How It Works',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStepPill('1', 'Upload', 'Select Files'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textMuted),
              ),
              _buildStepPill('2', 'Pay', 'Pay online'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textMuted),
              ),
              _buildStepPill('3', 'Print', 'Enter OTP'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepPill(String num, String title, String subtitle) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    num,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTransparentPricing() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sell_outlined, size: 16, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Transparent Self-Service Rates',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildPriceChip('Black & White', '₹2.00 / page', Icons.format_color_reset_rounded),
              _buildPriceChip('Full Color', '₹5.00 / page', Icons.color_lens_rounded),
              _buildPriceChip('Auto-Duplex', 'Available', Icons.flip_rounded),
              _buildPriceChip('Instant Payment', 'UPI / Card', Icons.bolt_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
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
