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

# Distribution server configuration
DIST_BASE_URL="https://dist.lacylights.com/releases"

# GitHub organization (kept for backward compatibility)
GITHUB_ORG="bbernstein"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
# Try to write to log file, but don't fail if we can't (e.g., read-only filesystem or permissions)
# Output to stderr to avoid interfering with script output
log() {
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo "$timestamp $1" >&2
    # Attempt to append to log file, ignore errors
    echo "$timestamp $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Function to print colored output
# Output to stderr to not interfere with script output (e.g., JSON)
print_status() {
    echo -e "${BLUE}==>${NC} $1" >&2
    log "INFO: $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1" >&2
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1" >&2
    log "WARNING: $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect current platform (OS and architecture)
# Returns: os:arch (e.g., "linux:arm64", "darwin:amd64")
get_current_platform() {
    local os arch

    # Detect OS
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux) os="linux" ;;
        *) os="unknown" ;;
    esac

    # Detect architecture
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        amd64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        arm64) arch="arm64" ;;
        armv7l|armv6l|arm) arch="arm" ;;
        *) arch="unknown" ;;
    esac

    echo "${os}:${arch}"
}

# Function to clean up deprecated MCP components from existing installations
# MCP has been removed from RPi distribution (it's macOS-only via lacylights-mac)
# This function removes orphaned directories and services from older installations
cleanup_deprecated_mcp() {
    local cleaned=false

    # Stop and disable MCP service if it exists
    if systemctl list-unit-files lacylights-mcp.service &>/dev/null 2>&1; then
        if systemctl is-active --quiet lacylights-mcp 2>/dev/null; then
            print_status "Stopping deprecated MCP service..."
            sudo systemctl stop lacylights-mcp 2>/dev/null || true
        fi
        if systemctl is-enabled --quiet lacylights-mcp 2>/dev/null; then
            print_status "Disabling deprecated MCP service..."
            sudo systemctl disable lacylights-mcp 2>/dev/null || true
        fi
        # Remove the service file if it exists
        if [ -f "/etc/systemd/system/lacylights-mcp.service" ]; then
            print_status "Removing deprecated MCP service file..."
            sudo rm -f /etc/systemd/system/lacylights-mcp.service
            sudo systemctl daemon-reload
        fi
        cleaned=true
    fi

    # Remove orphaned MCP directory
    if [ -d "$LACYLIGHTS_ROOT/mcp" ]; then
        print_status "Removing deprecated MCP directory..."
        sudo rm -rf "$LACYLIGHTS_ROOT/mcp"
        cleaned=true
    fi

    # Remove orphaned MCP repo directory
    if [ -d "$REPOS_DIR/lacylights-mcp" ]; then
        print_status "Removing deprecated MCP repo directory..."
        sudo rm -rf "$REPOS_DIR/lacylights-mcp"
        cleaned=true
    fi

    # Remove stale MCP symlink if it exists
    if [ -L "$REPOS_DIR/lacylights-mcp" ]; then
        print_status "Removing deprecated MCP symlink..."
        sudo rm -f "$REPOS_DIR/lacylights-mcp"
        cleaned=true
    fi

    if [ "$cleaned" = true ]; then
        print_success "Deprecated MCP components cleaned up"
    fi
}

# Function to fix npm cache permissions
# This fixes issues where npm cache was created by root user
fix_npm_permissions() {
    local npm_home="/home/lacylights/.npm"

    # Get lacylights user/group IDs
    local lacylights_uid=$(id -u lacylights 2>/dev/null || echo "")
    local lacylights_gid=$(id -g lacylights 2>/dev/null || echo "")

    if [ -z "$lacylights_uid" ] || [ -z "$lacylights_gid" ]; then
        print_warning "Could not determine lacylights user/group IDs, skipping npm permission fix"
        return 0
    fi

    # Create npm cache directory if it doesn't exist
    if [ ! -d "$npm_home" ]; then
        print_status "Creating npm cache directory..."
        sudo mkdir -p "$npm_home"
        sudo chown -R "$lacylights_uid:$lacylights_gid" "$npm_home"
    fi

    # Fix ownership of npm cache directory
    # This resolves "Your cache folder contains root-owned files" errors
    if [ -d "$npm_home" ]; then
        local current_owner=$(stat -c '%u' "$npm_home" 2>/dev/null || stat -f '%u' "$npm_home" 2>/dev/null || echo "")
        if [ -n "$current_owner" ] && [ "$current_owner" != "$lacylights_uid" ]; then
            print_status "Fixing npm cache permissions..."
            sudo chown -R "$lacylights_uid:$lacylights_gid" "$npm_home" 2>/dev/null || {
                print_warning "Could not fix npm cache permissions (may need manual intervention)"
            }
        fi
    fi

    # Also fix other npm-related directories that might have wrong permissions
    local npm_dirs=(
        "/home/lacylights/.node-gyp"
        "/home/lacylights/.cache/node"
    )

    for dir in "${npm_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local dir_owner=$(stat -c '%u' "$dir" 2>/dev/null || stat -f '%u' "$dir" 2>/dev/null || echo "")
            if [ -n "$dir_owner" ] && [ "$dir_owner" != "$lacylights_uid" ]; then
                sudo chown -R "$lacylights_uid:$lacylights_gid" "$dir" 2>/dev/null || true
            fi
        fi
    done
}

