#!/bin/bash

# LacyLights Deployment Script
# General-purpose deployment for backend, frontend, and MCP server
#
# Usage:
#   ./scripts/deploy.sh                    Deploy all components
#   ./scripts/deploy.sh --backend-only     Deploy only backend
#   ./scripts/deploy.sh --frontend-only    Deploy only frontend
#   ./scripts/deploy.sh --mcp-only         Deploy only MCP server
#   ./scripts/deploy.sh --skip-rebuild     Sync files only, no rebuild
#   ./scripts/deploy.sh --skip-restart     Don't restart services

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PI_USER="${PI_USER:-pi}"  # Default to 'pi', but allow override via environment variable
PI_HOST="${PI_HOST:-lacylights.local}"
BACKEND_REMOTE="/opt/lacylights/backend"
FRONTEND_REMOTE="/opt/lacylights/frontend-src"
MCP_REMOTE="/opt/lacylights/mcp"
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPOS_DIR="$(dirname "$LOCAL_DIR")"

# Ensure PI_HOST includes username, default to PI_USER if not provided
if [[ "$PI_HOST" != *@* ]]; then
    PI_HOST="$PI_USER@$PI_HOST"
fi

# Parse command line arguments
DEPLOY_BACKEND=true
DEPLOY_FRONTEND=true
DEPLOY_MCP=true
SKIP_LOCAL_BUILD=false
REBUILD_ON_PI=false
SKIP_RESTART=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --backend-only)
            DEPLOY_FRONTEND=false
            DEPLOY_MCP=false
            shift
            ;;
        --frontend-only)
            DEPLOY_BACKEND=false
            DEPLOY_MCP=false
            shift
            ;;
        --mcp-only)
            DEPLOY_BACKEND=false
            DEPLOY_FRONTEND=false
            shift
            ;;
        --skip-local-build)
            SKIP_LOCAL_BUILD=true
            shift
            ;;
        --rebuild-on-pi)
            REBUILD_ON_PI=true
            shift
            ;;
        --skip-restart)
            SKIP_RESTART=true
            shift
            ;;
        --help)
            echo "LacyLights Deployment Script"
            echo ""
            echo "Usage:"
            echo "  $0 [options]"
            echo ""
            echo "Options:"
            echo "  --backend-only       Deploy only backend"
            echo "  --frontend-only      Deploy only frontend"
            echo "  --mcp-only           Deploy only MCP server"
            echo "  --skip-local-build   Skip building locally (use existing builds)"
            echo "  --rebuild-on-pi      Rebuild on Pi after deployment (slower, default: false)"
            echo "  --skip-restart       Don't restart services"
            echo "  --help               Show this help message"
            echo ""
            echo "Build Behavior:"
            echo "  By default, projects are built locally on your Mac before deployment."
            echo "  Use --skip-local-build to skip building (faster if already built)."
            echo "  Use --rebuild-on-pi to rebuild on the Pi after transfer (slower)."
            echo ""
            echo "Environment Variables:"
            echo "  PI_HOST              Raspberry Pi hostname (default: lacylights.local)"
            echo "                       Can include username (e.g., pi@lacylights.local)"
            echo "  PI_USER              Username for SSH (default: pi)"
            echo ""
            echo "Examples:"
            echo "  $0                                  # Build locally and deploy"
            echo "  $0 --skip-local-build               # Deploy without building"
            echo "  $0 --rebuild-on-pi                  # Build locally and rebuild on Pi"
            echo "  PI_HOST=ntclights.local $0          # Deploy to ntclights.local"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Check prerequisites
print_header "LacyLights Deployment"

print_info "Configuration:"
print_info "  Target: $PI_HOST"
print_info "  Backend: $([ "$DEPLOY_BACKEND" = true ] && echo "✓" || echo "✗")"
print_info "  Frontend: $([ "$DEPLOY_FRONTEND" = true ] && echo "✓" || echo "✗")"
print_info "  MCP: $([ "$DEPLOY_MCP" = true ] && echo "✓" || echo "✗")"
print_info "  Local Build: $([ "$SKIP_LOCAL_BUILD" = false ] && echo "✓" || echo "✗")"
print_info "  Rebuild on Pi: $([ "$REBUILD_ON_PI" = true ] && echo "✓" || echo "✗")"
print_info "  Restart: $([ "$SKIP_RESTART" = false ] && echo "✓" || echo "✗")"

