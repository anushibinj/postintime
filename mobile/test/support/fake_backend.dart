import 'dart:convert';

/// An in-memory stand-in for the PostInTime API, shared by the widget tests and `tool/mock_server.dart`.
///
/// It implements just the endpoints the app calls, with the response shapes of the real backend.
class FakeBackend {
  FakeBackend({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  int _ids = 0;
  int _ticks = 0;

  final Map<String, Map<String, dynamic>> users = {};
  final Map<String, Map<String, dynamic>> channels = {};
  final Map<String, List<Map<String, dynamic>>> posts = {};
  final Map<String, List<Map<String, dynamic>>> accounts = {};
  final Map<String, List<Map<String, dynamic>>> targets = {}; // keyed by postId
  final Map<String, List<Map<String, dynamic>>> jobs = {};
  final List<Map<String, dynamic>> apiTokens = [];

  /// Every request as "METHOD /path", in order, for assertions.
  final List<String> log = [];

  /// Bodies of the requests, parallel to [log].
  final List<Object?> bodies = [];

  /// Origin put in front of uploaded media URLs (the mock server sets it to its own address).
  String mediaBaseUrl = 'http://fake.test';

  /// Webhook publishing outcome; set to a message to make webhook publishing fail.
  String? webhookFailure;

  String nextId(String prefix) => '$prefix-${++_ids}';

  /// A strictly increasing timestamp, so "recently updated" ordering is deterministic.
  String _stamp() => _clock().toUtc().add(Duration(seconds: ++_ticks)).toIso8601String();

  static String jwt({required String sub, required String email, Duration lifetime = const Duration(hours: 24)}) {
    String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final exp = DateTime.now().add(lifetime).millisecondsSinceEpoch ~/ 1000;
    return '${part({'alg': 'HS256'})}.${part({'sub': sub, 'email': email, 'exp': exp})}.signature';
  }

  Map<String, dynamic> addChannel({required String name, required String slug, String? description}) {
    final id = nextId('channel');
    final stamp = _stamp();
    final channel = {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'enabled': true,
      'createdAt': stamp,
      'updatedAt': stamp,
    };
    channels[id] = channel;
    posts[id] = [];
    accounts[id] = [];
    jobs[id] = [];
    return channel;
  }

  Map<String, dynamic> addAccount(
    String channelId, {
    required String platform,
    required String name,
    String mode = 'manual',
    String? profileUrl,
    String? webhookUrl,
  }) {
    final stamp = _stamp();
    final account = {
      'id': nextId('account'),
      'platform': platform,
      'name': name,
      'profileUrl': profileUrl,
      'postingMode': mode,
      'enabled': true,
      'webhookUrl': webhookUrl,
      'webhookAuthType': 'none',
      'webhookUsername': null,
      'webhookHasPassword': false,
      'createdAt': stamp,
      'updatedAt': stamp,
    };
    accounts[channelId]!.add(account);
    return account;
  }

  Map<String, dynamic> addPost(
    String channelId, {
    required String title,
    String? caption,
    String status = 'draft',
    Map<String, dynamic>? media,
  }) {
    final stamp = _stamp();
    final post = {
      'id': nextId('post'),
      'channelId': channelId,
      'title': title,
      'caption': caption,
      'media': media,
      'status': status,
      'createdAt': stamp,
      'updatedAt': stamp,
    };
    posts[channelId]!.add(post);
    targets[post['id']! as String] = [];
    return post;
  }

  // ---------------------------------------------------------------------------------------------

  Map<String, dynamic> _channelJson(Map<String, dynamic> channel) => {
    ...channel,
    'postCount': posts[channel['id']]!.length,
    'socialAccountCount': accounts[channel['id']]!.length,
  };

  Map<String, dynamic> _postJson(Map<String, dynamic> post) {
    final postTargets = targets[post['id']] ?? [];
    final channelId = post['channelId']! as String;
    final queued = _queuedItem(channelId, post['id']! as String);
    final accountList = accounts[channelId]!;
    return {
      ...post,
      'publicationSummary': {
        'total': postTargets.length,
        'published': postTargets.where((t) => t['status'] == 'published').length,
        'pending': postTargets.where((t) => t['status'] == 'pending').length,
        'failed': postTargets.where((t) => t['status'] == 'failed').length,
      },
      'targets': [
        for (final t in postTargets)
          {
            'id': t['id'],
            'socialAccountId': t['socialAccountId'],
            'platform': accountList.firstWhere((a) => a['id'] == t['socialAccountId'])['platform'],
            'name': accountList.firstWhere((a) => a['id'] == t['socialAccountId'])['name'],
            'status': t['status'],
          },
      ],
      'bulkPublishScheduledAt': queued?['scheduledAt'],
    };
  }

  Map<String, dynamic> _targetJson(Map<String, dynamic> target, String channelId) {
    final account = accounts[channelId]!.firstWhere((a) => a['id'] == target['socialAccountId']);
    return {
      'id': target['id'],
      'socialAccount': {
        'id': account['id'],
        'platform': account['platform'],
        'name': account['name'],
        'profileUrl': account['profileUrl'],
      },
      'status': target['status'],
      'publishingMode': account['postingMode'],
      'publishedAt': target['publishedAt'],
    };
  }

  Map<String, dynamic>? _queuedItem(String channelId, String postId) {
    for (final job in jobs[channelId] ?? <Map<String, dynamic>>[]) {
      for (final item in job['items'] as List<Map<String, dynamic>>) {
        if (item['postId'] == postId && item['status'] == 'pending') {
          return item;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _tokenJson(Map<String, dynamic> token, {bool secret = false}) => {
    for (final entry in token.entries)
      if (entry.key != 'secret') entry.key: entry.value,
    if (secret) 'token': token['secret'],
  };

  // ---------------------------------------------------------------------------------------------

  /// Handles one request and returns the status code and JSON body.
  (int, Object?) handle(String method, Uri uri, Object? body) {
    log.add('$method ${uri.path}');
    bodies.add(body);
    final path = uri.path;
    final json = body is Map<String, dynamic> ? body : <String, dynamic>{};
    RegExpMatch? match(String pattern) => RegExp('^$pattern\$').firstMatch(path);

    if (path == '/api/v1/auth/login' && method == 'POST') {
      final user = users[json['email']];
      if (user == null || user['password'] != json['password']) {
        return (401, {'message': 'Invalid credentials', 'code': 'AUTH_FAILED'});
      }
      return (200, _authResponse(user));
    }
    if (path == '/api/v1/auth/register' && method == 'POST') {
      final email = json['email']! as String;
      if (users.containsKey(email)) {
        return (409, {'message': 'Email already registered', 'code': 'CONFLICT'});
      }
      final displayName = json['displayName'] as String?;
      final user = {
        'id': nextId('user'),
        'email': email,
        'password': json['password'],
        'displayName': displayName ?? email,
      };
      users[email] = user;
      return (200, _authResponse(user));
    }

    if (path == '/api/v1/channels') {
      if (method == 'GET') return (200, [for (final c in channels.values) _channelJson(c)]);
      if (method == 'POST') {
        final channel = addChannel(
          name: json['name']! as String,
          slug: json['slug']! as String,
          description: json['description'] as String?,
        );
        return (201, _channelJson(channel));
      }
    }
    var m = match('/api/v1/channels/([^/]+)');
    if (m != null) {
      final channel = channels[m.group(1)];
      if (channel == null) return (404, {'message': 'Channel not found', 'code': 'NOT_FOUND'});
      if (method == 'GET') return (200, _channelJson(channel));
      if (method == 'PATCH') {
        for (final key in ['name', 'slug', 'description', 'enabled']) {
          if (json.containsKey(key)) channel[key] = json[key];
        }
        channel['updatedAt'] = _stamp();
        return (200, _channelJson(channel));
      }
      if (method == 'DELETE') {
        channels.remove(channel['id']);
        return (204, null);
      }
    }

    m = match('/api/v1/channels/([^/]+)/posts');
    if (m != null) {
      final channelId = m.group(1)!;
      if (method == 'GET') return (200, _postPage(channelId, uri.queryParameters));
      if (method == 'POST') {
        final post = addPost(
          channelId,
          title: json['title']! as String,
          caption: json['caption'] as String?,
          status: json['status'] as String? ?? 'draft',
          media: _mediaById(json['mediaId'] as String?),
        );
        return (201, _postJson(post));
      }
    }
    m = match('/api/v1/channels/([^/]+)/posts/([^/]+)');
    if (m != null) {
      final channelId = m.group(1)!;
      final post = _findPost(channelId, m.group(2)!);
      if (post == null) return (404, {'message': 'Post not found', 'code': 'NOT_FOUND'});
      if (method == 'GET') return (200, _postJson(post));
      if (method == 'PATCH') {
        for (final key in ['title', 'caption', 'status']) {
          if (json.containsKey(key)) post[key] = json[key];
        }
        if (json['mediaId'] != null) post['media'] = _mediaById(json['mediaId']! as String);
        post['updatedAt'] = _stamp();
        return (200, _postJson(post));
      }
      if (method == 'DELETE') {
        posts[channelId]!.remove(post);
        return (204, null);
      }
    }

    m = match('/api/v1/channels/([^/]+)/posts/([^/]+)/targets');
    if (m != null) {
      final channelId = m.group(1)!;
      final postId = m.group(2)!;
      if (method == 'GET') return (200, [for (final t in targets[postId]!) _targetJson(t, channelId)]);
      if (method == 'POST') {
        for (final accountId in (json['socialAccountIds']! as List).cast<String>()) {
          if (targets[postId]!.every((t) => t['socialAccountId'] != accountId)) {
            targets[postId]!.add({
              'id': nextId('target'),
              'socialAccountId': accountId,
              'status': 'pending',
              'publishedAt': null,
            });
          }
        }
        return (201, [for (final t in targets[postId]!) _targetJson(t, channelId)]);
      }
    }
    m = match('/api/v1/channels/([^/]+)/posts/([^/]+)/targets/toggle');
    if (m != null && method == 'POST') {
      final channelId = m.group(1)!;
      final postId = m.group(2)!;
      if (_queuedItem(channelId, postId) != null) {
        return (409, {'message': 'Post is queued for bulk posting', 'code': 'POST_QUEUED'});
      }
      final accountId = json['socialAccountId']! as String;
      var target = targets[postId]!.where((t) => t['socialAccountId'] == accountId).firstOrNull;
      target ??= {'id': nextId('target'), 'socialAccountId': accountId, 'status': 'pending', 'publishedAt': null};
      if (!targets[postId]!.contains(target)) targets[postId]!.add(target);
      final account = accounts[channelId]!.firstWhere((a) => a['id'] == accountId);
      if (target['status'] == 'published') {
        target['status'] = 'pending';
        target['publishedAt'] = null;
      } else if (account['postingMode'] == 'webhook' && webhookFailure != null) {
        target['status'] = 'failed';
        return (502, {'message': webhookFailure, 'code': 'PUBLISH_FAILED'});
      } else {
        target['status'] = 'published';
        target['publishedAt'] = _stamp();
      }
      return (200, _targetJson(target, channelId));
    }
    m = match('/api/v1/channels/([^/]+)/posts/([^/]+)/targets/([^/]+)/(publish|mark-published|reset)');
    if (m != null && method == 'POST') {
      final channelId = m.group(1)!;
      final postId = m.group(2)!;
      final target = targets[postId]!.where((t) => t['id'] == m!.group(3)).firstOrNull;
      if (target == null) return (404, {'message': 'Target not found', 'code': 'NOT_FOUND'});
      final account = accounts[channelId]!.firstWhere((a) => a['id'] == target['socialAccountId']);
      switch (m.group(4)) {
        case 'publish':
          if (_queuedItem(channelId, postId) != null) {
            return (409, {'message': 'Post is queued for bulk posting', 'code': 'POST_QUEUED'});
          }
          if (account['postingMode'] == 'webhook') {
            if (webhookFailure != null) {
              target['status'] = 'failed';
              return (502, {'message': webhookFailure, 'code': 'PUBLISH_FAILED'});
            }
            target['status'] = 'published';
            target['publishedAt'] = _stamp();
          } else {
            target['status'] = 'publishing';
          }
          return (
            200,
            {
              'targetId': target['id'],
              'status': target['status'],
              'publishingMode': account['postingMode'],
              'instructions': {'copyCaption': true, 'downloadMedia': true, 'destinationUrl': account['profileUrl']},
            },
          );
        case 'mark-published':
          target['status'] = 'published';
          target['publishedAt'] = _stamp();
        case 'reset':
          target['status'] = 'pending';
          target['publishedAt'] = null;
      }
      return (200, _targetJson(target, channelId));
    }

    m = match('/api/v1/channels/([^/]+)/social-accounts');
    if (m != null) {
      final channelId = m.group(1)!;
      if (method == 'GET') return (200, accounts[channelId]!);
      if (method == 'POST') {
        final account = addAccount(
          channelId,
          platform: json['platform']! as String,
          name: json['name']! as String,
          mode: json['postingMode'] as String? ?? 'manual',
          profileUrl: json['profileUrl'] as String?,
          webhookUrl: json['webhookUrl'] as String?,
        );
        _applyWebhookAuth(account, json);
        return (201, account);
      }
    }
    m = match('/api/v1/channels/([^/]+)/social-accounts/([^/]+)(?:/(enable|disable))?');
    if (m != null) {
      final channelId = m.group(1)!;
      final account = accounts[channelId]!.where((a) => a['id'] == m!.group(2)).firstOrNull;
      if (account == null) return (404, {'message': 'Account not found', 'code': 'NOT_FOUND'});
      if (method == 'DELETE') {
        accounts[channelId]!.remove(account);
        return (204, null);
      }
      if (method == 'PATCH') {
        for (final key in ['name', 'profileUrl', 'postingMode', 'webhookUrl']) {
          if (json.containsKey(key)) account[key] = json[key];
        }
        _applyWebhookAuth(account, json);
        return (200, account);
      }
      if (method == 'POST' && m.group(3) != null) {
        account['enabled'] = m.group(3) == 'enable';
        return (200, account);
      }
    }

    m = match('/api/v1/channels/([^/]+)/bulk-publish-jobs');
    if (m != null) {
      final channelId = m.group(1)!;
      if (method == 'GET') return (200, jobs[channelId]!);
      if (method == 'POST') return (201, _createJob(channelId, json));
    }
    m = match('/api/v1/channels/([^/]+)/bulk-publish-jobs/([^/]+)/cancel');
    if (m != null && method == 'POST') {
      final job = jobs[m.group(1)!]!.where((j) => j['id'] == m!.group(2)).firstOrNull;
      if (job == null) return (404, {'message': 'Job not found', 'code': 'NOT_FOUND'});
      for (final item in job['items'] as List<Map<String, dynamic>>) {
        if (item['status'] == 'pending') item['status'] = 'cancelled';
      }
      job['status'] = 'cancelled';
      return (200, job);
    }
    m = match('/api/v1/channels/([^/]+)/bulk-publish-jobs/([^/]+)/items/([^/]+)/cancel');
    if (m != null && method == 'POST') {
      final job = jobs[m.group(1)!]!.where((j) => j['id'] == m!.group(2)).firstOrNull;
      final item = (job?['items'] as List<Map<String, dynamic>>?)?.where((i) => i['id'] == m!.group(3)).firstOrNull;
      if (item == null) return (404, {'message': 'Item not found', 'code': 'NOT_FOUND'});
      item['status'] = 'cancelled';
      return (200, job);
    }

    if (path == '/api/v1/api-tokens') {
      if (method == 'GET') return (200, [for (final t in apiTokens) _tokenJson(t)]);
      if (method == 'POST') {
        final token = {
          'id': nextId('token'),
          'name': json['name'],
          'tokenPrefix': 'pit_${_ids}ab',
          'secret': 'pit_secret_${_ids}_xyz',
          'expiresAt': json['expiresAt'],
          'lastUsedAt': null,
          'createdAt': _stamp(),
        };
        apiTokens.add(token);
        return (201, _tokenJson(token, secret: true));
      }
    }
    m = match('/api/v1/api-tokens/([^/]+)(?:/(refresh))?');
    if (m != null) {
      final token = apiTokens.where((t) => t['id'] == m!.group(1)).firstOrNull;
      if (token == null) return (404, {'message': 'Token not found', 'code': 'NOT_FOUND'});
      if (method == 'DELETE') {
        apiTokens.remove(token);
        return (204, null);
      }
      if (method == 'PATCH') {
        if (json['neverExpires'] == true) token['expiresAt'] = null;
        if (json.containsKey('expiresAt')) token['expiresAt'] = json['expiresAt'];
        if (json.containsKey('name')) token['name'] = json['name'];
        return (200, _tokenJson(token));
      }
      if (method == 'POST' && m.group(2) == 'refresh') {
        token['secret'] = 'pit_secret_refreshed_${++_ids}';
        return (200, _tokenJson(token, secret: true));
      }
    }

    if (path == '/api/v1/media' && method == 'POST') {
      final id = nextId('media');
      final media = {
        'id': id,
        'url': '$mediaBaseUrl/api/v1/media/files/$id.png',
        'contentType': 'image/png',
        'originalFilename': '$id.png',
      };
      _media[id] = media;
      return (201, media);
    }

    return (404, {'message': 'No route for $method $path', 'code': 'NOT_FOUND'});
  }

  final Map<String, Map<String, dynamic>> _media = {};

  Map<String, dynamic>? _mediaById(String? id) => id == null ? null : _media[id];

  Map<String, dynamic>? _findPost(String channelId, String postId) =>
      (posts[channelId] ?? []).where((p) => p['id'] == postId).firstOrNull;

  Map<String, dynamic> _authResponse(Map<String, dynamic> user) => {
    'token': jwt(sub: user['id']! as String, email: user['email']! as String),
    'userId': user['id'],
    'email': user['email'],
    'displayName': user['displayName'],
  };

  void _applyWebhookAuth(Map<String, dynamic> account, Map<String, dynamic> json) {
    if (json['webhookAuthType'] != null) account['webhookAuthType'] = json['webhookAuthType'];
    if (json.containsKey('webhookUsername')) account['webhookUsername'] = json['webhookUsername'];
    if ((json['webhookPassword'] as String?)?.isNotEmpty ?? false) account['webhookHasPassword'] = true;
    account['updatedAt'] = _stamp();
  }

  Map<String, dynamic> _postPage(String channelId, Map<String, String> query) {
    final page = int.tryParse(query['page'] ?? '') ?? 0;
    final size = int.tryParse(query['size'] ?? '') ?? 20;
    final search = (query['search'] ?? '').toLowerCase();
    final status = query['status'];
    var matching = posts[channelId]!.where((post) {
      final text = '${post['title']} ${post['caption'] ?? ''}'.toLowerCase();
      return (search.isEmpty || text.contains(search)) && (status == null || post['status'] == status);
    }).toList();
    // Newest update first, which is the only sort the app asks for.
    matching.sort((a, b) => (b['updatedAt']! as String).compareTo(a['updatedAt']! as String));
    final totalPages = (matching.length / size).ceil();
    final items = matching.skip(page * size).take(size).map(_postJson).toList();
    return {
      'items': items,
      'page': page,
      'size': size,
      'totalItems': matching.length,
      'totalPages': totalPages,
      'hasNext': page + 1 < totalPages,
      'hasPrevious': page > 0,
    };
  }

  Map<String, dynamic> _createJob(String channelId, Map<String, dynamic> json) {
    final interval = json['intervalMinutes']! as int;
    final postIds = (json['postIds']! as List).cast<String>();
    final now = _clock().toUtc();
    var next = now;
    for (final job in jobs[channelId]!) {
      for (final item in job['items'] as List<Map<String, dynamic>>) {
        if (item['status'] == 'pending') {
          final at = DateTime.parse(item['scheduledAt']! as String);
          if (at.isAfter(next) || next == now) next = at.add(Duration(minutes: interval));
        }
      }
    }
    final jobId = nextId('job');
    final stamp = _stamp();
    final items = <Map<String, dynamic>>[
      for (var i = 0; i < postIds.length; i++)
        {
          'id': nextId('item'),
          'postId': postIds[i],
          'postTitle': _findPost(channelId, postIds[i])!['title'],
          'position': i,
          'status': 'pending',
          'scheduledAt': next.add(Duration(minutes: interval * i)).toIso8601String(),
          'errorMessage': null,
          'processedAt': null,
        },
    ];
    final job = {
      'id': jobId,
      'channelId': channelId,
      'intervalMinutes': interval,
      'status': 'running',
      'nextRunAt': items.first['scheduledAt'],
      'totalItems': items.length,
      'processedItems': 0,
      'failedItems': 0,
      'items': items,
      'socialAccountIds': json['socialAccountIds'],
      'createdAt': stamp,
      'updatedAt': stamp,
    };
    jobs[channelId]!.add(job);
    return job;
  }
}
