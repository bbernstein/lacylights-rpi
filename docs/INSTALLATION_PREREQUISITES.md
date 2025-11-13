# Installation Prerequisites

This document covers the prerequisites and common setup issues for installing LacyLights on a fresh Raspberry Pi.

## System Requirements

### Hardware
- **Raspberry Pi 4** (4GB+ RAM recommended)
- **MicroSD card** (32GB+ Class 10 or better)
- **Power supply** (official 5V 3A recommended)
- **Ethernet cable** for wired DMX network
- Built-in WiFi for internet access

### Software
- **Raspberry Pi OS** (64-bit, Lite or Desktop)
- **SSH enabled**
- **Internet connection** for initial setup

## Before Installation

### 1. Update CA Certificates

Fresh Raspberry Pi installations may have outdated SSL certificates, which will cause curl to fail with SSL errors.

**Fix this first:**

```bash
# Update package lists
sudo apt-get update

# Install/update CA certificates and curl
sudo apt-get install -y ca-certificates curl
```

### 2. Verify System Date/Time

Incorrect system time can cause SSL certificate validation failures.

```bash
# Check current date/time
date

# If incorrect, enable NTP (requires internet)
sudo timedatectl set-ntp true

# Verify it's fixed
date
```

### 3. Verify Internet Connection

```bash
# Test basic connectivity
ping -c 3 8.8.8.8

# Test DNS resolution
ping -c 3 google.com

# Test HTTPS access
curl -I https://www.google.com
```

## Common Installation Issues

### SSL Certificate Errors

**Symptom:**
```
curl: (60) SSL certificate problem: self-signed certificate
```

**Causes:**
1. Outdated CA certificates (most common)
2. Incorrect system date/time
3. Network proxy interfering with SSL

**Solutions:**

1. **Update CA certificates** (recommended):
   ```bash
   sudo apt-get update
   sudo apt-get install -y ca-certificates
   ```

2. **Fix system time**:
   ```bash
   sudo timedatectl set-ntp true
   date  # Verify it's correct
   ```

3. **Check for proxy issues**:
   ```bash
   # Check if proxy is set
   env | grep -i proxy

   # If you see proxy settings you don't recognize, unset them:
   unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
   ```

4. **Alternative installation method** (if SSL issues persist after updating CA certificates and system time):
   ```bash
   # Use git clone to obtain the installation files directly:
   git clone https://github.com/bbernstein/lacylights-rpi.git
   # Then run the install script manually:
   cd lacylights-rpi
   bash install.sh
   ```

### No Internet Connection

**Symptom:**
```
curl: (6) Could not resolve host: raw.githubusercontent.com
```

**Solutions:**

1. **Check WiFi connection** (if using WiFi):
   ```bash
   # Check WiFi status
   iwconfig

   # List available networks
   sudo iwlist wlan0 scan | grep ESSID

   # Connect to WiFi using raspi-config
   sudo raspi-config
   # Select: System Options → Wireless LAN
   ```

2. **Check Ethernet connection** (if using Ethernet):
   ```bash
   # Check ethernet status
   ip addr show eth0

   # Check cable is connected
   ethtool eth0 | grep "Link detected"
   ```

3. **Verify DNS resolution**:
   ```bash
   # Check DNS servers
   cat /etc/resolv.conf

   # Should show something like:
   # nameserver 8.8.8.8
   # nameserver 8.8.4.4

   # If empty or wrong, add Google DNS temporarily:
   echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf
   ```

### Insufficient Disk Space

**Symptom:**
```
No space left on device
```

**Solutions:**

1. **Check available space**:
   ```bash
   df -h
   ```

2. **Clean up if needed**:
   ```bash
   # Remove old package archives
   sudo apt-get clean

   # Remove orphaned packages
   sudo apt-get autoremove

   # Check space again
   df -h
   ```

3. **Expand filesystem** (if SD card is larger than shown):
   ```bash
   sudo raspi-config
   # Select: Advanced Options → Expand Filesystem
   sudo reboot
   ```

## Recommended First-Time Setup

For a smooth installation experience, follow these steps on a fresh Raspberry Pi:

### 1. Initial OS Setup

```bash
# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Install essential tools
sudo apt-get install -y ca-certificates curl git

# Enable NTP for accurate time
sudo timedatectl set-ntp true

# Verify everything works
date
ping -c 3 google.com
curl -I https://www.google.com
```

