import 'dart:typed_data';

class WebDragDropService {
  static void register({
    required void Function(bool isDragging) onDragStateChange,
    required void Function(String fileName, Uint8List fileBytes) onFileDropped,
  }) {
    // No-op on non-web platforms
  }

  static void unregister() {
    // No-op on non-web platforms
  }
}
