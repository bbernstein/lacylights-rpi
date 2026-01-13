# LacyLights RPi

Raspberry Pi deployment and setup tools for [LacyLights](https://github.com/bbernstein/lacylights) stage lighting control system.

## Overview

This repository contains everything needed to deploy and run LacyLights on Raspberry Pi hardware as a turnkey stage lighting solution.

**What is LacyLights?**

LacyLights is a complete stage lighting control system with:
- DMX/Art-Net protocol support for professional lighting fixtures
- Web-based interface for look creation and cue management
- WiFi configuration for internet connectivity
- Real-time lighting control and playback

> **Note:** AI-powered lighting design via MCP server is available on macOS via the [lacylights-mac](https://github.com/bbernstein/lacylights-mac) application. The RPi distribution focuses on turnkey hardware deployment.

## Quick Start

### One-Command Installation (Recommended)

**For a fresh Raspberry Pi, run this single command directly on the Pi:**

```bash
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash && \
    cd ~/lacylights-setup && \
    sudo bash scripts/setup-local-pi.sh
```

That's it! This will:
1. Download the latest release from dist.lacylights.com
2. Verify download integrity with SHA256 checksum
3. Configure the system (hostname, packages, swap)
4. Set up networking (ethernet + WiFi)
5. Install and configure PostgreSQL
6. Deploy LacyLights (backend, frontend)
7. Start the service

After completion, access LacyLights at: **http://lacylights.local**

**Prerequisites:** Fresh Raspberry Pi with internet connection. If you get SSL certificate errors:
```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl
```

See [INSTALLATION_PREREQUISITES.md](docs/INSTALLATION_PREREQUISITES.md) for troubleshooting.

### Options for Single-Command Setup

The `setup-local-pi.sh` script supports several options:

```bash
# Specify component versions
sudo bash scripts/setup-local-pi.sh \
    --backend-version v1.1.0 \
    --frontend-version v0.2.0

# Configure WiFi during setup
sudo bash scripts/setup-local-pi.sh \
    --wifi-ssid "MyNetwork" \
    --wifi-password "mypassword"

# Skip WiFi configuration prompts
sudo bash scripts/setup-local-pi.sh --skip-wifi
```

### Alternative: Git Clone Method

If you prefer to clone the repository first:

```bash
# Update CA certificates and install git
sudo apt-get update && sudo apt-get install -y ca-certificates curl git

# Clone repository
git clone https://github.com/bbernstein/lacylights-rpi.git
cd lacylights-rpi

# Run complete setup
sudo bash scripts/setup-local-pi.sh
```

### Remote Installation (From Your Development Machine)

If you want to install from your computer to a remote Pi:

```bash
# From your development machine, run the setup script with the Pi's hostname
# This script will SSH to the Pi and run all setup steps automatically
cd lacylights-rpi  # Clone the repo on your machine first
./scripts/setup-new-pi.sh pi@raspberrypi.local
```

Or use the automated installer:

```bash
# From your development machine
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | \
    bash -s -- latest pi@raspberrypi.local
```

Then access your LacyLights at: **http://lacylights.local**

### Alternative Methods

**Option A: Git Clone (Most Reliable)**

This method always works and doesn't depend on GitHub's CDN cache:

```bash
# First, update CA certificates
sudo apt-get update && sudo apt-get install -y ca-certificates curl git

# Clone repository
git clone https://github.com/bbernstein/lacylights-rpi.git
cd lacylights-rpi

# Run setup scripts directly (since you're already on the Pi)
sudo ./setup/01-system-setup.sh
sudo ./setup/02-network-setup.sh
sudo ./setup/03-database-setup.sh
sudo ./setup/04-permissions-setup.sh
sudo ./setup/05-service-install.sh
```

**Option B: Direct Download (If Git Not Available)**

```bash
# Download and extract
mkdir -p ~/lacylights-setup
cd ~/lacylights-setup
curl -fsSL https://github.com/bbernstein/lacylights-rpi/archive/refs/heads/main.tar.gz | tar xz --strip-components=1

# Run setup scripts directly (since you're already on the Pi)
sudo ./setup/01-system-setup.sh
sudo ./setup/02-network-setup.sh
sudo ./setup/03-database-setup.sh
sudo ./setup/04-permissions-setup.sh
sudo ./setup/05-service-install.sh
```

**For Development:** Specify specific component versions:
```bash
./scripts/setup-new-pi.sh localhost \
    --backend-version v1.1.0 \
    --frontend-version v0.2.0
```

### Deploying Updates

After making code changes to any LacyLights repository:

```bash
cd lacylights-rpi
./scripts/deploy.sh
```

That's it! The script handles type checking, syncing, building, and restarting.

## Installation Options

### Option 1: One-Command Install (Recommended)

Download and install a release with a single command. The installer automatically fetches releases from **dist.lacylights.com**, our AWS-based distribution platform:

```bash
# Install latest release (fetches metadata from dist.lacylights.com/releases/rpi/latest.json)
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash

# Install specific version (downloads from dist.lacylights.com)
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash -s -- v0.1.1

# Remote installation from your development machine
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | \
    bash -s -- latest pi@raspberrypi.local
```

**Benefits of the AWS distribution:**
- ✅ Fast, reliable downloads from CloudFront CDN
- ✅ Automatic SHA256 checksum verification for all versions
- ✅ Always get the latest stable release
- ✅ No GitHub API rate limits

**Alternative: Download directly from AWS distribution:**
```bash
# Download install script from AWS distribution
curl -fsSL https://dist.lacylights.com/releases/rpi/install.sh | bash
```

### Option 2: Git Clone (For Development)

Clone the repository if you plan to modify deployment scripts or contribute:

```bash
git clone https://github.com/bbernstein/lacylights-rpi.git
cd lacylights-rpi
./scripts/setup-new-pi.sh pi@raspberrypi.local
```

## Releases and Versioning

### Release Types

LacyLights RPi uses semantic versioning with two types of releases:

**Stable Releases** (e.g., `v0.1.6`)
- Production-ready versions
- Automatically distributed via `install.sh`
- Downloaded with: `curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash`
- Verified with SHA256 checksums
- Recommended for production use

**Beta Releases** (e.g., `v0.1.7b1`, `v0.1.7b2`)
- Pre-release testing versions
- Require manual download from dist.lacylights.com
- Not auto-installed via `install.sh` (security feature)
- Perfect for testing new features before stable release
- Multiple betas can exist for the same target version

### Current Version

Latest stable release: **v0.1.6**

View all releases: [GitHub Releases](https://github.com/bbernstein/lacylights-rpi/releases)

### Installing Specific Versions

**Latest Stable (Recommended):**
```bash
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash
```

**Specific Stable Version:**
```bash
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash -s -- v0.1.6
```

**Beta Version (Manual Download Required):**
```bash
# Download specific beta
curl -fsSL https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7b1.tar.gz -o lacylights-beta.tar.gz

# Extract to installation directory
rm -rf ~/lacylights-setup
mkdir -p ~/lacylights-setup
tar xzf lacylights-beta.tar.gz -C ~/lacylights-setup
chmod +x ~/lacylights-setup/scripts/*.sh
chmod +x ~/lacylights-setup/setup/*.sh
chmod +x ~/lacylights-setup/utils/*.sh

# Run setup
cd ~/lacylights-setup
sudo ./scripts/setup-local-pi.sh
```

**Why Beta Versions Require Manual Download:**
- Prevents accidental installation of pre-release versions
- Ensures beta testers are intentionally opting in
- Maintains stability for production users
- Security best practice for testing software

### Version Format

- **Stable:** `vMAJOR.MINOR.PATCH` (e.g., `v0.1.6`)
- **Beta:** `vMAJOR.MINOR.PATCHb[N]` (e.g., `v0.1.7b1`)

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR** (X.0.0): Breaking changes requiring user action
- **MINOR** (0.X.0): New features, backward compatible
- **PATCH** (0.0.X): Bug fixes and small improvements

### Distribution Infrastructure

All releases are distributed via AWS-powered infrastructure:

- **S3 Bucket:** Fast, reliable downloads from CloudFront CDN
- **SHA256 Verification:** All versions include checksums
- **DynamoDB Metadata:** Programmatic access to release information
- **No GitHub API Rate Limits:** Direct downloads, no throttling

**Metadata URLs:**
```bash
# Latest stable release metadata
curl https://dist.lacylights.com/releases/rpi/latest.json

# Specific version metadata
curl https://dist.lacylights.com/releases/rpi/0.1.6.json

# Beta version metadata
curl https://dist.lacylights.com/releases/rpi/0.1.7b1.json
```

For maintainers creating releases, see [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md).

## What's Included

This repository provides:

### Deployment Scripts

- **`scripts/deploy.sh`** - General-purpose deployment for all code changes
- **`scripts/setup-new-pi.sh`** - Complete setup for fresh Raspberry Pi

### System Configuration

- **`systemd/`** - systemd service files for automatic startup
- **`config/`** - Configuration templates (.env, sudoers, etc.)

### Setup Modules

Modular setup scripts in `setup/`:
- `01-system-setup.sh` - Install dependencies (Node.js, NetworkManager, etc.)
- `02-network-setup.sh` - Configure networking and hostname
- `03-database-setup.sh` - Create database and user
- `04-permissions-setup.sh` - Set up system user and permissions
- `05-service-install.sh` - Install and enable systemd service

### Utilities

Diagnostic and maintenance tools in `utils/`:
- **`check-health.sh`** - Comprehensive system health check
- **`view-logs.sh`** - Easy log viewing with filtering
- **`network-diagnostic.sh`** - Network connectivity troubleshooting
- **`wifi-diagnostic.sh`** - WiFi troubleshooting and diagnostics

### Documentation

Complete guides in `docs/`:
- [DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deploying code changes
- [INITIAL_SETUP.md](docs/INITIAL_SETUP.md) - Fresh installation guide
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [WIFI_SETUP.md](docs/WIFI_SETUP.md) - WiFi configuration guide
- [UPDATING.md](docs/UPDATING.md) - System and package updates

## Prerequisites

### Hardware

- **Raspberry Pi 4** (4GB+ RAM recommended)
- **MicroSD card** (32GB+ Class 10 or better)
- **Power supply** (official 5V 3A recommended)
- **Ethernet cable** for wired DMX network
- Built-in WiFi for internet access

### Software on Pi

- Raspberry Pi OS (64-bit, Lite or Desktop)
- SSH enabled
- Internet connection for initial setup
- **Important**: Updated CA certificates (see [INSTALLATION_PREREQUISITES.md](docs/INSTALLATION_PREREQUISITES.md))

**First-time setup checklist:**
```bash
# Update CA certificates to avoid SSL errors
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Verify system time is correct
date

# Test internet connectivity
ping -c 3 google.com
```

See [INSTALLATION_PREREQUISITES.md](docs/INSTALLATION_PREREQUISITES.md) for complete setup guide and troubleshooting.

### Software on Development Machine

- macOS, Linux, or Windows with WSL
- Git
- SSH client
- This repository cloned: [lacylights-rpi](https://github.com/bbernstein/lacylights-rpi)

**For fresh installation:** Release archives are downloaded directly from GitHub to the Pi during setup (no git repositories).

**For development workflow:** Clone the application repositories locally:
  - [lacylights-go](https://github.com/bbernstein/lacylights-go) (Go backend - recommended)
  - [lacylights-fe](https://github.com/bbernstein/lacylights-fe) (frontend)

**Recommended directory structure for development:**
```
~/src/lacylights/
├── lacylights-go/      # Go backend repository (for development)
├── lacylights-fe/      # Frontend repository (for development)
└── lacylights-rpi/     # This repository (deployment tools)
```

## Repository Structure

```
lacylights-rpi/
├── README.md                 # This file
├── scripts/
│   ├── deploy.sh             # General deployment script
│   └── setup-new-pi.sh       # New Pi setup script
├── systemd/
│   └── lacylights.service    # Systemd service definition
├── config/
│   ├── .env.example          # Environment variables template
│   └── sudoers.d/
│       └── lacylights        # WiFi management permissions
├── setup/
│   ├── 01-system-setup.sh           # Install system packages
│   ├── 02-network-setup.sh          # Configure network
│   ├── 03-database-setup.sh         # Setup SQLite database
│   ├── 04-permissions-setup.sh      # User and permissions
│   └── 05-service-install.sh        # Install systemd service
├── utils/
│   ├── check-health.sh              # Health check tool
│   ├── view-logs.sh                 # Log viewer
│   └── wifi-diagnostic.sh           # WiFi diagnostics
└── docs/
    ├── DEPLOYMENT.md                # Deployment guide
    ├── INITIAL_SETUP.md             # Setup guide
    ├── TROUBLESHOOTING.md           # Troubleshooting
    ├── WIFI_SETUP.md                # WiFi guide
    └── UPDATING.md                  # Update guide
```

## Common Tasks

### Deploy All Components

```bash
./scripts/deploy.sh
```

### Deploy Specific Component

```bash
./scripts/deploy.sh --backend-only
./scripts/deploy.sh --frontend-only
```

### Check System Health

```bash
ssh pi@lacylights.local '~/lacylights-setup/utils/check-health.sh'
```

### View Logs

```bash
# Follow logs in real-time
ssh pi@lacylights.local '~/lacylights-setup/utils/view-logs.sh'

# Show last 100 lines
ssh pi@lacylights.local '~/lacylights-setup/utils/view-logs.sh -n 100'

# Show only errors
ssh pi@lacylights.local '~/lacylights-setup/utils/view-logs.sh -e'
```

### Check Network

```bash
# General network diagnostics
ssh pi@lacylights.local '~/lacylights-setup/utils/network-diagnostic.sh'

# WiFi-specific diagnostics
ssh pi@lacylights.local '~/lacylights-setup/utils/wifi-diagnostic.sh'
```

### Restart Service

```bash
ssh pi@lacylights.local 'sudo systemctl restart lacylights'
```

## Network Architecture

LacyLights uses an **intelligent dual-network setup** that automatically routes traffic appropriately:

### Wired Network (eth0) - Local DMX Network
- **Purpose:** DMX/Art-Net lighting control (local only)
- **Configuration:** DHCP or static IP
- **Broadcast:** Configurable in settings (e.g., 192.168.1.255)
- **Usage:** Communication with DMX lighting fixtures
- **Routing:** Low priority for internet (high metric = 200)

### Wireless Network (wlan0) - Internet Gateway
- **Purpose:** External internet access
- **Configuration:** Web interface or command line (any SSID)
- **Usage:** AI model access (OpenAI, Claude), system updates, GitHub downloads
- **Routing:** High priority for internet (low metric = 100)
- **Setup:** See [WIFI_SETUP.md](docs/WIFI_SETUP.md)

### Automatic Route Management

The system automatically configures routing priorities:
- **Internet traffic** → Always routes through WiFi (when connected)
- **Local DMX traffic** → Always routes through Ethernet
- **Works standalone** → Operates on local network without WiFi
- **No hardcoding** → Works with any WiFi network configured by user

This is handled by a NetworkManager dispatcher script that automatically sets route metrics whenever a network interface changes state.

## Environment Variables

Key configuration in `/opt/lacylights/backend/.env`:

```bash
# Database (SQLite)
DATABASE_URL="file:./prisma/lacylights.db"

# Server
PORT=4000
NODE_ENV=production

# DMX/Art-Net
ARTNET_ENABLED=true
ARTNET_BROADCAST=192.168.1.255
DMX_UNIVERSE_COUNT=4

# WiFi
WIFI_ENABLED=true
WIFI_DEVICE=wlan0
```

See [config/.env.example](config/.env.example) for all options.

## System Layout

### File Locations

- **Application:** `/opt/lacylights/`
  - Backend: `/opt/lacylights/backend/`
  - Frontend: `/opt/lacylights/frontend-src/`
- **Configuration:** `/opt/lacylights/backend/.env`
- **Service:** `/etc/systemd/system/lacylights.service`
- **Sudoers:** `/etc/sudoers.d/lacylights`
- **Setup scripts:** `~/lacylights-setup/`

### System User

- **User:** `lacylights` (system user, no login)
- **Group:** `lacylights`
- **Permissions:** WiFi management via sudo (no password)

## Development Workflow

### Typical Development Cycle

1. **Make changes locally**
   ```bash
   cd lacylights-go  # Go backend
   # Edit code
   git add .
   git commit -m "Add: new feature"
   ```

2. **Build and test locally**
   ```bash
   make build
   make test
   ```

3. **Deploy to Pi**
   ```bash
   cd ../lacylights-rpi
   ./scripts/deploy.sh
   ```

4. **Test on Pi**
   - Open http://lacylights.local
   - Test changes
   - Check logs if needed

5. **Push to GitHub**
   ```bash
   cd ../lacylights-go
   git push origin main
   ```

### Quick Iteration

For rapid development:

```bash
# Build locally and sync to Pi
./scripts/deploy.sh

# When ready, restart service on Pi
ssh pi@lacylights.local
sudo systemctl restart lacylights
```

Note: The Go backend is a pre-compiled binary, so there's no build step on the Pi.

## Troubleshooting

### Can't Connect to Pi

```bash
# Try IP address instead of hostname
ping 192.168.1.100  # Your Pi's IP

# Or find Pi on network
nmap -sn 192.168.1.0/24 | grep -i raspberry

# Connect using IP
PI_HOST=pi@192.168.1.100 ./scripts/deploy.sh
```

### Service Won't Start

```bash
# Check status
ssh pi@lacylights.local 'sudo systemctl status lacylights'

# View logs
ssh pi@lacylights.local 'sudo journalctl -u lacylights -n 50'

# Common fixes
ssh pi@lacylights.local << 'EOF'
  # Check binary exists and is executable
  ls -la /opt/lacylights/backend/lacylights-server

  # Ensure correct permissions
  sudo chown lacylights:lacylights /opt/lacylights/backend/lacylights-server
  sudo chmod +x /opt/lacylights/backend/lacylights-server

  # Restart service
  sudo systemctl restart lacylights
EOF
```

### Build Fails

```bash
# For Go backend, check build locally first
cd lacylights-go
make build
make test

# Then retry deployment
```

For more issues, see [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## Security

### Default Security Measures

- ✅ Dedicated system user (not root)
- ✅ Random database password
- ✅ Limited sudo access (WiFi only)
- ✅ systemd security restrictions

### Additional Hardening (Optional)

```bash
# Enable firewall
ssh pi@lacylights.local
sudo apt-get install ufw
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 4000/tcp  # GraphQL
sudo ufw enable

# Change default password
passwd

# Setup SSH keys (disable password auth)
ssh-copy-id pi@lacylights.local
```

## Backup and Recovery

### Quick Backup

```bash
ssh pi@lacylights.local

# Backup database
cp /opt/lacylights/backend/prisma/lacylights.db ~/lacylights-backup.db

# Backup config
sudo cp /opt/lacylights/backend/.env ~/lacylights-config.backup

# Download to local machine
scp pi@lacylights.local:~/lacylights-* ./backups/
```

### Restore from Backup

```bash
# Upload backup
scp ./backups/lacylights-backup.sql pi@lacylights.local:~/

# Restore
ssh pi@lacylights.local
sudo systemctl stop lacylights
cp ~/lacylights-backup.db /opt/lacylights/backend/prisma/lacylights.db
sudo chown lacylights:lacylights /opt/lacylights/backend/prisma/lacylights.db
sudo systemctl start lacylights
```

## Creating Distributable Images

Once you have a working LacyLights installation, you can create compressed SD card images for deploying to new devices.

### Important: Use the Right SD Card Size

**For creating master images, use a 16GB or 32GB SD card.** The imaging process copies the entire card, so:

| Card Size | Imaging Time | Recommendation |
|-----------|--------------|----------------|
| 16GB      | ~10 min      | **Recommended** |
| 32GB      | ~20 min      | Good balance |
| 128GB     | ~80 min      | Too slow |

The compressed image (~2-3GB) can be written to any card 16GB or larger.

### Quick Start

```bash
# Create an image from a working Pi (on your Mac)
./scripts/create-image.sh
```

The script will guide you through:
1. Preparing the Pi (stop services, zero free space)
2. Shutting down and transferring the SD card
3. Creating and compressing the image

**Output:** `~/Desktop/lacylights-YYYYMMDD-HHMMSS.img.gz`

📖 **See [docs/IMAGE_CREATION.md](docs/IMAGE_CREATION.md) for the complete guide**

## Contributing

This is a deployment repository. For application code contributions:

- Go Backend: [lacylights-go](https://github.com/bbernstein/lacylights-go) (recommended)
- Frontend: [lacylights-fe](https://github.com/bbernstein/lacylights-fe)

For deployment tooling improvements, open an issue or PR in this repository.

### For Maintainers: Creating Releases

To create releases, you need to set up a `RELEASE_TOKEN` secret first:

📖 **See [docs/RELEASE_TOKEN_SETUP.md](docs/RELEASE_TOKEN_SETUP.md) for setup instructions**

Once configured, create releases via GitHub Actions:
1. Go to Actions → Create Release
2. Select version bump type (patch/minor/major)
3. Choose stable or beta (prerelease) release
4. Run workflow

**Release Types:**
- **Stable Releases** (e.g., `v0.1.6`): Production-ready, automatically distributed via install.sh
- **Beta Releases** (e.g., `v0.1.7b1`): Pre-release testing versions, require manual download

📖 **See [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md) for detailed release process guide**
📖 **See [docs/RELEASES.md](docs/RELEASES.md) for release management overview**

## Documentation

- **Getting Started:**
  - [INSTALLATION_PREREQUISITES.md](docs/INSTALLATION_PREREQUISITES.md) - Prerequisites and common issues (read this first!)
  - [INITIAL_SETUP.md](docs/INITIAL_SETUP.md) - First-time setup
  - [DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deploying changes

- **Configuration:**
  - [WIFI_SETUP.md](docs/WIFI_SETUP.md) - WiFi configuration
  - [config/.env.example](config/.env.example) - Environment variables

- **Distribution:**
  - [IMAGE_CREATION.md](docs/IMAGE_CREATION.md) - Creating distributable SD card images

- **Maintenance:**
  - [UPDATING.md](docs/UPDATING.md) - System updates
  - [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues

- **Release Management (Maintainers):**
  - [RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md) - Complete release process guide (stable and beta)
  - [RELEASES.md](docs/RELEASES.md) - Release management overview
  - [RELEASE_TOKEN_SETUP.md](docs/RELEASE_TOKEN_SETUP.md) - Setting up release automation token

- **Scripts:**
  - [scripts/deploy.sh](scripts/deploy.sh) - Deployment script
  - [scripts/setup-new-pi.sh](scripts/setup-new-pi.sh) - Setup script
  - [install.sh](install.sh) - One-command installer

## Backend

LacyLights uses a Go backend for optimal performance on Raspberry Pi:

- **Performance**: Fast startup, low memory usage (~256MB)
- **Deployment**: Single compiled binary, no runtime dependencies
- **Reliability**: Production-ready, battle-tested

## Related Repositories

- [lacylights](https://github.com/bbernstein/lacylights) - Main documentation
- [lacylights-go](https://github.com/bbernstein/lacylights-go) - Go Backend (GraphQL, DMX, Database)
- [lacylights-fe](https://github.com/bbernstein/lacylights-fe) - Frontend (React, Next.js)
- [lacylights-mac](https://github.com/bbernstein/lacylights-mac) - macOS Application (includes MCP/AI integration)

## License

See individual component repositories for license information.

## Support

- **Documentation:** Check [docs/](docs/) directory
- **Issues:** Open an issue in the relevant repository
- **Diagnostics:** Run `utils/check-health.sh` on the Pi

## Quick Reference

### Useful URLs
- Web Interface: http://lacylights.local
- GraphQL Playground: http://lacylights.local:4000/graphql (if enabled)

### Useful Commands
```bash
# Deployment
./scripts/deploy.sh                                    # Deploy all
./scripts/deploy.sh --backend-only                     # Deploy backend only

# System
ssh pi@lacylights.local 'sudo systemctl status lacylights'     # Check status
ssh pi@lacylights.local 'sudo systemctl restart lacylights'    # Restart
ssh pi@lacylights.local 'sudo reboot'                          # Reboot Pi

# Logs
ssh pi@lacylights.local 'sudo journalctl -u lacylights -f'     # Follow logs
ssh pi@lacylights.local '~/lacylights-setup/utils/view-logs.sh -e'  # View errors

# Health & Diagnostics
ssh pi@lacylights.local '~/lacylights-setup/utils/check-health.sh'       # Health check
ssh pi@lacylights.local '~/lacylights-setup/utils/network-diagnostic.sh' # Network check
ssh pi@lacylights.local '~/lacylights-setup/utils/wifi-diagnostic.sh'    # WiFi check

# Database
ssh pi@lacylights.local 'sqlite3 /opt/lacylights/backend/prisma/lacylights.db'  # Connect to DB
ssh pi@lacylights.local 'cp /opt/lacylights/backend/prisma/lacylights.db ~/backup.db'  # Backup
```

---

**Happy Lighting! 🎭**