# Function to map repository name to distribution component name
get_dist_component() {
    local repo="$1"
    case "$repo" in
        lacylights-go) echo "go" ;;
        lacylights-fe) echo "fe-server" ;;  # RPi uses server build with pre-built .next
        *) echo "" ;;
    esac
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

# Function to get the latest release version from distribution server
get_latest_release_version() {
    local repo="$1"
    local component=$(get_dist_component "$repo")

    if [ -z "$component" ]; then
        echo "unknown"
        return
    fi

    local latest_json_url="$DIST_BASE_URL/$component/latest.json"
    local version=""

    # Fetch latest.json from distribution server
    if command_exists jq; then
        local response_file
        response_file=$(mktemp) || {
            echo "unknown"
            return
        }

        local http_code=$(curl -s -w "%{http_code}" -o "$response_file" "$latest_json_url" 2>/dev/null)

        # Check for 2xx success codes
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
            version=$(jq -r '.version // empty' "$response_file" 2>/dev/null)
            if [ "$version" = "null" ] || [ -z "$version" ]; then
                version="unknown"
            else
                # Ensure version has 'v' prefix for consistency
                if [[ ! "$version" =~ ^v ]]; then
                    version="v$version"
                fi
            fi
        else
            version="unknown"
        fi
        rm -f "$response_file"
    else
        # Fallback without jq - use grep/sed with HTTP status checking
        local http_code=$(curl -s -w "%{http_code}" -o /dev/null "$latest_json_url" 2>/dev/null)
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
            local response=$(curl -s "$latest_json_url" 2>/dev/null)
            version=$(echo "$response" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

            if [ -z "$version" ]; then
                version="unknown"
            else
                # Ensure version has 'v' prefix for consistency
                if [[ ! "$version" =~ ^v ]]; then
                    version="v$version"
                fi
            fi
        else
            version="unknown"
        fi
    fi

    echo "$version"
}

# Function to list all available releases for a repository
# Uses the distribution server's versions.json endpoint
list_available_versions() {
    local repo="$1"
    local component
    component=$(get_dist_component "$repo")

    if [ -z "$component" ]; then
        echo "[]"
        return
    fi

    local versions_url="$DIST_BASE_URL/$component/versions.json"

    if command_exists jq; then
        local response_file
        response_file=$(mktemp) || {
            echo "[]"
            return
        }

        local http_code
        http_code=$(curl -s -w "%{http_code}" -o "$response_file" "$versions_url")

        # Check for 2xx success codes
        if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
            rm -f "$response_file"
            print_warning "versions.json not available for $component, no version listing"
            echo "[]"
            return
        fi

        # Extract versions from the versions.json array
        # Format: [{"version": "0.8.12", "isPrerelease": false, ...}, ...]
        # Returns versions prefixed with 'v' for consistency
        local versions
        versions=$(jq -r '.[] | "v" + .version' "$response_file" 2>/dev/null)
        rm -f "$response_file"

        if [ -n "$versions" ]; then
            echo "$versions"
        else
            echo "[]"
        fi
    else
        # Fallback without jq - extract version strings using grep/sed with HTTP status checking
        local http_code=$(curl -s -w "%{http_code}" -o /dev/null "$versions_url" 2>/dev/null)
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
            local response
            response=$(curl -s "$versions_url")
            if [ -n "$response" ]; then
                echo "$response" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | \
                    sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/v\1/' | head -20
            else
                echo "[]"
            fi
        else
            echo "[]"
        fi
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
        lacylights-go)
            if systemctl is-active --quiet lacylights; then
                sudo systemctl stop lacylights
            fi
            ;;
        lacylights-fe)
            if systemctl is-active --quiet lacylights-frontend; then
                sudo systemctl stop lacylights-frontend
            fi
            ;;
    esac

    # Safety check: Only allow removal if repo_dir is within /opt/lacylights/repos/
    if [[ ! "$repo_dir" =~ ^/opt/lacylights/repos/ ]] || [ "$repo_dir" = "/" ] || [ -z "$repo_dir" ]; then
        print_error "Invalid repository directory path: $repo_dir"
        return 1
    fi

    # Remove current directory
    rm -rf "$repo_dir"

    # Extract backup
    if ! tar -xzf "$backup_file" -C "$(dirname "$repo_dir")"; then
        print_error "Failed to restore from backup"
        return 1
    fi

    # Reinstall dependencies and rebuild for the restored version
    print_status "Restoring dependencies for $repo_name..."
    pushd "$repo_dir" >/dev/null

    # For Go backend, just ensure the binary is executable
    if [ "$repo_name" = "lacylights-go" ]; then
        if [ -f "lacylights-server" ]; then
            chmod +x lacylights-server
            # Use full path for sudoers compatibility
            sudo chown lacylights:lacylights "$repo_dir/lacylights-server"
        fi
    elif [ -f "package.json" ]; then
        # Fix npm cache permissions before running npm commands
        fix_npm_permissions

        # Install dependencies (production-only for npm repos)
        if [ -f "package-lock.json" ]; then
            rm -rf node_modules
            if ! npm ci --production; then
                print_warning "npm ci failed, falling back to npm install..."
                npm install --production
            fi
        else
            npm install --production
        fi
    fi

    popd >/dev/null

    # Start service
    case "$repo_name" in
        lacylights-go)
            sudo systemctl start lacylights || true
            ;;
        lacylights-fe)
            sudo systemctl start lacylights-frontend || true
            ;;
    esac

    print_success "$repo_name restored from backup"
    return 0
}

