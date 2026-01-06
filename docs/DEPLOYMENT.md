# LacyLights Deployment Guide

This guide covers deploying code changes to an existing LacyLights Raspberry Pi installation.

## Prerequisites

- LacyLights already installed and running on Raspberry Pi (see [INITIAL_SETUP.md](INITIAL_SETUP.md))
- SSH access to the Pi
- All LacyLights repositories cloned locally
- Changes committed to git in respective repositories

## Quick Deployment

For most code changes, use the general deployment script:

```bash
cd lacylights-rpi
./scripts/deploy.sh
```

This will:
1. Type check all code before deployment
2. Sync code to the Raspberry Pi
3. Rebuild backend, frontend, and MCP server
4. Restart the LacyLights service
5. Run health checks

## Deployment Options

### Deploy All Components

```bash
./scripts/deploy.sh
```

### Deploy Specific Components

```bash
# Backend only
./scripts/deploy.sh --backend-only

# Frontend only
./scripts/deploy.sh --frontend-only
```

### Skip Rebuild

If you only want to sync files without rebuilding:

```bash
./scripts/deploy.sh --skip-rebuild
```

### Skip Service Restart

If you want to rebuild but not restart the service:

```bash
./scripts/deploy.sh --skip-restart
```

## Environment Variables

Set the target Pi hostname (default: `pi@lacylights.local`):

```bash
PI_HOST=pi@mylights.local ./scripts/deploy.sh
```

## Deployment Process

The deployment script performs these steps:

### 1. Prerequisites Check
- Verifies all repositories exist locally
- Checks if Raspberry Pi is reachable
- Tests SSH access

### 2. Type Checking
- Runs TypeScript type check on all components
- Fails fast if type errors are found
- Prevents deploying broken code

### 3. Code Sync
- Uses `rsync` to efficiently sync only changed files
- Excludes `node_modules`, `.git`, build artifacts, tests
- Maintains file permissions and timestamps

### 4. Remote Build
- Installs production dependencies
- Builds TypeScript to JavaScript
- Creates optimized frontend bundle
- All builds run on the Pi in production mode

### 5. Service Management
- Restarts the LacyLights systemd service
- Waits for service to start
- Verifies service is running

### 6. Health Checks
- Tests GraphQL endpoint
- Checks WiFi availability
- Reports any issues

## Common Workflows

### After Changing Backend Code

```bash
cd lacylights-go
# Make changes
git add .
git commit -m "Fix: improve DMX timing"
cd ../lacylights-rpi
./scripts/deploy.sh --backend-only
```

### After Changing Frontend Code

```bash
cd lacylights-fe
# Make changes
git add .
git commit -m "Add: new scene editor"
cd ../lacylights-rpi
./scripts/deploy.sh --frontend-only
```

### Quick File Sync (No Rebuild)

If you're iterating quickly and want to sync files without rebuilding:

```bash
./scripts/deploy.sh --skip-rebuild --skip-restart
# Then manually restart when ready:
ssh pi@lacylights.local 'sudo systemctl restart lacylights'
```

## Troubleshooting

### Deployment Fails at Type Check

**Problem:** TypeScript errors prevent deployment

**Solution:**
```bash
# Fix type errors first
cd lacylights-go  # or lacylights-fe
npm run type-check
# Fix errors, then retry deployment
```

### Cannot Reach Raspberry Pi

**Problem:** `Cannot reach lacylights.local`

**Solutions:**
1. Check Pi is powered on
2. Verify network connection
3. Try IP address: `PI_HOST=pi@192.168.1.100 ./scripts/deploy.sh`
4. Check mDNS: `ping lacylights.local`

### Build Fails on Pi

**Problem:** Build fails during remote execution

**Solutions:**
1. Check disk space: `ssh pi@lacylights.local 'df -h'`
2. Check memory: `ssh pi@lacylights.local 'free -h'`
3. View build logs in deployment output
4. Manually build to see full errors:
   ```bash
   ssh pi@lacylights.local
   cd /opt/lacylights/backend
   npm run build
   ```

