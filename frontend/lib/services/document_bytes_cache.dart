import 'dart:typed_data';

class DocumentBytesCache {
  static final Map<String, Uint8List> _cache = {};

  static void put(String docId, Uint8List bytes) {
    if (docId.isNotEmpty && bytes.isNotEmpty) {
      _cache[docId] = bytes;
    }
  }

  static Uint8List? get(String docId) => _cache[docId];

  static bool has(String docId) => _cache.containsKey(docId);

  static void clear() => _cache.clear();
}
