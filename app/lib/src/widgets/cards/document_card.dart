import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_typography.dart';
import '../../models/document_model.dart';
import '../../models/print_configuration_model.dart';
import '../../utils/formatters.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final PrintConfigurationModel? configuration;
  final VoidCallback? onConfigure;
  final VoidCallback? onDelete;
  final bool showConfigureButton;

  const DocumentCard({
    super.key,
    required this.document,
    this.configuration,
    this.onConfigure,
    this.onDelete,
    this.showConfigureButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File Type Icon Container
                Container(
                  width: 48,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _getFileBadgeColor(document.fileExtension),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Center(
                    child: Text(
                      document.fileExtension,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Document Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name,
                        style: AppTypography.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${document.pageCount} ${document.pageCount == 1 ? "page" : "pages"} • ${AppFormatters.formatFileSize(document.sizeBytes)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                    onPressed: onDelete,
                    tooltip: 'Remove document',
                  ),
              ],
            ),
            if (configuration != null) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      _buildChip(
                        configuration!.colorMode == ColorMode.color ? 'Color' : 'B&W',
                        configuration!.colorMode == ColorMode.color
                            ? AppColors.tertiary
                            : AppColors.secondary,
                      ),
                      _buildChip(
                        configuration!.duplexMode == DuplexMode.doubleSided ? '2-Sided' : '1-Sided',
                        AppColors.primary,
                      ),
                      _buildChip(
                        '${configuration!.copies} ${configuration!.copies == 1 ? "copy" : "copies"}',
                        AppColors.outlineLight,
                      ),
                    ],
                  ),
                  Text(
                    AppFormatters.formatCurrency(configuration!.estimatedCost),
                    style: AppTypography.titleMedium.copyWith(
                      color: isDark ? AppColors.primaryDark : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            if (showConfigureButton && onConfigure != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onConfigure,
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Change Settings'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getFileBadgeColor(String ext) {
    switch (ext) {
      case 'PDF':
        return const Color(0xFFDC2626);
      case 'DOC':
      case 'DOCX':
        return const Color(0xFF2563EB);
      case 'PPT':
      case 'PPTX':
        return const Color(0xFFEA580C);
      case 'JPG':
      case 'JPEG':
      case 'PNG':
        return const Color(0xFF059669);
      default:
        return AppColors.secondary;
    }
  }
}
