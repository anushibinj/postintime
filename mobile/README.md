# PostInTime mobile

A Flutter client for PostInTime that mirrors the web app in [`frontend/`](../frontend): the same
screens, the same API calls and the same behaviour, laid out for a phone. It runs on Android and iOS
(and, for a quick look, in a browser).

## Run it

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable, 3.47 or newer).

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<your-computer>:8080
```

`API_BASE_URL` is the PostInTime API (see the root README for starting the backend). Without it the app
uses `http://10.0.2.2:8080` on the Android emulator (its alias for your computer) and
`http://localhost:8080` everywhere else. You can also change the address from the sign in screen
(**Server: …** at the bottom); the choice is remembered on the device.

Things to know when pointing a phone at your own backend:

- On a real phone use your computer's LAN address, not `localhost`.
- Set the backend's `APPLICATION_ROOT_URL` to that same address. Image links in API responses are built
  from it, so a phone can only load images if that address is reachable from the phone.
- Plain `http://` is allowed so development servers work. Use `https://` for anything real.

### Try it without the backend

`tool/mock_server.dart` is a small in-memory API (no PostgreSQL or object storage) with sample data: a
channel with posts, social accounts, a bulk posting queue and an API token.

```bash
dart run tool/mock_server.dart          # http://localhost:8080, sign in as demo@example.com / password123
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

It reuses the fake backend the tests run against, so the two always agree on the API's response shapes.

## Develop

```bash
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed .   # formatting uses a 120 column width
```

The tests are widget tests that drive the whole app (router, state, API client) against an in-memory
fake of the backend, plus unit tests for the logic ported from the web hooks. They cover every screen
and flow below, including the bulk posting queue and session expiry. They load the real Roboto and
icon fonts from the Flutter SDK, so layout overflow checks match what a phone shows.

## What is in the app

Everything the web app does is available:

| Web app | Mobile app |
| --- | --- |
| Register, sign in, JWT session, sign out when the token expires (timer and 401 `AUTH_EXPIRED`) | Same. The token is kept in the Keychain / Keystore. |
| Sidebar: Channels, Settings | Bottom navigation bar: Channels, Settings |
| Header: signed-in user, Logout | Account menu in the top bar (and a Logout button in Settings) |
| Collapsible sidebar, remembered in localStorage | Not applicable on a phone |
| Channels as cards: view, edit, delete, enabled state, counts | Same |
| Create / edit channel (name, slug, description, enabled) | Bottom sheet with the same fields and rules (slug is fixed once created) |
| Channel page: description, counts, Manage social accounts, New Post | Same |
| Posts as bordered rows: thumbnail (`?size=` resized), title, caption preview, queued label | Same. Account buttons sit under the text so they fit on a phone. |
| Per-account publish buttons (send webhook, mark / unmark posted), locked while queued | Same, including the error dialog when a webhook fails |
| Pager: page, page size 10 / 20 / 50, "1-20 of 45 posts" | Same |
| Search and Draft / Ready filter | Search screen (the magnifier on the channel page) |
| Multiselect posts across pages, "Select page", Clear | Same |
| Bulk post: interval slider 5-30 min, accounts to post to, order, timing summary | Bottom sheet with the same controls and wording |
| Bulk queue: collapsed by default, remove one post, Cancel all, recent results with errors | Same, refreshed every 10 s while a job is running |
| Post page: image, title, caption and length, status, publishing targets, queued notice | Same |
| Add targets, publish (webhook or manual), copy caption, download image, open destination, mark as published | Same (links open in the browser or the matching app) |
| New / edit post: image upload, title (200), caption, Draft / Ready | Same. Pick from the gallery or take a photo. |
| Social accounts: add, edit, enable / disable, delete, webhook URL and basic auth | Same |
| Settings: API tokens (create with expiry, change expiry, refresh, delete, copy secret once) | Same |
| API client waits up to 15 minutes for slow webhooks | Same |

Extras that only make sense on a phone: pull to refresh on every list, a server address setting on the
sign in screen, and toasts that sit at the top of the screen so they never cover a button.

## How it is built

```
lib/
  api/        API client (token, 15 min timeout, session expiry) and one class per resource
  models/     Response models and enums
  logic/      Pure logic ported from the web hooks: bulk interval, queue timing, paging params
  state/      Riverpod: cached data providers, mutations that refresh what they change, auth
  features/   One folder per area: auth, channels, posts, bulk_publish, social_accounts, settings
  widgets/    Shared widgets: tags, dialogs, toast, async button, collapsible panel
  app/        Router (go_router), theme, navigation shell
tool/         Mock API server
test/         Widget and unit tests, and the in-memory fake backend
```

State management is [Riverpod](https://riverpod.dev) in place of TanStack Query: data providers cache
for 30 seconds, retry a failed load once and are dropped on sign out, and each mutation invalidates the
same data its web counterpart does. Routing is [go_router](https://pub.dev/packages/go_router) with the
web app's routes.

## Known differences and limits

- Removing an image while editing a post has no effect on the server: the API ignores a missing
  `mediaId` (the web app behaves the same).
- When driven in a browser (the only target run here), creating a post logs a Flutter "Cannot get
  renderObject of inactive element" focus assertion (a null-check error in release builds). It comes
  from the framework's view-focus handling, the post is created and shown correctly, and it was not
  seen on any other screen. It has not been checked on Android or iOS.
- Only the web build was run in a browser here; Android and iOS builds need their own toolchains
  (Android SDK, Xcode) and were checked through analysis and the widget tests.
