#!/bin/bash

# LacyLights Log Viewer
# Easy access to service logs with filtering options

# Colors for output
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Parse command line arguments
MODE="follow"
LINES=50
PRIORITY="info"
SINCE=""

show_help() {
    cat << EOF
LacyLights Log Viewer

Usage: $0 [options]

Options:
  -f, --follow           Follow logs in real-time (default)
  -n, --lines N          Show last N lines (default: 50)
  -p, --priority LEVEL   Filter by priority: debug, info, warn, err (default: info)
  -s, --since TIME       Show logs since time (e.g., "1 hour ago", "2023-01-01")
  -a, --all              Show all logs (no follow)
  -e, --errors           Show only errors
  -w, --warnings         Show warnings and errors
  -h, --help             Show this help message

Examples:
  $0                           # Follow logs in real-time
  $0 -n 100                    # Show last 100 lines
  $0 -e                        # Show only errors
  $0 -s "1 hour ago"           # Show logs from last hour
  $0 -a -p err                 # Show all error logs

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            MODE="follow"
            shift
            ;;
        -a|--all)
            MODE="all"
            shift
            ;;
        -n|--lines)
            LINES="$2"
            shift 2
            ;;
        -p|--priority)
            PRIORITY="$2"
            shift 2
            ;;
        -s|--since)
            SINCE="$2"
            shift 2
            ;;
        -e|--errors)
            PRIORITY="err"
            MODE="all"
            shift
            ;;
        -w|--warnings)
            PRIORITY="warning"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_header "LacyLights Logs"

# Build journalctl command
CMD="sudo journalctl -u lacylights"

# Add priority filter
if [ -n "$PRIORITY" ]; then
    case $PRIORITY in
        debug)
            CMD="$CMD -p debug"
            print_info "Priority: Debug and above"
            ;;
        info)
            CMD="$CMD -p info"
            print_info "Priority: Info and above"
            ;;
        warn|warning)
            CMD="$CMD -p warning"
            print_info "Priority: Warning and errors"
            ;;
        err|error)
            CMD="$CMD -p err"
            print_info "Priority: Errors only"
            ;;
    esac
fi

# Add time filter
if [ -n "$SINCE" ]; then
    CMD="$CMD --since '$SINCE'"
    print_info "Since: $SINCE"
fi

# Add mode
if [ "$MODE" == "follow" ]; then
    CMD="$CMD -f"
    print_info "Mode: Following logs (Ctrl+C to exit)"
else
    CMD="$CMD -n $LINES"
    print_info "Mode: Showing last $LINES lines"
fi

echo ""

# Execute command
eval $CMD
