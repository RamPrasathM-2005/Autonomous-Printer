import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/document.dart';
import '../services/api_error.dart';
import '../services/api_service.dart';
import '../services/document_bytes_cache.dart';
import '../widgets/real_document_preview.dart';
import '../widgets/workflow_stepper.dart';
import 'document_editor_screen.dart';
import 'order_summary_screen.dart';

class PrintOptionsScreen extends StatefulWidget {
  final List<UploadedDocument> documents;
  final String selectedStationId;

  PrintOptionsScreen({
    super.key,
    List<UploadedDocument>? documents,
    UploadedDocument? document,
    this.selectedStationId = 'PRINT-SERVER-001',
  }) : documents = documents ?? (document != null ? [document] : []);

  UploadedDocument get primaryDocument => documents.isNotEmpty
      ? documents.first
      : UploadedDocument(
          documentId: 'doc-default',
          originalFilename: 'document.pdf',
          pages: 1,
          size: 0,
          status: 'UPLOADED',
        );

  @override
  State<PrintOptionsScreen> createState() => _PrintOptionsScreenState();
}

class _PrintOptionsScreenState extends State<PrintOptionsScreen> {
  final ApiService _apiService = ApiService();

  late List<DocumentPrintConfig> _configs;

  // Global Print Settings (applied by default to all non-customized documents)
  String _globalPaperSize = 'A4';
  bool _globalIsColor = false;
  int _globalCopies = 1;
  String _globalOrientation = 'portrait';
  String _globalSides = 'one-sided';

  bool _isUploadingMore = false;
  String? _errorMessage;

  static const List<String> _blockedExtensions = [
    'exe', 'bat', 'sh', 'js', 'vbs', 'ps1', 'jar', 'html', 'htm', 'php', 'py', 'rb', 'pl', 'cmd',
    'com', 'msi', 'scr', 'hta', 'cpl', 'msc', 'gadget', 'inf', 'reg', 'scf', 'vbe', 'wsf', 'wsh',
  ];

  @override
  void initState() {
    super.initState();
    final docs = widget.documents.isNotEmpty
        ? widget.documents
        : [widget.primaryDocument];
    _configs = docs
        .map(
          (d) => DocumentPrintConfig(
            document: d,
            copies: _globalCopies,
            isColor: _globalIsColor,
            paperSize: _globalPaperSize,
            orientation: _globalOrientation,
            sides: _globalSides,
            hasCustomSettings: false,
          ),
        )
        .toList();
  }

  void _applyGlobalSettingsToDefaults() {
    for (int i = 0; i < _configs.length; i++) {
      if (!_configs[i].hasCustomSettings) {
        _configs[i] = _configs[i].copyWith(
          copies: _globalCopies,
          isColor: _globalIsColor,
          paperSize: _globalPaperSize,
          orientation: _globalOrientation,
          sides: _globalSides,
        );
      }
    }
  }

  void _updateGlobalSetting(VoidCallback update) {
    setState(() {
      update();
      _applyGlobalSettingsToDefaults();
    });
  }


  void _toggleDocumentColor(int index) {
    setState(() {
      final current = _configs[index];
      _configs[index] = current.copyWith(
        isColor: !current.isColor,
        hasCustomSettings: true,
      );
    });
  }

  void _updateDocumentCopies(int index, int delta) {
    setState(() {
      final current = _configs[index];
      final newCopies = (current.copies + delta).clamp(1, 100);
      _configs[index] = current.copyWith(
        copies: newCopies,
        hasCustomSettings: true,
      );
    });
  }

  double get _totalEstimatedTotal {
    return _configs.fold(0.0, (sum, c) => sum + c.estimatedCost);
  }

  int get _totalCalculatedPages {
    return _configs.fold(0, (sum, c) => sum + (c.calculatedPages * c.copies));
  }

  int get _totalCopies {
    return _configs.fold(0, (sum, c) => sum + c.copies);
  }

