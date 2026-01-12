# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

LacyLights RPi is a **production deployment platform** for running LacyLights on Raspberry Pi hardware as a turnkey stage lighting controller. It provides deployment scripts, systemd service configuration, and management utilities for a dedicated lighting appliance.

**Role in LacyLights Ecosystem:**
- **Production platform** for Raspberry Pi (parallel to lacylights-mac for macOS)
- Downloads releases from dist.lacylights.com (lacylights-terraform infrastructure)
- Hosts two application components:
  - lacylights-go (backend API server)
  - lacylights-fe (web frontend as static files)
- Manages systemd services for automatic startup
- Configures dual-network (WiFi for internet + Ethernet for DMX)
- Provides diagnostic and maintenance utilities

**Note:** This is NOT a development environment. Development can be done on any OS by running the component repos directly. This platform is for end users running LacyLights in production.

## Development Commands

### Deployment
```bash
./scripts/deploy.sh              # Deploy all components to Pi
./scripts/deploy.sh --backend-only   # Deploy backend only
./scripts/deploy.sh --frontend-only  # Deploy frontend only
```

### Setup (Fresh Pi)
```bash
./scripts/setup-new-pi.sh pi@raspberrypi.local  # Remote setup
sudo ./scripts/setup-local-pi.sh                 # Local setup
```

### Modular Setup Scripts
```bash
sudo ./setup/00-wifi-setup.sh         # Initial WiFi configuration
sudo ./setup/01-system-setup.sh       # Install dependencies
sudo ./setup/02-network-setup.sh      # Configure networking
sudo ./setup/03-database-setup.sh     # Setup SQLite
sudo ./setup/04-permissions-setup.sh  # User and permissions
sudo ./setup/05-service-install.sh    # Install systemd service
sudo ./setup/06-nginx-setup.sh        # Configure Nginx reverse proxy
```

### Utilities (Run on Pi)
```bash
~/lacylights-setup/utils/check-health.sh      # System health check
~/lacylights-setup/utils/view-logs.sh         # View service logs
~/lacylights-setup/utils/network-diagnostic.sh # Network diagnostics
~/lacylights-setup/utils/wifi-diagnostic.sh   # WiFi troubleshooting
```

## Architecture

### Directory Structure

```
lacylights-rpi/
├── install.sh              # One-command installer
├── scripts/
│   ├── deploy.sh           # General deployment
│   ├── setup-new-pi.sh     # Fresh Pi setup (remote)
│   ├── setup-local-pi.sh   # Fresh Pi setup (local)
│   └── create-image.sh     # Create SD card image
├── setup/
│   ├── 00-wifi-setup.sh        # WiFi configuration
│   ├── 01-system-setup.sh      # System packages
│   ├── 02-network-setup.sh     # Network config
│   ├── 03-database-setup.sh    # Database setup
│   ├── 04-permissions-setup.sh # Permissions
│   ├── 05-service-install.sh   # systemd service
│   └── 06-nginx-setup.sh       # Nginx reverse proxy
├── systemd/
│   └── lacylights.service  # systemd service definition
├── config/
│   ├── .env.example        # Environment template
│   └── sudoers.d/
│       └── lacylights      # WiFi sudo permissions
├── utils/
│   ├── check-health.sh     # Health diagnostics
│   ├── view-logs.sh        # Log viewer
│   ├── network-diagnostic.sh
│   └── wifi-diagnostic.sh
├── nginx/                  # Nginx configuration
└── docs/                   # Documentation
```

### File Locations on Pi

| Path | Purpose |
|------|---------|
| `/opt/lacylights/backend/` | Go backend binary and data |
| `/opt/lacylights/frontend-src/` | Frontend static files |
| `/etc/systemd/system/lacylights.service` | systemd service |
| `/etc/sudoers.d/lacylights` | WiFi management permissions |
| `~/lacylights-setup/` | Setup scripts and utilities |

### Network Architecture

**Dual-network setup with automatic routing:**

| Interface | Purpose | Routing Priority |
|-----------|---------|-----------------|
| `eth0` (Ethernet) | DMX/Art-Net (local only) | Low (metric 200) |
| `wlan0` (WiFi) | Internet access | High (metric 100) |

