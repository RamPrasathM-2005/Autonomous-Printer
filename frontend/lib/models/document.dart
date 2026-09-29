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
