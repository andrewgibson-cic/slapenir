# SLAPENIR Agent Environment
# Wolfi-based minimal container for AI agent execution with glibc compatibility

FROM cgr.dev/chainguard/wolfi-base:latest

# Metadata
LABEL maintainer="andrew.gibson-cic@ibm.com"
LABEL description="SLAPENIR Agent: Secure Python execution environment with process supervision"
LABEL version="0.1.0"

# Install build tools, Python, bash, iptables for traffic enforcement, and Java 21
RUN for i in 1 2 3; do \
        apk add --no-cache \
            python-3.12 \
            python-3.12-dev \
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
            rust \
            cmake \
            ripgrep \
            openssl-dev \
            netcat-openbsd \
            jq && break || (echo "apk add attempt $i failed, retrying in 10s..." && sleep 10); \
    done

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
# Wolfi uses musl libc - the postinstall script detects platform as linux-${ARCH}
# and looks for the "opencode-linux-${ARCH}" package (glibc binary).
# We install the musl binary and alias it under the expected package name
# so the postinstall's require.resolve() finds it correctly.
RUN ARCH=$(node -e "console.log(process.arch === 'arm64' ? 'arm64' : 'x64')") && \
    npm install -g --ignore-scripts "opencode-ai@1.3.13" "opencode-linux-${ARCH}-musl@1.3.13" && \
    cp -r \
      "/usr/local/lib/node_modules/opencode-linux-${ARCH}-musl" \
      "/usr/local/lib/node_modules/opencode-linux-${ARCH}" && \
    cd /usr/local/lib/node_modules/opencode-ai && \
    node postinstall.mjs && \
    test -f /usr/local/lib/node_modules/opencode-ai/bin/.opencode && \
    echo "OpenCode binary installed successfully"

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
    chown -R agent:agent /var/log/slapenir && \
    chmod 755 /var/log/slapenir

# Copy s6 service configuration
COPY s6-overlay/s6-rc.d/ /etc/s6-overlay/s6-rc.d/

