#!/bin/bash

# Self-Update Wrapper for LacyLights
# This script is called by the backend to update itself.
# It runs the update in the background with a delay to allow the HTTP response to complete.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update-repos.sh"

# Validate arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <repository> [version]"
    exit 1
fi

REPOSITORY="$1"
VERSION="${2:-}"

# Build the update command
if [ -n "$VERSION" ]; then
    UPDATE_CMD="$UPDATE_SCRIPT update $REPOSITORY $VERSION"
else
    UPDATE_CMD="$UPDATE_SCRIPT update $REPOSITORY"
fi

# Use systemd-run to spawn the update process outside the current service's security context
# This bypasses the NoNewPrivileges restriction and runs with full system privileges
# The update will run after a 3-second delay to allow the HTTP response to complete
systemd-run --unit=lacylights-self-update \
    --description="LacyLights Self-Update to ${VERSION:-latest}" \
    --on-active=3s \
    --timer-property=AccuracySec=100ms \
    bash -c "$UPDATE_CMD >> /opt/lacylights/logs/update.log 2>&1"

# Exit immediately so the backend can return the HTTP response
echo "Update scheduled for $REPOSITORY${VERSION:+ to $VERSION}"
exit 0
