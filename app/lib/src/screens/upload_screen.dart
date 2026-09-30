import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import '../models/document_model.dart';
import '../providers/document_provider.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/cards/document_card.dart';
import '../widgets/feedback/custom_snackbar.dart';
import '../widgets/layout/app_scaffold.dart';
import '../widgets/layout/bottom_action_bar.dart';
import '../widgets/status/step_progress_indicator.dart';
import 'uploaded_documents_screen.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docProvider = context.watch<DocumentProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppScaffold(
      title: 'Upload Documents',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1 of 4 Indicator
          const StepProgressIndicator(currentStep: 1),
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag & Drop / Tap to upload dropzone
                  GestureDetector(
                    onTap: docProvider.isPicking ? null : () => docProvider.pickAndUploadFiles(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.surfaceDark : Colors.white),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                        border: Border.all(
                          color: isDark ? AppColors.primaryDark : AppColors.primary,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.file_upload_outlined,
                              size: 40,
                              color: isDark ? AppColors.primaryDark : AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            docProvider.isPicking ? 'Selecting Files...' : 'Tap to Select Files',
                            style: AppTypography.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Supported formats: PDF, DOCX, PPTX, JPG, PNG (Max 50MB)',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.outlineLight),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (docProvider.isPicking)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () => docProvider.pickAndUploadFiles(),
                              icon: const Icon(Icons.add),
                              label: const Text('Browse Device'),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Quick Demo Samples (For convenience during testing / simulation)
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Or try quick sample files:', style: AppTypography.labelSmall),
                      TextButton(
                        onPressed: () {
                          docProvider.addSimulatedDocument(
                            name: 'Lab_Report_Final_V2.pdf',
                            pageCount: 8,
                            sizeBytes: 1420000,
                            extension: 'pdf',
                          );
                          docProvider.addSimulatedDocument(
                            name: 'Project_Presentation_Slides.pptx',
                            pageCount: 14,
                            sizeBytes: 3850000,
                            extension: 'pptx',
                          );
                          CustomSnackBar.showSuccess(context, 'Sample documents added to session');
                        },
                        child: const Text('+ Add Sample PDFs'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Uploaded files in current session
                  if (docProvider.documents.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected Files (${docProvider.documents.length})',
                          style: AppTypography.headlineMedium,
                        ),
                        Text(
                          '${docProvider.totalPages} Total Pages',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark ? AppColors.primaryDark : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...docProvider.documents.map((doc) {
                      if (doc.status == DocumentUploadStatus.uploading) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Padding(
                            padding: AppSpacing.cardPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        'Uploading ${doc.name}...',
                                        style: AppTypography.titleMedium,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                LinearProgressIndicator(
                                  value: doc.uploadProgress > 0 ? doc.uploadProgress : null,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return DocumentCard(
                        document: doc,
                        showConfigureButton: false,
                        onDelete: () => docProvider.removeDocument(doc.id),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: docProvider.documents.isNotEmpty
          ? BottomActionBar(
              child: PrimaryButton(
                text: 'Proceed to Settings (${docProvider.documents.length} Files)',
                icon: Icons.arrow_forward,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UploadedDocumentsScreen()),
                  );
                },
              ),
            )
          : null,
    );
  }
}
