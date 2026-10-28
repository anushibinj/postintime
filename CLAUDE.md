# postintime

## Package manager

The `frontend/` app uses **pnpm** exclusively (see `frontend/pnpm-lock.yaml`). Do not use `npm` or `yarn`:

- Install deps: `pnpm install`
- Dev server: `pnpm dev`
- Lint: `pnpm lint`
- Test: `pnpm test`
- Build: `pnpm build`

`frontend/package.json` pins `packageManager: pnpm@10.33.0` and has a `preinstall` guard that fails
if invoked via `npm install`/`yarn install`. `frontend/.gitignore` also excludes `package-lock.json`
and `yarn.lock` so they can't be committed by accident.

## Mobile app

`mobile/` is a Flutter client that mirrors `frontend/`. Run these from `mobile/`:

- Install deps: `flutter pub get`
- Lint: `flutter analyze`
- Test: `flutter test`
- Format: `dart format .` (120 column width, set in `analysis_options.yaml`)
- Try it without the backend: `dart run tool/mock_server.dart`

The API address is a build-time define: `--dart-define=API_BASE_URL=...`. When a web feature changes,
change the matching Flutter feature in `mobile/lib/features/` and its widget test. The tests run against
the in-memory fake backend in `mobile/test/support/fake_backend.dart`, so update it when an API shape changes.
