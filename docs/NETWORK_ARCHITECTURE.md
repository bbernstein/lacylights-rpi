# LacyLights Network Architecture

This document explains how LacyLights manages dual-network routing for production deployments.

## Design Goals

1. **Ethernet for local DMX network** - Reliable, low-latency connection to lighting fixtures
2. **WiFi for internet** - Access to AI models, updates, and external services
3. **Works standalone** - Device operates on local network without WiFi
4. **User-configurable** - No hardcoded WiFi SSIDs, works with any network
5. **Automatic routing** - No manual configuration required

## Network Interfaces

### Ethernet (eth0)

**Purpose:** DMX/Art-Net lighting control network

**Configuration:**
- Typically DHCP from local router/switch
- Can be static IP if needed
- Connected to lighting fixtures and controllers

**Route Priority:**
- **Metric: 200** (low priority for internet)
- Used only for local subnet traffic
- Never becomes default gateway for internet

**Example Setup:**
```
IP: 10.0.8.100 (from local DHCP)
Gateway: 10.0.8.1
Subnet: 10.0.8.0/24
```

### WiFi (wlan0)

**Purpose:** Internet gateway for external services

**Configuration:**
- User-configured via web interface
- Works with any SSID/password
- DHCP from WiFi router

**Route Priority:**
- **Metric: 100** (high priority for internet)
- Becomes default gateway when connected
- Routes all non-local traffic

**Example Setup:**
```
IP: 192.168.1.150 (from WiFi DHCP)
Gateway: 192.168.1.1
Subnet: 192.168.1.0/24
```

## Automatic Route Management

### NetworkManager Dispatcher Script

Located at: `/etc/NetworkManager/dispatcher.d/99-route-priority`

This script automatically runs whenever a network interface changes state:

**For Ethernet (eth0):**
- Sets `ipv4.route-metric 200` (low priority)
- Sets `ipv6.route-metric 200`
- Ensures it's never used as default gateway

**For WiFi (wlan0):**
- Sets `ipv4.route-metric 100` (high priority)
- Sets `ipv6.route-metric 100`
- Automatically becomes default gateway

### Route Metrics Explained

Linux uses route metrics to determine which gateway to use:
- **Lower metric = Higher priority**
- **Higher metric = Lower priority**

```bash
# Example routing table with both interfaces:
default via 192.168.1.1 dev wlan0 proto dhcp metric 100   # WiFi - preferred
default via 10.0.8.1 dev eth0 proto dhcp metric 200       # Ethernet - backup
10.0.8.0/24 dev eth0 proto kernel scope link src 10.0.8.100
192.168.1.0/24 dev wlan0 proto kernel scope link src 192.168.1.150
```

In this example:
- Internet traffic (default route) goes through wlan0 (metric 100)
- Local 10.0.8.0/24 traffic goes through eth0 (direct route)
- Local 192.168.1.0/24 traffic goes through wlan0 (direct route)

## Deployment Scenarios

### Scenario 1: Production with WiFi

**Setup:**
- Ethernet connected to lighting fixtures on 10.0.8.0/24
- WiFi connected to customer's network on 192.168.1.0/24

**Routing:**
- DMX traffic (10.0.8.x) → eth0
- Internet traffic (github.com, openai.com) → wlan0
- Works perfectly

### Scenario 2: Production without WiFi

**Setup:**
- Ethernet connected to lighting fixtures on 10.0.8.0/24
- No WiFi configured

**Routing:**
- DMX traffic (10.0.8.x) → eth0
- Internet traffic → No route (expected, works offline)
- Device fully functional for lighting control

### Scenario 3: Development/Setup

**Setup:**
- Ethernet connected to laptop/router with internet on 10.0.8.0/24
- WiFi not configured yet

**Routing:**
- All traffic → eth0 (only interface)
- Can download from GitHub during initial setup
- After WiFi configured, routes switch automatically

## Setup Process

During `setup-new-pi.sh`:

1. **Step 2: Network Setup** (`02-network-setup.sh`)
   - Detects Ethernet connection
   - Sets Ethernet metric to 200
   - Installs dispatcher script to `/etc/NetworkManager/dispatcher.d/`
   - Configures NetworkManager for automatic handling

