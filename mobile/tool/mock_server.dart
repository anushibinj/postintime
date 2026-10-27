// A mock PostInTime API for trying the app without the real backend (no Postgres or object storage).
//
//   dart run tool/mock_server.dart [port]
//
// Sign in with demo@example.com / password123. Data lives in memory and resets on restart.
// It reuses the fake backend the widget tests use, so the two always agree on the API's shapes.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../test/support/fake_backend.dart';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8080;
  final backend = FakeBackend();
  _seed(backend, 'http://localhost:$port');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Mock PostInTime API on http://localhost:$port  (demo@example.com / password123)');
  await for (final request in server) {
    _cors(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 204;
      await request.response.close();
      continue;
    }
    final path = request.uri.path;
    if (request.method == 'GET' && path.startsWith('/api/v1/media/files/')) {
      request.response
        ..headers.contentType = ContentType('image', 'png')
        ..add(_png(path.hashCode));
      await request.response.close();
      continue;
    }
    final contentType = request.headers.contentType?.mimeType ?? '';
    Object? body;
    final raw = await utf8.decoder.bind(request).join();
    if (contentType == 'application/json' && raw.isNotEmpty) {
      body = jsonDecode(raw);
    }
    final (status, payload) = backend.handle(request.method, request.uri, body);
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json;
    if (payload != null) {
      request.response.write(jsonEncode(payload));
    }
    await request.response.close();
  }
}

void _cors(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Headers', 'authorization, content-type')
    ..set('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
}

void _seed(FakeBackend backend, String origin) {
  backend.users['demo@example.com'] = {
    'id': backend.nextId('user'),
    'email': 'demo@example.com',
    'password': 'password123',
    'displayName': 'Demo',
  };

  Map<String, dynamic> media(int n) => {
    'id': backend.nextId('media'),
    'url': '$origin/api/v1/media/files/$n.png',
    'contentType': 'image/png',
  };

  final tech =
      backend.addChannel(
            name: 'Tech Tips',
            slug: 'tech-tips',
            description: 'Short, practical posts about developer tools and workflows.',
          )['id']!
          as String;
  final linkedin = backend.addAccount(
    tech,
    platform: 'linkedin',
    name: 'Company LinkedIn',
    mode: 'webhook',
    webhookUrl: 'https://n8n.example.com/webhook/linkedin',
  );
  final instagram = backend.addAccount(
    tech,
    platform: 'instagram',
    name: 'Insta',
    profileUrl: 'https://instagram.com/postintime',
  );
  backend.addAccount(
    tech,
    platform: 'x',
    name: 'X updates',
    mode: 'webhook',
    webhookUrl: 'https://n8n.example.com/webhook/x',
  );
  backend.addAccount(tech, platform: 'facebook', name: 'Facebook page', profileUrl: 'https://facebook.com/postintime');

  final captions = [
    'Five keyboard shortcuts that will save you an hour a week. Number three is the one nobody knows about.',
    'Why we moved our CI from 14 minutes to 3: caching, parallelism and one surprising flaky test.',
    'A tiny script to rename photos by date.',
    'Our code review checklist, open sourced.',
    'Draft: thoughts on database migrations',
  ];
  final titles = [
    'Keyboard shortcuts you never knew',
    'Faster CI in three steps',
    'Rename photos by date',
    'Code review checklist',
    'Migration notes',
  ];
  final postIds = <String>[];
  for (var i = 0; i < titles.length; i++) {
    final post = backend.addPost(
      tech,
      title: titles[i],
      caption: captions[i],
      status: i == 4 ? 'draft' : 'ready',
      media: i < 3 ? media(i + 1) : null,
    );
    postIds.add(post['id']! as String);
  }
  // Post 0 is live on LinkedIn and Instagram.
  for (final account in [linkedin, instagram]) {
    backend.targets[postIds[0]]!.add({
      'id': backend.nextId('target'),
      'socialAccountId': account['id'],
      'status': 'published',
      'publishedAt': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
    });
  }
  backend.targets[postIds[1]]!.add({
    'id': backend.nextId('target'),
    'socialAccountId': linkedin['id'],
    'status': 'pending',
    'publishedAt': null,
  });

  // A bulk posting queue: two posts waiting and a couple of recent results.
  final now = DateTime.now().toUtc();
  String at(int minutes) => now.add(Duration(minutes: minutes)).toIso8601String();
  Map<String, dynamic> item(
    int i,
    String postId,
    String title,
    String status,
    int minutes, {
    String? error,
    bool done = false,
  }) => {
    'id': backend.nextId('item'),
    'postId': postId,
    'postTitle': title,
    'position': i,
    'status': status,
    'scheduledAt': at(minutes),
    'errorMessage': error,
    'processedAt': done ? at(minutes) : null,
  };
  backend.jobs[tech]!.add({
    'id': backend.nextId('job'),
    'channelId': tech,
    'intervalMinutes': 10,
    'status': 'running',
    'nextRunAt': at(12),
    'totalItems': 4,
    'processedItems': 2,
    'failedItems': 1,
    'socialAccountIds': [linkedin['id']],
    'createdAt': at(-30),
    'updatedAt': at(-10),
    'items': [
      item(0, postIds[2], titles[2], 'published', -20, done: true),
      item(1, postIds[3], titles[3], 'failed', -10, error: 'Webhook responded 502: upstream timeout', done: true),
      item(2, postIds[1], titles[1], 'pending', 12),
      item(3, postIds[4], titles[4], 'pending', 22),
    ],
  });

  backend.addChannel(name: 'Travel Diary', slug: 'travel', description: 'Photos from the road.')['enabled'] = false;
  backend.apiTokens.add({
    'id': backend.nextId('token'),
    'name': 'n8n ingest',
    'tokenPrefix': 'pit_a1b2c3',
    'secret': 'pit_a1b2c3_full',
    'expiresAt': now.add(const Duration(days: 90)).toIso8601String(),
    'lastUsedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
    'createdAt': now.subtract(const Duration(days: 40)).toIso8601String(),
  });
}

/// A small solid-colour PNG so thumbnails and previews have something to draw.
Uint8List _png(int seed) {
  const size = 160;
  final hue = (seed.abs() % 360).toDouble();
  final color = HSVColor(hue).toRgb();
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < size; x++) {
      final shade = 0.6 + 0.4 * (x + y) / (2 * size);
      raw
        ..addByte((color.$1 * shade).round())
        ..addByte((color.$2 * shade).round())
        ..addByte((color.$3 * shade).round());
    }
  }
  final out = BytesBuilder()..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final length = ByteData(4)..setUint32(0, data.length);
    out.add(length.buffer.asUint8List());
    final body = [...type.codeUnits, ...data];
    out.add(body);
    final crc = ByteData(4)..setUint32(0, _crc32(body));
    out.add(crc.buffer.asUint8List());
  }

  final header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2); // colour type: RGB
  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', zlib.encode(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

class HSVColor {
  const HSVColor(this.hue);

  final double hue;

  /// Fully saturated, mid-bright colour for [hue], as 0..255 RGB.
  (int, int, int) toRgb() {
    final h = hue / 60;
    final x = 1 - ((h % 2) - 1).abs();
    final (r, g, b) = switch (h.floor()) {
      0 => (1.0, x, 0.0),
      1 => (x, 1.0, 0.0),
      2 => (0.0, 1.0, x),
      3 => (0.0, x, 1.0),
      4 => (x, 0.0, 1.0),
      _ => (1.0, 0.0, x),
    };
    return ((r * 200 + 40).round(), (g * 200 + 40).round(), (b * 200 + 40).round());
  }
}
