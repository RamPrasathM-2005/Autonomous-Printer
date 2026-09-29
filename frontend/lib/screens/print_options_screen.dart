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

  int get totalPages =>
      documents.fold(0, (sum, d) => sum + d.pages);

  @override
  State<PrintOptionsScreen> createState() => _PrintOptionsScreenState();
}

class _PrintOptionsScreenState extends State<PrintOptionsScreen> {
  final ApiService _apiService = ApiService();

  int _copies = 1;
  bool _isColor = false;
  String _sides = 'one-sided'; // 'one-sided' or 'two-sided-long-edge'
  String _paperSize = 'A4';
  bool _isCustomRange = false;

  final TextEditingController _rangeController = TextEditingController();
  bool _isValidating = false;
  String? _validationError;

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  int get _calculatedPages {
    if (!_isCustomRange || _rangeController.text.trim().isEmpty) {
      return widget.totalPages > 0 ? widget.totalPages : 1;
    }
    final text = _rangeController.text.trim();
    final parts = text.split('-');
    if (parts.length == 2) {
      int? start = int.tryParse(parts[0].trim());
      int? end = int.tryParse(parts[1].trim());
      if (start != null && end != null && end >= start) {
        return (end - start + 1);
      }
    }
    return widget.totalPages > 0 ? widget.totalPages : 1;
  }

  double get _estimatedTotal {
    final rate = _isColor ? 10.0 : 2.0;
    final pages = _calculatedPages;
    double total = pages * _copies * rate;
    if (_sides != 'one-sided') {
      // 10% duplex discount
      total = total * 0.9;
    }
    return total;
  }

  Future<void> _submitOrder() async {
    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    try {
      final settings = PrintSettings(
        copies: _copies,
        colour: _isColor,
        sides: _sides,
        paperSize: _paperSize,
        pageRange:
            _isCustomRange && _rangeController.text.trim().isNotEmpty
                ? _rangeController.text.trim()
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
                  // Document summary banner
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
                          child: Icon(
                            widget.documents.length > 1
                                ? Icons.copy_all_rounded
                                : Icons.picture_as_pdf,
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
                                widget.documents.length > 1
                                    ? '${widget.documents.length} Documents Selected'
                                    : widget.primaryDocument.filename,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.totalPages} Total Pages • Station: ${widget.selectedStationId}',
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
                  ),

                  const SizedBox(height: 24),

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
                                onPressed: _copies > 1
                                    ? () => setState(() => _copies--)
                                    : null,
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 36),
                                alignment: Alignment.center,
                                child: Text(
                                  '$_copies',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: _copies < 50
                                    ? () => setState(() => _copies++)
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
                            isSelected: !_isColor,
                            onTap: () => setState(() => _isColor = false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectableChip(
                            label: 'Full Color',
                            subtitle: '₹10.00 / page',
                            icon: Icons.palette_outlined,
                            isSelected: _isColor,
                            onTap: () => setState(() => _isColor = true),
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
                            isSelected: _sides == 'one-sided',
                            onTap: () =>
                                setState(() => _sides = 'one-sided'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelectableChip(
                            label: 'Double-Sided',
                            subtitle: '10% Duplex discount',
                            icon: Icons.auto_stories_outlined,
                            isSelected: _sides != 'one-sided',
                            onTap: () => setState(
                                () => _sides = 'two-sided-long-edge'),
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
                        final isSelected = _paperSize == size;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(() => _paperSize = size),
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
                    title: 'Page Range',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<bool>(
                                value: false,
                                groupValue: _isCustomRange,
                                title: const Text('All Pages',
                                    style: TextStyle(fontSize: 14)),
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppTheme.primary,
                                onChanged: (v) {
                                  setState(() => _isCustomRange = false);
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<bool>(
                                value: true,
                                groupValue: _isCustomRange,
                                title: const Text('Custom Range',
                                    style: TextStyle(fontSize: 14)),
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppTheme.primary,
                                onChanged: (v) {
                                  setState(() => _isCustomRange = true);
                                },
                              ),
                            ),
                          ],
                        ),
                        if (_isCustomRange) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _rangeController,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 1-3 or 1,2,5',
                              prefixIcon: Icon(Icons.format_list_numbered,
                                  size: 20),
                            ),
                            onChanged: (_) => setState(() {}),
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
                            color: AppTheme.danger.withOpacity(0.3)),
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
                          color: Colors.black.withOpacity(0.03),
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
                                const Text(
                                  'Estimated Total',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${_estimatedTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
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
