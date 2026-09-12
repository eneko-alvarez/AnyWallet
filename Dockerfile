FROM node:24-bookworm-slim AS build

WORKDIR /app
COPY package.json package-lock.json ./
COPY server/package.json server/package.json
RUN npm ci

COPY server/tsconfig.json server/tsconfig.build.json server/
COPY server/src server/src
RUN npm --workspace server run build

FROM node:24-bookworm-slim AS runtime

ENV NODE_ENV=production
WORKDIR /app
RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates openssl \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
COPY server/package.json server/package.json
RUN npm ci --omit=dev \
    && npm cache clean --force \
    && mkdir -p /app/server/data \
    && chown -R node:node /app

COPY --from=build --chown=node:node /app/server/dist server/dist
COPY --chown=node:node server/public server/public

USER node
EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:' + (process.env.PORT || 8787) + '/health', { headers: { 'x-forwarded-proto': 'https' } }).then(r => { if (!r.ok) process.exit(1) }).catch(() => process.exit(1))"
CMD ["node", "server/dist/index.js"]
