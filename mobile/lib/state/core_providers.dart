import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/api_tokens_api.dart';
import '../api/auth_api.dart';
import '../api/bulk_publish_api.dart';
import '../api/channels_api.dart';
import '../api/media_api.dart';
import '../api/posts_api.dart';
import '../api/publishing_api.dart';
import '../api/social_accounts_api.dart';

/// Overridden in `main()` with the loaded preferences.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Overridden in `main()` with a client whose stored token is already loaded.
final apiClientProvider = Provider<ApiClient>(
  (ref) => throw UnimplementedError('apiClientProvider must be overridden'),
);

/// The API origin the app talks to; changing it is persisted and applies to the next request.
class ApiBaseUrlController extends Notifier<String> {
  @override
  String build() => ref.read(apiClientProvider).baseUrl;

  Future<void> set(String url) async {
    final normalized = ApiConfig.normalize(url);
    ref.read(apiClientProvider).baseUrl = normalized;
    state = normalized;
    await ApiConfig.save(ref.read(sharedPreferencesProvider), normalized);
  }
}

final apiBaseUrlProvider = NotifierProvider<ApiBaseUrlController, String>(ApiBaseUrlController.new);

final authApiProvider = Provider((ref) => AuthApi(ref.watch(apiClientProvider)));
final channelsApiProvider = Provider((ref) => ChannelsApi(ref.watch(apiClientProvider)));
final postsApiProvider = Provider((ref) => PostsApi(ref.watch(apiClientProvider)));
final mediaApiProvider = Provider((ref) => MediaApi(ref.watch(apiClientProvider)));
final publishingApiProvider = Provider((ref) => PublishingApi(ref.watch(apiClientProvider)));
final socialAccountsApiProvider = Provider((ref) => SocialAccountsApi(ref.watch(apiClientProvider)));
final bulkPublishApiProvider = Provider((ref) => BulkPublishApi(ref.watch(apiClientProvider)));
final apiTokensApiProvider = Provider((ref) => ApiTokensApi(ref.watch(apiClientProvider)));

/// Mirrors the web QueryClient defaults: retry a failed query once, but never a dead session.
Duration? appRetry(int retryCount, Object error) {
  if (error is ApiException && error.isSessionExpired) {
    return null;
  }
  return retryCount >= 1 ? null : const Duration(seconds: 1);
}
