import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document_model.dart';
import '../services/document_service.dart';

class DocumentProvider with ChangeNotifier {
  final DocumentService _service = DocumentService();
  final List<DocumentModel> _documents = [];
  bool _isPicking = false;
  String? _errorMessage;

  List<DocumentModel> get documents => List.unmodifiable(_documents);
  bool get isPicking => _isPicking;
  String? get errorMessage => _errorMessage;
  bool get hasDocuments => _documents.isNotEmpty;

  int get totalPages => _documents.fold(0, (sum, doc) => sum + doc.pageCount);

  Future<void> pickAndUploadFiles() async {
    _isPicking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'pptx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        for (final platformFile in result.files) {
          if (platformFile.path == null) continue;

          final file = File(platformFile.path!);
          final name = platformFile.name;
          final size = platformFile.size;
          final ext = platformFile.extension?.toLowerCase() ?? 'pdf';
          String mime = 'application/pdf';
          if (ext == 'jpg' || ext == 'jpeg') mime = 'image/jpeg';
          if (ext == 'png') mime = 'image/png';
          if (ext == 'docx') mime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          if (ext == 'pptx') mime = 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

          // Add temp placeholder model
          final tempDoc = DocumentModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            localPath: file.path,
            sizeBytes: size,
            mimeType: mime,
            status: DocumentUploadStatus.uploading,
            uploadProgress: 0.1,
          );
          _documents.add(tempDoc);
          notifyListeners();

          try {
            final uploadedDoc = await _service.uploadDocument(
              file: file,
              fileName: name,
              sizeBytes: size,
              mimeType: mime,
              onProgress: (p) {
                final idx = _documents.indexWhere((d) => d.id == tempDoc.id);
                if (idx != -1) {
                  _documents[idx] = _documents[idx].copyWith(uploadProgress: p);
                  notifyListeners();
                }
              },
            );

            final idx = _documents.indexWhere((d) => d.id == tempDoc.id);
            if (idx != -1) {
              _documents[idx] = uploadedDoc;
              notifyListeners();
            }
          } catch (e) {
            final idx = _documents.indexWhere((d) => d.id == tempDoc.id);
            if (idx != -1) {
              _documents[idx] = _documents[idx].copyWith(
                status: DocumentUploadStatus.error,
                errorMessage: e.toString(),
              );
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to pick files: $e';
    } finally {
      _isPicking = false;
      notifyListeners();
    }
  }

  void addSimulatedDocument({
    required String name,
    required int pageCount,
    required int sizeBytes,
    required String extension,
  }) {
    final doc = DocumentModel(
      id: 'DOC-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      localPath: '/mock/$name',
      sizeBytes: sizeBytes,
      mimeType: extension == 'pdf' ? 'application/pdf' : 'image/png',
      pageCount: pageCount,
      status: DocumentUploadStatus.uploaded,
      uploadProgress: 1.0,
    );
    _documents.add(doc);
    notifyListeners();
  }

  Future<void> removeDocument(String documentId) async {
    _documents.removeWhere((d) => d.id == documentId);
    notifyListeners();
    await _service.deleteDocument(documentId);
  }

  DocumentModel? getDocumentById(String documentId) {
    try {
      return _documents.firstWhere((d) => d.id == documentId);
    } catch (_) {
      return null;
    }
  }

  void reset() {
    _documents.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
