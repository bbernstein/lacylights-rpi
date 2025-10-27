# LacyLights Update Guide

Guide for updating the LacyLights system, packages, and dependencies.

## Types of Updates

1. **Application Updates** - New LacyLights features and fixes
2. **System Updates** - Raspberry Pi OS patches and security updates
3. **Dependency Updates** - Node.js, npm packages
4. **Firmware Updates** - Raspberry Pi firmware

## Application Updates

### Updating LacyLights Code

Most common - updating your LacyLights application code:

```bash
# On your development machine
cd lacylights-node  # or lacylights-fe, lacylights-mcp
git pull origin main

# Deploy to Pi
cd ../lacylights-rpi
./scripts/deploy.sh
```

The deployment script automatically:
- Type checks code
- Syncs changes to Pi
- Rebuilds on Pi
- Restarts service
- Runs health checks

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

### Checking Application Version

```bash
# Backend version
ssh pi@lacylights.local 'cd /opt/lacylights/backend && npm version'

# Frontend version
ssh pi@lacylights.local 'cd /opt/lacylights/frontend-src && npm version'

# Check what's running
curl -s http://lacylights.local:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __typename }"}' \
  | grep Query
```

## System Updates

### Raspberry Pi OS Updates

Regular system updates for security and stability:

```bash
ssh pi@lacylights.local

# Update package lists
sudo apt-get update

# Show available updates
apt list --upgradable

# Install updates
sudo apt-get upgrade -y

# Reboot if needed (check if /var/run/reboot-required exists)
if [ -f /var/run/reboot-required ]; then
    echo "Reboot required"
    sudo reboot
fi
```

**Frequency:** Weekly or monthly, depending on security requirements

### Full Distribution Upgrade

For major Raspberry Pi OS version updates:

```bash
ssh pi@lacylights.local

# Full upgrade (may take 30+ minutes)
sudo apt-get update
sudo apt-get dist-upgrade -y

# Clean up old packages
sudo apt-get autoremove -y
sudo apt-get autoclean

# Reboot
sudo reboot
```

**Frequency:** When major OS versions are released

**Caution:** Test in development first. May require manual intervention.

### Automatic Updates (Optional)

Enable unattended-upgrades for security patches:

```bash
ssh pi@lacylights.local
sudo apt-get install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure (edit if needed)
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

**Pros:** Always up-to-date security patches
**Cons:** Automatic reboots may interrupt shows

## Dependency Updates

### Node.js Updates

#### Update to Latest LTS

```bash
ssh pi@lacylights.local

# Add NodeSource repository (if not already added)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -

# Update Node.js
sudo apt-get install -y nodejs

# Verify version
node --version
npm --version

# Rebuild LacyLights with new Node version
cd /opt/lacylights/backend
npm rebuild
npm run build

cd /opt/lacylights/frontend-src
npm rebuild
npm run build

# Restart service
sudo systemctl restart lacylights
```

#### Update to Specific Version

```bash
# For Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### npm Package Updates

#### Update Application Dependencies

On your development machine:

```bash
# Check for outdated packages
cd lacylights-node
npm outdated

# Update dependencies
npm update

# Or update specific package
npm update <package-name>

# Run tests
npm test

# Deploy if tests pass
cd ../lacylights-rpi
./scripts/deploy.sh
```

#### Update Global npm

On the Pi:

```bash
ssh pi@lacylights.local
sudo npm install -g npm@latest
npm --version
```

## Firmware Updates

### Raspberry Pi Firmware

Firmware updates improve hardware compatibility and performance:

```bash
ssh pi@lacylights.local

# Update firmware
sudo rpi-update

# Reboot
sudo reboot
```

**Caution:** Only use for specific issues. May cause instability.

**Alternative (safer):**
```bash
# Standard firmware updates (recommended)
sudo apt-get update
sudo apt-get upgrade
```

## Backup Before Updates

Always backup before major updates:

### Quick Backup

```bash
ssh pi@lacylights.local

# Backup database
cp /opt/lacylights/backend/prisma/lacylights.db ~/lacylights-db-$(date +%Y%m%d).db

# Backup configuration
sudo cp /opt/lacylights/backend/.env ~/lacylights-env-$(date +%Y%m%d).backup

# Copy to local machine
scp pi@lacylights.local:~/lacylights-*.{db,backup} ./backups/
```

### Full System Backup

For SD card image backup:

1. Shut down Pi:
   ```bash
   ssh pi@lacylights.local 'sudo shutdown -h now'
   ```

2. Remove SD card and create image on your computer:
   ```bash
   # macOS
   diskutil list
   sudo dd if=/dev/rdisk2 of=lacylights-backup.img bs=1m

   # Linux
   lsblk
   sudo dd if=/dev/sdb of=lacylights-backup.img bs=4M status=progress
   ```

3. Compress image:
   ```bash
   gzip lacylights-backup.img
   ```

## Update Strategy

### Development Environment

1. Update code on development machine
2. Run tests locally
3. Test on development Pi (if available)
4. Deploy to production Pi
5. Monitor for issues

### Production Environment

