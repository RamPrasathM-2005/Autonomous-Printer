import 'dart:js_interop';
import 'dart:typed_data';

@JS('initWebDragDrop')
external void _initWebDragDrop(
  JSFunction onStateChange,
  JSFunction onFileDrop,
);

@JS('clearWebDragDrop')
external void _clearWebDragDrop();

class WebDragDropService {
  static void register({
    required void Function(bool isDragging) onDragStateChange,
    required void Function(String fileName, Uint8List fileBytes) onFileDropped,
  }) {
    try {
      final jsStateChange = ((JSBoolean isDragging) {
        onDragStateChange(isDragging.toDart);
      }).toJS;

      final jsFileDrop = ((JSString name, JSUint8Array bytes) {
        onFileDropped(name.toDart, bytes.toDart);
      }).toJS;

      _initWebDragDrop(jsStateChange, jsFileDrop);
    } catch (_) {}
  }

  static void unregister() {
    try {
      _clearWebDragDrop();
    } catch (_) {}
  }
}
