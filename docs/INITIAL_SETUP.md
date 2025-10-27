# LacyLights Initial Setup Guide

This guide walks you through setting up LacyLights on a fresh Raspberry Pi from scratch.

## What You'll Need

### Hardware
- **Raspberry Pi 4** (4GB+ RAM recommended)
- **MicroSD card** (32GB+ recommended, Class 10 or better)
- **Power supply** (official Raspberry Pi 5V 3A recommended)
- **Ethernet cable** for initial setup and DMX network
- **WiFi capability** (built-in on Pi 4)

### Software
- **Raspberry Pi OS** (64-bit, Lite or Desktop)
- **Development machine** (macOS, Linux, or Windows with WSL)
- **lacylights-rpi** repository cloned locally (deployment tools)

**Note:** Other repositories (backend, frontend, MCP) are cloned directly from GitHub to the Pi during setup.

### Network
- Local network with DHCP
- Internet connection for initial package downloads
- mDNS support (Bonjour/Avahi) for `.local` hostname resolution

## Quick Start

For a fresh Raspberry Pi with SSH enabled:

```bash
cd lacylights-rpi

# Setup with latest code from GitHub
./scripts/setup-new-pi.sh pi@raspberrypi.local

# Or specify specific versions:
./scripts/setup-new-pi.sh pi@raspberrypi.local \
    --backend-version v1.1.0 \
    --frontend-version v0.2.0 \
    --mcp-version v1.0.0
```

This one command will:
1. Install all system dependencies
2. Configure networking and hostname
3. Set up SQLite database directory
4. Create system user and permissions
5. Clone all application code from GitHub
6. Build and start services

**Setup time:** 15-20 minutes

**Note:** Repositories are cloned directly from GitHub to the Pi, so you don't need them locally.

## Detailed Setup Process

If you prefer to understand each step or the automated script fails, follow this detailed guide.

### Step 1: Prepare the Raspberry Pi

#### 1.1 Flash Raspberry Pi OS

Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/):

1. Choose **Raspberry Pi OS (64-bit)** - Lite or Desktop
2. Configure advanced options:
   - Enable SSH
   - Set username: `pi`
   - Set password
   - Configure WiFi (optional, for initial setup)
   - Set hostname: `raspberrypi` (will be changed to `lacylights` later)
3. Flash to microSD card

#### 1.2 First Boot

1. Insert microSD card and power on
2. Wait 1-2 minutes for first boot
3. Find Pi on network:
   ```bash
   ping raspberrypi.local
   # or use IP scanner to find IP address
   ```

#### 1.3 Initial Connection

```bash
ssh pi@raspberrypi.local
```

Update the system:
```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo reboot
```

Wait for reboot, then reconnect:
```bash
ssh pi@raspberrypi.local
```

### Step 2: Run Automated Setup

From your development machine:

```bash
cd lacylights-rpi
./scripts/setup-new-pi.sh pi@raspberrypi.local
```

The script will prompt for password multiple times. Consider setting up SSH keys for smoother operation.

### Step 3: Verify Installation

#### Check Service Status

```bash
ssh pi@lacylights.local 'sudo systemctl status lacylights'
```

Expected output:
```
● lacylights.service - LacyLights Stage Lighting Control
   Active: active (running)
```

#### Check GraphQL API

```bash
curl http://lacylights.local:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __typename }"}'
```

Expected output:
```json
{"data":{"__typename":"Query"}}
```

#### Access Web Interface

Open in browser: **http://lacylights.local**

You should see the LacyLights web interface.

## Manual Setup (Advanced)

If the automated script fails or you want more control:

### 1. System Dependencies

```bash
ssh pi@raspberrypi.local
cd ~/lacylights-setup/setup
sudo bash 01-system-setup.sh
```

This installs:
- Node.js 20
- NetworkManager
- Build tools

**Note:** SQLite is included with Prisma, no separate database installation needed.

### 2. Network Configuration

```bash
sudo bash 02-network-setup.sh
```

This:
- Sets hostname to `lacylights`
- Enables NetworkManager
- Configures WiFi device

**Note:** You'll need to reconnect using the new hostname:
```bash
ssh pi@lacylights.local
```

