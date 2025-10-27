#!/bin/bash

# LacyLights Database Setup
# Creates SQLite database directory and configuration

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

print_header "LacyLights Database Setup"

# Note: Directory creation happens in Step 7 (Downloading Releases)
# This step just validates prerequisites

print_info "Validating database prerequisites..."

# Check if sqlite3 is available (optional, but useful for troubleshooting)
if ! command -v sqlite3 &> /dev/null; then
    print_info "Note: sqlite3 command not found (not required, but useful for database inspection)"
else
    SQLITE_VERSION=$(sqlite3 --version | awk '{print $1}')
    print_success "sqlite3 available: version $SQLITE_VERSION"
fi

print_success "Database prerequisites validated"
print_info ""
print_info "Database configuration:"
print_info "  - Type: SQLite"
print_info "  - Location: /opt/lacylights/backend/prisma/dev.db"
print_info "  - Will be created during migrations in Step 9 (Building Projects)"
