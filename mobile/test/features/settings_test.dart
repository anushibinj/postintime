import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

Future<TestApp> openSettings(WidgetTester tester, {void Function(TestApp app)? seed}) async {
  final app = await createApp();
  seed?.call(app);
  await pumpApp(tester, app);
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')));
  await tester.pumpAndSettle();
  return app;
}

Map<String, dynamic> token(String id, String name, {String? expiresAt, String? lastUsedAt}) => {
  'id': id,
  'name': name,
  'tokenPrefix': 'pit_$id',
  'secret': 'pit_full_secret_$id',
  'expiresAt': expiresAt,
  'lastUsedAt': lastUsedAt,
  'createdAt': '2026-01-01T00:00:00Z',
};

void main() {
  testWidgets('shows the account email and an empty token list', (tester) async {
    await openSettings(tester);
    expect(find.text('Email: me@example.com'), findsOneWidget);
    expect(find.text('API tokens'), findsOneWidget);
    expect(find.text('Use a token as a Bearer credential for REST calls to the PostInTime API.'), findsOneWidget);
    expect(find.text('No API tokens yet.'), findsOneWidget);
  });

  testWidgets('lists tokens with prefix, expiry and last use', (tester) async {
    await openSettings(
      tester,
      seed: (app) {
        app.backend.apiTokens.addAll([
          token('a1', 'CI pipeline', expiresAt: '2027-03-05T12:00:00Z', lastUsedAt: '2026-10-01T12:00:00Z'),
          token('b2', 'Forever'),
        ]);
      },
    );

    expect(find.text('CI pipeline'), findsOneWidget);
    expect(find.text('pit_a1…'), findsOneWidget);
    expect(find.text('Expires Mar 5, 2027'), findsOneWidget);
    expect(find.text('Last used Oct 1, 2026'), findsOneWidget);
    expect(find.text('Forever'), findsOneWidget);
    expect(find.text('Never expires'), findsOneWidget);
  });

  testWidgets('creates a token, shows its secret once and can copy it', (tester) async {
    final clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final app = await openSettings(tester);

    await tapText(tester, 'New token');
    await tapText(tester, 'OK');
    expect(find.text('Give this token a name'), findsOneWidget);

    await enterField(tester, 'Name', 'CI pipeline');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 days').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'OK');

    expect(find.text('Copy your API token'), findsOneWidget);
    expect(find.text('This secret is shown only once. Store it somewhere safe.'), findsOneWidget);
    expect(
      find.text('pit_secret_${app.backend.apiTokens.single['id'].toString().split('-').last}_xyz'),
      findsOneWidget,
    );
    final created = app.backend.bodies[app.backend.log.indexOf('POST /api/v1/api-tokens')]! as Map;
    expect(created['name'], 'CI pipeline');
    final expires = DateTime.parse(created['expiresAt'] as String);
    expect(expires.difference(DateTime.now()).inDays, inInclusiveRange(29, 30));

    await tapText(tester, 'Copy token');
    expect(clipboard.single, startsWith('pit_secret_'));
    expect(find.text('Token copied'), findsOneWidget);

    await tapText(tester, 'Done');
    expect(find.text('CI pipeline'), findsOneWidget);
    expect(find.text('Copy your API token'), findsNothing);
  });

  testWidgets('a token that never expires is created without an expiry', (tester) async {
    final app = await openSettings(tester);
    await tapText(tester, 'New token');
    await enterField(tester, 'Name', 'Forever');
    await tapText(tester, 'OK');
    final created = app.backend.bodies[app.backend.log.indexOf('POST /api/v1/api-tokens')]! as Map;
    expect(created, {'name': 'Forever', 'expiresAt': null});
  });

  testWidgets('changes a token expiry, including back to never', (tester) async {
    final app = await openSettings(
      tester,
      seed: (app) => app.backend.apiTokens.add(token('a1', 'CI', expiresAt: '2027-03-05T12:00:00Z')),
    );

    expect(find.text('Change expiry'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('90 days').last);
    await tester.pumpAndSettle();
    expect(find.text('Expiry updated'), findsOneWidget);
    final patch = app.backend.bodies[app.backend.log.lastIndexWhere((e) => e.startsWith('PATCH'))]! as Map;
    expect(DateTime.parse(patch['expiresAt'] as String).difference(DateTime.now()).inDays, inInclusiveRange(89, 90));

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Never expires').last);
    await tester.pumpAndSettle();
    final never = app.backend.bodies[app.backend.log.lastIndexWhere((e) => e.startsWith('PATCH'))]! as Map;
    expect(never, {'neverExpires': true});
    expect(app.backend.apiTokens.single['expiresAt'], isNull);
  });

  testWidgets('refreshing a token asks first and shows the new secret', (tester) async {
    final app = await openSettings(tester, seed: (app) => app.backend.apiTokens.add(token('a1', 'CI')));

    await tapText(tester, 'Refresh secret');
    expect(find.text('Refresh this token?'), findsOneWidget);
    expect(
      find.text('The current secret will stop working immediately. A new secret will be shown once.'),
      findsOneWidget,
    );
    await tapText(tester, 'Cancel');
    expect(app.backend.log.where((e) => e.endsWith('/refresh')), isEmpty);

    await tapText(tester, 'Refresh secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Refresh'));
    await tester.pumpAndSettle();

    expect(find.text('API token refreshed'), findsOneWidget);
    expect(find.text('Copy your API token'), findsOneWidget);
    expect(find.textContaining('pit_secret_refreshed_'), findsOneWidget);
  });

  testWidgets('deleting a token asks first', (tester) async {
    final app = await openSettings(tester, seed: (app) => app.backend.apiTokens.add(token('a1', 'CI')));

    await tapText(tester, 'Delete');
    expect(find.text('Delete this token?'), findsOneWidget);
    expect(find.text('Requests using this token will fail immediately.'), findsOneWidget);
    await tapText(tester, 'Cancel');
    expect(app.backend.apiTokens, hasLength(1));

    await tapText(tester, 'Delete');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(app.backend.apiTokens, isEmpty);
    expect(find.text('No API tokens yet.'), findsOneWidget);
  });
}
