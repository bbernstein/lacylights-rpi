#!/bin/bash

# LacyLights WiFi Mode Check Script
# Runs at boot to determine if AP mode should be activated
#
# Logic:
# 1. If Ethernet is connected, stay in client mode (user can manually enable AP)
# 2. If WiFi is connected to known network, stay in client mode
# 3. If no network connection after timeout, start AP mode
#
# Environment:
#   WIFI_CHECK_TIMEOUT - Seconds to wait for WiFi connection (default: 30)
#   WIFI_INTERFACE - WiFi interface name (default: wlan0)

set -e

# Configuration
WIFI_CHECK_TIMEOUT="${WIFI_CHECK_TIMEOUT:-30}"
WIFI_INTERFACE="${WIFI_INTERFACE:-wlan0}"
GRAPHQL_ENDPOINT="${GRAPHQL_ENDPOINT:-http://localhost:4000/graphql}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[WIFI-MODE]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[WIFI-MODE]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WIFI-MODE]${NC} $1"
}

log_error() {
    echo -e "${RED}[WIFI-MODE]${NC} $1"
}

# Check if Ethernet is connected
check_ethernet() {
    local eth_status
    eth_status=$(nmcli -t -f DEVICE,STATE device status | grep "eth" | grep ":connected" || true)
    if [ -n "$eth_status" ]; then
        return 0
    fi
    return 1
}

# Check if WiFi is connected to a known network
check_wifi_connection() {
    local wifi_status
    wifi_status=$(nmcli -t -f DEVICE,STATE device status | grep "${WIFI_INTERFACE}:connected" || true)
    if [ -n "$wifi_status" ]; then
        return 0
    fi
    return 1
}

# Wait for WiFi connection with timeout
wait_for_wifi() {
    local timeout=$1
    local elapsed=0

    log_info "Waiting for WiFi connection (timeout: ${timeout}s)..."

    while [ $elapsed -lt $timeout ]; do
        if check_wifi_connection; then
            log_success "WiFi connected!"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        log_info "Waiting... ${elapsed}/${timeout}s"
    done

    log_warning "WiFi connection timeout after ${timeout}s"
    return 1
}

# Trigger AP mode via GraphQL
trigger_ap_mode() {
    log_info "Triggering AP mode via GraphQL..."

    local response
    response=$(curl -s -X POST "${GRAPHQL_ENDPOINT}" \
        -H "Content-Type: application/json" \
        -d '{"query":"mutation { startAPMode { success message mode } }"}' 2>/dev/null || echo '{"errors":[{"message":"Connection refused"}]}')

    if echo "$response" | grep -q '"success":true'; then
        log_success "AP mode started successfully"
        local ssid
        ssid=$(echo "$response" | grep -o '"ssid":"[^"]*"' | cut -d'"' -f4 || echo "lacylights")
        log_info "Connect to SSID: $ssid"
        log_info "Open browser to: http://192.168.4.1"
        return 0
    else
        log_error "Failed to start AP mode"
        log_error "Response: $response"
        return 1
    fi
}

# Main logic
main() {
    log_info "LacyLights WiFi Mode Check starting..."
    log_info "Interface: ${WIFI_INTERFACE}"

    # Check 1: Ethernet connected?
    if check_ethernet; then
        log_success "Ethernet is connected - staying in client mode"
        log_info "User can manually enable AP mode via settings if needed"
        exit 0
    fi

    # Check 2: Already connected to WiFi?
    if check_wifi_connection; then
        log_success "WiFi is already connected - staying in client mode"
        exit 0
    fi

    # Check 3: Wait for WiFi connection
    if wait_for_wifi "$WIFI_CHECK_TIMEOUT"; then
        log_success "WiFi connected successfully - staying in client mode"
        exit 0
    fi

    # No connection after timeout - start AP mode
    log_warning "No network connection detected"
    log_info "Starting AP mode for configuration..."

    # Wait a bit for backend service to be ready
    sleep 5

    if trigger_ap_mode; then
        exit 0
    else
        log_error "Failed to start AP mode - please check backend service"
        exit 1
    fi
}

# Run main function
main "$@"