1. **Schedule updates** - Plan during downtime
2. **Backup first** - Database and config
3. **Test updates** - On dev/staging first if possible
4. **Have rollback plan** - Know how to revert
5. **Monitor after update** - Check logs and performance

## Update Schedule

Recommended update frequency:

| Component | Frequency | Timing |
|-----------|-----------|--------|
| Application code | As needed | After testing |
| Security updates | Weekly | Low-usage times |
| OS updates | Monthly | Scheduled downtime |
| Node.js | Quarterly | When new LTS released |
| Firmware | As needed | Only if required |

## Monitoring Updates

### Check for Available Updates

```bash
ssh pi@lacylights.local

# OS updates
apt list --upgradable

# npm packages (in each project)
cd /opt/lacylights/backend
npm outdated

cd /opt/lacylights/frontend-src
npm outdated
```

### Update Notifications

Set up email notifications for available updates:

```bash
# Install apticron
sudo apt-get install apticron

# Configure
sudo nano /etc/apticron/apticron.conf
# Set EMAIL="your@email.com"
```

## Troubleshooting Updates

### Update Fails

**Problem:** apt-get upgrade fails

**Solutions:**

1. Check disk space:
   ```bash
   df -h
   ```

2. Fix broken packages:
   ```bash
   sudo apt-get install -f
   sudo dpkg --configure -a
   ```

3. Clear package cache:
   ```bash
   sudo apt-get clean
   sudo apt-get update
   ```

### Service Won't Start After Update

**Problem:** LacyLights fails to start after update

**Solutions:**

1. Check logs:
   ```bash
   sudo journalctl -u lacylights -n 50
   ```

2. Rebuild:
   ```bash
   cd /opt/lacylights/backend
   npm install --production
   npm run build
   sudo systemctl restart lacylights
   ```

3. Restore backup:
   ```bash
   # Restore database
   cp ~/lacylights-backup.db /opt/lacylights/backend/prisma/lacylights.db

   # Restore config
   sudo cp ~/lacylights-env.backup /opt/lacylights/backend/.env

   # Fix permissions
   sudo chown lacylights:lacylights /opt/lacylights/backend/prisma/lacylights.db

   # Restart
   sudo systemctl restart lacylights
   ```

### Database Migration Issues

**Problem:** Prisma migration fails after update

**Solutions:**

1. Check migration status:
   ```bash
   cd /opt/lacylights/backend
   npx prisma migrate status
   ```

2. Deploy migrations:
   ```bash
   npx prisma migrate deploy
   ```

3. Reset if necessary (CAUTION: deletes data):
   ```bash
   # Backup first!
   cp /opt/lacylights/backend/prisma/lacylights.db ~/backup-before-reset.db

   # Reset
   npx prisma migrate reset --force

   # Restore data if needed (copy backup back)
   ```

### Dependency Conflicts

**Problem:** npm packages have conflicting dependencies

**Solutions:**

1. Clear npm cache:
   ```bash
   npm cache clean --force
   ```

2. Remove node_modules and reinstall:
   ```bash
   cd /opt/lacylights/backend
   rm -rf node_modules package-lock.json
   npm install --production
   ```

3. Update one package at a time to identify conflict:
   ```bash
   npm update <package> --save
   npm test
   ```

## Rolling Back Updates

### Rollback Application Code

```bash
# On development machine
cd lacylights-node
git log --oneline  # Find commit to rollback to
git checkout <previous-commit-hash>

# Deploy
cd ../lacylights-rpi
./scripts/deploy.sh
```

### Rollback System Updates

```bash
ssh pi@lacylights.local

# Downgrade specific package
sudo apt-get install <package>=<older-version>

# Hold package at current version
sudo apt-mark hold <package>

# Or restore from backup image
# (requires SD card image restoration)
```

### Rollback Database

```bash
# Restore from backup
ssh pi@lacylights.local
sudo systemctl stop lacylights
cp ~/lacylights-backup.db /opt/lacylights/backend/prisma/lacylights.db
sudo chown lacylights:lacylights /opt/lacylights/backend/prisma/lacylights.db
sudo systemctl start lacylights
```

## Best Practices

### Before Updating

1. ✅ Review changelog/release notes
2. ✅ Backup database and configuration
3. ✅ Schedule during low-usage time
4. ✅ Test on development system first
5. ✅ Have rollback plan ready

### During Update

1. ✅ Monitor progress and logs
2. ✅ Don't interrupt the process
3. ✅ Note any warnings or errors
4. ✅ Verify each step completes

### After Update

1. ✅ Check service status
2. ✅ Run health checks
3. ✅ Test key functionality
4. ✅ Monitor logs for errors
5. ✅ Document what was updated

## Emergency Update (Security)

For critical security patches:

```bash
# Quick security update
ssh pi@lacylights.local
sudo apt-get update
sudo apt-get upgrade -y

# Restart if needed
sudo reboot

# Verify service comes back up
sudo systemctl status lacylights
```

## See Also

- [DEPLOYMENT.md](DEPLOYMENT.md) - Deploying application updates
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Fixing issues after updates
- [INITIAL_SETUP.md](INITIAL_SETUP.md) - Fresh installation
