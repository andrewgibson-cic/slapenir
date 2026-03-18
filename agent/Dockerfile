# SLAPENIR Agent Environment
# Wolfi-based minimal container for AI agent execution with glibc compatibility

FROM cgr.dev/chainguard/wolfi-base:latest

# Metadata
LABEL maintainer="andrew.gibson-cic@ibm.com"
LABEL description="SLAPENIR Agent: Secure Python execution environment with process supervision"
LABEL version="0.1.0"

# Install build tools, Python, bash, iptables for traffic enforcement, Java 21, and build tool wrappers
RUN apk add --no-cache \
    python-3.11 \
    py3-pip \
    build-base \
    git \
    curl \
    ca-certificates \
    xz \
    openssh-client \
    bash \
    iptables \
    iproute2 \
    gnupg \
    openjdk-21 \
    gradle \
    maven \
    yarn \
    pnpm \
    ncurses-terminfo-base \
    cmake \
    ripgrep

# Install Rust/Cargo via rustup (cargo not available in Wolfi repos)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
ENV PATH=/root/.cargo/bin:$PATH

# Create minimal getconf wrapper for VS Code server compatibility (Wolfi lacks getconf)
RUN printf '#!/bin/sh\n\
case "$1" in\n\
    LONG_BIT) echo 64 ;;\n\
    GNU_LIBC_VERSION) echo "glibc 2.38" ;;\n\
    *) echo "getconf: unknown variable $1" >&2; exit 1 ;;\n\
esac\n' > /usr/bin/getconf && chmod +x /usr/bin/getconf

# Install Node.js for OpenCode CLI
RUN apk add --no-cache nodejs npm

# Install OpenCode CLI globally
RUN npm install -g opencode-ai@latest

# Install s6-overlay from GitHub releases (Wolfi doesn't have s6-overlay package)
ARG S6_OVERLAY_VERSION=3.1.6.2
ARG TARGETARCH=aarch64
RUN curl -L "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" | tar -C / -Jxpf - && \
    curl -L "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${TARGETARCH}.tar.xz" | tar -C / -Jxpf -

# Install step-cli for certificate management (copy from step-ca image)
COPY --from=smallstep/step-ca:latest /usr/local/bin/step /usr/local/bin/step

# Create agent user (non-root for security) with bash as default shell
RUN addgroup -g 1000 agent && \
    adduser -D -u 1000 -G agent -s /bin/bash agent

# Create OpenCode configuration and data directories
RUN mkdir -p /home/agent/.config/opencode \
             /home/agent/.local/share/opencode && \
    chown -R agent:agent /home/agent/.config/opencode /home/agent/.local/share/opencode && \
    chmod 755 /home/agent/.config/opencode /home/agent/.local/share/opencode

# Copy OpenCode configuration and AGENTS.md (OpenCode's instruction file)
COPY config/opencode.json /home/agent/.config/opencode/opencode.json
COPY config/AGENTS.md /home/agent/.config/opencode/AGENTS.md
# Also copy AGENTS.md to workspace (OpenCode reads it from working directory)
COPY config/AGENTS.md /home/agent/workspace/AGENTS.md
RUN chown agent:agent /home/agent/.config/opencode/opencode.json /home/agent/.config/opencode/AGENTS.md /home/agent/workspace/AGENTS.md && \
    chmod 644 /home/agent/.config/opencode/opencode.json /home/agent/.config/opencode/AGENTS.md /home/agent/workspace/AGENTS.md

# Set up directories
RUN mkdir -p /home/agent/certs \
             /home/agent/workspace \
             /home/agent/scripts \
             /etc/s6-overlay/s6-rc.d/agent-svc \
             /var/log/slapenir && \
    chown -R agent:agent /home/agent && \
    chown agent:agent /var/log/slapenir && \
    chmod 755 /var/log/slapenir

# Copy s6 service configuration
COPY s6-overlay/s6-rc.d/ /etc/s6-overlay/s6-rc.d/

# Copy cont-init.d scripts to the correct location for s6-overlay
COPY s6-overlay/cont-init.d/ /etc/cont-init.d/
RUN chmod +x /etc/cont-init.d/* 2>/dev/null || true

# Copy agent scripts
COPY scripts/ /home/agent/scripts/
RUN chmod +x /home/agent/scripts/*.sh

# Install build tool wrappers for security
# These intercept build tool commands and block execution during OpenCode sessions
RUN mkdir -p /home/agent/scripts/lib && \
    chmod +x /home/agent/scripts/*-wrapper 2>/dev/null || true

# Shadow system binaries with security wrappers
# Moves real binaries to .real suffix, creates symlinks to wrappers
RUN for tool in gradle mvn npm yarn pnpm cargo pip pip3; do \
        if command -v $tool >/dev/null 2>&1; then \
            real_path=$(which $tool); \
            # Only shadow if not already shadowed
            if [ ! -f "${real_path}.real" ]; then \
                mv "$real_path" "${real_path}.real"; \
                # Create symlink if wrapper exists
                if [ -f "/home/agent/scripts/${tool}-wrapper" ]; then \
                    ln -s /home/agent/scripts/${tool}-wrapper "$real_path"; \
                fi; \
            fi; \
        fi; \
    done

# Create gradlew symlink (catches ./gradlew)
RUN if [ -f /home/agent/scripts/gradle-wrapper ]; then \
        ln -sf /home/agent/scripts/gradle-wrapper /home/agent/scripts/gradlew; \
    fi

# Install Python dependencies (common AI/ML packages)
RUN pip install --no-cache-dir --break-system-packages \
    requests \
    httpx \
    aiohttp \
    pydantic \
    python-dotenv

# Install uv package manager for Code-Graph-RAG
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH=/root/.local/bin:$PATH
RUN uv --version

# Install Code-Graph-RAG with full Tree-sitter support
# This clones the repo and compiles Tree-sitter grammars for multi-language AST analysis
RUN git clone --depth 1 https://github.com/vitali87/code-graph-rag.git /tmp/code-graph-rag && \
    cd /tmp/code-graph-rag && \
    uv sync --extra treesitter-full && \
    uv pip install --system . && \
    rm -rf /tmp/code-graph-rag

# Create Code-Graph-RAG config directory
RUN mkdir -p /home/agent/.code-graph-rag && \
    chown agent:agent /home/agent/.code-graph-rag

# Set working directory
WORKDIR /home/agent/workspace

# Don't use USER directive - run as root for iptables traffic enforcement
# s6-overlay will drop privileges for user services via S6_RUNASUSER

# Environment variables
ENV PYTHON_VERSION=3.11 \
    PYTHONUNBUFFERED=1 \
    HOME=/home/agent \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk \
    JAVA_OPTS="-Xmx2g -Xms512m" \
    PATH=/root/.cargo/bin:/home/agent/.local/bin:/usr/lib/jvm/java-21-openjdk/bin:$PATH

# Configure s6-overlay to run user services as agent
ENV S6_RUNASUSER=agent

# Health check (run as agent user)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD su - agent -c "python3 -c 'import sys; sys.exit(0)'" || exit 1

# Use s6-overlay as init system
ENTRYPOINT ["/init"]
CMD []
