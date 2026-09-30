import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import '../providers/otp_provider.dart';
import '../providers/print_status_provider.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/feedback/custom_snackbar.dart';
import '../widgets/feedback/loading_indicator.dart';
import '../widgets/layout/app_scaffold.dart';
import '../widgets/status/countdown_timer_widget.dart';
import 'print_status_screen.dart';

class OTPScreen extends StatelessWidget {
  final String orderId;

  const OTPScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    final otpProvider = context.watch<OtpProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (otpProvider.isLoading) {
      return const AppScaffold(
        title: 'Pickup OTP',
        showBackButton: false,
        body: LoadingIndicator(message: 'Generating secure pickup OTP...'),
      );
    }

    final otpCode = otpProvider.otpModel?.otp ?? '123456';

    return AppScaffold(
      title: 'Kiosk Pickup OTP',
      showBackButton: false,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Enter this OTP at the Kiosk Screen',
              style: AppTypography.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Walk up to the printer station and type this 6-digit release code to begin printing immediately.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.outlineLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // High-contrast OTP Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2B1D4F) : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(
                  color: isDark ? AppColors.primaryDark : AppColors.primary,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'RELEASE CODE',
                    style: AppTypography.labelSmall.copyWith(
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.onPrimaryContainerDark : AppColors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: otpCode.split('').map((char) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          char,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: isDark ? AppColors.primaryDark : AppColors.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: otpCode));
                      CustomSnackBar.showSuccess(context, 'OTP copied to clipboard: $otpCode');
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Code'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Expiry countdown timer
            CountdownTimerWidget(
              remainingDuration: otpProvider.remainingTime,
              isExpired: otpProvider.isExpired,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Instruction Card
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Station Instructions', style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _buildInstruction('1. Locate the physical tablet display on the printer.'),
                  _buildInstruction('2. Tap "Enter Pickup OTP" on the kiosk.'),
                  _buildInstruction('3. Type the 6-digit code above and press Enter.'),
                  _buildInstruction('4. Wait for tray output & retrieve printed sheets.'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            PrimaryButton(
              text: 'Track Print Progress Live',
              icon: Icons.graphic_eq_rounded,
              onPressed: () {
                context.read<PrintStatusProvider>().startTracking('JOB-$orderId', orderId);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PrintStatusScreen(jobId: 'JOB-$orderId', orderId: orderId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(text, style: AppTypography.bodySmall),
    );
  }
}
