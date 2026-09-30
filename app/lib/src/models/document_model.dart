enum DocumentUploadStatus { pending, uploading, uploaded, error }

class DocumentModel {
  final String id;
  final String name;
  final String localPath;
  final int sizeBytes;
  final String mimeType;
  final int pageCount;
  final String? thumbnailUrl;
  final DocumentUploadStatus status;
  final double uploadProgress; // 0.0 to 1.0
  final String? errorMessage;

  const DocumentModel({
    required this.id,
    required this.name,
    required this.localPath,
    required this.sizeBytes,
    required this.mimeType,
    this.pageCount = 1,
    this.thumbnailUrl,
    this.status = DocumentUploadStatus.pending,
    this.uploadProgress = 0.0,
    this.errorMessage,
  });

  DocumentModel copyWith({
    String? id,
    String? name,
    String? localPath,
    int? sizeBytes,
    String? mimeType,
    int? pageCount,
    String? thumbnailUrl,
    DocumentUploadStatus? status,
    double? uploadProgress,
    String? errorMessage,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      pageCount: pageCount ?? this.pageCount,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      status: status ?? this.status,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['documentId'] ?? json['id'] ?? '',
      name: json['fileName'] ?? json['name'] ?? 'Unnamed Document',
      localPath: json['localPath'] ?? '',
      sizeBytes: json['fileSize'] ?? json['sizeBytes'] ?? 0,
      mimeType: json['mimeType'] ?? 'application/pdf',
      pageCount: json['pageCount'] ?? 1,
      thumbnailUrl: json['thumbnailUrl'],
      status: DocumentUploadStatus.uploaded,
      uploadProgress: 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentId': id,
      'fileName': name,
      'localPath': localPath,
      'sizeBytes': sizeBytes,
      'mimeType': mimeType,
      'pageCount': pageCount,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  String get fileExtension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'PDF';
  }
}