# Check if repos exist
print_header "Checking Prerequisites"

if [ ! -d "$REPOS_DIR/lacylights-go" ]; then
    print_error "Backend repository not found at $REPOS_DIR/lacylights-go"
    exit 1
fi

if [ ! -d "$REPOS_DIR/lacylights-fe" ]; then
    print_error "Frontend repository not found at $REPOS_DIR/lacylights-fe"
    exit 1
fi

if [ ! -d "$REPOS_DIR/lacylights-mcp" ]; then
    print_warning "MCP repository not found at $REPOS_DIR/lacylights-mcp"
    DEPLOY_MCP=false
fi

print_success "Repository locations verified"

# Check if Pi is reachable
print_info "Checking if Raspberry Pi is reachable..."
# Extract hostname from PI_HOST (e.g., pi@ntclights.local -> ntclights.local)
PI_HOSTNAME=$(echo "$PI_HOST" | cut -d'@' -f2)
if ! ping -c 1 -W 2 "$PI_HOSTNAME" &> /dev/null; then
    print_error "Cannot reach $PI_HOSTNAME"
    print_error "Please ensure:"
    print_error "  1. Raspberry Pi is powered on"
    print_error "  2. Connected to the same network"
    print_error "  3. Hostname $PI_HOSTNAME is resolving"
    exit 1
fi
print_success "Raspberry Pi is reachable"

# Check SSH access
print_info "Checking SSH access..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$PI_HOST" "exit" 2>/dev/null; then
    print_warning "SSH key authentication not set up"
    print_info "You will be prompted for password during deployment"
else
    print_success "SSH access verified"
fi

# Check and update hostname if needed
print_header "Verifying Hostname Configuration"

# Extract desired hostname from PI_HOST (e.g., pi@ntclights.local -> ntclights)
# Strip .local suffix first, then take first component (for multi-dot hostnames)
DESIRED_HOSTNAME=$(echo "$PI_HOSTNAME" | sed 's/\.local$//' | cut -d'.' -f1)
print_info "Expected hostname: $DESIRED_HOSTNAME"

# Get current hostname from Pi
CURRENT_HOSTNAME=$(ssh "$PI_HOST" "hostname")
print_info "Current hostname: $CURRENT_HOSTNAME"

if [ "$CURRENT_HOSTNAME" != "$DESIRED_HOSTNAME" ]; then
    print_warning "Hostname mismatch detected"
    print_info "Updating hostname from '$CURRENT_HOSTNAME' to '$DESIRED_HOSTNAME'..."

    # Update hostname
    ssh "$PI_HOST" << EOF
set -e
echo "[INFO] Setting hostname to $DESIRED_HOSTNAME..."
sudo hostnamectl set-hostname "$DESIRED_HOSTNAME"

# Update /etc/hosts
sudo sed -i "s/$CURRENT_HOSTNAME/$DESIRED_HOSTNAME/g" /etc/hosts

echo "[SUCCESS] Hostname updated to $DESIRED_HOSTNAME"
echo "[INFO] Note: Hostname change takes full effect after reboot"
EOF

    if [ $? -eq 0 ]; then
        print_success "Hostname updated successfully"
        print_info "Note: Hostname change takes full effect after reboot"
    else
        print_error "Failed to update hostname"
        print_warning "Continuing with deployment..."
    fi
else
    print_success "Hostname is correctly set to $DESIRED_HOSTNAME"
fi

