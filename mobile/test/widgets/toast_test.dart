import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postintime/widgets/toast.dart';

import '../support/harness.dart';

void main() {
  testWidgets('shows a message at the top and hides it after a few seconds', (tester) async {
    await pumpWidgetWithApp(tester, await createApp(), const SizedBox.shrink());

    Toast.success('Saved');
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Saved'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newer message replaces the one on screen', (tester) async {
    await pumpWidgetWithApp(tester, await createApp(), const SizedBox.shrink());

    Toast.success('First');
    await tester.pump();
    Toast.error('Second');
    await tester.pump();

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('a message that arrives while the previous one is fading out does not crash', (tester) async {
    await pumpWidgetWithApp(tester, await createApp(), const SizedBox.shrink());

    Toast.success('Image uploaded');
    await tester.pump();
    // The first toast's display time is up and it is fading out, with its removal still pending.
    await tester.pump(const Duration(seconds: 3));
    Toast.success('Post created');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.text('Image uploaded'), findsNothing);
    expect(find.text('Post created'), findsNothing, reason: 'it has timed out by now too');
  });

  testWidgets('does nothing before the app has a navigator', (tester) async {
    Toast.success('Nobody is listening');
    expect(tester.takeException(), isNull);
  });
}
