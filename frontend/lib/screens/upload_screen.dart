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
    if (bytes[0] != 0x25 || bytes[1] != 0x50 ||
        bytes[2] != 0x44 || bytes[3] != 0x46) {
      return '"$filename" does not appear to be a valid PDF — content mismatch.';
    }
  } else if (ext == 'jpg' || ext == 'jpeg') {
    if (bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF) {
      return '"$filename" does not appear to be a valid JPEG image.';
    }
  } else if (ext == 'png') {
    if (bytes[0] != 0x89 || bytes[1] != 0x50 ||
        bytes[2] != 0x4E || bytes[3] != 0x47) {
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
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  final List<SelectedDocItem> _selectedFiles = [];
  bool _isUploading = false;
  String _uploadStatusText = '';
  String? _uploadError;
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
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (files.isNotEmpty) {
        for (final file in files) {
          final Uint8List rawBytes = await file.readAsBytes();

          if (rawBytes.isEmpty) {
            setState(
              () => _uploadError =
                  'Cannot read "${file.name}" — please try again.',
            );
            continue;
          }

          final List<int> fileBytes = rawBytes;

          final secError = _validateFileBytes(file.name, fileBytes);
          if (secError != null) {
            setState(() => _uploadError = secError);
            continue;
          }

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

  void _clearAllFiles() {
    if (_isUploading) return;
    setState(() {
      _selectedFiles.clear();
      _uploadError = null;
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
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: _buildAppBar(),
      body: Column(
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

                      // Upload zone
                      _buildDropzone(),
                      const SizedBox(height: 20),

                      // File list
                      if (_selectedFiles.isNotEmpty) ...[
                        _buildFileList(),
                      ],

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
          const Text(
            'Autonomous Printer',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        // Server connection button
        GestureDetector(
          onTap: _showServerConfigDialog,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(
                color: ApiConfig.isTunneled
                    ? AppTheme.successBorder
                    : AppTheme.border,
              ),
              borderRadius: BorderRadius.circular(8),
              color: ApiConfig.isTunneled
                  ? AppTheme.successSurface
                  : AppTheme.surfaceSubtle,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: ApiConfig.isTunneled
                        ? AppTheme.success
                        : AppTheme.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  ApiConfig.isTunneled ? 'Cloud' : 'Local',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ApiConfig.isTunneled
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Refresh
        _isLoadingStations
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              )
            : IconButton(
                onPressed: _loadStations,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.textMuted,
                  size: 18,
                ),
                tooltip: 'Refresh',
              ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildStatusBar() {
    final station = _selectedStation;
    final isOnline = station != null && station.status.toLowerCase() == 'online';

    if (_isLoadingStations) {
      return Container(
        height: 36,
        color: AppTheme.surfaceSubtle,
        alignment: Alignment.center,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textMuted),
            ),
            SizedBox(width: 8),
            Text(
              'Connecting to station...',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    if (station == null) return const SizedBox.shrink();

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isOnline ? AppTheme.successSurface : AppTheme.surfaceSubtle,
        border: Border(
          bottom: BorderSide(
            color: isOnline ? AppTheme.successBorder : AppTheme.border,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOnline ? AppTheme.success : AppTheme.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            isOnline
                ? '${station.name} · Ready'
                : '${station.name} · Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isOnline ? AppTheme.success : AppTheme.textMuted,
            ),
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
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _uploadError!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.danger,
              ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropzone() {
    return GestureDetector(
      onTap: _isUploading ? null : _pickFiles,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.border,
            width: 1.5,
            style: BorderStyle.solid,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            // Icon area — restrained, not theatrical
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryBorder),
              ),
              child: const Icon(
                Icons.upload_file_rounded,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select files to print',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'PDF, JPG, or PNG',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                'Browse Files',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
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
                        ),
                      ],
                    ),
                  ),
                  if (hasFiles && !_isUploading) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _clearAllFiles,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: (_selectedFiles.isEmpty || _isUploading)
                        ? null
                        : _handleNext,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 13,
                      ),
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
