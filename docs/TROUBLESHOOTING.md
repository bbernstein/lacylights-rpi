# LacyLights Troubleshooting Guide

Common issues and their solutions.

## Quick Diagnostics

Run these commands to quickly identify issues:

```bash
# Overall health check
ssh pi@lacylights.local '~/lacylights-setup/utils/check-health.sh'

# WiFi-specific diagnostics
ssh pi@lacylights.local '~/lacylights-setup/utils/wifi-diagnostic.sh'

# View recent logs
ssh pi@lacylights.local '~/lacylights-setup/utils/view-logs.sh -n 100'

# View only errors
ssh pi@lacylights.local '~/lacylights-setup/utils/view-logs.sh -e'
```

## Service Issues

### Service Won't Start

**Symptoms:**
- `sudo systemctl start lacylights` fails
- Service shows as "failed" in status

**Diagnosis:**
```bash
ssh pi@lacylights.local
sudo systemctl status lacylights
sudo journalctl -u lacylights -n 50
```

**Common Causes and Solutions:**

#### 1. Database Not Running

```bash
# Check PostgreSQL
sudo systemctl status postgresql

# Start if needed
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Restart LacyLights
sudo systemctl restart lacylights
```

#### 2. Missing or Invalid .env File

```bash
# Check if .env exists
sudo cat /opt/lacylights/backend/.env

# If missing, create from template
sudo cp /opt/lacylights/backend/.env.example /opt/lacylights/backend/.env

# Update DATABASE_URL with correct password
sudo nano /opt/lacylights/backend/.env

# Fix permissions
sudo chown lacylights:lacylights /opt/lacylights/backend/.env
sudo chmod 600 /opt/lacylights/backend/.env
```

#### 3. Port Already in Use

```bash
# Check what's using port 4000
sudo netstat -tlnp | grep 4000
# or
sudo ss -tlnp | grep 4000

# Kill old process if needed
sudo kill <PID>

# Restart service
sudo systemctl restart lacylights
```

#### 4. Build Artifacts Missing

```bash
# Rebuild
cd /opt/lacylights/backend
npm run build

# Restart service
sudo systemctl restart lacylights
```

### Service Crashes After Starting

**Symptoms:**
- Service starts but crashes within seconds
- "active (running)" briefly, then "failed"

**Diagnosis:**
```bash
# Watch logs in real-time
sudo journalctl -u lacylights -f

# Restart service while watching logs
sudo systemctl restart lacylights
```

**Common Causes:**

#### 1. Database Connection Error

```bash
# Test database connection
psql $(grep DATABASE_URL /opt/lacylights/backend/.env | cut -d'=' -f2 | tr -d '"')

# If fails, check:
# - PostgreSQL is running
# - Database exists
# - Password is correct
# - User has privileges
```

#### 2. Prisma Migration Needed

```bash
cd /opt/lacylights/backend
npx prisma migrate deploy
sudo systemctl restart lacylights
```

#### 3. Missing Dependencies

```bash
cd /opt/lacylights/backend
npm install --production
sudo systemctl restart lacylights
```

### Service Keeps Restarting

**Symptoms:**
- Service shows as "restarting" constantly
- Multiple "Started LacyLights" messages in logs

**Solution:**
```bash
# Stop the service completely
sudo systemctl stop lacylights

# Try running manually to see error
cd /opt/lacylights/backend
sudo -u lacylights node dist/index.js

# Fix the error shown, then start service
sudo systemctl start lacylights
```

## Network Issues

### Can't Access lacylights.local

**Symptoms:**
- `ping lacylights.local` fails
- Can't access web interface

**Solutions:**

#### 1. Find IP Address Directly

```bash
# If you can still SSH to old address
ssh pi@raspberrypi.local 'hostname -I'

# Use IP address instead
ping 192.168.1.100
http://192.168.1.100
```

#### 2. Check mDNS/Avahi

```bash
# On Pi
ssh pi@<IP>
sudo systemctl status avahi-daemon

# If not running
sudo apt-get install avahi-daemon
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon
```

#### 3. Check Hostname

```bash
ssh pi@<IP>
hostname
# Should show: lacylights

# If not:
sudo hostnamectl set-hostname lacylights
sudo reboot
```

### Web Interface Doesn't Load

**Symptoms:**
- Can ping lacylights.local
- HTTP connection refused or times out

