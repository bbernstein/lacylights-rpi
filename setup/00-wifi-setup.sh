#!/bin/bash

# LacyLights WiFi Setup Helper
# Configures WiFi to enable internet access during setup
# This runs BEFORE system package installation

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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Parse arguments
WIFI_SSID="$1"
WIFI_PASSWORD="$2"
SKIP_PROMPT="${3:-false}"

print_header "LacyLights WiFi Setup"

# Check if WiFi device exists
print_info "Checking for WiFi device..."
if ! command -v nmcli &> /dev/null; then
    print_error "NetworkManager (nmcli) not found"
    print_error "WiFi configuration requires NetworkManager"
    print_info "Install it with: sudo apt-get install network-manager"
    exit 1
fi

WIFI_DEVICE=$(nmcli device status | grep wifi | awk '{print $1}' | head -n 1)

if [ -z "$WIFI_DEVICE" ]; then
    print_error "No WiFi device found"
    print_info "This Raspberry Pi may not have WiFi capability"
    exit 1
fi

print_success "WiFi device found: $WIFI_DEVICE"

# Enable WiFi radio
print_info "Enabling WiFi radio..."
sudo nmcli radio wifi on
print_success "WiFi radio enabled"

# Wait for WiFi radio to fully initialize
print_info "Waiting for WiFi radio to initialize..."
sleep 3

# Check current connectivity
print_info "Checking current internet connectivity..."
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    print_success "Already connected to internet"

    # Show current connection
    CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
    if [ -n "$CURRENT_SSID" ]; then
        print_info "Currently connected to: $CURRENT_SSID"
    fi

    if [ "$SKIP_PROMPT" = "true" ]; then
        exit 0
    fi

    read -p "WiFi is already working. Reconfigure anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Keeping current WiFi configuration"
        exit 0
    fi
fi

