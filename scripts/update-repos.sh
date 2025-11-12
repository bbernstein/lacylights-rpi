#!/bin/bash

# LacyLights Repository Update Script for Raspberry Pi
# This script manages version updates for all three LacyLights components

set -e  # Exit on error

# Configuration
LACYLIGHTS_ROOT="/opt/lacylights"
REPOS_DIR="$LACYLIGHTS_ROOT/repos"
SCRIPTS_DIR="$LACYLIGHTS_ROOT/scripts"
BACKUP_DIR="$LACYLIGHTS_ROOT/backups"
LOG_FILE="$LACYLIGHTS_ROOT/logs/update.log"

# GitHub organization
GITHUB_ORG="bbernstein"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to print colored output
print_status() {
    echo -e "${BLUE}==>${NC} $1"
    log "INFO: $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
    log "WARNING: $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get the current installed version
get_installed_version() {
    local repo_dir="$1"
    if [ -f "$repo_dir/.lacylights-version" ]; then
        cat "$repo_dir/.lacylights-version"
    else
        echo "unknown"
    fi
}

# Function to get the latest release version from GitHub
get_latest_release_version() {
    local repo="$1"
    local api_url="https://api.github.com/repos/$GITHUB_ORG/$repo/releases/latest"

    if command_exists jq; then
        local response_file=$(mktemp)
        if [ -z "$response_file" ]; then
            echo "unknown"
            return
        fi

        local http_code=$(curl -s -w "%{http_code}" -o "$response_file" "$api_url")

        # Check for 2xx success codes
        if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
            rm -f "$response_file"
            echo "unknown"
            return
        fi

        local version=$(jq -r '.tag_name // empty' "$response_file")
        rm -f "$response_file"

        if [ -z "$version" ] || [ "$version" = "null" ]; then
            echo "unknown"
        else
            echo "$version"
        fi
    else
        # Fallback to grep/cut if jq not available
        local version=$(curl -s "$api_url" | grep '"tag_name"' | cut -d '"' -f 4)
        if [ -z "$version" ]; then
            print_warning "Failed to detect latest version for $repo" >&2
            echo "unknown"
        else
            echo "$version"
        fi
    fi
}

# Function to list all available releases for a repository
list_available_versions() {
    local repo="$1"
    local api_url="https://api.github.com/repos/$GITHUB_ORG/$repo/releases"

    if command_exists jq; then
        local response_file=$(mktemp)
        if [ -z "$response_file" ]; then
            echo "[]"
            return
        fi

        local http_code=$(curl -s -w "%{http_code}" -o "$response_file" "$api_url")

        # Check for 2xx success codes
        if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
            rm -f "$response_file"
            echo "[]"
            return
        fi

        local versions=$(jq -r '.[].tag_name' "$response_file" | head -20)
        rm -f "$response_file"
        echo "$versions"
    else
        curl -s "$api_url" | grep '"tag_name"' | cut -d '"' -f 4 | head -20
    fi
}

# Function to restore from backup
restore_from_backup() {
    local backup_file="$1"
    local repo_name="$2"
    local repo_dir="$REPOS_DIR/$repo_name"

    print_status "Restoring $repo_name from backup..."

    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi

    # Stop service before restoring
    case "$repo_name" in
        lacylights-node)
            sudo systemctl stop lacylights-backend || true
            ;;
        lacylights-fe)
            sudo systemctl stop lacylights-frontend || true
            ;;
    esac

    # Remove current directory
    rm -rf "$repo_dir"

    # Extract backup
    if ! tar -xzf "$backup_file" -C "$(dirname "$repo_dir")"; then
        print_error "Failed to restore from backup"
        return 1
    fi

    # Start service
    case "$repo_name" in
        lacylights-node)
            sudo systemctl start lacylights-backend || true
            ;;
        lacylights-fe)
            sudo systemctl start lacylights-frontend || true
            ;;
    esac

    print_success "$repo_name restored from backup"
    return 0
}