# Function to get version information for all repos
# Versions are read from deployment directories (where services actually run)
# This ensures version is accurate whether deployed via deploy.sh or update-repos.sh
get_all_versions() {
    local output_format="${1:-text}"

    # Read versions from actual deployment directories, not repos/
    local fe_installed=$(get_installed_version "$LACYLIGHTS_ROOT/frontend-src")
    local go_installed=$(get_installed_version "$LACYLIGHTS_ROOT/backend")

    local fe_latest=$(get_latest_release_version "lacylights-fe")
    local go_latest=$(get_latest_release_version "lacylights-go")

    if [ "$output_format" = "json" ]; then
        cat <<EOF
{
  "lacylights-fe": {
    "installed": "$fe_installed",
    "latest": "$fe_latest"
  },
  "lacylights-go": {
    "installed": "$go_installed",
    "latest": "$go_latest"
  }
}
EOF
    else
        echo "lacylights-fe: $fe_installed (latest: $fe_latest)"
        echo "lacylights-go: $go_installed (latest: $go_latest)"
    fi
}

# Function to update a specific repository to a specific version
update_repo() {
    local repo_name="$1"
    local target_version="$2"  # Can be "latest" or specific version like "v1.2.3"

    # Validate repo_name against whitelist
    case "$repo_name" in
        "lacylights-fe"|"lacylights-go")
            ;;
        *)
            print_error "Invalid repository name: $repo_name. Must be one of: lacylights-fe, lacylights-go"
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
    # Read version from deployment directories (where services actually run)
    local version_check_dir
    case "$repo_name" in
        "lacylights-go") version_check_dir="$LACYLIGHTS_ROOT/backend" ;;
        "lacylights-fe") version_check_dir="$LACYLIGHTS_ROOT/frontend-src" ;;
        *) version_check_dir="$repo_dir" ;;
    esac
    local current_version=$(get_installed_version "$version_check_dir")
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

    # For lacylights-go, back up database if using SQLite
    if [ "$repo_name" = "lacylights-go" ]; then
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
    local temp_dir
    temp_dir=$(mktemp -d) || {
        print_error "Failed to create temporary directory"
        rm -rf "$temp_backup"
        return 1
    }

    # Download the release archive from distribution server
    print_status "Downloading $repo_name $version_to_install..."

    local component=$(get_dist_component "$repo_name")
    if [ -z "$component" ]; then
        print_error "Unknown component for $repo_name"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi

    # Fetch metadata from distribution server (version-specific or latest)
    local metadata_url
    if [ "$target_version" = "latest" ]; then
        metadata_url="$DIST_BASE_URL/$component/latest.json"
    else
        local version_number="${version_to_install#v}"
        metadata_url="$DIST_BASE_URL/$component/$version_number.json"
    fi
    local metadata_file="$temp_dir/metadata.json"

    if ! curl -fsSL "$metadata_url" -o "$metadata_file"; then
        print_error "Failed to fetch release metadata from $metadata_url"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi

    # Detect current platform for selecting the correct download URL
    local platform=$(get_current_platform)
    local platform_os="${platform%%:*}"
    local platform_arch="${platform##*:}"

    if [ "$platform_os" = "unknown" ] || [ "$platform_arch" = "unknown" ]; then
        print_error "Could not detect platform (os=$platform_os, arch=$platform_arch)"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi

    print_status "Detected platform: $platform_os/$platform_arch"

    # Extract download URL and SHA256 from metadata for current platform
    local download_url
    local expected_sha256

    # Check if metadata has platforms array (multi-platform) or direct url/sha256 (single-platform)
    local has_platforms=false
    if command_exists jq; then
        if jq -e '.platforms' "$metadata_file" > /dev/null 2>&1; then
            has_platforms=true
        fi
    elif command_exists python3; then
        if python3 -c "import json; f=open('$metadata_file'); d=json.load(f); exit(0 if 'platforms' in d else 1)" 2>/dev/null; then
            has_platforms=true
        fi
    fi

    # Handle platform-independent releases (e.g., static frontend)
    if [ "$has_platforms" = false ]; then
        print_status "Using platform-independent release"
        if command_exists jq; then
            download_url=$(jq -r '.url // empty' "$metadata_file")
            expected_sha256=$(jq -r '.sha256 // empty' "$metadata_file")
        elif command_exists python3; then
            local python_result
            python_result=$(python3 -c "
import json
with open('$metadata_file') as f:
    d = json.load(f)
print(d.get('url', '') + '|' + d.get('sha256', ''))
" 2>/dev/null)
            download_url="${python_result%%|*}"
            expected_sha256="${python_result##*|}"
        fi
    elif command_exists jq; then
        # Use jq to select the correct platform from the platforms array
        # First, check how many matches we have to detect data quality issues
        local matches
        matches=$(jq -c --arg os "$platform_os" --arg arch "$platform_arch" '
            [ .platforms[] | select(.os == $os and .arch == $arch) ]
        ' "$metadata_file")
        local match_count
        match_count=$(echo "$matches" | jq 'length')

        if [ "$match_count" -eq 0 ]; then
            print_error "No matching platform entry found in metadata for $platform_os/$platform_arch"
            print_error "Available platforms:"
            jq -r '.platforms[] | "  - \(.os)/\(.arch)"' "$metadata_file" >&2
            rm -rf "$temp_dir" "$temp_backup"
            return 1
        elif [ "$match_count" -gt 1 ]; then
            print_error "Multiple matching platform entries ($match_count) found in metadata for $platform_os/$platform_arch"
            rm -rf "$temp_dir" "$temp_backup"
            return 1
        fi

        download_url=$(echo "$matches" | jq -r '.[0].url // empty')
        expected_sha256=$(echo "$matches" | jq -r '.[0].sha256 // empty')
    elif command_exists python3; then
        # Fallback to Python if jq is not available
        # Single invocation to get both URL and SHA256 with proper error handling
        local python_result
        python_result=$(python3 -c "
import json, sys
try:
    with open('$metadata_file') as f:
        d = json.load(f)
    p = [x for x in d.get('platforms', []) if x.get('os') == '$platform_os' and x.get('arch') == '$platform_arch']
    if len(p) == 0:
        print('ERROR:No matching platform entry found')
    elif len(p) > 1:
        print('ERROR:Multiple matching platform entries found')
    else:
        print(p[0].get('url', '') + '|' + p[0].get('sha256', ''))
except Exception as e:
    print('ERROR:Failed to parse metadata: ' + str(e))
" 2>/dev/null)

        if [[ "$python_result" == ERROR:* ]]; then
            print_error "${python_result#ERROR:} for $platform_os/$platform_arch"
            rm -rf "$temp_dir" "$temp_backup"
            return 1
        fi

        download_url="${python_result%%|*}"
        expected_sha256="${python_result##*|}"
    else
        print_error "Neither jq nor python3 available for JSON parsing"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi

    if [ -z "$download_url" ]; then
        print_error "Could not extract download URL from metadata for platform $platform_os/$platform_arch"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi

    local archive_file="$temp_dir/${repo_name}.tar.gz"

    # Download the archive
    if ! curl -fsSL "$download_url" -o "$archive_file"; then
        print_error "Failed to download $repo_name from $download_url"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi

    # Verify SHA256 checksum if available
    if [ -n "$expected_sha256" ]; then
        print_status "Verifying SHA256 checksum..."
        local actual_sha256
        if command_exists sha256sum; then
            actual_sha256=$(sha256sum "$archive_file" | awk '{print $1}')
        elif command_exists shasum; then
            actual_sha256=$(shasum -a 256 "$archive_file" | awk '{print $1}')
        else
            print_warning "No SHA256 tool available, skipping checksum verification"
            actual_sha256=""
        fi

        if [ -n "$actual_sha256" ]; then
            if [ "$actual_sha256" != "$expected_sha256" ]; then
                print_error "SHA256 checksum mismatch!"
                print_error "Expected: $expected_sha256"
                print_error "Got:      $actual_sha256"
                rm -rf "$temp_dir" "$temp_backup"
                return 1
            fi
            print_success "SHA256 checksum verified"
        fi
    else
        print_warning "No SHA256 checksum available in metadata, skipping verification"
    fi

    # Validate the downloaded archive integrity
    print_status "Validating archive format..."
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

    # Go archives contain just the binary (no directory structure)
    # Other archives have a top-level directory that needs stripping
    if [ "$repo_name" = "lacylights-go" ]; then
        # Go archive: extract flat, then rename binary to expected name
        if ! tar -xzf "$archive_file" -C "$temp_dir/extract"; then
            print_error "Failed to extract archive"
            rm -rf "$temp_dir" "$temp_backup"
            return 1
        fi
        # Rename platform-specific binary to lacylights-server
        local extracted_binary=$(find "$temp_dir/extract" -maxdepth 1 -name "lacylights-*" -type f | head -1)
        if [ -n "$extracted_binary" ] && [ -f "$extracted_binary" ]; then
            mv "$extracted_binary" "$temp_dir/extract/lacylights-server"
        fi
        # Fail early if binary wasn't found or rename failed
        if [ ! -f "$temp_dir/extract/lacylights-server" ]; then
            print_error "Go backend binary not found in archive after extraction"
            print_error "Expected binary matching 'lacylights-*' in archive"
            rm -rf "$temp_dir" "$temp_backup"
            return 1
        fi
    else
        # Other archives: strip top-level directory
        if ! tar -xzf "$archive_file" -C "$temp_dir/extract" --strip-components=1; then
            print_error "Failed to extract archive"
            rm -rf "$temp_dir" "$temp_backup"
            return 1
        fi
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
        lacylights-go)
            if systemctl is-active --quiet lacylights; then
                print_status "Stopping lacylights service..."
                sudo systemctl stop lacylights
                # Wait for systemd to confirm service is stopped
                local wait_count=0
                while systemctl is-active --quiet lacylights && [ $wait_count -lt 30 ]; do
                    sleep 1
                    wait_count=$((wait_count + 1))
                done
                # Verify service actually stopped
                if systemctl is-active --quiet lacylights; then
                    print_error "Service failed to stop after 30 seconds. Aborting update."
                    rm -rf "$temp_dir" "$temp_backup"
                    return 1
                fi
                # Give the process a moment to fully exit
                sleep 1
            fi
            ;;
        lacylights-fe)
            if systemctl is-active --quiet lacylights-frontend; then
                sudo systemctl stop lacylights-frontend
                sleep 2
            fi
            ;;
    esac

    # Replace old directory with new
    # Safety check: Only allow deletion if repo_dir is a subdirectory of /opt/lacylights/repos/
    if [[ ! "$repo_dir" =~ ^/opt/lacylights/repos/ ]] || [ "$repo_dir" = "/" ] || [ "$repo_dir" = "/opt" ]; then
        print_error "Invalid repository directory path: $repo_dir"
        rm -rf "$temp_dir" "$temp_backup"
        return 1
    fi

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

    # Restore database for lacylights-go
    if [ "$repo_name" = "lacylights-go" ]; then
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

    # Clean up
    rm -rf "$temp_dir" "$temp_backup"

    print_success "$repo_name extracted to $repo_dir"

    # Deploy pre-built releases to their service directories
    if [ "$repo_name" = "lacylights-fe" ]; then
        # Frontend is pre-built with .next and node_modules included - just deploy
        print_status "Deploying pre-built frontend for $repo_name"

        # Deploy frontend to frontend-src directory where the systemd service runs
        local frontend_dir="$LACYLIGHTS_ROOT/frontend-src"
        # Note: frontend_backup_file is used by restore_frontend() below.
        # Bash nested functions inherit parent scope, so this variable is accessible.
        local frontend_backup_file=""

        # Create directory if it doesn't exist
        if [ ! -d "$frontend_dir" ]; then
            print_status "Creating frontend directory..."
            if ! sudo mkdir -p "$frontend_dir"; then
                print_error "Failed to create frontend directory"
                restore_from_backup "$backup_file" "$repo_name"
                return 1
            fi
        fi

        # Create a backup of frontend-src BEFORE clearing it
        # This ensures we can restore the working frontend if deployment fails
        if [ -d "$frontend_dir" ] && [ -n "$(ls -A "$frontend_dir" 2>/dev/null)" ]; then
            local fe_timestamp=$(date +"%Y%m%d_%H%M%S")
            frontend_backup_file="$BACKUP_DIR/frontend-src_backup_${fe_timestamp}.tar.gz"
            print_status "Creating backup of frontend-src at $frontend_backup_file..."
            if ! tar -czf "$frontend_backup_file" -C "$(dirname "$frontend_dir")" "$(basename "$frontend_dir")"; then
                print_warning "Failed to create frontend-src backup, continuing without backup"
                frontend_backup_file=""
            fi
        fi

        # Helper function to restore frontend-src from backup
        restore_frontend() {
            if [ -n "$frontend_backup_file" ] && [ -f "$frontend_backup_file" ]; then
                print_status "Restoring frontend-src from backup..."
                # Safety check
                if [[ ! "$frontend_dir" =~ ^/opt/lacylights/ ]] || [ "$frontend_dir" = "/" ] || [ -z "$frontend_dir" ]; then
                    print_error "Invalid frontend directory path: $frontend_dir"
                    return 1
                fi
                # Clear and restore
                find "$frontend_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
                if tar -xzf "$frontend_backup_file" -C "$(dirname "$frontend_dir")" --strip-components=0; then
                    print_success "Frontend-src restored from backup"
                    # Restart the frontend service (use restart to ensure clean state)
                    if ! sudo systemctl restart lacylights-frontend; then
                        print_warning "Failed to restart frontend service after restoration"
                    fi
                else
                    print_error "Failed to restore frontend-src from backup"
                fi
            else
                print_warning "No frontend-src backup available, cannot restore previous state"
            fi
        }

        # Helper function to clean up old frontend backups (keep last 3)
        cleanup_old_frontend_backups() {
            local backup_pattern="$BACKUP_DIR/frontend-src_backup_*.tar.gz"
            local backup_count
            backup_count=$(find "$BACKUP_DIR" -name "frontend-src_backup_*.tar.gz" 2>/dev/null | wc -l)
            if [ "$backup_count" -gt 3 ]; then
                print_status "Cleaning up old frontend backups (keeping last 3)..."
                # Sort by timestamp (oldest first) and remove all but the last 3
                find "$BACKUP_DIR" -name "frontend-src_backup_*.tar.gz" -printf '%T+ %p\n' 2>/dev/null | \
                    sort | head -n -3 | cut -d' ' -f2- | xargs rm -f 2>/dev/null || true
            fi
        }

        print_status "Deploying frontend to frontend-src directory..."
        # Ensure directory has proper group ownership and permissions
        sudo chown -R lacylights:lacylights "$frontend_dir"
        sudo chmod -R g+w "$frontend_dir"
        sudo chmod g+s "$frontend_dir"

        # Remove old files (fe-server archive includes node_modules and .next)
        # Note: Use find instead of glob to ensure hidden files/dirs are also removed
        # Safety check: Only allow deletion if frontend_dir is within /opt/lacylights/
        if [[ ! "$frontend_dir" =~ ^/opt/lacylights/ ]] || [ "$frontend_dir" = "/" ] || [ -z "$frontend_dir" ]; then
            print_error "Invalid frontend directory path: $frontend_dir"
            restore_frontend
            restore_from_backup "$backup_file" "$repo_name"
            return 1
        fi
        if ! find "$frontend_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +; then
            print_error "Failed to remove old frontend files"
            restore_frontend
            restore_from_backup "$backup_file" "$repo_name"
            return 1
        fi

        # Copy new files from repos to frontend-src
        # Note: Use /. to copy all contents including hidden files/directories
        if cp -r "$repo_dir"/. "$frontend_dir/"; then
            # Ensure new files have group write permissions
            sudo chmod -R g+w "$frontend_dir"

            # Validate that .next directory exists (should be in the archive)
            if [ ! -d "$frontend_dir/.next" ]; then
                print_error "Frontend archive missing .next directory - invalid release"
                print_error "The fe-server release should include a pre-built .next directory"
                restore_frontend
                restore_from_backup "$backup_file" "$repo_name"
                return 1
            fi

            # Validate that node_modules exists (should be in the archive)
            if [ ! -d "$frontend_dir/node_modules" ]; then
                print_error "Frontend archive missing node_modules directory - invalid release"
                print_error "The fe-server release should include node_modules"
                restore_frontend
                restore_from_backup "$backup_file" "$repo_name"
                return 1
            fi

            # Extract version from package.json with proper error handling
            local fe_version="unknown"
            if [ -f "$frontend_dir/package.json" ]; then
                if ! fe_version=$(node -p "require('$frontend_dir/package.json').version" 2>/dev/null); then
                    print_warning "Unable to determine frontend version from package.json"
                    fe_version="unknown"
                fi
            else
                print_warning "package.json not found in $frontend_dir; frontend version unknown"
            fi

            # Clean up old frontend backups (keep last 3 for manual recovery if needed)
            cleanup_old_frontend_backups

            print_success "Frontend deployed to $frontend_dir (v$fe_version)"
        else
            print_error "Failed to copy frontend to frontend-src directory"
            restore_frontend
            restore_from_backup "$backup_file" "$repo_name"
            return 1
        fi
    elif [ "$repo_name" = "lacylights-go" ]; then
        # Go backend is a pre-built binary - set up and deploy to backend directory
        print_status "Setting up Go backend binary..."
        pushd "$repo_dir" >/dev/null
        if [ -f "lacylights-server" ]; then
            chmod +x lacylights-server
            # Use full path for sudoers compatibility
            sudo chown lacylights:lacylights "$repo_dir/lacylights-server"
            print_success "Go backend binary ready in repos directory"

            # Deploy binary to the backend directory where the systemd service runs
            local backend_dir="$LACYLIGHTS_ROOT/backend"
            if [ -d "$backend_dir" ]; then
                print_status "Deploying binary to backend directory..."
                # Copy the binary to the backend directory
                if cp lacylights-server "$backend_dir/lacylights-server"; then
                    chmod +x "$backend_dir/lacylights-server"
                    sudo chown lacylights:lacylights "$backend_dir/lacylights-server"
                    print_success "Go backend binary deployed to $backend_dir"
                else
                    print_error "Failed to copy binary to backend directory"
                    popd >/dev/null
                    restore_from_backup "$backup_file" "$repo_name"
                    return 1
                fi
            else
                print_warning "Backend directory $backend_dir not found, creating it..."
                if ! mkdir -p "$backend_dir"; then
                    print_error "Failed to create backend directory"
                    popd >/dev/null
                    restore_from_backup "$backup_file" "$repo_name"
                    return 1
                fi
                sudo chown lacylights:lacylights "$backend_dir"
                if cp lacylights-server "$backend_dir/lacylights-server"; then
                    chmod +x "$backend_dir/lacylights-server"
                    sudo chown lacylights:lacylights "$backend_dir/lacylights-server"
                    print_success "Go backend binary deployed to $backend_dir"
                else
                    print_error "Failed to copy binary to backend directory"
                    popd >/dev/null
                    restore_from_backup "$backup_file" "$repo_name"
                    return 1
                fi
            fi
        else
            print_error "Go backend binary not found in archive"
            print_status "Attempting to restore from backup..."
            popd >/dev/null
            restore_from_backup "$backup_file" "$repo_name"
            return 1
        fi
        popd >/dev/null
    elif [ -f "$repo_dir/package.json" ]; then
        # Fix npm cache permissions before running npm commands
        fix_npm_permissions

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

        # Rebuild if necessary
        if [ -f "$repo_dir/tsconfig.json" ] && grep -q '"build"' "$repo_dir/package.json"; then
            print_status "Rebuilding $repo_name..."
            pushd "$repo_dir" >/dev/null
            if npm run build; then
                print_success "Build succeeded for $repo_name"

                # Prune dev dependencies after successful build
                print_status "Pruning dev dependencies..."
                if ! npm prune --production; then
                    print_warning "Failed to prune dev dependencies, continuing anyway..."
                fi
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

    # Start services with automatic rollback on failure
    print_status "Starting $repo_name service..."
    case "$repo_name" in
        lacylights-go)
            # Use || true to prevent script exit on start failure
            sudo systemctl start lacylights || true
            # Retry with exponential backoff to allow service time to start
            local retry_count=0
            local max_retries=5
            local wait_time=1
            while [ $retry_count -lt $max_retries ]; do
                sleep $wait_time
                if sudo systemctl is-active --quiet lacylights; then
                    print_success "lacylights service started successfully"
                    break
                fi
                retry_count=$((retry_count + 1))
                wait_time=$((wait_time * 2))
                if [ $retry_count -lt $max_retries ]; then
                    print_status "Service not ready, retrying in ${wait_time}s (attempt $((retry_count + 1))/$max_retries)..."
                fi
            done

            if [ $retry_count -eq $max_retries ]; then
                print_error "Failed to start lacylights service after $max_retries attempts"
                print_status "Attempting to restore from backup..."
                restore_from_backup "$backup_file" "$repo_name"
                return 1
            fi
            ;;
        lacylights-fe)
            # Use restart to ensure new code is loaded; || true to prevent script exit on failure
            sudo systemctl restart lacylights-frontend || true
            # Retry with exponential backoff to allow service time to start
            local retry_count=0
            local max_retries=5
            local wait_time=1
            while [ $retry_count -lt $max_retries ]; do
                sleep $wait_time
                local service_state=$(sudo systemctl is-active lacylights-frontend 2>&1 || echo "failed")
                log "DEBUG: Service state check: $service_state"
                if [ "$service_state" = "active" ]; then
                    print_success "lacylights-frontend service started successfully"
                    break
                fi
                retry_count=$((retry_count + 1))
                wait_time=$((wait_time * 2))
                if [ $retry_count -lt $max_retries ]; then
                    print_status "Service not ready (state: $service_state), retrying in ${wait_time}s (attempt $((retry_count + 1))/$max_retries)..."
                fi
            done

            if [ $retry_count -eq $max_retries ]; then
                print_error "Failed to start lacylights-frontend service after $max_retries attempts"
                print_status "Attempting to restore from backup..."
                restore_from_backup "$backup_file" "$repo_name"
                return 1
            fi
            ;;
    esac

    # Write version file to deployment directory ONLY after successful deployment
    # This ensures version file matches actual deployed version
    local version_file_dir
    case "$repo_name" in
        "lacylights-go") version_file_dir="$LACYLIGHTS_ROOT/backend" ;;
        "lacylights-fe") version_file_dir="$LACYLIGHTS_ROOT/frontend-src" ;;
        *) version_file_dir="$repo_dir" ;;
    esac
    echo "$version_to_install" > "$version_file_dir/.lacylights-version"

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
            # Update frontend first, then backend last to avoid self-update interruption
            print_status "Updating all repositories to latest versions..."

            # Clean up deprecated MCP components from older installations
            cleanup_deprecated_mcp

            local failed=0

            for repo in lacylights-fe lacylights-go; do
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
                             repo: lacylights-fe or lacylights-go
                             version: version tag (e.g., v1.2.3) or 'latest' (default)

  update-all                 Update all repositories to latest versions

  help                       Show this help message

Examples:
  $0 versions
  $0 versions json
  $0 available lacylights-go
  $0 update lacylights-go v1.3.0
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
