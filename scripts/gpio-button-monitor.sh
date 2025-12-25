#!/bin/bash

# LacyLights GPIO Button Monitor
# Monitors a GPIO pin for button press to trigger AP mode
#
# Hardware Setup:
#   - Connect a momentary button between GPIO pin and GND
#   - Button press pulls pin LOW (internal pull-up is used)
#
# Usage:
#   Hold button for 5 seconds to force AP mode
#
# Environment:
#   GPIO_PIN - GPIO pin number to monitor (default: 17)
#   HOLD_TIME - Seconds to hold button to trigger AP mode (default: 5)
#   GRAPHQL_ENDPOINT - Backend GraphQL endpoint

# Configuration
GPIO_PIN="${GPIO_PIN:-17}"
HOLD_TIME="${HOLD_TIME:-5}"
GRAPHQL_ENDPOINT="${GRAPHQL_ENDPOINT:-http://localhost:4000/graphql}"
GPIO_CHIP="${GPIO_CHIP:-gpiochip0}"

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[GPIO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[GPIO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warning() {
    echo -e "${YELLOW}[GPIO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[GPIO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# Check if gpiod tools are available
check_gpiod() {
    if ! command -v gpioget &> /dev/null; then
        log_error "gpiod tools not installed. Run: sudo apt install gpiod"
        exit 1
    fi
}

# Read GPIO pin value (returns 0 for pressed, 1 for released)
read_gpio() {
    gpioget --bias=pull-up "${GPIO_CHIP}" "${GPIO_PIN}" 2>/dev/null || echo "1"
}

# Trigger AP mode via GraphQL
trigger_ap_mode() {
    log_info "Button held for ${HOLD_TIME}s - triggering AP mode..."

    local response
    response=$(curl -s --max-time 5 -X POST "${GRAPHQL_ENDPOINT}" \
        -H "Content-Type: application/json" \
        -d '{"query":"mutation { startAPMode { success message mode } }"}' 2>/dev/null || echo '{"errors":[{"message":"Connection refused"}]}')

    if echo "$response" | grep -q '"success":true'; then
        log_success "AP mode started successfully!"
        return 0
    else
        log_error "Failed to start AP mode: $response"
        return 1
    fi
}

# Main monitoring loop
main() {
    log_info "LacyLights GPIO Button Monitor starting..."
    log_info "Monitoring GPIO${GPIO_PIN} for ${HOLD_TIME}s hold"

    check_gpiod

    local press_start=0
    local was_pressed=false

    while true; do
        local value
        value=$(read_gpio)

        if [ "$value" = "0" ]; then
            # Button is pressed (pulled LOW)
            if [ "$was_pressed" = false ]; then
                # Button just pressed
                press_start=$(date +%s)
                was_pressed=true
                log_info "Button pressed..."
            else
                # Check if held long enough
                local now
                now=$(date +%s)
                local held_time=$((now - press_start))

                if [ $held_time -ge $HOLD_TIME ]; then
                    log_success "Button held for ${HOLD_TIME}s!"
                    trigger_ap_mode

                    # Wait for button release before continuing
                    while [ "$(read_gpio)" = "0" ]; do
                        sleep 0.1
                    done

                    was_pressed=false
                    log_info "Button released, resuming monitoring..."
                fi
            fi
        else
            # Button is released
            if [ "$was_pressed" = true ]; then
                log_info "Button released (held for $(($(date +%s) - press_start))s)"
                was_pressed=false
            fi
        fi

        sleep 0.1
    done
}

# Handle signals for clean shutdown
cleanup() {
    log_info "Shutting down GPIO monitor..."
    exit 0
}

trap cleanup SIGTERM SIGINT

# Run main function
main "$@"
