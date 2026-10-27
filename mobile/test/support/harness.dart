import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:postintime/api/api_client.dart';
import 'package:postintime/api/token_store.dart';
import 'package:postintime/app/app.dart';
import 'package:postintime/app/navigator_keys.dart';
import 'package:postintime/state/core_providers.dart';
import 'package:postintime/state/now_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_adapter.dart';
import 'fake_backend.dart';

/// "Now" for every test: a fixed afternoon, so relative labels like "in 5 min" are deterministic.
final DateTime testNow = DateTime(2026, 10, 27, 15, 0);

class TestApp {
  TestApp(this.backend, this.client);

  final FakeBackend backend;
  final ApiClient client;
}

/// A phone-sized viewport so mobile layouts are what gets tested.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

List<Override> testOverrides(TestApp app, SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  apiClientProvider.overrideWithValue(app.client),
  nowProvider.overrideWith((ref) => Stream.value(testNow)),
];

/// Builds a client wired to [backend], optionally already signed in.
Future<TestApp> createApp({FakeBackend? backend, bool signedIn = true}) async {
  final fake = backend ?? FakeBackend(clock: () => testNow);
  String? token;
  if (signedIn) {
    final user = fake.users.putIfAbsent(
      'me@example.com',
      () => {'id': fake.nextId('user'), 'email': 'me@example.com', 'password': 'password1', 'displayName': 'Me'},
    );
    token = FakeBackend.jwt(sub: user['id']! as String, email: 'me@example.com');
  }
  final client = ApiClient(
    tokenStore: MemoryTokenStore(token),
    baseUrl: 'http://fake.test',
    dio: Dio()..httpClientAdapter = FakeBackendAdapter(fake),
    // The test clock, so token expiry follows `tester.pump(duration)`.
    clock: () => clock.now(),
  );
  await client.load();
  return TestApp(fake, client);
}

/// Pumps the whole app against [app] and waits for the first screen.
Future<void> pumpApp(WidgetTester tester, TestApp app, {List<Override> extra = const []}) async {
  usePhoneScreen(tester);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [...testOverrides(app, prefs), ...extra],
      child: const PostInTimeApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a single [child] widget inside the providers, for component tests.
Future<void> pumpWidgetWithApp(
  WidgetTester tester,
  TestApp app,
  Widget child, {
  List<Override> extra = const [],
}) async {
  usePhoneScreen(tester);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [...testOverrides(app, prefs), ...extra],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types [text] into the text field labelled [label].
Future<void> enterField(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  expect(field, findsOneWidget, reason: 'field "$label"');
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

/// Taps the button/label [text], scrolling it into view first.
Future<void> tapText(WidgetTester tester, String text, {bool settle = true}) async {
  final finder = find.text(text);
  expect(finder, findsAtLeastNWidgets(1), reason: 'text "$text"');
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  if (settle) {
    await tester.pumpAndSettle();
  }
}

/// Scrolls the page's list until [finder] is built and on screen, like a user would.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// Scrolls the page's list back to its top.
Future<void> scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
}
