#!/bin/bash
# ============================================================================
# SLAPENIR Allow-Build Trap
# ============================================================================
# Intercepts ALLOW_BUILD=1 commands via DEBUG trap so that pathname-executed
# scripts (./gradlew, ./mvnw) get network access even though they bypass
# alias/function lookup and the wrapper symlinks only shadow system binaries.
#
# How it works:
#   1. DEBUG trap fires before every command
#   2. Checks BASH_COMMAND for "ALLOW_BUILD=1" prefix or env var being set
#   3. Calls netctl enable/disable around the command
#
# Loaded by:
#   - .bashrc (interactive shells via setup-bashrc.sh)
#   - BASH_ENV (non-interactive bash -c shells, e.g. from opencode)
# ============================================================================

_slapenir_net_auto=0

_slapenir_preexec() {
    local cmd="${BASH_COMMAND:-}"

    if [ "${ALLOW_BUILD:-}" = "1" ]; then
        if [ "$_slapenir_net_auto" = "0" ]; then
            if command -v netctl >/dev/null 2>&1 && ! netctl status >/dev/null 2>&1; then
                netctl enable 2>/dev/null || true
                _slapenir_net_auto=1
            fi
        fi
        if [ -z "${HTTP_PROXY:-}" ]; then
            export HTTP_PROXY="http://${BUILD_PROXY_HOST:-proxy}:${BUILD_PROXY_PORT:-3000}"
            export HTTPS_PROXY="http://${BUILD_PROXY_HOST:-proxy}:${BUILD_PROXY_PORT:-3000}"
            export NO_PROXY="localhost,127.0.0.1,proxy,postgres,memgraph,host.docker.internal"
        fi
        return 0
    fi

    if [[ "$cmd" == ALLOW_BUILD=1\ * ]]; then
        if [ "$_slapenir_net_auto" = "0" ]; then
            if command -v netctl >/dev/null 2>&1 && ! netctl status >/dev/null 2>&1; then
                netctl enable 2>/dev/null || true
                _slapenir_net_auto=1
            fi
        fi
        if [ -z "${HTTP_PROXY:-}" ]; then
            export HTTP_PROXY="http://${BUILD_PROXY_HOST:-proxy}:${BUILD_PROXY_PORT:-3000}"
            export HTTPS_PROXY="http://${BUILD_PROXY_HOST:-proxy}:${BUILD_PROXY_PORT:-3000}"
            export NO_PROXY="localhost,127.0.0.1,proxy,postgres,memgraph,host.docker.internal"
        fi
    fi
}

_slapenir_precmd() {
    if [ "$_slapenir_net_auto" = "1" ]; then
        netctl disable 2>/dev/null || true
        unset HTTP_PROXY HTTPS_PROXY NO_PROXY 2>/dev/null || true
        _slapenir_net_auto=0
    fi
}

trap '_slapenir_preexec' DEBUG

if [[ $- == *i* ]]; then
    PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}_slapenir_precmd"
else
    trap '_slapenir_precmd' EXIT
fi
