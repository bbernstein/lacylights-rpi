#!/bin/bash

# LacyLights: Node to Go Backend Migration Script
# Migrates existing Raspberry Pi installations from Node.js backend to Go backend
#
# This script:
# - Detects current backend type
# - Backs up database and configuration
# - Downloads appropriate Go binary for Pi architecture
# - Verifies checksum
# - Stops Node backend
# - Installs Go backend
# - Updates systemd service
# - Starts Go backend
# - Provides rollback on failure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BACKEND_DIR="/opt/lacylights/backend"
DATABASE_PATH="$BACKEND_DIR/prisma/lacylights.db"
BACKUP_DIR="/opt/lacylights/backups"
DIST_BASE_URL="https://dist.lacylights.com/releases/go"
SERVICE_NAME="lacylights"
TEMP_DIR=""

# Logging
LOG_FILE="/var/log/lacylights-migration.log"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE" 2>/dev/null || true
}

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo "======================================== $1 ========================================" >> "$LOG_FILE" 2>/dev/null || true
}

# Cleanup function
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        print_info "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# Rollback function
rollback() {
    print_header "ROLLING BACK MIGRATION"
    print_error "Migration failed. Starting rollback procedure..."

    # Stop Go backend if running
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        print_info "Stopping Go backend service..."
        sudo systemctl stop "$SERVICE_NAME" || true
    fi

    # Restore Node backend service file
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service.node-backup" ]; then
        print_info "Restoring Node backend service file..."
        sudo cp "/etc/systemd/system/${SERVICE_NAME}.service.node-backup" "/etc/systemd/system/${SERVICE_NAME}.service"
        sudo systemctl daemon-reload
    fi

    # Restore database if backup exists
    if [ -f "${DATABASE_PATH}.pre-go-migration" ]; then
        print_info "Restoring database backup..."
        sudo cp "${DATABASE_PATH}.pre-go-migration" "$DATABASE_PATH"
        sudo chown lacylights:lacylights "$DATABASE_PATH"
    fi

    # Restore .env if backup exists
    if [ -f "${BACKEND_DIR}/.env.pre-go-migration" ]; then
        print_info "Restoring environment configuration..."
        sudo cp "${BACKEND_DIR}/.env.pre-go-migration" "${BACKEND_DIR}/.env"
        sudo chown lacylights:lacylights "${BACKEND_DIR}/.env"
    fi

    # Restart Node backend
    print_info "Restarting Node backend service..."
    sudo systemctl start "$SERVICE_NAME" || print_error "Failed to restart Node backend - manual intervention required"

    print_error "Rollback complete. System restored to Node backend."
    print_info "Check logs at: $LOG_FILE"
    exit 1
}

# Check if running as root or with sudo
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run with sudo"
        print_error "Usage: sudo $0"
        exit 1
    fi
}

# Detect current backend type
detect_backend_type() {
    print_header "Detecting Current Backend"

    # Check systemd service file
    if [ ! -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        print_error "LacyLights service not found"
        print_error "This script is for migrating existing installations only"
        exit 1
    fi

    # Check ExecStart line to determine backend type
    EXEC_START=$(grep "^ExecStart=" "/etc/systemd/system/${SERVICE_NAME}.service" | head -1)

    if echo "$EXEC_START" | grep -q "node"; then
        print_success "Detected Node.js backend"
        return 0
    elif echo "$EXEC_START" | grep -q "lacylights-server"; then
        print_info "Go backend already installed"
        print_info "Nothing to migrate"
        exit 0
    else
        print_error "Unknown backend type"
        print_error "ExecStart: $EXEC_START"
        exit 1
    fi
}

# Detect Raspberry Pi architecture
detect_architecture() {
    print_header "Detecting System Architecture"

    ARCH=$(uname -m)
    print_info "System architecture: $ARCH"

    case "$ARCH" in
        aarch64|arm64)
            BINARY_ARCH="arm64"
            print_success "Detected 64-bit ARM (Pi 4/5)"
            ;;
        armv7l|armhf)
            BINARY_ARCH="armhf"
            print_success "Detected 32-bit ARM (Pi 3)"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            print_error "This migration script supports Raspberry Pi 3, 4, and 5 only"
            exit 1
            ;;
    esac
}

