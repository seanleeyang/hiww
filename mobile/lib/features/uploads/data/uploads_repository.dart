import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';

class UploadsRepository {
  UploadsRepository(this._api);
  final ApiClient _api;

  /// Uploads [file] and returns the public URL the backend stored it at.
  Future<String> uploadImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final data = await _api.upload(
      '/api/uploads',
      bytes: bytes,
      filename: file.name.isEmpty ? 'photo.jpg' : file.name,
      contentType: _contentType(file),
    );
    return ((data as Map)['url']).toString();
  }

  String _contentType(XFile file) {
    final fromPlatform = file.mimeType;
    if (fromPlatform != null && fromPlatform.startsWith('image/')) {
      return fromPlatform;
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

final uploadsRepositoryProvider = Provider<UploadsRepository>(
  (ref) => UploadsRepository(ref.watch(apiClientProvider)),
);
