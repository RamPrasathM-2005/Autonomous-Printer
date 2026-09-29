import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../widgets/workflow_stepper.dart';
import 'payment_screen.dart';

class DocumentPrintConfig {
  final UploadedDocument document;
  int copies;
  bool isColor;
  String sides; // 'one-sided' or 'two-sided-long-edge'
  String paperSize; // 'A4', 'Letter', 'Legal'
  bool isCustomRange;
  String customRange;

  DocumentPrintConfig({
    required this.document,
    this.copies = 1,
    this.isColor = false,
    this.sides = 'one-sided',
    this.paperSize = 'A4',
    this.isCustomRange = false,
    this.customRange = '',
  });

  int get calculatedPages {
    if (!isCustomRange || customRange.trim().isEmpty) {
      return document.pages > 0 ? document.pages : 1;
    }
    final text = customRange.trim();
    final parts = text.split('-');
    if (parts.length == 2) {
      int? start = int.tryParse(parts[0].trim());
      int? end = int.tryParse(parts[1].trim());
      if (start != null && end != null && end >= start) {
        return (end - start + 1);
      }
    }
    return document.pages > 0 ? document.pages : 1;
  }

  double get estimatedCost {
    final rate = isColor ? 10.0 : 2.0;
    double cost = calculatedPages * copies * rate;
    if (sides != 'one-sided') {
      cost = cost * 0.9; // 10% duplex discount
    }
    return cost;
  }
}

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
    super.dispose();
  }

  DocumentPrintConfig get _currentConfig => _configs[_selectedDocIndex];

  void _selectDocument(int index) {
    if (index >= 0 && index < _configs.length) {
      setState(() {
        _selectedDocIndex = index;
        _rangeController.text = _configs[index].customRange;
      });
    }
  }

  void _applyCurrentSettingsToAll() {
    final current = _currentConfig;
    setState(() {
      for (int i = 0; i < _configs.length; i++) {
        _configs[i].copies = current.copies;
        _configs[i].isColor = current.isColor;
        _configs[i].sides = current.sides;
        _configs[i].paperSize = current.paperSize;
        _configs[i].isCustomRange = current.isCustomRange;
        _configs[i].customRange = current.customRange;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Settings successfully applied to all ${_configs.length} documents!',
        ),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
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
          builder: (ctx) => PaymentScreen(order: order),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Configure Documents (${_configs.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _applyCurrentSettingsToAll,
                          icon: const Icon(Icons.copy_all_rounded, size: 16),
                          label: const Text(
                            'Apply to All PDFs',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Horizontal PDF tabs
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _configs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (ctx, index) {
                          final cfg = _configs[index];
                          final isSelected = index == _selectedDocIndex;
                          return InkWell(
                            onTap: () => _selectDocument(index),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primarySurface
                                    : AppTheme.surfaceWhite,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf_outlined,
                                    size: 16,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary,
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
                                          ? AppTheme.primary
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primary
                                          : AppTheme.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${cfg.document.pages}p',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.textSecondary,
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
                    const SizedBox(height: 16),
                  ],

                  // Currently active document banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppTheme.primary,
                            size: 22,
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
                        if (_configs.length > 1)
                          OutlinedButton.icon(
                            onPressed: _applyCurrentSettingsToAll,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              side: const BorderSide(color: AppTheme.primary),
                            ),
                            icon: const Icon(Icons.sync_rounded,
                                size: 14, color: AppTheme.primary),
                            label: const Text(
                              'Set to All',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
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
                                    ? () => setState(
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
                                    ? () => setState(
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
                            onTap: () =>
                                setState(() => _currentConfig.isColor = false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectableChip(
                            label: 'Full Color',
                            subtitle: '₹10.00 / page',
                            icon: Icons.palette_outlined,
                            isSelected: _currentConfig.isColor,
                            onTap: () =>
                                setState(() => _currentConfig.isColor = true),
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
                            onTap: () => setState(
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
                            onTap: () => setState(() =>
                                _currentConfig.sides = 'two-sided-long-edge'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Option 4: Paper Size
                  _buildSectionCard(
                    title: 'Paper Size',
                    child: Row(
                      children: ['A4', 'Letter', 'Legal'].map((size) {
                        final isSelected = _currentConfig.paperSize == size;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(
                                  () => _currentConfig.paperSize = size),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primarySurface
                                      : AppTheme.surfaceWhite,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.border,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  size,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                                  setState(() {
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
                                  setState(() {
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
                              setState(() {
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Total Estimated Cost',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
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
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                Text(
                                  '$_totalCalculatedPages Total Pages across ${_configs.length} Document(s)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
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
                                        '${c.document.filename} (${c.copies}x, ${c.isColor ? "Color" : "B/W"})',
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
