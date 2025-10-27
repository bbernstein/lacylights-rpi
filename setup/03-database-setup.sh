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

# Create database directory
print_info "Creating database directory..."
mkdir -p /opt/lacylights/backend/prisma
print_success "Database directory created"

# Create database URL configuration
print_info "Saving database connection string..."
mkdir -p /tmp/lacylights-setup
cat > /tmp/lacylights-setup/database.env << 'EOF'
# Database connection string for SQLite
# Add this to /opt/lacylights/backend/.env
DATABASE_URL="file:./prisma/lacylights.db"
EOF

print_success "Database setup complete"
print_info ""
print_info "SQLite database will be created at: /opt/lacylights/backend/prisma/lacylights.db"
print_info "Database will be initialized when migrations are run during service installation"
print_info "Connection string saved to: /tmp/lacylights-setup/database.env"
