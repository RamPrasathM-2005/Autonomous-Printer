import 'package:flutter/material.dart';

import '../models/document.dart';
import 'real_document_preview_stub.dart'
    if (dart.library.html) 'real_document_preview_web.dart';

class RealDocumentPreview extends StatelessWidget {
  final UploadedDocument document;
  final bool isLandscape;
  final bool isThumbnail;
  final double? width;
  final double? height;

  const RealDocumentPreview({
    super.key,
    required this.document,
    this.isLandscape = false,
    this.isThumbnail = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return RealDocumentPreviewWidget(
      document: document,
      isLandscape: isLandscape,
      isThumbnail: isThumbnail,
      width: width,
      height: height,
    );
  }
}
