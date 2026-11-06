# whatsapp-web-js-client-for-postintime

A small WhatsApp client built on [whatsapp-web.js](https://github.com/wwebjs/whatsapp-web.js). It logs in to
your WhatsApp account, then listens for postintime webhook calls and posts each post's **caption** as a text
message to a WhatsApp **channel** named in the webhook URL.

> whatsapp-web.js drives WhatsApp Web in a headless Chrome. It is not an official WhatsApp API, and WhatsApp
> may block accounts that use unofficial clients. Use an account you can afford to lose.

## Requirements

- Node.js 20.6 or newer
- pnpm (`corepack enable`)
- WhatsApp channels that you **own or are an admin of** (only admins can post to a channel)

## Setup

```bash
pnpm install
cp .env.example .env
```

The channel to post to goes in the webhook URL (see below). The client prints the ids of your channels
(`120363000000000000@newsletter`) after it logs in. WhatsApp Web loads channels a little after login, so the
list can take up to a minute to appear. If it never does, open the channel once in WhatsApp on your phone, or
set `WHATSAPP_CHANNEL_INVITE_CODE` (below) and the client prints the channel's id as `Default channel: …`.

Optionally, set a default channel in `.env` for webhook calls whose URL has no channel id, either:

- `WHATSAPP_CHANNEL_ID`: the channel id, or
- `WHATSAPP_CHANNEL_INVITE_CODE`: the channel's link from **Channel info > Share**, e.g.
  `https://whatsapp.com/channel/0029Va...` (the bare code after `/channel/` works too).

## Run

```bash
pnpm start
```

1. The first time, a QR code is printed in the terminal. On your phone open WhatsApp >
   **Settings > Linked devices > Link a device** and scan it.
2. The login is saved in `.wwebjs_auth/`, so later starts log in without a QR code. Delete that folder to log
   out and link again.
3. Once WhatsApp is ready, the webhook server starts:
   `Listening for postintime webhooks on http://0.0.0.0:3000/webhooks/post-to-channel/<channel id>`

Stop it with `Ctrl+C`.

## Run with Docker

The client is the `whatsapp` service of the postintime `docker compose` stack (repository root):

```bash
docker compose up -d --build whatsapp
docker compose logs -f whatsapp
```

Scan the QR code from the logs. The login is kept in the `whatsapp_session` volume, so restarts and rebuilds
don't ask again (`docker compose down -v` deletes it). Settings come from the root `.env`:

| Root `.env` | Passed to the client as |
| --- | --- |
| `WHATSAPP_HOST_PORT` (default `3000`) | Host port mapped to the container's port 3000 |
| `WHATSAPP_CHANNEL_ID` / `WHATSAPP_CHANNEL_INVITE_CODE` | Same names (optional default channel) |
| `WHATSAPP_WEBHOOK_USERNAME` / `WHATSAPP_WEBHOOK_PASSWORD` | `WEBHOOK_USERNAME` / `WEBHOOK_PASSWORD` |

Inside the stack the backend reaches the client at `http://whatsapp:3000/webhooks/post-to-channel/<channel id>`.
The container reports healthy once WhatsApp is logged in and the webhook server is up.

On its own: `docker build -t postintime-whatsapp .` then
`docker run -it -p 3000:3000 -v postintime-whatsapp:/data postintime-whatsapp`.

## Connect postintime

In postintime, open the channel's **Social accounts**, add (or edit) an account with posting mode **Webhook**
and set the webhook URL to:

```
http://<host running this client>:3000/webhooks/post-to-channel/<channel id>
```

for example `http://localhost:3000/webhooks/post-to-channel/120363000000000000@newsletter`
(`http://whatsapp:3000/...` when both run in the docker compose stack). The
`@newsletter` part may be left out. Use one social account per WhatsApp channel, each with its own URL.

If you set `WEBHOOK_USERNAME` / `WEBHOOK_PASSWORD` in `.env`, choose **Basic** auth on the social account and
enter the same username and password.

## Webhook

### `POST /webhooks/post-to-channel/{channelId}`

Posts to the channel `channelId` (`120363000000000000@newsletter`, or just `120363000000000000`).
`POST /webhooks/post-to-channel` without an id posts to the default channel from `.env`.

Accepts the multipart form data postintime sends (`media`, `title`, `caption`), and also JSON or
form-urlencoded bodies. Only `caption` is used: it is sent as a text message to the channel. `media` and
`title` are ignored for now.

| Response | When |
| --- | --- |
| `200 {"status":"sent"}` | The caption was posted to the channel |
| `400 CAPTION_REQUIRED` | `caption` is missing or blank |
| `400 CHANNEL_REQUIRED` | The URL has no channel id and no default channel is set |
| `401 UNAUTHORIZED` | Basic auth is on and the credentials are missing or wrong |
| `502 WHATSAPP_SEND_FAILED` | WhatsApp refused the message (the reason is in `message`) |
| `503 WHATSAPP_NOT_READY` | The client is still logging in to WhatsApp (or waiting for the QR code); retry later |

postintime shows non-2xx responses as a failed post, with the response body.

Try it with curl:

```bash
curl -F title=Test -F caption='Hello from postintime' http://localhost:3000/webhooks/post-to-channel/120363000000000000@newsletter
```

`GET /health` returns `200 {"status":"ok"}` once WhatsApp is logged in, and `503 {"status":"starting"}` before.

The webhook server starts listening right away, before WhatsApp has logged in, and keeps idle connections
open for 65 seconds (longer than postintime's HTTP client pool). Before, posting while the client was
starting, or reusing a connection Node had already closed, failed in postintime with
`header parser received no bytes`.

## Settings

| Variable | Default | Meaning |
| --- | --- | --- |
| `WHATSAPP_CHANNEL_ID` | | Default channel id (`...@newsletter`), for URLs without a channel id |
| `WHATSAPP_CHANNEL_INVITE_CODE` | | Default channel invite link or code, used when no default id is set |
| `PORT` | `3000` | Webhook server port |
| `HOST` | `0.0.0.0` | Address the webhook server listens on |
| `WEBHOOK_USERNAME` / `WEBHOOK_PASSWORD` | | Turn on HTTP Basic auth for the webhook |
| `WHATSAPP_SESSION_DIR` | `.wwebjs_auth` | Where the WhatsApp login is saved |
| `HEADLESS` | `true` | `false` shows the Chrome window |
| `PUPPETEER_EXECUTABLE_PATH` | | Use an installed Chrome instead of the one Puppeteer downloads |

## Develop

```bash
pnpm test
```

The tests run the webhook server with a fake WhatsApp sender, so they need no phone or Chrome.