### 3. Database Setup

```bash
sudo bash 03-database-setup.sh
```

This:
- Creates database directory at `/opt/lacylights/backend/prisma/`
- Saves SQLite connection string

The database connection string is saved to `/tmp/lacylights-setup/database.env`

**Note:** The SQLite database file will be created automatically when migrations run.

### 4. Permissions Setup

```bash
sudo bash 04-permissions-setup.sh
```

This:
- Creates `lacylights` system user
- Creates `/opt/lacylights/` directories
- Installs sudoers file for WiFi management

### 5. Clone Application Code

The repositories are cloned from GitHub on the Pi:

```bash
ssh pi@lacylights.local

# Clone backend (main branch)
git clone https://github.com/bbernstein/lacylights-node.git /opt/lacylights/backend

# Clone frontend (main branch)
git clone https://github.com/bbernstein/lacylights-fe.git /opt/lacylights/frontend-src

# Clone MCP server (main branch)
git clone https://github.com/bbernstein/lacylights-mcp.git /opt/lacylights/mcp

# Or clone specific versions:
# git clone --depth 1 --branch v1.1.0 https://github.com/bbernstein/lacylights-node.git /opt/lacylights/backend
```

### 6. Build Projects

```bash
ssh pi@lacylights.local

# Build backend
cd /opt/lacylights/backend
npm install
npm run build

# Run database migrations
npx prisma migrate deploy

# Build frontend
cd /opt/lacylights/frontend-src
npm install
npm run build

# Build MCP server
cd /opt/lacylights/mcp
npm install
npm run build
```

### 7. Install and Start Service

```bash
cd ~/lacylights-setup/setup
sudo bash 05-service-install.sh
sudo systemctl start lacylights
```

## Network Configuration

### Dual Network Setup

LacyLights uses two network interfaces:

1. **Ethernet (eth0)** - DMX/Art-Net lighting network
   - Connect to DMX lighting fixtures
   - Configure broadcast address in settings
   - Example: 192.168.1.255 for 192.168.1.x network

2. **WiFi (wlan0)** - External internet access
   - Connect to your local WiFi for internet
   - Used by MCP server to reach AI models
   - Configured via web interface

### Setting Up WiFi

After installation, configure WiFi through the web interface:

1. Navigate to **Settings** → **WiFi Configuration**
2. Click **Scan Networks**
3. Select your network
4. Enter password
5. Click **Connect**

See [WIFI_SETUP.md](WIFI_SETUP.md) for detailed WiFi configuration.

## SSH Key Setup (Recommended)

For easier deployment and management:

```bash
# On your development machine
ssh-copy-id pi@lacylights.local
```

Now you can SSH and deploy without entering passwords.

## Security Considerations

### Default Setup

- LacyLights runs as dedicated `lacylights` user (not root)
- Database password is randomly generated
- Web interface has no authentication (trusted local network only)
- systemd service has security restrictions

### Hardening (Optional)

For production or untrusted networks:

1. **Enable firewall:**
   ```bash
   ssh pi@lacylights.local
   sudo apt-get install ufw
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 4000/tcp  # GraphQL API
   sudo ufw allow 80/tcp    # HTTP
   sudo ufw enable
   ```

2. **Change default password:**
   ```bash
   ssh pi@lacylights.local
   passwd
   ```

3. **Add authentication to web interface** (future feature)

4. **Use HTTPS** (requires nginx reverse proxy)

## Backup and Recovery

### Backup Configuration

Save these important files:

```bash
ssh pi@lacylights.local
# Environment configuration
sudo cat /opt/lacylights/backend/.env > ~/lacylights-backup.env

# Database
cp /opt/lacylights/backend/prisma/lacylights.db ~/lacylights-backup.db
```

Copy to your local machine:
```bash
scp pi@lacylights.local:~/lacylights-backup.* ./
```

### Restore from Backup

