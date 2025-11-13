#!/bin/bash

# LacyLights RPi One-Command Installer
# Downloads and extracts the latest release for easy installation on Raspberry Pi

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

# Default values
GITHUB_REPO="bbernstein/lacylights-rpi"
VERSION="${1:-latest}"
INSTALL_DIR="$HOME/lacylights-setup"
PI_HOST="${2:-}"

# Parse command line arguments
show_help() {
    cat << EOF
LacyLights RPi Installer

This script downloads and installs LacyLights deployment tools on a Raspberry Pi.

USAGE:
    Local installation (run on the Raspberry Pi):
        curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh | bash
        curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh | bash -s -- v1.0.0

    Remote installation (run from your development machine):
        curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh | bash -s -- latest pi@raspberrypi.local
        curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh | bash -s -- v1.0.0 pi@lacylights.local

ARGUMENTS:
    VERSION         Version tag to install (default: latest)
                    Examples: latest, v1.0.0, v1.2.3

    PI_HOST         SSH host for remote installation (optional)
                    Examples: pi@raspberrypi.local, pi@192.168.1.100
                    If provided, installation happens on the remote Pi via SSH

EXAMPLES:
    # Install latest version locally on the Pi
    curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh | bash

    # Install specific version locally on the Pi
    curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh | bash -s -- v1.0.0

    # Install latest version on a remote Pi
    curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh | bash -s -- latest pi@raspberrypi.local

    # Install specific version on a remote Pi
    curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh | bash -s -- v1.0.0 pi@lacylights.local

NEXT STEPS:
    After installation, run the setup script:
        cd ~/lacylights-setup
        ./scripts/setup-new-pi.sh <pi-host>

    Or if already on the Pi:
        cd ~/lacylights-setup
        sudo ./setup/01-system-setup.sh
        # ... continue with other setup scripts

EOF
    exit 0
}

if [ "$VERSION" = "--help" ] || [ "$VERSION" = "-h" ]; then
    show_help
fi

print_header "LacyLights RPi Installer"

# Remote installation mode
if [ -n "$PI_HOST" ]; then
    print_info "Remote installation mode"
    print_info "Target: $PI_HOST"
    print_info "Version: $VERSION"
    echo ""

    # Download this script and execute on remote Pi
    print_info "Downloading installer to remote Pi..."

    REMOTE_SCRIPT=$(cat << 'REMOTE_EOF'
#!/bin/bash
set -e

# Re-download installer on the Pi (ensures we have the latest)
TEMP_INSTALLER=$(mktemp)
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh -o "$TEMP_INSTALLER"
chmod +x "$TEMP_INSTALLER"

# Execute installer locally on the Pi
bash "$TEMP_INSTALLER" VERSION_PLACEHOLDER

# Clean up
rm -f "$TEMP_INSTALLER"
REMOTE_EOF
)

    # Replace VERSION_PLACEHOLDER with actual version
    REMOTE_SCRIPT="${REMOTE_SCRIPT//VERSION_PLACEHOLDER/$VERSION}"

    # Execute on remote Pi
    ssh "$PI_HOST" "$REMOTE_SCRIPT"

    print_success "Installation complete on remote Pi!"
    print_info ""
    print_info "Next steps:"
    print_info "  ssh $PI_HOST"
    print_info "  cd ~/lacylights-setup"
    print_info "  ./scripts/setup-new-pi.sh"
    exit 0
fi

# Local installation mode (running on the Pi)
print_info "Local installation mode"
print_info "Version: $VERSION"
print_info "Install directory: $INSTALL_DIR"
echo ""

# Check if we're on a Raspberry Pi (optional warning)
if [ -f /proc/device-tree/model ]; then
    PI_MODEL=$(cat /proc/device-tree/model)
    print_info "Detected: $PI_MODEL"
else
    print_warning "This doesn't appear to be a Raspberry Pi"
    print_warning "Continuing anyway..."
fi

