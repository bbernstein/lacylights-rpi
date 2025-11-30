# Migrating to Go Backend

This guide explains how to migrate your existing LacyLights Raspberry Pi installation from the Node.js backend to the new Go backend.

## Why Migrate to Go?

The Go backend provides several benefits over the Node.js backend:

### Performance Benefits
- **Faster startup time**: Go binary starts in milliseconds vs Node.js which takes seconds
- **Lower memory usage**: ~256MB vs ~512MB for Node.js
- **Better concurrency**: Native goroutines handle concurrent DMX operations more efficiently
- **No runtime overhead**: Compiled binary runs directly without interpreter

### Operational Benefits
- **Simpler deployment**: Single binary, no npm/node_modules required
- **Smaller footprint**: No Node.js runtime or dependencies needed
- **Better resource utilization**: More efficient on Raspberry Pi hardware
- **Improved stability**: Compiled languages catch more errors at build time

### Compatibility
- **100% API compatible**: Same GraphQL schema and REST endpoints
- **Same database schema**: Uses the existing SQLite database
- **Same configuration**: Uses the same .env file format
- **No data migration needed**: Your existing scenes, fixtures, and cues work as-is

## Prerequisites

Before migrating, ensure:

1. **Existing Installation**: You have a working LacyLights installation with Node.js backend
2. **Internet Connection**: Required to download the Go binary
3. **Backup**: While the migration script creates backups automatically, it's good to have your own
4. **SSH Access**: You need SSH access to your Raspberry Pi
5. **Sudo Access**: Migration requires root privileges

## Migration Process

### Automatic Migration (Recommended)

The easiest way to migrate is using the automated migration script:

```bash
# SSH into your Raspberry Pi
ssh pi@lacylights.local

# Download and run the migration script
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/scripts/migrate-to-go.sh | sudo bash
```

Or if you have the lacylights-rpi repository:

```bash
# SSH into your Raspberry Pi
ssh pi@lacylights.local

# Navigate to setup directory
cd ~/lacylights-setup

# Run migration script
sudo ./scripts/migrate-to-go.sh
```

The script will:
1. Detect your current Node.js backend installation
2. Detect your Raspberry Pi architecture (arm64 or armhf)
3. Create automatic backups of:
   - SQLite database
   - Environment configuration (.env)
   - Systemd service file
4. Download the appropriate Go binary for your architecture
5. Verify the binary checksum
6. Stop the Node.js backend service
7. Install the Go backend binary
8. Update the systemd service configuration
9. Start the Go backend service
10. Verify the service is healthy

### What Gets Migrated

✅ **Migrated automatically:**
- All database data (projects, scenes, fixtures, cues)
- Environment configuration (.env file)
- Service configuration (systemd)
- User and permissions

❌ **Not migrated (no longer needed):**
- Node.js runtime
- npm packages and node_modules
- TypeScript source files (Go is pre-compiled)

### Migration Safety

The migration script includes robust safety features:

1. **Automatic Backups**: Creates timestamped backups before making any changes
2. **Automatic Rollback**: If anything fails, automatically reverts to Node.js backend
3. **Health Verification**: Tests the Go backend before completing migration
4. **Detailed Logging**: All operations logged to `/var/log/lacylights-migration.log`

### Architecture Detection

The script automatically detects your Raspberry Pi architecture:

- **Raspberry Pi 3**: armhf (32-bit ARM)
- **Raspberry Pi 4**: arm64 (64-bit ARM)
- **Raspberry Pi 5**: arm64 (64-bit ARM)

And downloads the appropriate binary from `dist.lacylights.com`.

## Manual Migration

If you prefer to migrate manually or need more control:

### Step 1: Backup Current Installation

```bash
# Create backup directory
sudo mkdir -p /opt/lacylights/backups/manual-migration

# Backup database
sudo cp /opt/lacylights/backend/prisma/lacylights.db \
     /opt/lacylights/backups/manual-migration/

# Backup environment config
sudo cp /opt/lacylights/backend/.env \
     /opt/lacylights/backups/manual-migration/

# Backup service file
sudo cp /etc/systemd/system/lacylights.service \
     /opt/lacylights/backups/manual-migration/
```

### Step 2: Download Go Binary

Detect your architecture:
```bash
ARCH=$(uname -m)
echo "Architecture: $ARCH"
```

