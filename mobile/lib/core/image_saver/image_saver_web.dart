// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html is fine here — this file is only ever selected for the web
// target via the conditional export in image_saver.dart, never bundled
// into the mobile/desktop build.
import 'dart:html' as html;
import 'dart:typed_data';

import 'image_saver_types.dart';

/// Triggers a browser download of [bytes] via a same-origin blob URL — works
/// regardless of whether the source (e.g. an R2 object) sends a
/// `Content-Disposition: attachment` header, since the browser never
/// re-fetches the remote URL.
Future<SaveResult> saveImageBytes(Uint8List bytes) async {
  try {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'hiww-photo.jpg')
      ..click();
    html.Url.revokeObjectUrl(url);
    return SaveResult.success;
  } catch (_) {
    return SaveResult.failure;
  }
}