# Create backup
create_backup() {
    print_header "Creating Backup"

    # Create backup directory
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_SUBDIR="$BACKUP_DIR/migration-$TIMESTAMP"

    print_info "Creating backup directory: $BACKUP_SUBDIR"
    sudo mkdir -p "$BACKUP_SUBDIR"

    # Backup database
    if [ -f "$DATABASE_PATH" ]; then
        print_info "Backing up database..."
        sudo cp "$DATABASE_PATH" "$BACKUP_SUBDIR/lacylights.db"
        sudo cp "$DATABASE_PATH" "${DATABASE_PATH}.pre-go-migration"
        print_success "Database backed up"
    else
        print_warning "Database not found at $DATABASE_PATH"
    fi

    # Backup .env file
    if [ -f "${BACKEND_DIR}/.env" ]; then
        print_info "Backing up environment configuration..."
        sudo cp "${BACKEND_DIR}/.env" "$BACKUP_SUBDIR/.env"
        sudo cp "${BACKEND_DIR}/.env" "${BACKEND_DIR}/.env.pre-go-migration"
        print_success "Environment configuration backed up"
    else
        print_warning ".env file not found"
    fi

    # Backup service file
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        print_info "Backing up service file..."
        sudo cp "/etc/systemd/system/${SERVICE_NAME}.service" "$BACKUP_SUBDIR/${SERVICE_NAME}.service"
        sudo cp "/etc/systemd/system/${SERVICE_NAME}.service" "/etc/systemd/system/${SERVICE_NAME}.service.node-backup"
        print_success "Service file backed up"
    fi

    print_success "Backup complete: $BACKUP_SUBDIR"
    print_info "In case of issues, backups are stored at: $BACKUP_SUBDIR"
}

