import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

/// A signed-in app with one channel, opened on that channel's page.
Future<({TestApp app, String channelId})> openChannel(
  WidgetTester tester, {
  void Function(FakeBackend backend, String channelId)? seed,
}) async {
  final app = await createApp();
  final channel = app.backend.addChannel(name: 'Tech', slug: 'tech');
  final channelId = channel['id']! as String;
  seed?.call(app.backend, channelId);
  await pumpApp(tester, app);
  await tapText(tester, 'View');
  return (app: app, channelId: channelId);
}

void main() {
  testWidgets('lists posts with their captions, newest update first', (tester) async {
    await openChannel(
      tester,
      seed: (backend, channelId) {
        backend.addPost(channelId, title: 'First post', caption: 'Old caption');
        backend.addPost(channelId, title: 'Second post', caption: 'Newer caption');
      },
    );

    expect(find.text('First post'), findsOneWidget);
    expect(find.text('Newer caption'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Second post')).dy,
      lessThan(tester.getTopLeft(find.text('First post')).dy),
      reason: 'sorted by updatedAt,desc',
    );
    expect(find.text('1-2 of 2 posts'), findsOneWidget);
  });

  testWidgets('each post row is one named, tappable item for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await openChannel(
      tester,
      seed: (backend, channelId) {
        backend.addPost(channelId, title: 'First post', caption: 'Old caption');
      },
    );

    // The row announces its title and caption together, instead of an unnamed button.
    final row = find.bySemanticsLabel(RegExp(r'First post\s+Old caption'));
    expect(row, findsOneWidget);
    expect(tester.getSemantics(row).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('shows an empty state when the channel has no posts', (tester) async {
    await openChannel(tester);
    expect(find.text('No posts yet'), findsOneWidget);
  });

  testWidgets('creates a post from the form and opens it', (tester) async {
    final opened = await openChannel(tester);

    await tapText(tester, 'New Post');
    expect(find.text('New post'), findsOneWidget);
    // A title is required before the post can be created.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create post')).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, '').first, 'Launch day');
    await tester.pump();
    await tester.enterText(
      find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText?.startsWith('Write the caption') == true),
      'We are live!',
    );
    await tester.pump();
    expect(find.text('12 characters'), findsOneWidget);
    expect(find.text('Keep working on this post. Drafts are not treated as ready to publish.'), findsOneWidget);

    await scrollTo(tester, find.text('Ready'));
    await tester.tap(find.text('Ready'));
    await tester.pump();
    expect(find.text('This post is ready. You can add publishing targets and mark them published.'), findsOneWidget);

    await tapText(tester, 'Create post');

    expect(find.text('Post created'), findsOneWidget);
    expect(find.text('View post'), findsOneWidget);
    expect(find.text('Launch day'), findsOneWidget);
    expect(find.text('We are live!'), findsOneWidget);
    expect(find.text('12 characters'), findsOneWidget);
    final body =
        opened.app.backend.bodies[opened.app.backend.log.indexOf('POST /api/v1/channels/${opened.channelId}/posts')]!
            as Map;
    expect(body, {'title': 'Launch day', 'caption': 'We are live!', 'status': 'ready'});
  });

  testWidgets('edits a post, filling the form from the saved post', (tester) async {
    final opened = await openChannel(
      tester,
      seed: (backend, channelId) {
        backend.addPost(channelId, title: 'Old title', caption: 'Old caption', status: 'ready');
      },
    );

    await tapText(tester, 'Old title');
    expect(find.text('View post'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit post'), findsOneWidget);
    expect(find.text('Update the image, caption, and status.'), findsOneWidget);
    expect(find.text('Old title'), findsOneWidget);
    expect(find.text('Old caption'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Old title'), 'New title');
    await tester.pump();
    await tapText(tester, 'Save changes');

    expect(find.text('Post updated'), findsOneWidget);
    expect(find.text('View post'), findsOneWidget);
    expect(find.text('New title'), findsOneWidget);
    expect(opened.app.backend.posts[opened.channelId]!.single['title'], 'New title');
  });

  testWidgets('deleting a post asks first and returns to the channel', (tester) async {
    final opened = await openChannel(
      tester,
      seed: (backend, channelId) {
        backend.addPost(channelId, title: 'Doomed');
      },
    );

    await tapText(tester, 'Doomed');
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete post?'), findsOneWidget);

    await tapText(tester, 'Cancel');
    expect(opened.app.backend.posts[opened.channelId], hasLength(1));

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(opened.app.backend.posts[opened.channelId], isEmpty);
    expect(find.text('No posts yet'), findsOneWidget);
  });

  testWidgets('pages through posts and can change the page size', (tester) async {
    await openChannel(
      tester,
      seed: (backend, channelId) {
        for (var i = 1; i <= 25; i++) {
          backend.addPost(channelId, title: 'Post $i');
        }
      },
    );

    expect(find.text('Post 25'), findsOneWidget);
    await scrollTo(tester, find.text('1-20 of 25 posts'));
    expect(find.text('Post 5'), findsNothing);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Post 5'), findsOneWidget);
    expect(find.text('Post 25'), findsNothing);
    await scrollTo(tester, find.text('21-25 of 25 posts'));

    await tester.tap(find.text('20 / page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50 / page').last);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('1-25 of 25 posts'));
    expect(find.text('1-25 of 25 posts'), findsOneWidget);
  });

  testWidgets('the search screen filters by text and by status', (tester) async {
    await openChannel(
      tester,
      seed: (backend, channelId) {
        backend.addPost(channelId, title: 'Alpha launch', status: 'ready');
        backend.addPost(channelId, title: 'Beta notes', status: 'draft');
        backend.addPost(channelId, title: 'Alpha draft', status: 'draft');
      },
    );

    await tester.tap(find.byTooltip('Search posts'));
    await tester.pumpAndSettle();
    expect(find.text('Beta notes'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '').first, 'alpha');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Alpha launch'), findsOneWidget);
    expect(find.text('Alpha draft'), findsOneWidget);
    expect(find.text('Beta notes'), findsNothing);

    await tester.tap(find.text('Ready'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha launch'), findsOneWidget);
    expect(find.text('Alpha draft'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha draft'), findsOneWidget);
  });

  testWidgets('account buttons mark a post as posted and unmark it', (tester) async {
    final opened = await openChannel(
      tester,
      seed: (backend, channelId) {
        backend.addAccount(channelId, platform: 'instagram', name: 'Insta');
        backend.addPost(channelId, title: 'Photo');
      },
    );
    final button = find.byTooltip('Insta · Manual · Not posted');
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Insta · Manual · Posted'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    final targets = opened.app.backend.targets.values.single;
    expect(targets.single['status'], 'published');

    await tester.tap(find.byTooltip('Insta · Manual · Posted'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Insta · Manual · Not posted'), findsOneWidget);
  });

  testWidgets('only enabled accounts get a button', (tester) async {
    await openChannel(
      tester,
      seed: (backend, channelId) {
        backend.addAccount(channelId, platform: 'x', name: 'On X');
        backend.addAccount(channelId, platform: 'facebook', name: 'On FB')['enabled'] = false;
        backend.addPost(channelId, title: 'Photo');
      },
    );
    expect(find.byTooltip('On X · Manual · Not posted'), findsOneWidget);
    expect(find.byTooltip('On FB · Manual · Not posted'), findsNothing);
  });

  testWidgets('a failing webhook shows the server message in an error dialog', (tester) async {
    final opened = await openChannel(
      tester,
      seed: (backend, channelId) {
        backend.addAccount(
          channelId,
          platform: 'linkedin',
          name: 'Hook',
          mode: 'webhook',
          webhookUrl: 'https://n8n.test/hook',
        );
        backend.addPost(channelId, title: 'Photo');
      },
    );
    opened.app.backend.webhookFailure = 'Webhook responded 500: boom';

    await tester.tap(find.byTooltip('Hook · Webhook · Not posted'));
    await tester.pumpAndSettle();

    expect(find.text('Publish failed'), findsOneWidget);
    expect(find.text('Webhook responded 500: boom'), findsOneWidget);
    await tapText(tester, 'OK');
    expect(find.byTooltip('Hook · Webhook · Not posted'), findsOneWidget);
  });
}
