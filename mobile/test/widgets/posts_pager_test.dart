import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postintime/features/posts/posts_pager.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('does not render when there are no posts', (tester) async {
    await tester.pumpWidget(host(PostsPager(page: 0, size: 20, totalItems: 0, onChange: (_, _) {})));
    expect(find.byType(IconButton), findsNothing);
    expect(find.textContaining('posts'), findsNothing);
  });

  testWidgets('requests the next zero-based page', (tester) async {
    (int, int)? change;
    await tester.pumpWidget(host(PostsPager(page: 0, size: 2, totalItems: 5, onChange: (p, s) => change = (p, s))));

    expect(find.text('1-2 of 5 posts'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    expect(change, (1, 2));
  });

  testWidgets('disables previous on the first page and next on the last', (tester) async {
    await tester.pumpWidget(host(PostsPager(page: 0, size: 20, totalItems: 25, onChange: (_, _) {})));
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left)).onPressed, isNull);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNotNull);

    await tester.pumpWidget(host(PostsPager(page: 1, size: 20, totalItems: 25, onChange: (_, _) {})));
    expect(find.text('21-25 of 25 posts'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left)).onPressed, isNotNull);
  });

  testWidgets('changing the page size keeps the page when it still exists', (tester) async {
    (int, int)? change;
    await tester.pumpWidget(host(PostsPager(page: 2, size: 10, totalItems: 45, onChange: (p, s) => change = (p, s))));

    expect(find.text('10 / page'), findsOneWidget);
    await tester.tap(find.text('10 / page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 / page').last);
    await tester.pumpAndSettle();
    expect(change, (2, 20));

    // 45 posts at 50 per page is a single page, so page 2 no longer exists.
    await tester.tap(find.text('10 / page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50 / page').last);
    await tester.pumpAndSettle();
    expect(change, (0, 50));
  });

  testWidgets('shows a size that is not one of the presets', (tester) async {
    await tester.pumpWidget(host(PostsPager(page: 0, size: 7, totalItems: 20, onChange: (_, _) {})));
    expect(find.text('7 / page'), findsOneWidget);
  });
}
