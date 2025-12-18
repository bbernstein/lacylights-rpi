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

# Create a temporary script that will run in the background
# This avoids issues with declare -f and function serialization
TEMP_SCRIPT="/tmp/lacylights-update-$$"
cat > "$TEMP_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
# Wait a few seconds to allow the HTTP response to be sent
sleep 3

# Run the actual update
SCRIPT_EOF

# Add the update command with proper quoting
if [ -n "$VERSION" ]; then
    echo "\"$UPDATE_SCRIPT\" update \"$REPOSITORY\" \"$VERSION\"" >> "$TEMP_SCRIPT"
else
    echo "\"$UPDATE_SCRIPT\" update \"$REPOSITORY\"" >> "$TEMP_SCRIPT"
fi

# Make it executable
chmod +x "$TEMP_SCRIPT"

# Start the update in the background, detached from this process
# Redirect output to update log and clean up temp script when done
nohup bash -c "$TEMP_SCRIPT >> /opt/lacylights/logs/update.log 2>&1; rm -f $TEMP_SCRIPT" &

# Disown the background process so it survives this script's exit
disown

# Exit immediately so the backend can return the HTTP response
echo "Update scheduled for $REPOSITORY${VERSION:+ to $VERSION}"
exit 0
