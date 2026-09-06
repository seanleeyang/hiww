import 'dart:typed_data';

import 'image_saver_types.dart';

/// Never actually selected — [dart.library.io] or [dart.library.html] always
/// matches on every platform Hiww ships to. Present only so the conditional
/// export in `image_saver.dart` has a well-typed default.
Future<SaveResult> saveImageBytes(Uint8List bytes) async => SaveResult.failure;
