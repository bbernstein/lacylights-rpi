# Quick Fix: Update Failed Due to Read-Only Filesystem

## The Problem

You tried to update lacylights-fe and got this error:

```
tee: /opt/lacylights/logs/update.log: Read-only file system
curl: (22) The requested URL returned error: 404
```

This happens because your Raspberry Pi's filesystem is mounted as **read-only** to protect the SD card.

## Immediate Fix (Run on Your Raspberry Pi)

### Step 1: Remount Filesystem as Read-Write

```bash
sudo mount -o remount,rw /
```

### Step 2: Ensure You're in a Valid Directory

```bash
cd /tmp
```

### Step 3: Run the Update

```bash
sudo /opt/lacylights/scripts/update-repos.sh update lacylights-fe latest
```

### Step 4: Remount as Read-Only (Optional but Recommended)

```bash
sync
sudo mount -o remount,ro /
```

## Better Solution: Use the Wrapper Script

We've created a wrapper that handles all of this automatically. **Use this for future updates:**

```bash
# Update frontend
cd /tmp
sudo /opt/lacylights/scripts/update-repos-wrapper.sh update lacylights-fe latest

# Update backend
sudo /opt/lacylights/scripts/update-repos-wrapper.sh update lacylights-go latest

# Update all components
sudo /opt/lacylights/scripts/update-repos-wrapper.sh update-all
```

## Verify Current Filesystem Status

To check if your filesystem is read-only:

```bash
mount | grep 'on / '
```

Look for `(ro,` or `(rw,` in the output:
- `ro` = read-only
- `rw` = read-write

## Install the Wrapper Script

If you don't have the wrapper script yet, you need to update your lacylights-rpi installation:

```bash
# Download latest lacylights-rpi scripts
cd ~
curl -fsSL https://github.com/bbernstein/lacylights-rpi/archive/refs/heads/main.tar.gz | tar xz
sudo cp lacylights-rpi-main/scripts/update-repos-wrapper.sh /opt/lacylights/scripts/
sudo chmod +x /opt/lacylights/scripts/update-repos-wrapper.sh
rm -rf lacylights-rpi-main
```

## Why Did the 404 Happen?

The 404 error was likely a secondary issue caused by the read-only filesystem:
1. The script couldn't write to the log directory
2. This caused working directory errors
3. Which led to curl failing with 404

The distribution server (https://dist.lacylights.com) is working fine - the issue was local.

## More Information

See [docs/READ_ONLY_FILESYSTEM.md](docs/READ_ONLY_FILESYSTEM.md) for complete documentation on handling read-only filesystems.
