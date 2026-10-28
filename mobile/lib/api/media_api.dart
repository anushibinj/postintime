import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/models.dart';
import 'api_client.dart';

class MediaApi {
  MediaApi(this._client);

  final ApiClient _client;

  Future<MediaInfo> uploadMedia({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType.parse(contentType)),
    });
    final json = await _client.send('POST', '/api/v1/media', formData: form) as Map<String, dynamic>;
    return MediaInfo.fromJson(json);
  }

  Future<void> deleteMedia(String mediaId) async {
    await _client.delete('/api/v1/media/$mediaId');
  }
}

/// Appends `?size=` for backend-resized square thumbnails (e.g. 32, 64).
String mediaUrlWithSize(String url, int size) {
  final parsed = Uri.tryParse(url);
  if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
    return parsed.replace(queryParameters: {...parsed.queryParameters, 'size': '$size'}).toString();
  }
  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}size=$size';
}
