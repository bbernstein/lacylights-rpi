#!/bin/bash

# LacyLights Offline Deployment - One Command Setup
# Prepares offline bundle and installs on Pi in a single operation
# Perfect for production deployments on isolated networks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Parse command line arguments
PI_HOST=""
PI_USER="${PI_USER:-pi}"  # Default to 'pi', but allow override via environment variable
BACKEND_VERSION="main"
FRONTEND_VERSION="main"
MCP_VERSION="main"
KEEP_BUNDLE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --backend-version)
            BACKEND_VERSION="$2"
            shift 2
            ;;
        --frontend-version)
            FRONTEND_VERSION="$2"
            shift 2
            ;;
        --mcp-version)
            MCP_VERSION="$2"
            shift 2
            ;;
        --keep-bundle)
            KEEP_BUNDLE=true
            shift
            ;;
        --help)
            echo "LacyLights Offline Deployment Script"
            echo ""
            echo "One-command deployment for Pi without internet access."
            echo "This script prepares an offline bundle and installs it on the Pi."
            echo ""
            echo "Usage: $0 <pi-host> [options]"
            echo ""
            echo "Arguments:"
            echo "  <pi-host>                 Hostname or SSH connection string"
            echo "                            (e.g., ntclights.local or pi@ntclights.local)"
            echo ""
            echo "Options:"
            echo "  --backend-version TAG     Git tag/branch for backend (default: main)"
            echo "  --frontend-version TAG    Git tag/branch for frontend (default: main)"
            echo "  --mcp-version TAG         Git tag/branch for MCP server (default: main)"
            echo "  --keep-bundle             Keep the offline bundle after installation"
            echo "  --help                    Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  PI_USER                   Username for SSH (default: pi)"
            echo "                            Example: PI_USER=admin $0 ntclights.local"
            echo ""
            echo "What this script does:"
            echo "  1. Prepares offline bundle with specified versions (Mac downloads from internet)"
            echo "  2. Installs on Pi using offline bundle (Pi needs no internet)"
            echo ""
            echo "Network requirements:"
            echo "  - Mac: Internet access for downloads"
            echo "  - Mac: SSH access to Pi (can be on different network)"
            echo "  - Pi: No internet required, internal network only"
            echo ""
            echo "Examples:"
            echo "  $0 pi@ntclights.local"
            echo "  $0 ntclights.local                    # Uses default user 'pi'"
            echo "  PI_USER=admin $0 ntclights.local      # Uses user 'admin'"
            echo "  $0 lacylights.local --backend-version v1.1.0 --frontend-version v0.2.0"
            echo "  $0 10.0.8.100 --keep-bundle"
            echo ""
            echo "See docs/OFFLINE_INSTALLATION.md for detailed documentation."
            exit 0
            ;;
        *)
            if [ -z "$PI_HOST" ]; then
                PI_HOST="$1"
            else
                print_error "Unknown option: $1"
                print_error "Use --help for usage information"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if PI_HOST is provided
if [ -z "$PI_HOST" ]; then
    print_error "Usage: $0 <pi-host> [options]"
    print_error "Example: $0 ntclights.local or $0 pi@ntclights.local"
    print_error "Use --help for more information"
    exit 1
fi

# Ensure PI_HOST includes username, default to 'pi' if not provided
if [[ "$PI_HOST" != *@* ]]; then
    print_info "No username specified, defaulting to user '$PI_USER'"
    PI_HOST="$PI_USER@$PI_HOST"
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

print_header "LacyLights Offline Deployment"
print_info "Target Pi: $PI_HOST"
print_info "Backend version: $BACKEND_VERSION"
print_info "Frontend version: $FRONTEND_VERSION"
print_info "MCP version: $MCP_VERSION"
print_info ""
print_info "This script will:"
print_info "  1. Download all files from internet (on this Mac)"
print_info "  2. Create offline bundle"
print_info "  3. Install on Pi without internet access"

# Step 1: Check prerequisites
print_header "Step 1: Checking Prerequisites"

if [ ! -f "$SCRIPT_DIR/prepare-offline.sh" ]; then
    print_error "prepare-offline.sh not found"
    print_error "Expected location: $SCRIPT_DIR/prepare-offline.sh"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/setup-new-pi.sh" ]; then
    print_error "setup-new-pi.sh not found"
    print_error "Expected location: $SCRIPT_DIR/setup-new-pi.sh"
    exit 1
fi

# Check for internet connectivity
print_info "Checking internet connectivity..."
if ! curl -s -m 5 https://github.com > /dev/null 2>&1; then
    print_error "Cannot reach github.com"
    print_error "This script requires internet access to download files"
    print_error "Please ensure you are connected to the internet"
    exit 1
