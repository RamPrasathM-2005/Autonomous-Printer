// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/document.dart';
import '../services/document_bytes_cache.dart';

@JS('renderPdfToCanvas')
external void _renderPdfToCanvas(
  JSString canvasId,
  JSString base64Data,
  JSNumber pageNumber,
);

class RealDocumentPreviewWidget extends StatefulWidget {
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
  State<RealDocumentPreviewWidget> createState() =>
      _RealDocumentPreviewWidgetState();
}

class _RealDocumentPreviewWidgetState extends State<RealDocumentPreviewWidget> {
  static final Set<String> _registeredViews = {};
  String? _viewType;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _setupView();
    _triggerRender();
  }

  @override
  void didUpdateWidget(covariant RealDocumentPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id ||
        oldWidget.isLandscape != widget.isLandscape) {
      _setupView();
      _triggerRender();
    }
  }

  void _setupView() {
    final doc = widget.document;
    final bytes = DocumentBytesCache.get(doc.id);
    if (doc.isPdf && bytes != null && !widget.isThumbnail) {
      final viewId = 'pdf-canvas-view-${doc.id}';
      final canvasId = 'pdf-canvas-${doc.id}';

      if (!_registeredViews.contains(viewId)) {
        ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
          final container = html.DivElement()
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.display = 'flex'
            ..style.alignItems = 'center'
            ..style.justifyContent = 'center'
            ..style.backgroundColor = '#FFFFFF'
            ..style.overflow = 'auto';

          final canvas = html.CanvasElement()
            ..id = canvasId
            ..style.maxWidth = '100%'
            ..style.maxHeight = '100%'
            ..style.boxShadow = '0 2px 8px rgba(0,0,0,0.1)'
            ..style.borderRadius = '4px';

          container.children.add(canvas);
          return container;
        });
        _registeredViews.add(viewId);
      }
      _viewType = viewId;
    }
  }

  void _triggerRender() {
    final doc = widget.document;
    final bytes = DocumentBytesCache.get(doc.id);
    if (doc.isPdf && bytes != null && !widget.isThumbnail) {
      final base64Str = base64Encode(bytes);
      final canvasId = 'pdf-canvas-${doc.id}';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          try {
            _renderPdfToCanvas(
              canvasId.toJS,
              base64Str.toJS,
              _currentPage.toJS,
            );
          } catch (_) {}
        });
      });
    }
  }

  void _changePage(int delta) {
    final newPage = (_currentPage + delta).clamp(1, widget.document.pages);
    if (newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
      });
      _triggerRender();
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final bytes = DocumentBytesCache.get(doc.id);

    // 1. If it is an image and we have cached bytes
    if (!doc.isPdf && bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.isThumbnail ? 4 : 8),
        child: Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.isThumbnail ? BoxFit.cover : BoxFit.contain,
        ),
      );
    }

    // 2. If it is a PDF and we are rendering canvas view on web
    if (doc.isPdf && _viewType != null && !widget.isThumbnail) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: HtmlElementView(viewType: _viewType!)),
            if (doc.pages > 1)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _currentPage > 1 ? () => _changePage(-1) : null,
                        child: Icon(
                          Icons.chevron_left,
                          size: 16,
                          color: _currentPage > 1
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Page $_currentPage of ${doc.pages}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _currentPage < doc.pages
                            ? () => _changePage(1)
                            : null,
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: _currentPage < doc.pages
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // 3. Thumbnail / Fallback
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(widget.isThumbnail ? 6 : 8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            doc.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
            size: widget.isThumbnail ? 22 : 36,
            color: doc.isPdf ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
          ),
          if (!widget.isThumbnail) ...[
            const SizedBox(height: 8),
            Text(
              doc.filename,
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
              '${doc.pages} ${doc.pages == 1 ? 'page' : 'pages'} · ${doc.formattedSize}',
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ] else ...[
            const SizedBox(height: 2),
            Text(
              '${doc.pages}p',
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
