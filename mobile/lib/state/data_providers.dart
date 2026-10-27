import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/posts_api.dart';
import '../models/models.dart';
import 'core_providers.dart';
import 'auth_controller.dart';

/// How long unused data stays cached; matches the web QueryClient's 30 second stale time.
const Duration cacheTime = Duration(seconds: 30);

/// How often a channel's bulk posting jobs are refreshed while one is still running.
const Duration runningPollInterval = Duration(seconds: 10);

/// Keeps an auto-disposed provider's data around for [cacheTime] after its last listener leaves, so
/// navigating back shows the previous data straight away.
void _cacheFor(Ref ref) {
  final link = ref.keepAlive();
  Timer? timer;
  ref.onCancel(() => timer = Timer(cacheTime, link.close));
  ref.onResume(() => timer?.cancel());
  ref.onDispose(() => timer?.cancel());
}

/// Marks the provider as depending on the signed-in session and caches it.
void _scoped(Ref ref) {
  ref.watch(sessionKeyProvider);
  _cacheFor(ref);
}

typedef PostKey = ({String channelId, String postId});
typedef PostsKey = ({String channelId, PostFilters filters});

final channelsProvider = FutureProvider.autoDispose<List<Channel>>((ref) {
  _scoped(ref);
  return ref.watch(channelsApiProvider).fetchChannels();
});

final channelProvider = FutureProvider.autoDispose.family<Channel, String>((ref, channelId) {
  _scoped(ref);
  return ref.watch(channelsApiProvider).fetchChannel(channelId);
});

final postsProvider = FutureProvider.autoDispose.family<PageResponse<Post>, PostsKey>((ref, key) {
  _scoped(ref);
  return ref.watch(postsApiProvider).fetchPosts(key.channelId, key.filters);
});

final postProvider = FutureProvider.autoDispose.family<Post, PostKey>((ref, key) {
  _scoped(ref);
  return ref.watch(postsApiProvider).fetchPost(key.channelId, key.postId);
});

final targetsProvider = FutureProvider.autoDispose.family<List<PostTarget>, PostKey>((ref, key) {
  _scoped(ref);
  return ref.watch(publishingApiProvider).fetchTargets(key.channelId, key.postId);
});

final socialAccountsProvider = FutureProvider.autoDispose.family<List<SocialAccount>, String>((ref, channelId) {
  _scoped(ref);
  return ref.watch(socialAccountsApiProvider).fetchSocialAccounts(channelId);
});

/// A channel's bulk posting jobs. Re-fetched every 10 seconds while a job is still working through
/// its posts, so progress stays live without polling an idle queue.
final bulkJobsProvider = FutureProvider.autoDispose.family<List<BulkPublishJob>, String>((ref, channelId) async {
  _scoped(ref);
  final jobs = await ref.watch(bulkPublishApiProvider).fetchJobs(channelId);
  if (jobs.any((job) => job.status == BulkPublishJobStatus.running)) {
    final timer = Timer(runningPollInterval, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return jobs;
});

final apiTokensProvider = FutureProvider.autoDispose<List<ApiToken>>((ref) {
  _scoped(ref);
  return ref.watch(apiTokensApiProvider).fetchApiTokens();
});

/// Whether [error] is the "session expired" failure, which the UI treats as a sign-out rather than an error.
bool isSessionExpired(Object error) => error is ApiException && error.isSessionExpired;
