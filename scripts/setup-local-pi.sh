#!/bin/bash

# LacyLights Local Pi Setup Script
# Complete one-command setup when running directly on the Raspberry Pi
#
# Usage:
#   sudo bash setup-local-pi.sh [options]
#
# Options:
#   --backend-version TAG     Git tag/branch for backend (default: latest release)
#   --frontend-version TAG    Git tag/branch for frontend (default: latest release)
#   --mcp-version TAG         Git tag/branch for MCP server (default: latest release)
#   --skip-wifi               Skip WiFi configuration prompts
#   --wifi-ssid SSID          WiFi network name
#   --wifi-password PASSWORD  WiFi password
#   --help                    Show this help message

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

# Determine script and setup directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$(dirname "$SCRIPT_DIR")"

# Parse command line arguments
BACKEND_VERSION=""
FRONTEND_VERSION=""
MCP_VERSION=""
SKIP_WIFI=false
WIFI_SSID="${WIFI_SSID:-}"
WIFI_PASSWORD="${WIFI_PASSWORD:-}"

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
        --wifi-ssid)
            WIFI_SSID="$2"
            shift 2
            ;;
        --wifi-password)
            WIFI_PASSWORD="$2"
            shift 2
            ;;
        --skip-wifi)
            SKIP_WIFI=true
            shift
            ;;
        --help)
            echo "LacyLights Local Pi Setup Script"
            echo ""
            echo "Usage: sudo bash $0 [options]"
            echo ""
            echo "This script performs complete setup when running directly on the Raspberry Pi."
            echo ""
            echo "Options:"
            echo "  --backend-version TAG     Git tag/branch for backend (default: latest release)"
            echo "  --frontend-version TAG    Git tag/branch for frontend (default: latest release)"
            echo "  --mcp-version TAG         Git tag/branch for MCP server (default: latest release)"
            echo "  --wifi-ssid SSID          WiFi network name"
            echo "  --wifi-password PASSWORD  WiFi password"
            echo "  --skip-wifi               Skip WiFi configuration"
            echo "  --help                    Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  WIFI_SSID                 WiFi network name (alternative to --wifi-ssid)"
            echo "  WIFI_PASSWORD             WiFi password (alternative to --wifi-password)"
            echo ""
            echo "Examples:"
            echo "  sudo bash $0"
            echo "  sudo bash $0 --wifi-ssid \"MyNetwork\" --wifi-password \"mypassword\""
            echo "  sudo bash $0 --backend-version v1.1.0 --frontend-version v0.2.0"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_error "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

print_header "LacyLights Local Pi Setup"
print_info "This script will set up LacyLights on this Raspberry Pi"
print_info "Setup directory: $SETUP_DIR"

# Step 1: System Setup
print_header "Step 1/7: System Setup"
bash "$SETUP_DIR/setup/01-system-setup.sh"

# Step 2: Network Setup
print_header "Step 2/7: Network Setup"
bash "$SETUP_DIR/setup/02-network-setup.sh"

# Step 3: Database Setup
print_header "Step 3/7: Database Setup"
bash "$SETUP_DIR/setup/03-database-setup.sh"

# Step 4: Permissions Setup
print_header "Step 4/7: Permissions Setup"
bash "$SETUP_DIR/setup/04-permissions-setup.sh"

# Step 5: Service Installation
print_header "Step 5/7: Service Installation"
bash "$SETUP_DIR/setup/05-service-install.sh"

# Step 6: Deploy LacyLights Applications
print_header "Step 6/7: Deploying LacyLights Applications"

# Create deployment directories
mkdir -p /opt/lacylights/{backend,frontend-src,mcp}

# Function to get latest release tag from GitHub
get_latest_release() {
    local repo=$1
    curl -fsSL "https://api.github.com/repos/bbernstein/${repo}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "main"
}

# Determine versions to deploy
if [ -z "$BACKEND_VERSION" ]; then
    print_info "Fetching latest backend version..."
    BACKEND_VERSION=$(get_latest_release "lacylights-node")
    print_info "Using backend version: $BACKEND_VERSION"
fi

if [ -z "$FRONTEND_VERSION" ]; then
    print_info "Fetching latest frontend version..."
    FRONTEND_VERSION=$(get_latest_release "lacylights-fe")
    print_info "Using frontend version: $FRONTEND_VERSION"
fi

if [ -z "$MCP_VERSION" ]; then
    print_info "Fetching latest MCP version..."
    MCP_VERSION=$(get_latest_release "lacylights-mcp")
    print_info "Using MCP version: $MCP_VERSION"
fi

# Deploy Backend
print_info "Deploying backend ($BACKEND_VERSION)..."
cd /opt/lacylights/backend
if [ "$BACKEND_VERSION" = "main" ]; then
    curl -fsSL "https://github.com/bbernstein/lacylights-node/archive/refs/heads/main.tar.gz" | tar xz --strip-components=1
