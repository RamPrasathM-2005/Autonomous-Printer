import '../widgets/print_action_bar.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/help_action.dart';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/document.dart';
import '../services/api_error.dart';
import '../services/api_service.dart';
import '../services/document_bytes_cache.dart';
import '../widgets/real_document_preview.dart';
import 'document_editor_screen.dart';
import 'order_summary_screen.dart';
import '../widgets/ui_state.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

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
  bool _isDragging = false;
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
          content: Text('At least one document is required.'),
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

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (_isUploadingMore || files.isEmpty) return;

    setState(() {
      _isUploadingMore = true;
      _errorMessage = null;
    });

    try {
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

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = userError(e, fallback: 'Failed to add dropped file.');
        });
      }
    } finally {
      if (mounted) setState(() => _isUploadingMore = false);
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
    return AppScaffold(
      appBar: AppBar(
        actions: const [HelpAction()],
        title: const Text('Print Settings'),
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
      ),
      body: UiProcessingOverlay(
        isProcessing: _isUploadingMore,
        title: 'Uploading Document',
        message: 'Adding file to print job...',
        child: DropTarget(
          onDragEntered: (detail) => setState(() => _isDragging = true),
          onDragExited: (detail) => setState(() => _isDragging = false),
          onDragDone: (detail) async {
            setState(() => _isDragging = false);
            await _handleDroppedFiles(detail.files);
          },
          child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag indicator banner
                    if (_isDragging) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primary, width: 2),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.file_download_rounded, color: AppTheme.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Drop files to add',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Error Banner
                    if (_errorMessage != null) ...[
                      _buildErrorBanner(),
                      const SizedBox(height: 12),
                    ],

                    // Global Settings
                    _buildGlobalSettingsCard(),
                    const SizedBox(height: 16),

                    // Documents header + add button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${_configs.length} Document${_configs.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: _isUploadingMore ? null : _pickMoreFiles,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.border),
                              borderRadius: BorderRadius.circular(8),
                              color: AppTheme.surfaceWhite,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isUploadingMore)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: AppTheme.primary,
                                    ),
                                  )
                                else
                                  const Icon(Icons.add_rounded,
                                      size: 14, color: AppTheme.primary),
                                          Text(
                                  _isUploadingMore ? 'Adding...' : 'Add file',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Document list
                    _buildDocumentList(constraints.maxWidth),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
    ),
      // Bottom bar
      bottomNavigationBar: _buildBottomBar(),
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
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 15, color: AppTheme.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: AppTheme.danger),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close_rounded,
                size: 15, color: AppTheme.danger),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalSettingsCard() {
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Default Settings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                if (isWide) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildColorToggle()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildCopiesField()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildPaperSizeField()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildOrientationToggle()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSidesToggle()),
                        ],
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildColorToggle(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildCopiesField()),
                        const SizedBox(width: 10),
                        Expanded(child: _buildPaperSizeField()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildOrientationToggle(),
                    const SizedBox(height: 12),
                    _buildSidesToggle(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings Controls ────────────────────────────────────────────────────

  Widget _buildColorToggle() {
    return _settingGroup(
      label: 'Color',
      child: Row(
        children: [
          Expanded(
            child: _togglePill(
              label: 'B&W',
              selected: !_globalIsColor,
              onTap: () => _updateGlobalSetting(() => _globalIsColor = false),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _togglePill(
              label: 'Color',
              selected: _globalIsColor,
              onTap: () => _updateGlobalSetting(() => _globalIsColor = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopiesField() {
    return _settingGroup(
      label: 'Copies',
      child: _copiesCounter(
        value: _globalCopies,
        onDecrement: _globalCopies > 1
            ? () => _updateGlobalSetting(() => _globalCopies--)
            : null,
        onIncrement: _globalCopies < 100
            ? () => _updateGlobalSetting(() => _globalCopies++)
            : null,
      ),
    );
  }

  Widget _buildPaperSizeField() {
    return _settingGroup(
      label: 'Paper',
      child: _dropdownField<String>(
        value: _globalPaperSize,
        items: const ['A4', 'Letter', 'Legal'],
        onChanged: (val) {
          if (val != null) _updateGlobalSetting(() => _globalPaperSize = val);
        },
      ),
    );
  }

  Widget _buildOrientationToggle() {
    return _settingGroup(
      label: 'Orientation',
      child: Row(
        children: [
          Expanded(
            child: _togglePill(
              label: 'Portrait',
              selected: _globalOrientation == 'portrait',
              onTap: () => _updateGlobalSetting(() => _globalOrientation = 'portrait'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _togglePill(
              label: 'Landscape',
              selected: _globalOrientation == 'landscape',
              onTap: () => _updateGlobalSetting(() => _globalOrientation = 'landscape'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidesToggle() {
    return _settingGroup(
      label: 'Sides',
      child: Row(
        children: [
          Expanded(
            child: _togglePill(
              label: '1-Sided',
              selected: _globalSides == 'one-sided',
              onTap: () => _updateGlobalSetting(() => _globalSides = 'one-sided'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _togglePill(
              label: '2-Sided',
              selected: _globalSides != 'one-sided',
              onTap: () => _updateGlobalSetting(() => _globalSides = 'two-sided-long-edge'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingGroup({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }

  Widget _togglePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySurface : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _copiesCounter({
    required int value,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: SizedBox(
              width: 32,
              child: Icon(
                Icons.remove_rounded,
                size: 14,
                color: onDecrement != null ? AppTheme.textSecondary : AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: SizedBox(
              width: 32,
              child: Icon(
                Icons.add_rounded,
                size: 14,
                color: onIncrement != null ? AppTheme.textSecondary : AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownField<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text('$item'),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDocumentList(double maxWidth) {
    return Column(
      children: List.generate(_configs.length, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index < _configs.length - 1 ? 8 : 0),
          child: _buildDocumentRow(_configs[index], index),
        );
      }),
    );
  }

  Widget _buildDocumentRow(DocumentPrintConfig c, int index) {
    final doc = c.document;
    final hasCustom = c.hasCustomSettings;

    return GestureDetector(
      onTap: () => _openDocumentEditor(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasCustom ? AppTheme.primaryBorder : AppTheme.border,
            width: hasCustom ? 1.5 : 1,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 32,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: RealDocumentPreview(
                document: doc,
                isThumbnail: true,
              ),
            ),
            const SizedBox(width: 12),

            // Name + specs
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.filename,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 5, runSpacing: 5,
                    children: [
                      _specPill(c.isColor ? 'Color' : 'B&W'),
                      _specPill('${c.copies}x'),
                      _specPill(c.paperSize),
                      if (hasCustom) ...[
                          _specPill('Custom', highlighted: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Quick controls
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Price
                Text(
                  '₹${c.estimatedCost.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // quick copies stepper
                    GestureDetector(
                      onTap: c.copies > 1 ? () => _updateDocumentCopies(index, -1) : null,
                      child: Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 16,
                        color: c.copies > 1 ? AppTheme.textSecondary : AppTheme.textMuted,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        '${c.copies}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _updateDocumentCopies(index, 1),
                      child: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 6),

            // Remove
            GestureDetector(
              onTap: () => _removeDocument(index),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 15, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specPill(String label, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted ? AppTheme.primarySurface : AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlighted ? AppTheme.primaryBorder : AppTheme.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: highlighted ? AppTheme.primary : AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildBottomBar() => PrintActionBar(
    details: '${_configs.length} files \u00b7 $_totalCalculatedPages pages',
    amount: '\u20b9${_totalEstimatedTotal.toStringAsFixed(2)}',
    action: 'Continue',
    onPressed: _continueToSummary,
  );
}
