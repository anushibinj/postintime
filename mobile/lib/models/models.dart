import 'enums.dart';

export 'enums.dart';

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;

DateTime _requiredDate(Object? value) => _date(value) ?? DateTime.fromMillisecondsSinceEpoch(0);

class ApiToken {
  const ApiToken({
    required this.id,
    required this.name,
    required this.tokenPrefix,
    this.token,
    this.expiresAt,
    this.lastUsedAt,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String tokenPrefix;

  /// The full secret; only present in the response to create/refresh.
  final String? token;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;
  final DateTime createdAt;

  factory ApiToken.fromJson(Map<String, dynamic> json) => ApiToken(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    tokenPrefix: json['tokenPrefix'] as String? ?? '',
    token: json['token'] as String?,
    expiresAt: _date(json['expiresAt']),
    lastUsedAt: _date(json['lastUsedAt']),
    createdAt: _requiredDate(json['createdAt']),
  );
}

class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.enabled,
    required this.postCount,
    required this.socialAccountCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final bool enabled;
  final int postCount;
  final int socialAccountCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    description: json['description'] as String?,
    enabled: json['enabled'] as bool? ?? true,
    postCount: (json['postCount'] as num?)?.toInt() ?? 0,
    socialAccountCount: (json['socialAccountCount'] as num?)?.toInt() ?? 0,
    createdAt: _requiredDate(json['createdAt']),
    updatedAt: _requiredDate(json['updatedAt']),
  );
}

class MediaInfo {
  const MediaInfo({
    required this.id,
    required this.url,
    required this.contentType,
    this.originalFilename,
    this.sizeBytes,
    this.width,
    this.height,
  });

  final String id;
  final String url;
  final String contentType;
  final String? originalFilename;
  final int? sizeBytes;
  final int? width;
  final int? height;

  factory MediaInfo.fromJson(Map<String, dynamic> json) => MediaInfo(
    id: json['id'] as String,
    url: json['url'] as String? ?? '',
    contentType: json['contentType'] as String? ?? '',
    originalFilename: json['originalFilename'] as String?,
    sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
  );
}

class PublicationSummary {
  const PublicationSummary({required this.total, required this.published, required this.pending, required this.failed});

  final int total;
  final int published;
  final int pending;
  final int failed;

  factory PublicationSummary.fromJson(Map<String, dynamic> json) => PublicationSummary(
    total: (json['total'] as num?)?.toInt() ?? 0,
    published: (json['published'] as num?)?.toInt() ?? 0,
    pending: (json['pending'] as num?)?.toInt() ?? 0,
    failed: (json['failed'] as num?)?.toInt() ?? 0,
  );
}

class PostTargetSummary {
  const PostTargetSummary({
    required this.id,
    required this.socialAccountId,
    required this.platform,
    required this.name,
    required this.status,
  });

  final String id;
  final String socialAccountId;
  final Platform platform;
  final String name;
  final TargetStatus status;

  factory PostTargetSummary.fromJson(Map<String, dynamic> json) => PostTargetSummary(
    id: json['id'] as String,
    socialAccountId: json['socialAccountId'] as String? ?? '',
    platform: Platform.parse(json['platform'] as String?),
    name: json['name'] as String? ?? '',
    status: TargetStatus.parse(json['status'] as String?),
  );
}

