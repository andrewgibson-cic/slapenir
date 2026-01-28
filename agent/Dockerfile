# SLAPENIR Agent Environment
# Wolfi-based minimal container for AI agent execution with glibc compatibility

FROM cgr.dev/chainguard/wolfi-base:latest

# Metadata
LABEL maintainer="andrew.gibson-cic@ibm.com"
LABEL description="SLAPENIR Agent: Secure Python execution environment with process supervision"
LABEL version="0.1.0"

# Install build tools, Python, and s6-overlay for process supervision
RUN apk add --no-cache \
    python-3.11 \
    py3-pip \
    build-base \
    git \
    curl \
    ca-certificates \
    s6-overlay

# Install step-cli for certificate management (copy from step-ca image)
COPY --from=smallstep/step-ca:latest /usr/local/bin/step /usr/local/bin/step

# Create agent user (non-root for security)
RUN addgroup -g 1000 agent && \
    adduser -D -u 1000 -G agent agent

# Set up directories
RUN mkdir -p /home/agent/certs \
             /home/agent/workspace \
             /home/agent/scripts \
             /etc/s6-overlay/s6-rc.d/agent-svc && \
    chown -R agent:agent /home/agent

# Copy s6 service configuration
COPY s6-overlay/ /etc/s6-overlay/

# Copy agent scripts
COPY scripts/ /home/agent/scripts/
RUN chmod +x /home/agent/scripts/*.sh

# Install Python dependencies (common AI/ML packages)
RUN pip install --no-cache-dir --break-system-packages \
    requests \
    httpx \
    aiohttp \
    pydantic \
    python-dotenv

# Set working directory
WORKDIR /home/agent/workspace

# Switch to agent user
USER agent

# Environment variables
ENV PYTHON_VERSION=3.11 \
    PYTHONUNBUFFERED=1 \
    HOME=/home/agent \
    PATH=/home/agent/.local/bin:$PATH

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "import sys; sys.exit(0)" || exit 1

# Use s6-overlay as init system
ENTRYPOINT ["/init"]
CMD []