# Local Build Phase
if [ "$SKIP_LOCAL_BUILD" = false ]; then
    print_header "Building Projects Locally"

    print_info "Building on Mac (faster than Pi)..."
    print_info ""

    # Build backend
    if [ "$DEPLOY_BACKEND" = true ]; then
        print_info "Building backend..."
        cd "$REPOS_DIR/lacylights-go"

        # Check if we have a Makefile or just compile directly
        if [ -f "Makefile" ]; then
            print_info "Building Go backend with make..."
            make build-arm64
        elif [ -f "go.mod" ]; then
            print_info "Building Go backend..."
            GOOS=linux GOARCH=arm64 go build -o lacylights-server ./cmd/server
        fi

        if [ $? -eq 0 ]; then
            print_success "Backend built successfully"
        else
            print_error "Backend build failed"
            exit 1
        fi
    fi

    # Build frontend
    if [ "$DEPLOY_FRONTEND" = true ]; then
        print_info "Building frontend..."
        cd "$REPOS_DIR/lacylights-fe"

        # Install dependencies if needed
        if [ ! -d "node_modules" ]; then
            print_info "Installing frontend dependencies..."
            npm install
        fi

        # Build with NODE_ENV=production for static export
        print_info "Building Next.js app with static export..."
        NODE_ENV=production npm run build

        if [ $? -eq 0 ]; then
            print_success "Frontend built successfully"
        else
            print_error "Frontend build failed"
            exit 1
        fi
    fi

    # Build MCP
    if [ "$DEPLOY_MCP" = true ]; then
        print_info "Building MCP server..."
        cd "$REPOS_DIR/lacylights-mcp"

        # Install dependencies if needed
        if [ ! -d "node_modules" ]; then
            print_info "Installing MCP dependencies..."
            npm install
        fi

        # Build
        print_info "Compiling TypeScript..."
        npm run build

        if [ $? -eq 0 ]; then
            print_success "MCP server built successfully"
        else
            print_error "MCP server build failed"
            exit 1
        fi
    fi

    print_success "All projects built successfully on Mac"
else
    print_info "Skipping local build (using existing builds)"
fi

# Backend Deployment
if [ "$DEPLOY_BACKEND" = true ]; then
    print_header "Deploying Backend (lacylights-go)"

    cd "$REPOS_DIR/lacylights-go"

    # Check current branch
    BACKEND_BRANCH=$(git branch --show-current)
    print_info "Current branch: $BACKEND_BRANCH"

    # Sync backend to Pi (including built binary)
    print_info "Syncing Go backend binary and configuration to Raspberry Pi..."
    rsync -avz --delete \
        --exclude '.git' \
        --exclude '.DS_Store' \
        --exclude 'coverage' \
        --exclude '*.log' \
        --exclude '__tests__' \
        --include 'lacylights-server' \
        --include '.env*' \
        --include 'prisma/' \
        --include 'prisma/**' \
        --exclude '*' \
        ./ "$PI_HOST:$BACKEND_REMOTE/"

    # Ensure binary is executable
    print_info "Setting binary permissions..."
    ssh "$PI_HOST" "chmod +x $BACKEND_REMOTE/lacylights-server && sudo chown lacylights:lacylights $BACKEND_REMOTE/lacylights-server"

    print_success "Backend binary synced"
fi

# Frontend Deployment
if [ "$DEPLOY_FRONTEND" = true ]; then
    print_header "Deploying Frontend (lacylights-fe)"

    cd "$REPOS_DIR/lacylights-fe"

    # Check current branch
    FRONTEND_BRANCH=$(git branch --show-current)
    print_info "Current branch: $FRONTEND_BRANCH"

    # Type check frontend
    print_info "Running TypeScript type check..."
    if npm run type-check 2>&1 | grep -q "error TS"; then
        print_error "Frontend type check failed"
        print_error "Fix type errors before deploying"
        exit 1
    fi
    print_success "Frontend type check passed"

    # Sync frontend to Pi (including built .next/ and out/)
    print_info "Syncing frontend code and build artifacts to Raspberry Pi..."
    rsync -avz --delete \
        --exclude 'node_modules' \
        --exclude '.git' \
        --exclude '.DS_Store' \
        --exclude 'coverage' \
        --exclude '*.log' \
        --exclude '__tests__' \
        ./ "$PI_HOST:$FRONTEND_REMOTE/"

    print_success "Frontend code and build artifacts synced"
fi

# MCP Deployment
if [ "$DEPLOY_MCP" = true ]; then
    print_header "Deploying MCP Server (lacylights-mcp)"

    cd "$REPOS_DIR/lacylights-mcp"

    # Check current branch
    MCP_BRANCH=$(git branch --show-current)
    print_info "Current branch: $MCP_BRANCH"

    # Type check MCP
    print_info "Running TypeScript type check..."
    if npm run type-check 2>&1 | grep -q "error TS"; then
        print_error "MCP type check failed"
        print_error "Fix type errors before deploying"
        exit 1
    fi
    print_success "MCP type check passed"

    # Sync MCP to Pi (including built dist/)
    print_info "Syncing MCP code and build artifacts to Raspberry Pi..."
    rsync -avz --delete \
        --exclude 'node_modules' \
        --exclude '.git' \
        --exclude '.DS_Store' \
        --exclude 'coverage' \
        --exclude '*.log' \
        --exclude '__tests__' \
        ./ "$PI_HOST:$MCP_REMOTE/"

    print_success "MCP code and build artifacts synced"