class Post {
  const Post({
    required this.id,
    this.channelId,
    required this.title,
    this.caption,
    this.media,
    required this.status,
    this.publicationSummary,
    this.targets,
    this.bulkPublishScheduledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? channelId;
  final String title;
  final String? caption;
  final MediaInfo? media;
  final PostStatus status;
  final PublicationSummary? publicationSummary;
  final List<PostTargetSummary>? targets;

  /// When the channel's bulk posting queue will post this; null when not queued.
  final DateTime? bulkPublishScheduledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Post.fromJson(Map<String, dynamic> json) {
    final media = json['media'];
    final summary = json['publicationSummary'];
    final targets = json['targets'];
    return Post(
      id: json['id'] as String,
      channelId: json['channelId'] as String?,
      title: json['title'] as String? ?? '',
      caption: json['caption'] as String?,
      media: media is Map<String, dynamic> ? MediaInfo.fromJson(media) : null,
      status: PostStatus.parse(json['status'] as String?),
      publicationSummary: summary is Map<String, dynamic> ? PublicationSummary.fromJson(summary) : null,
      targets: targets is List
          ? targets.whereType<Map<String, dynamic>>().map(PostTargetSummary.fromJson).toList()
          : null,
      bulkPublishScheduledAt: _date(json['bulkPublishScheduledAt']),
      createdAt: _requiredDate(json['createdAt']),
      updatedAt: _requiredDate(json['updatedAt']),
    );
  }
}

class PageResponse<T> {
  const PageResponse({
    required this.items,
    required this.page,
    required this.size,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<T> items;
  final int page;
  final int size;
  final int totalItems;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  factory PageResponse.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) parseItem) {
    final items = json['items'];
    return PageResponse(
      items: items is List ? items.whereType<Map<String, dynamic>>().map(parseItem).toList() : <T>[],
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      hasNext: json['hasNext'] as bool? ?? false,
      hasPrevious: json['hasPrevious'] as bool? ?? false,
    );
  }
}

class SocialAccount {
  const SocialAccount({
    required this.id,
    required this.platform,
    required this.name,
    this.profileUrl,
    required this.postingMode,
    required this.enabled,
    this.webhookUrl,
    this.webhookAuthType = WebhookAuthType.none,
    this.webhookUsername,
    this.webhookHasPassword = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final Platform platform;
  final String name;
  final String? profileUrl;
  final PostingMode postingMode;
  final bool enabled;
  final String? webhookUrl;
  final WebhookAuthType webhookAuthType;
  final String? webhookUsername;
  final bool webhookHasPassword;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isWebhook => postingMode == PostingMode.webhook;

  factory SocialAccount.fromJson(Map<String, dynamic> json) => SocialAccount(
    id: json['id'] as String,
    platform: Platform.parse(json['platform'] as String?),
    name: json['name'] as String? ?? '',
    profileUrl: json['profileUrl'] as String?,
    postingMode: PostingMode.parse(json['postingMode'] as String?),
    enabled: json['enabled'] as bool? ?? true,
    webhookUrl: json['webhookUrl'] as String?,
    webhookAuthType: WebhookAuthType.parse(json['webhookAuthType'] as String?),
    webhookUsername: json['webhookUsername'] as String?,
    webhookHasPassword: json['webhookHasPassword'] as bool? ?? false,
    createdAt: _requiredDate(json['createdAt']),
    updatedAt: _requiredDate(json['updatedAt']),
  );
}

class TargetAccount {
  const TargetAccount({required this.id, required this.platform, required this.name, this.profileUrl});

  final String id;
  final Platform platform;
  final String name;
  final String? profileUrl;

  factory TargetAccount.fromJson(Map<String, dynamic> json) => TargetAccount(
    id: json['id'] as String,
    platform: Platform.parse(json['platform'] as String?),
    name: json['name'] as String? ?? '',
    profileUrl: json['profileUrl'] as String?,
  );
}

class PostTarget {
  const PostTarget({
    required this.id,
    required this.socialAccount,
    required this.status,
    required this.publishingMode,
    this.publishedAt,
    this.externalPostId,
    this.externalUrl,
  });

  final String id;
  final TargetAccount socialAccount;
  final TargetStatus status;
  final PostingMode publishingMode;
  final DateTime? publishedAt;
  final String? externalPostId;
  final String? externalUrl;

  factory PostTarget.fromJson(Map<String, dynamic> json) => PostTarget(
    id: json['id'] as String,
    socialAccount: TargetAccount.fromJson(json['socialAccount'] as Map<String, dynamic>),
    status: TargetStatus.parse(json['status'] as String?),
    publishingMode: PostingMode.parse(json['publishingMode'] as String?),
    publishedAt: _date(json['publishedAt']),
    externalPostId: json['externalPostId'] as String?,
    externalUrl: json['externalUrl'] as String?,
  );
}

class PublishInstructions {
  const PublishInstructions({required this.copyCaption, required this.downloadMedia, this.destinationUrl});

  final bool copyCaption;
  final bool downloadMedia;
  final String? destinationUrl;

  factory PublishInstructions.fromJson(Map<String, dynamic> json) => PublishInstructions(
    copyCaption: json['copyCaption'] as bool? ?? false,
    downloadMedia: json['downloadMedia'] as bool? ?? false,
    destinationUrl: json['destinationUrl'] as String?,
  );
}

class PublishResponse {
  const PublishResponse({
    required this.targetId,
    required this.status,
    required this.publishingMode,
    required this.instructions,
  });

  final String targetId;
  final TargetStatus status;
  final PostingMode publishingMode;
  final PublishInstructions instructions;

  factory PublishResponse.fromJson(Map<String, dynamic> json) {
    final instructions = json['instructions'];
    return PublishResponse(
      targetId: json['targetId'] as String? ?? '',
      status: TargetStatus.parse(json['status'] as String?),
      publishingMode: PostingMode.parse(json['publishingMode'] as String?),
      instructions: instructions is Map<String, dynamic>
          ? PublishInstructions.fromJson(instructions)
          : const PublishInstructions(copyCaption: false, downloadMedia: false),
    );
  }
}

class BulkPublishItem {
  const BulkPublishItem({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.position,
    required this.status,
    required this.scheduledAt,
    this.errorMessage,
    this.processedAt,
  });

  final String id;
  final String postId;
  final String postTitle;
  final int position;
  final BulkPublishItemStatus status;
  final DateTime scheduledAt;
  final String? errorMessage;
  final DateTime? processedAt;

  factory BulkPublishItem.fromJson(Map<String, dynamic> json) => BulkPublishItem(
    id: json['id'] as String,
    postId: json['postId'] as String? ?? '',
    postTitle: json['postTitle'] as String? ?? '',
    position: (json['position'] as num?)?.toInt() ?? 0,
    status: BulkPublishItemStatus.parse(json['status'] as String?),
    scheduledAt: _requiredDate(json['scheduledAt']),
    errorMessage: json['errorMessage'] as String?,
    processedAt: _date(json['processedAt']),
  );
}

class BulkPublishJob {
  const BulkPublishJob({
    required this.id,
    required this.channelId,
    required this.intervalMinutes,
    required this.status,
    this.nextRunAt,
    required this.totalItems,
    required this.processedItems,
    required this.failedItems,
    required this.items,
    required this.socialAccountIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String channelId;
  final int intervalMinutes;
  final BulkPublishJobStatus status;
  final DateTime? nextRunAt;
  final int totalItems;
  final int processedItems;
  final int failedItems;
  final List<BulkPublishItem> items;

  /// Social accounts every post of the job goes to.
  final List<String> socialAccountIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BulkPublishJob.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final accountIds = json['socialAccountIds'];
    return BulkPublishJob(
      id: json['id'] as String,
      channelId: json['channelId'] as String? ?? '',
      intervalMinutes: (json['intervalMinutes'] as num?)?.toInt() ?? 5,
      status: BulkPublishJobStatus.parse(json['status'] as String?),
      nextRunAt: _date(json['nextRunAt']),
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      processedItems: (json['processedItems'] as num?)?.toInt() ?? 0,
      failedItems: (json['failedItems'] as num?)?.toInt() ?? 0,
      items: items is List
          ? items.whereType<Map<String, dynamic>>().map(BulkPublishItem.fromJson).toList()
          : <BulkPublishItem>[],
      socialAccountIds: accountIds is List ? accountIds.whereType<String>().toList() : <String>[],
      createdAt: _requiredDate(json['createdAt']),
      updatedAt: _requiredDate(json['updatedAt']),
    );
  }
}

/// The signed-in user, as returned by login/register or decoded from the stored token.
class AuthUser {
  const AuthUser({required this.token, required this.userId, required this.email, required this.displayName});

  final String token;
  final String userId;
  final String email;
  final String displayName;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    token: json['token'] as String,
    userId: json['userId'] as String? ?? '',
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
  );
}