Download appropriate binary:
```bash
# For 64-bit ARM (Pi 4/5)
curl -fsSL -o /tmp/lacylights-server \
  https://dist.lacylights.com/releases/go/lacylights-server-latest-arm64

# For 32-bit ARM (Pi 3)
curl -fsSL -o /tmp/lacylights-server \
  https://dist.lacylights.com/releases/go/lacylights-server-latest-armhf
```

Verify checksum (optional but recommended):
```bash
# Download checksum file
curl -fsSL -o /tmp/lacylights-server.sha256 \
  https://dist.lacylights.com/releases/go/lacylights-server-latest-arm64.sha256

# Verify
cd /tmp
sha256sum -c lacylights-server.sha256
```

### Step 3: Stop Node Backend

```bash
sudo systemctl stop lacylights
```

### Step 4: Install Go Binary

```bash
# Copy binary
sudo cp /tmp/lacylights-server /opt/lacylights/backend/lacylights-server

# Make executable
sudo chmod +x /opt/lacylights/backend/lacylights-server

# Set ownership
sudo chown lacylights:lacylights /opt/lacylights/backend/lacylights-server
```

### Step 5: Update Service File

```bash
# Download new service file
curl -fsSL -o /tmp/lacylights-go.service \
  https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/systemd/lacylights-go.service

# Install service file
sudo cp /tmp/lacylights-go.service /etc/systemd/system/lacylights.service

# Reload systemd
sudo systemctl daemon-reload
```

### Step 6: Start Go Backend

```bash
sudo systemctl start lacylights
```

### Step 7: Verify Migration

```bash
# Check service status
sudo systemctl status lacylights

# Check logs
sudo journalctl -u lacylights -n 50

# Test GraphQL endpoint
curl -X POST -H "Content-Type: application/json" \
  -d '{"query":"{ __typename }"}' \
  http://localhost:4000/graphql

# Access web interface
# Open http://lacylights.local in browser
```

## Post-Migration

### Verify Everything Works

1. **Web Interface**: Open http://lacylights.local
2. **Check Projects**: Verify all your projects, scenes, and fixtures are present
3. **Test DMX Output**: Send a test cue to ensure DMX/Art-Net still works
4. **Check WiFi**: Ensure WiFi configuration is still working

### Monitor Performance

```bash
# Monitor service
sudo systemctl status lacylights

# View logs
sudo journalctl -u lacylights -f

# Check memory usage
ps aux | grep lacylights-server
```

### Remove Node.js (Optional)

After confirming everything works, you can optionally remove Node.js to free up space:

```bash
# Remove Node.js (only if you're not using it for anything else!)
sudo apt-get remove --purge nodejs npm

# Remove old Node backend files (optional)
sudo rm -rf /opt/lacylights/backend/dist
sudo rm -rf /opt/lacylights/backend/node_modules
```

**Warning**: Only remove Node.js if you're certain you don't need it for other applications!

## Rollback to Node.js

If you need to rollback to the Node.js backend:

### Automatic Rollback

The migration script creates backup files that make rollback easy:

```bash
# Stop Go backend
sudo systemctl stop lacylights

# Restore Node service file
sudo cp /etc/systemd/system/lacylights.service.node-backup \
     /etc/systemd/system/lacylights.service

# Reload systemd
sudo systemctl daemon-reload

# Restore database (if needed)
sudo cp /opt/lacylights/backend/prisma/lacylights.db.pre-go-migration \
     /opt/lacylights/backend/prisma/lacylights.db

# Restore environment config (if needed)
sudo cp /opt/lacylights/backend/.env.pre-go-migration \
     /opt/lacylights/backend/.env

# Start Node backend
sudo systemctl start lacylights
```

### Manual Rollback

If backup files are not available:

```bash
# Stop Go backend
sudo systemctl stop lacylights

# Restore from manual backup
sudo cp /opt/lacylights/backups/manual-migration/lacylights.service \
     /etc/systemd/system/lacylights.service
sudo cp /opt/lacylights/backups/manual-migration/lacylights.db \
     /opt/lacylights/backend/prisma/lacylights.db
sudo cp /opt/lacylights/backups/manual-migration/.env \
     /opt/lacylights/backend/.env

# Reload systemd
sudo systemctl daemon-reload

# Start Node backend
sudo systemctl start lacylights
```

