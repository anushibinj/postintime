# PostInTime

Channel-centric content management and social publishing application.

## Stack

- **Frontend:** React, TypeScript, Vite, TanStack Query, Ant Design
- **Mobile:** Flutter (Android and iOS), Riverpod, go_router — see [mobile/README.md](./mobile/README.md)
- **Backend:** Spring Boot 3, Java 21, PostgreSQL, Flyway
- **Storage:** MinIO (local) / S3-compatible object storage

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Java 21 and Node.js 20+ / pnpm (only if you run the apps on the host)

### 1. Configure environment

```bash
cp .env.example .env
```

### 2. Start the full stack

```bash
docker compose up -d --build
```

This starts PostgreSQL, MinIO, the Spring Boot API, and the React UI.

Host ports are set in `.env` (`BACKEND_HOST_PORT`, `FRONTEND_HOST_PORT`, `MINIO_API_HOST_PORT`, `MINIO_CONSOLE_HOST_PORT`). Defaults:

| Service | URL (default host port) |
|---------|-----|
| App | http://localhost:5173 |
| API | http://localhost:8080 |
| Swagger UI | http://localhost:8080/swagger-ui.html |
| MinIO API | http://localhost:9000 |
| MinIO console | http://localhost:9001 |

Containers still listen on 8080 (API), 80 (nginx), and 9000/9001 (MinIO). Compose publishes those to the host ports above. Set `APPLICATION_ROOT_URL` (and matching `VITE_API_BASE_URL`) to the public API origin the browser uses — media URLs from the API are built from that value. Rebuild the frontend after changing `VITE_API_BASE_URL` / `BACKEND_HOST_PORT`.

Stop with `docker compose down`.

### Run apps on the host (optional)

With only infrastructure in Docker (`docker compose up -d postgres minio`):

```bash
cd backend
mvn spring-boot:run
```

API: `http://localhost:8080`. The backend image is a multistage Alpine build (Maven JDK → layered JRE). It listens on `PORT` (default 8080).

```bash
cd frontend
pnpm install
pnpm dev
```

App: `http://localhost:5173`.

### Mobile app (optional)

