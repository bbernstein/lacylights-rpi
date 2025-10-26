#!/bin/bash

# LacyLights Network Setup
# Configures NetworkManager and hostname

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

# Set hostname
print_info "Setting hostname to lacylights..."

CURRENT_HOSTNAME=$(hostname)
if [ "$CURRENT_HOSTNAME" == "lacylights" ]; then
    print_success "Hostname already set to lacylights"
else
    sudo hostnamectl set-hostname lacylights

    # Update /etc/hosts
    sudo sed -i "s/$CURRENT_HOSTNAME/lacylights/g" /etc/hosts

    print_success "Hostname changed from $CURRENT_HOSTNAME to lacylights"
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
else
    print_error "No active wired connection found"
    print_info "Please ensure ethernet cable is connected"
fi

print_header "Network Setup Complete"
print_success "Network configuration completed"
print_info ""
print_info "Network Status:"
nmcli device status
