import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import '../providers/document_provider.dart';
import '../providers/config_provider.dart';
import '../utils/price_calculator.dart';
import '../utils/formatters.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/cards/document_card.dart';
import '../widgets/feedback/empty_state.dart';
import '../widgets/layout/app_scaffold.dart';
import '../widgets/layout/bottom_action_bar.dart';
import '../widgets/status/step_progress_indicator.dart';
import 'print_configuration_screen.dart';
import 'order_summary_screen.dart';

class UploadedDocumentsScreen extends StatelessWidget {
  const UploadedDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docProvider = context.watch<DocumentProvider>();
    final configProvider = context.watch<ConfigProvider>();
    final docs = docProvider.documents;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate live pricing breakdown for bottom summary bar
    final breakdown = PriceCalculator.calculateOrderBreakdown(
      docs.map((d) => PricingItemInput(
        pages: d.pageCount,
        config: configProvider.getConfiguration(d.id, defaultPages: d.pageCount),
      )).toList(),
    );

    if (docs.isEmpty) {
      return AppScaffold(
        title: 'Uploaded Documents',
        body: EmptyState(
          title: 'No Documents Uploaded',
          description: 'Please upload files to configure your print settings.',
          actionText: 'Go to Upload',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    return AppScaffold(
      title: 'Configure Documents',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Add More Files',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepProgressIndicator(currentStep: 2),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Documents to Print (${docs.length})',
                style: AppTypography.headlineMedium,
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Files'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final config = configProvider.getConfiguration(doc.id, defaultPages: doc.pageCount);

                return DocumentCard(
                  document: doc,
                  configuration: config,
                  showConfigureButton: true,
                  onConfigure: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PrintConfigurationScreen(documentId: doc.id),
                      ),
                    );
                  },
                  onDelete: () => docProvider.removeDocument(doc.id),
                );
              },
            ),
          ),
        ],
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
                    'Estimated Cost',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.outlineLight),
                  ),
                  Text(
                    AppFormatters.formatCurrency(breakdown.grandTotal),
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
                text: 'Review Order',
                icon: Icons.checklist_rtl_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OrderSummaryScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
