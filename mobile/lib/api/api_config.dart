import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apiBaseUrlKey = 'postintime_api_base_url';

/// Where the API lives. Build with `--dart-define=API_BASE_URL=https://api.example.com` to bake in a
/// default; users can also point the app at another server from the sign-in screen.
class ApiConfig {
  const ApiConfig._();

  static const String _defined = String.fromEnvironment('API_BASE_URL');

  static String get defaultBaseUrl {
    if (_defined.isNotEmpty) {
      return normalize(_defined);
    }
    // The Android emulator reaches the host machine through 10.0.2.2, not localhost.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  /// Trims whitespace and trailing slashes so paths can be appended with a leading slash.
  static String normalize(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

  /// Whether [url] is something Dio can call: an http(s) URL with a host.
  static bool isValid(String url) {
    final uri = Uri.tryParse(normalize(url));
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  static Future<String> load(SharedPreferences prefs) async {
    final saved = prefs.getString(apiBaseUrlKey);
    return saved != null && isValid(saved) ? normalize(saved) : defaultBaseUrl;
  }

  static Future<void> save(SharedPreferences prefs, String url) async {
    final normalized = normalize(url);
    if (normalized == defaultBaseUrl) {
      await prefs.remove(apiBaseUrlKey);
    } else {
      await prefs.setString(apiBaseUrlKey, normalized);
    }
  }
}
