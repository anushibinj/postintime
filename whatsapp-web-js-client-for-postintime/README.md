# whatsapp-web-js-client-for-postintime

A small WhatsApp client built on [whatsapp-web.js](https://github.com/wwebjs/whatsapp-web.js). It logs in to
your WhatsApp account, then listens for postintime webhook calls and posts each post's **caption** as a text
message to one of your WhatsApp **channels**.

> whatsapp-web.js drives WhatsApp Web in a headless Chrome. It is not an official WhatsApp API, and WhatsApp
> may block accounts that use unofficial clients. Use an account you can afford to lose.

## Requirements

- Node.js 20.6 or newer
- pnpm (`corepack enable`)
- A WhatsApp channel that you **own or are an admin of** (only admins can post to a channel)

## Setup

```bash
pnpm install
cp .env.example .env
```

In `.env`, set the channel to post to, either:

- `WHATSAPP_CHANNEL_INVITE_CODE`: the channel's link from **Channel info > Share**, e.g.
  `https://whatsapp.com/channel/0029Va...` (the bare code after `/channel/` works too), or
- `WHATSAPP_CHANNEL_ID`: the channel id, e.g. `120363000000000000@newsletter`. The client prints the ids of
  your channels after it logs in.

## Run

```bash
pnpm start
```

1. The first time, a QR code is printed in the terminal. On your phone open WhatsApp >
   **Settings > Linked devices > Link a device** and scan it.
2. The login is saved in `.wwebjs_auth/`, so later starts log in without a QR code. Delete that folder to log
   out and link again.
3. Once WhatsApp is ready, the webhook server starts:
   `Listening for postintime webhooks on http://0.0.0.0:3000/webhooks/post-to-channel`

Stop it with `Ctrl+C`.

## Connect postintime

In postintime, open the channel's **Social accounts**, add (or edit) an account with posting mode **Webhook**
and set the webhook URL to:

```
http://<host running this client>:3000/webhooks/post-to-channel
```

If you set `WEBHOOK_USERNAME` / `WEBHOOK_PASSWORD` in `.env`, choose **Basic** auth on the social account and
enter the same username and password.

## Webhook

### `POST /webhooks/post-to-channel`

Accepts the multipart form data postintime sends (`media`, `title`, `caption`), and also JSON or
form-urlencoded bodies. Only `caption` is used: it is sent as a text message to the channel. `media` and
`title` are ignored for now.

| Response | When |
| --- | --- |
| `200 {"status":"sent"}` | The caption was posted to the channel |
| `400 CAPTION_REQUIRED` | `caption` is missing or blank |
| `401 UNAUTHORIZED` | Basic auth is on and the credentials are missing or wrong |
| `502 WHATSAPP_SEND_FAILED` | WhatsApp refused the message (the reason is in `message`) |

postintime shows non-2xx responses as a failed post, with the response body.

Try it with curl:

```bash
curl -F title=Test -F caption='Hello from postintime' http://localhost:3000/webhooks/post-to-channel
```

`GET /health` returns `{"status":"ok"}`.

## Settings

| Variable | Default | Meaning |
| --- | --- | --- |
| `WHATSAPP_CHANNEL_ID` | | Channel id to post to (`...@newsletter`) |
| `WHATSAPP_CHANNEL_INVITE_CODE` | | Channel invite link or code, used when no id is set |
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
