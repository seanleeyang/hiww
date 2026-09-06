import 'dart:typed_data';

import 'package:gal/gal.dart';

import 'image_saver_types.dart';

/// Saves [bytes] to the device's photo gallery (Android/iOS), asking for
/// permission first if it hasn't been granted yet.
Future<SaveResult> saveImageBytes(Uint8List bytes) async {
  try {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) return SaveResult.permissionDenied;
    }
    await Gal.putImageBytes(bytes, album: 'Hiww');
    return SaveResult.success;
  } catch (_) {
    return SaveResult.failure;
  }
}
