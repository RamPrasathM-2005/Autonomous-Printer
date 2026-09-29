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

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory UploadedDocument.fromJson(Map<String, dynamic> json) {
    return UploadedDocument(
      documentId: json['documentId'] ?? json['id'] ?? '',
      originalFilename: json['originalFilename'] ?? json['original_filename'] ?? 'file',
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
  String sides; // 'one-sided' or 'two-sided-long-edge'
  String paperSize; // Fixed to 'A4'
  String orientation; // 'portrait' or 'landscape'
  bool isCustomRange;
  String customRange;

  DocumentPrintConfig({
    required this.document,
    this.copies = 1,
    this.isColor = false,
    this.sides = 'one-sided',
    this.paperSize = 'A4',
    this.orientation = 'portrait',
    this.isCustomRange = false,
    this.customRange = '',
  });

  String get colorDescription => isColor ? 'Full Color' : 'Black & White';
  String get sidesDescription => sides == 'one-sided' ? 'Single-Sided' : 'Double-Sided';
  String get pageRangeDescription =>
      (isCustomRange && customRange.trim().isNotEmpty) ? customRange.trim() : 'All Pages';

  int get calculatedPages {
    if (!isCustomRange || customRange.trim().isEmpty) {
      return document.pages > 0 ? document.pages : 1;
    }
    final text = customRange.trim();
    final parts = text.split('-');
    if (parts.length == 2) {
      int? start = int.tryParse(parts[0].trim());
      int? end = int.tryParse(parts[1].trim());
      if (start != null && end != null && end >= start) {
        return (end - start + 1);
      }
    }
    return document.pages > 0 ? document.pages : 1;
  }

  double get estimatedCost {
    final rate = isColor ? 10.0 : 2.0;
    double cost = calculatedPages * copies * rate;
    if (sides != 'one-sided') {
      cost = cost * 0.9; // 10% duplex discount
    }
    return cost;
  }
}
