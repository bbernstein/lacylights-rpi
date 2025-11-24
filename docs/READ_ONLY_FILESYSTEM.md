# Read-Only Filesystem on Raspberry Pi

## Overview

Raspberry Pi systems are sometimes configured with a read-only root filesystem to prevent SD card corruption from sudden power loss or frequent writes. While this improves reliability, it requires special handling when performing updates.

## Symptoms

When attempting to update LacyLights on a read-only filesystem, you'll see errors like:

```
tee: /opt/lacylights/logs/update.log: Read-only file system
shell-init: error retrieving current directory: getcwd: cannot access parent directories: No such file or directory
```

## Solution

### Option 1: Use the Update Wrapper (Recommended)

We've created a wrapper script that automatically handles read-only filesystem remounting:

```bash
# On the Raspberry Pi
cd /opt/lacylights/scripts
sudo ./update-repos-wrapper.sh update lacylights-fe latest
```

The wrapper will:
1. Detect if the filesystem is read-only
2. Remount as read-write temporarily
3. Run the update
4. Remount as read-only when complete

### Option 2: Manual Remount

If you need to run updates manually:

```bash
# 1. Remount as read-write
sudo mount -o remount,rw /

# 2. Ensure you're in a valid directory
cd /tmp

# 3. Run the update
sudo /opt/lacylights/scripts/update-repos.sh update lacylights-fe latest

# 4. Remount as read-only (optional but recommended)
sudo mount -o remount,ro /
```

### Option 3: Configure Permanent Read-Write (Not Recommended)

If you want to disable read-only mode permanently:

```bash
# Remove read-only flag from /boot/cmdline.txt
sudo sed -i 's/ ro / rw /' /boot/cmdline.txt

# Remove read-only from /etc/fstab
sudo sed -i 's/,ro,/,rw,/' /etc/fstab

# Reboot
sudo reboot
```

**Warning:** This reduces SD card longevity. Only do this if you understand the trade-offs.

## How to Check Filesystem Mode

```bash
# Check if root is read-only
mount | grep 'on / '

# Output for read-only:
# /dev/mmcblk0p2 on / type ext4 (ro,noatime,...)

# Output for read-write:
# /dev/mmcblk0p2 on / type ext4 (rw,noatime,...)
```

## Automated Updates with Read-Only Filesystem

### Update Frontend to Latest

```bash
sudo /opt/lacylights/scripts/update-repos-wrapper.sh update lacylights-fe latest
```

### Update Backend to Latest

```bash
sudo /opt/lacylights/scripts/update-repos-wrapper.sh update lacylights-node latest
```

### Update All Components

```bash
sudo /opt/lacylights/scripts/update-repos-wrapper.sh update-all
```

### Update to Specific Version

```bash
sudo /opt/lacylights/scripts/update-repos-wrapper.sh update lacylights-fe v0.7.2
```

## Integrating with Web Interface

If your LacyLights web interface calls the update script, update it to use the wrapper:

```typescript
// Old (won't work with read-only filesystem):
const result = await execAsync('/opt/lacylights/scripts/update-repos.sh update lacylights-fe latest');

// New (handles read-only filesystem):
const result = await execAsync('/opt/lacylights/scripts/update-repos-wrapper.sh update lacylights-fe latest');
```

## Troubleshooting

### "Cannot proceed without write access to filesystem"

The wrapper couldn't remount the filesystem as read-write. This usually means:
- You're not running with sudo
- The filesystem is corrupted
- There's a mount error

Try:
```bash
sudo -i
mount -o remount,rw /
```

### "Current directory is invalid"

Your working directory was deleted. The wrapper automatically handles this by changing to `/tmp`, but if you see this error, you can manually fix it:

```bash
cd /tmp
```

### Updates Still Failing

If updates continue to fail even with the wrapper:

1. Check disk space:
   ```bash
   df -h
   ```

2. Check for filesystem errors:
   ```bash
   sudo fsck -n /dev/mmcblk0p2
   ```

3. Check system logs:
   ```bash
   sudo journalctl -xe
   ```

## Best Practices

1. **Always use the wrapper script** for updates on Raspberry Pi
2. **Monitor SD card health** - even with read-only mode, SD cards can fail
3. **Keep backups** of your configuration and database
4. **Test updates** on a dev Pi before production

## Related Documentation

- [UPDATING.md](UPDATING.md) - General update procedures
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [DEPLOYMENT.md](DEPLOYMENT.md) - Development deployment guide