### 2. Configure Networking

**For WiFi:**
```bash
sudo raspi-config
# System Options → Wireless LAN
# Enter SSID and password
```

**For Static IP (optional but recommended):**
```bash
# Edit dhcpcd.conf
sudo nano /etc/dhcpcd.conf

# Add at the end (example for eth0):
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 8.8.4.4

# Save and restart
sudo reboot
```

### 3. Enable SSH (if not already enabled)

```bash
sudo systemctl enable ssh
sudo systemctl start ssh
```

### 4. Set Hostname (optional)

```bash
sudo raspi-config
# System Options → Hostname
# Set to: lacylights

# Or manually:
sudo hostnamectl set-hostname lacylights
sudo reboot
```

## Post-Installation Verification

After running the LacyLights installer, verify it worked:

```bash
# Check installation directory exists
ls -la ~/lacylights-setup

# Check scripts are present
ls ~/lacylights-setup/scripts/

# Verify scripts are executable
ls -la ~/lacylights-setup/scripts/setup-new-pi.sh
```

## Alternative Installation Methods

If the one-command installer continues to fail, you can use these alternatives:

### Method 1: Download and Run Locally

```bash
# Download installer
wget https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh

# Review it
less install.sh

# Make executable and run
chmod +x install.sh
./install.sh
```

### Method 2: Git Clone

```bash
# Install git
sudo apt-get install -y git

# Clone repository
git clone https://github.com/bbernstein/lacylights-rpi.git

# Run setup
cd lacylights-rpi
./scripts/setup-new-pi.sh localhost
```

### Method 3: Offline Installation

If your Pi has no internet, consider using a USB drive to transfer the release archive or use an ethernet connection for initial setup.

You can download a release archive on a computer with internet:
1. Go to https://github.com/bbernstein/lacylights-rpi/releases
2. Download the latest `lacylights-rpi-*.tar.gz` file
3. Transfer to Pi via USB drive or SCP
4. Extract: `tar xzf lacylights-rpi-*.tar.gz -C ~/lacylights-setup`
5. Run setup: `cd ~/lacylights-setup && ./scripts/setup-new-pi.sh localhost`

## Getting Help

If you continue to have issues:

1. **Check the error message** carefully
2. **Review this document** for your specific error
3. **Check system logs**:
   ```bash
   # System log
   sudo journalctl -xe

   # Network issues
   sudo journalctl -u NetworkManager
   ```

4. **Gather diagnostic info**:
   ```bash
   # System info
   uname -a
   cat /etc/os-release

   # Network info
   ip addr
   ip route
   cat /etc/resolv.conf

   # Disk space
   df -h

   # Check date/time
   date
   timedatectl
   ```

5. **Open an issue**: https://github.com/bbernstein/lacylights-rpi/issues
   - Include the error message
   - Include the diagnostic info above
   - Describe what you've tried

## Security Considerations

### Changing Default Password

**IMPORTANT**: Change the default Raspberry Pi password immediately:

```bash
passwd
```

### SSH Key Authentication

For better security, set up SSH key authentication:

```bash
# On your local machine:
ssh-copy-id pi@lacylights.local

# Then on the Pi, disable password authentication (optional):
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart ssh
```

### Firewall (Optional)

```bash
# Install and configure UFW
sudo apt-get install -y ufw

# Allow SSH
sudo ufw allow 22/tcp

# Allow LacyLights (if needed for external access)
sudo ufw allow 4000/tcp

# Enable firewall
sudo ufw enable
```

## Raspberry Pi OS Versions

LacyLights is tested on:
- ✅ Raspberry Pi OS (64-bit) Bullseye
- ✅ Raspberry Pi OS (64-bit) Bookworm
- ✅ Raspberry Pi OS Lite (64-bit)

32-bit versions should work but are not actively tested.

## Summary Checklist

Before installing LacyLights, verify:

- [ ] Raspberry Pi OS is installed and booted
- [ ] SSH access works
- [ ] Internet connection is active
- [ ] CA certificates are up to date: `sudo apt-get install -y ca-certificates`
- [ ] System time is correct: `date`
- [ ] Can access GitHub: `curl -I https://github.com`
- [ ] Sufficient disk space: `df -h` (at least 5GB free)
- [ ] Default password changed (security)

Once all checkboxes are complete, proceed with installation:

```bash
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash
```
