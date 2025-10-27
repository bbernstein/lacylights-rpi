#!/bin/bash

# LacyLights Network Diagnostics
# Comprehensive network connectivity troubleshooting

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

print_header "LacyLights Network Diagnostics"

# Check network interfaces
print_header "Network Interfaces"

if command -v ip &> /dev/null; then
    print_info "Available network interfaces:"
    ip addr show | grep -E "^[0-9]+: " | sed 's/^/  /'
    echo ""

    # Check Ethernet
    if ip addr show eth0 2>/dev/null | grep -q "state UP"; then
        ETH_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        print_success "Ethernet (eth0): UP - $ETH_IP"
    else
        print_warning "Ethernet (eth0): DOWN or not configured"
    fi

    # Check WiFi
    if ip addr show wlan0 2>/dev/null | grep -q "inet "; then
        WIFI_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        print_success "WiFi (wlan0): Connected - $WIFI_IP"
    else
        print_warning "WiFi (wlan0): Not connected"
    fi
else
    print_error "ip command not available"
    ISSUES=$((ISSUES + 1))
fi

# Check default gateway
print_header "Gateway & Routing"

if command -v ip &> /dev/null; then
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    if [ -n "$GATEWAY" ]; then
        print_success "Default gateway: $GATEWAY"

        # Try to ping gateway
        if ping -c 1 -W 2 "$GATEWAY" > /dev/null 2>&1; then
            print_success "Gateway is reachable"
        else
            print_error "Cannot ping gateway"
            ISSUES=$((ISSUES + 1))
        fi
    else
        print_error "No default gateway configured"
        ISSUES=$((ISSUES + 1))
    fi
fi

# Check DNS
print_header "DNS Configuration"

if [ -f /etc/resolv.conf ]; then
    print_info "DNS servers configured:"
    grep "^nameserver" /etc/resolv.conf | sed 's/^/  /'

    # Test DNS resolution
    print_info "Testing DNS resolution..."

    # Try ping first (most reliable, always available)
    if ping -c 1 -W 2 github.com > /dev/null 2>&1; then
        # Get IP using getent if available, otherwise just report success
        if command -v getent &> /dev/null; then
            GITHUB_IP=$(getent hosts github.com | awk '{print $1}' | head -1)
            print_success "github.com resolves to $GITHUB_IP"
        else
            print_success "github.com resolves successfully"
        fi
    else
        print_error "Cannot resolve github.com"
        ISSUES=$((ISSUES + 1))

        # Try to understand why
        print_info "Checking if 'host' or 'nslookup' commands are available..."
        if command -v nslookup &> /dev/null; then
            nslookup github.com 8.8.8.8 > /dev/null 2>&1 && \
                print_warning "DNS works with 8.8.8.8 but not with configured DNS" && \
                print_info "Consider adding 'nameserver 8.8.8.8' to /etc/resolv.conf"
        fi
    fi
else
    print_error "/etc/resolv.conf not found"
    ISSUES=$((ISSUES + 1))
fi

# Check internet connectivity
print_header "Internet Connectivity"

# Test with ping
print_info "Testing with ping to 8.8.8.8 (Google DNS)..."
if ping -c 3 -W 2 8.8.8.8 > /dev/null 2>&1; then
    print_success "Can reach internet (8.8.8.8)"
else
    print_error "Cannot reach internet via ping"
    ISSUES=$((ISSUES + 1))
fi

# Test HTTPS to GitHub
print_info "Testing HTTPS connection to github.com..."
if curl -s -m 10 https://github.com > /dev/null 2>&1; then
    print_success "Can connect to github.com via HTTPS"
else
    print_error "Cannot connect to github.com via HTTPS"
    ISSUES=$((ISSUES + 1))

    # Try to get more info
    print_info "Detailed curl output:"
    curl -v -m 10 https://github.com 2>&1 | grep -E "connect|SSL|certificate|error" | sed 's/^/  /' || true
fi

# Check firewall
print_header "Firewall Status"

if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null | grep Status | awk '{print $2}')
    if [ "$UFW_STATUS" == "active" ]; then
        print_info "UFW firewall is active"
        print_info "Allowed services:"
        sudo ufw status | grep ALLOW | sed 's/^/  /'
    else
        print_info "UFW firewall is inactive"
    fi
else
    print_info "UFW not installed (no firewall)"
fi

# Check NetworkManager
print_header "NetworkManager Status"

if command -v nmcli &> /dev/null; then
    print_success "NetworkManager is installed"

    print_info "Connection status:"
    nmcli device status | sed 's/^/  /'

    if nmcli device status | grep -q "wifi.*connected"; then
        print_success "WiFi is managed by NetworkManager"
        WIFI_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)
        print_info "Connected to: $WIFI_SSID"
    fi
else
    print_warning "NetworkManager not installed"
    print_info "WiFi configuration may not be available in web interface"
fi

# Summary
print_header "Summary"

if [ $ISSUES -eq 0 ]; then
    print_success "All network checks passed! 🎉"
    echo ""
    print_info "Network is properly configured for GitHub downloads"
    exit 0
else
    print_warning "Found $ISSUES network issue(s)"
    echo ""
    print_info "Common fixes:"

    if ! ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
        echo "  • No internet: Check Ethernet cable or WiFi connection"
        echo "  • Configure WiFi: Use raspi-config or nmcli"
    fi

    if ! host github.com > /dev/null 2>&1; then
        echo "  • DNS not working: Add 'nameserver 8.8.8.8' to /etc/resolv.conf"
        echo "  • Or use: echo 'nameserver 8.8.8.8' | sudo tee -a /etc/resolv.conf"
    fi

    if ! curl -s -m 10 https://github.com > /dev/null 2>&1; then
        echo "  • HTTPS blocked: Check firewall settings"
        echo "  • Check proxy: Ensure no proxy is blocking GitHub"
    fi

    exit 1
fi
