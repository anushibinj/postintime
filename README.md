# PostInTime

Channel-centric content management and social publishing application.

## Stack

- **Frontend:** React, TypeScript, Vite, TanStack Query, Ant Design
- **Backend:** Spring Boot 3, Java 21, PostgreSQL, Flyway
- **Storage:** MinIO (local) / S3-compatible object storage

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Java 21
- Node.js 20+ and pnpm

### 1. Start infrastructure

```bash
docker compose up -d
```

### 2. Configure environment

```bash
cp .env.example .env
```

### 3. Start backend

```bash
cd backend
mvn spring-boot:run
```

API runs at `http://localhost:8080`.

### 4. Start frontend

```bash
cd frontend
pnpm install
pnpm dev
```

App runs at `http://localhost:5173`.

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

All APIs are under `/api/v1`. Authentication uses JWT Bearer tokens.

### Key endpoints

| Resource | Endpoints |
|----------|-----------|
| Auth | `POST /api/v1/auth/register`, `POST /api/v1/auth/login` |
| Channels | `GET/POST /api/v1/channels`, `GET/PATCH/DELETE /api/v1/channels/{id}` |
| Posts | `GET/POST /api/v1/channels/{id}/posts`, `GET/PATCH/DELETE .../posts/{postId}` |
| Media | `POST /api/v1/media`, `DELETE /api/v1/media/{id}` |
| Social Accounts | `GET/POST /api/v1/channels/{id}/social-accounts` |
| Publishing | `GET/POST .../posts/{postId}/targets`, `POST .../targets/toggle`, `POST .../targets/{id}/publish`, `POST .../mark-published` |

## Environment

Copy `.env.example` to `.env` and adjust values. For local development:

- PostgreSQL runs via Docker Compose on port 5432
- MinIO runs on ports 9000 (API) and 9001 (console)
- Backend uses Java 21 (`export JAVA_HOME` to JDK 21 if needed)
- Frontend connects directly to `http://localhost:8080` (no Vite proxy)
