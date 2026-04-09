#!/bin/bash

cat > /home/agent/.bashrc << 'BASHEOF'
# SLAPENIR Agent .bashrc

if [ -f /home/agent/.env ]; then
    set -a
    source /home/agent/.env
    set +a
fi

_gradlew_real() {
    local gradlew_script
    if [ -f "./gradlew" ]; then
        gradlew_script="./gradlew"
    elif [ -f "gradlew" ]; then
        gradlew_script="gradlew"
    else
        echo "ERROR: gradlew not found in current directory" >&2
        return 1
    fi

    if [ "${ALLOW_BUILD:-}" != "1" ] && [ "${GRADLE_ALLOW_BUILD:-}" != "1" ]; then
        echo "BUILD TOOL BLOCKED: gradlew - Use: ALLOW_BUILD=1 gradlew <args>" >&2
        return 1
    fi

    if ! netctl status >/dev/null 2>&1; then
        netctl enable 2>/dev/null || true
    fi

    HTTP_PROXY="http://${BUILD_PROXY_HOST:-proxy}:${BUILD_PROXY_PORT:-3000}" \
    HTTPS_PROXY="http://${BUILD_PROXY_HOST:-proxy}:${BUILD_PROXY_PORT:-3000}" \
    NO_PROXY="localhost,127.0.0.1,proxy,postgres,memgraph,host.docker.internal" \
    GRADLE_WRAPPER_OPTS="${GRADLE_WRAPPER_OPTS:--Dhttp.proxyHost=proxy -Dhttp.proxyPort=3000 -Dhttps.proxyHost=proxy -Dhttps.proxyPort=3000 -Dhttp.nonProxyHosts=localhost|127.0.0.1|proxy|postgres|host.docker.internal}" \
    "$gradlew_script" $GRADLE_WRAPPER_OPTS "$@"
    local exit_code=$?

    netctl disable 2>/dev/null || true
    return $exit_code
}
alias gradlew='_gradlew_real'

net() {
    local already_enabled=false
    netctl status >/dev/null 2>&1 && already_enabled=true

    if ! $already_enabled; then
        netctl enable 2>/dev/null || true
    fi

    "$@"
    local exit_code=$?

    if ! $already_enabled; then
        netctl disable 2>/dev/null || true
    fi

    return $exit_code
}

if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

PS1='\[\033[01;32m\]agent@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
alias ll='ls -lah'
alias python='python3'
alias pip='pip3'
export EDITOR=vi
export LANG=en_US.UTF-8
export GIT_CONFIG_GLOBAL=~/.config/git/config

if [ -f /home/agent/scripts/lib/allow-build-trap.sh ]; then
    source /home/agent/scripts/lib/allow-build-trap.sh
fi
BASHEOF

chmod 644 /home/agent/.bashrc
chown agent:agent /home/agent/.bashrc 2>/dev/null || true

echo "✅ .bashrc configured"
