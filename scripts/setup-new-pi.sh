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
PI_USER="${PI_USER:-pi}"  # Default to 'pi', but allow override via environment variable
BACKEND_VERSION="main"
FRONTEND_VERSION="main"
MCP_VERSION="main"
OFFLINE_BUNDLE=""
WIFI_SSID="${WIFI_SSID:-}"
WIFI_PASSWORD="${WIFI_PASSWORD:-}"
SKIP_WIFI=false
OFFLINE_MODE_NEEDS_WIFI=false

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
            echo "LacyLights Complete Setup Script"
            echo ""
            echo "Usage: $0 <pi-host> [options]"
            echo ""
            echo "Arguments:"
            echo "  <pi-host>                 Hostname or SSH connection string"
            echo "                            (e.g., lacylights.local or pi@lacylights.local)"
            echo ""
            echo "Options:"
            echo "  --backend-version TAG     Git tag/branch for backend (default: main)"
            echo "  --frontend-version TAG    Git tag/branch for frontend (default: main)"
            echo "  --mcp-version TAG         Git tag/branch for MCP server (default: main)"
            echo "  --offline-bundle PATH     Use offline bundle (no internet on Pi required)"
            echo "  --wifi-ssid SSID          WiFi network name to connect to"
            echo "  --wifi-password PASSWORD  WiFi password"
            echo "  --skip-wifi               Skip WiFi configuration"
            echo "  --help                    Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  PI_USER                   Username for SSH (default: pi)"
            echo "                            Example: PI_USER=admin $0 ntclights.local"
            echo "  WIFI_SSID                 WiFi network name (alternative to --wifi-ssid)"
            echo "  WIFI_PASSWORD             WiFi password (alternative to --wifi-password)"
            echo ""
            echo "WiFi Configuration:"
            echo "  If the Pi needs internet access to download packages, you can configure WiFi:"
            echo "    $0 ntclights.local --wifi-ssid \"MyNetwork\" --wifi-password \"mypassword\""
            echo "  Or use environment variables:"
            echo "    WIFI_SSID=\"MyNetwork\" WIFI_PASSWORD=\"mypassword\" $0 ntclights.local"
            echo "  If WiFi credentials are not provided, the script will prompt for them."
            echo ""
            echo "Offline Installation:"
            echo "  For Pis without internet access, first prepare an offline bundle:"
            echo "    ./scripts/prepare-offline.sh"
            echo "  Then use the bundle for installation:"
            echo "    $0 lacylights.local --offline-bundle lacylights-offline-*.tar.gz"
            echo ""
            echo "Examples:"
            echo "  $0 pi@lacylights.local"
            echo "  $0 ntclights.local                    # Uses default user 'pi'"
            echo "  PI_USER=admin $0 ntclights.local      # Uses user 'admin'"
            echo "  $0 ntclights.local --wifi-ssid \"HomeWiFi\" --wifi-password \"secret\""
            echo "  $0 lacylights.local --backend-version v1.1.0 --frontend-version v0.2.0"
            echo "  $0 lacylights.local --offline-bundle lacylights-offline-20251027-160000.tar.gz"
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
    print_error "Example: $0 pi@lacylights.local or $0 lacylights.local"
    print_error "Use --help for more options"
    exit 1
fi

# Ensure PI_HOST includes username, default to 'pi' if not provided
if [[ "$PI_HOST" != *@* ]]; then
    print_info "No username specified, defaulting to user '$PI_USER'"
    PI_HOST="$PI_USER@$PI_HOST"
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

# Check SSH access and handle host key verification
print_info "Checking SSH access..."

# First, check if host key is already known
# PI_HOSTNAME was already extracted above for ping check
if ! ssh-keygen -F "$PI_HOSTNAME" >/dev/null 2>&1; then
    print_warning "Host key not yet verified for $PI_HOSTNAME"
    print_info "Connecting to verify host key (you may be prompted)..."

    # Do an interactive connection to handle host key verification
    # This allows the user to accept the host key
    if ! ssh -o ConnectTimeout=10 "$PI_HOST" "exit"; then
        print_error "Failed to connect to Pi"
        print_error "Please check:"
        print_error "  1. Pi is powered on and connected to network"
        print_error "  2. Hostname $PI_HOSTNAME is correct"
        print_error "  3. SSH is enabled on the Pi"
        exit 1
    fi

    print_success "Host key verified and saved"
