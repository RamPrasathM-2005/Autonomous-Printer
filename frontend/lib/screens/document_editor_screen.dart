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

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doc.filename,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Custom Document Print Editor',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _resetToDefault,
            icon: const Icon(Icons.refresh, size: 15, color: AppTheme.textSecondary),
            label: const Text(
              'Reset',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildPreviewSection(doc, isLandscape, constraints.maxWidth),
                  ),
                ),
                Container(width: 1, color: AppTheme.border),
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildControlsSection(),
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPreviewSection(doc, isLandscape, constraints.maxWidth),
                const SizedBox(height: 14),
                _buildControlsSection(),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          border: const Border(top: BorderSide(color: AppTheme.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 360;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_calculatedPages ${ _calculatedPages == 1 ? 'page' : 'pages'} × $_copies ${ _copies == 1 ? 'copy' : 'copies'}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '₹${_estimatedCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.check, size: 15),
                    label: Text(
                      isSmall ? 'Apply' : 'Apply Settings',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 10 : 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewSection(UploadedDocument doc, bool isLandscape, double maxWidth) {
    final previewHeight = maxWidth < 600 ? 240.0 : 360.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.remove_red_eye_outlined, size: 16, color: AppTheme.primary),
                  SizedBox(width: 6),
                  Text(
                    'Document Preview',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _isColor
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _isColor
                        ? const Color(0xFFBFDBFE)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Text(
                  _isColor ? 'Color' : 'B&W',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _isColor
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Real Document Preview (Renders actual PDF iframe on web or actual Image)
          Center(
            child: SizedBox(
              width: double.infinity,
              height: previewHeight,
              child: RealDocumentPreview(
                document: doc,
                isLandscape: isLandscape,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Document Metadata Tags
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoTag('Type', doc.isPdf ? 'PDF' : 'Image'),
                _buildInfoTag('Size', doc.formattedSize),
                _buildInfoTag('Pages', '$_calculatedPages / ${doc.pages}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTag(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildControlsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Custom Print Configuration',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Settings applied to this document only.',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // 1. Page Range
          _buildSectionLabel('Page Range', Icons.filter_none_outlined),
          const SizedBox(height: 6),
          _buildRangeSegmentedControl(),
          if (_rangeOption == 'custom') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _rangeController,
              decoration: InputDecoration(
                hintText: 'e.g. 1-3, 5, 7-${widget.initialConfig.document.pages}',
                labelText: 'Custom Range (Total ${widget.initialConfig.document.pages} pages)',
                labelStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.edit_outlined, size: 16),
                filled: true,
                fillColor: AppTheme.surfaceSubtle,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _customRange = val;
                });
              },
            ),
          ],
          const SizedBox(height: 16),

          // 2. Copies & Color Mode Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Copies', Icons.content_copy),
                    const SizedBox(height: 6),
                    Container(
                      height: 38,
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
                            onPressed: _copies > 1
                                ? () => setState(() => _copies--)
                                : null,
                          ),
                          Expanded(
                            child: Text(
                              '$_copies',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 14),
                            padding: EdgeInsets.zero,
                            onPressed: _copies < 100
                                ? () => setState(() => _copies++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Paper Size', Icons.aspect_ratio),
                    const SizedBox(height: 6),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(8),
                        color: AppTheme.surfaceSubtle,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _paperSize,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
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
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Color Mode
          _buildSectionLabel('Color Mode', Icons.palette_outlined),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildChoiceCard(
                  title: 'B&W',
                  subtitle: '₹2.00 / page',
                  icon: Icons.filter_b_and_w,
                  isSelected: !_isColor,
                  onTap: () => setState(() => _isColor = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceCard(
                  title: 'Full Color',
                  subtitle: '₹10.00 / page',
                  icon: Icons.color_lens,
                  isSelected: _isColor,
                  onTap: () => setState(() => _isColor = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Orientation
          _buildSectionLabel('Orientation', Icons.screen_rotation_outlined),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildMiniChoice(
                  label: 'Portrait',
                  icon: Icons.stay_current_portrait,
                  isSelected: _orientation == 'portrait',
                  onTap: () => setState(() => _orientation = 'portrait'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniChoice(
                  label: 'Landscape',
                  icon: Icons.stay_current_landscape,
                  isSelected: _orientation == 'landscape',
                  onTap: () => setState(() => _orientation = 'landscape'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5. Duplex / Sides
          _buildSectionLabel('Print Sides', Icons.auto_stories_outlined),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildMiniChoice(
                  label: '1-Sided',
                  icon: Icons.looks_one_outlined,
                  isSelected: _sides == 'one-sided',
                  onTap: () => setState(() => _sides = 'one-sided'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniChoice(
                  label: '2-Sided',
                  icon: Icons.looks_two_outlined,
                  isSelected: _sides != 'one-sided',
                  onTap: () => setState(() => _sides = 'two-sided-long-edge'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 5),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildRangeSegmentedControl() {
    final options = [
      {'key': 'all', 'label': 'All'},
      {'key': 'odd', 'label': 'Odd'},
      {'key': 'even', 'label': 'Even'},
      {'key': 'custom', 'label': 'Custom'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: options.map((opt) {
          final isSelected = _rangeOption == opt['key'];
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _rangeOption = opt['key']!;
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  opt['label']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.85)
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChoice({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
              size: 14,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
}
