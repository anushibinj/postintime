import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

/// Opens the detail page of the channel's only post.
Future<({TestApp app, String channelId, String postId})> openPost(
  WidgetTester tester, {
  void Function(FakeBackend backend, String channelId, String postId)? seed,
}) async {
  final app = await createApp();
  final channelId = app.backend.addChannel(name: 'Tech', slug: 'tech')['id']! as String;
  final postId = app.backend.addPost(channelId, title: 'Launch', caption: 'Big news!', status: 'ready')['id']! as String;
  seed?.call(app.backend, channelId, postId);
  await pumpApp(tester, app);
  await tapText(tester, 'View');
  await tapText(tester, 'Launch');
  return (app: app, channelId: channelId, postId: postId);
}

void main() {
  testWidgets('shows the post, its caption length and the empty publishing state', (tester) async {
    await openPost(tester);

    expect(find.text('View post'), findsOneWidget);
    expect(find.text('Review the image, caption, and publishing status.'), findsOneWidget);
    expect(find.text('Launch'), findsOneWidget);
    expect(find.text('Big news!'), findsOneWidget);
    expect(find.text('9 characters'), findsOneWidget);
    expect(find.text('No image'), findsOneWidget);
    await scrollTo(tester, find.text('No publishing targets yet. Add social accounts as targets.'));
    expect(find.text('Add Targets'), findsNothing, reason: 'no accounts to add yet');
  });

  testWidgets('shows a placeholder when the post has no caption', (tester) async {
    final app = await createApp();
    final channelId = app.backend.addChannel(name: 'Tech', slug: 'tech')['id']! as String;
    app.backend.addPost(channelId, title: 'Bare');
    await pumpApp(tester, app);
    await tapText(tester, 'View');
    await tapText(tester, 'Bare');

    expect(find.text('No caption'), findsOneWidget);
    expect(find.text('0 characters'), findsOneWidget);
  });

  testWidgets('adds publishing targets from the enabled accounts only', (tester) async {
    final opened = await openPost(tester, seed: (backend, channelId, postId) {
      backend.addAccount(channelId, platform: 'linkedin', name: 'Work LinkedIn');
      backend.addAccount(channelId, platform: 'x', name: 'Side X');
      backend.addAccount(channelId, platform: 'facebook', name: 'Off page')['enabled'] = false;
    });

    await scrollTo(tester, find.text('Add Targets'));
    await tapText(tester, 'Add Targets');
    expect(find.text('Add Publishing Targets'), findsOneWidget);
    expect(find.text('Work LinkedIn (linkedin)'), findsOneWidget);
    expect(find.text('Side X (x)'), findsOneWidget);
    expect(find.text('Off page (facebook)'), findsNothing);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK')).onPressed, isNull);

    await tapText(tester, 'Work LinkedIn (linkedin)');
    await tapText(tester, 'OK');

    expect(find.text('Targets added'), findsOneWidget);
    expect(find.text('Work LinkedIn'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('linkedin'), findsOneWidget);
    expect(opened.app.backend.targets[opened.postId], hasLength(1));
    // Side X is still available as a target.
    expect(find.text('Add Targets'), findsOneWidget);
  });

  testWidgets('publishing to a webhook account finishes without further steps', (tester) async {
    final opened = await openPost(tester, seed: (backend, channelId, postId) {
      final account = backend.addAccount(channelId, platform: 'x', name: 'Hook X', mode: 'webhook');
      backend.targets[postId]!.add({'id': 't1', 'socialAccountId': account['id'], 'status': 'pending', 'publishedAt': null});
    });

    await scrollTo(tester, find.byTooltip('Publish'));
    await tester.tap(find.byTooltip('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Webhook published'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('1 / 1 published'), findsOneWidget);
    expect(find.byTooltip('Publish'), findsNothing);
    expect(opened.app.backend.targets[opened.postId]!.single['status'], 'published');
  });

  testWidgets('a failed webhook is reported and the target shows as failed', (tester) async {
    final opened = await openPost(tester, seed: (backend, channelId, postId) {
      final account = backend.addAccount(channelId, platform: 'x', name: 'Hook X', mode: 'webhook');
      backend.targets[postId]!.add({'id': 't1', 'socialAccountId': account['id'], 'status': 'pending', 'publishedAt': null});
      backend.webhookFailure = 'Webhook responded 502';
    });

    await scrollTo(tester, find.byTooltip('Publish'));
    await tester.tap(find.byTooltip('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Publish failed'), findsOneWidget);
    expect(find.text('Webhook responded 502'), findsOneWidget);
    await tapText(tester, 'OK');
    expect(find.text('Failed'), findsOneWidget);
    expect(opened.app.backend.targets[opened.postId]!.single['status'], 'failed');
  });

  testWidgets('publishing to a manual account shows what to post and marks it published', (tester) async {
    final clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final opened = await openPost(tester, seed: (backend, channelId, postId) {
      final account = backend.addAccount(channelId, platform: 'instagram', name: 'Insta', profileUrl: 'https://instagram.com/me');
      backend.targets[postId]!.add({'id': 't1', 'socialAccountId': account['id'], 'status': 'pending', 'publishedAt': null});
    });

    await scrollTo(tester, find.byTooltip('Publish'));
    await tester.tap(find.byTooltip('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Publish to Insta'), findsOneWidget);
    expect(find.text('Caption'), findsWidgets);
    expect(find.text('Big news!'), findsWidgets);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('https://instagram.com/me'), findsOneWidget);
    expect(find.text('Open instagram'), findsOneWidget);
    // The post has no image, so there is nothing to download.
    expect(find.text('Download Image'), findsNothing);

    await tapText(tester, 'Copy Caption');
    expect(clipboard, ['Big news!']);
    expect(find.text('Caption copied'), findsOneWidget);

    await tapText(tester, 'Mark as Published');
    expect(find.text('Marked as published'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(opened.app.backend.targets[opened.postId]!.single['status'], 'published');
    final marked = opened.app.backend.log.indexWhere((entry) => entry.endsWith('/targets/t1/mark-published'));
    expect(opened.app.backend.bodies[marked], containsPair('notes', 'Published manually'));
  });

  testWidgets('a post in the bulk queue cannot be published individually', (tester) async {
    await openPost(tester, seed: (backend, channelId, postId) {
      final account = backend.addAccount(channelId, platform: 'x', name: 'Hook X', mode: 'webhook');
      backend.targets[postId]!.add({'id': 't1', 'socialAccountId': account['id'], 'status': 'pending', 'publishedAt': null});
      backend.jobs[channelId]!.add({
        'id': 'job1',
        'channelId': channelId,
        'intervalMinutes': 5,
        'status': 'running',
        'totalItems': 1,
        'processedItems': 0,
        'failedItems': 0,
        'socialAccountIds': [account['id']],
        'createdAt': testNow.toIso8601String(),
        'updatedAt': testNow.toIso8601String(),
        'items': [
          {
            'id': 'item1',
            'postId': postId,
            'postTitle': 'Launch',
            'position': 0,
            'status': 'pending',
            'scheduledAt': testNow.add(const Duration(minutes: 12)).toUtc().toIso8601String(),
          },
        ],
      });
    });

    await scrollTo(tester, find.textContaining('Queued for bulk posting at 3:12 PM (in 12 min)'));
    expect(find.text('The bulk posting queue will publish this post. Remove it from the queue on the channel page to post it individually.'), findsOneWidget);
    expect(find.byTooltip('Publish'), findsNothing);
  });
}
