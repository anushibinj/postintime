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
