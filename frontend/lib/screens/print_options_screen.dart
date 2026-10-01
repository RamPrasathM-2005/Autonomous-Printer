import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../widgets/workflow_stepper.dart';
import '../widgets/server_config_dialog.dart';
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
  String _selectedPrinter = 'HP_LaserJet_400_M401dn_F36EC0';

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
      if (_tabScrollController.hasClients) {
        final target = (index * 160.0)
            .clamp(0.0, _tabScrollController.position.maxScrollExtent);
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
        pageRange: current.isCustomRange && current.customRange.trim().isNotEmpty
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

      // Explicitly set printer on order if endpoint available
      try {
        await _apiService.selectOrderPrinter(
          orderId: order.id,
          cupsPrinterName: _selectedPrinter,
        );
      } catch (_) {}

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
        titleSpacing: 16,
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.jpg',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const Icon(Icons.print_rounded, size: 24, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Print Options',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: () => showServerConfigModal(context),
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
        ],
      ),
      body: Column(
        children: [
          const WorkflowStepper(currentStep: 2),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (ctx, index) {
                              final cfg = _configs[index];
                              final isSelected = index == _selectedDocIndex;
                              return InkWell(
                                onTap: () => _selectDocument(index),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primary : AppTheme.surfaceWhite,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.primary : AppTheme.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: isSelected ? AppTheme.buttonShadow : AppTheme.cardShadow,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        cfg.document.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                                        size: 16,
                                        color: isSelected ? Colors.white : AppTheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        cfg.document.filename,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? Colors.white : AppTheme.textPrimary,
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

                      // Active Document Summary Card
                      _buildDocumentHeaderCard(),

                      const SizedBox(height: 20),

                      // Document Preview Card (PDF Sheet Preview or Image Canvas)
                      _buildDocumentPreviewCard(),

                      const SizedBox(height: 20),

                      // Destination Printer Selector
                      _buildSectionContainer(
                        title: 'Destination Printer',
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildPrinterOptionCard(
                                id: 'HP_LaserJet_400_M401dn_F36EC0',
                                name: 'HP LaserJet 400',
                                desc: 'Duplex • B&W • Fast',
                                icon: Icons.print_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildPrinterOptionCard(
                                id: 'Printer_2',
                                name: 'Secondary Printer',
                                desc: 'Color / Tray 2 • High Res',
                                icon: Icons.color_lens_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Segment 1: Color Mode Selector (Color or Grayscale)
                      _buildSectionContainer(
                        title: 'Color Mode',
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSegmentPill(
                                label: 'Color',
                                icon: Icons.color_lens_rounded,
                                isSelected: _currentConfig.isColor,
                                accentColor: const Color(0xFF6366F1),
                                onTap: () => _updateActiveSetting(() => _currentConfig.isColor = true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSegmentPill(
                                label: 'Grayscale',
                                icon: Icons.tonality_rounded,
                                isSelected: !_currentConfig.isColor,
                                accentColor: const Color(0xFF475569),
                                onTap: () => _updateActiveSetting(() => _currentConfig.isColor = false),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Segment 2: Paper Size & Orientation (Reference Image 3: Paper Size segment)
                      _buildSectionContainer(
                        title: 'Paper Size & Layout',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Paper Size',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: ['A4', 'Letter', 'Legal'].map((size) {
                                final isSelected = _currentConfig.paperSize == size;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: _buildPillChip(
                                      label: size,
                                      isSelected: isSelected,
                                      onTap: () => _updateActiveSetting(() => _currentConfig.paperSize = size),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Orientation',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSegmentPill(
                                    label: 'Portrait',
                                    icon: Icons.crop_portrait_rounded,
                                    isSelected: _currentConfig.orientation == 'portrait',
                                    onTap: () => _updateActiveSetting(() => _currentConfig.orientation = 'portrait'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSegmentPill(
                                    label: 'Landscape',
                                    icon: Icons.crop_landscape_rounded,
                                    isSelected: _currentConfig.orientation == 'landscape',
                                    onTap: () => _updateActiveSetting(() => _currentConfig.orientation = 'landscape'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Segment 3: Copies Stepper
                      _buildSectionContainer(
                        title: 'Number of Copies',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Select copies to print',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _currentConfig.copies > 1
                                        ? () => _updateActiveSetting(() => _currentConfig.copies--)
                                        : null,
                                    icon: const Icon(Icons.remove_rounded),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppTheme.surfaceWhite,
                                      foregroundColor: AppTheme.textPrimary,
                                      elevation: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '${_currentConfig.copies}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    onPressed: () => _updateActiveSetting(() => _currentConfig.copies++),
                                    icon: const Icon(Icons.add_rounded),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Segment 4: Sides & Page Range Options
                      _buildSectionContainer(
                        title: 'Sides & Page Selection',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Print Sides',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPillChip(
                                    label: 'Single-sided',
                                    isSelected: _currentConfig.sides == 'one-sided',
                                    onTap: () => _updateActiveSetting(() => _currentConfig.sides = 'one-sided'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildPillChip(
                                    label: 'Double-sided',
                                    isSelected: _currentConfig.sides != 'one-sided',
                                    onTap: () => _updateActiveSetting(() => _currentConfig.sides = 'two-sided-long-edge'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Page Range',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildRangeChip('All Pages (${_currentConfig.document.pages})', 'all'),
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
                                  prefixIcon: Icon(Icons.format_list_numbered_rounded, size: 20),
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
                            border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _validationError!,
                                  style: const TextStyle(color: AppTheme.danger, fontSize: 13, fontWeight: FontWeight.w500),
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
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Total Estimated Price',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_configs.length > 1) ...[
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => setState(() => _showCostBreakdown = !_showCostBreakdown),
                                    child: Icon(
                                      _showCostBreakdown ? Icons.expand_less : Icons.expand_more,
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
                              '$_totalCalculatedPages Pages (${_configs.length} Doc${_configs.length > 1 ? "s" : ""})',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isValidating ? null : _submitOrder,
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
                        child: _isValidating
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
                                  Text('Preparing Order...'),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.print_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Print Now',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.timer_outlined, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          '~15s',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                        child: Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 28),
                      ),
                    )
                  : Image.asset(
                      'assets/images/mountain_preview.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFEFF6FF),
                        child: const Icon(Icons.image_rounded, color: Color(0xFF2563EB), size: 28),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${doc.pages} Page(s)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(doc.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
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

  Widget _buildDocumentPreviewCard() {
    final doc = _currentConfig.document;
    final isPdf = doc.isPdf;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isPdf ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                        size: 16,
                        color: isPdf ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isPdf ? 'PDF Document Preview' : 'Image Document Preview',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _currentConfig.isColor
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _currentConfig.isColor
                          ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _currentConfig.isColor ? Icons.color_lens_rounded : Icons.tonality_rounded,
                        size: 13,
                        color: _currentConfig.isColor ? const Color(0xFF6366F1) : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentConfig.isColor ? 'Color' : 'Grayscale',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _currentConfig.isColor ? const Color(0xFF6366F1) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            height: 250,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: isPdf ? _buildPdfPreviewCanvas() : _buildImagePreviewCanvas(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreviewCanvas() {
    final doc = _currentConfig.document;
    final isColor = _currentConfig.isColor;

    return Center(
      child: Container(
        width: 175,
        height: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isColor ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Text(
                  _currentConfig.paperSize,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              doc.filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isColor ? const Color(0xFF0F172A) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${_currentConfig.calculatedPages} pg • ${_currentConfig.pageRangeDescription}',
              style: const TextStyle(
                fontSize: 8,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            for (int i = 0; i < 5; i++) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                width: i % 2 == 0 ? double.infinity : 110,
                height: 5,
                decoration: BoxDecoration(
                  color: isColor
                      ? (i == 0 ? const Color(0xFF818CF8) : const Color(0xFFE2E8F0))
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            const Spacer(),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isColor ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isColor ? '● Color Mode' : '● Grayscale Mode',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: isColor ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewCanvas() {
    final isColor = _currentConfig.isColor;

    return Stack(
      alignment: Alignment.center,
      children: [
        ColorFiltered(
          colorFilter: isColor
              ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
              : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
          child: Image.asset(
            'assets/images/mountain_preview.jpg',
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => Center(
              child: Icon(
                Icons.image_rounded,
                size: 64,
                color: isColor ? AppTheme.primary : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isColor ? Icons.color_lens_rounded : Icons.tonality_rounded,
                  size: 13,
                  color: isColor ? const Color(0xFFA5B4FC) : Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  isColor ? 'Preview: Full Color Image' : 'Preview: Grayscale B&W Image',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContainer({required String title, required Widget child}) {
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
          color: isSelected ? activeColor.withValues(alpha: 0.1) : AppTheme.surfaceSubtle,
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
            Icon(icon, size: 20, color: isSelected ? activeColor : AppTheme.textSecondary),
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
      onTap: () => _updateActiveSetting(() => _currentConfig.rangeOption = option),
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

  Widget _buildPrinterOptionCard({
    required String id,
    required String name,
    required String desc,
    required IconData icon,
  }) {
    final isSelected = _selectedPrinter == id;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPrinter = id;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySurface : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppTheme.buttonShadow : AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 22, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppTheme.primary.withOpacity(0.8) : AppTheme.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
