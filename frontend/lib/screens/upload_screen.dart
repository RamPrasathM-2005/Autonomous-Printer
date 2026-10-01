import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/print_server.dart';
import '../services/api_service.dart';
import '../widgets/workflow_stepper.dart';
import '../widgets/server_config_dialog.dart';
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

  Future<void> _showServerConfigDialog() async {
    final confirmed = await showServerConfigModal(context);
    if (confirmed == true && mounted) {
      setState(() {
        _uploadError = null;
      });
      await _loadStations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/app_logo.jpg',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
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
                  Text(
                    'Self-Service Kiosk',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: _showServerConfigDialog,
              icon: const Icon(Icons.dns_rounded, size: 15, color: Colors.white),
              label: const Text(
                'Server',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 2),
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
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.textSecondary),
                  tooltip: 'Refresh Kiosk Status',
                ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Server Configuration & Connection Status Bar (Prominent in UI)
                      InkWell(
                        onTap: _showServerConfigDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.dns_rounded, size: 16, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CONNECTED BACKEND SERVER',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textMuted,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      ApiConfig.backendUrl,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                        fontFamily: 'monospace',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.tune_rounded, size: 13, color: AppTheme.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      'Configure Server',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

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
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _uploadStatusText.isNotEmpty ? _uploadStatusText : 'Uploading...',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showServerConfigDialog,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.dns_rounded, size: 20),
        label: const Text(
          'Server Config',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3),
        ),
        tooltip: 'Configure Backend Server / Tunnel URL',
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
