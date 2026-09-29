import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import 'payment_screen.dart';

class PrintOptionsScreen extends StatefulWidget {
  final UploadedDocument document;

  const PrintOptionsScreen({super.key, required this.document});

  @override
  State<PrintOptionsScreen> createState() => _PrintOptionsScreenState();
}

class _PrintOptionsScreenState extends State<PrintOptionsScreen> {
  final ApiService _apiService = ApiService();

  int _copies = 1;
  bool _isColor = false;
  String _sides = 'one-sided';
  String _paperSize = 'A4';
  String _orientation = 'portrait';
  bool _isCustomRange = false;

  final TextEditingController _rangeController = TextEditingController();
  bool _isValidating = false;
  String? _validationError;

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  double get _estimatedTotal {
    final ratePerPage = _isColor ? 10.0 : 2.0;
    int pages = widget.document.pages;
    if (_isCustomRange && _rangeController.text.isNotEmpty) {
      // rough client preview estimate
      final parts = _rangeController.text.split('-');
      if (parts.length == 2) {
        int? start = int.tryParse(parts[0]);
        int? end = int.tryParse(parts[1]);
        if (start != null && end != null && end >= start) {
          pages = (end - start + 1);
        }
      }
    }
    return pages * _copies * ratePerPage;
  }

  Future<void> _submitOrder() async {
    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    final stationId = ApiConfig.selectedStationId ?? 'PRINT-SERVER-001';
    final range = _isCustomRange ? _rangeController.text.trim() : 'all';

    final settings = PrintSettings(
      pageRange: range.isEmpty ? 'all' : range,
      copies: _copies,
      colour: _isColor,
      sides: _sides,
      paperSize: _paperSize,
      orientation: _orientation,
    );

    try {
      final order = await _apiService.createOrder(
        documentId: widget.document.documentId,
        printServerId: stationId,
        printSettings: settings,
      );

      setState(() {
        _isValidating = false;
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PaymentScreen(order: order, document: widget.document),
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
      appBar: AppBar(
        title: const Text('Print Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Document summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primaryLight, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.document.originalFilename,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.document.pages} Total Pages  •  ${widget.document.formattedSize}',
                          style: const TextStyle(fontSize: 13, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Number of copies
            _sectionHeader('Number of Copies'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Copies', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _copies > 1 ? () => setState(() => _copies--) : null,
                        icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryLight),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_copies',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: _copies < 99 ? () => setState(() => _copies++) : null,
                        icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryLight),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Color Mode Selection
            _sectionHeader('Color Mode'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _modeOption(
                    title: 'Black & White',
                    subtitle: '₹2.00 / page',
                    icon: Icons.filter_b_and_w_rounded,
                    isSelected: !_isColor,
                    onTap: () => setState(() => _isColor = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modeOption(
                    title: 'Full Color',
                    subtitle: '₹10.00 / page',
                    icon: Icons.color_lens_rounded,
                    isSelected: _isColor,
                    onTap: () => setState(() => _isColor = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Duplex / Sides
            _sectionHeader('Sides (Duplex)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _choiceChip(
                    label: 'Single-Sided',
                    isSelected: _sides == 'one-sided',
                    onTap: () => setState(() => _sides = 'one-sided'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _choiceChip(
                    label: '2-Sided (Long)',
                    isSelected: _sides == 'two-sided-long-edge',
                    onTap: () => setState(() => _sides = 'two-sided-long-edge'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _choiceChip(
                    label: '2-Sided (Short)',
                    isSelected: _sides == 'two-sided-short-edge',
                    onTap: () => setState(() => _sides = 'two-sided-short-edge'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Page range
            _sectionHeader('Page Range'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _choiceChip(
                    label: 'All Pages (1-${widget.document.pages})',
                    isSelected: !_isCustomRange,
                    onTap: () => setState(() => _isCustomRange = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _choiceChip(
                    label: 'Custom Range',
                    isSelected: _isCustomRange,
                    onTap: () => setState(() => _isCustomRange = true),
                  ),
                ),
              ],
            ),
            if (_isCustomRange) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _rangeController,
                decoration: const InputDecoration(
                  hintText: 'e.g. 1-5 or 1,3,5',
                  labelText: 'Custom Page Range',
                  prefixIcon: Icon(Icons.pages_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 20),

            // Orientation & Paper Size
            _sectionHeader('Paper Size & Layout'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _paperSize,
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceDark,
                        items: ['A4', 'Letter', 'Legal']
                            .map((s) => DropdownMenuItem(value: s, child: Text('Size: $s')))
                            .toList(),
                        onChanged: (v) => setState(() => _paperSize = v ?? 'A4'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _orientation,
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceDark,
                        items: const [
                          DropdownMenuItem(value: 'portrait', child: Text('Portrait')),
                          DropdownMenuItem(value: 'landscape', child: Text('Landscape')),
                        ],
                        onChanged: (v) => setState(() => _orientation = v ?? 'portrait'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Estimated Price Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryDark.withOpacity(0.4), AppTheme.primary.withOpacity(0.2)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryLight.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated Total', style: TextStyle(fontSize: 13, color: Colors.white70)),
                      Text('Authoritative rate by backend', style: TextStyle(fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                  Text(
                    '₹${_estimatedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Error display
            if (_validationError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_rounded, color: AppTheme.danger, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Job Validation Rejected',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _validationError!,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Validate & Proceed
            ElevatedButton(
              onPressed: _isValidating ? null : _submitOrder,
              child: _isValidating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Validating Job with Backend...'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Validate Job & Proceed to Payment'),
                        SizedBox(width: 8),
                        Icon(Icons.payment_rounded, size: 18),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
    );
  }

  Widget _choiceChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.25) : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLight : Colors.white10,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _modeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.2) : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLight : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? AppTheme.primaryLight : Colors.white54),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
