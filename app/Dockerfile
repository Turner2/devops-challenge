# syntax=docker/dockerfile:1

# ---- Stage 1: production dependencies only -------------------------------
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---- Stage 2: run the unit tests inside the build -------------------------
# A failing test fails `docker build`, so a broken image can never be pushed.
FROM node:24-alpine AS test
WORKDIR /app
ENV NODE_ENV=test
COPY package.json package-lock.json ./
RUN npm ci
COPY src/ ./src/
COPY tests/ ./tests/
RUN npm run test:ci

# ---- Stage 3: runtime image ----------------------------------------------
FROM node:24-alpine AS runtime
ARG APP_VERSION=dev
ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=${APP_VERSION}
WORKDIR /app

# Non-root user with a fixed UID so Kubernetes runAsNonRoot can verify it.
RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app app

COPY --from=deps --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app package.json ./
COPY --chown=app:app src/ ./src/

USER 10001
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

# Run node directly (not via npm) so SIGTERM reaches the app.
CMD ["node", "src/index.js"]
