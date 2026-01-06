# Creating LacyLights SD Card Images

This guide covers creating distributable SD card images for deploying LacyLights to new Raspberry Pi devices.

## Overview

Once you have a working LacyLights installation, you can create a compressed disk image that can be written to new SD cards. This enables rapid deployment of identical systems without running the full setup process each time.

## SD Card Size Recommendations

### For Creating Master Images: Use 16GB or 32GB Cards

**This is critical for efficient imaging.** The imaging process copies the entire SD card, and the size of the raw image equals the card size.

| Card Size | Raw Image | Compressed | Imaging Time | Recommendation |
|-----------|-----------|------------|--------------|----------------|
| 8GB       | 8GB       | ~2GB       | ~5 min       | Too small - system needs ~7GB |
| **16GB**  | **16GB**  | **~2-3GB** | **~10 min**  | **Recommended minimum** |
| **32GB**  | **32GB**  | **~2-3GB** | **~20 min**  | **Good balance** |
| 64GB      | 64GB      | ~2-3GB     | ~40 min      | Unnecessarily large |
| 128GB     | 128GB     | ~2-3GB     | ~80 min      | Too slow for imaging |

**Why not use a larger card and copy only part of it?**

ext4 filesystems don't store data contiguously. Files can be allocated anywhere in the partition. Copying only a portion of the disk (using `dd count=N`) will corrupt files whose data blocks are stored beyond the cutoff point.

### For Deployment: Any Size 16GB or Larger

The compressed image can be written to any card 16GB or larger. The filesystem automatically expands to fill the available space on first boot.

## Complete Workflow

### Step 1: Create a Master SD Card

Use a **16GB or 32GB** SD card for your master image.

```bash
# On your Mac, use Raspberry Pi Imager:
# 1. Choose OS: Raspberry Pi OS Lite (64-bit)
# 2. Choose Storage: Your 16GB/32GB SD card
# 3. Click the gear icon for advanced options:
#    - Set hostname: raspberrypi (will be changed to lacylights during setup)
#    - Enable SSH with your public key
#    - Configure WiFi if needed
#    - Set locale/timezone
# 4. Write the image
```

### Step 2: Initial Pi Setup

Insert the SD card into the Raspberry Pi and boot it up.

```bash
# From your development Mac, run the setup script
cd lacylights-rpi
./scripts/setup-new-pi.sh pi@raspberrypi.local
```

This script will:
- Configure the hostname to `lacylights`
- Install required system packages
- Set up the lacylights user and permissions
- Configure networking

### Step 3: Deploy LacyLights

```bash
# Deploy the application
./scripts/deploy.sh
```

This installs:
- Go backend server
- Next.js frontend
- Nginx reverse proxy
- systemd services

### Step 4: Verify the Installation

```bash
# Test from your Mac
open http://lacylights.local/
```

Verify:
- Web interface loads
- Can create/edit scenes
- DMX output works (if you have fixtures connected)

### Step 5: Create the Disk Image

Once you have a verified working installation:

```bash
# Run the image creation script
./scripts/create-image.sh
```

The script will:
1. **Validate** - Check system configuration is correct
2. **Prepare** - Stop services, clean caches, zero free space
3. **Shutdown** - Safely shut down the Pi
4. **Detect** - Find the SD card when inserted in Mac
5. **Image** - Create raw disk image with `dd`
6. **Compress** - Compress with `gzip -9`

Output files:
- `~/Desktop/lacylights-YYYYMMDD-HHMMSS.img.gz` - Compressed image (~2-3GB)
- `~/Desktop/lacylights-YYYYMMDD-HHMMSS.img.gz.sha256` - Checksum file

## Writing Images to New Cards

### Using Raspberry Pi Imager (Recommended)

1. Open Raspberry Pi Imager
2. Choose OS → Use custom → Select your `.img.gz` file
3. Choose Storage → Select target SD card
4. Click Write

The imager automatically:
- Decompresses the image
- Writes to the card
- Verifies the write

### Using Command Line

```bash
# Find your SD card device
diskutil list

# Unmount the card (replace diskN with actual disk number)
diskutil unmountDisk /dev/diskN

# Write the image (this will take several minutes)
gunzip -c ~/Desktop/lacylights-*.img.gz | sudo dd of=/dev/rdiskN bs=1m status=progress

# Eject
diskutil eject /dev/diskN
```

## First Boot on New Card

When booting a new card created from the image:

1. Insert the card into a Raspberry Pi
2. Connect power
3. Wait ~2 minutes for first boot (filesystem expansion happens automatically)
4. Access at http://lacylights.local/

**Note:** If using a card larger than the master (e.g., writing 16GB image to 128GB card), the filesystem automatically expands to use all available space.

## Troubleshooting

### Image creation fails with "Sudoers file is corrupted"

The system configuration is invalid. Redeploy to fix:
```bash
./scripts/deploy.sh
```

### Compressed image is larger than expected

Free space wasn't properly zeroed. Run the full process from step 1:
```bash
./scripts/create-image.sh --start-from-step 1
```

### Services don't start on new card

Check the journal for errors:
```bash
ssh pi@lacylights.local
journalctl -u lacylights -n 50
```

### Hostname not resolving

mDNS may take a minute to propagate. Try:
```bash
# Wait and retry
ping lacylights.local

# Or use IP address directly
ssh pi@<ip-address>
```

## Best Practices

1. **Use a dedicated master card** - Keep a 16GB or 32GB card specifically for creating images
2. **Test before imaging** - Always verify the installation works before creating an image
3. **Version your images** - The script timestamps images automatically
4. **Keep checksums** - Store `.sha256` files with images for verification
5. **Document changes** - Note what's different in each image version

## Script Reference

```bash
# Full process from step 1
./scripts/create-image.sh

# Skip Pi preparation (if already done)
./scripts/create-image.sh --start-from-step 3

# Use specific SD card device
./scripts/create-image.sh --device /dev/disk8

# See all options
./scripts/create-image.sh --help
```
