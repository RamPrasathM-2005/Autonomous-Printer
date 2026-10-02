import '../widgets/print_action_bar.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/help_action.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/document.dart';
import '../widgets/real_document_preview.dart';

class DocumentEditorScreen extends StatefulWidget {
  final DocumentPrintConfig initialConfig;

  const DocumentEditorScreen({
    super.key,
    required this.initialConfig,
  });

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late int _copies;
  late bool _isColor;
  late String _rangeOption;
  late String _customRange;
  late String _sides;
  late String _orientation;
  late String _paperSize;
  late TextEditingController _rangeController;

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _copies = c.copies;
    _isColor = c.isColor;
    _rangeOption = c.rangeOption;
    _customRange = c.customRange;
    _sides = c.sides;
    _orientation = c.orientation;
    _paperSize = c.paperSize;
    _rangeController = TextEditingController(text: _customRange);
  }

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  int get _calculatedPages {
    final total = widget.initialConfig.document.pages <= 0
        ? 1
        : widget.initialConfig.document.pages;
    if (_rangeOption == 'all') return total;
    if (_rangeOption == 'odd') return (total / 2).ceil();
    if (_rangeOption == 'even') return (total / 2).floor();
    if (_rangeOption == 'custom' && _customRange.trim().isNotEmpty) {
      try {
        int count = 0;
        final parts = _customRange.split(',');
        for (var part in parts) {
          part = part.trim();
          if (part.contains('-')) {
            final range = part.split('-');
            if (range.length == 2) {
              final start = int.parse(range[0].trim());
              final end = int.parse(range[1].trim());
              if (start <= end) {
                final validStart = start.clamp(1, total);
                final validEnd = end.clamp(1, total);
                if (validEnd >= validStart) {
                  count += (validEnd - validStart + 1);
                }
              }
            }
          } else if (part.isNotEmpty) {
            final page = int.parse(part);
            if (page >= 1 && page <= total) count++;
          }
        }
        return count > 0 ? count : total;
      } catch (_) {
        return total;
      }
    }
    return total;
  }

  double get _estimatedCost {
    final rate = _isColor ? 10.0 : 2.0;
    return _calculatedPages * _copies * rate;
  }

  void _saveSettings() {
    final updated = widget.initialConfig.copyWith(
      copies: _copies,
      isColor: _isColor,
      rangeOption: _rangeOption,
      customRange: _customRange.trim(),
      sides: _sides,
      orientation: _orientation,
      paperSize: _paperSize,
      hasCustomSettings: true,
    );
    Navigator.pop(context, updated);
  }

  void _resetToDefault() {
    final reset = widget.initialConfig.copyWith(
      copies: 1,
      isColor: false,
      rangeOption: 'all',
      customRange: '',
      sides: 'one-sided',
      orientation: 'portrait',
      paperSize: 'A4',
      hasCustomSettings: false,
    );
    Navigator.pop(context, reset);
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.initialConfig.document;
    final isLandscape = _orientation == 'landscape';

    return AppScaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
        title: Text(
          doc.filename,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          const HelpAction(),
          TextButton(
            onPressed: _resetToDefault,
            child: const Text(
              'Reset',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final previewHeight = constraints.maxWidth < 600 ? 220.0 : 300.0;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildPreviewCard(doc, isLandscape, previewHeight),
                  ),
                ),
                const VerticalDivider(width: 1, color: AppTheme.border),
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildControlsCard(),
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPreviewCard(doc, isLandscape, previewHeight),
                const SizedBox(height: 12),
                _buildControlsCard(),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildPreviewCard(UploadedDocument doc, bool isLandscape, double height) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isColor ? AppTheme.primarySurface : AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _isColor ? AppTheme.primaryBorder : AppTheme.border,
                    ),
                  ),
                  child: Text(
                    _isColor ? 'Color' : 'B&W',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _isColor ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // Preview area
          SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RealDocumentPreview(
                document: doc,
                isLandscape: isLandscape,
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // Metadata strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metaItem('Type', doc.isPdf ? 'PDF' : 'Image'),
                _dividerDot(),
                _metaItem('Size', doc.formattedSize),
                _dividerDot(),
                _metaItem('Pages', '$_calculatedPages / ${doc.pages}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _dividerDot() {
    return Container(
      width: 1,
      height: 20,
      color: AppTheme.border,
    );
  }

  Widget _buildControlsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Text(
              'Document Settings',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Page Range
                _sectionLabel('Page Range'),
                const SizedBox(height: 8),
                _buildRangeSelector(),
                if (_rangeOption == 'custom') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _rangeController,
                    decoration: InputDecoration(
                      hintText: 'e.g. 1-3, 5, 7-${widget.initialConfig.document.pages}',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceWhite,
                    ),
                    onChanged: (val) => setState(() => _customRange = val),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                const SizedBox(height: 18),

                // Color Mode
                _sectionLabel('Color Mode'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _choiceCard(
                        label: 'Black & White',
                        detail: '₹2.00 / page',
                        selected: !_isColor,
                        onTap: () => setState(() => _isColor = false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _choiceCard(
                        label: 'Full Color',
                        detail: '₹10.00 / page',
                        selected: _isColor,
                        onTap: () => setState(() => _isColor = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Copies & Paper
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Copies'),
                          const SizedBox(height: 8),
                          _copiesCounter(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Paper Size'),
                          const SizedBox(height: 8),
                          _paperSizeDropdown(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Orientation
                _sectionLabel('Orientation'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _miniChoice(
                        label: 'Portrait',
                        selected: _orientation == 'portrait',
                        onTap: () => setState(() => _orientation = 'portrait'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniChoice(
                        label: 'Landscape',
                        selected: _orientation == 'landscape',
                        onTap: () => setState(() => _orientation = 'landscape'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Sides
                _sectionLabel('Print Sides'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _miniChoice(
                        label: '1-Sided',
                        selected: _sides == 'one-sided',
                        onTap: () => setState(() => _sides = 'one-sided'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniChoice(
                        label: '2-Sided',
                        selected: _sides != 'one-sided',
                        onTap: () =>
                            setState(() => _sides = 'two-sided-long-edge'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildRangeSelector() {
    const options = [
      {'key': 'all', 'label': 'All'},
      {'key': 'odd', 'label': 'Odd'},
      {'key': 'even', 'label': 'Even'},
      {'key': 'custom', 'label': 'Custom'},
    ];

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: options.map((opt) {
          final isSelected = _rangeOption == opt['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _rangeOption = opt['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.surfaceWhite : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isSelected ? AppTheme.border : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _choiceCard({
    required String label,
    required String detail,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySurface : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppTheme.primary : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _copiesCounter() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _copies > 1 ? () => setState(() => _copies--) : null,
            child: SizedBox(
              width: 38,
              child: Icon(
                Icons.remove_rounded,
                size: 15,
                color: _copies > 1 ? AppTheme.textSecondary : AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$_copies',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: _copies < 100 ? () => setState(() => _copies++) : null,
            child: SizedBox(
              width: 38,
              child: Icon(
                Icons.add_rounded,
                size: 15,
                color: _copies < 100 ? AppTheme.textSecondary : AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paperSizeDropdown() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _paperSize,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            DropdownMenuItem(value: 'A4', child: Text('A4')),
            DropdownMenuItem(value: 'Letter', child: Text('Letter')),
            DropdownMenuItem(value: 'Legal', child: Text('Legal')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _paperSize = val);
          },
        ),
      ),
    );
  }

  Widget _miniChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySurface : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
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

  Widget _buildBottomBar() => PrintActionBar(
    details: '$_calculatedPages pages \u00d7 $_copies',
    amount: '\u20b9${_estimatedCost.toStringAsFixed(2)}',
    action: 'Apply Settings',
    onPressed: _saveSettings,
  );
}
