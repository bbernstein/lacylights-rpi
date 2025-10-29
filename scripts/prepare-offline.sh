#!/bin/bash

# LacyLights Offline Bundle Preparation
# Downloads all required files for offline Pi installation
# Run this on a Mac/PC with internet access

set -e

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
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Detect tar type once for efficiency
TAR_TYPE="gnu"
if tar --version 2>&1 | grep -q "bsdtar"; then
    TAR_TYPE="bsd"
fi

# Helper function to create tar archives with fallback for different tar versions
archive_with_fallback() {
    local output_file="$1"
    local source_dir="$2"
    local change_dir="$3"  # Optional: directory to change to before archiving

    # Build tar command as array to avoid word splitting issues
    local tar_cmd=()

    # Disable macOS extended attributes to avoid warnings on Linux
    if [ "$TAR_TYPE" = "bsd" ]; then
        # BSD tar (macOS) - try flags in order of preference
        tar_cmd=(tar --no-xattrs --no-mac-metadata -czf "$output_file")
        if [ -n "$change_dir" ]; then
            tar_cmd+=(-C "$change_dir")
        fi
        tar_cmd+=("$source_dir")

        COPYFILE_DISABLE=1 "${tar_cmd[@]}" 2>/dev/null || \
        {
            # Fallback: without macOS metadata flags
            tar_cmd=(tar --no-xattrs -czf "$output_file")
            if [ -n "$change_dir" ]; then
                tar_cmd+=(-C "$change_dir")
            fi
            tar_cmd+=("$source_dir")
            COPYFILE_DISABLE=1 "${tar_cmd[@]}" 2>/dev/null
        } || \
        {
            # Fallback: basic tar
            tar_cmd=(tar -czf "$output_file")
            if [ -n "$change_dir" ]; then
                tar_cmd+=(-C "$change_dir")
            fi
            tar_cmd+=("$source_dir")
            COPYFILE_DISABLE=1 "${tar_cmd[@]}"
        }
    else
        # GNU tar or unknown tar
        tar_cmd=(tar --no-xattrs -czf "$output_file")
        if [ -n "$change_dir" ]; then
            tar_cmd+=(-C "$change_dir")
        fi
        tar_cmd+=("$source_dir")

        COPYFILE_DISABLE=1 "${tar_cmd[@]}" 2>/dev/null || \
        {
            # Fallback: basic tar
            tar_cmd=(tar -czf "$output_file")
            if [ -n "$change_dir" ]; then
                tar_cmd+=(-C "$change_dir")
            fi
            tar_cmd+=("$source_dir")
            COPYFILE_DISABLE=1 "${tar_cmd[@]}"
        }
    fi
}

# Parse command line arguments
BACKEND_VERSION="main"
FRONTEND_VERSION="main"
MCP_VERSION="main"
OUTPUT_DIR="./lacylights-offline-bundle"

while [[ $# -gt 0 ]]; do
    case $1 in
        --backend-version)
            BACKEND_VERSION="$2"
            shift 2
            ;;
        --frontend-version)
            FRONTEND_VERSION="$2"
            shift 2
            ;;
        --mcp-version)
            MCP_VERSION="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help)
            echo "LacyLights Offline Bundle Preparation"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --backend-version TAG   Git tag/branch for backend (default: main)"
            echo "  --frontend-version TAG  Git tag/branch for frontend (default: main)"
            echo "  --mcp-version TAG       Git tag/branch for MCP server (default: main)"
            echo "  --output DIR            Output directory (default: ./lacylights-offline-bundle)"
            echo "  --help                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 --backend-version v1.1.0 --frontend-version v0.2.0"
            echo "  $0 --output /tmp/lacylights-bundle"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_error "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_header "LacyLights Offline Bundle Preparation"
print_info "Backend version: $BACKEND_VERSION"
print_info "Frontend version: $FRONTEND_VERSION"
print_info "MCP version: $MCP_VERSION"
print_info "Output directory: $OUTPUT_DIR"

# Check prerequisites
print_header "Checking Prerequisites"

if ! command -v curl &> /dev/null; then
    print_error "curl is required but not installed"
    exit 1
fi
print_success "curl found"

if ! command -v node &> /dev/null; then
    print_error "Node.js is required but not installed"
    exit 1
fi
NODE_VERSION=$(node --version)
print_success "Node.js found: $NODE_VERSION"

if ! command -v npm &> /dev/null; then
    print_error "npm is required but not installed"
    exit 1
fi
NPM_VERSION=$(npm --version)
print_success "npm found: v$NPM_VERSION"

# Create output directory
print_header "Setting Up Output Directory"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"/{releases,npm-cache}
print_success "Output directory created: $OUTPUT_DIR"

# Helper function to download GitHub release archive
download_release() {
    local repo=$1
    local version=$2
    local dest_name=$3
    local repo_name=$(basename $repo)

    print_info "Downloading $repo_name version $version..."

    # Determine if version is a tag or branch
    if [[ "$version" =~ ^v[0-9] ]]; then
        # It's a tag
        url="https://github.com/$repo/archive/refs/tags/${version}.tar.gz"
    else
        # It's a branch
        url="https://github.com/$repo/archive/refs/heads/${version}.tar.gz"
    fi

    # Download to releases directory
    curl -L -o "$OUTPUT_DIR/releases/${dest_name}.tar.gz" "$url"

    print_success "$repo_name downloaded"
}

# Download all releases
print_header "Downloading Release Archives"

download_release "bbernstein/lacylights-node" "$BACKEND_VERSION" "backend"
download_release "bbernstein/lacylights-fe" "$FRONTEND_VERSION" "frontend"
download_release "bbernstein/lacylights-mcp" "$MCP_VERSION" "mcp"

