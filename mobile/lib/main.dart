import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/api_config.dart';
import 'api/token_store.dart';
import 'app/app.dart';
import 'state/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final client = ApiClient(tokenStore: SecureTokenStore(), baseUrl: await ApiConfig.load(prefs));
  await client.load();

  runApp(
    ProviderScope(
      retry: appRetry,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs), apiClientProvider.overrideWithValue(client)],
      child: const PostInTimeApp(),
    ),
  );
}
