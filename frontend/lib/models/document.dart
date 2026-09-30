class UploadedDocument {
  final String documentId;
  final String originalFilename;
  final int pages;
  final int size;
  final String status;

  UploadedDocument({
    required this.documentId,
    required this.originalFilename,
    required this.pages,
    required this.size,
    required this.status,
  });

  String get id => documentId;
  String get filename => originalFilename;
  bool get isPdf => originalFilename.toLowerCase().endsWith('.pdf');

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory UploadedDocument.fromJson(Map<String, dynamic> json) {
    return UploadedDocument(
      documentId: json['documentId'] ?? json['id'] ?? '',
      originalFilename:
          json['originalFilename'] ?? json['original_filename'] ?? 'file',
      pages: json['pages'] ?? json['page_count'] ?? 1,
      size: json['size'] ?? json['file_size'] ?? 0,
      status: json['status'] ?? 'UPLOADED',
    );
  }
}

class DocumentPrintConfig {
  final UploadedDocument document;
  int copies;
  bool isColor;
  String sides; // 'one-sided', 'two-sided-long-edge', 'two-sided-short-edge'
  String paperSize; // 'A4', 'Letter', 'Legal'
  String printQuality; // 'Standard', 'High (600 DPI)', 'Draft'
  String rangeOption; // 'all', 'odd', 'even', 'custom'
  String customRange;
  String orientation; // 'portrait', 'landscape'

  DocumentPrintConfig({
    required this.document,
    this.copies = 1,
    this.isColor = false,
    this.sides = 'one-sided',
    this.paperSize = 'A4',
    this.printQuality = 'Standard',
    this.rangeOption = 'all',
    this.customRange = '',
    this.orientation = 'portrait',
  });

  bool get isCustomRange => rangeOption == 'custom';

  String get colorDescription => isColor ? 'Full Color' : 'Black & White';
  String get sidesDescription =>
      sides == 'one-sided' ? 'Single-Sided' : 'Double-Sided';
  String get pageRangeDescription =>
      (isCustomRange && customRange.trim().isNotEmpty)
      ? customRange.trim()
      : 'All Pages';

  int get calculatedPages {
    final total = document.pages;
    if (rangeOption == 'all') return total;
    if (rangeOption == 'odd') return (total / 2).ceil();
    if (rangeOption == 'even') return (total / 2).floor();
    if (rangeOption == 'custom' && customRange.isNotEmpty) {
      try {
        int count = 0;
        final parts = customRange.split(',');
        for (var part in parts) {
          part = part.trim();
          if (part.contains('-')) {
            final range = part.split('-');
            if (range.length == 2) {
              final start = int.parse(range[0]);
              final end = int.parse(range[1]);
              count += (end - start + 1).clamp(0, total);
            }
          } else {
            final page = int.parse(part);
            if (page >= 1 && page <= total) count++;
          }
        }
        return count > 0 ? count : total;
      } catch (_) {
        return total;
      }
    }
    return total;
  }

  double get estimatedCost {
    final perPageBase = isColor ? 5.0 : 2.0;
    final totalPg = calculatedPages;
    return totalPg * copies * perPageBase;
  }
}
