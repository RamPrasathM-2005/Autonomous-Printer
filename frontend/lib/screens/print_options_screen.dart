import 'package:flutter/material.dart';

import '../services/api_error.dart';

import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import 'payment_screen.dart';

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
  int _selectedDocIndex = 0;
  final TextEditingController _rangeController = TextEditingController();
  final ScrollController _tabScrollController = ScrollController();

  bool _isValidating = false;
  String? _validationError;
  bool _showCostBreakdown = false;

  @override
  void initState() {
    super.initState();
    final docs = widget.documents.isNotEmpty
        ? widget.documents
        : [widget.primaryDocument];
    _configs = docs.map((d) => DocumentPrintConfig(document: d)).toList();
    _rangeController.text = _configs.first.customRange;
  }

  @override
  void dispose() {
    _rangeController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  DocumentPrintConfig get _currentConfig => _configs[_selectedDocIndex];

  void _updateActiveSetting(VoidCallback update) {
    setState(() {
      update();
    });
  }

  void _selectDocument(int index) {
    if (index >= 0 && index < _configs.length) {
      setState(() {
        _selectedDocIndex = index;
        _rangeController.text = _configs[index].customRange;
      });
      if (_tabScrollController.hasClients) {
        final target = (index * 160.0).clamp(
          0.0,
          _tabScrollController.position.maxScrollExtent,
        );
        _tabScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  double get _totalEstimatedTotal {
    return _configs.fold(0.0, (sum, c) => sum + c.estimatedCost);
  }

  int get _totalCalculatedPages {
    return _configs.fold(0, (sum, c) => sum + (c.calculatedPages * c.copies));
  }

  Future<void> _submitOrder() async {
    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    try {
      final current = _currentConfig;
      final settings = PrintSettings(
        copies: current.copies,
        colour: current.isColor,
        sides: current.sides,
        paperSize: current.paperSize,
        orientation: current.orientation,
        pageRange:
            current.isCustomRange && current.customRange.trim().isNotEmpty
            ? current.customRange.trim()
            : current.rangeOption,
      );

      final List<Map<String, dynamic>> itemsPayload = _configs.map((c) {
        final pr = (c.isCustomRange && c.customRange.trim().isNotEmpty)
            ? c.customRange.trim()
            : c.rangeOption;
        return {
          'document_id': c.document.id,
          'settings': {
            'copies': c.copies,
            'colour': c.isColor,
            'sides': c.sides,
            'paper_size': c.paperSize,
            'orientation': c.orientation,
            'page_range': pr,
          },
        };
      }).toList();

      final order = await _apiService.createOrder(
        documentId: widget.primaryDocument.id,
        printServerId: widget.selectedStationId,
        printSettings: settings,
        items: itemsPayload,
      );

      setState(() {
        _isValidating = false;
      });

      if (!mounted) return;

      // Navigate to Step 3: Payment
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PaymentScreen(
            order: order,
            documents: widget.documents,
            configs: _configs,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isValidating = false;
        _validationError = userError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Print options'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
      ),
      body: Column(
        children: [
          // WorkflowStepper removed — no top flow bar
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Multi-Document Tab Selector Bar (If multiple files uploaded)
                      if (_configs.length > 1) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Configuring Document ${_selectedDocIndex + 1} of ${_configs.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              '${_configs.length} Files Uploaded',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            controller: _tabScrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: _configs.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (ctx, index) {
                              final cfg = _configs[index];
                              final isSelected = index == _selectedDocIndex;
                              return InkWell(
                                onTap: () => _selectDocument(index),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.surfaceWhite,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primary
                                          : AppTheme.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? AppTheme.buttonShadow
                                        : AppTheme.cardShadow,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        cfg.document.isPdf
                                            ? Icons.picture_as_pdf_rounded
                                            : Icons.image_rounded,
                                        size: 16,
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        cfg.document.filename,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Active Document Summary Card (Inspired by Image 2 Header Card)
                      _buildDocumentHeaderCard(),

                      const SizedBox(height: 20),

                      // Segment 1: Color Mode Selector (Color or Grayscale)
                      _buildSectionContainer(
                        title: 'Color',
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSegmentPill(
                                label: 'Color',
                                icon: Icons.color_lens_rounded,
                                isSelected: _currentConfig.isColor,
                                accentColor: AppTheme.primary,
                                onTap: () => _updateActiveSetting(
                                  () => _currentConfig.isColor = true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSegmentPill(
                                label: 'B&W',
                                icon: Icons.tonality_rounded,
                                isSelected: !_currentConfig.isColor,
                                accentColor: const Color(0xFF475569),
                                onTap: () => _updateActiveSetting(
                                  () => _currentConfig.isColor = false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Segment 2: Paper Size & Orientation (Reference Image 3: Paper Size segment)
                      _buildSectionContainer(
                        title: 'Paper and layout',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Paper Size',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: ['A4', 'Letter', 'Legal'].map((size) {
                                final isSelected =
                                    _currentConfig.paperSize == size;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: _buildPillChip(
                                      label: size,
                                      isSelected: isSelected,
                                      onTap: () => _updateActiveSetting(
                                        () => _currentConfig.paperSize = size,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Orientation',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSegmentPill(
                                    label: 'Portrait',
                                    icon: Icons.crop_portrait_rounded,
                                    isSelected:
                                        _currentConfig.orientation ==
                                        'portrait',
                                    onTap: () => _updateActiveSetting(
                                      () => _currentConfig.orientation =
                                          'portrait',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSegmentPill(
                                    label: 'Landscape',
                                    icon: Icons.crop_landscape_rounded,
                                    isSelected:
                                        _currentConfig.orientation ==
                                        'landscape',
                                    onTap: () => _updateActiveSetting(
                                      () => _currentConfig.orientation =
                                          'landscape',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Segment 3: Duplex & Copies Counter Card (Reference Image 3: Copies stepper card)
                      Row(
                        children: [
                          // Copies Counter (Reference Image 3: - 1 + Pill Card)
                          Expanded(
                            flex: 1,
                            child: _buildSectionContainer(
                              title: 'Copies',
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton.filledTonal(
                                    onPressed: _currentConfig.copies > 1
                                        ? () => _updateActiveSetting(
                                            () => _currentConfig.copies--,
                                          )
                                        : null,
                                    icon: const Icon(Icons.remove_rounded),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppTheme.surfaceSubtle,
                                      foregroundColor: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${_currentConfig.copies}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    onPressed: () => _updateActiveSetting(
                                      () => _currentConfig.copies++,
                                    ),
                                    icon: const Icon(Icons.add_rounded),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppTheme.primarySurface,
                                      foregroundColor: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Segment 4: Sides & Page Range Options
                      _buildSectionContainer(
                        title: 'Sides and pages',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Print Sides',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPillChip(
                                    label: 'Single-sided',
                                    isSelected:
                                        _currentConfig.sides == 'one-sided',
                                    onTap: () => _updateActiveSetting(
                                      () => _currentConfig.sides = 'one-sided',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildPillChip(
                                    label: 'Double-sided',
                                    isSelected:
                                        _currentConfig.sides != 'one-sided',
                                    onTap: () => _updateActiveSetting(
                                      () => _currentConfig.sides =
                                          'two-sided-long-edge',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Page Range',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildRangeChip(
                                  'All Pages (${_currentConfig.document.pages})',
                                  'all',
                                ),
                                _buildRangeChip('Odd Pages Only', 'odd'),
                                _buildRangeChip('Even Pages Only', 'even'),
                                _buildRangeChip('Custom Range', 'custom'),
                              ],
                            ),
                            if (_currentConfig.isCustomRange) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _rangeController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 1-5, 8, 11-13',
                                  prefixIcon: Icon(
                                    Icons.format_list_numbered_rounded,
                                    size: 20,
                                  ),
                                ),
                                onChanged: (text) {
                                  _updateActiveSetting(() {
                                    _currentConfig.customRange = text;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (_validationError != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
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
                                  _validationError!,
                                  style: const TextStyle(
                                    color: AppTheme.danger,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action & Total Summary Bar (Reference Image 3 Action Bar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
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
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Estimated total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_configs.length > 1) ...[
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => setState(
                                    () => _showCostBreakdown =
                                        !_showCostBreakdown,
                                  ),
                                  child: Icon(
                                    _showCostBreakdown
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${_totalEstimatedTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$_totalCalculatedPages ${_totalCalculatedPages == 1 ? 'page' : 'pages'} / ${_configs.length} ${_configs.length == 1 ? 'file' : 'files'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                      final action = ElevatedButton(
                        onPressed: _isValidating ? null : _submitOrder,
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
                        child: _isValidating
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Preparing...'),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.print_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Continue to payment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      );
                      if (constraints.maxWidth < 560) {
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

  Widget _buildDocumentHeaderCard() {
    final doc = _currentConfig.document;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: doc.isPdf
                  ? Container(
                      color: const Color(0xFFFEF2F2),
                      child: const Center(
                        child: Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Color(0xFFDC2626),
                          size: 28,
                        ),
                      ),
                    )
                  : Image.asset(
                      'assets/images/mountain_preview.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFEFF6FF),
                        child: const Icon(
                          Icons.image_rounded,
                          color: Color(0xFF2563EB),
                          size: 28,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.filename,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${doc.pages} ${doc.pages == 1 ? 'page' : 'pages'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(doc.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: 'Add / Change Document',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(10),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildSegmentPill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final activeColor = accentColor ?? AppTheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.1)
              : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? activeColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? activeColor : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySurface : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRangeChip(String label, String option) {
    final isSelected = _currentConfig.rangeOption == option;
    return InkWell(
      onTap: () =>
          _updateActiveSetting(() => _currentConfig.rangeOption = option),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySurface : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
