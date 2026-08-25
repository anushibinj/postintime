# PostInTime

Channel-centric content management and social publishing application.

## Stack

- **Frontend:** React, TypeScript, Vite, TanStack Query, Ant Design
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

## Development

See [PRD.md](./PRD.md) for full product specification.

### Running tests

```bash
# Backend
cd backend && mvn clean test

# Frontend
cd frontend && pnpm lint && pnpm build
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
| Posts | `GET/POST /api/v1/channels/{id}/posts`, `GET/PATCH/DELETE .../posts/{postId}` |
| Media | `POST /api/v1/media`, `DELETE /api/v1/media/{id}` |
| Social Accounts | `GET/POST /api/v1/channels/{id}/social-accounts` (posting mode: `manual` or `webhook`, optional webhook URL and Basic auth) |
| Publishing | `GET/POST .../posts/{postId}/targets`, `POST .../targets/toggle`, `POST .../targets/{id}/publish`, `POST .../mark-published` |
| Public | `GET /api/v1/public/channels`, `POST /api/v1/public/channels/{channelId}/posts` (API token) |

Public API docs (list channels and create posts): [http://localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html). OpenAPI JSON: `/v3/api-docs`. Click **Authorize** and paste a `pit_…` token.

## Environment

Copy `.env.example` to `.env` and adjust values. For local development:

- `docker compose up -d --build` runs PostgreSQL, MinIO, backend, and frontend
- Host ports: `BACKEND_HOST_PORT` (default 8080), `FRONTEND_HOST_PORT` (5173), `MINIO_API_HOST_PORT` (9000), `MINIO_CONSOLE_HOST_PORT` (9001); PostgreSQL stays on 5432
- Backend uses Java 21 (`export JAVA_HOME` to JDK 21 if needed)
- Frontend connects directly to `VITE_API_BASE_URL` (no Vite proxy). Media file URLs in API responses use `APPLICATION_ROOT_URL` (`app.base-url`); keep those two in sync with the published backend host port.
- Expired JWT sessions are cleared in the browser and the user is sent to `/login`
- Personal API tokens are created in Settings and used as Bearer tokens for REST access
- `GET /api/v1/public/channels` lists the authenticated user's channels and metadata (`Authorization: Bearer pit_…` or `X-Api-Key`)
- `POST /api/v1/public/channels/{channelId}/posts` creates a post in that channel. JSON body: `{ "title", "caption", "mediaId", "status" }`. Multipart form: `title`, `caption`, `status`, and `media` (image file). Auth is the same API token.
- Swagger UI for those public APIs: `http://localhost:8080/swagger-ui.html` (OpenAPI at `/v3/api-docs`)
- Call `http://localhost:8080` from Postman (not the Vite origin). CORS allows any Origin for Bearer clients; missing tokens return 401.
- Each social account is **Manual** (toggle published locally) or **Webhook**. Webhook accounts POST multipart `title`, `caption`, and optional `media` to the configured URL (optional HTTP Basic). A successful webhook marks that account published on the post; failures return `PUBLISH_FAILED` with the response body.
