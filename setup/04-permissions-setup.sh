#!/bin/bash

# LacyLights Permissions Setup
# Creates system user and sets up sudoers for WiFi management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_header "LacyLights Permissions Setup"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Create lacylights system user
print_info "Creating lacylights system user..."

if id "lacylights" &>/dev/null; then
    print_success "User lacylights already exists"
else
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin lacylights
    print_success "User lacylights created"
fi

# Create lacylights group
if getent group lacylights &>/dev/null; then
    print_success "Group lacylights already exists"
else
    sudo groupadd lacylights
    print_success "Group lacylights created"
fi

# Add lacylights user to lacylights group
sudo usermod -a -G lacylights lacylights

# Create application directories
print_info "Creating application directories..."

sudo mkdir -p /opt/lacylights/{backend,frontend-src,mcp,scripts,repos,backups,logs}
sudo chown -R lacylights:lacylights /opt/lacylights
sudo chmod -R 755 /opt/lacylights

# Copy update scripts to /opt/lacylights/scripts/
if [ -f "$REPO_DIR/scripts/update-repos.sh" ]; then
    print_info "Installing version management scripts..."
    sudo cp "$REPO_DIR/scripts/update-repos.sh" /opt/lacylights/scripts/
    sudo chmod +x /opt/lacylights/scripts/update-repos.sh
    sudo chown lacylights:lacylights /opt/lacylights/scripts/update-repos.sh

    # Install wrapper script for read-only filesystem support
    if [ -f "$REPO_DIR/scripts/update-repos-wrapper.sh" ]; then
        sudo cp "$REPO_DIR/scripts/update-repos-wrapper.sh" /opt/lacylights/scripts/
        sudo chmod +x /opt/lacylights/scripts/update-repos-wrapper.sh
        sudo chown lacylights:lacylights /opt/lacylights/scripts/update-repos-wrapper.sh
        print_success "Version management scripts installed (including read-only filesystem wrapper)"
    else
        print_success "Version management script installed"
        print_error "Warning: update-repos-wrapper.sh not found (read-only filesystem support unavailable)"
    fi
else
    print_error "Warning: update-repos.sh not found at $REPO_DIR/scripts/update-repos.sh"
fi

print_success "Application directories created"

# Install sudoers file for WiFi management
print_info "Installing sudoers file for WiFi management..."

if [ -f "$REPO_DIR/config/sudoers.d/lacylights" ]; then
    sudo cp "$REPO_DIR/config/sudoers.d/lacylights" /etc/sudoers.d/lacylights
    sudo chmod 0440 /etc/sudoers.d/lacylights
    sudo chown root:root /etc/sudoers.d/lacylights

    # Validate sudoers file
    if sudo visudo -c -f /etc/sudoers.d/lacylights; then
        print_success "Sudoers file installed and validated"
    else
        print_error "Sudoers file validation failed"
        sudo rm /etc/sudoers.d/lacylights
        exit 1
    fi
else
    print_error "Sudoers file not found at $REPO_DIR/config/sudoers.d/lacylights"
    exit 1
fi

# Set up npm cache directory with correct permissions
# This prevents "Your cache folder contains root-owned files" errors
print_info "Setting up npm cache directory..."

# Create home directory for lacylights user if needed (for npm cache)
if [ ! -d "/home/lacylights" ]; then
    sudo mkdir -p /home/lacylights
    sudo chown lacylights:lacylights /home/lacylights
    sudo chmod 755 /home/lacylights
fi

# Create npm cache directory with correct ownership
sudo mkdir -p /home/lacylights/.npm
sudo chown -R lacylights:lacylights /home/lacylights/.npm
sudo chmod -R 755 /home/lacylights/.npm

# Create other npm-related directories that might be needed
for dir in /home/lacylights/.node-gyp /home/lacylights/.cache; do
    if [ ! -d "$dir" ]; then
        sudo mkdir -p "$dir"
    fi
    sudo chown -R lacylights:lacylights "$dir"
    sudo chmod -R 755 "$dir"
done

print_success "npm cache directory configured"

print_header "Permissions Setup Complete"
print_success "User, group, and permissions configured"
print_info ""
print_info "Created:"
print_info "  - User: lacylights (system user)"
print_info "  - Group: lacylights"
print_info "  - Directory: /opt/lacylights/"
print_info "  - Scripts: /opt/lacylights/scripts/ (version management)"
print_info "  - Repos: /opt/lacylights/repos/ (symlinks to backend/frontend/mcp)"
print_info "  - Backups: /opt/lacylights/backups/ (for update rollbacks)"
print_info "  - Logs: /opt/lacylights/logs/ (update logs)"
print_info "  - npm cache: /home/lacylights/.npm/"
print_info "  - Sudoers: /etc/sudoers.d/lacylights (WiFi management)"
