#!/bin/bash

# LacyLights Network Setup
# Configures NetworkManager and hostname
#
# Usage:
#   sudo bash 02-network-setup.sh [hostname]
#
# Arguments:
#   hostname    Optional hostname to set (default: lacylights)

set -e

# Determine setup directory (one level up from this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$(dirname "$SCRIPT_DIR")"

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

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_header "LacyLights Network Setup"

# Get desired hostname from argument or default to lacylights
DESIRED_HOSTNAME="${1:-lacylights}"
print_info "Target hostname: $DESIRED_HOSTNAME"

# Set hostname
print_info "Setting hostname to $DESIRED_HOSTNAME..."

CURRENT_HOSTNAME=$(hostname)
if [ "$CURRENT_HOSTNAME" == "$DESIRED_HOSTNAME" ]; then
    print_success "Hostname already set to $DESIRED_HOSTNAME"
else
    sudo hostnamectl set-hostname "$DESIRED_HOSTNAME"

    # Update /etc/hosts
    sudo sed -i "s/$CURRENT_HOSTNAME/$DESIRED_HOSTNAME/g" /etc/hosts

    print_success "Hostname changed from $CURRENT_HOSTNAME to $DESIRED_HOSTNAME"
    print_info "Reboot required for hostname change to take full effect"
fi

# Enable and start NetworkManager
print_info "Enabling NetworkManager..."

if systemctl is-enabled NetworkManager &> /dev/null; then
    print_success "NetworkManager already enabled"
else
    sudo systemctl enable NetworkManager
    print_success "NetworkManager enabled"
fi

if systemctl is-active NetworkManager &> /dev/null; then
    print_success "NetworkManager already running"
else
    sudo systemctl start NetworkManager
    print_success "NetworkManager started"
fi

# Check WiFi device
print_info "Checking WiFi device..."

if nmcli device status | grep -q "wifi"; then
    WIFI_DEVICE=$(nmcli device status | grep wifi | awk '{print $1}' | head -n 1)
    print_success "WiFi device found: $WIFI_DEVICE"

    # Enable WiFi radio
    print_info "Enabling WiFi radio..."
    sudo nmcli radio wifi on
    print_success "WiFi radio enabled"
else
    print_error "No WiFi device found"
    print_error "This Raspberry Pi may not have WiFi capability"
    print_info "Continuing with wired network only..."
fi

# Check wired connection
print_info "Checking wired network..."

if nmcli device status | grep -q "ethernet.*connected"; then
    ETH_DEVICE=$(nmcli device status | grep "ethernet.*connected" | awk '{print $1}' | head -n 1)
    print_success "Wired connection active on $ETH_DEVICE"

    # Configure Ethernet for local-only traffic (high metric = low priority for internet)
    print_info "Configuring Ethernet for local network only..."
    ETH_CONNECTION=$(nmcli -t -f GENERAL.CONNECTION device show "$ETH_DEVICE" | cut -d: -f2)
    if [ -n "$ETH_CONNECTION" ]; then
        sudo nmcli connection modify "$ETH_CONNECTION" ipv4.route-metric 200
        sudo nmcli connection modify "$ETH_CONNECTION" ipv6.route-metric 200
        print_success "Ethernet configured with low priority for internet routing"
        print_info "WiFi (when connected) will be used for internet access"
    fi
else
    print_error "No active wired connection found"
    print_info "Please ensure ethernet cable is connected"
fi

# Install NetworkManager dispatcher script for automatic route priority
print_info "Installing route priority dispatcher script..."

sudo mkdir -p /etc/NetworkManager/dispatcher.d

# Copy dispatcher script from setup directory
DISPATCHER_SCRIPT="$SETUP_DIR/config/networkmanager/dispatcher.d/99-route-priority"
if [ -f "$DISPATCHER_SCRIPT" ]; then
    sudo cp "$DISPATCHER_SCRIPT" /etc/NetworkManager/dispatcher.d/99-route-priority
    sudo chmod +x /etc/NetworkManager/dispatcher.d/99-route-priority
    print_success "Route priority dispatcher installed"
    print_info "All WiFi connections will automatically have internet routing priority"
else
    print_error "Dispatcher script not found at $DISPATCHER_SCRIPT"
    print_info "Route priority will need to be configured manually"
fi

# Install gpiod for GPIO button monitoring
print_info "Installing gpiod for GPIO button support..."
if dpkg -l | grep -q "gpiod"; then
    print_success "gpiod already installed"
else
    sudo apt-get update
    sudo apt-get install -y gpiod
    print_success "gpiod installed"
fi

# Install dnsmasq captive portal configuration
print_info "Installing captive portal DNS configuration..."
CAPTIVE_PORTAL_CONF="$SETUP_DIR/config/networkmanager/dnsmasq-shared.d/captive-portal.conf"
if [ -f "$CAPTIVE_PORTAL_CONF" ]; then
    sudo mkdir -p /etc/NetworkManager/dnsmasq-shared.d
    sudo cp "$CAPTIVE_PORTAL_CONF" /etc/NetworkManager/dnsmasq-shared.d/captive-portal.conf
    print_success "Captive portal DNS configuration installed"
else
    print_warning "Captive portal config not found at $CAPTIVE_PORTAL_CONF"
fi

# Install captive portal nginx configuration
print_info "Installing captive portal nginx configuration..."
CAPTIVE_NGINX="$SETUP_DIR/nginx/sites-available/lacylights-captive"
if [ -f "$CAPTIVE_NGINX" ]; then
    sudo cp "$CAPTIVE_NGINX" /etc/nginx/sites-available/lacylights-captive
    print_success "Captive portal nginx configuration installed"
    print_info "Note: This config will be activated automatically when AP mode is enabled"
else
    print_warning "Captive portal nginx config not found at $CAPTIVE_NGINX"
fi

# Create pre-configured AP connection profile (disabled by default)
print_info "Creating AP mode connection profile..."

# Generate SSID from MAC address
if [ -f "/sys/class/net/wlan0/address" ]; then
    MAC=$(cat /sys/class/net/wlan0/address | tr -d ':' | tail -c 5 | tr '[:lower:]' '[:upper:]')
    AP_SSID="lacylights-${MAC}"
else
    AP_SSID="lacylights-setup"
fi

# Check if AP connection already exists
if nmcli connection show "$AP_SSID" &> /dev/null; then
    print_success "AP connection profile '$AP_SSID' already exists"
else
    # Create AP connection (but don't activate it)
    sudo nmcli connection add \
        type wifi \
        ifname wlan0 \
        con-name "$AP_SSID" \
        autoconnect no \
        ssid "$AP_SSID" \
        mode ap \
        ipv4.method shared \
        ipv4.addresses "192.168.4.1/24" \
        wifi.band bg \
        wifi.channel 6 2>/dev/null && \
    print_success "AP connection profile '$AP_SSID' created" || \
    print_warning "Could not create AP connection profile (this is OK if running off-device)"
fi

print_header "Network Setup Complete"
print_success "Network configuration completed"
print_info ""
print_info "Dual Network Configuration:"
print_info "  • Ethernet (eth0): Local DMX/Art-Net network"
print_info "  • WiFi (wlan0): Internet access (when configured)"
print_info ""
print_info "AP Mode Configuration:"
print_info "  • SSID: $AP_SSID"
print_info "  • IP: 192.168.4.1"
print_info "  • AP mode will auto-start if no WiFi connection at boot"
print_info "  • Hold GPIO button for 5s to force AP mode"
print_info ""
print_info "Network Status:"
nmcli device status