print_success "All releases downloaded"

# Extract and prepare npm dependencies
print_header "Preparing NPM Dependencies"

print_info "This may take several minutes..."

# Create temporary extraction directory
TEMP_DIR="$OUTPUT_DIR/temp-extract"
mkdir -p "$TEMP_DIR"

# Process each project
for project in backend frontend mcp; do
    print_info "Processing $project dependencies..."

    # Extract archive
    mkdir -p "$TEMP_DIR/$project"
    tar -xzf "$OUTPUT_DIR/releases/${project}.tar.gz" -C "$TEMP_DIR/$project" --strip-components=1

    cd "$TEMP_DIR/$project"

    # Download dependencies and build
    if [ -f package.json ]; then
        print_info "Downloading npm packages for $project..."
        npm install --cache "$OUTPUT_DIR/npm-cache" --prefer-offline

        print_info "Building $project..."
        # Build with NODE_ENV=production for proper production builds (frontend export)
        NODE_ENV=production npm run build

        print_info "Creating clean package cache for $project..."
        # Create a portable node_modules that works on ARM
        # We'll let the Pi rebuild native modules if needed
        archive_with_fallback "$OUTPUT_DIR/releases/${project}-node_modules.tar.gz" "node_modules/"

        # Create build artifacts archive
        print_info "Archiving build artifacts for $project..."
        if [ -d "dist" ]; then
            # Backend and MCP use dist/
            archive_with_fallback "$OUTPUT_DIR/releases/${project}-dist.tar.gz" "dist/"
            print_success "$project dist/ archived"
        fi

        if [ -d ".next" ]; then
            # Frontend uses .next/
            archive_with_fallback "$OUTPUT_DIR/releases/${project}-next.tar.gz" ".next/"
            print_success "$project .next/ archived"
        fi

        if [ -d "out" ]; then
            # Frontend export build creates out/ directory (static files)
            archive_with_fallback "$OUTPUT_DIR/releases/${project}-out.tar.gz" "out/"
            print_success "$project out/ archived"
        fi

        print_success "$project built and dependencies cached"
    fi

    cd - > /dev/null
done

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Create bundle metadata
print_header "Creating Bundle Metadata"

cat > "$OUTPUT_DIR/bundle-info.json" << EOF
{
    "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "versions": {
        "backend": "$BACKEND_VERSION",
        "frontend": "$FRONTEND_VERSION",
        "mcp": "$MCP_VERSION"
    },
    "node_version": "$NODE_VERSION",
    "npm_version": "$NPM_VERSION",
    "platform": "$(uname -s)",
    "arch": "$(uname -m)"
}
EOF

print_success "Bundle metadata created"

# Create installation script that will be used on Pi
cat > "$OUTPUT_DIR/install-from-bundle.sh" << 'INSTALL_SCRIPT'
#!/bin/bash
# This script is automatically generated
# It installs LacyLights from the offline bundle

set -e

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[INFO] Installing from offline bundle: $BUNDLE_DIR"
echo "[INFO] This script should be run as part of setup-new-pi.sh"
echo "[INFO] or manually on the Pi after transferring this bundle"

# This will be called by the main setup script
# with proper environment and permissions
INSTALL_SCRIPT

chmod +x "$OUTPUT_DIR/install-from-bundle.sh"

# Create archive of entire bundle
print_header "Creating Bundle Archive"

# Use a temporary directory for bundle creation
BUNDLE_DIR="${TMPDIR:-/tmp}/lacylights-bundles"
mkdir -p "$BUNDLE_DIR"

BUNDLE_NAME="lacylights-offline-$(date +%Y%m%d-%H%M%S).tar.gz"
BUNDLE_PATH="$BUNDLE_DIR/$BUNDLE_NAME"

print_info "Creating $BUNDLE_NAME..."
print_info "Bundle location: $BUNDLE_PATH"

# Clean up old bundles (keep only last 3)
print_info "Cleaning up old bundles..."
OLD_BUNDLES=$(ls -t "$BUNDLE_DIR"/lacylights-offline-*.tar.gz 2>/dev/null | tail -n +4)
if [ -n "$OLD_BUNDLES" ]; then
    echo "$OLD_BUNDLES" | xargs rm -f
    print_info "Removed $(echo "$OLD_BUNDLES" | wc -l | tr -d ' ') old bundle(s)"
fi

# Create portable archive with all bundle contents
archive_with_fallback "$BUNDLE_PATH" "." "$OUTPUT_DIR"

print_success "Bundle archive created: $BUNDLE_PATH"

# Print summary
print_header "Preparation Complete"

print_success "Offline bundle ready!"
print_info ""
print_info "Bundle contents:"
print_info "  - Backend release: $BACKEND_VERSION (pre-built)"
print_info "  - Frontend release: $FRONTEND_VERSION (pre-built)"
print_info "  - MCP release: $MCP_VERSION (pre-built)"
print_info "  - NPM dependencies cache"
print_info "  - Pre-downloaded node_modules"
print_info "  - Pre-built artifacts (dist/, .next/)"
print_info ""
print_info "Bundle locations:"
print_info "  - Directory: $OUTPUT_DIR"
print_info "  - Archive: $BUNDLE_PATH"
print_info ""
print_info "Next steps:"
print_info "  1. Transfer bundle to Pi or keep on Mac for setup"
print_info "  2. Run setup script with --offline-bundle flag:"
print_info "     ./scripts/setup-new-pi.sh pi@ntclights.local --offline-bundle $BUNDLE_PATH"
print_info ""
print_success "Ready for offline installation!"
