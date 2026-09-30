import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import '../models/print_configuration_model.dart';
import '../providers/document_provider.dart';
import '../providers/config_provider.dart';
import '../utils/formatters.dart';
import '../utils/price_calculator.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/forms/copies_stepper.dart';
import '../widgets/forms/page_range_input.dart';
import '../widgets/forms/segmented_toggle.dart';
import '../widgets/layout/app_scaffold.dart';
import '../widgets/layout/bottom_action_bar.dart';
import '../widgets/feedback/custom_snackbar.dart';

class PrintConfigurationScreen extends StatefulWidget {
  final String documentId;

  const PrintConfigurationScreen({
    super.key,
    required this.documentId,
  });

  @override
  State<PrintConfigurationScreen> createState() => _PrintConfigurationScreenState();
}

class _PrintConfigurationScreenState extends State<PrintConfigurationScreen> {
  late ColorMode _colorMode;
  late DuplexMode _duplexMode;
  late PrintOrientation _orientation;
  late int _copies;
  late String _pageRange;

  @override
  void initState() {
    super.initState();
    final configProvider = context.read<ConfigProvider>();
    final docProvider = context.read<DocumentProvider>();
    final doc = docProvider.getDocumentById(widget.documentId);
    final initial = configProvider.getConfiguration(widget.documentId, defaultPages: doc?.pageCount ?? 1);

    _colorMode = initial.colorMode;
    _duplexMode = initial.duplexMode;
    _orientation = initial.orientation;
    _copies = initial.copies;
    _pageRange = initial.pageRange;
  }

  void _saveSettings() {
    final docProvider = context.read<DocumentProvider>();
    final configProvider = context.read<ConfigProvider>();
    final doc = docProvider.getDocumentById(widget.documentId);

    final updated = PrintConfigurationModel(
      documentId: widget.documentId,
      colorMode: _colorMode,
      duplexMode: _duplexMode,
      orientation: _orientation,
      copies: _copies,
      pageRange: _pageRange,
    );

    configProvider.updateConfiguration(widget.documentId, updated, doc?.pageCount ?? 1);
    CustomSnackBar.showSuccess(context, 'Settings updated for ${doc?.name ?? "document"}');
    Navigator.of(context).pop();
  }

  void _applyToAllDocuments() {
    final docProvider = context.read<DocumentProvider>();
    final configProvider = context.read<ConfigProvider>();

    final base = PrintConfigurationModel(
      documentId: widget.documentId,
      colorMode: _colorMode,
      duplexMode: _duplexMode,
      orientation: _orientation,
      copies: _copies,
      pageRange: _pageRange,
    );

    configProvider.applyToAll(
      base,
      docProvider.documents,
    );
    CustomSnackBar.showSuccess(context, 'Applied settings to all ${docProvider.documents.length} documents');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final docProvider = context.watch<DocumentProvider>();
    final doc = docProvider.getDocumentById(widget.documentId);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (doc == null) {
      return const AppScaffold(
        title: 'Configure Print',
        body: Center(child: Text('Document not found')),
      );
    }

    final currentConfig = PrintConfigurationModel(
      documentId: widget.documentId,
      colorMode: _colorMode,
      duplexMode: _duplexMode,
      orientation: _orientation,
      copies: _copies,
      pageRange: _pageRange,
    );

    final itemCost = PriceCalculator.calculateItemCost(
      totalDocumentPages: doc.pageCount,
      config: currentConfig,
    );

    return AppScaffold(
      title: 'Print Settings',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Document Header
            Container(
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: isDark ? AppColors.surfaceVariantDark : AppColors.outlineVariantLight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: AppColors.primary, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.name, style: AppTypography.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '${doc.pageCount} ${doc.pageCount == 1 ? "Page" : "Pages"} total • ${AppFormatters.formatFileSize(doc.sizeBytes)}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.outlineLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Color Mode Toggle
            const Text('Color Mode', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            SegmentedToggle<ColorMode>(
              selectedValue: _colorMode,
              options: const [
                SegmentedToggleOption(
                  value: ColorMode.blackAndWhite,
                  label: 'Black & White',
                  subtitle: '₹2.00 / page',
                  icon: Icons.format_color_text,
                ),
                SegmentedToggleOption(
                  value: ColorMode.color,
                  label: 'Full Color',
                  subtitle: '₹10.00 / page',
                  icon: Icons.palette_outlined,
                ),
              ],
              onSelected: (val) => setState(() => _colorMode = val),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Duplex Sides Toggle
            const Text('Sides per Sheet', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            SegmentedToggle<DuplexMode>(
              selectedValue: _duplexMode,
              options: const [
                SegmentedToggleOption(
                  value: DuplexMode.singleSided,
                  label: '1-Sided (Single)',
                  subtitle: 'Standard',
                  icon: Icons.filter_1,
                ),
                SegmentedToggleOption(
                  value: DuplexMode.doubleSided,
                  label: '2-Sided (Duplex)',
                  subtitle: 'Save Paper & Cost',
                  icon: Icons.filter_2,
                ),
              ],
              onSelected: (val) => setState(() => _duplexMode = val),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Number of Copies
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Number of Copies', style: AppTypography.titleMedium),
                CopiesStepper(
                  value: _copies,
                  onChanged: (val) => setState(() => _copies = val),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Orientation
            const Text('Orientation', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            SegmentedToggle<PrintOrientation>(
              selectedValue: _orientation,
              options: const [
                SegmentedToggleOption(
                  value: PrintOrientation.portrait,
                  label: 'Portrait',
                  icon: Icons.stay_current_portrait,
                ),
                SegmentedToggleOption(
                  value: PrintOrientation.landscape,
                  label: 'Landscape',
                  icon: Icons.stay_current_landscape,
                ),
              ],
              onSelected: (val) => setState(() => _orientation = val),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Page Range Selector
            const Text('Pages to Print', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            PageRangeInput(
              initialValue: _pageRange,
              totalPages: doc.pageCount,
              onChanged: (val) => setState(() => _pageRange = val),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Apply To All Button if multiple documents exist
            if (docProvider.documents.length > 1) ...[
              Center(
                child: TextButton.icon(
                  onPressed: _applyToAllDocuments,
                  icon: const Icon(Icons.copy_all),
                  label: Text('Apply these settings to all ${docProvider.documents.length} files'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item Cost',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.outlineLight),
                  ),
                  Text(
                    AppFormatters.formatCurrency(itemCost),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.primaryDark : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PrimaryButton(
                text: 'Save Settings',
                icon: Icons.check,
                onPressed: _saveSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
