# Offline Setup Guide

This guide explains how to set up LacyLights on a Raspberry Pi that has **no internet access** after initial preparation.

## Overview

The LacyLights offline setup process has two phases:

1. **Preparation Phase**: Run once with internet access to install system dependencies
2. **Deployment Phase**: Can be run repeatedly without internet access

## Why Two Phases?

System packages (Node.js, NetworkManager, build tools) must be installed from Debian/Ubuntu repositories and cannot be bundled easily. However, once these are installed, all subsequent deployments can happen offline.

## Phase 1: Preparing the Raspberry Pi (Requires Internet)

### Option A: Use Raspberry Pi Imager (Recommended)

The easiest approach is to prepare the base system before disconnecting from the internet:

1. **Flash Raspberry Pi OS** with recommended packages:
   - Use Raspberry Pi Imager
   - Select "Raspberry Pi OS (64-bit)" with Desktop (includes more packages by default)
   - Configure SSH, hostname, and user in the imager settings

2. **Boot and connect to internet temporarily**:
   ```bash
   # Connect via Ethernet or WiFi
   # SSH into the Pi
   ssh pi@raspberrypi.local
   ```

3. **Install required system packages**:
   ```bash
   # Update package lists
   sudo apt-get update

   # Install Node.js 20
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
   sudo apt-get install -y nodejs

   # Install NetworkManager
   sudo apt-get install -y network-manager

   # Install build tools
   sudo apt-get install -y build-essential git curl

   # Optional: Install nginx
   sudo apt-get install -y nginx
   ```

4. **Verify installation**:
   ```bash
   node -v      # Should show v20.x.x or later
   npm -v       # Should show npm version
   nmcli --version  # Should show NetworkManager version
   gcc --version    # Should show gcc version
   ```

5. **Disconnect from internet**: Now the Pi is ready for offline deployment!

### Option B: Pre-configured Image

Create a "golden image" with all dependencies pre-installed:

1. Complete Option A above
2. Create an image backup:
   ```bash
   # On your Mac/PC
   sudo dd if=/dev/sdX of=lacylights-prepared.img bs=4M status=progress
   ```
3. Use this image for all future Pi installations

## Phase 2: Offline Deployment (No Internet Required)

Once the Pi is prepared, you can deploy LacyLights completely offline:

### From Your Mac/PC (with internet)

```bash
# Your Mac needs internet to download the code
# The Pi does NOT need internet

cd lacylights-rpi
./scripts/deploy-offline.sh ntclights.local
```

This will:
1. Download LacyLights code from GitHub (on your Mac)
2. Download npm dependencies (on your Mac)
3. **Build all projects on your Mac** (much faster than Pi)
4. Create an offline bundle with pre-built artifacts
5. Transfer everything to the Pi
6. Install without any internet access on the Pi (only rebuilds native modules)

### What Gets Transferred

The offline bundle includes:
- ✅ Backend code (lacylights-node) - **pre-built on Mac**
- ✅ Frontend code (lacylights-fe) - **pre-built on Mac**
- ✅ MCP server code (lacylights-mcp) - **pre-built on Mac**
- ✅ All npm dependencies pre-downloaded
- ✅ Pre-built artifacts (dist/, .next/)
- ✅ Configuration files
- ✅ Setup scripts

The bundle does NOT include:
- ❌ System packages (Node.js, NetworkManager, etc.) - must be pre-installed
- ❌ Raspberry Pi OS updates - use prepared image

**Build Performance**: All TypeScript compilation and bundling happens on your Mac, avoiding the slow build process on the Pi's limited CPU. The Pi only rebuilds native modules for ARM compatibility.

## Quick Reference

### Required Pre-installed Packages

For offline deployment to work, the Pi must have:

| Package | Version | Check Command |
|---------|---------|---------------|
| Node.js | 18+ | `node -v` |
| npm | Any | `npm -v` |
| NetworkManager | Any | `nmcli --version` |
| gcc | Any | `gcc --version` |
| make | Any | `make --version` |
| git | Any | `git --version` |
| curl | Any | `curl --version` |
| nginx | Any (optional) | `nginx -v` |

### Preparation Checklist

- [ ] Raspberry Pi OS installed and booted
- [ ] Connected to internet temporarily
- [ ] Node.js 20 installed from nodesource
- [ ] NetworkManager installed
- [ ] Build tools installed (build-essential, git, curl)
- [ ] (Optional) Nginx installed
- [ ] Verification commands all pass
- [ ] Internet disconnected

### Deployment Checklist

- [ ] Your Mac/PC has internet access
- [ ] You can SSH to the Pi (via local network)
- [ ] Pi has required packages pre-installed
- [ ] Run `./scripts/deploy-offline.sh <pi-hostname>`

## Troubleshooting

### "Node.js is not installed"

The Pi needs Node.js pre-installed. Connect to internet temporarily and run:
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs
```

### "NetworkManager is not installed"

The Pi needs NetworkManager pre-installed. Connect to internet temporarily and run:
```bash
sudo apt-get update
sudo apt-get install -y network-manager
```

### "Missing build tools"

The Pi needs build tools pre-installed. Connect to internet temporarily and run:
```bash
sudo apt-get update
sudo apt-get install -y build-essential git curl
```

### "Cannot reach github.com" (on Mac/PC)

Your Mac/PC needs internet access to download the LacyLights code and create the offline bundle. The Pi does not need internet, but your development machine does.

### npm install fails on Pi

If npm install fails during offline deployment:

1. Check that Node.js is installed: `node -v`
2. Check that npm is installed: `npm -v`
3. Verify the offline bundle includes node_modules
4. Try rebuilding native modules: `npm rebuild`

## Advanced: Fully Air-Gapped Setup

For completely air-gapped environments (no internet on Mac/PC either):

1. **On a machine with internet**:
   ```bash
   # Download everything
   ./scripts/prepare-offline.sh

   # This creates: lacylights-offline-YYYYMMDD-HHMMSS.tar.gz
   ```

2. **Transfer the bundle** to your Mac/PC via USB drive

3. **On your Mac/PC** (no internet needed):
   ```bash
   # Use the pre-created bundle
   ./scripts/setup-new-pi.sh pi@ntclights.local \
       --offline-bundle lacylights-offline-20251028-120000.tar.gz
   ```

## Network Configuration

The offline setup works with:

- **Wired connection only**: Pi connected via Ethernet to local network
- **WiFi after setup**: Configure WiFi through the web interface after LacyLights is running
- **No internet required**: Pi operates on local network only
- **Your Mac connects via SSH**: Must be on same local network as Pi

## See Also

- [OFFLINE_INSTALLATION.md](OFFLINE_INSTALLATION.md) - Technical details about offline installation
- [INITIAL_SETUP.md](INITIAL_SETUP.md) - Standard online setup process
- [DEPLOYMENT.md](DEPLOYMENT.md) - Regular deployment workflow
