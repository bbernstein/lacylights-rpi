#!/bin/bash

# LacyLights WiFi Diagnostic Tool
# Comprehensive WiFi troubleshooting and diagnostics

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
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

ISSUES=0

print_header "LacyLights WiFi Diagnostic"

# Check if NetworkManager is installed
print_header "NetworkManager Status"

if ! command -v nmcli &> /dev/null; then
    print_error "NetworkManager (nmcli) is not installed"
    print_info "Install with: sudo apt-get install network-manager"
    exit 1
fi

print_success "NetworkManager is installed: $(nmcli --version | head -n1)"

# Check if NetworkManager service is running
if systemctl is-active --quiet NetworkManager; then
    print_success "NetworkManager service is running"
else
    print_error "NetworkManager service is not running"
    print_info "Start with: sudo systemctl start NetworkManager"
    ISSUES=$((ISSUES + 1))
fi

# Check WiFi device
print_header "WiFi Device Status"

if ! nmcli device status | grep -q "wifi"; then
    print_error "No WiFi device found"
    print_info "This Raspberry Pi may not have WiFi capability"
    exit 1
fi

WIFI_DEVICE=$(nmcli device status | grep wifi | awk '{print $1}' | head -n 1)
WIFI_STATE=$(nmcli device status | grep "$WIFI_DEVICE" | awk '{print $3}')

print_success "WiFi device found: $WIFI_DEVICE"
print_info "Device state: $WIFI_STATE"

# Check if WiFi device is managed
if nmcli device show "$WIFI_DEVICE" | grep -q "GENERAL.STATE.*unmanaged"; then
    print_warning "WiFi device is unmanaged"
    print_info "Set to managed with: sudo nmcli device set $WIFI_DEVICE managed yes"
    ISSUES=$((ISSUES + 1))
fi

# Check WiFi radio
print_header "WiFi Radio Status"

WIFI_RADIO=$(nmcli radio wifi)
if [ "$WIFI_RADIO" == "enabled" ]; then
    print_success "WiFi radio is enabled"
else
    print_error "WiFi radio is disabled"
    print_info "Enable with: sudo nmcli radio wifi on"
    ISSUES=$((ISSUES + 1))
fi

# Check current connection
print_header "WiFi Connection Status"

if nmcli device status | grep "$WIFI_DEVICE" | grep -q "connected"; then
    SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)
    SIGNAL=$(nmcli -t -f active,signal dev wifi | grep '^yes' | cut -d':' -f2)
    SECURITY=$(nmcli -t -f active,security dev wifi | grep '^yes' | cut -d':' -f2)

    print_success "Connected to: $SSID"
    print_info "Signal strength: ${SIGNAL}%"
    print_info "Security: $SECURITY"

    # Show connection details
    CONNECTION_NAME=$(nmcli -t -f device,name connection show --active | grep "^$WIFI_DEVICE:" | cut -d':' -f2)
    if [ -n "$CONNECTION_NAME" ]; then
        print_info "Connection profile: $CONNECTION_NAME"

        # Get IP address
        IP_ADDRESS=$(nmcli -t -f IP4.ADDRESS connection show "$CONNECTION_NAME" | cut -d':' -f2 | cut -d'/' -f1)
        if [ -n "$IP_ADDRESS" ]; then
            print_success "IP address: $IP_ADDRESS"
        fi

        # Get gateway
        GATEWAY=$(nmcli -t -f IP4.GATEWAY connection show "$CONNECTION_NAME" | cut -d':' -f2)
        if [ -n "$GATEWAY" ]; then
            print_info "Gateway: $GATEWAY"

            # Test gateway connectivity
            if ping -c 1 -W 2 "$GATEWAY" &> /dev/null; then
                print_success "Can reach gateway"
            else
                print_error "Cannot reach gateway"
                ISSUES=$((ISSUES + 1))
            fi
        fi

        # Get DNS
        DNS=$(nmcli -t -f IP4.DNS connection show "$CONNECTION_NAME" | cut -d':' -f2)
        if [ -n "$DNS" ]; then
            print_info "DNS servers: $DNS"

            # Test DNS
            if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
                print_success "Can reach external DNS (8.8.8.8)"
            else
                print_error "Cannot reach external DNS"
                ISSUES=$((ISSUES + 1))
            fi

            # Test DNS resolution
            if nslookup google.com &> /dev/null; then
                print_success "DNS resolution working"
            else
                print_error "DNS resolution failing"
                ISSUES=$((ISSUES + 1))
            fi
        fi
    fi