2. **User configures WiFi** (via web interface)
   - User enters SSID/password through LacyLights web UI
   - Backend creates NetworkManager connection
   - Dispatcher script automatically runs
   - WiFi metric set to 100
   - Routes automatically updated

3. **No manual configuration needed**
   - Everything happens automatically
   - Works with any WiFi network
   - Survives reboots

## Troubleshooting

### Check Current Routes

```bash
# View routing table
ip route show

# Should show both routes with different metrics:
default via 192.168.1.1 dev wlan0 metric 100   # WiFi preferred
default via 10.0.8.1 dev eth0 metric 200       # Ethernet backup
```

### Check Route Metrics

```bash
# Check Ethernet metric
nmcli -f ipv4.route-metric connection show "Wired connection 1"

# Check WiFi metric (replace with actual connection name)
nmcli -f ipv4.route-metric connection show "YourWiFiSSID"
```

### Test Internet Routing

```bash
# Check which interface is used for internet
ip route get 8.8.8.8

# Should show: "8.8.8.8 via 192.168.1.1 dev wlan0 src 192.168.1.150"
```

### Test Local Routing

```bash
# Check which interface is used for local DMX
ip route get 10.0.8.50

# Should show: "10.0.8.50 dev eth0 src 10.0.8.100"
```

### Manually Fix Routes (if needed)

```bash
# Reset Ethernet metric
sudo nmcli connection modify "Wired connection 1" ipv4.route-metric 200
sudo nmcli connection down "Wired connection 1"
sudo nmcli connection up "Wired connection 1"

# Reset WiFi metric
sudo nmcli connection modify "YourSSID" ipv4.route-metric 100
sudo nmcli connection down "YourSSID"
sudo nmcli connection up "YourSSID"
```

## Production Considerations

### Shipping Configuration

When shipping a LacyLights device:

1. ✅ Dispatcher script is installed
2. ✅ Ethernet metric is pre-configured
3. ✅ Device works on local network immediately
4. ✅ Customer can add WiFi through web interface
5. ✅ Routes automatically configure on first WiFi connection

### No Hardcoding Required

The system does NOT require:
- ❌ Hardcoded WiFi SSID
- ❌ Hardcoded WiFi password
- ❌ Hardcoded IP subnets
- ❌ Manual route configuration
- ❌ Customer technical knowledge

### Automatic Behavior

The system automatically:
- ✅ Detects WiFi when user configures it
- ✅ Sets correct route priorities
- ✅ Routes internet through WiFi
- ✅ Routes local DMX through Ethernet
- ✅ Maintains configuration across reboots

## Technical Details

### NetworkManager Connection Files

Location: `/etc/NetworkManager/system-connections/`

**Ethernet connection:**
```ini
[connection]
id=Wired connection 1
type=ethernet

[ipv4]
method=auto
route-metric=200
```

**WiFi connection (created by user):**
```ini
[connection]
id=CustomerWiFi
type=wifi

[wifi]
ssid=CustomerWiFi

[ipv4]
method=auto
route-metric=100
```

### Dispatcher Script Execution

The dispatcher script is called by NetworkManager:

```bash
# Called with: /etc/NetworkManager/dispatcher.d/99-route-priority <interface> <action>
# Example: 99-route-priority wlan0 up
```

The script:
1. Checks interface type (wifi vs ethernet)
2. Gets the connection name for that interface
3. Sets appropriate metrics via `nmcli connection modify`
4. Logs actions via `logger -t route-priority`

### Viewing Dispatcher Logs

```bash
# View dispatcher script logs
journalctl -t route-priority

# Should show:
# "Configuring eth0 (ethernet) with high metric (local only)"
# "Configuring wlan0 (wifi) with low metric (internet gateway)"
```

## See Also

- [INITIAL_SETUP.md](INITIAL_SETUP.md) - Setup instructions
- [WIFI_SETUP.md](WIFI_SETUP.md) - WiFi configuration guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Network troubleshooting
- [network-diagnostic.sh](../utils/network-diagnostic.sh) - Network diagnostic tool