fi

# Now check authentication method
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
rsync -avz \
    --exclude '.git' \
    --exclude '.claude' \
    --exclude '.offline-bundle-temp' \
    --exclude 'lacylights-offline-*.tar.gz' \
    --exclude '*.tar.gz' \
    --exclude '.DS_Store' \
    --exclude 'node_modules' \
    "$REPO_DIR/" "$PI_HOST:~/lacylights-setup/"

print_success "Setup scripts copied"

# WiFi Configuration (if needed and not skipped)
print_header "Step 2: Checking Internet Connectivity & Prerequisites"

# First check if Node.js is installed (required for all setups)
print_info "Checking for required packages on Pi..."
HAS_NODEJS=$(ssh "$PI_HOST" "command -v node &> /dev/null && echo 'yes' || echo 'no'")

# Check npm in multiple locations (sometimes not in pi user's default PATH)
HAS_NPM=$(ssh "$PI_HOST" 'bash -s' <<'ENDSSH'
check_npm_installed() {
    if command -v npm &> /dev/null; then
        echo "yes"
    elif [ -f /usr/bin/npm ]; then
        echo "yes"
    elif [ -f /usr/local/bin/npm ]; then
        echo "yes"
    else
        echo "no"
    fi
}
check_npm_installed
ENDSSH
)

HAS_INTERNET=$(ssh "$PI_HOST" "ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 && echo 'yes' || echo 'no'")

if [ "$HAS_NODEJS" = "yes" ]; then
    NODE_VERSION=$(ssh "$PI_HOST" "node -v")
    print_success "✅ Node.js is installed: $NODE_VERSION"
else
    print_warning "❌ Node.js is not installed"
fi

if [ "$HAS_NPM" = "yes" ]; then
    # Try to get npm version, checking multiple locations
    NPM_VERSION=$(ssh "$PI_HOST" "npm -v 2>/dev/null || /usr/bin/npm -v 2>/dev/null || /usr/local/bin/npm -v 2>/dev/null || echo 'unknown'")
    print_success "✅ npm is installed: v$NPM_VERSION"
else
    print_warning "❌ npm is not installed"
fi

if [ "$HAS_INTERNET" = "yes" ]; then
    print_success "✅ Pi has internet access"
else
    print_warning "❌ Pi does not have internet access"
fi

# For offline mode, Node.js and npm are hard requirements
# But we'll try to configure WiFi first if packages are missing and there's no internet
if [ -n "$OFFLINE_BUNDLE" ]; then
    if [ "$HAS_NODEJS" = "no" ] || [ "$HAS_NPM" = "no" ]; then
        # Check if we can get internet to install missing packages
        if [ "$HAS_INTERNET" = "no" ]; then
            print_warning ""
            print_warning "⚠️  OFFLINE MODE: Required packages missing on Raspberry Pi"
            print_warning ""

            if [ "$HAS_NODEJS" = "no" ]; then
                print_warning "   Missing: Node.js"
            fi
            if [ "$HAS_NPM" = "no" ]; then
                print_warning "   Missing: npm"
            fi

            print_warning ""
            print_info "Offline deployment requires Node.js and npm to be pre-installed."
            print_info "The Pi currently has no internet access."
            print_info ""
            print_info "Let's configure WiFi to enable internet access and install missing packages."
            print_info "After installation, the Pi can be disconnected from internet for future updates."
            print_info ""

            # Don't exit - let the WiFi configuration section handle this
            # Set a flag so we know WiFi is absolutely required
            OFFLINE_MODE_NEEDS_WIFI=true
        else
            # Pi has internet, we can install missing packages
            print_warning "Some packages are missing but Pi has internet access"
            print_info "Will attempt to install missing packages during system setup"

            if [ "$HAS_NODEJS" = "no" ]; then
                print_info "  - Will install: Node.js"
            fi
            if [ "$HAS_NPM" = "no" ]; then
                print_info "  - Will install: npm"
            fi
        fi
    fi
fi

# Determine if WiFi setup is needed
WIFI_NEEDED=false
if [ "$HAS_NODEJS" = "no" ] || [ "$HAS_INTERNET" = "no" ] || [ "$OFFLINE_MODE_NEEDS_WIFI" = "true" ]; then
    WIFI_NEEDED=true