  Future<void> _openDocumentEditor(int index) async {
    final result = await Navigator.push<DocumentPrintConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentEditorScreen(
          initialConfig: _configs[index],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _configs[index] = result;
      });
    }
  }

  void _removeDocument(int index) {
    if (_configs.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one document is required for printing.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _configs.removeAt(index);
    });
  }

  bool _isMagicBytesValid(Uint8List bytes, String filename) {
    if (bytes.length < 4) return false;
    final ext = filename.split('.').last.toLowerCase();
    if (ext == 'pdf') {
      return bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;
    }
    if (ext == 'jpg' || ext == 'jpeg') {
      return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    }
    if (ext == 'png') {
      return bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
    }
    return true;
  }

  Future<void> _pickMoreFiles() async {
    if (_isUploadingMore) return;

    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (files.isEmpty) return;

      setState(() {
        _isUploadingMore = true;
        _errorMessage = null;
      });

      for (final file in files) {
        final Uint8List rawBytes = await file.readAsBytes();

        if (rawBytes.isEmpty) {
          throw Exception('File "${file.name}" is empty or unreadable.');
        }

        final filename = file.name;
        final ext = filename.split('.').last.toLowerCase();

        if (_blockedExtensions.contains(ext)) {
          throw Exception('Executable or script files are strictly blocked.');
        }

        if (!_isMagicBytesValid(rawBytes, filename)) {
          throw Exception('File content for "$filename" does not match its format header.');
        }

        final uploadedDoc = await _apiService.uploadDocumentBytes(
          bytes: rawBytes,
          filename: filename,
        );
        DocumentBytesCache.put(uploadedDoc.id, rawBytes);

        _configs.add(
          DocumentPrintConfig(
            document: uploadedDoc,
            copies: _globalCopies,
            isColor: _globalIsColor,
            paperSize: _globalPaperSize,
            orientation: _globalOrientation,
            sides: _globalSides,
            hasCustomSettings: false,
          ),
        );
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = userError(e, fallback: 'Failed to add more files.');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingMore = false);
      }
    }
  }

  void _continueToSummary() {
    if (_configs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one document.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSummaryScreen(
          configs: _configs,
          selectedStationId: widget.selectedStationId,
          primaryDocument: _configs.first.document,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Print Configuration'),
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 2),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 840;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Error Banner
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, size: 16, color: Color(0xFFB91C1C)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 14, color: Color(0xFFB91C1C)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => setState(() => _errorMessage = null),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // 1. Global Print Settings Card
                          _buildGlobalSettingsCard(isWide),

                          // Single Add Files button placed directly below Global Settings card
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isUploadingMore ? null : _pickMoreFiles,
                                icon: _isUploadingMore
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.add_circle_outline_rounded, size: 18),
                                label: Text(
                                  _isUploadingMore ? 'Adding Files...' : '+ Add More Files',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  side: const BorderSide(color: AppTheme.primary, width: 1.2),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.04),
                                ),
                              ),
                            ),
                          ),

                          // 2. Section Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Uploaded Documents',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_configs.length}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                'Tap card to edit range',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 3. Responsive Document Cards Grid
                          _buildDocumentGrid(constraints.maxWidth),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Sticky Bottom Price & Continue Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          border: const Border(top: BorderSide(color: AppTheme.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_configs.length} docs · $_totalCalculatedPages pgs · $_totalCopies copies',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '₹${_totalEstimatedTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _continueToSummary,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text(
                  'Continue',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalSettingsCard(bool isWide) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: AppTheme.primary),
                  SizedBox(width: 6),
                  Text(
                    'Global Print Settings',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Applies to default docs',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isWide) ...[
            Row(
              children: [
                Expanded(child: _buildColorModeSelector()),
                const SizedBox(width: 12),
                Expanded(child: _buildCopiesCounter()),
                const SizedBox(width: 12),
                Expanded(child: _buildPaperSizeSelector()),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildOrientationSelector()),
                const SizedBox(width: 12),
                Expanded(child: _buildSidesSelector()),
              ],
            ),
          ] else ...[
            _buildColorModeSelector(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildCopiesCounter()),
                const SizedBox(width: 8),
                Expanded(child: _buildPaperSizeSelector()),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildOrientationSelector()),
                const SizedBox(width: 8),
                Expanded(child: _buildSidesSelector()),
              ],
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildColorModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Color Mode',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _buildSelectablePill(
                label: 'B&W (₹2)',
                icon: Icons.filter_b_and_w,
                isSelected: !_globalIsColor,
                onTap: () => _updateGlobalSetting(() => _globalIsColor = false),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildSelectablePill(
                label: 'Color (₹10)',
                icon: Icons.color_lens,
                isSelected: _globalIsColor,
                onTap: () => _updateGlobalSetting(() => _globalIsColor = true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCopiesCounter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Default Copies',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(8),
            color: AppTheme.surfaceSubtle,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 14),
                padding: EdgeInsets.zero,
                onPressed: _globalCopies > 1
                    ? () => _updateGlobalSetting(() => _globalCopies--)
                    : null,
              ),
              Expanded(
                child: Text(
                  '$_globalCopies',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 14),
                padding: EdgeInsets.zero,
                onPressed: _globalCopies < 100
                    ? () => _updateGlobalSetting(() => _globalCopies++)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaperSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paper Size',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(8),
            color: AppTheme.surfaceSubtle,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _globalPaperSize,
              isExpanded: true,
              style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
              items: const [
                DropdownMenuItem(value: 'A4', child: Text('A4')),
                DropdownMenuItem(value: 'Letter', child: Text('Letter')),
                DropdownMenuItem(value: 'Legal', child: Text('Legal')),
              ],
              onChanged: (val) {
                if (val != null) _updateGlobalSetting(() => _globalPaperSize = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrientationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Orientation',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _buildSelectablePill(
                label: 'Portrait',
                icon: Icons.stay_current_portrait,
                isSelected: _globalOrientation == 'portrait',
                onTap: () => _updateGlobalSetting(() => _globalOrientation = 'portrait'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildSelectablePill(
                label: 'Landscape',
                icon: Icons.stay_current_landscape,
                isSelected: _globalOrientation == 'landscape',
                onTap: () => _updateGlobalSetting(() => _globalOrientation = 'landscape'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSidesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Duplex / Sides',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _buildSelectablePill(
                label: '1-Sided',
                icon: Icons.looks_one_outlined,
                isSelected: _globalSides == 'one-sided',
                onTap: () => _updateGlobalSetting(() => _globalSides = 'one-sided'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildSelectablePill(
                label: '2-Sided',
                icon: Icons.looks_two_outlined,
                isSelected: _globalSides != 'one-sided',
                onTap: () => _updateGlobalSetting(() => _globalSides = 'two-sided-long-edge'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectablePill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentGrid(double maxWidth) {
    int crossAxisCount = 2;
    if (maxWidth >= 1000) {
      crossAxisCount = 4;
    } else if (maxWidth >= 600) {
      crossAxisCount = 3;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: maxWidth < 400 ? 0.96 : 0.92,
      ),
      itemCount: _configs.length,
      itemBuilder: (context, index) {
        return _buildDocumentCard(_configs[index], index);
      },
    );
  }

  Widget _buildDocumentCard(DocumentPrintConfig c, int index) {
    final doc = c.document;
    final hasCustom = c.hasCustomSettings;

    return InkWell(
      onTap: () => _openDocumentEditor(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCustom ? const Color(0xFF93C5FD) : AppTheme.border,
            width: hasCustom ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Status Badge & Delete Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasCustom
                        ? const Color(0xFFEFF6FF)
                        : AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: hasCustom
                          ? const Color(0xFFBFDBFE)
                          : AppTheme.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasCustom)
                        const Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(Icons.tune, size: 9, color: AppTheme.primary),
                        ),
                      Text(
                        hasCustom ? 'Custom' : 'Default',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: hasCustom
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _removeDocument(index),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(1),
                    child: Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Real Thumbnail Representation
            Center(
              child: SizedBox(
                width: 38,
                height: 44,
                child: RealDocumentPreview(
                  document: doc,
                  isThumbnail: true,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Filename
            Text(
              doc.filename,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),

            // Specs
            Text(
              '${c.pageRangeDescription} · ${c.copies}c',
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // Quick In-Card Toggle Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quick Color toggle chip
                InkWell(
                  onTap: () => _toggleDocumentColor(index),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.isColor ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: c.isColor ? const Color(0xFFBFDBFE) : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      c.isColor ? 'Color' : 'B&W',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: c.isColor ? const Color(0xFF1D4ED8) : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                // Quick Copies +/- stepper
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: c.copies > 1 ? () => _updateDocumentCopies(index, -1) : null,
                      child: const Icon(Icons.remove_circle_outline, size: 13, color: AppTheme.textSecondary),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        '${c.copies}c',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () => _updateDocumentCopies(index, 1),
                      child: const Icon(Icons.add_circle_outline, size: 13, color: AppTheme.primary),
                    ),
                  ],
                ),
                // Subtotal Price
                Text(
                  '₹${c.estimatedCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
