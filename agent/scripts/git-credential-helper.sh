#!/bin/bash
# Git credential helper for SLAPENIR Agent
# Provides GitHub authentication via Personal Access Token from environment
# Usage: git config credential.helper /path/to/this/script

case "$1" in
  get)
    # Provide credentials when Git requests them
    if [ -n "$GITHUB_TOKEN" ]; then
      echo "protocol=https"
      echo "host=github.com"
      echo "username=git"
      echo "password=${GITHUB_TOKEN}"
    else
      echo "ERROR: GITHUB_TOKEN environment variable not set" >&2
      exit 1
    fi
    ;;
  store|erase)
    # No-op: we don't persist credentials
    # Credentials come from environment only
    exit 0
    ;;
  *)
    echo "Usage: $0 {get|store|erase}" >&2
    exit 1
    ;;
esac