The Flutter client in [`mobile/`](./mobile) offers everything the web app does on a phone. It needs the
[Flutter SDK](https://docs.flutter.dev/get-started/install) and an API it can reach:

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<your-computer>:8080
```

On a real phone use your computer's LAN address, and set `APPLICATION_ROOT_URL` to the same address so
image links work. `dart run tool/mock_server.dart` starts a small mock API with sample data if you only
want to look around. See [mobile/README.md](./mobile/README.md) for details.

## Development

See [PRD.md](./PRD.md) for full product specification.

### Running tests

```bash
# Backend
cd backend && mvn clean test

# Frontend
cd frontend && pnpm lint && pnpm build

# Mobile (Flutter)
cd mobile && flutter analyze && flutter test
```

## Architecture

See [product-architecture-flowchart.mmd](./product-architecture-flowchart.mmd).

## API

All APIs are under `/api/v1`. Call the Spring Boot server (`http://localhost:8080`), not the Vite app. Session login uses JWT Bearer tokens. Personal API tokens (`pit_…`) can also be sent as `Authorization: Bearer <token>` or `X-Api-Key`. Copy the full secret shown when the token is created (the Settings list only shows a prefix). Missing or invalid credentials return **401**.

### Key endpoints

| Resource | Endpoints |
|----------|-----------|
| Auth | `POST /api/v1/auth/register`, `POST /api/v1/auth/login` |
| API tokens | `GET/POST /api/v1/api-tokens`, `PATCH/DELETE /api/v1/api-tokens/{id}`, `POST .../refresh` |
| Channels | `GET/POST /api/v1/channels`, `GET/PATCH/DELETE /api/v1/channels/{id}` |
| Posts | `GET/POST /api/v1/channels/{id}/posts` (`page`, `size` 1–100, `search`, `status`, `sort`), `GET/PATCH/DELETE .../posts/{postId}` |
| Media | `POST /api/v1/media`, `DELETE /api/v1/media/{id}`, `GET /api/v1/media/files/**` (optional `?size=32`…`512` for square JPEG thumbnails) |
| Social Accounts | `GET/POST /api/v1/channels/{id}/social-accounts` (posting mode: `manual` or `webhook`, optional webhook URL and Basic auth) |
| Publishing | `GET/POST .../posts/{postId}/targets`, `POST .../targets/toggle`, `POST .../targets/{id}/publish`, `POST .../mark-published` |
| Bulk publishing | `GET/POST /api/v1/channels/{id}/bulk-publish-jobs` (`postIds`, `intervalMinutes` 5–30 in steps of 5, default 5, `socialAccountIds` enabled webhook accounts to post to, default all; appends to the channel queue), `GET .../bulk-publish-jobs/{jobId}`, `POST .../{jobId}/cancel`, `POST .../{jobId}/items/{itemId}/cancel` (remove one post from the queue) |
| Public | `GET /api/v1/public/channels`, `POST /api/v1/public/channels/{channelId}/posts` (API token) |

Public API docs (list channels and create posts): [http://localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html). OpenAPI JSON: `/v3/api-docs`. Click **Authorize** and paste a `pit_…` token.

## Environment

Copy `.env.example` to `.env` and adjust values. For local development:

- `docker compose up -d --build` runs PostgreSQL, MinIO, backend, and frontend
- Host ports: `BACKEND_HOST_PORT` (default 8080), `FRONTEND_HOST_PORT` (5173), `MINIO_API_HOST_PORT` (9000), `MINIO_CONSOLE_HOST_PORT` (9001); PostgreSQL stays on 5432
- Backend uses Java 21 (`export JAVA_HOME` to JDK 21 if needed)
- Frontend connects directly to `VITE_API_BASE_URL` (no Vite proxy). Media file URLs in API responses use `APPLICATION_ROOT_URL` (`app.base-url`); keep those two in sync with the published backend host port. List thumbnails request `GET .../media/files/...?size=64` (square JPEG via Thumbnailator; allowed size 16–512).
- Expired JWT sessions are cleared in the browser and the user is sent to `/login`
- Personal API tokens are created in Settings and used as Bearer tokens for REST access
- `GET /api/v1/public/channels` lists the authenticated user's channels and metadata (`Authorization: Bearer pit_…` or `X-Api-Key`)
- `POST /api/v1/public/channels/{channelId}/posts` creates a post in that channel. JSON body: `{ "title", "caption", "mediaId", "status" }`. Multipart form: `title`, `caption`, `status`, and `media` (image file). Auth is the same API token.
- Swagger UI for those public APIs: `http://localhost:8080/swagger-ui.html` (OpenAPI at `/v3/api-docs`)
- Channel post lists are paginated. `GET /api/v1/channels/{id}/posts` returns `items` (each with `bulkPublishScheduledAt` when queued) plus `page`, `size`, `totalItems`, `totalPages`, `hasNext`, and `hasPrevious`. The channel posts UI pages through results (default 20 per page) using those query parameters.
- Call `http://localhost:8080` from Postman (not the Vite origin). CORS allows any Origin for Bearer clients; missing tokens return 401.
- Each social account is **Manual** (toggle published locally) or **Webhook**. Webhook accounts POST multipart `media` (optional), `title`, and `caption` to the configured URL (optional HTTP Basic), matching Postman/Bruno form-data (text fields have no part `Content-Type`). A successful webhook marks that account published on the post; failures return `PUBLISH_FAILED` with the response body.
- **Slow webhooks:** posting webhooks (for example n8n flows uploading media to social networks) can take minutes. The backend waits up to `WEBHOOK_READ_TIMEOUT` (default `15m`) for each webhook, and the frontend's API client waits up to 15 minutes for any API response. Webhook calls run outside database transactions, so a slow post never holds a database connection or lock. Anything between the browser and the API must allow long requests too: on Cloud Run set the request timeout to at least 900 seconds (`gcloud run deploy --timeout=900`), and give any reverse proxy a matching read timeout (e.g. nginx `proxy_read_timeout 900s`). Some browsers also cap how long they wait for a response (Firefox's `network.http.response.timeout` is 300 seconds by default); bulk posting runs on the server and is not affected.
- **Bulk posting:** inside a channel, tick posts (or **Select page**; the selection is kept while you page through posts) and click **Bulk post**. Pick the interval between posts on the slider (5–30 minutes in steps of 5, default 5). Each channel has one bulk posting **queue** stored in PostgreSQL: every queued post gets its own slot (`bulk_publish_items.scheduled_at`), and a new batch is appended one interval after the last queued post (or the last bulk post that went out), so batches never start on top of each other. When the queue is idle the first post goes out right away; the rest follow one per interval in the order you selected them. If the backend falls behind (for example it was down, or a webhook was slow), later posts are pushed back so each still keeps its interval. A post is first claimed (**Posting now**), then its webhooks are called, then the result is saved; if the backend stops mid-post, the post is marked failed (not retried, since it may already be live) once it has been silent for the webhook timeout plus 5 minutes. Queued posts show **Queued for posting at 3:45 PM (in 12 min)** in the list and on the post page; they cannot be selected again or posted individually (`POST_QUEUED` / `ALREADY_QUEUED`, HTTP 409) until you remove them from the queue on the channel page. Each post is sent to every enabled **webhook** account of the channel (manual accounts are skipped, accounts where the post is already published are skipped), one account at a time. A failed post is logged, marked on the job and the target, and the batch moves on to the next post after the interval. Batches (`bulk_publish_jobs`) and queued posts (`bulk_publish_items`) are run by a backend scheduler, so you can close the browser; the channel page lists the queue with a remove button per post and **Cancel all**, plus recent bulk post results. `BULK_PUBLISH_POLL_INTERVAL_MS` (default 10000) sets how often the backend checks for due posts. On Cloud Run, keep at least one instance warm (min instances ≥ 1, CPU always allocated) or scheduled posts wait until the next request wakes the service.
