import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'fake_backend.dart';

/// Serves [FakeBackend] to a Dio client without any network.
class FakeBackendAdapter implements HttpClientAdapter {
  FakeBackendAdapter(this.backend);

  final FakeBackend backend;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object? body;
    final data = options.data;
    if (data is String && data.isNotEmpty) {
      body = jsonDecode(data);
    } else if (data is FormData) {
      body = {
        for (final field in data.fields) field.key: field.value,
        // Uploaded files, as "field:filename:contentType".
        '_files': [for (final file in data.files) '${file.key}:${file.value.filename}:${file.value.contentType}'],
      };
    }
    final (status, payload) = backend.handle(options.method, options.uri, body);
    return ResponseBody.fromString(
      payload == null ? '' : jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