else
    print_warning "Not connected to any WiFi network"
    print_info "WiFi device state: $WIFI_STATE"
fi

# Check available networks
print_header "Available Networks"

print_info "Scanning for available networks..."
NETWORK_COUNT=$(nmcli -t -f SSID device wifi list | wc -l)

if [ "$NETWORK_COUNT" -gt 0 ]; then
    print_success "Found $NETWORK_COUNT networks"
    print_info ""
    nmcli device wifi list | head -n 11
else
    print_warning "No networks found"
    print_info "Try rescanning: sudo nmcli device wifi rescan"
fi

# Check saved connections
print_header "Saved Connections"

SAVED_WIFI=$(nmcli -t -f TYPE,NAME connection show | grep "^802-11-wireless:" | cut -d':' -f2)

if [ -n "$SAVED_WIFI" ]; then
    print_info "Saved WiFi connections:"
    echo "$SAVED_WIFI" | while read -r conn; do
        echo "  - $conn"
    done
else
    print_info "No saved WiFi connections"
fi

# Check permissions
print_header "Permissions Check"

# Check if lacylights user exists
if id "lacylights" &>/dev/null; then
    print_success "User 'lacylights' exists"

    # Check sudoers file
    if [ -f /etc/sudoers.d/lacylights ]; then
        print_success "Sudoers file exists: /etc/sudoers.d/lacylights"

        # Validate sudoers file
        if sudo visudo -c -f /etc/sudoers.d/lacylights &> /dev/null; then
            print_success "Sudoers file is valid"
        else
            print_error "Sudoers file is invalid"
            ISSUES=$((ISSUES + 1))
        fi
    else
        print_error "Sudoers file not found: /etc/sudoers.d/lacylights"
        print_info "WiFi configuration from web UI will not work"
        ISSUES=$((ISSUES + 1))
    fi
else
    print_warning "User 'lacylights' does not exist"
fi

# Check GraphQL API WiFi status
print_header "API WiFi Status"

WIFI_API=$(curl -s -f http://localhost:4000/graphql \
    -H "Content-Type: application/json" \
    -d '{"query": "{ wifiStatus { available enabled connected ssid } }"}' 2>/dev/null)

if [ -n "$WIFI_API" ]; then
    if echo "$WIFI_API" | grep -q "available"; then
        AVAILABLE=$(echo "$WIFI_API" | grep -o '"available":[^,}]*' | cut -d: -f2)
        ENABLED=$(echo "$WIFI_API" | grep -o '"enabled":[^,}]*' | cut -d: -f2)
        CONNECTED=$(echo "$WIFI_API" | grep -o '"connected":[^,}]*' | cut -d: -f2)

        print_info "API WiFi status:"
        print_info "  Available: $AVAILABLE"
        print_info "  Enabled: $ENABLED"
        print_info "  Connected: $CONNECTED"

        if [ "$AVAILABLE" == "true" ]; then
            print_success "WiFi configuration API is available"
        else
            print_warning "WiFi configuration API reports WiFi not available"
            ISSUES=$((ISSUES + 1))
        fi
    else
        print_error "Could not parse WiFi status from API"
        ISSUES=$((ISSUES + 1))
    fi
else
    print_error "Could not reach GraphQL API"
    print_info "Make sure LacyLights service is running"
    ISSUES=$((ISSUES + 1))
fi

# Summary
print_header "Diagnostic Summary"

if [ $ISSUES -eq 0 ]; then
    print_success "No WiFi issues detected! 🎉"
    exit 0
else
    print_warning "Found $ISSUES potential issue(s)"
    print_info ""
    print_info "Common fixes:"
    print_info "  Enable WiFi: sudo nmcli radio wifi on"
    print_info "  Rescan networks: sudo nmcli device wifi rescan"
    print_info "  Restart NetworkManager: sudo systemctl restart NetworkManager"
    print_info "  Check service logs: sudo journalctl -u lacylights -n 50"
    exit 1
fi