**Diagnosis:**
```bash
# Check if port 4000 is listening
ssh pi@lacylights.local 'sudo netstat -tlnp | grep 4000'

# Test GraphQL directly
curl http://lacylights.local:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __typename }"}'
```

**Solutions:**

#### 1. Service Not Running

```bash
ssh pi@lacylights.local
sudo systemctl status lacylights
sudo systemctl start lacylights
```

#### 2. Firewall Blocking

```bash
# Check if UFW is active
sudo ufw status

# Allow port 4000
sudo ufw allow 4000/tcp
```

#### 3. Frontend Build Missing

```bash
cd /opt/lacylights/frontend-src
npm run build
sudo systemctl restart lacylights
```

## WiFi Issues

### WiFi Section Doesn't Appear

**Symptoms:**
- Settings page shows Art-Net but no WiFi section

**Cause:** WiFi not available on this system

**Diagnosis:**
```bash
# Check WiFi availability
curl -s http://lacylights.local:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ wifiStatus { available } }"}' | grep available

# Check for WiFi device
ssh pi@lacylights.local 'nmcli device status | grep wifi'
```

**Solutions:**

#### 1. NetworkManager Not Installed

```bash
ssh pi@lacylights.local
sudo apt-get install network-manager
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
sudo systemctl restart lacylights
```

#### 2. WiFi Device Not Detected

```bash
# Check for wlan device
ip link show

# Check rfkill
rfkill list

# Unblock if needed
sudo rfkill unblock wifi
```

### Can't Connect to WiFi Network

**Symptoms:**
- WiFi section appears
- Networks visible
- Connection fails

**Diagnosis:**
```bash
ssh pi@lacylights.local
~/lacylights-setup/utils/wifi-diagnostic.sh
```

**Common Causes:**

#### 1. Wrong Password

- Double-check password
- Try connecting manually:
  ```bash
  sudo nmcli device wifi connect "SSID" password "password"
  ```

#### 2. Weak Signal

- Check signal strength in network list
- Move Pi closer to router
- Use external WiFi antenna

#### 3. Incompatible Security

- Check network security type
- Some enterprise WiFi (802.1X) not supported
- Try WPA2-PSK network first

#### 4. Missing Permissions

```bash
# Check sudoers file
sudo visudo -c -f /etc/sudoers.d/lacylights

# Reinstall if invalid
cd ~/lacylights-setup/setup
sudo bash 04-permissions-setup.sh
```

### WiFi Disconnects Randomly

**Symptoms:**
- WiFi connects initially
- Drops connection periodically

**Solutions:**

#### 1. Power Management

```bash
# Disable WiFi power management
sudo iwconfig wlan0 power off

# Make permanent
echo 'wireless-power off' | sudo tee -a /etc/network/interfaces
```

#### 2. Weak Signal

- Check signal strength
- Reposition Pi or router
- Reduce interference (microwave, other 2.4GHz devices)

#### 3. Router Issues

- Check router logs
- Try different WiFi channel
- Update router firmware

## Database Issues

### Database Connection Failed

**Symptoms:**
- Service fails with "connection refused"
- "ECONNREFUSED" errors in logs

**Solutions:**

#### 1. PostgreSQL Not Running

```bash
sudo systemctl status postgresql
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### 2. Wrong Database URL

```bash
# Check .env file
sudo grep DATABASE_URL /opt/lacylights/backend/.env

# Test connection
psql "$(sudo grep DATABASE_URL /opt/lacylights/backend/.env | cut -d'=' -f2 | tr -d '"')"
```

#### 3. Database Doesn't Exist

```bash
# Check if database exists
sudo -u postgres psql -l | grep lacylights

# Create if missing
sudo -u postgres psql -c "CREATE DATABASE lacylights;"
```

### Migration Errors

**Symptoms:**
- "Prisma schema is out of sync with database"
- Service fails on startup with schema errors

**Solutions:**

#### 1. Run Migrations

```bash
cd /opt/lacylights/backend
npx prisma migrate deploy
sudo systemctl restart lacylights
```

#### 2. Reset Database (CAUTION: deletes all data)

```bash
cd /opt/lacylights/backend
npx prisma migrate reset --force
sudo systemctl restart lacylights
```

## Performance Issues

### Slow Response Times

**Symptoms:**
- Web interface loads slowly
- GraphQL queries timeout

**Diagnosis:**
```bash
# Check system resources
ssh pi@lacylights.local
top
free -h
df -h
```

**Solutions:**

#### 1. High Memory Usage

```bash
# Check what's using memory
ps aux --sort=-%mem | head -10

