import 'package:flutter_test/flutter_test.dart';
import 'package:postintime/api/api_config.dart';
import 'package:postintime/state/core_providers.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

void main() {
  testWidgets('an API 401 for an expired session signs the user out and shows sign in', (tester) async {
    final app = await createApp();
    app.backend.addChannel(name: 'Tech', slug: 'tech');
    await pumpApp(tester, app);
    expect(find.text('Tech'), findsOneWidget);

    // The server stops accepting the session: the next call comes back as AUTH_EXPIRED.
    app.backend.users.clear();
    app.backend.channels.clear();
    app.client.expireSession();
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(app.client.token, isNull);
    expect(find.text('Tech'), findsNothing, reason: 'cached data is dropped with the session');
  });

  testWidgets('an already expired stored token starts at the sign in screen', (tester) async {
    final app = await createApp();
    await app.client.setToken(FakeBackend.jwt(sub: 'u', email: 'me@example.com', lifetime: const Duration(hours: -1)));
    await pumpApp(tester, app);
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(app.client.token, isNull);
    expect(app.backend.log, isEmpty);
  });

  testWidgets('the signed-in user is read from the stored token', (tester) async {
    final app = await createApp();
    await pumpApp(tester, app);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('me@example.com'), findsOneWidget);
  });

  testWidgets('the session ends by itself when the token expires', (tester) async {
    final app = await createApp();
    await app.client.setToken(
      FakeBackend.jwt(sub: 'u', email: 'me@example.com', lifetime: const Duration(seconds: 30)),
    );
    await pumpApp(tester, app);
    expect(find.text('No channels yet'), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to your account'), findsOneWidget);
  });

  testWidgets('the server address can be changed from the sign in screen and reset', (tester) async {
    final app = await createApp(signedIn: false);
    await pumpApp(tester, app);
    expect(find.text('Server: http://fake.test'), findsOneWidget);

    await tapText(tester, 'Server: http://fake.test');
    expect(find.text('Server address'), findsOneWidget);

    await enterField(tester, 'API base URL', 'not a url');
    await tapText(tester, 'Save');
    expect(find.text('Enter a full http:// or https:// address'), findsOneWidget);

    await enterField(tester, 'API base URL', ' https://api.example.com/ ');
    await tapText(tester, 'Save');
    expect(find.text('Server address saved'), findsOneWidget);
    expect(find.text('Server: https://api.example.com'), findsOneWidget);
    expect(app.client.baseUrl, 'https://api.example.com');

    await tapText(tester, 'Server: https://api.example.com');
    final defaultUrl = ApiConfig.defaultBaseUrl;
    await tapText(tester, 'Use default ($defaultUrl)');
    expect(app.client.baseUrl, defaultUrl);
    expect(find.text('Server: $defaultUrl'), findsOneWidget);
  });

  test('retry policy retries a failed query once, but never a dead session', () {
    expect(appRetry(0, Exception('boom')), isNotNull);
    expect(appRetry(1, Exception('boom')), isNull);
  });
}
