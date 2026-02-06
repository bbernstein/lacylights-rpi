#!/bin/bash

# LacyLights Go Backend Service Installation
# Installs and configures systemd service for Go backend

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

# Function to configure device authentication
configure_device_auth() {
    local env_file="$1"

    print_header "Device Authentication Configuration"
    print_info ""
    print_info "LacyLights supports two operating modes:"
    print_info ""
    print_info "  ${GREEN}No Authentication (default)${NC}"
    print_info "    - All clients on the network have full access"
    print_info "    - Best for isolated networks and single-user setups"
    print_info ""
    print_info "  ${YELLOW}Device Authentication${NC}"
    print_info "    - Devices must register and be approved by admin"
    print_info "    - Best for shared networks or multi-user environments"
    print_info ""

    # Check if running interactively
    if [ -t 0 ]; then
        read -p "Enable device authentication? (y/N): " -n 1 -r ENABLE_AUTH
        echo
    else
        print_info "Non-interactive mode - using default (no authentication)"
        print_info "To enable authentication in non-interactive mode, manually edit $env_file"
        ENABLE_AUTH="n"
    fi

    if [[ $ENABLE_AUTH =~ ^[Yy]$ ]]; then
        print_info "Configuring device authentication..."

        # Generate secure JWT secret
        print_info "Generating secure JWT secret..."

        # Ensure openssl is available for JWT secret generation
        if ! command -v openssl > /dev/null 2>&1; then
            print_error "openssl is required for JWT secret generation but was not found"
            print_info "Please install openssl (e.g., sudo apt-get install openssl) and re-run this script."
            exit 1
        fi

        JWT_SECRET=$(openssl rand -base64 32)

        # Prompt for admin email
        local DEFAULT_EMAIL="admin@lacylights.local"
        if [ -t 0 ]; then
            read -r -p "Admin email (default: $DEFAULT_EMAIL): " ADMIN_EMAIL
        else
            ADMIN_EMAIL=""
        fi
        ADMIN_EMAIL="${ADMIN_EMAIL:-$DEFAULT_EMAIL}"

        # Prompt for admin password with validation
        local PASSWORD_VALID=false
        local ADMIN_PASSWORD=""

        if [ -t 0 ]; then
            while [ "$PASSWORD_VALID" = false ]; do
                read -r -sp "Admin password (minimum 8 characters): " ADMIN_PASSWORD
                echo

                if [ ${#ADMIN_PASSWORD} -lt 8 ]; then
                    print_error "Password must be at least 8 characters long"
                    continue
                fi

                read -r -sp "Confirm password: " ADMIN_PASSWORD_CONFIRM
                echo

                if [ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]; then
                    print_error "Passwords do not match"
                    continue
                fi

                PASSWORD_VALID=true
            done
        else
            # Non-interactive mode: cannot set password, so disable authentication
            print_warning "Non-interactive mode - cannot set admin password interactively"
            print_warning "Disabling authentication to prevent unusable admin account"
            print_warning "To enable authentication later, manually edit $env_file"
            print_info "Device authentication disabled (non-interactive mode)"
            print_info "All clients on the network will have full access"
            return 0
        fi

        # Update .env file with authentication settings
        print_info "Updating environment configuration..."

        # Function to safely update or add a config value
        # Uses delete-and-append approach to handle special characters safely
        update_env_value() {
            local key="$1"
            local value="$2"
            local file="$3"

            # Remove any existing line (commented or not) for this key
            sudo sed -i "/^#\? *${key}=/d" "$file"
            # Append the new value using printf for proper special character handling
            printf '%s=%s\n' "${key}" "${value}" | sudo tee -a "$file" > /dev/null
        }

        # Update authentication settings in the .env file
        sudo sed -i "s/^AUTH_ENABLED=false/AUTH_ENABLED=true/" "$env_file"
        update_env_value "DEVICE_AUTH_ENABLED" "true" "$env_file"

        # Update JWT_SECRET (base64 may contain +, /, = but not |)
        update_env_value "JWT_SECRET" "$JWT_SECRET" "$env_file"

        # Update admin email
        update_env_value "DEFAULT_ADMIN_EMAIL" "$ADMIN_EMAIL" "$env_file"

        # Update admin password (only if set)
        # Note: Password is stored in plaintext; the backend hashes it on first use
        if [ -n "$ADMIN_PASSWORD" ]; then
            update_env_value "DEFAULT_ADMIN_PASSWORD" "$ADMIN_PASSWORD" "$env_file"
        fi

        print_success "Device authentication enabled"
        print_info "Admin email: $ADMIN_EMAIL"
        print_info ""
        print_warning "SECURITY NOTE: The admin password is stored in plaintext in $env_file"
        print_warning "Ensure file permissions are set to 600 (only readable by lacylights user)"
        print_info ""
        print_info "After the service starts:"
        print_info "  1. New devices will need to register"
        print_info "  2. Admin must approve devices via the web interface"
        print_info "  3. Approved devices can access the system automatically"
    else
        print_info "Device authentication disabled (default)"
        print_info "All clients on the network will have full access"
    fi
}

print_header "LacyLights Service Installation"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Install backend systemd service file
print_info "Installing Go backend systemd service file..."

if [ -f "$REPO_DIR/systemd/lacylights.service" ]; then
    sudo cp "$REPO_DIR/systemd/lacylights.service" /etc/systemd/system/lacylights.service
    sudo chmod 644 /etc/systemd/system/lacylights.service
    print_success "Go backend service file installed"
else
    print_error "Service file not found at $REPO_DIR/systemd/lacylights.service"
    exit 1
fi

# Install frontend systemd service file
print_info "Installing frontend systemd service file..."

if [ -f "$REPO_DIR/systemd/lacylights-frontend.service" ]; then
    sudo cp "$REPO_DIR/systemd/lacylights-frontend.service" /etc/systemd/system/lacylights-frontend.service
    sudo chmod 644 /etc/systemd/system/lacylights-frontend.service
    print_success "Frontend service file installed"
else
    print_error "Frontend service file not found at $REPO_DIR/systemd/lacylights-frontend.service"
    exit 1
fi

# Create .env file from template if it doesn't exist
print_info "Setting up environment configuration..."

ENV_FILE_CREATED=false
if [ ! -f /opt/lacylights/backend/.env ]; then
    if [ -f "$REPO_DIR/config/.env.example" ]; then
        sudo cp "$REPO_DIR/config/.env.example" /opt/lacylights/backend/.env

        # Update with database connection string if available
        if [ -f /tmp/lacylights-setup/database.env ]; then
            print_info "Adding database connection string..."
            sudo bash -c "cat /tmp/lacylights-setup/database.env >> /opt/lacylights/backend/.env"
        fi

        sudo chown lacylights:lacylights /opt/lacylights/backend/.env
        sudo chmod 600 /opt/lacylights/backend/.env
        print_success "Environment file created"
        ENV_FILE_CREATED=true
    else
        print_error "Environment template not found"
        exit 1
    fi
else
    print_success "Environment file already exists"
fi

# Configure device authentication (only for new installations)
if [ "$ENV_FILE_CREATED" = true ]; then
    configure_device_auth "/opt/lacylights/backend/.env"
    # Ensure correct ownership after auth configuration
    sudo chown lacylights:lacylights /opt/lacylights/backend/.env
    sudo chmod 600 /opt/lacylights/backend/.env
fi

# Reload systemd
print_info "Reloading systemd daemon..."
sudo systemctl daemon-reload
print_success "Systemd reloaded"

# Enable services
print_info "Enabling LacyLights services..."
sudo systemctl enable lacylights
sudo systemctl enable lacylights-frontend
print_success "Services enabled"

print_header "Service Installation Complete"
print_success "LacyLights backend and frontend services installed and enabled"
print_info ""
print_info "Useful commands:"
print_info "  sudo systemctl start lacylights lacylights-frontend  - Start services"
print_info "  sudo systemctl status lacylights lacylights-frontend - Check status"
print_info "  sudo systemctl stop lacylights lacylights-frontend   - Stop services"
print_info "  sudo journalctl -u lacylights -f                     - View backend logs"
print_info "  sudo journalctl -u lacylights-frontend -f            - View frontend logs"
