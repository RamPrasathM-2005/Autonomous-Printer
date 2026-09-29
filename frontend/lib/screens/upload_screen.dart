import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/print_server.dart';
import '../services/api_service.dart';
import '../widgets/workflow_stepper.dart';
import 'orders_history_screen.dart';
import 'print_options_screen.dart';
import 'settings_screen.dart';

class SelectedDocItem {
  final String name;
  final int size;
  final List<int> bytes;

  SelectedDocItem({
    required this.name,
    required this.size,
    required this.bytes,
  });
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ApiService _apiService = ApiService();

  final List<SelectedDocItem> _selectedFiles = [];
  bool _isUploading = false;
  String _uploadStatusText = '';
  String? _uploadError;

  PrintServer? _selectedStation;
  bool _isLoadingStations = true;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      final stations = await _apiService.fetchPrintServers();
      setState(() {
        if (stations.isNotEmpty) {
          _selectedStation = stations.firstWhere(
            (s) => s.status.toLowerCase() == 'online',
            orElse: () => stations.first,
          );
        }
        _isLoadingStations = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingStations = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int get _totalSizeBytes =>
      _selectedFiles.fold(0, (sum, f) => sum + f.size);

  Future<void> _pickFiles() async {
    setState(() {
      _uploadError = null;
    });

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (files.isNotEmpty) {
        for (final file in files) {
          final bytes = await file.readAsBytes();
          // Avoid duplicate additions
          if (!_selectedFiles.any((f) => f.name == file.name && f.size == bytes.length)) {
            _selectedFiles.add(
              SelectedDocItem(
                name: file.name,
                size: bytes.length,
                bytes: bytes,
              ),
            );
          }
        }
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _uploadError = 'File selection error: $e';
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
        _uploadError = 'Please select at least one document.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final List<UploadedDocument> uploadedDocs = [];

      for (int i = 0; i < _selectedFiles.length; i++) {
        final item = _selectedFiles[i];
        setState(() {
          _uploadStatusText =
              'Uploading document ${i + 1} of ${_selectedFiles.length}... (${item.name})';
        });

        final doc = await _apiService.uploadDocumentBytes(
          bytes: item.bytes,
          filename: item.name,
        );
        uploadedDocs.add(doc);
      }

      setState(() {
        _isUploading = false;
      });

      if (!mounted) return;

      // Navigate to Step 2: Print Settings with all uploaded documents
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PrintOptionsScreen(
            documents: uploadedDocs,
            selectedStationId: _selectedStation?.id ?? 'station-1',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.print_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'QwikPrint',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Autonomous Kiosk',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Order History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const OrdersHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const SettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 1),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Station status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedStation != null
                                ? 'Connected: ${_selectedStation!.name} (${_selectedStation!.location})'
                                : (_isLoadingStations
                                    ? 'Discovering nearby kiosk stations...'
                                    : 'Default Kiosk Station (Ready)'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Step 1: Select Documents',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add one or multiple PDFs and images.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedFiles.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_selectedFiles.length} file(s)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Upload Dropzone Card
                  InkWell(
                    onTap: _pickFiles,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 32, horizontal: 20),
                      decoration: BoxDecoration(
                        color: _selectedFiles.isNotEmpty
                            ? AppTheme.primarySurface
                            : AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedFiles.isNotEmpty
                              ? AppTheme.primary
                              : AppTheme.border,
                          width: _selectedFiles.isNotEmpty ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _selectedFiles.isNotEmpty
                                  ? AppTheme.primary
                                  : AppTheme.surfaceSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedFiles.isNotEmpty
                                  ? Icons.add_circle_outline
                                  : Icons.cloud_upload_outlined,
                              size: 28,
                              color: _selectedFiles.isNotEmpty
                                  ? Colors.white
                                  : AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _selectedFiles.isNotEmpty
                                ? '+ Tap to Add More Documents'
                                : 'Tap to Browse & Select PDF Files',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _selectedFiles.isNotEmpty
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Select multiple PDFs or images (Max 50MB per file)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Selected Documents List
                  if (_selectedFiles.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected Files (${_selectedFiles.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Total: ${_formatFileSize(_totalSizeBytes)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedFiles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final file = _selectedFiles[index];
                        final isPdf = file.name.toLowerCase().endsWith('.pdf');
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPdf
                                      ? const Color(0xFFFEF2F2)
                                      : AppTheme.primarySurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isPdf
                                      ? Icons.picture_as_pdf
                                      : Icons.image_outlined,
                                  color: isPdf
                                      ? const Color(0xFFDC2626)
                                      : AppTheme.primary,
                                  size: 20,
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
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
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
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: AppTheme.textMuted, size: 18),
                                tooltip: 'Remove file',
                                onPressed: () => _removeFile(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  if (_uploadError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.danger.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.danger, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _uploadError!,
                              style: const TextStyle(
                                  color: AppTheme.danger, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_selectedFiles.isNotEmpty && !_isUploading)
                          ? _handleNext
                          : null,
                      child: _isUploading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    _uploadStatusText.isNotEmpty
                                        ? _uploadStatusText
                                        : 'Uploading Documents...',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_selectedFiles.length > 1
                                    ? 'Continue with ${_selectedFiles.length} Documents'
                                    : 'Continue to Print Settings'),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 18),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