### Service Fails to Start

**Problem:** Service restart fails

**Solutions:**
1. Check service logs:
   ```bash
   ssh pi@lacylights.local 'sudo journalctl -u lacylights -n 50'
   ```
2. Check environment variables:
   ```bash
   ssh pi@lacylights.local 'sudo cat /opt/lacylights/backend/.env'
   ```
3. Try manual start for more details:
   ```bash
   ssh pi@lacylights.local 'sudo systemctl restart lacylights'
   ssh pi@lacylights.local 'sudo systemctl status lacylights'
   ```

### Database Migration Issues

**Problem:** Database schema changes not applied

**Solution:**
```bash
ssh pi@lacylights.local
cd /opt/lacylights/backend
npx prisma migrate deploy
sudo systemctl restart lacylights
```

## Manual Deployment

If the automated script doesn't work, you can deploy manually:

### 1. Sync Code

```bash
# Backend
rsync -avz --delete --exclude 'node_modules' --exclude '.git' \
    lacylights-go/ pi@lacylights.local:/opt/lacylights/backend/

# Frontend
rsync -avz --delete --exclude 'node_modules' --exclude '.git' \
    lacylights-fe/ pi@lacylights.local:/opt/lacylights/frontend-src/
```

### 2. Build on Pi

```bash
ssh pi@lacylights.local << 'EOF'
cd /opt/lacylights/backend
npm install --production
npm run build

cd /opt/lacylights/frontend-src
npm install --production
npm run build
EOF
```

### 3. Restart Service

```bash
ssh pi@lacylights.local 'sudo systemctl restart lacylights'
```

## Best Practices

### Before Deployment

1. **Commit your changes** - Deployment should always be from committed code
2. **Run tests locally** - Ensure tests pass before deploying
3. **Type check** - The deployment script does this, but check manually too
4. **Review changes** - Use `git diff` to review what you're deploying

### During Deployment

1. **Watch the output** - Deployment script provides detailed progress
2. **Don't interrupt** - Let the deployment complete
3. **Check health** - Verify the health check passes

### After Deployment

1. **Test the changes** - Visit http://lacylights.local and test your changes
2. **Check logs** - Look for any errors: `ssh pi@lacylights.local 'sudo journalctl -u lacylights -f'`
3. **Monitor performance** - Use the health check script: `ssh pi@lacylights.local '~/lacylights-setup/utils/check-health.sh'`

## Rollback

If deployment causes issues, you can rollback:

### Git Rollback

```bash
cd lacylights-go  # or other repo
git revert HEAD
# or
git reset --hard HEAD~1
cd ../lacylights-rpi
./scripts/deploy.sh
```

### Service Logs

To investigate issues before rolling back:

```bash
# View recent logs
ssh pi@lacylights.local 'sudo journalctl -u lacylights -n 100'

# Follow logs in real-time
ssh pi@lacylights.local 'sudo journalctl -u lacylights -f'

# View only errors
ssh pi@lacylights.local 'sudo journalctl -u lacylights -p err'
```

## Advanced Usage

### Custom Rsync Options

Set additional rsync options:

```bash
RSYNC_OPTS="-avz --progress" ./scripts/deploy.sh
```

### Deploy from Different Branch

```bash
cd lacylights-go
git checkout develop
cd ../lacylights-rpi
./scripts/deploy.sh --backend-only
```

### Deploy to Multiple Pis

```bash
for host in pi@light1.local pi@light2.local pi@light3.local; do
    PI_HOST=$host ./scripts/deploy.sh
done
```

## Next Steps

- [UPDATING.md](UPDATING.md) - Update system and dependencies
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [WIFI_SETUP.md](WIFI_SETUP.md) - WiFi configuration
