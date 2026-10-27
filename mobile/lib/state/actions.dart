import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/social_accounts_api.dart';
import '../models/models.dart';
import 'core_providers.dart';
import 'data_providers.dart';

/// Writes for channels. Each call refreshes the data it changes, like the web mutations do.
class ChannelActions {
  ChannelActions(this._ref);

  final Ref _ref;

  void _refresh([String? channelId]) {
    _ref.invalidate(channelsProvider);
    if (channelId != null) {
      _ref.invalidate(channelProvider(channelId));
    }
  }

  Future<Channel> create({required String name, required String slug, String? description}) async {
    final channel = await _ref.read(channelsApiProvider).createChannel(name: name, slug: slug, description: description);
    _refresh();
    return channel;
  }

  Future<Channel> update(
    String channelId, {
    String? name,
    String? slug,
    String? description,
    bool? enabled,
  }) async {
    final channel = await _ref.read(channelsApiProvider).updateChannel(
          channelId,
          name: name,
          slug: slug,
          description: description,
          enabled: enabled,
        );
    _refresh(channelId);
    return channel;
  }

  Future<void> delete(String channelId) async {
    await _ref.read(channelsApiProvider).deleteChannel(channelId);
    _refresh();
  }
}

final channelActionsProvider = Provider((ref) => ChannelActions(ref));

class PostActions {
  PostActions(this._ref, this.channelId);

  final Ref _ref;
  final String channelId;

  Future<Post> create({
    required String title,
    String? caption,
    String? mediaId,
    required PostStatus status,
  }) async {
    final post = await _ref
        .read(postsApiProvider)
        .createPost(channelId, title: title, caption: caption, mediaId: mediaId, status: status);
    _ref.invalidate(postsProvider);
    _ref.invalidate(channelsProvider);
    _ref.invalidate(channelProvider(channelId));
    return post;
  }

  Future<Post> update(
    String postId, {
    String? title,
    String? caption,
    String? mediaId,
    PostStatus? status,
  }) async {
    final post = await _ref
        .read(postsApiProvider)
        .updatePost(channelId, postId, title: title, caption: caption, mediaId: mediaId, status: status);
    _ref.invalidate(postsProvider);
    _ref.invalidate(postProvider((channelId: channelId, postId: postId)));
    return post;
  }

  Future<void> delete(String postId) async {
    await _ref.read(postsApiProvider).deletePost(channelId, postId);
    _ref.invalidate(postsProvider);
    _ref.invalidate(channelsProvider);
    _ref.invalidate(channelProvider(channelId));
  }
}

final postActionsProvider = Provider.family<PostActions, String>((ref, channelId) => PostActions(ref, channelId));

/// Publishing writes for one post: targets, publishing and the published toggles.
class PublishingActions {
  PublishingActions(this._ref, this.channelId, this.postId);

  final Ref _ref;
  final String channelId;
  final String postId;

  PostKey get _key => (channelId: channelId, postId: postId);

  void _refresh() {
    _ref.invalidate(targetsProvider(_key));
    _ref.invalidate(postProvider(_key));
    _ref.invalidate(postsProvider);
  }

  Future<List<PostTarget>> createTargets(List<String> socialAccountIds) async {
    final targets = await _ref.read(publishingApiProvider).createTargets(channelId, postId, socialAccountIds);
    _refresh();
    return targets;
  }

  Future<PublishResponse> publish(String targetId) async {
    try {
      return await _ref.read(publishingApiProvider).publishTarget(channelId, postId, targetId);
    } finally {
      // A failed webhook still changes the target (it becomes "failed"), so refresh either way.
      _refresh();
    }
  }

  Future<PostTarget> markPublished(String targetId, {String? externalUrl}) async {
    final target =
        await _ref.read(publishingApiProvider).markPublished(channelId, postId, targetId, externalUrl: externalUrl);
    _refresh();
    return target;
  }

  Future<PostTarget> reset(String targetId) async {
    final target = await _ref.read(publishingApiProvider).resetTarget(channelId, postId, targetId);
    _refresh();
    return target;
  }

