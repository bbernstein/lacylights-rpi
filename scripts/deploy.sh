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
PI_HOST="${PI_HOST:-pi@lacylights.local}"
BACKEND_REMOTE="/opt/lacylights/backend"
FRONTEND_REMOTE="/opt/lacylights/frontend-src"
MCP_REMOTE="/opt/lacylights/mcp"
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPOS_DIR="$(dirname "$LOCAL_DIR")"

# Parse command line arguments
DEPLOY_BACKEND=true
DEPLOY_FRONTEND=true
DEPLOY_MCP=true
SKIP_REBUILD=false
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
        --skip-rebuild)
            SKIP_REBUILD=true
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
            echo "  --backend-only      Deploy only backend"
            echo "  --frontend-only     Deploy only frontend"
            echo "  --mcp-only          Deploy only MCP server"
            echo "  --skip-rebuild      Sync files only, no rebuild"
            echo "  --skip-restart      Don't restart services"
            echo "  --help              Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  PI_HOST             Raspberry Pi SSH host (default: pi@lacylights.local)"
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
print_info "  Rebuild: $([ "$SKIP_REBUILD" = false ] && echo "✓" || echo "✗")"
print_info "  Restart: $([ "$SKIP_RESTART" = false ] && echo "✓" || echo "✗")"

# Check if repos exist
print_header "Checking Prerequisites"

if [ ! -d "$REPOS_DIR/lacylights-node" ]; then
    print_error "Backend repository not found at $REPOS_DIR/lacylights-node"
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
if ! ping -c 1 -W 2 lacylights.local &> /dev/null; then
    print_error "Cannot reach lacylights.local"
    print_error "Please ensure:"
    print_error "  1. Raspberry Pi is powered on"
    print_error "  2. Connected to the same network"
    print_error "  3. Hostname lacylights.local is resolving"
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

# Backend Deployment
if [ "$DEPLOY_BACKEND" = true ]; then
    print_header "Deploying Backend (lacylights-node)"

    cd "$REPOS_DIR/lacylights-node"

    # Check current branch
    BACKEND_BRANCH=$(git branch --show-current)
    print_info "Current branch: $BACKEND_BRANCH"

    # Type check backend
    print_info "Running TypeScript type check..."
    if npm run type-check 2>&1 | grep -q "error TS"; then
        print_error "Backend type check failed"
        print_error "Fix type errors before deploying"
        exit 1
    fi
    print_success "Backend type check passed"

    # Sync backend to Pi
    print_info "Syncing backend code to Raspberry Pi..."
    rsync -avz --delete \
        --exclude 'node_modules' \
        --exclude '.git' \
        --exclude '.env.local' \
        --exclude 'dist' \
        --exclude '.DS_Store' \
        --exclude 'coverage' \
        --exclude '*.log' \
        --exclude '__tests__' \
        ./ "$PI_HOST:$BACKEND_REMOTE/"

    print_success "Backend code synced"
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

    # Sync frontend to Pi
    print_info "Syncing frontend code to Raspberry Pi..."
    rsync -avz --delete \
        --exclude 'node_modules' \
        --exclude '.git' \
        --exclude '.next' \
        --exclude 'out' \
        --exclude '.DS_Store' \
        --exclude 'coverage' \
        --exclude '*.log' \
        --exclude '__tests__' \
        ./ "$PI_HOST:$FRONTEND_REMOTE/"

    print_success "Frontend code synced"
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

    # Sync MCP to Pi
    print_info "Syncing MCP code to Raspberry Pi..."
    rsync -avz --delete \
        --exclude 'node_modules' \
        --exclude '.git' \
        --exclude 'dist' \
        --exclude '.DS_Store' \
        --exclude 'coverage' \
        --exclude '*.log' \
        --exclude '__tests__' \
        ./ "$PI_HOST:$MCP_REMOTE/"

    print_success "MCP code synced"
fi

# Rebuild and Restart on Pi
if [ "$SKIP_REBUILD" = false ]; then
    print_header "Building Projects on Raspberry Pi"

    print_info "Connecting to Raspberry Pi to rebuild..."

    # Build commands based on what we deployed
    BUILD_COMMANDS=""

    if [ "$DEPLOY_BACKEND" = true ]; then
        BUILD_COMMANDS+="echo '[INFO] Rebuilding backend...'
cd $BACKEND_REMOTE
npm install
npm run build
"
    fi

    if [ "$DEPLOY_FRONTEND" = true ]; then
        BUILD_COMMANDS+="echo '[INFO] Rebuilding frontend...'
cd $FRONTEND_REMOTE
npm install
npm run build
"
    fi

    if [ "$DEPLOY_MCP" = true ]; then
        BUILD_COMMANDS+="echo '[INFO] Rebuilding MCP server...'
cd $MCP_REMOTE
npm install
npm run build
"
    fi

    ssh "$PI_HOST" "$BUILD_COMMANDS"

    if [ $? -eq 0 ]; then
        print_success "Build completed successfully"
    else
        print_error "Build failed on Pi"
        exit 1
    fi
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

HEALTH_CHECK=$(curl -s -f http://lacylights.local:4000/graphql \
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
WIFI_CHECK=$(curl -s http://lacylights.local:4000/graphql \
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
print_info "  🌐 http://lacylights.local"
print_info ""
print_info "Useful commands:"
print_info "  View logs:    ssh $PI_HOST 'sudo journalctl -u lacylights -f'"
print_info "  Check status: ssh $PI_HOST 'sudo systemctl status lacylights'"
print_info "  Restart:      ssh $PI_HOST 'sudo systemctl restart lacylights'"
print_info ""
print_success "🎉 Happy lighting! 🎉"
