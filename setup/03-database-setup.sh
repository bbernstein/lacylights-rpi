#!/bin/bash

# LacyLights Database Setup
# Creates PostgreSQL database and user

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

# Start PostgreSQL
print_info "Starting PostgreSQL..."
sudo systemctl start postgresql
sudo systemctl enable postgresql
print_success "PostgreSQL started"

# Generate random password for database user
DB_PASSWORD=$(openssl rand -base64 32)

# Check if user exists
print_info "Checking if lacylights user exists..."
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='lacylights'" | grep -q 1; then
    print_info "User lacylights already exists"
    print_info "Updating password..."
    sudo -u postgres psql -c "ALTER USER lacylights WITH PASSWORD '$DB_PASSWORD';"
else
    print_info "Creating database user: lacylights"
    sudo -u postgres psql -c "CREATE USER lacylights WITH PASSWORD '$DB_PASSWORD';"
    print_success "User created"
fi

# Check if database exists
print_info "Checking if lacylights database exists..."
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='lacylights'" | grep -q 1; then
    print_success "Database lacylights already exists"
else
    print_info "Creating database: lacylights"
    sudo -u postgres psql -c "CREATE DATABASE lacylights OWNER lacylights;"
    print_success "Database created"
fi

# Grant privileges
print_info "Granting privileges..."
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE lacylights TO lacylights;"
print_success "Privileges granted"

# Save connection string
print_info "Saving database connection string..."
mkdir -p /tmp/lacylights-setup
cat > /tmp/lacylights-setup/database.env << EOF
# Database connection string
# Add this to /opt/lacylights/backend/.env
DATABASE_URL="postgresql://lacylights:${DB_PASSWORD}@localhost:5432/lacylights"
EOF

print_success "Database setup complete"
print_info ""
print_info "Database connection string saved to: /tmp/lacylights-setup/database.env"
print_info "This will be copied to /opt/lacylights/backend/.env during service installation"