## Troubleshooting

### Migration Script Fails

**Check logs:**
```bash
sudo cat /var/log/lacylights-migration.log
```

**Common issues:**
- **Network errors**: Ensure Pi has internet connection
- **Permission errors**: Ensure running with sudo
- **Service won't start**: Check `sudo journalctl -u lacylights -n 50`

### Go Backend Won't Start

**Check service status:**
```bash
sudo systemctl status lacylights
```

**Check logs:**
```bash
sudo journalctl -u lacylights -n 50 --no-pager
```

**Common issues:**
- **Binary not executable**: `sudo chmod +x /opt/lacylights/backend/lacylights-server`
- **Wrong ownership**: `sudo chown lacylights:lacylights /opt/lacylights/backend/lacylights-server`
- **Missing .env file**: Restore from backup
- **Database locked**: Ensure no other processes are using the database

### GraphQL Endpoint Not Responding

**Test manually:**
```bash
curl -v -X POST -H "Content-Type: application/json" \
  -d '{"query":"{ __typename }"}' \
  http://localhost:4000/graphql
```

**Check:**
- Port 4000 is not blocked: `sudo netstat -tlnp | grep 4000`
- Service is running: `sudo systemctl status lacylights`
- No firewall blocking: `sudo ufw status`

### Database Migration Issues

The Go backend uses the same database schema, so no schema migration is needed. However:

**If database appears empty:**
```bash
# Check database file exists
ls -la /opt/lacylights/backend/prisma/lacylights.db

# Check permissions
# Should be owned by lacylights:lacylights with 644 permissions
```

**If database is corrupted:**
```bash
# Restore from backup
sudo cp /opt/lacylights/backups/manual-migration/lacylights.db \
     /opt/lacylights/backend/prisma/lacylights.db
sudo chown lacylights:lacylights /opt/lacylights/backend/prisma/lacylights.db
sudo systemctl restart lacylights
```

## New Installations

For new Raspberry Pi installations, you can install the Go backend directly without migrating:

### Using the Installer (Future)

Once the Go backend is the default, the standard installer will use it:

```bash
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash
cd ~/lacylights-setup
sudo bash scripts/setup-local-pi.sh --backend=go
```

### Manual Installation

Follow the standard installation guide but use the Go service file:

```bash
# Standard setup steps 1-4
sudo ./setup/01-system-setup.sh
sudo ./setup/02-network-setup.sh
sudo ./setup/03-database-setup.sh
sudo ./setup/04-permissions-setup.sh

# Use Go service installer
sudo ./setup/05-service-install-go.sh

# Download and install Go backend binary
# (This would be part of the standard download process)
```

## FAQ

### Do I need to update my frontend?

No. The Go backend is 100% API compatible with the Node.js backend. Your existing frontend will work without any changes.

### Will my lighting cues and scenes work?

Yes. The database schema is identical, so all your existing projects, scenes, fixtures, and cues will work exactly as before.

### Can I switch back to Node.js?

Yes. The migration script creates automatic backups, making rollback straightforward. See the "Rollback to Node.js" section above.

### How much faster is the Go backend?

Typical improvements:
- **Startup time**: 10-15 seconds (Node) → <1 second (Go)
- **Memory usage**: 400-600 MB (Node) → 100-200 MB (Go)
- **Response time**: Similar for most operations, better under heavy load

### Does WiFi configuration still work?

Yes. The Go backend includes the same WiFi management capabilities as the Node.js backend.

### What about the MCP server?

The MCP server is separate and continues to work with both Node.js and Go backends. No changes needed.

### Is the Go backend production-ready?

Yes. The Go backend has been tested to ensure feature parity and compatibility with the Node.js backend.

## Support

If you encounter issues during migration:

1. **Check logs**: `sudo journalctl -u lacylights -n 100`
2. **Check migration log**: `sudo cat /var/log/lacylights-migration.log`
3. **Health check**: `~/lacylights-setup/utils/check-health.sh`
4. **Open an issue**: [GitHub Issues](https://github.com/bbernstein/lacylights-rpi/issues)

## Related Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Standard deployment procedures
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [UPDATING.md](UPDATING.md) - System and package updates
- [README.md](../README.md) - Main documentation