Traffic automatically routes:
- Internet → WiFi (when connected)
- Local DMX → Ethernet
- Works standalone without WiFi

## Important Patterns

### Script Conventions
- All scripts use bash
- Scripts are idempotent (safe to run multiple times)
- Exit on error: `set -e`
- Verbose output for debugging
- Version detection from `VERSION` file

### Environment Variables (on Pi)
```bash
# /opt/lacylights/backend/.env
DATABASE_URL="file:./prisma/lacylights.db"
PORT=4000
NODE_ENV=production
ARTNET_ENABLED=true
ARTNET_BROADCAST=192.168.1.255
DMX_UNIVERSE_COUNT=4
WIFI_ENABLED=true
WIFI_DEVICE=wlan0
```

### System User
- **User:** `lacylights` (system user, no login)
- **Group:** `lacylights`
- **Permissions:** WiFi management via passwordless sudo

### Service Management
```bash
sudo systemctl status lacylights   # Check status
sudo systemctl restart lacylights  # Restart
sudo systemctl stop lacylights     # Stop
sudo journalctl -u lacylights -f   # Follow logs
```

## Testing Guidelines

- Test scripts on a fresh Pi image before release
- Verify all setup steps complete without errors
- Test network routing (DMX on eth0, internet on wlan0)
- Verify service auto-starts on reboot
- Test one-command installer from clean state

## CI/CD

| Workflow | File | Purpose |
|----------|------|---------|
| Release | `release.yml` | Create release, upload to dist.lacylights.com |

### Release Process
1. Create GitHub release with version tag
2. Workflow packages scripts as tarball
3. Uploads to S3 (dist.lacylights.com)
4. Updates DynamoDB metadata
5. Pi can download via `install.sh`

## Configuration

### Hardware Requirements
- **Raspberry Pi 4** (4GB+ RAM recommended)
- **MicroSD card** (32GB+ Class 10)
- **Power supply** (5V 3A official)
- **Ethernet cable** for DMX network
- Built-in WiFi for internet

### Software Requirements (on Pi)
- Raspberry Pi OS (64-bit)
- SSH enabled
- Internet connection for setup
- Updated CA certificates

## Related Repositories

| Repository | Relationship |
|------------|--------------|
| [lacylights-go](https://github.com/bbernstein/lacylights-go) | Backend deployed to Pi |
| [lacylights-fe](https://github.com/bbernstein/lacylights-fe) | Frontend deployed to Pi |
| [lacylights-terraform](https://github.com/bbernstein/lacylights-terraform) | Hosts release downloads |
| [lacylights-test](https://github.com/bbernstein/lacylights-test) | Integration tests |

## Important Notes

- This is a **deployment** repository, not an application
- Application code changes go to lacylights-go or lacylights-fe
- Scripts download pre-built releases from dist.lacylights.com
- The Go backend is a compiled binary (no build on Pi)
- Frontend is served as static files

## Common Tasks

### Deploy Code Changes
```bash
# After making changes to lacylights-go or lacylights-fe
cd lacylights-rpi
./scripts/deploy.sh
```

### Check System Health
```bash
ssh pi@lacylights.local '~/lacylights-setup/utils/check-health.sh'
```

### View Logs
```bash
ssh pi@lacylights.local 'sudo journalctl -u lacylights -f'
```

### Create SD Card Image
```bash
./scripts/create-image.sh
# Output: ~/Desktop/lacylights-YYYYMMDD.img.gz
```

## URLs on Running Pi

| URL | Purpose |
|-----|---------|
| http://lacylights.local | Web interface |
| http://lacylights.local:4000/graphql | GraphQL API |

## Troubleshooting

### Service Won't Start
```bash
sudo systemctl status lacylights
sudo journalctl -u lacylights -n 50
ls -la /opt/lacylights/backend/lacylights-server
```

### Network Issues
```bash
~/lacylights-setup/utils/network-diagnostic.sh
ip route show
nmcli connection show
```

### WiFi Issues
```bash
~/lacylights-setup/utils/wifi-diagnostic.sh
nmcli device wifi list
```
