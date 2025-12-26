#!/bin/bash

# LacyLights SD Card Image Creation Script
# Creates a compressed .img.gz file for imaging new Raspberry Pis
#
# This script:
# 1. Connects to a running Pi to clean up and prepare for imaging
# 2. Guides user to transfer SD card to Mac
# 3. Auto-detects the SD card device
# 4. Creates a minimal image (only used space + buffer)
# 5. Compresses the image for distribution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

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

print_step() {
    echo ""
    echo -e "${MAGENTA}${BOLD}>>> STEP $1: $2${NC}"
    echo ""
}

print_action() {
    echo -e "${YELLOW}    ACTION REQUIRED:${NC} $1"
}

wait_for_enter() {
    echo ""
    echo -e "${YELLOW}Press ENTER when ready to continue...${NC}"
    read -r
}

# Check if running on macOS
check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        print_error "This script must be run on macOS"
        exit 1
    fi
}

# Default values
PI_HOST="${PI_HOST:-lacylights.local}"
PI_USER="${PI_USER:-lacylights}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/Desktop}"
IMAGE_NAME="${IMAGE_NAME:-lacylights}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"
BUFFER_MB=512  # Extra space buffer in MB

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            PI_HOST="$2"
            shift 2
            ;;
        --user)
            PI_USER="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --skip-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        --help)
            echo "LacyLights SD Card Image Creation Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --host HOSTNAME      Pi hostname (default: lacylights.local)"
            echo "  --user USERNAME      Pi username (default: lacylights)"
            echo "  --output-dir PATH    Output directory (default: ~/Desktop)"
            echo "  --name NAME          Image base name (default: lacylights)"
            echo "  --skip-cleanup       Skip the Pi cleanup step"
            echo "  --help               Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  PI_HOST              Same as --host"
            echo "  PI_USER              Same as --user"
            echo "  OUTPUT_DIR           Same as --output-dir"
            echo "  IMAGE_NAME           Same as --name"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 --host mypi.local --user pi"
            echo "  $0 --skip-cleanup --name myproject"
            echo ""
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Generate timestamped filename
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
IMAGE_FILE="${OUTPUT_DIR}/${IMAGE_NAME}-${TIMESTAMP}.img"
COMPRESSED_FILE="${IMAGE_FILE}.gz"

print_header "LacyLights SD Card Image Creator"

echo ""
echo "Configuration:"
echo "  Pi Host:      ${PI_HOST}"
echo "  Pi User:      ${PI_USER}"
echo "  Output Dir:   ${OUTPUT_DIR}"
echo "  Image Name:   ${IMAGE_NAME}-${TIMESTAMP}.img.gz"
echo "  Skip Cleanup: ${SKIP_CLEANUP}"
echo ""

check_macos