# Function to get version information for all repos
get_all_versions() {
    local output_format="${1:-text}"

    local fe_installed=$(get_installed_version "$REPOS_DIR/lacylights-fe")
    local node_installed=$(get_installed_version "$REPOS_DIR/lacylights-node")
    local mcp_installed=$(get_installed_version "$REPOS_DIR/lacylights-mcp")

    local fe_latest=$(get_latest_release_version "lacylights-fe")
    local node_latest=$(get_latest_release_version "lacylights-node")
    local mcp_latest=$(get_latest_release_version "lacylights-mcp")

    if [ "$output_format" = "json" ]; then
        cat <<EOF
{
  "lacylights-fe": {
    "installed": "$fe_installed",
    "latest": "$fe_latest"
  },
  "lacylights-node": {
    "installed": "$node_installed",
    "latest": "$node_latest"
  },
  "lacylights-mcp": {
    "installed": "$mcp_installed",
    "latest": "$mcp_latest"
  }
}
EOF
    else
        echo "lacylights-fe: $fe_installed (latest: $fe_latest)"
        echo "lacylights-node: $node_installed (latest: $node_latest)"
        echo "lacylights-mcp: $mcp_installed (latest: $mcp_latest)"
    fi
}

# Function to update a specific repository to a specific version
update_repo() {
    local repo_name="$1"
    local target_version="$2"  # Can be "latest" or specific version like "v1.2.3"

    # Validate repo_name against whitelist
    case "$repo_name" in
        "lacylights-fe"|"lacylights-node"|"lacylights-mcp")
            ;;
        *)
            print_error "Invalid repository name: $repo_name. Must be one of: lacylights-fe, lacylights-node, lacylights-mcp"
            return 1
            ;;
    esac

    local repo_dir="$REPOS_DIR/$repo_name"

    print_status "Updating $repo_name to $target_version..."

    if [ ! -d "$repo_dir" ]; then
        print_error "$repo_name directory not found at $repo_dir"
        return 1
    fi

    # Resolve target version
    local version_to_install
    if [ "$target_version" = "latest" ]; then
        version_to_install=$(get_latest_release_version "$repo_name")
    else
        version_to_install="$target_version"
    fi

    if [ "$version_to_install" = "unknown" ] || [ -z "$version_to_install" ]; then
        print_error "Could not determine version to install for $repo_name"
        return 1
    fi

    # Check if already at target version
    local current_version=$(get_installed_version "$repo_dir")
    if [ "$current_version" = "$version_to_install" ]; then
        print_success "$repo_name is already at $version_to_install"
        return 0
    fi

    # Preserve configuration files
    local temp_backup=$(mktemp -d)
    if [ -z "$temp_backup" ] || [ ! -d "$temp_backup" ]; then
        print_error "Failed to create backup directory"
        return 1
    fi

    if [ -f "$repo_dir/.env" ]; then
        cp "$repo_dir/.env" "$temp_backup/.env"
    fi
    if [ -f "$repo_dir/.env.local" ]; then
        cp "$repo_dir/.env.local" "$temp_backup/.env.local"
    fi

    # For lacylights-node, back up database if using SQLite
    if [ "$repo_name" = "lacylights-node" ]; then
        if [ -f "$repo_dir/lacylights.db" ]; then
            cp "$repo_dir/lacylights.db" "$temp_backup/lacylights.db"
        fi
        if [ -f "$repo_dir/lacylights.db-shm" ]; then
            cp "$repo_dir/lacylights.db-shm" "$temp_backup/lacylights.db-shm"
        fi
        if [ -f "$repo_dir/lacylights.db-wal" ]; then
            cp "$repo_dir/lacylights.db-wal" "$temp_backup/lacylights.db-wal"
        fi
    fi

    # Create temporary directory for download
    local temp_dir=$(mktemp -d)
    if [ -z "$temp_dir" ] || [ ! -d "$temp_dir" ]; then
        print_error "Failed to create temporary directory"
        rm -rf "$temp_backup"
        return 1
    fi

    # Download the release archive
    print_status "Downloading $repo_name $version_to_install..."
    local download_url="https://github.com/$GITHUB_ORG/$repo_name/archive/refs/tags/$version_to_install.tar.gz"
    local archive_file="$temp_dir/${repo_name}.tar.gz"

    # Use -f flag to fail on HTTP errors (404, etc.)
    if ! curl -fsSL "$download_url" -o "$archive_file"; then
        print_error "Failed to download $repo_name $version_to_install (check if version exists)"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi

    # Validate the downloaded archive integrity
    print_status "Validating archive integrity..."
    if ! file "$archive_file" | grep -q 'gzip compressed data'; then
        print_error "Downloaded file is not a valid gzip archive"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi
    if ! tar -tzf "$archive_file" > /dev/null 2>&1; then
        print_error "Downloaded archive is corrupted or not a valid tar.gz"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi

    # Extract to temporary location
    print_status "Extracting $repo_name..."
    mkdir -p "$temp_dir/extract"
    if ! tar -xzf "$archive_file" -C "$temp_dir/extract" --strip-components=1; then
        print_error "Failed to extract archive"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi

    # Create permanent backup before any destructive operations
    mkdir -p "$BACKUP_DIR"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/${repo_name}_backup_${timestamp}.tar.gz"
    print_status "Creating backup of $repo_name at $backup_file..."
    if ! tar -czf "$backup_file" -C "$(dirname "$repo_dir")" "$(basename "$repo_dir")"; then
        print_error "Failed to create backup of $repo_name. Aborting update."
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi
    print_success "Backup created successfully"

    # Stop services before replacing files
    print_status "Stopping $repo_name service..."
    case "$repo_name" in
        lacylights-node)
            sudo systemctl stop lacylights-backend || true
            ;;
        lacylights-fe)
            sudo systemctl stop lacylights-frontend || true
            ;;
        lacylights-mcp)
            # MCP doesn't have a standalone service
            ;;
    esac

    # Replace old directory with new
    rm -rf "$repo_dir"
    mv "$temp_dir/extract" "$repo_dir" || {
        print_error "Failed to move extracted files"
        print_status "Attempting to restore from backup..."
        restore_from_backup "$backup_file" "$repo_name"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    }

    # Restore configuration files
    if [ -f "$temp_backup/.env" ]; then
        cp "$temp_backup/.env" "$repo_dir/.env"
    fi
    if [ -f "$temp_backup/.env.local" ]; then
        cp "$temp_backup/.env.local" "$repo_dir/.env.local"
    fi

    # Restore database for lacylights-node
    if [ "$repo_name" = "lacylights-node" ]; then
        if [ -f "$temp_backup/lacylights.db" ]; then
            cp "$temp_backup/lacylights.db" "$repo_dir/lacylights.db"
        fi
        if [ -f "$temp_backup/lacylights.db-shm" ]; then
            cp "$temp_backup/lacylights.db-shm" "$repo_dir/lacylights.db-shm"
        fi
        if [ -f "$temp_backup/lacylights.db-wal" ]; then
            cp "$temp_backup/lacylights.db-wal" "$repo_dir/lacylights.db-wal"
        fi
    fi

    # Write version file
    echo "$version_to_install" > "$repo_dir/.lacylights-version"

    # Clean up
    rm -rf "$temp_dir" "$temp_backup"

    print_success "$repo_name extracted to $repo_dir"

    # Install dependencies (all dependencies for build, then prune if needed)
    if [ -f "$repo_dir/package.json" ]; then
        print_status "Installing dependencies for $repo_name..."
        pushd "$repo_dir" >/dev/null

        # Check if build is needed first
        local needs_build=false
        if [ -f "tsconfig.json" ] && grep -q '"build"' "package.json"; then
            needs_build=true
        fi

        # Install all dependencies if build is needed, otherwise production only
        if [ "$needs_build" = true ]; then
            if [ -f "package-lock.json" ]; then
                # Remove node_modules to ensure clean npm ci
                rm -rf node_modules
                if ! npm ci; then
                    print_warning "npm ci failed, falling back to npm install..."
                    npm install
                fi
            else
                npm install
            fi
        else
            if [ -f "package-lock.json" ]; then
                if ! npm ci --production; then
                    print_warning "npm ci failed, falling back to npm install..."
                    npm install --production
                fi
            else
                npm install --production
            fi
        fi

        popd >/dev/null
        print_success "Dependencies installed for $repo_name"
    fi

    # Rebuild if necessary
    if [ -f "$repo_dir/tsconfig.json" ] && [ -f "$repo_dir/package.json" ]; then
        if grep -q '"build"' "$repo_dir/package.json"; then
            print_status "Rebuilding $repo_name..."
            pushd "$repo_dir" >/dev/null
            if npm run build; then
                print_success "Build succeeded for $repo_name"

                # Prune dev dependencies after successful build
                print_status "Pruning dev dependencies..."
                npm prune --production
            else
                print_error "Build failed for $repo_name"
                print_status "Attempting to restore from backup..."
                popd >/dev/null
                restore_from_backup "$backup_file" "$repo_name"
                return 1
            fi
            popd >/dev/null
        fi
    fi

    # Run database migrations for lacylights-node
    if [ "$repo_name" = "lacylights-node" ] && [ -f "$repo_dir/prisma/schema.prisma" ]; then
        print_status "Running database migrations for $repo_name..."
        pushd "$repo_dir" >/dev/null
        if npx prisma migrate deploy; then
            print_success "Database migrations completed for $repo_name"
        else
            print_error "Database migrations failed - aborting service startup"
            print_status "Attempting to restore from backup..."
            popd >/dev/null
            restore_from_backup "$backup_file" "$repo_name"
            return 1
        fi
        popd >/dev/null
    fi

    # Start services with automatic rollback on failure
    print_status "Starting $repo_name service..."
    case "$repo_name" in
        lacylights-node)
            # Use || true to prevent script exit on start failure
            sudo systemctl start lacylights-backend || true
            # Wait for service to start (2 seconds + exponential backoff for slower hardware)
            sleep 2
            if sudo systemctl is-active --quiet lacylights-backend; then
                print_success "lacylights-backend service started successfully"
            else
                print_error "Failed to start lacylights-backend service"
                print_status "Attempting to restore from backup..."
                restore_from_backup "$backup_file" "$repo_name"
                return 1
            fi
            ;;
        lacylights-fe)
            # Use || true to prevent script exit on start failure
            sudo systemctl start lacylights-frontend || true
            # Wait for service to start (2 seconds + exponential backoff for slower hardware)
            sleep 2
            if sudo systemctl is-active --quiet lacylights-frontend; then
                print_success "lacylights-frontend service started successfully"
            else
                print_error "Failed to start lacylights-frontend service"
                print_status "Attempting to restore from backup..."
                restore_from_backup "$backup_file" "$repo_name"
                return 1
            fi
            ;;
    esac

    print_success "$repo_name updated to $version_to_install"
    return 0
}

