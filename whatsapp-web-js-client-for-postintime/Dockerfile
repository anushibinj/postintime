# syntax=docker/dockerfile:1
#
# WhatsApp channel client for postintime (whatsapp-web.js + Chromium).
# Build:  docker build -t postintime-whatsapp ./whatsapp-web-js-client-for-postintime
# Run:    docker run -it --rm -p 3000:3000 -v postintime-whatsapp:/data postintime-whatsapp

FROM node:22-bookworm-slim

# Chromium for whatsapp-web.js (Puppeteer), plus fonts so emoji and non-Latin text render.
RUN apt-get update \
    && apt-get install -y --no-install-recommends chromium fonts-noto-color-emoji fonts-noto-core ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV PUPPETEER_SKIP_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    WHATSAPP_SESSION_DIR=/data/session \
    NODE_ENV=production \
    PORT=3000

WORKDIR /app
RUN corepack enable && corepack prepare pnpm@10.33.0 --activate

COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile --prod

COPY src ./src

# The WhatsApp login lives here; mount a volume so it survives restarts.
VOLUME /data
EXPOSE 3000

# /health answers 503 until WhatsApp has logged in and loaded chats, so this also reports "not ready yet".
HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=3 \
    CMD node -e "fetch('http://localhost:' + (process.env.PORT || 3000) + '/health').then((r) => process.exit(r.ok ? 0 : 1), () => process.exit(1))"

CMD ["node", "src/index.js"]