fi

# WiFi Configuration
# Allow WiFi setup even in offline mode if packages are missing
if [ "$SKIP_WIFI" = false ] || [ "$OFFLINE_MODE_NEEDS_WIFI" = "true" ]; then
    if [ "$WIFI_NEEDED" = true ]; then
        if [ "$HAS_INTERNET" = "no" ]; then
            print_info ""
            print_info "Internet access is needed to download system packages (Node.js, etc.)"
            print_info "Let's configure WiFi to enable internet access."
            print_info ""
        fi
    else
        print_info "No WiFi configuration needed - all requirements met"
    fi

    if [ "$WIFI_NEEDED" = true ]; then
        # If WiFi credentials were provided via command-line or environment variables
        if [ -n "$WIFI_SSID" ]; then
            print_info "Using provided WiFi credentials"
            print_info "SSID: $WIFI_SSID"

            WIFI_SETUP_RESULT=0
            ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && bash 00-wifi-setup.sh '$WIFI_SSID' '$WIFI_PASSWORD' true" || WIFI_SETUP_RESULT=$?

            if [ $WIFI_SETUP_RESULT -eq 0 ]; then
                print_success "✅ WiFi configured successfully"
                print_success "Pi now has internet access"
                HAS_INTERNET="yes"
            else
                print_error "❌ WiFi configuration failed"

                if [ "$HAS_NODEJS" = "no" ]; then
                    print_error "Cannot continue without Node.js and internet access"
                    print_error "Please either:"
                    print_error "  1. Check your WiFi credentials and try again"
                    print_error "  2. Connect Pi to internet via Ethernet"
                    print_error "  3. Pre-install Node.js manually"
                    exit 1
                else
                    print_warning "Continuing with limited connectivity"
                fi
            fi
        else
            # Interactive WiFi setup - required if Node.js is missing
            if [ "$HAS_NODEJS" = "no" ]; then
                print_error "Node.js is required but not installed"
                print_info ""
                print_info "To install Node.js, we need internet access."
                print_info "Please configure WiFi now."
                print_info ""
                WIFI_REQUIRED=true
            else
                print_info "Would you like to configure WiFi now?"
                print_info ""
                print_info "Options:"
                print_info "  y - Configure WiFi interactively (recommended)"
                print_info "  n - Skip WiFi setup"
                print_info ""
                WIFI_REQUIRED=false
            fi

            # Get user choice
            if [ "$WIFI_REQUIRED" = true ]; then
                read -p "Configure WiFi to continue? (y/n): " -n 1 -r
            else
                read -p "Configure WiFi? (y/n): " -n 1 -r
            fi
            echo
            echo

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Starting interactive WiFi setup..."
                echo ""

                # Call the WiFi setup script interactively (it will scan and show networks)
                WIFI_SETUP_RESULT=0
                ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && bash 00-wifi-setup.sh" || WIFI_SETUP_RESULT=$?

                if [ $WIFI_SETUP_RESULT -eq 0 ]; then
                    print_success "✅ WiFi configured successfully"
                    print_success "Pi now has internet access"
                    HAS_INTERNET="yes"
                else
                    print_error "❌ WiFi configuration failed"

                    if [ "$WIFI_REQUIRED" = true ]; then
                        print_error "Cannot continue without internet access"
                        print_error "Please either:"
                        print_error "  1. Verify WiFi credentials and run setup again"
                        print_error "  2. Connect Pi to internet via Ethernet"
                        print_error "  3. Pre-install Node.js manually"
                        exit 1
                    else
                        print_warning "Continuing without internet"
                    fi
                fi
            else
                if [ "$WIFI_REQUIRED" = true ]; then
                    print_error "WiFi setup is required to install Node.js"
                    print_error "Cannot continue without Node.js"
                    print_error ""
                    print_error "Please either:"
                    print_error "  1. Run setup again and configure WiFi"
                    print_error "  2. Connect Pi to internet via Ethernet and run setup again"
                    print_error "  3. Pre-install Node.js manually, then run setup again"
                    exit 1
                else
                    print_info "Skipping WiFi configuration"
                    print_info "Setup will continue with existing connectivity"
                fi
            fi
        fi
    fi
else
    if [ "$OFFLINE_MODE_NEEDS_WIFI" != "true" ]; then
        print_info "Skipping connectivity check (--skip-wifi flag)"
    fi
