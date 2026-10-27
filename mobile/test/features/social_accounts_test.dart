import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:postintime/models/models.dart';

import '../support/harness.dart';

final platformDropdown = find.byType(DropdownButtonFormField<Platform>);

Future<({TestApp app, String channelId})> openAccounts(WidgetTester tester, {void Function(TestApp app, String channelId)? seed}) async {
  final app = await createApp();
  final channelId = app.backend.addChannel(name: 'Tech', slug: 'tech')['id']! as String;
  seed?.call(app, channelId);
  await pumpApp(tester, app);
  await tapText(tester, 'View');
  await tapText(tester, 'Manage social accounts');
  return (app: app, channelId: channelId);
}

void main() {
  testWidgets('lists accounts with their mode, auth and state', (tester) async {
    await openAccounts(tester, seed: (app, channelId) {
      app.backend.addAccount(channelId, platform: 'linkedin', name: 'Work', profileUrl: 'https://linkedin.com/in/me');
      final hook = app.backend.addAccount(channelId, platform: 'x', name: 'Hook', mode: 'webhook', webhookUrl: 'https://n8n.test/hook');
      hook['webhookAuthType'] = 'basic';
      hook['enabled'] = false;
    });

    expect(find.text('Social Accounts'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('LinkedIn'), findsOneWidget);
    expect(find.text('https://linkedin.com/in/me'), findsOneWidget);
    expect(find.text('Manual · Enabled'), findsOneWidget);
    expect(find.text('Hook'), findsOneWidget);
    expect(find.text('https://n8n.test/hook'), findsOneWidget);
    expect(find.text('Webhook · Basic auth · Disabled'), findsOneWidget);
  });

  testWidgets('adds a manual account', (tester) async {
    final opened = await openAccounts(tester);
    expect(find.text('No social accounts yet'), findsOneWidget);

    await tapText(tester, 'Add Account');
    // Everything but the profile URL is required.
    await tapText(tester, 'OK');
    expect(find.text('Platform is required'), findsOneWidget);
    expect(find.text('Name is required'), findsOneWidget);

    await tester.tap(platformDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Instagram').last);
    await tester.pumpAndSettle();
    await enterField(tester, 'Name', 'My Insta');
    await enterField(tester, 'Profile URL', 'https://instagram.com/me');
    await tapText(tester, 'OK');

    expect(find.text('Account saved'), findsOneWidget);
    expect(find.text('My Insta'), findsOneWidget);
    final account = opened.app.backend.accounts[opened.channelId]!.single;
    expect(account['platform'], 'instagram');
    expect(account['postingMode'], 'manual');
    expect(account['profileUrl'], 'https://instagram.com/me');
  });

  testWidgets('adds a webhook account with basic auth', (tester) async {
    final opened = await openAccounts(tester);

    await tapText(tester, 'Add Account');
    await tester.tap(platformDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('LinkedIn').last);
    await tester.pumpAndSettle();
    await enterField(tester, 'Name', 'Auto LinkedIn');

    // Webhook fields only appear for the webhook action type.
    expect(find.widgetWithText(TextFormField, 'Webhook URL'), findsNothing);
    await tester.ensureVisible(find.text('Webhook'));
    await tester.tap(find.text('Webhook'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Webhook URL'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Username'), findsNothing);

    await tapText(tester, 'OK');
    expect(find.text('Webhook URL is required'), findsOneWidget);

    await enterField(tester, 'Webhook URL', 'https://n8n.test/webhook/post');
    await tester.ensureVisible(find.text('Basic'));
    await tester.tap(find.text('Basic'));
    await tester.pumpAndSettle();
    await tapText(tester, 'OK');
    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    await enterField(tester, 'Username', 'robot');
    await enterField(tester, 'Password', 's3cret');
    await tapText(tester, 'OK');

    expect(find.text('Account saved'), findsOneWidget);
    expect(find.text('Webhook · Basic auth · Enabled'), findsOneWidget);
    final account = opened.app.backend.accounts[opened.channelId]!.single;
    expect(account['postingMode'], 'webhook');
    expect(account['webhookUrl'], 'https://n8n.test/webhook/post');
    expect(account['webhookAuthType'], 'basic');
    expect(account['webhookUsername'], 'robot');
    expect(account['webhookHasPassword'], isTrue);
  });

  testWidgets('editing keeps the platform fixed and lets the stored password stay', (tester) async {
    final opened = await openAccounts(tester, seed: (app, channelId) {
      final hook = app.backend.addAccount(channelId, platform: 'x', name: 'Hook', mode: 'webhook', webhookUrl: 'https://n8n.test/hook');
      hook['webhookAuthType'] = 'basic';
      hook['webhookUsername'] = 'robot';
      hook['webhookHasPassword'] = true;
    });

    await tapText(tester, 'Edit');
    expect(find.text('Edit Account'), findsOneWidget);
    final platform = tester.widget<DropdownButtonFormField<Platform>>(platformDropdown);
    expect(platform.onChanged, isNull, reason: 'platform cannot change after creation');
    expect(find.text('robot'), findsOneWidget);
    expect(find.text('https://n8n.test/hook'), findsWidgets);
    expect(find.text('Leave blank to keep the current password'), findsOneWidget);

    await enterField(tester, 'Name', 'Renamed hook');
    await tapText(tester, 'OK');

    expect(find.text('Account saved'), findsOneWidget);
    expect(find.text('Renamed hook'), findsOneWidget);
    final bodyIndex = opened.app.backend.log.lastIndexWhere((entry) => entry.startsWith('PATCH'));
    final body = opened.app.backend.bodies[bodyIndex]! as Map;
    expect(body.containsKey('webhookPassword'), isFalse, reason: 'a blank password keeps the stored one');
    expect(body['name'], 'Renamed hook');
  });

  testWidgets('disables, re-enables and deletes an account', (tester) async {
    final opened = await openAccounts(tester, seed: (app, channelId) {
      app.backend.addAccount(channelId, platform: 'x', name: 'Side X');
    });

    await tapText(tester, 'Disable');
    expect(find.text('Manual · Disabled'), findsOneWidget);
    expect(find.text('Enable'), findsOneWidget);
    expect(opened.app.backend.accounts[opened.channelId]!.single['enabled'], isFalse);

    await tapText(tester, 'Enable');
    expect(find.text('Manual · Enabled'), findsOneWidget);

    await tapText(tester, 'Delete');
    expect(find.text('Delete account?'), findsOneWidget);
    await tapText(tester, 'Cancel');
    expect(opened.app.backend.accounts[opened.channelId], hasLength(1));

    await tapText(tester, 'Delete');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(opened.app.backend.accounts[opened.channelId], isEmpty);
    expect(find.text('No social accounts yet'), findsOneWidget);
  });

  testWidgets('accounts added here show up as publish buttons on the posts', (tester) async {
    await openAccounts(tester, seed: (app, channelId) => app.backend.addPost(channelId, title: 'A post'));
    await tapText(tester, 'Add Account');
    await tester.tap(platformDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Facebook').last);
    await tester.pumpAndSettle();
    await enterField(tester, 'Name', 'Page');
    await tapText(tester, 'OK');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Page · Manual · Not posted'), findsOneWidget);
    expect(find.text('f'), findsOneWidget);
  });
}