  Future<PostTarget> togglePublished(String socialAccountId) async {
    try {
      return await _ref.read(publishingApiProvider).togglePublished(channelId, postId, socialAccountId);
    } finally {
      _refresh();
    }
  }
}

final publishingActionsProvider =
    Provider.family<PublishingActions, PostKey>((ref, key) => PublishingActions(ref, key.channelId, key.postId));

class SocialAccountActions {
  SocialAccountActions(this._ref, this.channelId);

  final Ref _ref;
  final String channelId;

  void _refresh() {
    _ref.invalidate(socialAccountsProvider(channelId));
    _ref.invalidate(channelProvider(channelId));
    _ref.invalidate(channelsProvider);
  }

  Future<SocialAccount> create(SocialAccountInput data) async {
    final account = await _ref.read(socialAccountsApiProvider).createSocialAccount(channelId, data);
    _refresh();
    return account;
  }

  Future<SocialAccount> update(String accountId, SocialAccountInput data) async {
    final account = await _ref.read(socialAccountsApiProvider).updateSocialAccount(channelId, accountId, data);
    _refresh();
    return account;
  }

  Future<void> remove(String accountId) async {
    await _ref.read(socialAccountsApiProvider).deleteSocialAccount(channelId, accountId);
    _refresh();
  }

  Future<SocialAccount> enable(String accountId) async {
    final account = await _ref.read(socialAccountsApiProvider).enableSocialAccount(channelId, accountId);
    _refresh();
    return account;
  }

  Future<SocialAccount> disable(String accountId) async {
    final account = await _ref.read(socialAccountsApiProvider).disableSocialAccount(channelId, accountId);
    _refresh();
    return account;
  }
}

final socialAccountActionsProvider =
    Provider.family<SocialAccountActions, String>((ref, channelId) => SocialAccountActions(ref, channelId));

class BulkPublishActions {
  BulkPublishActions(this._ref, this.channelId);

  final Ref _ref;
  final String channelId;

  void _refresh() {
    _ref.invalidate(bulkJobsProvider(channelId));
    _ref.invalidate(postsProvider);
    _ref.invalidate(postProvider);
  }

  Future<BulkPublishJob> create({
    required List<String> postIds,
    required int intervalMinutes,
    required List<String> socialAccountIds,
  }) async {
    final job = await _ref.read(bulkPublishApiProvider).createJob(channelId, postIds, intervalMinutes, socialAccountIds);
    _refresh();
    return job;
  }

  Future<BulkPublishJob> cancelJob(String jobId) async {
    final job = await _ref.read(bulkPublishApiProvider).cancelJob(channelId, jobId);
    _refresh();
    return job;
  }

  Future<BulkPublishJob> cancelItem(String jobId, String itemId) async {
    final job = await _ref.read(bulkPublishApiProvider).cancelItem(channelId, jobId, itemId);
    _refresh();
    return job;
  }
}

final bulkPublishActionsProvider =
    Provider.family<BulkPublishActions, String>((ref, channelId) => BulkPublishActions(ref, channelId));

class ApiTokenActions {
  ApiTokenActions(this._ref);

  final Ref _ref;

  void _refresh() => _ref.invalidate(apiTokensProvider);

  Future<ApiToken> create({required String name, DateTime? expiresAt}) async {
    final token = await _ref.read(apiTokensApiProvider).createApiToken(name: name, expiresAt: expiresAt);
    _refresh();
    return token;
  }

  Future<ApiToken> updateExpiry(String tokenId, {DateTime? expiresAt, bool neverExpires = false}) async {
    final token = await _ref
        .read(apiTokensApiProvider)
        .updateApiToken(tokenId, expiresAt: expiresAt, neverExpires: neverExpires);
    _refresh();
    return token;
  }

  Future<ApiToken> refresh(String tokenId) async {
    final token = await _ref.read(apiTokensApiProvider).refreshApiToken(tokenId);
    _refresh();
    return token;
  }

  Future<void> remove(String tokenId) async {
    await _ref.read(apiTokensApiProvider).deleteApiToken(tokenId);
    _refresh();
  }
}

final apiTokenActionsProvider = Provider((ref) => ApiTokenActions(ref));
