import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import '../models/print_job_model.dart';
import '../providers/print_status_provider.dart';
import '../widgets/buttons/secondary_button.dart';
import '../widgets/layout/app_scaffold.dart';
import '../widgets/overlays/confirmation_dialog.dart';
import 'completed_screen.dart';

class PrintStatusScreen extends StatefulWidget {
  final String jobId;
  final String orderId;

  const PrintStatusScreen({
    super.key,
    required this.jobId,
    required this.orderId,
  });

  @override
  State<PrintStatusScreen> createState() => _PrintStatusScreenState();
}

class _PrintStatusScreenState extends State<PrintStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrintStatusProvider>().startTracking(widget.jobId, widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusProvider = context.watch<PrintStatusProvider>();
    final job = statusProvider.currentJob;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // If job is completed, allow user to transition or show Completed action
    if (job?.status == PrintJobStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CompletedScreen(orderId: widget.orderId),
          ),
        );
      });
    }

    return AppScaffold(
      title: 'Live Print Telemetry',
      showBackButton: false,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            // Circular / Gauge status animation container
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: job?.progress ?? 0.2,
                    strokeWidth: 8,
                    backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.outlineVariantLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getStatusColor(job?.status ?? PrintJobStatus.queued),
                    ),
                  ),
                  Center(
                    child: Icon(
                      _getStatusIcon(job?.status ?? PrintJobStatus.queued),
                      size: 48,
                      color: _getStatusColor(job?.status ?? PrintJobStatus.queued),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Live State Title
            Text(
              job?.readableStatus ?? 'Connecting to Print Agent...',
              style: AppTypography.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Job Ref: ${widget.jobId} • Station: ${job?.printerName ?? "Kiosk #1"}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.outlineLight),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Printing Progress',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.outlineLight),
                      ),
                      Text(
                        '${((job?.progress ?? 0.0) * 100).toInt()}%',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.primaryDark : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: LinearProgressIndicator(
                      value: job?.progress ?? 0.1,
                      minHeight: 10,
                      backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.outlineVariantLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Hardware Telemetry Steps
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
                  const Text('Agent Status Stream', style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  _buildStatusRow(
                    title: 'CUPS Spooler Queued',
                    isDone: (job?.progress ?? 0) >= 0.1,
                    isActive: job?.status == PrintJobStatus.queued,
                  ),
                  _buildStatusRow(
                    title: 'Rasterizing Document PDF',
                    isDone: (job?.progress ?? 0) >= 0.35,
                    isActive: job?.status == PrintJobStatus.processing,
                  ),
                  _buildStatusRow(
                    title: 'Laser Engine Printing & Fusing',
                    isDone: (job?.progress ?? 0) >= 0.9,
                    isActive: job?.status == PrintJobStatus.printing,
                  ),
                  _buildStatusRow(
                    title: 'Discharged to Output Bin',
                    isDone: (job?.progress ?? 0) >= 1.0,
                    isActive: job?.status == PrintJobStatus.completed,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            if (job?.status != PrintJobStatus.completed) ...[
              SecondaryButton(
                text: 'Cancel Printing',
                textColor: AppColors.error,
                onPressed: () async {
                  final confirmed = await ConfirmationDialog.show(
                    context,
                    title: 'Cancel Print Job?',
                    message: 'Are you sure you want to stop this print job? Any unprocessed pages will be cancelled.',
                    confirmText: 'Yes, Cancel',
                    isDestructive: true,
                  );
                  if (confirmed == true && context.mounted) {
                    statusProvider.cancelJob();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required String title,
    required bool isDone,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          if (isDone)
            const Icon(Icons.check_circle, color: AppColors.success, size: 20)
          else if (isActive)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            const Icon(Icons.radio_button_unchecked, color: AppColors.outlineLight, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(PrintJobStatus status) {
    switch (status) {
      case PrintJobStatus.completed:
        return AppColors.success;
      case PrintJobStatus.failed:
      case PrintJobStatus.cancelled:
        return AppColors.error;
      case PrintJobStatus.printing:
        return AppColors.statusPrinting;
      default:
        return AppColors.primary;
    }
  }

  IconData _getStatusIcon(PrintJobStatus status) {
    switch (status) {
      case PrintJobStatus.completed:
        return Icons.task_alt;
      case PrintJobStatus.failed:
        return Icons.error_outline;
      case PrintJobStatus.printing:
        return Icons.print;
      case PrintJobStatus.processing:
        return Icons.auto_awesome;
      default:
        return Icons.hourglass_top;
    }
  }
}
