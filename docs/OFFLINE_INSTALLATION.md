# LacyLights Offline Installation

This guide explains how to install LacyLights on a Raspberry Pi that **does not have internet access**.

## Overview

The offline installation is designed for production deployments where the Raspberry Pi is on an isolated internal network without internet connectivity. This is ideal for:

- **Private DMX networks** - Pi connected only to lighting fixtures
- **Secure environments** - No external network access required
- **Air-gapped installations** - Complete isolation from internet
- **Mobile setups** - Installations without reliable internet

## Two-Phase Installation

### Phase 1: Preparation (on Mac/PC with Internet)

Run on your development machine that has internet access:

```bash
cd /path/to/lacylights-rpi
./scripts/prepare-offline.sh
```

**What this does:**
1. Downloads release archives from GitHub
2. Downloads all npm dependencies
3. Caches node_modules for ARM architecture compatibility
4. Creates a complete offline bundle

**Output:**
- Creates `lacylights-offline-YYYYMMDD-HHMMSS.tar.gz`
- Bundle contains everything needed for installation

**Options:**
```bash
# Use specific versions
./scripts/prepare-offline.sh \
    --backend-version v1.1.0 \
    --frontend-version v0.2.0 \
    --mcp-version v0.1.0

# Custom output directory
./scripts/prepare-offline.sh --output /tmp/my-bundle
```

### Phase 2: Installation (on Raspberry Pi without Internet)

Run from your Mac/PC that can connect to the Pi:

```bash
cd /path/to/lacylights-rpi
./scripts/setup-new-pi.sh pi@ntclights.local \
    --offline-bundle lacylights-offline-20251027-160000.tar.gz
```

**What this does:**
1. Transfers the offline bundle to the Pi
2. Extracts all files and dependencies
3. Rebuilds native modules for ARM
4. Configures and starts all services

## Network Requirements

### For the Mac/PC (Installer)
- **Internet access** - Required during preparation phase
- **SSH access to Pi** - Can connect via internal network or both networks

### For the Raspberry Pi
- **No internet required** - Can be on isolated internal network
- **Internal network only** - Connected to DMX fixtures via Ethernet
- **SSH accessible from Mac** - Mac must be able to reach Pi (same network or routing)

## Network Topology Examples

### Option 1: Mac with Both Networks

```
Internet
   ↓
Mac (WiFi: Internet, Ethernet: Internal)
   ↓ SSH over Ethernet
Raspberry Pi (Ethernet: 10.0.8.x)
   ↓ DMX/Art-Net
Lighting Fixtures
```

### Option 2: Mac Switches Networks

```
# Step 1: Prepare bundle (Mac on WiFi with internet)
Mac WiFi → Internet → Download bundle

# Step 2: Switch to internal network
Mac Ethernet → Internal Network (10.0.8.x)
   ↓ SSH
Raspberry Pi → DMX Fixtures
```

### Option 3: Mac Routes Between Networks

```
Internet
   ↓
Mac (WiFi: Internet, routing enabled)
   ↓
Internal Network Switch
   ↓
Raspberry Pi (10.0.8.x) → DMX Fixtures
```

## Complete Example

### Scenario
- Mac has WiFi (internet) and Ethernet (internal network 10.0.8.0/24)
- Pi on internal network only: `ntclights.local` (10.0.8.100)
- Pi has no internet, no DNS

### Step-by-Step

**1. Prepare offline bundle (Mac on WiFi):**

```bash
cd ~/src/lacylights/lacylights-rpi

# Prepare bundle with latest releases
./scripts/prepare-offline.sh

# Output: lacylights-offline-20251027-143000.tar.gz
```

**2. Install on Pi (Mac connected to internal network):**

```bash
# Mac can reach Pi via Ethernet
ping ntclights.local  # or ping 10.0.8.100

# Run offline installation
./scripts/setup-new-pi.sh pi@ntclights.local \
    --offline-bundle lacylights-offline-20251027-143000.tar.gz
```

**3. Installation proceeds:**
- Transfers ~200MB bundle to Pi
- Extracts source code
- Extracts pre-downloaded npm dependencies
- Rebuilds native modules for ARM
- Runs migrations
- Builds frontend/backend
- Configures nginx
- Starts services

**4. Verify installation:**

```bash
# From Mac (connected to internal network)
curl http://ntclights.local/
# Should return HTTP 200 with frontend HTML
```

## What Gets Transferred

The offline bundle contains:

```
lacylights-offline-bundle/
├── releases/
│   ├── backend.tar.gz              # Backend source code
│   ├── backend-node_modules.tar.gz # Pre-downloaded dependencies
│   ├── frontend.tar.gz             # Frontend source code
│   ├── frontend-node_modules.tar.gz
│   ├── mcp.tar.gz                  # MCP server source code
│   └── mcp-node_modules.tar.gz
├── npm-cache/                      # Complete npm cache (unused, backup)
├── bundle-info.json                # Version metadata
└── install-from-bundle.sh          # Installation helper
```

## Advantages

1. **No Pi Internet Required** - Pi can be completely isolated
2. **Faster Installation** - No waiting for downloads on Pi
3. **Repeatable** - Same bundle for multiple Pis
4. **Version Control** - Bundle locks versions, no surprises
5. **Portable** - Transfer bundle via USB if needed

## Architecture Compatibility

The preparation script downloads dependencies on Mac (x64/ARM64) but creates node_modules tarballs that are then **rebuilt** on the Pi (ARM) during installation:

- **Pure JavaScript packages** - Work across architectures
- **Native modules** - Rebuilt with `npm rebuild` on Pi
- **Prisma** - Regenerated for ARM with `prisma generate`

This ensures compatibility even though Mac and Pi have different architectures.

## Troubleshooting

### Bundle Not Found

```
Error: Offline bundle not found: lacylights-offline-20251027-143000.tar.gz
```

**Solution:** Run `prepare-offline.sh` first to create the bundle.

### SSH Connection Fails

```
Error: Cannot reach ntclights.local
```

**Solution:** Ensure Mac can reach Pi on internal network:
- Check Ethernet connection
- Verify Pi's IP: `ssh pi@10.0.8.100`
- Check routing if using both WiFi and Ethernet

### Native Module Errors

```
Error: Could not find module '@prisma/engines'
```

**Solution:** The offline build includes `npm rebuild` which should handle this. If it persists:
1. SSH to Pi: `ssh pi@ntclights.local`
2. Rebuild manually: `cd /opt/lacylights/backend && npm rebuild`
3. Regenerate Prisma: `npx prisma generate`

### Transfer Too Slow

If bundle transfer is very slow over SSH:

**Option 1:** Use compression
```bash
scp -C lacylights-offline-*.tar.gz pi@ntclights.local:~/
```

**Option 2:** Transfer via USB drive
```bash
# On Mac
cp lacylights-offline-*.tar.gz /Volumes/USB/

# On Pi (after USB mount)
cp /media/pi/USB/lacylights-offline-*.tar.gz ~/
```

## Comparison: Online vs Offline Installation

| Feature | Online Installation | Offline Installation |
|---------|-------------------|---------------------|
| Pi Internet | **Required** | **Not Required** |
| Preparation | None | Run `prepare-offline.sh` |
| Install Time | 15-20 minutes | 10-15 minutes |
| Downloads | During installation | Before installation |
| Repeatability | May vary with updates | Locked versions |
| Network Isolation | No | Yes |

## See Also

- [INITIAL_SETUP.md](INITIAL_SETUP.md) - Standard online installation
- [NETWORK_ARCHITECTURE.md](NETWORK_ARCHITECTURE.md) - Dual-network routing
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting
