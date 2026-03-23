#!/bin/bash
# Setup bashrc to automatically source .env file

cat > /home/agent/.bashrc << 'EOF'
# SLAPENIR Agent .bashrc
# Auto-generated - automatically sources environment variables

# Check for ALLOW_BUILD mode first (before sourcing .env)
if [ "${ALLOW_BUILD:-}" = "1" ] || [ "${ALLOW_BUILD:-}" = "true" ]; then
    echo "⚠️  ALLOW_BUILD mode enabled - bypassing proxy"
    unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy
    export ALLOW_BUILD=1
    # Comment out proxy settings in gradle.properties
    if [ -f /home/agent/.gradle/gradle.properties ]; then
        sed -i 's|^\(systemProp\.http\.proxyHost=\)|#\1|' /home/agent/.gradle/gradle.properties
        sed -i 's|^\(systemProp\.http\.proxyPort=\)|#\1|' /home/agent/.gradle/gradle.properties
        sed -i 's|^\(systemProp\.https\.proxyHost=\)|#\1|' /home/agent/.gradle/gradle.properties
        sed -i 's|^\(systemProp\.https\.proxyPort=\)|#\1|' /home/agent/.gradle/gradle.properties
    fi
fi

# Source .env if it exists
if [ -f /home/agent/.env ]; then
    set -a
    source /home/agent/.env
    set +a
fi

# Re-check ALLOW_BUILD after sourcing .env (in case it was set there)
if [ "${ALLOW_BUILD:-}" = "1" ] || [ "${ALLOW_BUILD:-}" = "true" ]; then
    unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy
    # Comment out proxy settings in gradle.properties
    if [ -f /home/agent/.gradle/gradle.properties ]; then
        sed -i 's|^\(systemProp\.http\.proxyHost=\)|#\1|' /home/agent/.gradle/gradle.properties
        sed -i 's|^\(systemProp\.http\.proxyPort=\)|#\1|' /home/agent/.gradle/gradle.properties
        sed -i 's|^\(systemProp\.https\.proxyHost=\)|#\1|' /home/agent/.gradle/gradle.properties
        sed -i 's|^\(systemProp\.https\.proxyPort=\)|#\1|' /home/agent/.gradle/gradle.properties
    fi
fi

# Bash completion
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Colorful prompt
PS1='\[\033[01;32m\]agent@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Useful aliases
alias ll='ls -lah'
alias python='python3'
alias pip='pip3'

# Environment info
export EDITOR=vi
export LANG=en_US.UTF-8

# Git safe directories - use writable config location
export GIT_CONFIG_GLOBAL=~/.config/git/config

EOF

chmod 644 /home/agent/.bashrc
chown agent:agent /home/agent/.bashrc 2>/dev/null || true

echo "✅ .bashrc configured to auto-source .env"
