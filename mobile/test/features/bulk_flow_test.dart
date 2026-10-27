import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

Future<({TestApp app, String channelId, List<String> postIds, String hookId})> openChannelWithPosts(WidgetTester tester) async {
  final app = await createApp();
  final channelId = app.backend.addChannel(name: 'Tech', slug: 'tech')['id']! as String;
  final hook = app.backend.addAccount(channelId, platform: 'linkedin', name: 'LinkedIn hook', mode: 'webhook', webhookUrl: 'https://n8n.test/hook');
  app.backend.addAccount(channelId, platform: 'instagram', name: 'Manual IG');
  // Added oldest first, so the list (newest update first) reads C, B, A.
  final ids = [
    for (final title in ['Post A', 'Post B', 'Post C']) app.backend.addPost(channelId, title: title)['id']! as String,
  ];
  await pumpApp(tester, app);
  await tapText(tester, 'View');
  return (app: app, channelId: channelId, postIds: ids, hookId: hook['id']! as String);
}

void main() {
  testWidgets('selects posts, bulk posts them in the picked order and shows the queue', (tester) async {
    final opened = await openChannelWithPosts(tester);
    final boxes = find.byType(Checkbox); // [Select page, Post C, Post B, Post A]
    expect(boxes, findsNWidgets(4));
    expect(find.text('Bulk post'), findsNothing, reason: 'nothing selected yet');

    // Tick Post B first, then Post A: that is the order they are posted in.
    await tester.tap(boxes.at(2));
    await tester.pump();
    await tester.tap(boxes.at(3));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tapText(tester, 'Bulk post');
    expect(find.text('Bulk post 2 posts'), findsOneWidget);
    expect(find.text('LinkedIn hook'), findsOneWidget);
    expect(find.textContaining('Manual accounts (Manual IG) are skipped.'), findsOneWidget);
    await tapText(tester, 'Start bulk posting');

    expect(find.text('Added 2 posts to the bulk posting queue'), findsOneWidget);
    expect(find.text('2 selected'), findsNothing, reason: 'selection is cleared after queueing');
    final body = opened.app.backend.bodies[opened.app.backend.log.lastIndexOf('POST /api/v1/channels/${opened.channelId}/bulk-publish-jobs')]! as Map;
    expect(body, {
      'postIds': [opened.postIds[1], opened.postIds[0]],
      'intervalMinutes': 5,
      'socialAccountIds': [opened.hookId],
    });

    // The queue panel appears (collapsed) and queued posts are tagged and locked.
    expect(find.text('Bulk posting queue'), findsOneWidget);
    expect(find.text('2 posts'), findsOneWidget);
    expect(find.textContaining(RegExp(r'Queued for posting at 3:00 PM')), findsOneWidget);
    expect(find.textContaining(RegExp(r'Queued for posting at 3:05 PM')), findsOneWidget);
    expect(find.byTooltip('Already queued for bulk posting'), findsNWidgets(2));
    // Selected-page now only covers the post that is still free.
    await tester.tap(find.text('Select page'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('queued posts cannot be toggled or selected again', (tester) async {
    final opened = await openChannelWithPosts(tester);
    await tester.tap(find.text('Select page'));
    await tester.pump();
    expect(find.text('3 selected'), findsOneWidget);
    await tapText(tester, 'Bulk post');
    await tapText(tester, 'Start bulk posting');

    expect(find.text('Select page'), findsOneWidget);
    for (final box in tester.widgetList<Checkbox>(find.byType(Checkbox)).skip(1)) {
      expect(box.onChanged, isNull, reason: 'queued posts are locked');
    }
    final toggle = find.byTooltip('Manual IG · Manual · Not posted · Queued for bulk posting');
    expect(toggle, findsNWidgets(3));
    final before = opened.app.backend.log.length;
    await tester.tap(toggle.first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(opened.app.backend.log.length, before, reason: 'no request is sent for a locked post');
  });

  testWidgets('clearing the selection hides the bulk actions', (tester) async {
    await openChannelWithPosts(tester);
    await tester.tap(find.text('Select page'));
    await tester.pump();
    expect(find.text('3 selected'), findsOneWidget);
    await tapText(tester, 'Clear');
    expect(find.text('3 selected'), findsNothing);
    expect(find.text('Bulk post'), findsNothing);
  });

  testWidgets('a queued post can be removed from the queue and cancel all clears the rest', (tester) async {
    final opened = await openChannelWithPosts(tester);
    await tester.tap(find.text('Select page'));
    await tester.pump();
    await tapText(tester, 'Bulk post');
    await tapText(tester, 'Start bulk posting');
    expect(find.text('3 posts'), findsOneWidget);

    await scrollToTop(tester);
    await tester.tap(find.text('Bulk posting queue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Post C from the queue'));
    await tester.pumpAndSettle();
    expect(find.text('Removed "Post C" from the queue'), findsOneWidget);
    expect(find.text('2 posts'), findsOneWidget);

    await tester.tap(find.text('Cancel all'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel all'));
    await tester.pumpAndSettle();
    expect(find.text('Bulk posting queue cleared'), findsOneWidget);
    expect(find.text('Bulk posting queue'), findsNothing);
    // Posts are free to be queued again.
    expect(find.byTooltip('Already queued for bulk posting'), findsNothing);
    expect(opened.app.backend.jobs[opened.channelId]!.single['status'], 'cancelled');
  });

  testWidgets('a new batch queues behind the posts already waiting', (tester) async {
    final opened = await openChannelWithPosts(tester);
    final boxes = find.byType(Checkbox);
    await tester.tap(boxes.at(1)); // Post C
    await tester.pump();
    await tapText(tester, 'Bulk post');
    await tapText(tester, 'Start bulk posting');

    await tester.tap(find.byType(Checkbox).at(2)); // Post B (Post C is locked now)
    await tester.pump();
    await tapText(tester, 'Bulk post');
    expect(find.textContaining('1 post is already queued; these join the end of the queue.'), findsOneWidget);
    expect(find.textContaining(RegExp(r'The post goes live at 3:05 PM \(in 5 min\)')), findsOneWidget);
    await tapText(tester, 'Start bulk posting');

    expect(opened.app.backend.jobs[opened.channelId], hasLength(2));
    await scrollToTop(tester);
    expect(find.text('2 posts'), findsOneWidget);
  });

  testWidgets('bulk posting needs a webhook account', (tester) async {
    final app = await createApp();
    final channelId = app.backend.addChannel(name: 'Tech', slug: 'tech')['id']! as String;
    app.backend.addAccount(channelId, platform: 'instagram', name: 'Manual IG');
    app.backend.addPost(channelId, title: 'Post A');
    await pumpApp(tester, app);
    await tapText(tester, 'View');

    await tester.tap(find.text('Select page'));
    await tester.pump();
    await tapText(tester, 'Bulk post');
    expect(find.text('No webhook social accounts'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start bulk posting')).onPressed, isNull);
  });
}