fi

# Setup version management symlinks and files
print_header "Setting Up Version Management"

print_info "Creating symlinks for version management..."
ssh "$PI_HOST" << 'ENDSSH'
set -e

# Create symlinks in /opt/lacylights/repos/
if [ ! -L /opt/lacylights/repos/lacylights-go ]; then
    echo "[INFO] Creating symlink: lacylights-go -> backend"
    sudo ln -sf /opt/lacylights/backend /opt/lacylights/repos/lacylights-go
fi

if [ ! -L /opt/lacylights/repos/lacylights-fe ]; then
    echo "[INFO] Creating symlink: lacylights-fe -> frontend-src"
    sudo ln -sf /opt/lacylights/frontend-src /opt/lacylights/repos/lacylights-fe
fi

if [ ! -L /opt/lacylights/repos/lacylights-mcp ]; then
    echo "[INFO] Creating symlink: lacylights-mcp -> mcp"
    sudo ln -sf /opt/lacylights/mcp /opt/lacylights/repos/lacylights-mcp
fi

echo "[SUCCESS] Version management symlinks created"
ENDSSH

print_info "Creating version tracking files..."
ssh "$PI_HOST" << 'ENDSSH'
set -e

# Function to get git version from a repository
get_version() {
    local repo_path=$1
    cd "$repo_path"
    # Try to get the most recent tag
    version=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    # If no tags found, try to get from package.json
    if [ -z "$version" ] && [ -f "package.json" ]; then
        version=$(grep '"version"' package.json | head -1 | sed 's/.*"version": "\(.*\)".*/\1/')
        if [ -n "$version" ]; then
            version="v$version"
        fi
    fi

    # Default to unknown if still empty
    if [ -z "$version" ]; then
        version="unknown"
    fi

    echo "$version"
}

# Create version files for each repository with appropriate ownership
# backend is owned by lacylights, frontend-src and mcp are owned by pi
for repo in backend frontend-src mcp; do
    version=$(get_version "/opt/lacylights/$repo")
    echo "[INFO] Setting $repo version to $version"

    # Use appropriate user based on directory ownership
    if [ "$repo" = "backend" ]; then
        echo "$version" | sudo -u lacylights tee "/opt/lacylights/$repo/.lacylights-version" > /dev/null
    else
        echo "$version" | sudo -u pi tee "/opt/lacylights/$repo/.lacylights-version" > /dev/null
    fi
done

echo "[SUCCESS] Version tracking files created"
ENDSSH

if [ $? -eq 0 ]; then
    print_success "Version management setup complete"
else
    print_warning "Version management setup had some issues (non-critical)"
fi

# Rebuild on Pi (optional, for frontend/MCP only - Go backend doesn't need rebuild)
if [ "$REBUILD_ON_PI" = true ]; then
    print_header "Rebuilding Projects on Raspberry Pi"

    print_warning "Rebuilding on Pi is slower due to limited CPU"
    print_info "Consider using local builds (default) for faster deployments"
    print_info "Note: Go backend is pre-built and doesn't need rebuilding on Pi"
    print_info ""
    print_info "Connecting to Raspberry Pi to rebuild..."

    # Build commands based on what we deployed (skip backend - it's a pre-built binary)
    BUILD_COMMANDS=""

    if [ "$DEPLOY_FRONTEND" = true ]; then
        BUILD_COMMANDS+="echo '[INFO] Rebuilding frontend...'
cd $FRONTEND_REMOTE
npm install --production
npm run build
"
    fi

    if [ "$DEPLOY_MCP" = true ]; then
        BUILD_COMMANDS+="echo '[INFO] Rebuilding MCP server...'
cd $MCP_REMOTE
npm install --production
npm run build
"
    fi

    if [ -n "$BUILD_COMMANDS" ]; then
        ssh "$PI_HOST" "$BUILD_COMMANDS"

        if [ $? -eq 0 ]; then
            print_success "Rebuild on Pi completed successfully"
        else
            print_error "Rebuild failed on Pi"
            exit 1
        fi
    else
        print_info "No components require rebuilding on Pi"
    fi
