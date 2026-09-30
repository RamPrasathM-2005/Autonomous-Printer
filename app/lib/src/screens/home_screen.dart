import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import '../providers/app_provider.dart';
import '../providers/printer_status_provider.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/cards/kiosk_info_card.dart';
import '../widgets/cards/printer_status_banner.dart';
import 'upload_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final printerProvider = context.watch<PrinterStatusProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autonomous Printer'),
        actions: [
          IconButton(
            icon: Icon(appProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => appProvider.toggleTheme(),
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => printerProvider.refreshStatus(),
            tooltip: 'Refresh status',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kiosk Connection Information
            KioskInfoCard(
              stationName: appProvider.stationName,
              stationId: appProvider.stationId,
            ),
            const SizedBox(height: AppSpacing.md),

            // Hardware Health Banner
            PrinterStatusBanner(status: printerProvider.status),
            const SizedBox(height: AppSpacing.xl),

            // Main Upload CTA Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(
                  color: isDark ? AppColors.surfaceVariantDark : AppColors.outlineVariantLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: isDark ? AppColors.primaryDark : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Ready to Print Documents', style: AppTypography.headlineLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Upload your PDF, DOCX, PPTX, or image files to configure print settings and pay securely.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.outlineLight),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    text: 'Start Printing (Upload Files)',
                    icon: Icons.upload_file,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UploadScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Standard Rate Card
            const Text('Transparent Printing Rates', style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _buildRateCard(
                    context,
                    title: 'Black & White',
                    singlePrice: '₹2.00',
                    duplexPrice: '₹3.50',
                    icon: Icons.format_color_text,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildRateCard(
                    context,
                    title: 'Color Laser',
                    singlePrice: '₹10.00',
                    duplexPrice: '₹18.00',
                    icon: Icons.palette_outlined,
                    color: AppColors.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // How It Works Steps
            const Text('How Self-Service Works', style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            _buildStepItem(
              number: '1',
              title: 'Upload Documents',
              subtitle: 'Select files from your device. PDF, DOCX, PPTX, images supported.',
            ),
            _buildStepItem(
              number: '2',
              title: 'Customize Print Settings',
              subtitle: 'Choose color mode, duplex, copies, and specific page ranges.',
            ),
            _buildStepItem(
              number: '3',
              title: 'Instant Online Payment',
              subtitle: 'Pay via UPI, Cards, or NetBanking with zero waiting lines.',
            ),
            _buildStepItem(
              number: '4',
              title: 'Enter Pickup OTP',
              subtitle: 'Input your 6-digit OTP on the physical kiosk to release printouts.',
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildRateCard(
    BuildContext context, {
    required String title,
    required String singlePrice,
    required String duplexPrice,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.surfaceVariantDark : AppColors.outlineVariantLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(title, style: AppTypography.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('1-Sided: $singlePrice/page', style: AppTypography.bodySmall),
          const SizedBox(height: 2),
          Text('2-Sided: $duplexPrice/sheet', style: AppTypography.bodySmall),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.outlineLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
