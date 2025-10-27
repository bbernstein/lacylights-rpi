#!/bin/bash

# LacyLights Complete Setup Script
# One-command setup for a fresh Raspberry Pi

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
BACKEND_VERSION="main"
FRONTEND_VERSION="main"
MCP_VERSION="main"
OFFLINE_BUNDLE=""

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
        --offline-bundle)
            OFFLINE_BUNDLE="$2"
            shift 2
            ;;
        --help)
            echo "LacyLights Complete Setup Script"
            echo ""
            echo "Usage: $0 <pi-host> [options]"
            echo ""
            echo "Arguments:"
            echo "  <pi-host>                 SSH connection string (e.g., pi@lacylights.local)"
            echo ""
            echo "Options:"
            echo "  --backend-version TAG     Git tag/branch for backend (default: main)"
            echo "  --frontend-version TAG    Git tag/branch for frontend (default: main)"
            echo "  --mcp-version TAG         Git tag/branch for MCP server (default: main)"
            echo "  --offline-bundle PATH     Use offline bundle (no internet on Pi required)"
            echo "  --help                    Show this help message"
            echo ""
            echo "Offline Installation:"
            echo "  For Pis without internet access, first prepare an offline bundle:"
            echo "    ./scripts/prepare-offline.sh"
            echo "  Then use the bundle for installation:"
            echo "    $0 pi@lacylights.local --offline-bundle lacylights-offline-*.tar.gz"
            echo ""
            echo "Examples:"
            echo "  $0 pi@lacylights.local"
            echo "  $0 pi@lacylights.local --backend-version v1.1.0 --frontend-version v0.2.0"
            echo "  $0 pi@lacylights.local --offline-bundle lacylights-offline-20251027-160000.tar.gz"
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
    print_error "Example: $0 pi@lacylights.local"
    print_error "Use --help for more options"
    exit 1
fi

# Validate offline bundle if provided
if [ -n "$OFFLINE_BUNDLE" ]; then
    if [ ! -f "$OFFLINE_BUNDLE" ]; then
        print_error "Offline bundle not found: $OFFLINE_BUNDLE"
        print_error "Please run ./scripts/prepare-offline.sh first"
        exit 1
    fi
    print_success "Offline bundle found: $OFFLINE_BUNDLE"
fi

print_header "LacyLights Complete Setup"
print_info "Target: $PI_HOST"
if [ -n "$OFFLINE_BUNDLE" ]; then
    print_info "Mode: OFFLINE (no internet required on Pi)"
    print_info "Bundle: $(basename $OFFLINE_BUNDLE)"
else
    print_info "Mode: ONLINE (Pi will download from GitHub/npm)"
    print_info "Backend version: $BACKEND_VERSION"
    print_info "Frontend version: $FRONTEND_VERSION"
    print_info "MCP version: $MCP_VERSION"
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Check if we can reach the Pi
print_info "Checking if Raspberry Pi is reachable..."
PI_HOSTNAME=$(echo "$PI_HOST" | cut -d'@' -f2)

if ! ping -c 1 -W 2 "$PI_HOSTNAME" &> /dev/null; then
    print_error "Cannot reach $PI_HOSTNAME"
    print_error "Please ensure:"
    print_error "  1. Raspberry Pi is powered on"
    print_error "  2. Connected to the same network"
    print_error "  3. Hostname is resolving correctly"
    exit 1
fi

print_success "Raspberry Pi is reachable"

# Check SSH access
print_info "Checking SSH access..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$PI_HOST" "exit" 2>/dev/null; then
    print_warning "SSH key authentication not set up"
    print_info "You will be prompted for password during setup"
else
    print_success "SSH access verified"
fi

# Copy lacylights-rpi repository to Pi
print_header "Step 1: Copying Setup Scripts to Pi"
print_info "Copying lacylights-rpi repository to Pi..."

ssh "$PI_HOST" "mkdir -p ~/lacylights-setup"
rsync -avz --exclude '.git' \
    "$REPO_DIR/" "$PI_HOST:~/lacylights-setup/"

print_success "Setup scripts copied"

# Run system setup
print_header "Step 2: System Setup"
print_info "Installing system dependencies..."

ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 01-system-setup.sh"

print_success "System setup complete"

# Run network setup
print_header "Step 3: Network Setup"
print_info "Configuring network and hostname..."

ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 02-network-setup.sh"

print_success "Network setup complete"

# Run database setup
print_header "Step 4: Database Setup"
print_info "Creating SQLite database directory..."

ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && bash 03-database-setup.sh"

