import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import '../models/order_model.dart';
import '../models/payment_model.dart';
import '../providers/payment_provider.dart';
import '../utils/formatters.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/feedback/custom_snackbar.dart';
import '../widgets/layout/app_scaffold.dart';
import '../widgets/layout/bottom_action_bar.dart';
import 'payment_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final OrderModel order;

  const PaymentScreen({
    super.key,
    required this.order,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.upi;

  @override
  Widget build(BuildContext context) {
    final paymentProvider = context.watch<PaymentProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppScaffold(
      title: 'Payment',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Amount Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: isDark ? AppColors.surfaceVariantDark : AppColors.outlineVariantLight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Payable Amount',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.outlineLight),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppFormatters.formatCurrency(widget.order.total),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.primaryDark : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Order ID: ${widget.order.orderId}',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.outlineLight),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            const Text('Choose Payment Method', style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.sm),

            _buildPaymentOption(
              method: PaymentMethod.upi,
              title: 'UPI (GPay, PhonePe, Paytm, BHIM)',
              subtitle: 'Instant approval with 0% extra fees',
              icon: Icons.qr_code_2,
            ),
            _buildPaymentOption(
              method: PaymentMethod.card,
              title: 'Credit / Debit Cards',
              subtitle: 'Visa, MasterCard, RuPay',
              icon: Icons.credit_card,
            ),
            _buildPaymentOption(
              method: PaymentMethod.netbanking,
              title: 'NetBanking',
              subtitle: 'All major Indian banks supported',
              icon: Icons.account_balance,
            ),
            _buildPaymentOption(
              method: PaymentMethod.mock,
              title: 'Test Simulator Gateway',
              subtitle: 'Instant test sandbox approval',
              icon: Icons.developer_mode,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          text: 'Pay ${AppFormatters.formatCurrency(widget.order.total)}',
          icon: Icons.lock_outline,
          isLoading: paymentProvider.status == PaymentStatus.initiating ||
              paymentProvider.status == PaymentStatus.processing,
          onPressed: () async {
            final success = await paymentProvider.processPayment(
              orderId: widget.order.orderId,
              amountInRupees: widget.order.total,
              method: _selectedMethod,
            );

            if (success && context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => PaymentSuccessScreen(order: widget.order),
                ),
              );
            } else if (context.mounted) {
              CustomSnackBar.showError(
                context,
                paymentProvider.errorMessage ?? 'Payment failed. Please retry.',
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required PaymentMethod method,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedMethod == method;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(
          color: isSelected
              ? (isDark ? AppColors.primaryDark : AppColors.primary)
              : (isDark ? AppColors.surfaceVariantDark : AppColors.outlineVariantLight),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = method),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? (isDark ? AppColors.primaryDark : AppColors.primary)
                    : AppColors.outlineLight,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.outlineLight),
                    ),
                  ],
                ),
              ),
              Radio<PaymentMethod>(
                value: method,
                groupValue: _selectedMethod,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMethod = val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
