# LacyLights WiFi Setup Guide

Complete guide to configuring WiFi on your LacyLights Raspberry Pi.

## Overview

LacyLights uses a **dual-network architecture**:

- **Ethernet (wired)** - For DMX/Art-Net lighting control
- **WiFi (wireless)** - For external internet access (AI models, updates)

This allows your lighting network to remain isolated while still providing internet connectivity for system updates.

## Quick Setup

1. Navigate to http://lacylights.local
2. Click **Settings** → **WiFi Configuration**
3. Click **Scan Networks**
4. Select your network
5. Enter password
6. Click **Connect**

## Web Interface

### WiFi Radio Toggle

Enable or disable the WiFi radio:

- **ON (blue)** - WiFi scanning and connection available
- **OFF (gray)** - WiFi disabled, no scanning or connection

**When to disable:**
- Improved security when not needed
- Reduce power consumption
- Isolate system from external networks

### Current Status

Shows your current WiFi connection:

**When connected:**
- Network name (SSID)
- IP address
- Signal strength (percentage)
- Frequency (2.4GHz or 5GHz)

**When not connected:**
- "Not connected" message
- List of available networks below

### Available Networks

Shows all WiFi networks in range:

**Network Information:**
- Signal strength (bars and color)
  - Green: Excellent (75-100%)
  - Yellow: Good (50-74%)
  - Orange: Fair (25-49%)
  - Red: Poor (0-24%)
- Network name (SSID)
- Frequency band (2.4GHz/5GHz)
- Security type (badge)
- Status indicators:
  - **Connected** - Currently connected to this network
  - **Bookmark icon** - Previously connected (saved)

**Actions:**
- **Connect** - Connect to this network
- **Disconnect** - Disconnect from current network
- **Forget** - Remove saved credentials

### Security Types

Supported WiFi security types:

- **Open** - No password required (yellow warning)
- **WEP** - Legacy security (not recommended)
- **WPA/WPA2 Personal** - Standard home WiFi security
- **WPA3 Personal** - Modern security (if supported)
- **WPA/WPA2 Enterprise** - Corporate networks (802.1X)
- **OWE** - Enhanced Open (opportunistic encryption)

**Note:** Enterprise networks (802.1X) require additional configuration and may not work through the web interface.

### Hidden Networks

To connect to a hidden network:

1. Click on any network in the list
2. Enable "Connect to different network"
3. Enter the exact SSID (case-sensitive)
4. Enter password
5. Click **Connect**

## Command Line Configuration

### Using NetworkManager (nmcli)

All WiFi configuration can also be done via SSH:

#### List Available Networks

```bash
ssh pi@lacylights.local
sudo nmcli device wifi list
```

#### Connect to Network

```bash
sudo nmcli device wifi connect "SSID" password "password"
```

#### Disconnect

```bash
sudo nmcli connection down id "SSID"
```

#### Forget Network

```bash
sudo nmcli connection delete id "SSID"
```

#### Enable/Disable WiFi Radio

```bash
# Enable
sudo nmcli radio wifi on

# Disable
sudo nmcli radio wifi off

# Check status
nmcli radio wifi
```

#### View Current Connection

```bash
nmcli connection show --active
```

#### View Saved Connections

```bash
nmcli connection show
```

### Manual Configuration

For advanced scenarios, you can manually configure WiFi:

#### Edit Connection Profile

```bash
sudo nmcli connection edit "SSID"
```

#### Set Static IP

```bash
sudo nmcli connection modify "SSID" \
  ipv4.method manual \
  ipv4.addresses 192.168.1.100/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "8.8.8.8 8.8.4.4"

sudo nmcli connection up "SSID"
```

#### Set Priority (Multiple Networks)

```bash
# Higher number = higher priority
sudo nmcli connection modify "Home WiFi" connection.autoconnect-priority 10
sudo nmcli connection modify "Backup WiFi" connection.autoconnect-priority 5
```

## Troubleshooting

### WiFi Section Doesn't Appear

**Cause:** WiFi not available on this system

**Check:**
```bash
# Verify NetworkManager is installed
which nmcli

# Check for WiFi device
nmcli device status | grep wifi

# Check API reports WiFi available
curl -s http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ wifiStatus { available } }"}'
```

**Fix:**
```bash
# Install NetworkManager
sudo apt-get install network-manager
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# Restart LacyLights
sudo systemctl restart lacylights
```

### Can't See Any Networks

**Causes:**
- WiFi radio disabled
- No networks in range
- Scan hasn't been performed yet

**Solutions:**

1. **Enable WiFi radio** (if disabled in web interface)

2. **Rescan for networks:**
   ```bash
   sudo nmcli device wifi rescan
   sudo nmcli device wifi list
   ```

3. **Check WiFi device status:**
   ```bash
   nmcli device status
   ```

4. **Ensure WiFi is unblocked:**
   ```bash
   rfkill list
   # If blocked:
   sudo rfkill unblock wifi
   ```

### Connection Fails

**Common causes:**

#### 1. Wrong Password
- Double-check password (case-sensitive)
- Try typing manually instead of pasting
- Check for extra spaces

#### 2. Weak Signal
- Move Pi closer to router
- Check signal strength in network list
- Try different antenna position
- Use external WiFi adapter if built-in is weak

#### 3. Unsupported Security
- Check security type
- Enterprise (802.1X) may not work
- Try WPA2-PSK network first

#### 4. Router Issues
- Check router is functioning
- Try other devices on same network
- Restart router
- Check MAC address filtering
- Check client limit on router