```bash
# Copy files back
scp lacylights-backup.env pi@lacylights.local:~/

# Restore .env
ssh pi@lacylights.local
sudo cp ~/lacylights-backup.env /opt/lacylights/backend/.env
sudo chown lacylights:lacylights /opt/lacylights/backend/.env

# Restore database
sudo systemctl stop lacylights
cp ~/lacylights-backup.db /opt/lacylights/backend/prisma/lacylights.db
sudo chown lacylights:lacylights /opt/lacylights/backend/prisma/lacylights.db

# Restart service
sudo systemctl start lacylights
```

## Troubleshooting

### Setup Script Fails

**Problem:** Automated setup script fails midway

**Solution:**
1. Note which step failed
2. Run steps manually starting from that point
3. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
4. Review script output for error messages

### Can't Connect to lacylights.local

**Problem:** Hostname doesn't resolve

**Solutions:**
1. Use IP address instead:
   ```bash
   # Find IP
   ssh pi@raspberrypi.local 'hostname -I'
   # Connect using IP
   ssh pi@192.168.1.100
   ```

2. Check mDNS is working:
   ```bash
   # macOS/Linux
   dns-sd -q lacylights.local

   # Or use avahi-browse
   avahi-browse -a
   ```

3. Install Avahi on Pi:
   ```bash
   ssh pi@lacylights.local
   sudo apt-get install avahi-daemon
   sudo systemctl enable avahi-daemon
   sudo systemctl start avahi-daemon
   ```

### Service Won't Start

**Problem:** `sudo systemctl start lacylights` fails

**Solutions:**
1. Check logs:
   ```bash
   sudo journalctl -u lacylights -n 50
   ```

2. Common issues:
   - Missing .env file: `sudo cp /opt/lacylights/backend/.env.example /opt/lacylights/backend/.env`
   - Port already in use: `sudo netstat -tlnp | grep 4000`
   - Database file missing: `cd /opt/lacylights/backend && npx prisma migrate deploy`

3. Try manual start for details:
   ```bash
   cd /opt/lacylights/backend
   sudo -u lacylights node dist/index.js
   ```

### Database Connection Errors

**Problem:** Cannot connect to database

**Solutions:**
1. Check database file exists:
   ```bash
   ls -la /opt/lacylights/backend/prisma/lacylights.db
   ```

2. Check connection string in .env:
   ```bash
   sudo grep DATABASE_URL /opt/lacylights/backend/.env
   ```

3. Verify file permissions:
   ```bash
   sudo chown lacylights:lacylights /opt/lacylights/backend/prisma/lacylights.db
   sudo chmod 644 /opt/lacylights/backend/prisma/lacylights.db
   ```

4. Re-run migrations if database is missing:
   ```bash
   cd /opt/lacylights/backend
   npx prisma migrate deploy
   ```

### Out of Disk Space

**Problem:** No space left on device

**Solutions:**
1. Check disk usage:
   ```bash
   df -h
   ```

2. Clear npm cache:
   ```bash
   npm cache clean --force
   ```

3. Remove old logs:
   ```bash
   sudo journalctl --vacuum-time=7d
   ```

4. Use larger SD card (32GB+ recommended)

## Performance Optimization

### For Raspberry Pi 4

Default settings should work well. If you experience issues:

1. **Increase swap:**
   ```bash
   sudo dphys-swapfile swapoff
   sudo nano /etc/dphys-swapfile
   # Set CONF_SWAPSIZE=2048
   sudo dphys-swapfile setup
   sudo dphys-swapfile swapon
   ```

### For Raspberry Pi 3

May require adjustments:

1. Reduce memory limits in systemd service
2. Disable MCP server if not needed
3. Consider reducing Art-Net refresh rate

## Next Steps

After successful installation:

1. **Configure Art-Net** - Set broadcast address in Settings
2. **Add Fixtures** - Define your DMX fixtures
3. **Create Scenes** - Build lighting scenes
4. **Test WiFi** - Configure and test WiFi connectivity
5. **Read Documentation**:
   - [DEPLOYMENT.md](DEPLOYMENT.md) - Deploy code changes
   - [WIFI_SETUP.md](WIFI_SETUP.md) - WiFi configuration
   - [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues

## Support

If you encounter issues not covered here:

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Run health check: `./utils/check-health.sh`
3. View logs: `./utils/view-logs.sh`
4. Open an issue on GitHub
