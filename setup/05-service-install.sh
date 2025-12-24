#!/bin/bash

# LacyLights Go Backend Service Installation
# Installs and configures systemd service for Go backend

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

print_header "LacyLights Service Installation"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Install backend systemd service file
print_info "Installing Go backend systemd service file..."

if [ -f "$REPO_DIR/systemd/lacylights.service" ]; then
    sudo cp "$REPO_DIR/systemd/lacylights.service" /etc/systemd/system/lacylights.service
    sudo chmod 644 /etc/systemd/system/lacylights.service
    print_success "Go backend service file installed"
else
    print_error "Service file not found at $REPO_DIR/systemd/lacylights.service"
    exit 1
fi

# Install frontend systemd service file
print_info "Installing frontend systemd service file..."

if [ -f "$REPO_DIR/systemd/lacylights-frontend.service" ]; then
    sudo cp "$REPO_DIR/systemd/lacylights-frontend.service" /etc/systemd/system/lacylights-frontend.service
    sudo chmod 644 /etc/systemd/system/lacylights-frontend.service
    print_success "Frontend service file installed"
else
    print_error "Frontend service file not found at $REPO_DIR/systemd/lacylights-frontend.service"
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

# Enable services
print_info "Enabling LacyLights services..."
sudo systemctl enable lacylights
sudo systemctl enable lacylights-frontend
print_success "Services enabled"

print_header "Service Installation Complete"
print_success "LacyLights backend and frontend services installed and enabled"
print_info ""
print_info "Useful commands:"
print_info "  sudo systemctl start lacylights lacylights-frontend  - Start services"
print_info "  sudo systemctl status lacylights lacylights-frontend - Check status"
print_info "  sudo systemctl stop lacylights lacylights-frontend   - Stop services"
print_info "  sudo journalctl -u lacylights -f                     - View backend logs"
print_info "  sudo journalctl -u lacylights-frontend -f            - View frontend logs"
