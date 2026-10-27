import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  testWidgets('shows an empty state and creates a channel from the form', (tester) async {
    final app = await createApp();
    await pumpApp(tester, app);
    expect(find.text('No channels yet'), findsOneWidget);

    await tapText(tester, 'New Channel');
    expect(find.widgetWithText(TextFormField, 'Slug'), findsOneWidget);

    // Slug rules mirror the web form: lowercase words joined by single dashes.
    await enterField(tester, 'Name', 'Tech news');
    await enterField(tester, 'Slug', 'Tech News');
    await tapText(tester, 'OK');
    expect(find.text('Use lowercase letters, numbers and single dashes'), findsOneWidget);

    await enterField(tester, 'Slug', 'tech-news');
    await enterField(tester, 'Description', 'Daily tech links');
    await tapText(tester, 'OK');

    expect(find.text('Channel saved'), findsOneWidget);
    expect(find.text('Tech news'), findsOneWidget);
    expect(find.text('/tech-news'), findsOneWidget);
    expect(find.text('Daily tech links'), findsOneWidget);
    expect(find.text('Enabled'), findsOneWidget);
    expect(find.text('0 posts · 0 social accounts'), findsOneWidget);
    expect(app.backend.channels.values.single['slug'], 'tech-news');
  });

  testWidgets('requires a name and a slug', (tester) async {
    final app = await createApp();
    await pumpApp(tester, app);

    await tapText(tester, 'Create Channel');
    await tapText(tester, 'OK');
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Slug is required'), findsOneWidget);
    expect(app.backend.channels, isEmpty);
  });

  testWidgets('edits a channel but never its slug, and can disable it', (tester) async {
    final app = await createApp();
    final channel = app.backend.addChannel(name: 'Tech', slug: 'tech', description: 'Old');
    await pumpApp(tester, app);

    await tapText(tester, 'Edit');
    expect(find.text('Edit Channel'), findsOneWidget);
    final slug = tester.widget<TextField>(
      find.descendant(of: find.widgetWithText(TextFormField, 'Slug'), matching: find.byType(TextField)),
    );
    expect(slug.enabled, isFalse);

    await enterField(tester, 'Name', 'Tech daily');
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tapText(tester, 'OK');

    expect(find.text('Tech daily'), findsOneWidget);
    expect(find.text('Disabled'), findsOneWidget);
    expect(channel['enabled'], isFalse);
    expect(channel['slug'], 'tech');
  });

  testWidgets('deleting a channel asks first', (tester) async {
    final app = await createApp();
    app.backend.addChannel(name: 'Tech', slug: 'tech');
    await pumpApp(tester, app);

    await tapText(tester, 'Delete');
    expect(find.text('Delete channel?'), findsOneWidget);
    expect(find.text('This will delete all posts and social accounts in this channel.'), findsOneWidget);

    await tapText(tester, 'Cancel');
    expect(app.backend.channels, isNotEmpty);

    await tapText(tester, 'Delete');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(app.backend.channels, isEmpty);
    expect(find.text('Channel deleted'), findsOneWidget);
    expect(find.text('No channels yet'), findsOneWidget);
  });

  testWidgets('a channel card opens the channel with its description and counts', (tester) async {
    final app = await createApp();
    final channel = app.backend.addChannel(name: 'Tech', slug: 'tech', description: 'Gadgets and code');
    app.backend.addAccount(channel['id']! as String, platform: 'x', name: 'Tech on X');
    app.backend.addPost(channel['id']! as String, title: 'Hello world');
    await pumpApp(tester, app);

    await tapText(tester, 'View');

    expect(find.text('Gadgets and code'), findsOneWidget);
    expect(find.text('1 posts · 1 social accounts'), findsOneWidget);
    expect(find.text('Hello world'), findsOneWidget);
    expect(find.text('Manage social accounts'), findsOneWidget);
    expect(find.text('New Post'), findsOneWidget);
  });

  testWidgets('the bottom bar switches between Channels and Settings', (tester) async {
    final app = await createApp();
    await pumpApp(tester, app);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')));
    await tester.pumpAndSettle();
    expect(find.text('API tokens'), findsOneWidget);
    expect(find.text('Email: me@example.com'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Channels')));
    await tester.pumpAndSettle();
    expect(find.text('No channels yet'), findsOneWidget);
  });
}
