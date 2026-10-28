import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postintime/features/bulk_publish/bulk_publish_jobs.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

Map<String, dynamic> jobJson(String channelId, List<Map<String, dynamic>> items, {String status = 'running'}) => {
  'id': 'job-1',
  'channelId': channelId,
  'intervalMinutes': 5,
  'status': status,
  'totalItems': items.length,
  'processedItems': 0,
  'failedItems': 0,
  'socialAccountIds': ['account'],
  'createdAt': testNow.toIso8601String(),
  'updatedAt': testNow.toIso8601String(),
  'items': items,
};

Map<String, dynamic> itemJson(
  String id,
  String title,
  String status, {
  int minutes = 5,
  int? doneMinutesAgo,
  String? error,
}) => {
  'id': id,
  'postId': 'post-$id',
  'postTitle': title,
  'position': 0,
  'status': status,
  'scheduledAt': testNow.add(Duration(minutes: minutes)).toUtc().toIso8601String(),
  'errorMessage': error,
  'processedAt': doneMinutesAgo == null
      ? null
      : testNow.subtract(Duration(minutes: doneMinutesAgo)).toUtc().toIso8601String(),
};

Future<TestApp> pumpJobs(
  WidgetTester tester,
  List<Map<String, dynamic>> items, {
  void Function(FakeBackend)? seed,
}) async {
  final app = await createApp();
  app.backend.jobs['channel'] = [jobJson('channel', items)];
  app.backend.channels['channel'] = {'id': 'channel'};
  app.backend.posts['channel'] = [];
  app.backend.accounts['channel'] = [];
  seed?.call(app.backend);
  await pumpWidgetWithApp(tester, app, const SingleChildScrollView(child: BulkPublishJobs(channelId: 'channel')));
  return app;
}

void main() {
  testWidgets('keeps the queue collapsed until it is opened', (tester) async {
    await pumpJobs(tester, [
      itemJson('1', 'First queued', 'pending', minutes: 5),
      itemJson('2', 'Second queued', 'pending', minutes: 10),
    ]);

    expect(find.text('Bulk posting queue'), findsOneWidget);
    expect(find.text('2 posts'), findsOneWidget);
    expect(find.textContaining('Next 3:05 PM (in 5 min)'), findsOneWidget);
    expect(find.text('First queued'), findsNothing);

    await tester.tap(find.text('Bulk posting queue'));
    await tester.pumpAndSettle();
    expect(find.text('First queued'), findsOneWidget);
    expect(find.text('Second queued'), findsOneWidget);
    expect(find.text('3:05 PM (in 5 min)'), findsOneWidget);
    expect(find.text('3:10 PM (in 10 min)'), findsOneWidget);
    expect(find.text('5 min gap'), findsNWidgets(2));
  });

  testWidgets('removes a single post from the queue', (tester) async {
    final app = await pumpJobs(tester, [
      itemJson('1', 'First queued', 'pending', minutes: 5),
      itemJson('2', 'Second queued', 'pending', minutes: 10),
    ]);

    await tester.tap(find.text('Bulk posting queue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove First queued from the queue'));
    await tester.pumpAndSettle();

    expect(app.backend.log, contains('POST /api/v1/channels/channel/bulk-publish-jobs/job-1/items/1/cancel'));
    expect(find.text('Removed "First queued" from the queue'), findsOneWidget);
    expect(find.text('1 post'), findsOneWidget);
    expect(find.text('First queued'), findsNothing);
    expect(find.text('Second queued'), findsOneWidget);
  });

  testWidgets('cancel all asks first, then clears the queue', (tester) async {
    final app = await pumpJobs(tester, [
      itemJson('1', 'First queued', 'pending', minutes: 5),
      itemJson('2', 'Second queued', 'pending', minutes: 10),
    ]);

    await tester.tap(find.text('Cancel all'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel all queued posts?'), findsOneWidget);
    expect(find.text('Posts that have not gone live yet will not be posted.'), findsOneWidget);

    await tester.tap(find.text('Keep them'));
    await tester.pumpAndSettle();
    expect(app.backend.log.where((entry) => entry.endsWith('/cancel')), isEmpty);

    await tester.tap(find.text('Cancel all'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel all'));
    await tester.pumpAndSettle();

    expect(app.backend.log, contains('POST /api/v1/channels/channel/bulk-publish-jobs/job-1/cancel'));
    expect(find.text('Bulk posting queue cleared'), findsOneWidget);
    expect(find.text('Bulk posting queue'), findsNothing);
  });

  testWidgets('shows the post being published right now and locks its removal', (tester) async {
    await pumpJobs(tester, [
      itemJson('1', 'Going out', 'publishing', minutes: 0, doneMinutesAgo: 1),
      itemJson('2', 'Next up', 'pending', minutes: 5),
    ]);

    expect(find.text('Posting now'), findsOneWidget);
    await tester.tap(find.text('Bulk posting queue'));
    await tester.pumpAndSettle();
    expect(find.text('Posting now'), findsNWidgets(2));
    final remove = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close).first);
    expect(remove.onPressed, isNull, reason: 'a post that is being posted cannot be removed');
    expect(find.byTooltip('Being posted right now'), findsOneWidget);
  });

  testWidgets('lists recent results with their status and any error', (tester) async {
    await pumpJobs(tester, [
      itemJson('1', 'Went live', 'published', doneMinutesAgo: 10),
      itemJson('2', 'Broke', 'failed', doneMinutesAgo: 5, error: 'Webhook responded 500'),
      itemJson('3', 'Not needed', 'skipped', doneMinutesAgo: 3, error: 'Already published'),
      itemJson('4', 'Half done', 'partial', doneMinutesAgo: 2),
    ]);

    expect(find.text('Bulk posting queue'), findsNothing, reason: 'nothing is waiting');
    expect(find.text('Recent bulk posts (4)'), findsOneWidget);
    await tester.tap(find.text('Recent bulk posts (4)'));
    await tester.pumpAndSettle();

    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text('Partly failed'), findsOneWidget);
    expect(find.text('Webhook responded 500'), findsOneWidget);
    expect(find.text('Already published'), findsOneWidget);
    // Newest first.
    expect(tester.getTopLeft(find.text('Half done')).dy, lessThan(tester.getTopLeft(find.text('Went live')).dy));
    expect(find.text('Oct 27, 2:55 PM'), findsOneWidget);
  });

  testWidgets('renders nothing when there are no jobs', (tester) async {
    await pumpJobs(tester, []);
    expect(find.text('Bulk posting queue'), findsNothing);
    expect(find.textContaining('Recent bulk posts'), findsNothing);
  });
}
