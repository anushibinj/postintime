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

## Post-MVP items

- [x] Remove the dasboard view. The Channels view already meets the requirement.
- [x] Convert Channels view into Cards instead of a Table with columns. The action buttons should be provided at the bottom of each card.
- [x] When inside a channel, I don't want the huge cards showing the number of posts and social accounts. Make them single-line and small. Place the "Manage social accounts" button at the end of the channel title row.
- [x] The posts in the Channel should appear as a list. The image should be a small square preview in the beginning of the list. And each item in the list should show the title of the post, a small preview of the caption, and whether the post was published or not in its respective channels.
- [x] Add borders to each item in the list of Posts
- [x] Add a button to collapse/expand the left pane
- [x] Rewamp the Post edit/create page to make it more UX friendly. Right now it looks like a basic form.
- [x] As soon as my auth token is expired in the frontend, log me out and clear all of the authentication state in the frontend. I should be redirected to the login page instead.
- [x] Remove the Channel selector dropdown on the top of the page Header.
- [x] The state of the left sidebar collapsing need to be persisted in localStorage so that it maintains state across page refreshes.
- [x] Allow users to create API tokens for themselves. They should be able to send the generated API token to make REST calls to the spring boot backend by providing it as a Bearer token. Allow users to delete tokens, refresh them, set expiry (even infinite expiry) for the API tokens.
- [x] REST API to list all the channels for a given user - Create a GET REST API that will return all the channels and their metadata for the user. Authenticate via API keys.
- [x] REST API for creation of posts - Add a new REST API that can be accessible by the public to create new posts for a Channel. Accept whatever input is needed to create a post - the channel ID, post title, caption and media. Authenticate via API keys.
- [x] Swagger doc for all the public APIs - Creation of posts and Listing of channels for a user.
- [x] Create a Postgres DB in Neon DB service (cloud)
- [ ] Deploy the Spring Boot Backend into Google Cloud Run
  - [ ] Set JWT_SECRET
  - [ ] Set S3 details
- [ ] Integrate this app with n8n to ingest posts into PostInTime
- [ ] Create a SeaweedFS server on my home server
- [x] Show a spinner in the frontend when image is getting uploaded
- [ ] For thumbnails that appear in the frontend, show a compressed image in the size required by the small icon (example, 32x32). And create a backend handler that will accept a URL query param like ?size=32 and accordingly return an image. For example, api/v1/media/files/users/89107080-892b-4f8a-9323-a58e7177087a/temporary/7758d5f1-2e05-4aca-87fe-f454cde35b50.png?size=32
- [x] Update the frontend app title to "Postintme"