else
    curl -fsSL "https://github.com/bbernstein/lacylights-node/archive/refs/tags/${BACKEND_VERSION}.tar.gz" | tar xz --strip-components=1
fi

# Set ownership before installing dependencies
chown -R pi:pi /opt/lacylights/backend

# Install backend dependencies (including dev dependencies for build)
print_info "Installing backend dependencies..."
sudo -u pi npm ci

# Build backend
print_info "Building backend..."
sudo -u pi bash -c 'cd /opt/lacylights/backend && export PATH="./node_modules/.bin:$PATH" && npm run build'

# Remove dev dependencies after build to save space
print_info "Removing dev dependencies..."
sudo -u pi npm prune --omit=dev

# Create temp directory for fixture downloads
print_info "Creating temp directory..."
sudo -u pi mkdir -p /opt/lacylights/backend/temp

# Copy environment file if it doesn't exist
if [ ! -f /opt/lacylights/backend/.env ]; then
    if [ -f "$SETUP_DIR/config/.env.example" ]; then
        cp "$SETUP_DIR/config/.env.example" /opt/lacylights/backend/.env
        print_success "Environment file created from example"
    fi
fi

print_success "Backend deployed successfully"

# Deploy Frontend
print_info "Deploying frontend ($FRONTEND_VERSION)..."
cd /opt/lacylights/frontend-src
if [ "$FRONTEND_VERSION" = "main" ]; then
    curl -fsSL "https://github.com/bbernstein/lacylights-fe/archive/refs/heads/main.tar.gz" | tar xz --strip-components=1
else
    curl -fsSL "https://github.com/bbernstein/lacylights-fe/archive/refs/tags/${FRONTEND_VERSION}.tar.gz" | tar xz --strip-components=1
fi

# Set ownership before installing dependencies
chown -R pi:pi /opt/lacylights/frontend-src

# Install frontend dependencies (including dev dependencies for build)
print_info "Installing frontend dependencies..."
sudo -u pi npm ci

# Build frontend
print_info "Building frontend..."
# Build Next.js in server mode
sudo -u pi bash -c 'NEXT_PUBLIC_GRAPHQL_ENDPOINT=http://lacylights.local/graphql npm run build'

# Note: We keep dependencies (not pruning) because Next.js server needs them to run

print_success "Frontend deployed successfully"

# Deploy MCP Server
print_info "Deploying MCP server ($MCP_VERSION)..."
cd /opt/lacylights/mcp
if [ "$MCP_VERSION" = "main" ]; then
    curl -fsSL "https://github.com/bbernstein/lacylights-mcp/archive/refs/heads/main.tar.gz" | tar xz --strip-components=1
else
    curl -fsSL "https://github.com/bbernstein/lacylights-mcp/archive/refs/tags/${MCP_VERSION}.tar.gz" | tar xz --strip-components=1
fi

# Set ownership before installing dependencies
chown -R pi:pi /opt/lacylights/mcp

# Install MCP dependencies (including dev dependencies for build)
print_info "Installing MCP dependencies..."
sudo -u pi npm ci

# Build MCP
print_info "Building MCP server..."
sudo -u pi bash -c 'cd /opt/lacylights/mcp && export PATH="./node_modules/.bin:$PATH" && npm run build'

# Remove dev dependencies after build to save space
print_info "Removing dev dependencies..."
sudo -u pi npm prune --omit=dev

print_success "MCP server deployed successfully"

# Set correct ownership
# Backend runs as lacylights user, frontend runs as pi user
chown -R lacylights:lacylights /opt/lacylights/backend
chown -R pi:pi /opt/lacylights/frontend-src
chown -R pi:pi /opt/lacylights/mcp

# Run database migrations (after ownership change)
print_info "Running database migrations..."
sudo -u lacylights bash -c 'cd /opt/lacylights/backend && export PATH="./node_modules/.bin:$PATH" && npx prisma migrate deploy'
print_success "Database migrations completed"

# Setup version management symlinks
print_header "Setting Up Version Management"
print_info "Creating symlinks for version management..."

# Create symlinks in /opt/lacylights/repos/
if [ ! -L /opt/lacylights/repos/lacylights-node ]; then
    print_info "Creating symlink: lacylights-node -> backend"
    ln -sf /opt/lacylights/backend /opt/lacylights/repos/lacylights-node
fi

if [ ! -L /opt/lacylights/repos/lacylights-fe ]; then
    print_info "Creating symlink: lacylights-fe -> frontend-src"
    ln -sf /opt/lacylights/frontend-src /opt/lacylights/repos/lacylights-fe
fi

if [ ! -L /opt/lacylights/repos/lacylights-mcp ]; then
    print_info "Creating symlink: lacylights-mcp -> mcp"
    ln -sf /opt/lacylights/mcp /opt/lacylights/repos/lacylights-mcp
fi

print_success "Version management symlinks created"