fi
print_success "Internet connectivity OK"

# Check Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js is required but not installed"
    print_error "Please install Node.js from https://nodejs.org/"
    exit 1
fi
NODE_VERSION=$(node --version)
print_success "Node.js found: $NODE_VERSION"

# Check npm
if ! command -v npm &> /dev/null; then
    print_error "npm is required but not installed"
    exit 1
fi
NPM_VERSION=$(npm --version)
print_success "npm found: v$NPM_VERSION"

print_success "All prerequisites met"

# Step 2: Prepare offline bundle
print_header "Step 2: Preparing Offline Bundle"
print_info "Downloading releases and dependencies from internet..."
print_info "This may take several minutes..."
print_info ""

# Create temporary output directory
TEMP_OUTPUT="$REPO_DIR/.offline-bundle-temp"

# Run prepare-offline.sh
cd "$SCRIPT_DIR"
if ./prepare-offline.sh \
    --backend-version "$BACKEND_VERSION" \
    --frontend-version "$FRONTEND_VERSION" \
    --mcp-version "$MCP_VERSION" \
    --output "$TEMP_OUTPUT"; then
    print_success "Offline bundle prepared"
else
    print_error "Failed to prepare offline bundle"
    rm -rf "$TEMP_OUTPUT"
    exit 1
fi

# Find the created bundle in temp directory
BUNDLE_DIR="${TMPDIR:-/tmp}/lacylights-bundles"
BUNDLE_PATH=$(ls -t "$BUNDLE_DIR"/lacylights-offline-*.tar.gz 2>/dev/null | head -1)

if [ -z "$BUNDLE_PATH" ] || [ ! -f "$BUNDLE_PATH" ]; then
    print_error "Bundle file not found after preparation"
    print_error "Expected: $BUNDLE_DIR/lacylights-offline-*.tar.gz"
    rm -rf "$TEMP_OUTPUT"
    exit 1
fi

BUNDLE_SIZE=$(du -h "$BUNDLE_PATH" | cut -f1)
print_success "Bundle created: $BUNDLE_PATH ($BUNDLE_SIZE)"

# Step 3: Install on Pi
print_header "Step 3: Installing on Raspberry Pi"
print_info "Installing on $PI_HOST using offline bundle..."
print_info "Pi will not need internet access"
print_info ""

# Run setup-new-pi.sh with offline bundle
if ./setup-new-pi.sh "$PI_HOST" --offline-bundle "$BUNDLE_PATH"; then
    print_success "Installation completed successfully"
else
    print_error "Installation failed"
    print_error "Bundle preserved at: $BUNDLE_PATH"
    print_error "Check logs above for details"
    rm -rf "$TEMP_OUTPUT"
    exit 1
fi

# Step 4: Cleanup
print_header "Step 4: Cleanup"

# Remove temporary output directory
if [ -d "$TEMP_OUTPUT" ]; then
    rm -rf "$TEMP_OUTPUT"
    print_success "Temporary files cleaned"
fi

# Handle bundle cleanup
if [ "$KEEP_BUNDLE" = true ]; then
    print_info "Bundle preserved: $BUNDLE_PATH"
    print_info "You can use this bundle for additional Pi installations:"
    print_info "  ./scripts/setup-new-pi.sh pi@another-pi.local --offline-bundle $BUNDLE_PATH"
else
    rm -f "$BUNDLE_PATH"
    print_success "Bundle removed (use --keep-bundle to preserve)"
fi

# Final success message
print_header "Deployment Complete! 🎉"

print_success "LacyLights has been successfully deployed to $PI_HOST"
print_info ""
print_info "The Raspberry Pi is now running LacyLights!"
print_info ""
print_info "Access your installation:"
PI_HOSTNAME=$(echo "$PI_HOST" | cut -d'@' -f2)
print_info "  🌐 http://$PI_HOSTNAME"
print_info ""
print_info "Useful commands:"
print_info "  ssh $PI_HOST 'sudo systemctl status lacylights'    - Check status"
print_info "  ssh $PI_HOST 'sudo journalctl -u lacylights -f'    - View logs"
print_info "  ssh $PI_HOST 'sudo systemctl restart lacylights'   - Restart service"
print_info ""
print_info "Network configuration:"
print_info "  - Pi does not require internet access"
print_info "  - Configure WiFi through web interface if needed"
print_info "  - WiFi will be used for internet, Ethernet for DMX"
print_info ""
print_success "🎭 Happy lighting! 🎭"