# Copy cont-init.d scripts to the correct location for s6-overlay
COPY s6-overlay/cont-init.d/ /etc/cont-init.d/
RUN chmod +x /etc/cont-init.d/* 2>/dev/null || true

# Copy agent scripts
COPY scripts/ /home/agent/scripts/
RUN chmod +x /home/agent/scripts/*.sh /home/agent/scripts/*.mjs 2>/dev/null || true

# Copy package manager configs for isolated builds
COPY config/npm/ /home/agent/config/npm/
COPY config/yarn/ /home/agent/config/yarn/
COPY config/gradle/ /home/agent/config/gradle/
COPY config/pip/ /home/agent/config/pip/

# Create cache directories for package managers
RUN mkdir -p /home/agent/.npm \
             /home/agent/.gradle/caches \
             /home/agent/.gradle/wrapper \
             /home/agent/.cache/pip \
             /home/agent/.cache/opencode \
             /home/agent/.cache/codebase_rag \
             /home/agent/.yarn/cache \
             /home/agent/.yarn/global \
             /home/agent/.config/pip

# Pre-cache Gradle distribution for gradlew wrapper (air-gapped runtime support)
# During build we have direct internet access; runtime uses proxy
# Gradle uses MD5 hash of URL encoded as base36 for cache directory name
ARG GRADLE_VERSION=8.10.2
RUN GRADLE_DIST_URL="https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" && \
    GRADLE_HASH=$(python3 -c "import hashlib; h=hashlib.md5('$GRADLE_DIST_URL'.encode()).hexdigest(); n=int(h,16); chars='0123456789abcdefghijklmnopqrstuvwxyz'; r=''; exec('while n>0: n,rem=divmod(n,36); r=chars[rem]+r'); print(r)") && \
    GRADLE_DIST_DIR="/home/agent/.gradle/wrapper/dists/gradle-${GRADLE_VERSION}-bin/${GRADLE_HASH}" && \
    mkdir -p "$GRADLE_DIST_DIR" && \
    curl -fsSL "$GRADLE_DIST_URL" -o "${GRADLE_DIST_DIR}/gradle-${GRADLE_VERSION}-bin.zip" && \
    cd "$GRADLE_DIST_DIR" && \
    unzip -q "gradle-${GRADLE_VERSION}-bin.zip" && \
    touch "${GRADLE_DIST_DIR}/gradle-${GRADLE_VERSION}-bin.zip.ok" && \
    rm -rf /tmp/*

# Copy gradle.properties to ~/.gradle/ so Gradle uses proxy for dependencies
RUN cp /home/agent/config/gradle/gradle.properties /home/agent/.gradle/gradle.properties && \
    chown agent:agent /home/agent/.gradle/gradle.properties

# Fix cache directory ownership (created by root mkdir)
RUN chown -R agent:agent /home/agent/.npm \
             /home/agent/.gradle \
             /home/agent/.cache \
             /home/agent/.yarn \
             /home/agent/.config

# Install Python dependencies BEFORE wrapper shadowing (so pip isn't blocked)
# Install to Python 3.12 site-packages explicitly
RUN pip install --no-cache-dir --break-system-packages \
    --target /usr/lib/python3.12/site-packages \
    requests \
    httpx \
    aiohttp \
    pydantic \
    python-dotenv \
    prometheus-client

# Install Code-Graph-RAG from vendored source (upstream repo went private)
# Vendored from code-graph-rag 0.0.149, extracted from previous Docker build
# Tree-sitter grammars installed separately from PyPI (they're still public)
COPY vendor/ /tmp/code-graph-rag-vendor/
RUN pip install --no-cache-dir --break-system-packages --target /usr/lib/python3.13/site-packages \
    tree-sitter==0.25.2 \
    tree-sitter-c==0.24.1 \
    tree-sitter-cpp==0.23.4 \
    tree-sitter-go==0.25.0 \
    tree-sitter-java==0.23.5 \
    tree-sitter-javascript==0.25.0 \
    tree-sitter-lua==0.5.0 \
    tree-sitter-python==0.25.0 \
    tree-sitter-rust==0.24.1 \
    tree-sitter-scala==0.24.0 \
    tree-sitter-typescript==0.23.2 \
    typer>=0.12.5 \
    loguru>=0.7.3 \
    rich>=13.7.1 \
    neo4j \
    python-dotenv>=1.1.0 \
    pydantic \
    pydantic-settings>=2.0.0 \
    mcp>=1.21.1 \
    pydantic-ai>=1.70.0 \
    pymgclient>=1.4.0 \
    tiktoken>=0.12.0 \
    toml>=0.10.2 \
    watchdog>=6.0.0 \
    prompt-toolkit>=3.0.0 \
    diff-match-patch>=20241021 \
    click>=8.0.0 \
    protobuf>=5.27.0 \
    defusedxml>=0.7.1 \
    'huggingface-hub[hf-xet]>=0.36.0' && \
    cp -r /tmp/code-graph-rag-vendor/codebase_rag /usr/lib/python3.13/site-packages/codebase_rag && \
    cp -r /tmp/code-graph-rag-vendor/code_graph_rag-0.0.149.dist-info /usr/lib/python3.13/site-packages/code_graph_rag-0.0.149.dist-info && \
    rm -rf /tmp/code-graph-rag-vendor

# Patch code-graph-rag: fix missing tool descriptions for semantic_search and get_function_source
# Upstream bug: Tool() calls don't pass description parameter
RUN /home/agent/scripts/patch-codegraph-rag.sh

RUN printf '#!/bin/sh\nexec python3.13 -m codebase_rag.cli "$@"\n' > /usr/local/bin/cgr && \
    chmod +x /usr/local/bin/cgr && \
    ln -sf /usr/local/bin/cgr /usr/local/bin/code-graph-rag

# ============================================================================
# MCP Memory & Knowledge Tools
# ============================================================================

# Install official MCP memory server (SQLite-based knowledge graph)
RUN npm install -g @modelcontextprotocol/server-memory

# Install mcp-local-rag for markdown/document knowledge retrieval
# Handles PDF, DOCX, MD with semantic chunking and keyword boosting
RUN npm install -g --ignore-scripts mcp-local-rag

# Pre-download Hugging Face embedding model for air-gapped operation
# This caches the model during build so it's available offline at runtime
# Using all-MiniLM-L6-v2: reliable, no auth required, works offline
# Note: jina-embeddings-v2-base-code requires HuggingFace auth token
# Note: Download to /opt/huggingface-cache to avoid conflict with runtime volume
RUN mkdir -p /opt/huggingface-cache && \
    export HF_HOME=/opt/huggingface-cache && \
    export TRANSFORMERS_CACHE=/opt/huggingface-cache && \
    cd /usr/local/lib/node_modules/mcp-local-rag && \
    node --experimental-vm-modules -e " \
      import('@huggingface/transformers').then(async ({ pipeline }) => { \
        console.log('Pre-downloading embedding model for offline use...'); \
        console.log('Model: Xenova/all-MiniLM-L6-v2 (default, no auth required)'); \
        console.log('Cache dir: ' + process.env.TRANSFORMERS_CACHE); \
        const embedder = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2', { \
          cache_dir: process.env.TRANSFORMERS_CACHE, \
          quantized: false \
        }); \
        console.log('Testing model...'); \
        const test = await embedder('test embedding', { pooling: 'mean', normalize: true }); \
        console.log('✅ Model downloaded and cached successfully'); \
        console.log('Embedding dimensions:', test.dims); \
        console.log('Model ready for air-gapped operation'); \
      }).catch(err => { \
        console.error('❌ Failed to download model:', err); \
        process.exit(1); \
      }); \
    " && \
    chown -R agent:agent /opt/huggingface-cache

# Create MCP memory storage directories
RUN mkdir -p /home/agent/.local/share/mcp-memory \
             /home/agent/.local/share/mcp-knowledge && \
    chown -R agent:agent /home/agent/.local/share/mcp-memory \
                                /home/agent/.local/share/mcp-knowledge

# Install build tool wrappers for security
# These intercept build tool commands and block execution by default
RUN mkdir -p /home/agent/scripts/lib && \
    chmod +x /home/agent/scripts/*-wrapper 2>/dev/null || true && \
    chmod +x /home/agent/scripts/lib/*.sh 2>/dev/null || true

# Shadow system binaries with security wrappers
# Moves real binaries to .real suffix and creates symlinks to wrappers
# All builds blocked by default - requires ALLOW_BUILD=1 or <TOOL>_ALLOW_BUILD=1
RUN for tool in gradle mvn npm yarn pnpm cargo pip pip3; do \
        if command -v $tool >/dev/null 2>&1; then \
            real_path=$(which $tool); \
            if [ ! -f "${real_path}.real" ]; then \
                mv "$real_path" "${real_path}.real"; \
                if [ -f "/home/agent/scripts/${tool}-wrapper" ]; then \
                    ln -s /home/agent/scripts/${tool}-wrapper "$real_path"; \
                fi; \
            fi; \
        fi; \
    done

# Build netctl - setuid binary for agent to control network access
# Allows agent user to run network-enable.sh (iptables) without sudo
COPY scripts/netctl.c /tmp/netctl.c
RUN gcc -static -o /usr/local/bin/netctl /tmp/netctl.c && \
    chown root:root /usr/local/bin/netctl && \
    chmod 4755 /usr/local/bin/netctl && \
    rm /tmp/netctl.c

# Create gradlew symlink (catches ./gradlew)
RUN if [ -f /home/agent/scripts/gradle-wrapper ]; then \
        ln -sf /home/agent/scripts/gradle-wrapper /home/agent/scripts/gradlew; \
    fi

# Create Code-Graph-RAG config directory
RUN mkdir -p /home/agent/.code-graph-rag && \
    chown agent:agent /home/agent/.code-graph-rag

# Set working directory
WORKDIR /home/agent/workspace

# Don't use USER directive - run as root for iptables traffic enforcement
# s6-overlay will drop privileges for user services via S6_RUNASUSER

# Environment variables
ENV PYTHON_VERSION=3.12 \
    PYTHONUNBUFFERED=1 \
    HOME=/home/agent \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk \
    JAVA_OPTS="-Xmx2g -Xms512m -Dhttp.proxyHost=proxy -Dhttp.proxyPort=3000 -Dhttps.proxyHost=proxy -Dhttps.proxyPort=3000 -Dhttp.nonProxyHosts=localhost|127.0.0.1|proxy" \
    GRADLE_OPTS="-Dhttp.proxyHost=proxy -Dhttp.proxyPort=3000 -Dhttps.proxyHost=proxy -Dhttps.proxyPort=3000 -Dhttp.nonProxyHosts=localhost|127.0.0.1|proxy" \
    HF_HUB_OFFLINE=1 \
    BUILD_PROXY_HOST=proxy \
    BUILD_PROXY_PORT=3000 \
    BASH_ENV=/home/agent/scripts/lib/allow-build-trap.sh \
    NODE_OPTIONS=--require=/home/agent/scripts/lib/node-fetch-port-fix.js \
    PATH=/root/.local/bin:/home/agent/.local/bin:/usr/lib/jvm/java-21-openjdk/bin:$PATH

# Configure s6-overlay to run user services as agent
ENV S6_RUNASUSER=agent

# Health check (run as agent user)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD su - agent -c "python3 -c 'import sys; sys.exit(0)'" || exit 1

# Use s6-overlay as init system
ENTRYPOINT ["/init"]
CMD []