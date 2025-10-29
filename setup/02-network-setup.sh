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
if [ -f ~/lacylights-setup/config/networkmanager/dispatcher.d/99-route-priority ]; then
    sudo cp ~/lacylights-setup/config/networkmanager/dispatcher.d/99-route-priority \
        /etc/NetworkManager/dispatcher.d/99-route-priority
    sudo chmod +x /etc/NetworkManager/dispatcher.d/99-route-priority
    print_success "Route priority dispatcher installed"
    print_info "All WiFi connections will automatically have internet routing priority"
else
    print_error "Dispatcher script not found at ~/lacylights-setup/config/networkmanager/dispatcher.d/99-route-priority"
    print_info "Route priority will need to be configured manually"
fi

print_header "Network Setup Complete"
print_success "Network configuration completed"
print_info ""
print_info "Dual Network Configuration:"
print_info "  • Ethernet (eth0): Local DMX/Art-Net network"
print_info "  • WiFi (wlan0): Internet access (when configured)"
print_info ""
print_info "Network Status:"
nmcli device status
