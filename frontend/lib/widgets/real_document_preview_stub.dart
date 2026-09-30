import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/document.dart';
import '../services/document_bytes_cache.dart';

class RealDocumentPreviewWidget extends StatelessWidget {
  final UploadedDocument document;
  final bool isLandscape;
  final bool isThumbnail;
  final double? width;
  final double? height;

  const RealDocumentPreviewWidget({
    super.key,
    required this.document,
    this.isLandscape = false,
    this.isThumbnail = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = DocumentBytesCache.get(document.id);

    if (!document.isPdf && bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(isThumbnail ? 4 : 8),
        child: Image.memory(
          bytes,
          width: width,
          height: height,
          fit: isThumbnail ? BoxFit.cover : BoxFit.contain,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(isThumbnail ? 6 : 8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            document.isPdf
                ? Icons.picture_as_pdf_rounded
                : Icons.image_rounded,
            size: isThumbnail ? 22 : 36,
            color: document.isPdf
                ? const Color(0xFFDC2626)
                : const Color(0xFF2563EB),
          ),
          if (!isThumbnail) ...[
            const SizedBox(height: 8),
            Text(
              document.filename,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${document.pages} ${document.pages == 1 ? 'page' : 'pages'} · ${document.formattedSize}',
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ] else ...[
            const SizedBox(height: 2),
            Text(
              '${document.pages}p',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
