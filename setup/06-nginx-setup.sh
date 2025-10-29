#!/bin/bash

# LacyLights Nginx Setup
# Installs and configures nginx as reverse proxy for frontend/backend

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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_header "LacyLights Nginx Setup"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Install nginx
print_info "Installing nginx..."

if command -v nginx &> /dev/null; then
    NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
    print_success "Nginx already installed: $NGINX_VERSION"
else
    sudo apt-get update
    sudo apt-get install -y nginx
    print_success "Nginx installed"
fi

# Stop nginx during configuration
print_info "Stopping nginx for configuration..."
sudo systemctl stop nginx

# Install LacyLights nginx configuration
print_info "Installing LacyLights nginx configuration..."

if [ -f "$REPO_DIR/config/nginx/sites-available/lacylights" ]; then
    sudo cp "$REPO_DIR/config/nginx/sites-available/lacylights" \
        /etc/nginx/sites-available/lacylights
    print_success "Nginx configuration installed"
else
    print_error "Nginx configuration not found at $REPO_DIR/config/nginx/sites-available/lacylights"
    exit 1
fi

# Disable default site
print_info "Disabling default nginx site..."
if [ -L /etc/nginx/sites-enabled/default ]; then
    sudo rm /etc/nginx/sites-enabled/default
    print_success "Default site disabled"
else
    print_info "Default site already disabled"
fi

# Enable LacyLights site
print_info "Enabling LacyLights nginx site..."
if [ ! -L /etc/nginx/sites-enabled/lacylights ]; then
    sudo ln -s /etc/nginx/sites-available/lacylights \
        /etc/nginx/sites-enabled/lacylights
    print_success "LacyLights site enabled"
else
    print_success "LacyLights site already enabled"
fi

# Create symlink for frontend files
print_info "Creating symlink for frontend files..."
if [ -d /opt/lacylights/frontend-src/out ]; then
    # Remove old symlink/directory if exists
    if [ -L /opt/lacylights/frontend ]; then
        sudo rm /opt/lacylights/frontend
    elif [ -d /opt/lacylights/frontend ]; then
        print_warning "Directory /opt/lacylights/frontend exists, removing..."
        sudo rm -rf /opt/lacylights/frontend
    fi

    # Create symlink
    sudo ln -s /opt/lacylights/frontend-src/out /opt/lacylights/frontend
    print_success "Symlink created: /opt/lacylights/frontend -> /opt/lacylights/frontend-src/out"
else
    print_warning "Frontend build not found at /opt/lacylights/frontend-src/out"
    print_info "Will create symlink after frontend is built"
fi

# Test nginx configuration
print_info "Testing nginx configuration..."
if sudo nginx -t; then
    print_success "Nginx configuration is valid"
else
    print_error "Nginx configuration test failed"
    exit 1
fi

# Enable and start nginx
print_info "Enabling and starting nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

if systemctl is-active --quiet nginx; then
    print_success "Nginx is running"
else
    print_error "Nginx failed to start"
    exit 1
fi

print_header "Nginx Setup Complete"
print_success "Nginx configured successfully"
print_info ""
print_info "Configuration:"
print_info "  - Nginx site: /etc/nginx/sites-available/lacylights"
print_info "  - Frontend root: /opt/lacylights/frontend (symlink)"
print_info "  - GraphQL proxy: http://localhost:4000/graphql"
print_info "  - WebSocket proxy: http://localhost:4000/graphql"
print_info ""
print_info "Access LacyLights at:"
print_info "  - http://lacylights.local"
print_info "  - http://localhost"