# Get WiFi credentials if not provided
WIFI_SECURITY_TYPE=""
if [ -z "$WIFI_SSID" ]; then
    # Check WiFi device state
    WIFI_STATE=$(nmcli -t -f DEVICE,STATE device | grep "^$WIFI_DEVICE:" | cut -d: -f2)
    print_info "WiFi device state: $WIFI_STATE"

    print_info "Scanning for available networks..."
    sudo nmcli device wifi rescan || true

    # Wait longer for scan to complete and results to populate
    print_info "Waiting for scan to complete..."
    sleep 5

    echo ""
    echo "Available WiFi networks:"
    echo "------------------------"

    # Get list of SSIDs and store in array with security info
    # Deduplicate by SSID (keep strongest signal for each unique SSID)
    mapfile -t SSID_LIST < <(nmcli -t -f SSID,SIGNAL,SECURITY device wifi list | \
        grep -v '^:' | \
        sort -t: -k1,1 -k2,2rn | \
        awk -F: '!seen[$1]++' | \
        sort -t: -k2,2rn | \
        head -n 15)

    if [ ${#SSID_LIST[@]} -eq 0 ]; then
        print_warning "No WiFi networks found after scan"
        print_info "Checking WiFi device status..."
        nmcli device show "$WIFI_DEVICE" | grep -E "GENERAL.STATE|GENERAL.REASON"

        print_info "Trying one more scan..."
        sudo nmcli device wifi rescan 2>/dev/null || true
        sleep 5
        # Deduplicate by SSID (keep strongest signal for each unique SSID)
        mapfile -t SSID_LIST < <(nmcli -t -f SSID,SIGNAL,SECURITY device wifi list | \
            grep -v '^:' | \
            sort -t: -k1,1 -k2,2rn | \
            awk -F: '!seen[$1]++' | \
            sort -t: -k2,2rn | \
            head -n 15)
    fi

    if [ ${#SSID_LIST[@]} -eq 0 ]; then
        print_warning "Still no WiFi networks found"
        print_info "Raw scan output for debugging:"
        nmcli device wifi list | head -20
        echo ""
        read -p "Enter WiFi SSID manually: " WIFI_SSID

        if [ -z "$WIFI_SSID" ]; then
            print_error "SSID cannot be empty"
            exit 1
        fi
    else
        # Display networks with numbers
        i=1
        declare -A SSID_MAP
        declare -A SECURITY_MAP
        for network in "${SSID_LIST[@]}"; do
            SSID=$(echo "$network" | cut -d: -f1)
            SIGNAL=$(echo "$network" | cut -d: -f2)
            SECURITY=$(echo "$network" | cut -d: -f3)

            # Skip empty SSIDs
            if [ -z "$SSID" ]; then
                continue
            fi

            # Format security info
            if [ -z "$SECURITY" ]; then
                SEC_INFO="Open"
            else
                SEC_INFO="Secured"
            fi

            # Store SSID and security in maps
            SSID_MAP[$i]="$SSID"
            SECURITY_MAP[$i]="$SECURITY"

            # Display with signal strength bars
            BARS=""
            if [ "$SIGNAL" -gt 75 ]; then
                BARS="▂▄▆█"
            elif [ "$SIGNAL" -gt 50 ]; then
                BARS="▂▄▆_"
            elif [ "$SIGNAL" -gt 25 ]; then
                BARS="▂▄__"
            else
                BARS="▂___"
            fi

            printf "%2d) %-32s %s %s\n" "$i" "$SSID" "$BARS" "$SEC_INFO"
            ((i++))
        done

        echo ""
        echo "Select a network by number, or press 'c' to enter custom SSID"
        echo ""
        read -p "Choice (1-$((i-1)) or 'c'): " NETWORK_CHOICE

        if [ "$NETWORK_CHOICE" = "c" ] || [ "$NETWORK_CHOICE" = "C" ]; then
            read -p "Enter WiFi SSID: " WIFI_SSID

            if [ -z "$WIFI_SSID" ]; then
                print_error "SSID cannot be empty"
                exit 1
            fi
        elif [[ "$NETWORK_CHOICE" =~ ^[0-9]+$ ]] && [ "$NETWORK_CHOICE" -ge 1 ] && [ "$NETWORK_CHOICE" -lt "$i" ]; then
            WIFI_SSID="${SSID_MAP[$NETWORK_CHOICE]}"
            WIFI_SECURITY_TYPE="${SECURITY_MAP[$NETWORK_CHOICE]}"
            print_info "Selected: $WIFI_SSID"
        else
            print_error "Invalid choice"
            exit 1
        fi
    fi
fi

if [ -z "$WIFI_PASSWORD" ]; then
    read -s -p "Enter WiFi password (hidden): " WIFI_PASSWORD
    echo

    if [ -z "$WIFI_PASSWORD" ]; then
        print_warning "Empty password - connecting to open network"
    fi
fi

# Connect to WiFi
print_info "Connecting to WiFi network: $WIFI_SSID"

# Remove existing connection with same SSID if it exists
if nmcli connection show "$WIFI_SSID" &> /dev/null; then
    print_info "Removing existing connection profile..."
    sudo nmcli connection delete "$WIFI_SSID" || true
fi

# Determine if this is an open or secured network
IS_OPEN=false
if [ -z "$WIFI_PASSWORD" ]; then
    IS_OPEN=true
fi

# Create connection using nmcli connection add for better control
CONNECTION_NAME="$WIFI_SSID"
CONNECT_SUCCESS=false

if [ "$IS_OPEN" = true ]; then
    # Open network (no password)
    print_info "Connecting to open network..."
    # Set route metrics during creation for high priority internet routing
    # Lower metric = higher priority: metric 50 gives WiFi higher priority than Ethernet (typically metric 100)
    if sudo nmcli connection add type wifi con-name "$CONNECTION_NAME" ifname "$WIFI_DEVICE" ssid "$WIFI_SSID" \
            ipv4.route-metric 50 ipv6.route-metric 50 && \
       sudo nmcli connection up "$CONNECTION_NAME"; then
        CONNECT_SUCCESS=true
        print_success "Connected to $WIFI_SSID (open network)"
    fi
else
    # Secured network - use WPA/WPA2
    print_info "Connecting to secured network..."

    # Set key management to WPA-PSK (default for most modern networks)
    KEY_MGMT="wpa-psk"

    # Create the connection with explicit security settings AND route metrics
    # Setting metrics during creation ensures they're active immediately
    # Lower metric = higher priority: metric 50 gives WiFi higher priority than Ethernet (typically metric 100)
    if sudo nmcli connection add type wifi con-name "$CONNECTION_NAME" ifname "$WIFI_DEVICE" ssid "$WIFI_SSID" \
            wifi-sec.key-mgmt "$KEY_MGMT" wifi-sec.psk "$WIFI_PASSWORD" \
            ipv4.route-metric 50 ipv6.route-metric 50; then

        print_info "Connection profile created with high-priority routing, activating..."

        # Try to bring up the connection
        if sudo nmcli connection up "$CONNECTION_NAME" 2>&1; then
            CONNECT_SUCCESS=true
            print_success "Connected to $WIFI_SSID"
        else
            print_warning "First connection attempt failed, retrying..."
            sleep 2

            # Sometimes it takes a moment, try once more
            if sudo nmcli connection up "$CONNECTION_NAME" 2>&1; then
                CONNECT_SUCCESS=true
                print_success "Connected to $WIFI_SSID"
            fi
        fi
    fi
fi

if [ "$CONNECT_SUCCESS" = false ]; then
    print_error "Failed to connect to WiFi"
    print_error "Please check your SSID and password"

    # Clean up failed connection
    sudo nmcli connection delete "$CONNECTION_NAME" 2>/dev/null || true
    exit 1
fi

print_success "WiFi configured with high priority for internet routing"

# Wait for DHCP lease and IP address assignment
print_info "Waiting for IP address assignment..."

# Wait up to 15 seconds for an IP address
MAX_WAIT=15
WAITED=0
HAS_IP=false

while [ $WAITED -lt $MAX_WAIT ]; do
    # Check if we have an IP address
    IP_ADDR=$(ip addr show dev "$WIFI_DEVICE" | grep "inet " | awk '{print $2}' | cut -d/ -f1)

    if [ -n "$IP_ADDR" ] && [[ "$IP_ADDR" != 169.254.* ]]; then
        HAS_IP=true
        print_success "[OK] IP address assigned: $IP_ADDR"
        break
    fi

    sleep 1
    ((WAITED++))
done

if [ "$HAS_IP" = false ]; then
    print_error "[FAIL] Failed to obtain IP address"
    print_error "DHCP may not be working on this network"
    exit 1
fi

# Wait a bit more for routing table to be updated
print_info "Waiting for routing to establish..."
sleep 3

# Check if we have a default route via WiFi
print_info "Checking default route..."
if ip route | grep -q "^default.*$WIFI_DEVICE"; then
    print_success "[OK] Default route configured via WiFi"
else
    print_warning "[WARN] No default route via WiFi (may still work via Ethernet)"
fi

# Verify internet connectivity
print_info "Verifying internet connectivity..."

# Try ping to 8.8.8.8 with a reasonable timeout
if ping -c 2 -W 3 8.8.8.8 > /dev/null 2>&1; then
    print_success "[OK] Internet connectivity verified"

    # Test DNS resolution
    sleep 1
    if ping -c 1 -W 5 github.com > /dev/null 2>&1; then
        print_success "[OK] DNS resolution working"
    else
        print_warning "[WARN] DNS resolution may not be working"
    fi
else
    print_error "[FAIL] No internet connectivity"
    print_error "WiFi connected but cannot reach internet"
    print_info ""
    print_info "Diagnostic information:"
    print_info "  IP Address: $IP_ADDR"
    print_info "  WiFi Device: $WIFI_DEVICE"
    print_info ""
    print_info "Trying to diagnose the issue..."

    # Show routing table
    echo ""
    echo "Current routing table:"
    ip route
    echo ""

    # Try to ping gateway
    GATEWAY=$(ip route | grep "^default.*$WIFI_DEVICE" | awk '{print $3}')
    if [ -n "$GATEWAY" ]; then
        print_info "Testing connection to gateway ($GATEWAY)..."
        if ping -c 1 -W 2 "$GATEWAY" > /dev/null 2>&1; then
            print_info "[OK] Can reach gateway - DNS or external routing issue"
        else
            print_error "[FAIL] Cannot reach gateway - WiFi authentication may be required"
        fi
    fi

    print_info ""
    print_info "This may be normal if your network requires:"
    print_info "  - Captive portal authentication (open browser to authenticate)"
    print_info "  - MAC address approval"
    print_info "  - VPN or proxy configuration"
    exit 1
fi

# Show connection details
print_header "WiFi Configuration Complete"
print_success "WiFi successfully configured"
print_info ""
print_info "Connection details:"
nmcli connection show "$WIFI_SSID" | grep -E "ipv4.addresses|ipv4.gateway|ipv4.dns" | head -n 3 || true
print_info ""
print_success "Ready to proceed with system setup"
