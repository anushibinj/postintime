import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  testWidgets('signed-out users land on the sign in screen', (tester) async {
    await pumpApp(tester, await createApp(signedIn: false));
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(find.text('Channels'), findsNothing);
  });

  testWidgets('sign in validates the form before calling the API', (tester) async {
    final app = await createApp(signedIn: false);
    await pumpApp(tester, app);

    await tapText(tester, 'Sign In');
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(app.backend.log, isEmpty);
  });

  testWidgets('wrong credentials show an error and keep the user signed out', (tester) async {
    final app = await createApp(signedIn: false);
    app.backend.users['me@example.com'] = {
      'id': 'u1',
      'email': 'me@example.com',
      'password': 'right-pass',
      'displayName': 'Me',
    };
    await pumpApp(tester, app);

    await enterField(tester, 'Email', 'me@example.com');
    await enterField(tester, 'Password', 'wrong');
    await tapText(tester, 'Sign In');

    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(app.client.token, isNull);
  });

  testWidgets('signing in opens the channels list and stores the session', (tester) async {
    final app = await createApp(signedIn: false);
    app.backend.users['me@example.com'] = {
      'id': 'u1',
      'email': 'me@example.com',
      'password': 'right-pass',
      'displayName': 'Me',
    };
    await pumpApp(tester, app);

    await enterField(tester, 'Email', 'me@example.com');
    await enterField(tester, 'Password', 'right-pass');
    await tapText(tester, 'Sign In');

    expect(find.text('No channels yet'), findsOneWidget);
    expect(app.client.token, isNotNull);
  });

  testWidgets('registering sends the typed name, email and password', (tester) async {
    final app = await createApp(signedIn: false);
    await pumpApp(tester, app);

    await tapText(tester, 'Register');
    expect(find.text('Create Account'), findsOneWidget);

    await enterField(tester, 'Display Name', 'Shibin');
    await enterField(tester, 'Email', 'anushibin007@gmail.com');
    await enterField(tester, 'Password', 'short');
    await tapText(tester, 'Register');
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    expect(app.backend.log, isEmpty);

    await enterField(tester, 'Password', 'Opentext1!');
    await tapText(tester, 'Register');

    expect(app.backend.log.first, 'POST /api/v1/auth/register');
    expect(app.backend.log.where((entry) => entry.contains('auth/register')), hasLength(1));
    expect(app.backend.bodies.first, {
      'email': 'anushibin007@gmail.com',
      'password': 'Opentext1!',
      'displayName': 'Shibin',
    });
    expect(find.text('No channels yet'), findsOneWidget);
  });

  testWidgets('a taken email shows the registration error', (tester) async {
    final app = await createApp(signedIn: false);
    app.backend.users['taken@example.com'] = {
      'id': 'u1',
      'email': 'taken@example.com',
      'password': 'x',
      'displayName': 't',
    };
    await pumpApp(tester, app);

    await tapText(tester, 'Register');
    await enterField(tester, 'Email', 'taken@example.com');
    await enterField(tester, 'Password', 'password123');
    await tapText(tester, 'Register');

    expect(find.text('Registration failed. Email may already be in use.'), findsOneWidget);
  });

  testWidgets('logging out returns to the sign in screen', (tester) async {
    final app = await createApp();
    await pumpApp(tester, app);
    expect(find.text('Channels'), findsWidgets);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Me'), findsNothing); // token only carries the email
    expect(find.text('me@example.com'), findsOneWidget);
    await tapText(tester, 'Logout');

    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(app.client.token, isNull);
  });
}
