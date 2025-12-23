#!/bin/bash

# Secure Update Runner for LacyLights
# This script is designed to be called by systemd-run from the backend.
# It validates all inputs to prevent command injection attacks.
#
# Usage: run-update.sh <repository> [version]
# Arguments must be validated before being used in any command.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update-repos.sh"
LOG_FILE="/opt/lacylights/logs/update.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Validate number of arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <repository> [version]" >&2
    exit 1
fi

REPOSITORY="$1"
VERSION="${2:-}"

# Whitelist validation for repository name
# Only allow known repository names to prevent injection
case "$REPOSITORY" in
    lacylights-go|lacylights-mcp|lacylights-fe)
        # Valid repository
        ;;
    *)
        echo "ERROR: Invalid repository name: $REPOSITORY" >&2
        echo "Must be one of: lacylights-go, lacylights-mcp, lacylights-fe" >&2
        exit 1
        ;;
esac

# Validate version format if provided
# Only allow semantic versioning format to prevent injection
if [ -n "$VERSION" ]; then
    # Match v1.2.3 or 1.2.3 with optional prerelease (-alpha.1) and build metadata (+build)
    if ! echo "$VERSION" | grep -qE '^v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$'; then
        echo "ERROR: Invalid version format: $VERSION" >&2
        echo "Must be semver format (e.g., v1.2.3 or 1.2.3-beta.1)" >&2
        exit 1
    fi
fi

# Log the update attempt
{
    echo ""
    echo "=========================================="
    echo "Update started at $(date -Iseconds)"
    echo "Repository: $REPOSITORY"
    echo "Version: ${VERSION:-latest}"
    echo "=========================================="
} >> "$LOG_FILE"

# Run the update with validated arguments
# Arguments are passed directly, not through bash -c
if [ -n "$VERSION" ]; then
    exec "$UPDATE_SCRIPT" update "$REPOSITORY" "$VERSION" >> "$LOG_FILE" 2>&1
else
    exec "$UPDATE_SCRIPT" update "$REPOSITORY" >> "$LOG_FILE" 2>&1
fi
