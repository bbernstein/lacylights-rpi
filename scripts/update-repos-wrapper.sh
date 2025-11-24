#!/bin/bash

# LacyLights Update Wrapper
# This script handles read-only filesystem remounting for safe updates on Raspberry Pi

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    print_warning "Not running on Raspberry Pi, skipping filesystem remount checks"
    SKIP_REMOUNT=true
else
    SKIP_REMOUNT=false
fi

# Function to check if root filesystem is mounted read-only
is_root_readonly() {
    if [ "$SKIP_REMOUNT" = true ]; then
        return 1  # Not read-only
    fi

    local mount_opts=$(mount | grep 'on / ' | cut -d '(' -f 2 | cut -d ')' -f 1)
    if echo "$mount_opts" | grep -q "^ro,\|,ro,\|,ro$"; then
        return 0  # Read-only
    else
        return 1  # Read-write
    fi
}

# Store original read-only state
WAS_READONLY=false
if is_root_readonly; then
    WAS_READONLY=true
    print_status "Root filesystem is currently mounted read-only"
fi

# Ensure we're in a valid directory
if ! pwd >/dev/null 2>&1; then
    print_warning "Current directory is invalid, changing to /tmp"
    cd /tmp
fi

# Function to remount filesystem as read-write
remount_rw() {
    if [ "$SKIP_REMOUNT" = true ]; then
        return 0
    fi

    if is_root_readonly; then
        print_status "Remounting root filesystem as read-write..."
        # Try to remount with sudo, but don't fail if sudo doesn't work
        # (e.g., when running from systemd service with NoNewPrivileges)
        if sudo mount -o remount,rw / 2>/dev/null; then
            print_success "Root filesystem remounted as read-write"
            return 0
        else
            print_warning "Could not remount filesystem (may not have sudo access)"
            print_warning "Continuing anyway - operations may still work if paths are already writable"
            return 0
        fi
    else
        print_status "Root filesystem already writable"
        return 0
    fi
}

# Function to remount filesystem as read-only
remount_ro() {
    if [ "$SKIP_REMOUNT" = true ]; then
        return 0
    fi

    if [ "$WAS_READONLY" = true ]; then
        print_status "Remounting root filesystem as read-only..."
        # Sync first to ensure all writes are flushed
        sync
        sleep 1
        # Try to remount, but don't fail if sudo doesn't work
        if sudo mount -o remount,ro / 2>/dev/null; then
            print_success "Root filesystem remounted as read-only"
            return 0
        else
            print_warning "Could not remount filesystem as read-only (may not have sudo access)"
            print_warning "This is not critical, but you may want to reboot soon"
            return 0
        fi
    fi
    return 0
}

# Trap to ensure we remount as read-only on exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_error "Update failed with exit code $exit_code"
    fi
    remount_ro
    exit $exit_code
}

trap cleanup EXIT INT TERM

# Main execution
print_status "Starting LacyLights update process..."

# Remount as read-write (non-fatal if it fails - may already be writable)
remount_rw

# Ensure log directory exists
if [ ! -d "/opt/lacylights/logs" ]; then
    print_status "Creating log directory..."
    # Try with sudo first, fall back to direct creation
    if ! sudo mkdir -p /opt/lacylights/logs 2>/dev/null; then
        # If sudo fails, try without it (may work if we already have write access)
        if mkdir -p /opt/lacylights/logs 2>/dev/null; then
            print_success "Log directory created"
        else
            print_warning "Could not create log directory (may not have write access)"
        fi
    else
        sudo chown lacylights:lacylights /opt/lacylights/logs 2>/dev/null || true
        print_success "Log directory created"
    fi
fi

# Run the actual update script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update-repos.sh"

if [ ! -f "$UPDATE_SCRIPT" ]; then
    # Try alternate location
    UPDATE_SCRIPT="/opt/lacylights/scripts/update-repos.sh"
fi

if [ ! -f "$UPDATE_SCRIPT" ]; then
    print_error "Update script not found at $UPDATE_SCRIPT"
    exit 1
fi

print_status "Running update script: $UPDATE_SCRIPT $@"
"$UPDATE_SCRIPT" "$@"

# Success message
print_success "Update completed successfully"
print_status "Filesystem will be remounted as read-only if it was originally read-only"

exit 0