# Create version tracking files
print_info "Creating version tracking files..."

# Extract version from package.json with error handling and fallback
if [ -f /opt/lacylights/backend/package.json ]; then
    BACKEND_PKG_VERSION=$(grep '"version"' /opt/lacylights/backend/package.json | head -1 | sed 's/.*"version": "\(.*\)".*/v\1/')
    if [ -z "$BACKEND_PKG_VERSION" ] || [ "$BACKEND_PKG_VERSION" = "v" ]; then
        BACKEND_PKG_VERSION="unknown"
    fi
else
    BACKEND_PKG_VERSION="unknown"
fi

if [ -f /opt/lacylights/frontend-src/package.json ]; then
    FRONTEND_PKG_VERSION=$(grep '"version"' /opt/lacylights/frontend-src/package.json | head -1 | sed 's/.*"version": "\(.*\)".*/v\1/')
    if [ -z "$FRONTEND_PKG_VERSION" ] || [ "$FRONTEND_PKG_VERSION" = "v" ]; then
        FRONTEND_PKG_VERSION="unknown"
    fi
else
    FRONTEND_PKG_VERSION="unknown"
fi

if [ -f /opt/lacylights/mcp/package.json ]; then
    MCP_PKG_VERSION=$(grep '"version"' /opt/lacylights/mcp/package.json | head -1 | sed 's/.*"version": "\(.*\)".*/v\1/')
    if [ -z "$MCP_PKG_VERSION" ] || [ "$MCP_PKG_VERSION" = "v" ]; then
        MCP_PKG_VERSION="unknown"
    fi
else
    MCP_PKG_VERSION="unknown"
fi

# Create .lacylights-version files with proper user context (consistent with deploy.sh)
# All version files are owned by lacylights user to match deploy.sh behavior
sudo -u lacylights bash -c "echo '$BACKEND_PKG_VERSION' > /opt/lacylights/backend/.lacylights-version"
sudo -u lacylights bash -c "echo '$FRONTEND_PKG_VERSION' > /opt/lacylights/frontend-src/.lacylights-version"
sudo -u lacylights bash -c "echo '$MCP_PKG_VERSION' > /opt/lacylights/mcp/.lacylights-version"

print_info "Installed versions: Backend=$BACKEND_PKG_VERSION, Frontend=$FRONTEND_PKG_VERSION, MCP=$MCP_PKG_VERSION"
print_success "Version tracking files created"

# Install and start frontend service
print_header "Installing Frontend Service"
print_info "Installing frontend systemd service..."
cp "$SETUP_DIR/systemd/lacylights-frontend.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable lacylights-frontend
systemctl start lacylights-frontend
print_success "Frontend service installed and started"

# Check frontend service status
sleep 2
if systemctl is-active --quiet lacylights-frontend; then
    print_success "Frontend service is running on port 3000"
else
    print_warning "Frontend service may not have started. Check logs with: sudo journalctl -u lacylights-frontend -n 50"
fi

# Start the backend service
print_header "Starting LacyLights Backend Service"
systemctl start lacylights
print_success "Backend service started"

# Check backend service status
sleep 2
if systemctl is-active --quiet lacylights; then
    print_success "Backend service is running"
else
    print_warning "Backend service may not have started correctly. Check logs with: sudo journalctl -u lacylights -n 50"
fi

# Step 7: Nginx Setup
print_header "Step 7/7: Nginx Setup"
bash "$SETUP_DIR/setup/06-nginx-setup.sh"

print_header "Setup Complete!"
print_success "LacyLights has been installed and started"
print_info ""
print_info "Access LacyLights at: http://lacylights.local"
print_info ""
print_info "Useful commands:"
print_info "  sudo systemctl status lacylights    - Check service status"
print_info "  sudo systemctl restart lacylights   - Restart service"
print_info "  sudo journalctl -u lacylights -f    - View live logs"
print_info ""
print_info "Configuration file: /opt/lacylights/backend/.env"
print_info ""

# Optional WiFi configuration
if [ "$SKIP_WIFI" = false ]; then
    print_header "WiFi Configuration (Optional)"
    print_info "The Pi is currently using ethernet for the local DMX network."
    print_info "You can optionally configure WiFi for internet access."
    print_info ""

    if [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PASSWORD" ]; then
        print_info "Configuring WiFi with provided credentials..."
        nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD" || print_warning "WiFi configuration failed. You can configure it manually later."
    else
        read -p "Would you like to configure WiFi now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter WiFi SSID: " wifi_ssid
            read -sp "Enter WiFi password: " wifi_password
            echo
            nmcli device wifi connect "$wifi_ssid" password "$wifi_password" || print_warning "WiFi configuration failed. You can try again with: sudo nmcli device wifi connect \"$wifi_ssid\" password \"yourpassword\""
        fi
    fi
fi

print_header "All Done!"
print_success "LacyLights is ready to use at http://lacylights.local"
