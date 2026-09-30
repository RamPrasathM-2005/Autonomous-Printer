import 'dart:typed_data';

import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

Future<void> downloadFile(Uint8List bytes, String filename) =>
    downloadFileUniversal(bytes, filename);
