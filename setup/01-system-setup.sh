#!/bin/bash

# LacyLights System Setup
# Installs all required system packages and dependencies
# Supports both online and offline modes

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

print_header "LacyLights System Setup"

# Parse command line arguments
FORCE_ONLINE=false
if [ "$1" = "--force-online" ]; then
    FORCE_ONLINE=true
    print_info "Forced online mode (WiFi just configured)"
fi

# Check internet connectivity
print_info "Checking internet connectivity..."
OFFLINE_MODE=false

if [ "$FORCE_ONLINE" = true ]; then
    # WiFi was just configured, trust that internet is available
    print_success "Internet connectivity available - ONLINE MODE (forced)"
    OFFLINE_MODE=false
elif ! ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    OFFLINE_MODE=true
    print_warning "No internet connectivity detected - OFFLINE MODE"
    print_info "Will verify existing packages instead of installing new ones"
else
    print_success "Internet connectivity available - ONLINE MODE"
fi

# Update package lists (only in online mode)
if [ "$OFFLINE_MODE" = false ]; then
    print_info "Updating package lists..."
    if sudo apt-get update; then
        print_success "Package lists updated"
    else
        print_warning "Failed to update package lists"
        print_info "Switching to offline mode..."
        OFFLINE_MODE=true
    fi
else
    print_info "Skipping package list update (offline mode)"
fi

# Install Node.js
print_info "Checking Node.js..."

# Check if Node.js is already installed
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ -n "$NODE_VERSION" ] && [[ "$NODE_VERSION" =~ ^[0-9]+$ ]] && [ "$NODE_VERSION" -ge 18 ]; then
        print_success "Node.js $NODE_VERSION already installed ($(node -v))"

        # Check if npm is available
        if command -v npm &> /dev/null; then
            print_success "npm installed: $(npm -v)"
        else
            print_warning "npm not found - checking if it exists..."
            if [ -f /usr/bin/npm ] || [ -f /usr/local/bin/npm ]; then
                print_warning "npm exists but not in PATH"
            else
                print_error "npm is missing but Node.js is installed"
                if [ "$OFFLINE_MODE" = true ]; then
                    print_error "OFFLINE MODE: Cannot install npm without internet"
                    exit 1
                else
                    print_info "Installing npm..."
                    sudo apt-get install -y npm
                fi
            fi
        fi
    else
        if [ "$OFFLINE_MODE" = true ]; then
            print_error "Node.js version $NODE_VERSION is too old (need 18+)"
            print_error "OFFLINE MODE: Cannot upgrade Node.js without internet"
            print_error "Please install Node.js 18+ manually or run setup with internet access"
            exit 1
        else
            print_info "Upgrading Node.js from version $NODE_VERSION to 20..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
            print_success "Node.js upgraded: $(node -v)"
        fi
    fi
else
    if [ "$OFFLINE_MODE" = true ]; then
        print_error "Node.js is not installed"
        print_error "OFFLINE MODE: Cannot install Node.js without internet"
        print_error ""
        print_error "To prepare the Pi for offline setup, first run this with internet access:"
        print_error "  1. Connect Pi to internet temporarily"
        print_error "  2. Run: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -"
        print_error "  3. Run: sudo apt-get install -y nodejs"
        print_error "  4. Disconnect from internet and retry"
        exit 1
    else
        print_info "Installing Node.js 20..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
        print_success "Node.js installed: $(node -v)"

        # Verify npm is installed
        if command -v npm &> /dev/null; then
            print_success "npm installed: $(npm -v)"
        else
            print_warning "npm not found in PATH, checking system..."
            if [ -f /usr/bin/npm ] || [ -f /usr/local/bin/npm ]; then
                print_success "npm is installed but not in PATH"
            else
                print_error "npm was not installed with Node.js"
                print_error "This is unexpected - installing npm separately..."
                sudo apt-get install -y npm
                if command -v npm &> /dev/null; then
                    print_success "npm installed: $(npm -v)"
                else
                    print_error "Failed to install npm"
                    exit 1
                fi
            fi
        fi
    fi
fi

# Verify npm is available after Node.js installation
print_info "Verifying npm availability..."
if ! command -v npm &> /dev/null; then
    if [ -f /usr/bin/npm ]; then
        print_info "npm found at /usr/bin/npm but not in PATH"
        print_info "Adding to PATH..."
        export PATH="/usr/bin:$PATH"
    elif [ -f /usr/local/bin/npm ]; then
        print_info "npm found at /usr/local/bin/npm but not in PATH"
        print_info "Adding to PATH..."
        export PATH="/usr/local/bin:$PATH"
    fi
fi

if command -v npm &> /dev/null; then
    print_success "npm is ready: $(npm -v)"
else
    print_error "npm is still not available after installation"
    print_error "Please check your Node.js installation"
    exit 1
fi

# SQLite is included with Node.js/Prisma, no separate installation needed
print_info "SQLite will be used for database (included with Prisma)"
print_success "No additional database software needed"

# Install NetworkManager
print_info "Checking NetworkManager..."

if command -v nmcli &> /dev/null; then
    print_success "NetworkManager already installed: $(nmcli --version | head -1)"
else
    if [ "$OFFLINE_MODE" = true ]; then
        print_error "NetworkManager is not installed"
        print_error "OFFLINE MODE: Cannot install NetworkManager without internet"
        print_error ""
        print_error "To prepare the Pi for offline setup, first run with internet:"
        print_error "  sudo apt-get update && sudo apt-get install -y network-manager"
        exit 1
    else
        print_info "Installing NetworkManager..."
        sudo apt-get install -y network-manager
        print_success "NetworkManager installed"
    fi
fi

# Install build tools
print_info "Checking build tools..."

# Check for essential build tools
MISSING_TOOLS=()
command -v gcc &> /dev/null || MISSING_TOOLS+=("gcc")
command -v make &> /dev/null || MISSING_TOOLS+=("make")
command -v git &> /dev/null || MISSING_TOOLS+=("git")
command -v curl &> /dev/null || MISSING_TOOLS+=("curl")

if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    print_success "All build tools already installed"
else
    if [ "$OFFLINE_MODE" = true ]; then
        print_error "Missing build tools: ${MISSING_TOOLS[*]}"
        print_error "OFFLINE MODE: Cannot install build tools without internet"
        print_error ""
        print_error "To prepare the Pi for offline setup, first run with internet:"
        print_error "  sudo apt-get update && sudo apt-get install -y build-essential git curl"
        exit 1
    else
        print_info "Installing build tools (${MISSING_TOOLS[*]})..."
        sudo apt-get install -y build-essential git curl
        print_success "Build tools installed"
    fi
fi

# Install Nginx (optional, skip in offline mode)
if [ "$OFFLINE_MODE" = false ]; then
    print_info "Checking Nginx (optional reverse proxy)..."

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
else
    print_info "Checking Nginx..."
    if command -v nginx &> /dev/null; then
        print_success "Nginx already installed"
    else
        print_warning "Nginx not installed (optional, skipping in offline mode)"
    fi
fi

print_header "System Setup Complete"
if [ "$OFFLINE_MODE" = true ]; then
    print_success "All required dependencies verified (offline mode)"
    print_info "System is ready for offline LacyLights installation"
else
    print_success "All system dependencies installed successfully"
fi
