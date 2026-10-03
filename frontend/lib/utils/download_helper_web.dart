import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadFileUniversal(Uint8List bytes, String filename) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  try {
    triggerUrlDownloadUniversal(url, filename: filename);
  } finally {
    // Allow the browser to start consuming the Blob before revoking its URL.
    await Future<void>.delayed(const Duration(seconds: 1));
    web.URL.revokeObjectURL(url);
  }
}

void triggerUrlDownloadUniversal(String url, {String? filename}) {
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename ?? ''
    ..target = '_blank'
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}

void openPdfInNewTabUniversal(Uint8List bytes) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}