print_success "Database setup complete"

# Run permissions setup
print_header "Step 5: Permissions Setup"
print_info "Creating system user and setting permissions..."

ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 04-permissions-setup.sh"

print_success "Permissions setup complete"

# Check network connectivity (skip in offline mode)
if [ -z "$OFFLINE_BUNDLE" ]; then
    print_header "Step 6: Network Connectivity Check"
    print_info "Checking internet connectivity..."

    ssh "$PI_HOST" << 'NETCHECK'
set -e

echo "[INFO] Checking network interfaces..."
ip addr show | grep -E "^[0-9]+:|inet " || true

echo ""
echo "[INFO] Checking DNS resolution..."
# Use ping to test DNS (more reliable than 'host' which may not be installed)
if ! ping -c 1 -W 2 github.com > /dev/null 2>&1; then
    echo "[ERROR] Cannot resolve or reach github.com"
    echo "[INFO] Trying to ping 8.8.8.8 (Google DNS)..."
    if ! ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
        echo "[ERROR] No internet connectivity"
        echo "[ERROR] Please ensure the Pi has internet access (WiFi or Ethernet)"
        exit 1
    else
        echo "[ERROR] Internet works but DNS is not resolving"
        echo "[INFO] Check /etc/resolv.conf for DNS servers"
        exit 1
    fi
else
    echo "[SUCCESS] DNS resolution working"
fi

echo "[INFO] Testing HTTPS connection to github.com..."
if ! curl -s -m 10 https://github.com > /dev/null 2>&1; then
    echo "[ERROR] Cannot connect to github.com via HTTPS"
    echo "[INFO] Please check firewall and network settings"
    exit 1
fi

echo "[SUCCESS] Network connectivity OK"
NETCHECK

    print_success "Network check passed"
else
    print_header "Step 6: Network Connectivity Check"
    print_info "SKIPPED - Using offline bundle (no internet required on Pi)"
fi

# Step 7: Download/Extract releases (online or offline)
if [ -z "$OFFLINE_BUNDLE" ]; then
    # ONLINE MODE: Download from GitHub
    print_header "Step 7: Downloading Releases from GitHub"
    print_info "Downloading LacyLights release archives from GitHub..."

    # Ensure directories exist and pi user can write during setup
    print_info "Preparing directories for downloads..."
    ssh "$PI_HOST" << 'DIRSETUP'
set -e

# Ensure /opt/lacylights exists
sudo mkdir -p /opt/lacylights

# Give pi user temporary ownership for downloads
sudo chown -R pi:pi /opt/lacylights

# Ensure parent directory is accessible
sudo chmod 755 /opt/lacylights

echo "[SUCCESS] Directories prepared"
DIRSETUP

    print_success "Directories ready for downloads"

    ssh "$PI_HOST" << EOF
set -e

# Helper function to download and extract GitHub archive
download_release() {
    local repo=\$1
    local version=\$2
    local dest=\$3
    local repo_name=\$(basename \$repo)

    echo "[INFO] Downloading \$repo_name version \$version..."

    # Determine if version is a tag or branch
    if [[ "\$version" =~ ^v[0-9]+ ]]; then
        # It's a tag
        url="https://github.com/\$repo/archive/refs/tags/\${version}.tar.gz"
    else
        # It's a branch
        url="https://github.com/\$repo/archive/refs/heads/\${version}.tar.gz"
    fi

    # Create temp directory
    mkdir -p /tmp/lacylights-downloads
    cd /tmp/lacylights-downloads

    # Download archive
    curl -L -o "\${repo_name}.tar.gz" "\$url"

    # Extract archive
    tar -xzf "\${repo_name}.tar.gz"

    # Find extracted directory (handle various naming formats)
    extracted_dir=\$(find . -maxdepth 1 -type d -name "\${repo_name}-*" | head -1)

    if [ -z "\$extracted_dir" ]; then
        echo "[ERROR] Failed to find extracted directory for \$repo_name"
        return 1
    fi

    # Ensure parent directory exists
    dest_parent=\$(dirname "\$dest")
    mkdir -p "\$dest_parent"

    # Remove destination if it exists
    rm -rf "\$dest"

    # Move to destination
    if ! mv "\$extracted_dir" "\$dest"; then
        echo "[ERROR] Failed to move \$extracted_dir to \$dest"
        ls -la "\$(dirname "\$dest")" || true
        ls -la "\$extracted_dir" || true
        return 1
    fi

    # Clean up
    rm -f "\${repo_name}.tar.gz"

    echo "[SUCCESS] \$repo_name ready at \$dest"
}

