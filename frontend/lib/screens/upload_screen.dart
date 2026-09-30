import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/print_server.dart';
import '../services/api_service.dart';
import '../widgets/workflow_stepper.dart';
import 'print_options_screen.dart';

class SelectedDocItem {
  final String name;
  final int size;
  final List<int> bytes;
  double progress; // 0.0 to 1.0
  bool isCompleted;
  String? error;

  SelectedDocItem({
    required this.name,
    required this.size,
    required this.bytes,
    this.progress = 1.0,
    this.isCompleted = true,
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

class _UploadScreenState extends State<UploadScreen> with SingleTickerProviderStateMixin {
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

  int get _totalSizeBytes => _selectedFiles.fold(0, (sum, f) => sum + f.size);

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
          final fileBytes = await file.readAsBytes();
          // Avoid duplicate file additions
          if (!_selectedFiles.any((f) => f.name == file.name && f.size == fileBytes.length)) {
            _selectedFiles.add(
              SelectedDocItem(
                name: file.name,
                size: fileBytes.length,
                bytes: fileBytes,
                progress: 1.0,
                isCompleted: true,
              ),
            );
          }
        }
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _uploadError = 'File selection notice: ${e.toString()}';
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
        _uploadError = 'Please select at least one document to proceed.';
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
          item.progress = 0.3;
          _uploadStatusText = 'Uploading ${i + 1} of ${_selectedFiles.length}: ${item.name}';
        });

        // Simulate upload progress steps visually
        await Future.delayed(const Duration(milliseconds: 150));
        setState(() {
          item.progress = 0.7;
        });

        final doc = await _apiService.uploadDocumentBytes(
          bytes: item.bytes,
          filename: item.name,
        );

        setState(() {
          item.progress = 1.0;
          item.isCompleted = true;
        });

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
            selectedStationId: _selectedStation?.id ?? 'PRINT-SERVER-001',
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
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.print_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'QwikPrint',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Autonomous Self-Service Kiosk',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadStations,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            tooltip: 'Refresh Kiosk Status',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 1),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kiosk Connection Banner
                      _buildStationCard(),

                      const SizedBox(height: 20),

                      // Section Title & File Count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Documents',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Upload your PDF or image files to start printing.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (_selectedFiles.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primarySurface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                              ),
                              child: Text(
                                '${_selectedFiles.length} file(s) selected',
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

                      // Error message banner
                      if (_uploadError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
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
                                icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.danger),
                                onPressed: () => setState(() => _uploadError = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Dropzone Card (Inspired by Image 1 & 2)
                      _buildDropzoneCard(),

                      const SizedBox(height: 24),

                      // Uploaded Files Progress Listing (Inspired by Image 1 & Image 2)
                      if (_selectedFiles.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'File Uploading Progress',
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
                          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedFiles.isEmpty
                                ? 'No documents selected'
                                : '${_selectedFiles.length} file(s) ready',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedFiles.isEmpty
                                ? 'Select PDF or images above'
                                : 'Total size: ${_formatFileSize(_totalSizeBytes)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: (_selectedFiles.isEmpty || _isUploading) ? null : _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          shadowColor: AppTheme.primary.withOpacity(0.4),
                        ),
                        child: _isUploading
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Uploading...', style: TextStyle(fontWeight: FontWeight.w700)),
                                ],
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Continue to Options',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                      ),
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

  Widget _buildStationCard() {
    final isOnline = _selectedStation?.status.toLowerCase() == 'online';
    return Container(
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
              color: isOnline ? AppTheme.successSurface : AppTheme.warningSurface,
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
                    Text(
                      _selectedStation?.name ?? 'Central Kiosk Station',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOnline ? AppTheme.successSurface : AppTheme.warningSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (isOnline ? 'ONLINE' : 'CONNECTING').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isOnline ? const Color(0xFF047857) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedStation?.location ?? 'Location: Main Campus Library Terminal #1',
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
    );
  }

  Widget _buildDropzoneCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.25),
          width: 2,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: _pickFiles,
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
                        color: AppTheme.primary.withOpacity(0.15),
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
                          color: AppTheme.primary.withOpacity(0.3),
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

              const Text(
                'Choose your file to upload',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Drag and drop or browse PDF, PNG, or JPG files',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Pink Accent Browse Button (Direct reference from Image 1 & Image 2)
              ElevatedButton(
                onPressed: _pickFiles,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent, // Rose/Pink accent from Reference Image 1
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  shadowColor: AppTheme.accent.withOpacity(0.4),
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

              const SizedBox(height: 16),

              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildFormatPill('PDF Document', Icons.picture_as_pdf_rounded, const Color(0xFFE11D48)),
                  _buildFormatPill('Images (JPG, PNG)', Icons.image_rounded, const Color(0xFF2563EB)),
                  _buildFormatPill('Up to 50 MB', Icons.check_circle_outline_rounded, const Color(0xFF059669)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatPill(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItemCard(SelectedDocItem file, int index) {
    final badgeColor = file.isPdf ? const Color(0xFFE11D48) : const Color(0xFF2563EB);
    final badgeIcon = file.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded;
    final percentInt = (file.progress * 100).toInt();

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
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withOpacity(0.2)),
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
                      '${_formatFileSize(file.size)} • ${file.fileExtension}',
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
                '$percentInt%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: file.isCompleted ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeFile(index),
                icon: const Icon(Icons.cancel_rounded, color: AppTheme.textMuted, size: 20),
                tooltip: 'Remove file',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar line (Reference Image 1 & Image 2)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: file.progress,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(
                file.isCompleted ? AppTheme.accent : AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
