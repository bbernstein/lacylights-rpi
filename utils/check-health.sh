#!/bin/bash

# LacyLights Health Check
# Comprehensive system health monitoring

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

print_header "LacyLights Health Check"

# Check if running on Pi
if [ -f /proc/device-tree/model ]; then
    MODEL=$(cat /proc/device-tree/model)
    print_info "Device: $MODEL"
else
    print_info "Device: $(uname -s) $(uname -m)"
fi

# System Status
print_header "System Status"

# Check uptime
UPTIME=$(uptime -p)
print_info "Uptime: $UPTIME"

# Check memory
MEMORY=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
print_info "Memory Used: $MEMORY"

# Check disk space
DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')
print_info "Disk Usage: $DISK"

# Check if disk is >90% full
DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_PERCENT" -gt 90 ]; then
    print_warning "Disk usage is high (${DISK_PERCENT}%)"
    ISSUES=$((ISSUES + 1))
fi

# Service Status
print_header "Service Status"

# Check LacyLights service
if systemctl is-active --quiet lacylights; then
    print_success "LacyLights service is running"

    # Check how long it's been running
    SERVICE_START=$(systemctl show -p ActiveEnterTimestamp lacylights | cut -d= -f2)
    print_info "Service started: $SERVICE_START"
else
    print_error "LacyLights service is not running"
    ISSUES=$((ISSUES + 1))
fi

# Check if service is enabled
if systemctl is-enabled --quiet lacylights; then
    print_success "LacyLights service is enabled (auto-start)"
else
    print_warning "LacyLights service is not enabled"
    ISSUES=$((ISSUES + 1))
fi

# Database Status
print_header "Database Status"

DB_FILE="/opt/lacylights/backend/prisma/lacylights.db"

if [ -f "$DB_FILE" ]; then
    print_success "SQLite database exists"

    # Check database size
    DB_SIZE=$(du -h "$DB_FILE" | cut -f1)
    print_info "Database size: $DB_SIZE"

    # Check if database is readable
    if [ -r "$DB_FILE" ]; then
        print_success "Database file is readable"
    else
        print_error "Database file is not readable"
        ISSUES=$((ISSUES + 1))
    fi
else
    print_warning "SQLite database not found (will be created on first run)"
    print_info "Expected location: $DB_FILE"
fi

# Network Status
print_header "Network Status"

# Check wired connection
if ip addr show | grep -q "eth0.*state UP"; then
    ETH_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    print_success "Wired network connected: $ETH_IP"
else
    print_warning "Wired network not connected"
fi

# Check WiFi
if command -v nmcli &> /dev/null; then
    if nmcli device status | grep -q "wifi.*connected"; then
        WIFI_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)
        WIFI_SIGNAL=$(nmcli -t -f active,signal dev wifi | grep '^yes' | cut -d':' -f2)
        print_success "WiFi connected: $WIFI_SSID (Signal: ${WIFI_SIGNAL}%)"
    else
        print_info "WiFi not connected"
    fi
else
    print_info "NetworkManager not available"
fi

# Check hostname
HOSTNAME=$(hostname)
if [ "$HOSTNAME" == "lacylights" ]; then
    print_success "Hostname: lacylights"
else
    print_warning "Hostname is $HOSTNAME (expected: lacylights)"
fi

# Check if hostname resolves
if ping -c 1 -W 2 lacylights.local &> /dev/null; then
    print_success "lacylights.local resolves correctly"
else
    print_warning "lacylights.local does not resolve"
    ISSUES=$((ISSUES + 1))
fi

# API Health
print_header "API Health"

# Check if port 4000 is listening
if netstat -tuln 2>/dev/null | grep -q ":4000 " || ss -tuln 2>/dev/null | grep -q ":4000 "; then
    print_success "GraphQL server is listening on port 4000"

    # Try GraphQL query
    HEALTH_CHECK=$(curl -s -f http://localhost:4000/graphql \
        -H "Content-Type: application/json" \
        -d '{"query": "{ __typename }"}' 2>/dev/null)

    if echo "$HEALTH_CHECK" | grep -q "Query"; then
        print_success "GraphQL endpoint is responding"

        # Check WiFi status
        WIFI_STATUS=$(curl -s -f http://localhost:4000/graphql \
            -H "Content-Type: application/json" \
            -d '{"query": "{ wifiStatus { available enabled connected } }"}' 2>/dev/null)

        if echo "$WIFI_STATUS" | grep -q "available"; then
            AVAILABLE=$(echo "$WIFI_STATUS" | grep -o '"available":[^,}]*' | cut -d: -f2)
            print_info "WiFi configuration available: $AVAILABLE"
        fi
    else
        print_error "GraphQL endpoint not responding correctly"
        print_info "Response: $HEALTH_CHECK"
        ISSUES=$((ISSUES + 1))
    fi
else
    print_error "GraphQL server is not listening on port 4000"
    ISSUES=$((ISSUES + 1))
fi

# Check recent errors
print_header "Recent Errors"

ERROR_COUNT=$(sudo journalctl -u lacylights --since "1 hour ago" -p err | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    print_success "No errors in the last hour"
else
    print_warning "Found $ERROR_COUNT errors in the last hour"
    print_info "View with: sudo journalctl -u lacylights -p err --since '1 hour ago'"
fi

# Summary
print_header "Summary"

if [ $ISSUES -eq 0 ]; then
    print_success "All health checks passed! 🎉"
    exit 0
else
    print_warning "Found $ISSUES issue(s)"
    print_info ""
    print_info "For more details:"
    print_info "  Service logs: sudo journalctl -u lacylights -n 50"
    print_info "  Service status: sudo systemctl status lacylights"
    print_info "  Database logs: sudo journalctl -u postgresql -n 50"
    exit 1
fi