# Restart service to clear memory
sudo systemctl restart lacylights

# Increase swap if needed
sudo dphys-swapfile swapoff
sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

#### 2. Disk Space Full

```bash
# Check disk usage
df -h

# Clear logs
sudo journalctl --vacuum-time=7d

# Clear npm cache
npm cache clean --force

# Clear old builds
cd /opt/lacylights
find . -name "node_modules" -type d -prune -exec rm -rf {} +
```

#### 3. Database Too Large

```bash
# Check database size
sudo -u postgres psql -d lacylights -c "SELECT pg_size_pretty(pg_database_size('lacylights'));"

# Vacuum database
sudo -u postgres psql -d lacylights -c "VACUUM FULL ANALYZE;"
```

### High CPU Usage

**Symptoms:**
- Pi runs hot
- Fan always on
- System sluggish

**Diagnosis:**
```bash
# Check CPU usage
top

# Check service CPU
systemctl status lacylights
```

**Solutions:**

- Check for infinite loops in logs
- Reduce Art-Net refresh rate in settings
- Disable MCP server if not needed

## DMX/Art-Net Issues

### No DMX Output

**Symptoms:**
- Fixtures don't respond
- No Art-Net packets on network

**Diagnosis:**
```bash
# Check Art-Net is enabled
curl -s http://lacylights.local:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ settings { key value } }"}' \
  | grep -i artnet

# Check network interface
ip addr show eth0
```

**Solutions:**

#### 1. Wrong Broadcast Address

- Go to Settings → Art-Net Configuration
- Check broadcast address matches your network
- Example: 192.168.1.255 for 192.168.1.x network

#### 2. Wired Connection Issue

```bash
# Check ethernet is connected
ip link show eth0
# Should show "state UP"

# Check IP address
ip addr show eth0
```

#### 3. Art-Net Disabled

- Check .env file: `ARTNET_ENABLED=true`
- Restart service after changing

## Deployment Issues

### Type Check Fails

**Symptoms:**
- Deployment script fails at type check
- "error TS" messages

**Solution:**
```bash
# Fix type errors locally first
cd lacylights-node  # or other repo
npm run type-check

# Fix errors shown
# Then retry deployment
```

### Rsync Errors

**Symptoms:**
- "rsync error" during deployment
- Permission denied

**Solutions:**

#### 1. SSH Issues

```bash
# Test SSH connection
ssh pi@lacylights.local 'echo "Connection OK"'

# Setup SSH key if prompted for password
ssh-copy-id pi@lacylights.local
```

#### 2. Permission Issues on Pi

```bash
# Fix ownership
ssh pi@lacylights.local 'sudo chown -R lacylights:lacylights /opt/lacylights'

# Fix permissions
ssh pi@lacylights.local 'sudo chmod -R 755 /opt/lacylights'
```

### Build Fails on Pi

**Symptoms:**
- Deployment fails during remote build
- TypeScript or npm errors

**Solutions:**

#### 1. Out of Memory

```bash
# Increase Node memory
ssh pi@lacylights.local
export NODE_OPTIONS="--max-old-space-size=1024"
cd /opt/lacylights/backend
npm run build
```

#### 2. Missing node_modules

```bash
cd /opt/lacylights/backend
rm -rf node_modules package-lock.json
npm install --production
npm run build
```

## Getting More Help

### Collect Diagnostic Information

```bash
# Run all diagnostics
ssh pi@lacylights.local << 'EOF'
echo "=== System Info ==="
uname -a
cat /proc/device-tree/model

echo "=== Service Status ==="
sudo systemctl status lacylights --no-pager

echo "=== Recent Logs ==="
sudo journalctl -u lacylights -n 50 --no-pager

echo "=== Health Check ==="
~/lacylights-setup/utils/check-health.sh

echo "=== Network Status ==="
ip addr show
nmcli device status

echo "=== Disk Space ==="
df -h

echo "=== Memory ==="
free -h
EOF
```

### Where to Get Help

1. Review documentation in `docs/` directory
2. Run diagnostic scripts in `utils/` directory
3. Check GitHub issues
4. Open a new issue with diagnostic output
