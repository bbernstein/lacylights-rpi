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

# Function to run the update in the background after a delay
run_update_async() {
    # Wait a few seconds to allow the HTTP response to be sent
    sleep 3

    # Run the actual update
    if [ -n "$VERSION" ]; then
        "$UPDATE_SCRIPT" update "$REPOSITORY" "$VERSION"
    else
        "$UPDATE_SCRIPT" update "$REPOSITORY"
    fi
}

# Start the update in the background, detached from this process
# Use nohup to prevent SIGHUP when parent exits
# Redirect output to update log
nohup bash -c "$(declare -f run_update_async); run_update_async" \
    >> /opt/lacylights/logs/update.log 2>&1 &

# Disown the background process so it survives this script's exit
disown

# Exit immediately so the backend can return the HTTP response
echo "Update scheduled for $REPOSITORY${VERSION:+ to $VERSION}"
exit 0