# ============================================================================
# STEP 1: Connect to Pi and prepare for imaging
# ============================================================================
if [[ "${SKIP_CLEANUP}" != "true" ]]; then
    print_step "1" "Prepare the Raspberry Pi for imaging"

    print_action "Ensure the SD card is inserted in the running Raspberry Pi"
    echo ""
    echo "The script will now connect to ${PI_USER}@${PI_HOST} to:"
    echo "  - Stop LacyLights services"
    echo "  - Clean up temporary files and caches"
    echo "  - Zero out free space for better compression"
    echo ""
    echo "This may take several minutes depending on free space."

    wait_for_enter

    print_info "Connecting to Pi at ${PI_HOST}..."

    # Check SSH connectivity
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${PI_USER}@${PI_HOST}" "echo 'Connected'" 2>/dev/null; then
        print_error "Cannot connect to ${PI_USER}@${PI_HOST}"
        echo ""
        echo "Please ensure:"
        echo "  1. The Pi is powered on and running"
        echo "  2. You can SSH to it (try: ssh ${PI_USER}@${PI_HOST})"
        echo "  3. SSH key authentication is set up"
        echo ""
        exit 1
    fi

    print_success "SSH connection verified"

    # Run cleanup on the Pi
    print_info "Stopping LacyLights services..."
    ssh "${PI_USER}@${PI_HOST}" "sudo systemctl stop lacylights-go.service 2>/dev/null || true"
    ssh "${PI_USER}@${PI_HOST}" "sudo systemctl stop lacylights-mcp.service 2>/dev/null || true"

    print_info "Cleaning package manager cache..."
    ssh "${PI_USER}@${PI_HOST}" "sudo apt-get clean"

    print_info "Removing log files..."
    ssh "${PI_USER}@${PI_HOST}" "sudo rm -rf /var/log/*.gz /var/log/*.1 /var/log/*.old 2>/dev/null || true"
    ssh "${PI_USER}@${PI_HOST}" "sudo journalctl --vacuum-time=1d 2>/dev/null || true"

    print_info "Clearing user caches..."
    ssh "${PI_USER}@${PI_HOST}" "rm -rf ~/.cache/* 2>/dev/null || true"
    ssh "${PI_USER}@${PI_HOST}" "rm -rf /tmp/* 2>/dev/null || true"

    print_info "Clearing thumbnail caches..."
    ssh "${PI_USER}@${PI_HOST}" "rm -rf ~/.thumbnails/* 2>/dev/null || true"

    print_info "Zeroing free space for better compression (this takes a while)..."
    echo "  Creating zero file to fill free space..."
    # Use a controlled approach - create file until disk is ~95% full, then remove
    ssh "${PI_USER}@${PI_HOST}" "sudo dd if=/dev/zero of=/zero.file bs=1M status=progress 2>&1 || true"
    ssh "${PI_USER}@${PI_HOST}" "sudo rm -f /zero.file"

    print_info "Syncing filesystem..."
    ssh "${PI_USER}@${PI_HOST}" "sync"

    print_success "Pi preparation complete!"

    # Get disk usage info from Pi
    print_info "Getting disk usage information..."
    DISK_INFO=$(ssh "${PI_USER}@${PI_HOST}" "df -BM / | tail -1")
    USED_MB=$(echo "${DISK_INFO}" | awk '{print $3}' | tr -d 'M')
    print_info "Used space on root partition: ${USED_MB} MB"
fi

# ============================================================================
# STEP 2: Shut down the Pi and transfer SD card
# ============================================================================
print_step "2" "Shut down the Pi and transfer the SD card"

if [[ "${SKIP_CLEANUP}" != "true" ]]; then
    echo "The Pi will now be shut down safely."
    echo ""
    print_action "After shutdown, remove the SD card and insert it into your Mac"
    echo ""
    read -p "Shut down the Pi now? [Y/n]: " SHUTDOWN_CONFIRM

    if [[ "${SHUTDOWN_CONFIRM}" != "n" && "${SHUTDOWN_CONFIRM}" != "N" ]]; then
        print_info "Shutting down Pi..."
        ssh "${PI_USER}@${PI_HOST}" "sudo shutdown -h now" 2>/dev/null || true
        print_success "Shutdown command sent"
        echo ""
        echo "Wait for the Pi's LED to stop blinking (about 10-20 seconds),"
        echo "then safely remove the SD card."
    fi
else
    print_action "Remove the SD card from the Pi and insert it into your Mac"
fi

wait_for_enter

# ============================================================================
# STEP 3: Detect the SD card on Mac
# ============================================================================
print_step "3" "Detect the SD card"

print_info "Scanning for removable disks..."
echo ""

# List external/removable disks
DISK_LIST=$(diskutil list external 2>/dev/null || diskutil list)

echo "Available external disks:"
echo "${DISK_LIST}"
echo ""