# Download backend
download_release "bbernstein/lacylights-node" "$BACKEND_VERSION" "/opt/lacylights/backend"

# Download frontend
download_release "bbernstein/lacylights-fe" "$FRONTEND_VERSION" "/opt/lacylights/frontend-src"

# Download MCP server
download_release "bbernstein/lacylights-mcp" "$MCP_VERSION" "/opt/lacylights/mcp"

# Clean up temp directory
rm -rf /tmp/lacylights-downloads

EOF

    print_success "All release archives downloaded and extracted"

else
    # OFFLINE MODE: Extract from bundle
    print_header "Step 7: Extracting from Offline Bundle"
    print_info "Using offline bundle (no internet access required)..."

    # Transfer bundle to Pi
    print_info "Transferring offline bundle to Pi..."
    ssh "$PI_HOST" "mkdir -p ~/lacylights-offline"
    scp "$OFFLINE_BUNDLE" "$PI_HOST:~/lacylights-offline/bundle.tar.gz"
    print_success "Bundle transferred"

    # Extract and install from bundle
    print_info "Extracting and installing from bundle..."
    ssh "$PI_HOST" << 'OFFLINE_INSTALL'
set -e

cd ~/lacylights-offline

# Extract bundle
echo "[INFO] Extracting offline bundle..."
tar -xzf bundle.tar.gz

# Ensure /opt/lacylights exists
sudo mkdir -p /opt/lacylights
sudo chown -R pi:pi /opt/lacylights
sudo chmod 755 /opt/lacylights

# Extract release archives
echo "[INFO] Extracting backend..."
mkdir -p /opt/lacylights/backend
tar -xzf releases/backend.tar.gz -C /opt/lacylights/backend --strip-components=1

echo "[INFO] Extracting frontend..."
mkdir -p /opt/lacylights/frontend-src
tar -xzf releases/frontend.tar.gz -C /opt/lacylights/frontend-src --strip-components=1

echo "[INFO] Extracting MCP server..."
mkdir -p /opt/lacylights/mcp
tar -xzf releases/mcp.tar.gz -C /opt/lacylights/mcp --strip-components=1

# Extract pre-downloaded node_modules
echo "[INFO] Extracting pre-downloaded dependencies..."
if [ -f releases/backend-node_modules.tar.gz ]; then
    tar -xzf releases/backend-node_modules.tar.gz -C /opt/lacylights/backend/
    echo "[INFO] Backend dependencies extracted"
fi

if [ -f releases/frontend-node_modules.tar.gz ]; then
    tar -xzf releases/frontend-node_modules.tar.gz -C /opt/lacylights/frontend-src/
    echo "[INFO] Frontend dependencies extracted"
fi

if [ -f releases/mcp-node_modules.tar.gz ]; then
    tar -xzf releases/mcp-node_modules.tar.gz -C /opt/lacylights/mcp/
    echo "[INFO] MCP dependencies extracted"
fi

echo "[SUCCESS] All files extracted from offline bundle"
OFFLINE_INSTALL

    print_success "Offline bundle extracted successfully"
fi

# Create .env file for backend
print_header "Step 8: Creating Configuration Files"
print_info "Creating backend .env file..."

ssh "$PI_HOST" << 'ENVSETUP'
set -e

# Create .env file for backend
cd /opt/lacylights/backend

# Check if .env.example exists
if [ -f .env.example ]; then
    echo "[INFO] Copying .env.example to .env"
    cp .env.example .env
else
    echo "[INFO] Creating .env from scratch"
    touch .env
fi

# Set DATABASE_URL to absolute path for production
echo "[INFO] Setting DATABASE_URL for production"
if grep -q "^DATABASE_URL=" .env; then
    # Replace existing DATABASE_URL
    sed -i 's|^DATABASE_URL=.*|DATABASE_URL="file:/opt/lacylights/backend/prisma/dev.db"|' .env
else
    # Add DATABASE_URL
    echo 'DATABASE_URL="file:/opt/lacylights/backend/prisma/dev.db"' >> .env
fi

# Ensure production settings
echo "[INFO] Configuring production settings"
if grep -q "^NODE_ENV=" .env; then
    sed -i 's|^NODE_ENV=.*|NODE_ENV=production|' .env
else
    echo 'NODE_ENV=production' >> .env
fi

if ! grep -q "^PORT=" .env; then
    echo 'PORT=4000' >> .env
