# PostInTime TODO

## Environment

- [ ] `cd backend && mvn clean test` needs PostgreSQL on `localhost:5432` (see `docker compose up -d`). In this Cloud Agent VM Docker is not installed, so those integration tests fail with connection refused. Frontend `pnpm lint && pnpm test && pnpm build` passes after the register-form fix.

## MVP

- [x] Phase 0: Foundation — Docker, Spring Boot, React/Vite, JWT auth, Flyway, CI
- [x] Phase 1: Channels — schema, APIs, UI, channel switcher
- [x] Phase 2: Posts — CRUD, list, detail, form, search/filter
- [x] Phase 3: Media — upload, S3/MinIO storage, preview, download
- [x] Phase 4: Social Accounts — CRUD, platform selection, enable/disable
- [x] Phase 5: Publishing — targets, manual publish, mark published
- [x] Phase 6: Production Hardening — integration tests, error handling, docs
