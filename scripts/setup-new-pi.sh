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
        --help)
            echo "LacyLights Complete Setup Script"
            echo ""
            echo "Usage: $0 <pi-host> [options]"
            echo ""
            echo "Arguments:"
            echo "  <pi-host>              SSH connection string (e.g., pi@lacylights.local)"
            echo ""
            echo "Options:"
            echo "  --backend-version TAG   Git tag/branch for backend (default: main)"
            echo "  --frontend-version TAG  Git tag/branch for frontend (default: main)"
            echo "  --mcp-version TAG       Git tag/branch for MCP server (default: main)"
            echo "  --help                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 pi@lacylights.local"
            echo "  $0 pi@lacylights.local --backend-version v1.1.0 --frontend-version v0.2.0"
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

print_header "LacyLights Complete Setup"
print_info "Target: $PI_HOST"
print_info "Backend version: $BACKEND_VERSION"
print_info "Frontend version: $FRONTEND_VERSION"
print_info "MCP version: $MCP_VERSION"

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

# Download release archives from GitHub
print_header "Step 6: Downloading Releases from GitHub"
print_info "Downloading LacyLights release archives from GitHub..."

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
    if [[ "\$version" =~ ^v[0-9] ]]; then
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

    # Remove destination if it exists
    rm -rf "\$dest"

    # Move to destination
    mv "\$extracted_dir" "\$dest"

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

# Build projects
print_header "Step 7: Building Projects"
print_info "Building backend, frontend, and MCP..."

ssh "$PI_HOST" << 'ENDSSH'
set -e

echo "[INFO] Building backend..."
cd /opt/lacylights/backend
npm install --production
npm run build

echo "[INFO] Running database migrations..."
npx prisma migrate deploy

echo "[INFO] Building frontend..."
cd /opt/lacylights/frontend-src
npm install --production
npm run build

if [ -d /opt/lacylights/mcp ]; then
    echo "[INFO] Building MCP server..."
    cd /opt/lacylights/mcp
    npm install --production
    npm run build
fi

ENDSSH

print_success "All projects built"

# Install service
print_header "Step 8: Installing Service"
print_info "Installing systemd service..."

ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 05-service-install.sh"

print_success "Service installed"

# Fix permissions
print_info "Fixing file permissions..."
ssh "$PI_HOST" "sudo chown -R lacylights:lacylights /opt/lacylights"
print_success "Permissions fixed"

# Start service
print_header "Step 9: Starting Service"
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
print_header "Step 10: Health Check"
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
