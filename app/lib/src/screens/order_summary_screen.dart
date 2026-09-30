import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import '../providers/document_provider.dart';
import '../providers/config_provider.dart';
import '../providers/order_provider.dart';
import '../utils/price_calculator.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/cards/document_card.dart';
import '../widgets/cards/pricing_breakdown_card.dart';
import '../widgets/feedback/custom_snackbar.dart';
import '../widgets/layout/app_scaffold.dart';
import '../widgets/layout/bottom_action_bar.dart';
import '../widgets/status/step_progress_indicator.dart';
import 'payment_screen.dart';

class OrderSummaryScreen extends StatelessWidget {
  const OrderSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docProvider = context.watch<DocumentProvider>();
    final configProvider = context.watch<ConfigProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final docs = docProvider.documents;

    final breakdown = PriceCalculator.calculateOrderBreakdown(
      docs.map((d) => PricingItemInput(
        pages: d.pageCount,
        config: configProvider.getConfiguration(d.id, defaultPages: d.pageCount),
      )).toList(),
    );

    return AppScaffold(
      title: 'Order Summary',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepProgressIndicator(currentStep: 3),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Review Documents', style: AppTypography.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ...docs.map((doc) {
                    final config = configProvider.getConfiguration(doc.id, defaultPages: doc.pageCount);
                    return DocumentCard(
                      document: doc,
                      configuration: config,
                      showConfigureButton: false,
                    );
                  }),
                  const SizedBox(height: AppSpacing.md),
                  PricingBreakdownCard(breakdown: breakdown),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: AppSpacing.cardPadding,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security, color: AppColors.primary, size: 20),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Your print job is generated securely with dynamic 6-digit pickup OTP. Documents are never stored permanently.',
                            style: AppTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          text: 'Proceed to Payment',
          icon: Icons.payment,
          isLoading: orderProvider.isLoading,
          onPressed: () async {
            final order = await orderProvider.createOrder(
              documents: docs,
              configurations: configProvider.configurations,
            );

            if (order != null && context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaymentScreen(order: order),
                ),
              );
            } else if (context.mounted) {
              CustomSnackBar.showError(
                context,
                orderProvider.errorMessage ?? 'Could not initialize order.',
              );
            }
          },
        ),
      ),
    );
  }
}