fi

# Final check: if offline mode needs WiFi and we still don't have it, fail now
if [ "$OFFLINE_MODE_NEEDS_WIFI" = "true" ] && [ "$HAS_INTERNET" != "yes" ]; then
    print_error ""
    print_error "❌ Cannot continue offline deployment without internet access"
    print_error ""
    print_error "WiFi configuration was not completed successfully."
    print_error "Node.js and npm cannot be installed without internet."
    print_error ""
    print_error "Please either:"
    print_error "  1. Run setup again and configure WiFi when prompted"
    print_error "  2. Connect Pi to internet via Ethernet"
    print_error "  3. Pre-install Node.js manually:"
    print_error "     - Connect Pi to internet temporarily"
    print_error "     - Run: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -"
    print_error "     - Run: sudo apt-get install -y nodejs"
    print_error "     - Verify: node -v && npm -v"
    print_error ""
    exit 1
fi

# Run system setup
print_header "Step 3: System Setup"
print_info "Installing system dependencies..."

# Pass internet connectivity status to system setup script
# If we just configured WiFi, force online mode
if [ "$HAS_INTERNET" = "yes" ]; then
    print_info "Internet is available - installing packages online"
    ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 01-system-setup.sh --force-online"
else
    print_info "No internet - verifying existing packages only"
    ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 01-system-setup.sh"
fi

print_success "System setup complete"

# Re-check Node.js installation after system setup
print_info "Verifying Node.js installation..."
HAS_NODEJS=$(ssh "$PI_HOST" "command -v node &> /dev/null && echo 'yes' || echo 'no'")
HAS_NPM=$(ssh "$PI_HOST" "command -v npm &> /dev/null && echo 'yes' || echo 'no'")

if [ "$HAS_NODEJS" = "yes" ] && [ "$HAS_NPM" = "yes" ]; then
    NODE_VERSION=$(ssh "$PI_HOST" "node -v")
    NPM_VERSION=$(ssh "$PI_HOST" "npm -v")
    print_success "✅ Node.js $NODE_VERSION and npm v$NPM_VERSION are ready"
else
    print_error "❌ Node.js or npm installation failed"
    if [ "$HAS_NODEJS" = "no" ]; then
        print_error "   Node.js is still not available"
    fi
    if [ "$HAS_NPM" = "no" ]; then
        print_error "   npm is still not available"
    fi
    print_error "Cannot continue without Node.js and npm"
    exit 1
fi

# Run network setup
print_header "Step 4: Network Setup"
print_info "Configuring network and hostname..."

# Extract hostname from PI_HOST (e.g., pi@ntclights.local -> ntclights)
# Handle IP addresses separately to avoid breaking them
PI_HOST_PART=$(echo "$PI_HOST" | cut -d'@' -f2)