# Download Go binary
download_go_binary() {
    print_header "Downloading Go Backend"

    # Get latest version info
    print_info "Fetching latest Go backend version..."
    LATEST_JSON=$(curl -fsSL "$DIST_BASE_URL/latest.json" 2>/dev/null || echo "")

    if [ -z "$LATEST_JSON" ]; then
        print_error "Failed to fetch latest version metadata"
        print_error "URL: $DIST_BASE_URL/latest.json"
        rollback
    fi

    # Parse version and download URL
    VERSION=$(echo "$LATEST_JSON" | grep -o "\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed -E 's/.*"([^"]*)".*/\1/')

    # Construct binary-specific URL
    BINARY_URL="$DIST_BASE_URL/lacylights-server-${VERSION}-${BINARY_ARCH}"
    CHECKSUM_URL="$DIST_BASE_URL/lacylights-server-${VERSION}-${BINARY_ARCH}.sha256"

    print_success "Latest version: $VERSION"
    print_info "Architecture: $BINARY_ARCH"
    print_info "Binary URL: $BINARY_URL"

    # Create temporary directory
    TEMP_DIR=$(mktemp -d)

    # Download binary
    print_info "Downloading Go backend binary..."
    if ! curl -fsSL -o "$TEMP_DIR/lacylights-server" "$BINARY_URL"; then
        print_error "Failed to download Go backend binary"
        print_error "URL: $BINARY_URL"
        rollback
    fi
    print_success "Binary downloaded"

    # Download checksum
    print_info "Downloading checksum..."
    if ! curl -fsSL -o "$TEMP_DIR/lacylights-server.sha256" "$CHECKSUM_URL"; then
        print_warning "Checksum file not available, skipping verification"
    else
        # Verify checksum
        print_info "Verifying checksum..."
        cd "$TEMP_DIR"
        if command -v sha256sum &> /dev/null; then
            if sha256sum -c lacylights-server.sha256 &> /dev/null; then
                print_success "Checksum verified"
            else
                print_error "Checksum verification failed"
                print_error "Binary may be corrupted or tampered with"
                rollback
            fi
        elif command -v shasum &> /dev/null; then
            EXPECTED=$(cat lacylights-server.sha256 | awk '{print $1}')
            ACTUAL=$(shasum -a 256 lacylights-server | awk '{print $1}')
            if [ "$EXPECTED" = "$ACTUAL" ]; then
                print_success "Checksum verified"
            else
                print_error "Checksum verification failed"
                print_error "Expected: $EXPECTED"
                print_error "Actual: $ACTUAL"
                rollback
            fi
        else
            print_warning "No SHA256 tool available, skipping verification"
        fi
        cd - > /dev/null
    fi
}

# Stop Node backend
stop_node_backend() {
    print_header "Stopping Node Backend"

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_info "Stopping $SERVICE_NAME service..."
        sudo systemctl stop "$SERVICE_NAME"

        # Wait for service to stop
        sleep 2

        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_error "Failed to stop $SERVICE_NAME service"
            rollback
        fi
        print_success "Node backend stopped"
    else
        print_info "Service is not running"
    fi
}

# Install Go binary
install_go_binary() {
    print_header "Installing Go Backend"

    # Copy binary to backend directory
    print_info "Installing Go backend binary..."
    sudo cp "$TEMP_DIR/lacylights-server" "$BACKEND_DIR/lacylights-server"
    sudo chmod +x "$BACKEND_DIR/lacylights-server"
    sudo chown lacylights:lacylights "$BACKEND_DIR/lacylights-server"
    print_success "Go backend binary installed"

    # Verify binary works
    print_info "Verifying binary..."
    if ! sudo -u lacylights "$BACKEND_DIR/lacylights-server" --version &> /dev/null; then
        print_error "Go backend binary verification failed"
        rollback
    fi
    print_success "Binary verified"
}

# Update systemd service
update_service() {
    print_header "Updating Systemd Service"

    # Create new service file
    print_info "Creating Go backend service file..."

    cat << 'EOF' | sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" > /dev/null
[Unit]
Description=LacyLights Stage Lighting Control (Go Backend)
Documentation=https://github.com/bbernstein/lacylights
After=network.target

[Service]
Type=simple
User=lacylights
Group=lacylights
WorkingDirectory=/opt/lacylights/backend

# Environment variables
Environment="NODE_ENV=production"
EnvironmentFile=/opt/lacylights/backend/.env

# Start the Go backend server
ExecStart=/opt/lacylights/backend/lacylights-server

# Restart policy
Restart=always
RestartSec=10
StartLimitBurst=3
StartLimitInterval=60

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lacylights

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/lacylights

# Resource limits
LimitNOFILE=65536
MemoryMax=256M

[Install]
WantedBy=multi-user.target
EOF

    print_success "Service file created"

    # Reload systemd
    print_info "Reloading systemd daemon..."
    sudo systemctl daemon-reload
    print_success "Systemd reloaded"
}

# Update environment configuration
update_env_config() {
    print_header "Updating Environment Configuration"

    # The Go backend uses the same .env format
    # Just ensure critical settings are present

    if [ -f "${BACKEND_DIR}/.env" ]; then
        print_info "Verifying environment configuration..."

        # Check for DATABASE_URL
        if ! grep -q "^DATABASE_URL=" "${BACKEND_DIR}/.env"; then
            print_warning "DATABASE_URL not found, adding default..."
            echo 'DATABASE_URL="file:./prisma/lacylights.db"' | sudo tee -a "${BACKEND_DIR}/.env" > /dev/null
        fi

        # Check for PORT
        if ! grep -q "^PORT=" "${BACKEND_DIR}/.env"; then
            print_warning "PORT not found, adding default..."
            echo 'PORT=4000' | sudo tee -a "${BACKEND_DIR}/.env" > /dev/null
        fi

        print_success "Environment configuration verified"
    else
        print_error ".env file not found"
        rollback
    fi
}

# Start Go backend
start_go_backend() {
    print_header "Starting Go Backend"

    print_info "Starting $SERVICE_NAME service..."
    sudo systemctl start "$SERVICE_NAME"

    # Wait for service to start
    sleep 3

    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        print_error "Failed to start Go backend service"
        print_error "Check logs: sudo journalctl -u $SERVICE_NAME -n 50"
        rollback
    fi

    print_success "Go backend started"
}

# Verify health
verify_health() {
    print_header "Verifying Health"

    # Wait for server to be ready
    print_info "Waiting for server to be ready..."
    sleep 5

    # Try to connect to GraphQL endpoint
    print_info "Testing GraphQL endpoint..."

    MAX_RETRIES=10
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -f -s -o /dev/null -X POST \
            -H "Content-Type: application/json" \
            -d '{"query":"{ __typename }"}' \
            http://localhost:4000/graphql; then
            print_success "GraphQL endpoint is responding"
            return 0
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        print_info "Retry $RETRY_COUNT/$MAX_RETRIES..."
        sleep 2
    done

    print_error "GraphQL endpoint not responding"
    print_error "Service status:"
    sudo systemctl status "$SERVICE_NAME" --no-pager || true
    print_error "Recent logs:"
    sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager || true
    rollback
}

# Print completion message
print_completion() {
    print_header "Migration Complete!"

    cat << EOF

${GREEN}Successfully migrated to Go backend!${NC}

${CYAN}Summary:${NC}
  Backend Type:    Go (from Node.js)
  Version:         $VERSION
  Architecture:    $BINARY_ARCH
  Database:        $DATABASE_PATH (migrated)
  Service:         $SERVICE_NAME (updated)

${CYAN}Next Steps:${NC}
  1. Test your lighting setup to ensure everything works
  2. Check service status: sudo systemctl status $SERVICE_NAME
  3. View logs: sudo journalctl -u $SERVICE_NAME -f
  4. Access web interface: http://lacylights.local

${CYAN}Backups:${NC}
  Database:        $BACKUP_SUBDIR/lacylights.db
  Config:          $BACKUP_SUBDIR/.env
  Service:         $BACKUP_SUBDIR/${SERVICE_NAME}.service

${CYAN}Performance Benefits:${NC}
  - Faster startup time
  - Lower memory usage (~256MB vs ~512MB)
  - Better concurrent request handling
  - Native binary (no Node.js runtime overhead)

${CYAN}Rollback:${NC}
  If you need to rollback to Node.js backend:
    sudo systemctl stop $SERVICE_NAME
    sudo cp /etc/systemd/system/${SERVICE_NAME}.service.node-backup \\
           /etc/systemd/system/${SERVICE_NAME}.service
    sudo systemctl daemon-reload
    sudo systemctl start $SERVICE_NAME

${CYAN}Documentation:${NC}
  Migration log: $LOG_FILE

${GREEN}Happy Lighting!${NC}

EOF
}

# Main migration flow
main() {
    print_header "LacyLights: Node to Go Backend Migration"

    print_info "This script will migrate your LacyLights installation from Node.js to Go backend"
    print_info "Log file: $LOG_FILE"
    print_warning "Please ensure you have a backup before proceeding"
    echo ""

    read -p "Continue with migration? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        print_info "Migration cancelled"
        exit 0
    fi

    # Initialize log file
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"

    # Run migration steps
    check_root
    detect_backend_type
    detect_architecture
    create_backup
    download_go_binary
    stop_node_backend
    install_go_binary
    update_env_config
    update_service
    start_go_backend
    verify_health

    # Success!
    print_completion
}

# Run main function
main "$@"