else
    print_info "Skipping Pi rebuild (using locally built artifacts)"
fi

# Install production dependencies on Pi (only if we didn't already install during rebuild)
# Note: Go backend doesn't need npm dependencies - it's a self-contained binary
if [ "$REBUILD_ON_PI" = false ]; then
    print_header "Installing Production Dependencies on Pi"

    print_info "Installing runtime dependencies only..."
    print_info "Note: Go backend is self-contained and doesn't require dependencies"

    # Dependency installation commands based on what we deployed (skip backend)
    INSTALL_COMMANDS=""

    if [ "$DEPLOY_FRONTEND" = true ]; then
        INSTALL_COMMANDS+="echo '[INFO] Installing frontend dependencies...'
cd $FRONTEND_REMOTE
npm install --production
"
    fi

    if [ "$DEPLOY_MCP" = true ]; then
        INSTALL_COMMANDS+="echo '[INFO] Installing MCP dependencies...'
cd $MCP_REMOTE
npm install --production
"
    fi

    if [ -n "$INSTALL_COMMANDS" ]; then
        ssh "$PI_HOST" "$INSTALL_COMMANDS"

        if [ $? -eq 0 ]; then
            print_success "Production dependencies installed"
        else
            print_error "Failed to install dependencies on Pi"
            exit 1
        fi
    else
        print_info "No dependencies to install (Go backend is self-contained)"
    fi
else
    print_info "Skipping separate dependency installation (already installed during rebuild)"
fi

# Restart services
if [ "$SKIP_RESTART" = false ]; then
    print_header "Restarting Services"

    print_info "Restarting LacyLights service..."

    ssh "$PI_HOST" << 'ENDSSH'
set -e

echo "[INFO] Restarting LacyLights service..."
sudo systemctl restart lacylights

echo "[INFO] Waiting for service to start..."
sleep 3

echo "[INFO] Checking service status..."
if sudo systemctl is-active --quiet lacylights; then
    echo "[SUCCESS] LacyLights service is running"
else
    echo "[ERROR] LacyLights service failed to start"
    sudo systemctl status lacylights --no-pager
    exit 1
fi

ENDSSH

    if [ $? -eq 0 ]; then
        print_success "Services restarted successfully"
    else
        print_error "Failed to restart services on Pi"
        print_error "Check logs: ssh $PI_HOST 'sudo journalctl -u lacylights -n 50'"
        exit 1
    fi
fi

# Health Check
print_header "Health Check"

print_info "Checking GraphQL endpoint..."
sleep 2  # Give service time to fully start

HEALTH_CHECK=$(curl -s -f "http://$PI_HOSTNAME:4000/graphql" \
    -H "Content-Type: application/json" \
    -d '{"query": "{ __typename }"}' 2>/dev/null)

if echo "$HEALTH_CHECK" | grep -q "Query"; then
    print_success "✅ GraphQL endpoint is responding"
else
    print_warning "⚠️  GraphQL endpoint may not be responding correctly"
    print_info "Response: $HEALTH_CHECK"
fi

# Check WiFi status
print_info "Checking WiFi availability..."
WIFI_CHECK=$(curl -s "http://$PI_HOSTNAME:4000/graphql" \
    -H "Content-Type: application/json" \
    -d '{"query": "{ wifiStatus { available enabled connected } }"}' 2>/dev/null)

if echo "$WIFI_CHECK" | grep -q '"available":true'; then
    print_success "✅ WiFi configuration is available"
elif echo "$WIFI_CHECK" | grep -q '"available":false'; then
    print_info "ℹ️  WiFi configuration not available (expected on non-WiFi systems)"
fi

# Final success message
print_header "Deployment Complete!"

print_success "Deployment completed successfully"
print_info ""
print_info "Access your LacyLights instance:"
print_info "  🌐 http://$PI_HOSTNAME"
print_info ""
print_info "Useful commands:"
print_info "  View logs:    ssh $PI_HOST 'sudo journalctl -u lacylights -f'"
print_info "  Check status: ssh $PI_HOST 'sudo systemctl status lacylights'"
print_info "  Restart:      ssh $PI_HOST 'sudo systemctl restart lacylights'"
print_info ""
print_success "🎉 Happy lighting! 🎉"