# Check if it's an IP address (contains only digits and dots)
if [[ "$PI_HOST_PART" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # It's an IP address - use it as-is, don't strip dots or add .local
    PI_HOSTNAME="$PI_HOST_PART"
    IS_IP_ADDRESS=true
else
    # It's a hostname - strip .local suffix if present
    PI_HOSTNAME=$(echo "$PI_HOST_PART" | sed 's/\.local$//')
    IS_IP_ADDRESS=false
fi

CURRENT_HOSTNAME=$(ssh "$PI_HOST" "hostname")

if [ "$CURRENT_HOSTNAME" != "$PI_HOSTNAME" ]; then
    print_info "Current hostname: $CURRENT_HOSTNAME"
    print_info "Setting internal hostname to: $PI_HOSTNAME"

    # Run hostname change in background to avoid SSH hang
    # The connection will drop when hostname changes
    ssh "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 02-network-setup.sh '$PI_HOSTNAME' &" 2>/dev/null || true

    print_info "Hostname change initiated..."
    print_info "Waiting for mDNS to update (10 seconds)..."
    sleep 10

    # Try to reconnect with new hostname
    if [ "$IS_IP_ADDRESS" = true ]; then
        # For IP addresses, reconnect to the same IP
        print_info "Attempting to reconnect to $PI_HOSTNAME..."
        RECONNECT_HOST="$PI_HOSTNAME"
    else
        # For hostnames, use .local suffix for mDNS
        print_info "Attempting to reconnect to $PI_HOSTNAME.local..."
        RECONNECT_HOST="$PI_HOSTNAME.local"
    fi

    MAX_RETRIES=6
    RETRY_COUNT=0
    RECONNECTED=false

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "$PI_USER@$RECONNECT_HOST" "exit" 2>/dev/null; then
            RECONNECTED=true
            print_success "✅ Reconnected to $RECONNECT_HOST"
            # Update PI_HOST for remaining steps
            PI_HOST="$PI_USER@$RECONNECT_HOST"
            break
        fi

        ((RETRY_COUNT++))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            print_info "Retry $RETRY_COUNT/$MAX_RETRIES..."
            sleep 5
        fi
    done

    if [ "$RECONNECTED" = false ]; then
        print_error "Failed to reconnect after hostname change"
        print_error "The Pi may still be accessible at the old hostname"
        print_info "Try connecting manually: ssh $PI_USER@$PI_HOSTNAME.local"
        exit 1
    fi

    print_success "Hostname changed to: $PI_HOSTNAME"
else
    print_info "Hostname already set to: $PI_HOSTNAME"
fi

print_success "Network setup complete"

# Run database setup
print_header "Step 5: Database Setup"
print_info "Creating SQLite database directory..."

ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && bash 03-database-setup.sh"

print_success "Database setup complete"

# Run permissions setup
print_header "Step 6: Permissions Setup"
print_info "Creating system user and setting permissions..."

ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 04-permissions-setup.sh"

print_success "Permissions setup complete"

# Check network connectivity (skip in offline mode)
if [ -z "$OFFLINE_BUNDLE" ]; then
    print_header "Step 7: Network Connectivity Check"
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
    print_header "Step 7: Network Connectivity Check"
    print_info "SKIPPED - Using offline bundle (no internet required on Pi)"
fi

# Step 8: Download/Extract releases (online or offline)
if [ -z "$OFFLINE_BUNDLE" ]; then
    # ONLINE MODE: Download from GitHub
    print_header "Step 8: Downloading Releases from GitHub"
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
    print_header "Step 8: Extracting from Offline Bundle"
    print_info "Using offline bundle (no internet access required)..."

    # Transfer bundle to Pi
    print_info "Transferring offline bundle to Pi..."
    ssh "$PI_HOST" "mkdir -p ~/lacylights-offline"
    scp "$OFFLINE_BUNDLE" "$PI_HOST:~/lacylights-offline/bundle.tar.gz"
    print_success "Bundle transferred"

    # Extract and install from bundle
    print_info "Extracting and installing from bundle..."
    ssh "$PI_HOST" << 'OFFLINE_INSTALL'
# Don't use set -e in this section - we handle errors explicitly with return codes
# All extract_with_progress calls check return values and exit on failure

cd ~/lacylights-offline

# Helper function for tar extraction with progress
extract_with_progress() {
    local tarfile="$1"
    local dest="$2"
    local description="$3"
    local strip_components="${4:-1}"  # Default to 1 if not specified

    echo "[INFO] $description"
    echo "[DEBUG] Extracting $tarfile to $dest (strip-components=$strip_components)"

    # Check if source file exists
    if [ ! -f "$tarfile" ]; then
        echo "[ERROR] File not found: $tarfile"
        return 1
    fi

    # Build tar options
    TAR_OPTS="-xz"
    if [ -n "$dest" ]; then
        TAR_OPTS="$TAR_OPTS -C $dest"
        if [ "$strip_components" != "0" ]; then
            TAR_OPTS="$TAR_OPTS --strip-components=$strip_components"
        fi
    fi

    # Check if pv is available for progress bar
    if command -v pv &> /dev/null; then
        pv "$tarfile" | tar $TAR_OPTS
        # Capture pipe statuses immediately (must not run any commands before this)
        EXTRACT_STATUS=( "${PIPESTATUS[@]}" )
        if [ "${EXTRACT_STATUS[0]}" -ne 0 ] || [ "${EXTRACT_STATUS[1]}" -ne 0 ]; then
            echo "[ERROR] Failed to extract $tarfile"
            return 1
        fi
    else
        # Extract with verbose error output
        # Filter out harmless extended header warnings
        tar -f "$tarfile" $TAR_OPTS 2>&1 | \
            grep -v "Ignoring unknown extended header keyword"
        # Capture pipe statuses immediately (must not run any commands before this)
        EXTRACT_STATUS=( "${PIPESTATUS[@]}" )
        # Check tar's exit status (grep failure is OK if no warnings to filter)
        if [ "${EXTRACT_STATUS[0]}" -ne 0 ]; then
            echo "[ERROR] Failed to extract $tarfile"
            return 1
        fi
    fi

    echo "[SUCCESS] Extracted $tarfile"
    return 0
}

# Extract bundle
echo "[INFO] Extracting offline bundle (this may take a minute)..."
echo "[DEBUG] Current directory: $(pwd)"
echo "[DEBUG] Bundle file: bundle.tar.gz"
ls -lh bundle.tar.gz

if command -v pv &> /dev/null; then
    echo "[INFO] Using pv for progress..."
    pv bundle.tar.gz | tar -xz
    TAR_EXIT=$?
else
    echo "[INFO] Extracting without progress bar..."
    tar -xzf bundle.tar.gz 2>&1 | grep -v "Ignoring unknown extended header keyword" || true
    TAR_EXIT=${PIPESTATUS[0]}
fi

if [ $TAR_EXIT -ne 0 ]; then
    echo "[ERROR] Failed to extract offline bundle (exit code: $TAR_EXIT)"
    echo "[ERROR] Checking bundle integrity..."
    file bundle.tar.gz
    exit 1
fi

echo "[SUCCESS] Bundle extracted successfully"
echo "[DEBUG] Contents of current directory:"
ls -la

# Ensure /opt/lacylights exists
echo "[INFO] Setting up /opt/lacylights directory..."
sudo mkdir -p /opt/lacylights
sudo chown -R pi:pi /opt/lacylights
sudo chmod 755 /opt/lacylights
echo "[SUCCESS] Directory ready"

# Extract release archives
echo "[INFO] Extracting backend..."
mkdir -p /opt/lacylights/backend
if ! extract_with_progress "releases/backend.tar.gz" "/opt/lacylights/backend" "Extracting backend code"; then
    echo "[ERROR] Failed to extract backend"
    exit 1
fi

echo "[INFO] Extracting frontend..."
mkdir -p /opt/lacylights/frontend-src
if ! extract_with_progress "releases/frontend.tar.gz" "/opt/lacylights/frontend-src" "Extracting frontend code"; then
    echo "[ERROR] Failed to extract frontend"
    exit 1
fi

echo "[INFO] Extracting MCP server..."
mkdir -p /opt/lacylights/mcp
if ! extract_with_progress "releases/mcp.tar.gz" "/opt/lacylights/mcp" "Extracting MCP server code"; then
    echo "[ERROR] Failed to extract MCP server"
    exit 1
fi

# Extract pre-downloaded node_modules
echo "[INFO] Extracting pre-downloaded dependencies..."
if [ -f releases/backend-node_modules.tar.gz ]; then
    echo "[INFO] Extracting backend dependencies (large file, may take 30-60 seconds)..."
    if ! extract_with_progress "releases/backend-node_modules.tar.gz" "/opt/lacylights/backend" "Backend dependencies"; then
        echo "[ERROR] Failed to extract backend dependencies"
        exit 1
    fi
else
    echo "[WARNING] backend-node_modules.tar.gz not found in bundle"
fi

if [ -f releases/frontend-node_modules.tar.gz ]; then
    echo "[INFO] Extracting frontend dependencies (large file, may take 30-60 seconds)..."
    if ! extract_with_progress "releases/frontend-node_modules.tar.gz" "/opt/lacylights/frontend-src" "Frontend dependencies"; then
        echo "[ERROR] Failed to extract frontend dependencies"
        exit 1
    fi
else
    echo "[WARNING] frontend-node_modules.tar.gz not found in bundle"
fi

if [ -f releases/mcp-node_modules.tar.gz ]; then
    echo "[INFO] Extracting MCP dependencies..."
    if ! extract_with_progress "releases/mcp-node_modules.tar.gz" "/opt/lacylights/mcp" "MCP dependencies"; then
        echo "[ERROR] Failed to extract MCP dependencies"
        exit 1
    fi
else
    echo "[WARNING] mcp-node_modules.tar.gz not found in bundle"
fi

# Extract pre-built artifacts (don't strip components - preserve dist/ and .next/ directories)
echo "[INFO] Extracting pre-built artifacts..."
if [ -f releases/backend-dist.tar.gz ]; then
    echo "[INFO] Extracting backend build artifacts..."
    if ! extract_with_progress "releases/backend-dist.tar.gz" "/opt/lacylights/backend" "Backend dist/" 0; then
        echo "[ERROR] Failed to extract backend dist/"
        exit 1
    fi
else
    echo "[WARNING] backend-dist.tar.gz not found in bundle"
fi

if [ -f releases/frontend-next.tar.gz ]; then
    echo "[INFO] Extracting frontend build artifacts..."
    if ! extract_with_progress "releases/frontend-next.tar.gz" "/opt/lacylights/frontend-src" "Frontend .next/" 0; then
        echo "[ERROR] Failed to extract frontend .next/"
        exit 1
    fi
else
    echo "[WARNING] frontend-next.tar.gz not found in bundle"
fi

if [ -f releases/frontend-out.tar.gz ]; then
    echo "[INFO] Extracting frontend static export..."
    if ! extract_with_progress "releases/frontend-out.tar.gz" "/opt/lacylights/frontend-src" "Frontend out/" 0; then
        echo "[ERROR] Failed to extract frontend out/"
        exit 1
    fi
else
    echo "[WARNING] frontend-out.tar.gz not found in bundle"
fi

if [ -f releases/mcp-dist.tar.gz ]; then
    echo "[INFO] Extracting MCP build artifacts..."
    if ! extract_with_progress "releases/mcp-dist.tar.gz" "/opt/lacylights/mcp" "MCP dist/" 0; then
        echo "[ERROR] Failed to extract MCP dist/"
        exit 1
    fi
else
    echo "[WARNING] mcp-dist.tar.gz not found in bundle"
fi

echo "[SUCCESS] All files extracted from offline bundle"
OFFLINE_INSTALL

    print_success "Offline bundle extracted successfully"
fi

# Create .env file for backend
print_header "Step 9: Creating Configuration Files"
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
print_header "Step 10: Building Projects"
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
    print_info "Using pre-built artifacts from offline bundle (OFFLINE MODE)..."
    print_info "Note: Only rebuilding native modules for ARM architecture"

    ssh "$PI_HOST" << 'OFFLINE_BUILD'
set -e

echo "[INFO] Rebuilding backend native modules..."
cd /opt/lacylights/backend
npm rebuild

echo "[INFO] Running database migrations..."
npx prisma generate
npx prisma migrate deploy

echo "[INFO] Rebuilding frontend native modules..."
cd /opt/lacylights/frontend-src
npm rebuild

if [ -d /opt/lacylights/mcp ]; then
    echo "[INFO] Rebuilding MCP server native modules..."
    cd /opt/lacylights/mcp
    npm rebuild
fi

echo "[SUCCESS] All projects ready (using pre-built artifacts)"

OFFLINE_BUILD

fi

print_success "All projects built"

# Install service
print_header "Step 11: Installing Service"
print_info "Installing systemd service..."

ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 05-service-install.sh"

print_success "Service installed"

# Fix permissions
print_info "Fixing file permissions..."
ssh "$PI_HOST" "sudo chown -R lacylights:lacylights /opt/lacylights"
print_success "Permissions fixed"

# Install and configure nginx
print_header "Step 12: Installing Nginx"
print_info "Installing and configuring nginx..."

ssh -t "$PI_HOST" "cd ~/lacylights-setup/setup && sudo bash 06-nginx-setup.sh"

print_success "Nginx installed and configured"

# Start service
print_header "Step 13: Starting Service"
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
print_header "Step 14: Health Check"
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
print_info "  🌐 http://$PI_HOSTNAME"
print_info ""
print_info "Internal hostname has been set to: $PI_HOSTNAME"
print_info ""
print_info "Useful commands:"
print_info "  ssh $PI_HOST 'sudo systemctl status lacylights'    - Check status"
print_info "  ssh $PI_HOST 'sudo journalctl -u lacylights -f'    - View logs"
print_info "  ssh $PI_HOST 'sudo systemctl restart lacylights'   - Restart service"
print_info ""
print_info "To deploy code changes in the future:"
print_info "  cd $REPO_DIR"
print_info "  PI_HOST=$PI_HOST ./scripts/deploy.sh"
print_info ""
print_success "🎭 Happy lighting! 🎭"