#### 5. Channel Congestion
- 2.4GHz: Try channels 1, 6, or 11
- 5GHz: Less congested but shorter range
- Use WiFi analyzer to find best channel

### Connection Drops Randomly

**Causes and Solutions:**

#### 1. Power Management

```bash
# Disable WiFi power saving
sudo iwconfig wlan0 power off

# Make permanent
echo 'wireless-power off' | sudo tee -a /etc/network/interfaces
```

#### 2. Weak Signal
- Check signal strength
- Reposition Pi or access point
- Reduce interference (microwaves, Bluetooth, etc.)

#### 3. IP Conflict
```bash
# Release and renew IP
sudo nmcli connection down id "SSID"
sudo nmcli connection up id "SSID"
```

#### 4. Router Timeout
- Increase router DHCP lease time
- Configure static IP on Pi

### Connected But No Internet

**Diagnosis:**
```bash
# Check connection
ip addr show wlan0

# Ping gateway
ping -c 4 $(ip route | grep default | grep wlan0 | awk '{print $3}')

# Ping external IP
ping -c 4 8.8.8.8

# Check DNS
nslookup google.com
```

**Solutions:**

#### 1. Gateway Unreachable
```bash
# Check route
ip route show

# Add default route if missing
sudo ip route add default via <gateway-ip> dev wlan0
```

#### 2. DNS Not Working
```bash
# Check DNS servers
nmcli connection show "SSID" | grep DNS

# Set DNS manually
sudo nmcli connection modify "SSID" ipv4.dns "8.8.8.8 8.8.4.4"
sudo nmcli connection up "SSID"
```

#### 3. Firewall Blocking
```bash
# Check UFW status
sudo ufw status

# Temporarily disable to test
sudo ufw disable
# Test internet
# Re-enable if this wasn't the issue
sudo ufw enable
```

## Advanced Configuration

### Connect at Boot

Networks saved through the web interface or nmcli will automatically connect at boot.

To prevent auto-connection:
```bash
sudo nmcli connection modify "SSID" connection.autoconnect no
```

### Multiple Network Profiles

Save multiple networks with priorities:

```bash
# Add home network (highest priority)
sudo nmcli device wifi connect "Home WiFi" password "password"
sudo nmcli connection modify "Home WiFi" connection.autoconnect-priority 100

# Add backup network (lower priority)
sudo nmcli device wifi connect "Backup WiFi" password "password"
sudo nmcli connection modify "Backup WiFi" connection.autoconnect-priority 50

# Add fallback hotspot (lowest priority)
sudo nmcli device wifi connect "Phone Hotspot" password "password"
sudo nmcli connection modify "Phone Hotspot" connection.autoconnect-priority 10
```

The Pi will automatically connect to the highest priority available network.

### Guest/Captive Portal Networks

Many guest networks require accepting terms in a browser:

1. Connect to the network
2. Open http://lacylights.local in browser
3. You should be redirected to captive portal
4. Accept terms
5. Return to LacyLights interface

### VPN Over WiFi

To add VPN for additional security:

```bash
# Install OpenVPN
sudo apt-get install openvpn

# Copy your VPN config
sudo cp your-vpn.ovpn /etc/openvpn/client/

# Start VPN
sudo systemctl start openvpn-client@your-vpn
sudo systemctl enable openvpn-client@your-vpn
```

## Security Considerations

### Recommendations

1. **Use WPA2/WPA3 networks** - Avoid open or WEP networks
2. **Different network for lighting** - Keep DMX isolated on wired network
3. **Firewall enabled** - Use UFW to restrict access
4. **Regular updates** - Keep system and packages updated

### Trusted Networks Only

Only connect to networks you trust:
- ✅ Your home WiFi
- ✅ Your phone hotspot
- ✅ Known secure networks
- ❌ Public/cafe WiFi (unless via VPN)
- ❌ Unknown open networks

### Open Networks

If you must use open WiFi:

1. Enable firewall:
   ```bash
   sudo ufw enable
   sudo ufw default deny incoming
   sudo ufw allow 22/tcp  # SSH from specific IP only
   ```

2. Consider VPN (see above)

3. Disable services:
   ```bash
   sudo systemctl stop lacylights
   ```

## WiFi Diagnostics

Run comprehensive WiFi diagnostics:

```bash
ssh pi@lacylights.local
~/lacylights-setup/utils/wifi-diagnostic.sh
```

This checks:
- NetworkManager installation and status
- WiFi device presence and state
- WiFi radio status
- Current connection details
- Available networks
- Saved connections
- Permissions and sudoers configuration
- API WiFi status

## Performance Tips

### Optimize for Raspberry Pi

1. **Use 5GHz when possible** - Less interference, higher throughput
2. **Disable power management** - Prevents disconnections
3. **Choose good channel** - Use WiFi analyzer app
4. **Keep distance short** - Closer to AP = better signal
5. **Update firmware** - Keep Pi and router updated

### Bandwidth Considerations

LacyLights WiFi is primarily for:
- System updates (occasional)
- Web interface access (minimal)

**Not intended for:**
- Streaming large media files
- File transfers
- Art-Net/DMX output (use wired network)

## Best Practices

1. **Test before show** - Verify WiFi connection works
2. **Have backup** - Configure multiple networks if possible
3. **Document settings** - Save SSID and configuration
4. **Monitor connection** - Check signal strength in Status
5. **Wired for lighting** - Never rely on WiFi for DMX output

## See Also

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deploying code changes
- [INITIAL_SETUP.md](INITIAL_SETUP.md) - Initial installation
