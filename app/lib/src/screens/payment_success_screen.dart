import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import '../models/order_model.dart';
import '../providers/otp_provider.dart';
import '../utils/formatters.dart';
import '../widgets/buttons/primary_button.dart';
import 'otp_screen.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final OrderModel order;

  const PaymentSuccessScreen({
    super.key,
    required this.order,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger OTP fetch for order
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OtpProvider>().fetchOtp(widget.order.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.successContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('Payment Successful!', style: AppTypography.displayMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Paid ${AppFormatters.formatCurrency(widget.order.total)} securely',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.outlineLight),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Order Confirmation Receipt Card
              Container(
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: isDark ? AppColors.surfaceVariantDark : AppColors.outlineVariantLight,
                  ),
                ),
                child: Column(
                  children: [
                    _buildRow('Order Reference', widget.order.orderId),
                    const SizedBox(height: AppSpacing.sm),
                    _buildRow('Documents', '${widget.order.items.length} Files'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildRow('Payment Gateway', 'Razorpay Secure'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildRow('Time', AppFormatters.formatDateTime(DateTime.now())),
                  ],
                ),
              ),
              const Spacer(),

              PrimaryButton(
                text: 'View Pickup OTP & Track',
                icon: Icons.vpn_key_outlined,
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => OTPScreen(orderId: widget.order.orderId),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.outlineLight)),
        Text(value, style: AppTypography.titleMedium),
      ],
    );
  }
}
