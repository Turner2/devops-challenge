# ── Stage 1: Install production dependencies ───────────────────
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev

# ── Stage 2: Run tests ─────────────────────────────────────────
FROM node:18-alpine AS test
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY src/ ./src/
COPY tests/ ./tests/
RUN npm run test:ci

# ── Stage 3: Production image ──────────────────────────────────
FROM node:18-alpine AS production
WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=deps /app/node_modules ./node_modules
COPY src/ ./src/
COPY package.json ./

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