# Check for required tools
print_info "Checking for required tools..."
for cmd in curl tar; do
    if ! command -v $cmd &> /dev/null; then
        print_error "Required command '$cmd' not found"
        print_error "Please install it first: sudo apt-get install $cmd"
        exit 1
    fi
done
print_success "All required tools present"

# Determine download URL
if [ "$VERSION" = "latest" ]; then
    print_info "Fetching latest release information..."
    RELEASE_DATA=$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/releases/latest")
    VERSION=$(echo "$RELEASE_DATA" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$VERSION" ]; then
        print_error "Failed to fetch latest release version"
        print_error "Please specify a version explicitly"
        exit 1
    fi

    print_success "Latest version: $VERSION"
fi

# Extract version number without 'v' prefix for filename
VERSION_NUMBER="${VERSION#v}"
DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$VERSION/lacylights-rpi-$VERSION_NUMBER.tar.gz"

print_info "Download URL: $DOWNLOAD_URL"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Download release archive
print_header "Downloading Release"
print_info "Downloading from GitHub..."

if ! curl -fsSL -o "$TEMP_DIR/lacylights-rpi.tar.gz" "$DOWNLOAD_URL"; then
    print_error "Failed to download release archive"
    print_error "URL: $DOWNLOAD_URL"
    print_error ""
    print_error "Possible issues:"
    print_error "  1. Version '$VERSION' does not exist"
    print_error "  2. No internet connection"
    print_error "  3. GitHub is unreachable"
    print_error ""
    print_error "Available releases: https://github.com/$GITHUB_REPO/releases"
    exit 1
fi

print_success "Download complete"

# Backup existing installation if present
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Existing installation found"
    BACKUP_DIR="${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    print_info "Creating backup: $BACKUP_DIR"
    mv "$INSTALL_DIR" "$BACKUP_DIR"
    print_success "Backup created"
fi

# Extract archive
print_header "Installing"
print_info "Creating installation directory..."
mkdir -p "$INSTALL_DIR"

print_info "Extracting files..."
tar xzf "$TEMP_DIR/lacylights-rpi.tar.gz" -C "$INSTALL_DIR"

# Verify installation
if [ ! -f "$INSTALL_DIR/scripts/setup-new-pi.sh" ]; then
    print_error "Installation verification failed"
    print_error "Expected files not found in archive"
    exit 1
fi

# Make scripts executable
print_info "Setting permissions..."
chmod +x "$INSTALL_DIR"/scripts/*.sh 2>/dev/null || true
chmod +x "$INSTALL_DIR"/setup/*.sh 2>/dev/null || true
chmod +x "$INSTALL_DIR"/utils/*.sh 2>/dev/null || true

print_success "Installation complete!"

# Show next steps
print_header "Next Steps"

cat << EOF

Installation successful! LacyLights deployment tools are now installed at:
    $INSTALL_DIR

To set up LacyLights on this Raspberry Pi, you have two options:

${CYAN}Option 1: Complete automated setup${NC} (recommended for new installations)
    cd ~/lacylights-setup
    ./scripts/setup-new-pi.sh localhost

${CYAN}Option 2: Manual step-by-step setup${NC} (for advanced users)
    cd ~/lacylights-setup
    sudo ./setup/01-system-setup.sh
    sudo ./setup/02-network-setup.sh
    sudo ./setup/03-database-setup.sh
    sudo ./setup/04-permissions-setup.sh
    sudo ./setup/05-service-install.sh

${CYAN}Documentation:${NC}
    README:           $INSTALL_DIR/README.md
    Setup guide:      $INSTALL_DIR/docs/INITIAL_SETUP.md
    WiFi setup:       $INSTALL_DIR/docs/WIFI_SETUP.md
    Troubleshooting:  $INSTALL_DIR/docs/TROUBLESHOOTING.md

${CYAN}Installed version:${NC} $VERSION

${CYAN}Need help?${NC}
    https://github.com/$GITHUB_REPO/issues

EOF

print_success "Happy lighting! 🎭"
