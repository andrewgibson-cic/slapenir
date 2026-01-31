# SLAPENIR Proxy Dockerfile
# Multi-stage build for minimal production image

# Build stage
FROM rust:1.93-alpine AS builder

# Install build dependencies
RUN apk add --no-cache musl-dev openssl-dev openssl-libs-static pkgconfig

WORKDIR /app

# Copy manifests
COPY Cargo.toml Cargo.lock ./

# Copy source code
COPY src ./src

# Build release binary
RUN cargo build --release --locked

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache ca-certificates curl libgcc

# Create non-root user
RUN addgroup -g 1000 proxy && \
    adduser -D -u 1000 -G proxy proxy

# Copy binary from builder
COPY --from=builder /app/target/release/slapenir-proxy /usr/local/bin/proxy

# Set ownership
RUN chown proxy:proxy /usr/local/bin/proxy

# Create app directory and set as working directory
WORKDIR /app

# Switch to non-root user
USER proxy

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Run the proxy
CMD ["/usr/local/bin/proxy"]