# Try to auto-detect the SD card
# Look for disks that are external and have typical SD card sizes (8GB-128GB)
DETECTED_DISK=""
for disk in /dev/disk[0-9]*; do
    # Skip partitions, only look at whole disks
    if [[ "${disk}" =~ s[0-9]+$ ]]; then
        continue
    fi

    # Check if it's external/removable
    INFO=$(diskutil info "${disk}" 2>/dev/null || true)
    if echo "${INFO}" | grep -q "Removable Media.*Yes\|External.*Yes\|Protocol.*USB\|Protocol.*SD"; then
        SIZE_BYTES=$(echo "${INFO}" | grep "Disk Size" | head -1 | sed 's/.*(\([0-9]*\) Bytes).*/\1/' || echo "0")
        SIZE_GB=$((SIZE_BYTES / 1024 / 1024 / 1024))

        # Typical SD cards are 8GB to 512GB
        if [[ ${SIZE_GB} -ge 4 && ${SIZE_GB} -le 512 ]]; then
            DISK_NAME=$(basename "${disk}")
            print_info "Detected potential SD card: ${disk} (${SIZE_GB} GB)"
            DETECTED_DISK="${disk}"
        fi
    fi
done

echo ""
if [[ -n "${DETECTED_DISK}" ]]; then
    print_info "Auto-detected SD card: ${DETECTED_DISK}"
    read -p "Use this disk? [Y/n]: " USE_DETECTED
    if [[ "${USE_DETECTED}" == "n" || "${USE_DETECTED}" == "N" ]]; then
        DETECTED_DISK=""
    fi
fi

if [[ -z "${DETECTED_DISK}" ]]; then
    echo ""
    echo "Enter the disk device (e.g., disk4, disk8):"
    read -p "Disk: /dev/" DISK_NUM
    DETECTED_DISK="/dev/${DISK_NUM}"
fi

# Validate the disk exists
if [[ ! -e "${DETECTED_DISK}" ]]; then
    print_error "Disk ${DETECTED_DISK} does not exist"
    exit 1
fi

SD_DEVICE="${DETECTED_DISK}"
RAW_DEVICE="/dev/r$(basename "${SD_DEVICE}")"

# Get disk info
DISK_INFO=$(diskutil info "${SD_DEVICE}")
DISK_SIZE_BYTES=$(echo "${DISK_INFO}" | grep "Disk Size" | head -1 | sed 's/.*(\([0-9]*\) Bytes).*/\1/' || echo "0")
DISK_SIZE_GB=$((DISK_SIZE_BYTES / 1024 / 1024 / 1024))
DISK_SIZE_MB=$((DISK_SIZE_BYTES / 1024 / 1024))

echo ""
echo "Selected disk: ${SD_DEVICE}"
echo "Disk size: ${DISK_SIZE_GB} GB (${DISK_SIZE_MB} MB)"
echo ""

# Safety check - confirm this is the right disk
print_warning "This will read from ${SD_DEVICE}"
echo ""
diskutil list "${SD_DEVICE}"
echo ""
read -p "Is this the correct SD card? [y/N]: " CONFIRM_DISK

if [[ "${CONFIRM_DISK}" != "y" && "${CONFIRM_DISK}" != "Y" ]]; then
    print_error "Aborted by user"
    exit 1
fi

# ============================================================================
# STEP 4: Calculate optimal image size
# ============================================================================
print_step "4" "Calculate optimal image size"

print_info "Analyzing partition layout..."

# Get partition info
PART_INFO=$(diskutil list "${SD_DEVICE}")
echo "${PART_INFO}"
echo ""

# Find the last partition's end sector
# We need to capture only the used portion of the disk
# For a typical Pi SD card, we have:
#   - Partition 1: boot (FAT32, ~256MB)
#   - Partition 2: root (ext4, varies)

