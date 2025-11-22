# Multi-stage Docker build for recon-silly-ation

# Stage 1: Build ReScript
FROM node:18-alpine AS rescript-builder

WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./
COPY bsconfig.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY src ./src

# Build ReScript
RUN npm run build

# Stage 2: Build Haskell validator
FROM haskell:9.2-slim AS haskell-builder

WORKDIR /validator

# Copy Haskell source
COPY validator/validator-bridge.cabal ./
COPY validator/*.hs ./

# Build Haskell validator
RUN cabal update && \
    cabal build && \
    cabal install --installdir=/usr/local/bin

# Stage 3: Final runtime image
FROM node:18-alpine

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tini

# Copy built artifacts from builders
COPY --from=rescript-builder /app/lib ./lib
COPY --from=rescript-builder /app/node_modules ./node_modules
COPY --from=rescript-builder /app/package.json ./
COPY --from=haskell-builder /usr/local/bin/validator-bridge /usr/local/bin/

# Copy configuration files
COPY justfile ./
COPY examples ./examples

# Create data directory
RUN mkdir -p /data

# Set environment variables
ENV NODE_ENV=production
ENV ARANGO_URL=http://arangodb:8529
ENV ARANGO_DATABASE=reconciliation
ENV VALIDATOR_PATH=/usr/local/bin/validator-bridge

# Use tini as init system
ENTRYPOINT ["/sbin/tini", "--"]

# Default command
CMD ["node", "lib/js/src/CLI.bs.js", "--help"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "console.log('healthy')" || exit 1

# Labels
LABEL org.opencontainers.image.title="recon-silly-ation"
LABEL org.opencontainers.image.description="Documentation Reconciliation System"
LABEL org.opencontainers.image.version="0.1.0"
LABEL org.opencontainers.image.authors="Hyperpolymath"
