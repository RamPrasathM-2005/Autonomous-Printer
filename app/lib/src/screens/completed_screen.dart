import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import '../providers/document_provider.dart';
import '../providers/config_provider.dart';
import '../providers/order_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/otp_provider.dart';
import '../providers/print_status_provider.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/buttons/secondary_button.dart';
import 'home_screen.dart';
import 'upload_screen.dart';

class CompletedScreen extends StatefulWidget {
  final String orderId;

  const CompletedScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends State<CompletedScreen> {
  int _selectedRating = 5;

  void _resetSession(BuildContext context) {
    context.read<DocumentProvider>().reset();
    context.read<ConfigProvider>().reset();
    context.read<OrderProvider>().reset();
    context.read<PaymentProvider>().reset();
    context.read<OtpProvider>().reset();
    context.read<PrintStatusProvider>().reset();
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
                  Icons.celebration_rounded,
                  color: AppColors.success,
                  size: 52,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('Printout Collected!', style: AppTypography.displayMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Thank you for using Autonomous Printer. Please collect all your printed pages from the output tray.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.outlineLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Feedback rating card
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
                    const Text('Rate your printing experience', style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        return IconButton(
                          icon: Icon(
                            star <= _selectedRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () => setState(() => _selectedRating = star),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Action buttons
              PrimaryButton(
                text: 'Print More Documents',
                icon: Icons.add_to_photos_outlined,
                onPressed: () {
                  _resetSession(context);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const UploadScreen()),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                text: 'Back to Home',
                icon: Icons.home_outlined,
                onPressed: () {
                  _resetSession(context);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
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
}
