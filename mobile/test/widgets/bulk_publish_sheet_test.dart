import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postintime/features/bulk_publish/bulk_publish_sheet.dart';
import 'package:postintime/models/models.dart';

import '../support/harness.dart';

SocialAccount account({
  String id = 'acc',
  String name = 'Account',
  Platform platform = Platform.linkedin,
  PostingMode mode = PostingMode.webhook,
  bool enabled = true,
}) {
  return SocialAccount(
    id: id,
    platform: platform,
    name: name,
    postingMode: mode,
    enabled: enabled,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

const posts = [
  BulkPublishSelection(id: 'p1', title: 'First post'),
  BulkPublishSelection(id: 'p2', title: 'Second post'),
  BulkPublishSelection(id: 'p3', title: 'Third post'),
];

Future<void> pumpSheet(
  WidgetTester tester, {
  required List<SocialAccount> accounts,
  DateTime? queueTail,
  int queuedCount = 0,
  List<BulkPublishSelection> selection = posts,
  void Function(int, List<String>)? onSubmit,
}) async {
  await pumpWidgetWithApp(
    tester,
    await createApp(),
    BulkPublishSheet(
      posts: selection,
      accounts: accounts,
      queueTail: queueTail,
      queuedCount: queuedCount,
      submitting: false,
      onCancel: () {},
      onSubmit: onSubmit ?? (_, _) {},
    ),
  );
}

void main() {
  testWidgets('defaults to a 5 minute interval on a 5-30 slider', (tester) async {
    (int, List<String>)? submitted;
    await pumpSheet(
      tester,
      accounts: [account(id: 'a1', name: 'LinkedIn hook')],
      onSubmit: (interval, ids) => submitted = (interval, ids),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 5);
    expect(slider.max, 30);
    expect(slider.value, 5);
    expect(find.text('Bulk post 3 posts'), findsOneWidget);
    expect(find.textContaining('The first post goes live right away'), findsOneWidget);
    expect(find.textContaining(RegExp(r'The last post goes live at .*\(in 10 min\)')), findsOneWidget);
    for (final label in ['5m', '10m', '15m', '20m', '25m', '30m']) {
      expect(find.text(label), findsOneWidget);
    }

    // Dragging the thumb one step (a fifth of the track) moves the interval to 10 minutes.
    final box = tester.getRect(find.byType(Slider));
    const trackPadding = 24.0;
    final step = (box.width - 2 * trackPadding) / 5;
    await tester.dragFrom(Offset(box.left + trackPadding, box.center.dy), Offset(step, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 10);
    expect(find.textContaining(RegExp(r'The last post goes live at .*\(in 20 min\)')), findsOneWidget);
    expect(find.textContaining('then one every 10 minutes'), findsOneWidget);

    await tapText(tester, 'Start bulk posting');
    expect(submitted!.$1, 10);
    expect(submitted!.$2, ['a1']);
  });

  testWidgets('queues new posts behind the posts already waiting', (tester) async {
    await pumpSheet(
      tester,
      accounts: [account(id: 'a1', name: 'LinkedIn hook')],
      queueTail: testNow.add(const Duration(minutes: 20)),
      queuedCount: 4,
    );

    expect(find.textContaining('4 posts are already queued; these join the end of the queue.'), findsOneWidget);
    expect(find.textContaining(RegExp(r'The first post goes live at .*\(in 25 min\)')), findsOneWidget);
    expect(find.textContaining(RegExp(r'The last post goes live at .*\(in 35 min\)')), findsOneWidget);
  });

  testWidgets('a single post reads naturally', (tester) async {
    await pumpSheet(
      tester,
      accounts: [account(id: 'a1')],
      selection: const [BulkPublishSelection(id: 'p1', title: 'Only')],
      queuedCount: 1,
    );

    expect(find.text('Bulk post 1 post'), findsOneWidget);
    expect(find.textContaining('1 post is already queued'), findsOneWidget);
    expect(find.textContaining('The post goes live right away.'), findsOneWidget);
  });

  testWidgets('cannot start without an enabled webhook account', (tester) async {
    await pumpSheet(
      tester,
      accounts: [
        account(id: 'a1', name: 'Manual IG', mode: PostingMode.manual),
        account(id: 'a2', name: 'Disabled hook', enabled: false),
      ],
    );

    expect(find.text('No webhook social accounts'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start bulk posting')).onPressed, isNull);
  });

  testWidgets('posts only to the picked accounts and needs at least one', (tester) async {
    (int, List<String>)? submitted;
    await pumpSheet(
      tester,
      accounts: [
        account(id: 'a1', name: 'LinkedIn hook'),
        account(id: 'a2', name: 'X hook', platform: Platform.x),
        account(id: 'a3', name: 'Manual IG', mode: PostingMode.manual),
      ],
      onSubmit: (interval, ids) => submitted = (interval, ids),
    );

    bool checked(String name) => tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, name)).value!;
    final start = find.widgetWithText(FilledButton, 'Start bulk posting');

    expect(checked('LinkedIn hook'), isTrue);
    expect(checked('X hook'), isTrue);
    expect(find.widgetWithText(CheckboxListTile, 'Manual IG'), findsNothing);
    expect(find.textContaining('Manual accounts (Manual IG) are skipped.'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'LinkedIn hook'));
    await tester.pump();
    await tester.tap(start);
    await tester.pump();
    expect(submitted!.$1, 5);
    expect(submitted!.$2, ['a2']);

    // "All accounts" re-picks everything, and a second tap clears the picks.
    await tester.tap(find.text('All accounts'));
    await tester.pump();
    expect(checked('LinkedIn hook'), isTrue);
    expect(checked('X hook'), isTrue);
    await tester.tap(find.text('All accounts'));
    await tester.pump();
    expect(checked('X hook'), isFalse);
    expect(find.text('Pick at least one social account to start bulk posting.'), findsOneWidget);
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
  });

  testWidgets('lists the posts in the order they will go out', (tester) async {
    await pumpSheet(tester, accounts: [account(id: 'a1')]);
    expect(find.text('Order'), findsOneWidget);
    for (var i = 0; i < posts.length; i++) {
      expect(find.text('${i + 1}.'), findsOneWidget);
      expect(find.text(posts[i].title), findsOneWidget);
    }
    expect(find.textContaining('Posting runs on the server, so you can leave this page.'), findsOneWidget);
  });
}