# Get the size of partition 2 (main Linux partition)
PARTITION_2="${SD_DEVICE}s2"
if [[ -e "${PARTITION_2}" ]]; then
    PART2_INFO=$(diskutil info "${PARTITION_2}" 2>/dev/null || true)
    PART2_SIZE_BYTES=$(echo "${PART2_INFO}" | grep "Disk Size" | head -1 | sed 's/.*(\([0-9]*\) Bytes).*/\1/' || echo "0")
    PART2_OFFSET_BYTES=$(echo "${PART2_INFO}" | grep "Partition Offset" | head -1 | sed 's/.*(\([0-9]*\) Bytes).*/\1/' || echo "0")

    if [[ ${PART2_SIZE_BYTES} -gt 0 && ${PART2_OFFSET_BYTES} -gt 0 ]]; then
        # Total needed = offset + size of last partition + buffer
        NEEDED_BYTES=$((PART2_OFFSET_BYTES + PART2_SIZE_BYTES + BUFFER_MB * 1024 * 1024))
        NEEDED_MB=$((NEEDED_BYTES / 1024 / 1024))

        print_info "Partition 2 offset: $((PART2_OFFSET_BYTES / 1024 / 1024)) MB"
        print_info "Partition 2 size: $((PART2_SIZE_BYTES / 1024 / 1024)) MB"
        print_info "Calculated image size needed: ${NEEDED_MB} MB (including ${BUFFER_MB} MB buffer)"
    else
        print_warning "Could not determine partition layout, using full disk size"
        NEEDED_MB=${DISK_SIZE_MB}
    fi
else
    print_warning "Could not find partition 2, using full disk size"
    NEEDED_MB=${DISK_SIZE_MB}
fi

# Cap at actual disk size
if [[ ${NEEDED_MB} -gt ${DISK_SIZE_MB} ]]; then
    NEEDED_MB=${DISK_SIZE_MB}
fi

echo ""
echo "Image will capture: ${NEEDED_MB} MB of ${DISK_SIZE_MB} MB total"
echo "Output file: ${IMAGE_FILE}"
echo ""

# ============================================================================
# STEP 5: Unmount and create image
# ============================================================================
print_step "5" "Create the disk image"

print_info "Unmounting disk partitions..."
diskutil unmountDisk "${SD_DEVICE}" || true

print_warning "Creating image - this will take several minutes"
echo "Source: ${RAW_DEVICE}"
echo "Target: ${IMAGE_FILE}"
echo "Size: ${NEEDED_MB} MB"
echo ""

# Calculate block count (1MB blocks)
BLOCK_COUNT=${NEEDED_MB}

# Create the image
sudo dd if="${RAW_DEVICE}" of="${IMAGE_FILE}" bs=1m count="${BLOCK_COUNT}" status=progress

print_success "Raw image created: ${IMAGE_FILE}"

# Get uncompressed size
UNCOMPRESSED_SIZE=$(ls -lh "${IMAGE_FILE}" | awk '{print $5}')
print_info "Uncompressed image size: ${UNCOMPRESSED_SIZE}"

# ============================================================================
# STEP 6: Compress the image
# ============================================================================
print_step "6" "Compress the image"

print_info "Compressing with gzip -9 (maximum compression)..."
echo "This may take several minutes..."
echo ""

gzip -9 -v "${IMAGE_FILE}"

print_success "Compression complete!"

# Get compressed size
COMPRESSED_SIZE=$(ls -lh "${COMPRESSED_FILE}" | awk '{print $5}')

# ============================================================================
# Summary
# ============================================================================
print_header "Image Creation Complete!"

echo ""
echo "Output file: ${COMPRESSED_FILE}"
echo ""
echo "Size summary:"
echo "  Original disk:     ${DISK_SIZE_MB} MB"
echo "  Captured:          ${NEEDED_MB} MB"
echo "  Uncompressed:      ${UNCOMPRESSED_SIZE}"
echo "  Compressed:        ${COMPRESSED_SIZE}"
echo ""
echo "To write this image to a new SD card:"
echo ""
echo "  # Using Raspberry Pi Imager (recommended):"
echo "  # 1. Open Raspberry Pi Imager"
echo "  # 2. Choose OS -> Use custom"
echo "  # 3. Select ${COMPRESSED_FILE}"
echo "  # 4. Choose storage -> Select your SD card"
echo "  # 5. Write"
echo ""
echo "  # Or using dd (advanced):"
echo "  gunzip -c ${COMPRESSED_FILE} | sudo dd of=/dev/diskN bs=1m status=progress"
echo ""

print_action "You can now safely eject the SD card and return it to the Pi"

print_success "Done!"
