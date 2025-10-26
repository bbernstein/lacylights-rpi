#!/bin/bash

# LacyLights System Setup
# Installs all required system packages and dependencies

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

print_header "LacyLights System Setup"

# Update package lists
print_info "Updating package lists..."
sudo apt-get update

print_success "Package lists updated"

# Install Node.js
print_info "Installing Node.js 20..."

# Check if Node.js 20 is already installed
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -ge 20 ]; then
        print_success "Node.js $NODE_VERSION already installed"
    else
        print_info "Upgrading Node.js from version $NODE_VERSION to 20..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
else
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

print_success "Node.js installed: $(node -v)"
print_success "npm installed: $(npm -v)"

# Install PostgreSQL
print_info "Installing PostgreSQL..."

if command -v psql &> /dev/null; then
    print_success "PostgreSQL already installed: $(psql --version)"
else
    sudo apt-get install -y postgresql postgresql-contrib
    print_success "PostgreSQL installed"
fi

# Install NetworkManager
print_info "Installing NetworkManager..."

if command -v nmcli &> /dev/null; then
    print_success "NetworkManager already installed: $(nmcli --version)"
else
    sudo apt-get install -y network-manager
    print_success "NetworkManager installed"
fi

# Install build tools
print_info "Installing build tools..."
sudo apt-get install -y build-essential git curl

print_success "Build tools installed"

# Install Nginx (optional)
print_info "Installing Nginx (optional reverse proxy)..."

if command -v nginx &> /dev/null; then
    print_success "Nginx already installed"
else
    read -p "Install Nginx reverse proxy? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt-get install -y nginx
        print_success "Nginx installed"
    else
        print_info "Skipping Nginx installation"
    fi
fi

print_header "System Setup Complete"
print_success "All system dependencies installed successfully"