fi

# Set Art-Net broadcast to avoid interactive prompt
if ! grep -q "^ARTNET_BROADCAST=" .env; then
    echo '# ARTNET_BROADCAST=10.0.8.255  # Uncomment and adjust for your network' >> .env
fi

echo "[SUCCESS] Backend .env file created"
ENVSETUP

print_success "Configuration files created"

# Build projects (while still owned by pi user)
print_header "Step 9: Building Projects"
if [ -z "$OFFLINE_BUNDLE" ]; then
    print_info "Building backend, frontend, and MCP (ONLINE MODE)..."
    print_info "Note: Building as pi user before transferring ownership to lacylights"

    ssh "$PI_HOST" << 'ENDSSH'
set -e

echo "[INFO] Building backend..."
cd /opt/lacylights/backend
npm install
npm run build

echo "[INFO] Running database migrations..."
npx prisma migrate deploy

echo "[INFO] Building frontend..."
cd /opt/lacylights/frontend-src
npm install
npm run build

if [ -d /opt/lacylights/mcp ]; then
    echo "[INFO] Building MCP server..."
    cd /opt/lacylights/mcp
    npm install
    npm run build
fi

ENDSSH

else
    print_info "Building with pre-downloaded dependencies (OFFLINE MODE)..."
    print_info "Note: Rebuilding native modules for ARM architecture"

    ssh "$PI_HOST" << 'OFFLINE_BUILD'
set -e

echo "[INFO] Rebuilding backend native modules..."
cd /opt/lacylights/backend
npm rebuild
npm run build

echo "[INFO] Running database migrations..."
npx prisma generate
npx prisma migrate deploy

echo "[INFO] Rebuilding frontend native modules..."
cd /opt/lacylights/frontend-src
npm rebuild
npm run build

if [ -d /opt/lacylights/mcp ]; then
    echo "[INFO] Rebuilding MCP server native modules..."
    cd /opt/lacylights/mcp
    npm rebuild
    npm run build
fi

OFFLINE_BUILD

fi

print_success "All projects built"

# Install service
print_header "Step 10: Installing Service"
print_info "Installing systemd service..."

ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 05-service-install.sh"

print_success "Service installed"

# Fix permissions
print_info "Fixing file permissions..."
ssh "$PI_HOST" "sudo chown -R lacylights:lacylights /opt/lacylights"
print_success "Permissions fixed"

# Install and configure nginx
print_header "Step 11: Installing Nginx"
print_info "Installing and configuring nginx..."

ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 06-nginx-setup.sh"

print_success "Nginx installed and configured"

# Start service
print_header "Step 12: Starting Service"
print_info "Starting LacyLights service..."

ssh "$PI_HOST" "sudo systemctl start lacylights"

print_success "Service started"

# Wait for service to be ready
print_info "Waiting for service to be ready..."
sleep 5

# Check service status
if ssh "$PI_HOST" "sudo systemctl is-active --quiet lacylights"; then
    print_success "LacyLights service is running"
else
    print_error "LacyLights service failed to start"
    print_error "Check logs with: ssh $PI_HOST 'sudo journalctl -u lacylights -n 50'"
    exit 1
fi

# Health check
print_header "Step 13: Health Check"
print_info "Checking service health..."

sleep 2

HEALTH_CHECK=$(ssh "$PI_HOST" "curl -s -f http://localhost:4000/graphql -H 'Content-Type: application/json' -d '{\"query\": \"{ __typename }\"}'" 2>/dev/null || echo "")

if echo "$HEALTH_CHECK" | grep -q "Query"; then
    print_success "✅ GraphQL endpoint is responding"
else
    print_warning "⚠️  GraphQL endpoint may not be responding correctly"
fi

# Final success message
print_header "Setup Complete! 🎉"

print_success "LacyLights has been successfully installed on your Raspberry Pi!"
print_info ""
print_info "Access your LacyLights instance:"
print_info "  🌐 http://lacylights.local"
print_info ""
print_info "Useful commands:"
print_info "  ssh $PI_HOST 'sudo systemctl status lacylights'    - Check status"
print_info "  ssh $PI_HOST 'sudo journalctl -u lacylights -f'    - View logs"
print_info "  ssh $PI_HOST 'sudo systemctl restart lacylights'   - Restart service"
print_info ""
print_info "To deploy code changes in the future:"
print_info "  cd $REPO_DIR"
print_info "  ./scripts/deploy.sh"
print_info ""
print_success "🎭 Happy lighting! 🎭"
