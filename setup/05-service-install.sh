#!/bin/bash

# LacyLights Go Backend Service Installation
# Installs and configures systemd service for Go backend
#
# Note: This script now uses the Go backend by default.
# For the legacy Node.js backend, use 05-service-install-node.sh

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

print_header "LacyLights Go Backend Service Installation"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Install systemd service file (using Go backend service)
print_info "Installing Go backend systemd service file..."

if [ -f "$REPO_DIR/systemd/lacylights-go.service" ]; then
    sudo cp "$REPO_DIR/systemd/lacylights-go.service" /etc/systemd/system/lacylights.service
    sudo chmod 644 /etc/systemd/system/lacylights.service
    print_success "Go backend service file installed"
else
    print_error "Service file not found at $REPO_DIR/systemd/lacylights-go.service"
    exit 1
fi

# Create .env file from template if it doesn't exist
print_info "Setting up environment configuration..."

if [ ! -f /opt/lacylights/backend/.env ]; then
    if [ -f "$REPO_DIR/config/.env.example" ]; then
        sudo cp "$REPO_DIR/config/.env.example" /opt/lacylights/backend/.env

        # Update with database connection string if available
        if [ -f /tmp/lacylights-setup/database.env ]; then
            print_info "Adding database connection string..."
            sudo bash -c "cat /tmp/lacylights-setup/database.env >> /opt/lacylights/backend/.env"
        fi

        sudo chown lacylights:lacylights /opt/lacylights/backend/.env
        sudo chmod 600 /opt/lacylights/backend/.env
        print_success "Environment file created"
        print_info "Please review and customize /opt/lacylights/backend/.env"
    else
        print_error "Environment template not found"
        exit 1
    fi
else
    print_success "Environment file already exists"
fi

# Reload systemd
print_info "Reloading systemd daemon..."
sudo systemctl daemon-reload
print_success "Systemd reloaded"

# Enable service
print_info "Enabling LacyLights service..."
sudo systemctl enable lacylights
print_success "Service enabled"

print_header "Service Installation Complete"
print_success "LacyLights Go backend service installed and enabled"
print_info ""
print_info "The service will NOT start automatically yet."
print_info "First, you need to:"
print_info "  1. Download Go backend binary to /opt/lacylights/backend/lacylights-server"
print_info "  2. Make it executable: chmod +x /opt/lacylights/backend/lacylights-server"
print_info "  3. Set ownership: chown lacylights:lacylights /opt/lacylights/backend/lacylights-server"
print_info "  4. Start the service with: sudo systemctl start lacylights"
print_info ""
print_info "Useful commands:"
print_info "  sudo systemctl start lacylights    - Start the service"
print_info "  sudo systemctl status lacylights   - Check service status"
print_info "  sudo systemctl stop lacylights     - Stop the service"
print_info "  sudo journalctl -u lacylights -f   - View logs"
