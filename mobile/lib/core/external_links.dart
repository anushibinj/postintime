import 'package:url_launcher/url_launcher.dart';

import '../widgets/toast.dart';

/// Opens [url] in the browser or the matching app (the web app's `window.open(url, '_blank')`).
Future<void> openExternal(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {
    // Falls through to the message below.
  }
  Toast.error('Could not open $url');
}
