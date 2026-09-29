import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../widgets/workflow_stepper.dart';
import 'payment_screen.dart';

class PrintOptionsScreen extends StatefulWidget {
  final List<UploadedDocument> documents;
  final String selectedStationId;

  PrintOptionsScreen({
    super.key,
    List<UploadedDocument>? documents,
    UploadedDocument? document,
    this.selectedStationId = 'station-1',
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
    _configs = docs
        .map((d) => DocumentPrintConfig(document: d))
        .toList();
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
      // Auto-scroll selected tab into view smoothly
      if (_tabScrollController.hasClients) {
        final target = (index * 150.0)
            .clamp(0.0, _tabScrollController.position.maxScrollExtent);
        _tabScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _nextDocument() {
    if (_selectedDocIndex < _configs.length - 1) {
      _selectDocument(_selectedDocIndex + 1);
    }
  }

  void _prevDocument() {
    if (_selectedDocIndex > 0) {
      _selectDocument(_selectedDocIndex - 1);
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
        paperSize: 'A4',
        orientation: current.orientation,
        pageRange: current.isCustomRange && current.customRange.trim().isNotEmpty
            ? current.customRange.trim()
            : 'all',
      );

      final order = await _apiService.createOrder(
        documentId: widget.primaryDocument.id,
        printServerId: widget.selectedStationId,
        printSettings: settings,
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
        _validationError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Print Settings'),
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 2),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Multi-PDF Tab Selector (If more than 1 document)
                  if (_configs.length > 1) ...[
                    Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded,
                            size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Documents (${_selectedDocIndex + 1}/${_configs.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Horizontal PDF tabs (Clean, smooth scrolling without <> arrow buttons)
                    SizedBox(
                      height: 46,
                      child: ListView.separated(
                        controller: _tabScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: _configs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (ctx, index) {
                          final cfg = _configs[index];
                          final isSelected = index == _selectedDocIndex;

                          final Color tabBg = isSelected
                              ? AppTheme.primary
                              : AppTheme.surfaceWhite;
                          final Color tabBorder = isSelected
                              ? AppTheme.primary
                              : AppTheme.border;
                          final Color tabText = isSelected
                              ? Colors.white
                              : AppTheme.textPrimary;
                          final Color badgeBg = isSelected
                              ? Colors.white.withValues(alpha: 0.22)
                              : AppTheme.surfaceSubtle;
                          final Color badgeText = isSelected
                              ? Colors.white
                              : AppTheme.textSecondary;
                          final IconData tabIcon = isSelected
                              ? Icons.picture_as_pdf_rounded
                              : Icons.picture_as_pdf_outlined;
                          final Color iconColor = isSelected
                              ? Colors.white
                              : AppTheme.textSecondary;

                          return InkWell(
                            onTap: () => _selectDocument(index),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: tabBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: tabBorder,
                                  width: isSelected ? 1.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    tabIcon,
                                    size: 16,
                                    color: iconColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    cfg.document.filename,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: tabText,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${cfg.document.pages}p',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: badgeText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Currently active document banner with ONLY Next and Previous buttons
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentConfig.document.filename,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Document ${_selectedDocIndex + 1} of ${_configs.length} • ${_currentConfig.document.pages} Pages',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_configs.length > 1) ...[
                          const SizedBox(width: 8),
                          // Dedicated Next & Previous navigation buttons right by the PDF name
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _selectedDocIndex > 0
                                    ? _prevDocument
                                    : null,
                                icon: const Icon(Icons.arrow_back_rounded,
                                    size: 14),
                                label: const Text('Prev'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: AppTheme.textPrimary,
                                  disabledForegroundColor: AppTheme.textMuted,
                                  side: BorderSide(
                                    color: _selectedDocIndex > 0
                                        ? AppTheme.border
                                        : AppTheme.border
                                            .withValues(alpha: 0.4),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _selectedDocIndex < _configs.length - 1
                                    ? _nextDocument
                                    : null,
                                icon: const Icon(Icons.arrow_forward_rounded,
                                    size: 14),
                                label: const Text('Next'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      AppTheme.surfaceSubtle,
                                  disabledForegroundColor: AppTheme.textMuted,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Step 2: Configure Job Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option 1: Number of Copies
                  _buildSectionCard(
                    title: 'Number of Copies',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total sets to print',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                onPressed: _currentConfig.copies > 1
                                    ? () => _updateActiveSetting(
                                        () => _currentConfig.copies--)
                                    : null,
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 36),
                                alignment: Alignment.center,
                                child: Text(
                                  '${_currentConfig.copies}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: _currentConfig.copies < 50
                                    ? () => _updateActiveSetting(
                                        () => _currentConfig.copies++)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Option 2: Color Mode
                  _buildSectionCard(
                    title: 'Color Mode',
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSelectableChip(
                            label: 'Black & White',
                            subtitle: '₹2.00 / page',
                            icon: Icons.monochrome_photos_outlined,
                            isSelected: !_currentConfig.isColor,
                            onTap: () => _updateActiveSetting(
                                () => _currentConfig.isColor = false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectableChip(
                            label: 'Full Color',
                            subtitle: '₹10.00 / page',
                            icon: Icons.palette_outlined,
                            isSelected: _currentConfig.isColor,
                            onTap: () => _updateActiveSetting(
                                () => _currentConfig.isColor = true),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Option 3: Print Sides
                  _buildSectionCard(
                    title: 'Print Sides (Duplex)',
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSelectableChip(
                            label: 'Single-Sided',
                            subtitle: 'Standard',
                            icon: Icons.description_outlined,
                            isSelected: _currentConfig.sides == 'one-sided',
                            onTap: () => _updateActiveSetting(
                                () => _currentConfig.sides = 'one-sided'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectableChip(
                            label: 'Double-Sided',
                            subtitle: '10% Duplex discount',
                            icon: Icons.auto_stories_outlined,
                            isSelected: _currentConfig.sides != 'one-sided',
                            onTap: () => _updateActiveSetting(() =>
                                _currentConfig.sides = 'two-sided-long-edge'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Option 4: Orientation
                  _buildSectionCard(
                    title: 'Orientation (A4 Paper)',
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSelectableChip(
                            label: 'Portrait',
                            subtitle: 'Vertical layout',
                            icon: Icons.portrait_rounded,
                            isSelected:
                                _currentConfig.orientation == 'portrait',
                            onTap: () => _updateActiveSetting(
                                () => _currentConfig.orientation = 'portrait'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectableChip(
                            label: 'Landscape',
                            subtitle: 'Horizontal layout',
                            icon: Icons.landscape_rounded,
                            isSelected:
                                _currentConfig.orientation == 'landscape',
                            onTap: () => _updateActiveSetting(
                                () => _currentConfig.orientation = 'landscape'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Option 5: Page Range
                  _buildSectionCard(
                    title: 'Page Range for this Document',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  _updateActiveSetting(() {
                                    _currentConfig.isCustomRange = false;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: !_currentConfig.isCustomRange
                                        ? AppTheme.primarySurface
                                        : AppTheme.surfaceWhite,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: !_currentConfig.isCustomRange
                                          ? AppTheme.primary
                                          : AppTheme.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        !_currentConfig.isCustomRange
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        size: 16,
                                        color: !_currentConfig.isCustomRange
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'All Pages',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  _updateActiveSetting(() {
                                    _currentConfig.isCustomRange = true;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: _currentConfig.isCustomRange
                                        ? AppTheme.primarySurface
                                        : AppTheme.surfaceWhite,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _currentConfig.isCustomRange
                                          ? AppTheme.primary
                                          : AppTheme.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _currentConfig.isCustomRange
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        size: 16,
                                        color: _currentConfig.isCustomRange
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Custom Range',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_currentConfig.isCustomRange) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _rangeController,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 1-3 or 1,2,5',
                              prefixIcon: Icon(Icons.format_list_numbered,
                                  size: 20),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validationError!,
                              style: const TextStyle(
                                  color: AppTheme.danger, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Price Preview & Submit Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Flexible(
                                        child: Text(
                                          'Total Estimated Cost',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_configs.length > 1) ...[
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _showCostBreakdown =
                                                  !_showCostBreakdown;
                                            });
                                          },
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
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${_totalEstimatedTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  Text(
                                    '$_totalCalculatedPages Pages (${_configs.length} Doc${_configs.length > 1 ? "s" : ""})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _isValidating ? null : _submitOrder,
                              child: _isValidating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      children: [
                                        Text('Proceed to Pay'),
                                        SizedBox(width: 6),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 16),
                                      ],
                                    ),
                            ),
                          ],
                        ),

                        // Expandable per-document price breakdown
                        if (_showCostBreakdown && _configs.length > 1) ...[
                          const Divider(height: 24),
                          Column(
                            children: _configs.map((c) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${c.document.filename} (${c.copies}x, ${c.isColor ? "Color" : "B/W"}, ${c.orientation == "landscape" ? "Landscape" : "Portrait"})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '₹${c.estimatedCost.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
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

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.primarySurface : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color:
                    isSelected ? AppTheme.primary : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