# Main function
main() {
    local command="${1:-help}"
    shift || true

    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"

    case "$command" in
        versions|list)
            # Output format can be 'text' or 'json'
            local format="${1:-text}"
            get_all_versions "$format"
            ;;

        available)
            # List available versions for a specific repo
            local repo_name="$1"
            if [ -z "$repo_name" ]; then
                print_error "Usage: $0 available <repo-name>"
                exit 1
            fi
            list_available_versions "$repo_name"
            ;;

        update)
            # Update a specific repo to a specific version
            local repo_name="$1"
            local version="${2:-latest}"

            if [ -z "$repo_name" ]; then
                print_error "Usage: $0 update <repo-name> [version]"
                exit 1
            fi

            if ! update_repo "$repo_name" "$version"; then
                exit 1
            fi
            ;;

        update-all)
            # Update all repos to latest
            print_status "Updating all repositories to latest versions..."
            local failed=0

            for repo in lacylights-node lacylights-fe lacylights-mcp; do
                if ! update_repo "$repo" "latest"; then
                    failed=1
                fi
            done

            if [ $failed -eq 1 ]; then
                print_error "Some repositories failed to update"
                exit 1
            else
                print_success "All repositories updated successfully"
            fi
            ;;

        help|--help|-h)
            cat <<EOF
LacyLights Repository Update Manager for Raspberry Pi

Usage: $0 <command> [arguments]

Commands:
  versions [format]           Show installed and latest versions
                             Format: text (default) or json

  available <repo>           List available versions for a repository

  update <repo> [version]    Update a repository to specific version
                             repo: lacylights-fe, lacylights-node, or lacylights-mcp
                             version: version tag (e.g., v1.2.3) or 'latest' (default)

  update-all                 Update all repositories to latest versions

  help                       Show this help message

Examples:
  $0 versions
  $0 versions json
  $0 available lacylights-node
  $0 update lacylights-node v1.3.0
  $0 update lacylights-fe latest
  $0 update-all

EOF
            ;;

        *)
            print_error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
