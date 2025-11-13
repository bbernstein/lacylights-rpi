# LacyLights RPi

Raspberry Pi deployment and setup tools for [LacyLights](https://github.com/bbernstein/lacylights) stage lighting control system.

## Overview

This repository contains everything needed to deploy and run LacyLights on Raspberry Pi hardware as a turnkey stage lighting solution.

**What is LacyLights?**

LacyLights is a complete stage lighting control system with:
- DMX/Art-Net protocol support for professional lighting fixtures
- Web-based interface for scene creation and cue management
- AI-powered lighting design via MCP server integration
- WiFi configuration for internet connectivity
- Real-time lighting control and playback

## Quick Start

### New Installation (One-Command Setup)

For a fresh Raspberry Pi, use our one-command installer:

```bash
# On your Raspberry Pi (SSH in first):
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash

# Then run the setup:
cd ~/lacylights-setup
./scripts/setup-new-pi.sh localhost
```

**Or install remotely from your development machine:**

```bash
# This will download, install, and set up everything on your Pi
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | \
    bash -s -- latest pi@raspberrypi.local

# Then complete the setup
ssh pi@raspberrypi.local
cd ~/lacylights-setup
./scripts/setup-new-pi.sh localhost
```

Then access your LacyLights at: **http://lacylights.local**

### Alternative: Git Clone Method

If you prefer to clone the repository for development:

```bash
# Clone this repository
git clone https://github.com/bbernstein/lacylights-rpi.git
cd lacylights-rpi

# Run complete setup (takes 15-20 minutes)
./scripts/setup-new-pi.sh pi@raspberrypi.local

# Or specify specific versions:
./scripts/setup-new-pi.sh pi@raspberrypi.local \
    --backend-version v1.1.0 \
    --frontend-version v0.2.0 \
    --mcp-version v1.0.0
```

**Note:** The setup script downloads release archives directly from GitHub to the Pi (no git repositories created), so you don't need to have them cloned locally.

### Deploying Updates

After making code changes to any LacyLights repository:

```bash
cd lacylights-rpi
./scripts/deploy.sh
```

That's it! The script handles type checking, syncing, building, and restarting.

## Installation Options

### Option 1: One-Command Install (Recommended)

Download and install a specific release with a single command:

```bash
# Install latest release
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash

# Install specific version
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash -s -- v1.0.0

# Remote installation from your development machine
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | \
    bash -s -- latest pi@raspberrypi.local
```

### Option 2: Git Clone (For Development)

Clone the repository if you plan to modify deployment scripts or contribute:

```bash
git clone https://github.com/bbernstein/lacylights-rpi.git
cd lacylights-rpi
./scripts/setup-new-pi.sh pi@raspberrypi.local
```

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

### Software on Development Machine

- macOS, Linux, or Windows with WSL
- Git
- SSH client
- This repository cloned: [lacylights-rpi](https://github.com/bbernstein/lacylights-rpi)

**For fresh installation:** Release archives are downloaded directly from GitHub to the Pi during setup (no git repositories).

**For development workflow:** Clone the application repositories locally:
  - [lacylights-node](https://github.com/bbernstein/lacylights-node) (backend)
  - [lacylights-fe](https://github.com/bbernstein/lacylights-fe) (frontend)
  - [lacylights-mcp](https://github.com/bbernstein/lacylights-mcp) (MCP server)

**Recommended directory structure for development:**
```
~/src/lacylights/
├── lacylights-node/    # Backend repository (for development)
├── lacylights-fe/      # Frontend repository (for development)
├── lacylights-mcp/     # MCP server repository (for development)
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
./scripts/deploy.sh --mcp-only
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
  - MCP Server: `/opt/lacylights/mcp/`
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
   cd lacylights-node  # or other repo
   # Edit code
   git add .
   git commit -m "Add: new feature"
   ```

2. **Type check locally**
   ```bash
   npm run type-check
   npm test
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
   cd ../lacylights-node
   git push origin main
   ```

### Quick Iteration

For rapid development without rebuild:

```bash
# Sync files only, no rebuild or restart
./scripts/deploy.sh --skip-rebuild --skip-restart

# Make more changes and sync again
./scripts/deploy.sh --skip-rebuild --skip-restart

# When ready, rebuild and restart
ssh pi@lacylights.local
cd /opt/lacylights/backend
npm run build
sudo systemctl restart lacylights
```

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
  # Rebuild
  cd /opt/lacylights/backend
  npm run build

  # Restart service
  sudo systemctl restart lacylights
EOF
```

### Type Check Fails

```bash
# Fix type errors first
cd lacylights-node  # or other repo
npm run type-check

# Fix shown errors
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

## Contributing

This is a deployment repository. For application code contributions:

- Backend: [lacylights-node](https://github.com/bbernstein/lacylights-node)
- Frontend: [lacylights-fe](https://github.com/bbernstein/lacylights-fe)
- MCP Server: [lacylights-mcp](https://github.com/bbernstein/lacylights-mcp)

For deployment tooling improvements, open an issue or PR in this repository.

## Documentation

- **Getting Started:**
  - [INITIAL_SETUP.md](docs/INITIAL_SETUP.md) - First-time setup
  - [DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deploying changes

- **Configuration:**
  - [WIFI_SETUP.md](docs/WIFI_SETUP.md) - WiFi configuration
  - [config/.env.example](config/.env.example) - Environment variables

- **Maintenance:**
  - [UPDATING.md](docs/UPDATING.md) - System updates
  - [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues
  - [RELEASES.md](docs/RELEASES.md) - Creating and managing releases

- **Scripts:**
  - [scripts/deploy.sh](scripts/deploy.sh) - Deployment script
  - [scripts/setup-new-pi.sh](scripts/setup-new-pi.sh) - Setup script
  - [install.sh](install.sh) - One-command installer

## Related Repositories

- [lacylights](https://github.com/bbernstein/lacylights) - Main documentation
- [lacylights-node](https://github.com/bbernstein/lacylights-node) - Backend (GraphQL, DMX, Database)
- [lacylights-fe](https://github.com/bbernstein/lacylights-fe) - Frontend (React, Next.js)
- [lacylights-mcp](https://github.com/bbernstein/lacylights-mcp) - MCP Server (AI integration)

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
