# Release Process Guide

This document provides a comprehensive guide to creating and managing releases for the lacylights-rpi repository, including the new beta versioning capability.

## Table of Contents

- [Overview](#overview)
- [Version Format](#version-format)
- [Beta Releases](#beta-releases)
- [Stable Releases](#stable-releases)
- [Raspberry Pi Specific Notes](#raspberry-pi-specific-notes)
- [Release Checklist](#release-checklist)
- [Distribution Verification](#distribution-verification)
- [Troubleshooting](#troubleshooting)

## Overview

The lacylights-rpi repository uses an automated release system powered by GitHub Actions. The system supports two types of releases:

1. **Stable Releases** (e.g., `v0.1.6`) - Production-ready versions automatically distributed via install.sh
2. **Beta Releases** (e.g., `v0.1.7b1`) - Pre-release versions for testing, require manual download

When you create a release, the automation:

1. Calculates the next version number based on semantic versioning
2. Creates a VERSION file with the new version (plain text, single line)
3. Commits and pushes the version bump
4. Creates a git tag
5. Packages all deployment scripts and configuration files into a tarball
6. Creates a GitHub release with auto-generated release notes
7. Attaches the tarball as a release asset
8. Uploads the artifact to S3 (dist.lacylights.com)
9. Generates SHA256 checksum for download verification
10. Updates DynamoDB with release metadata
11. Updates latest.json metadata (stable releases only)
12. Uploads install.sh to S3 (stable releases only)

## Version Format

### Stable Releases

Format: `vMAJOR.MINOR.PATCH`

Examples:
- `v0.1.6` - Current version
- `v0.1.7` - Next patch version
- `v0.2.0` - Next minor version
- `v1.0.0` - Next major version

### Beta Releases

Format: `vMAJOR.MINOR.PATCHb[N]`

The beta number `[N]` is automatically incremented based on existing beta versions for the same base version.

Examples:
- `v0.1.7b1` - First beta for the upcoming 0.1.7 release
- `v0.1.7b2` - Second beta for the upcoming 0.1.7 release
- `v0.2.0b1` - First beta for the upcoming 0.2.0 release

**Important Beta Versioning Rules:**
- Beta versions point to the **next** stable version you're working toward
- The system automatically finds existing betas and increments the beta number
- When you create a patch beta after `v0.1.6`, it creates `v0.1.7b1` (not `v0.1.6b1`)
- Multiple betas can exist for the same target version (`v0.1.7b1`, `v0.1.7b2`, etc.)
- When you're ready, release the stable version `v0.1.7` to finalize

## Beta Releases

### When to Use Beta Releases

Create a beta release when you want to:
- Test new features before stable release
- Share pre-release versions with testers
- Validate changes on real hardware without affecting production users
- Iterate on features before committing to a stable release

### Creating a Beta Release

#### Via GitHub Actions (Recommended)

1. Go to the [Actions tab](https://github.com/bbernstein/lacylights-rpi/actions)
2. Select **"Create Release"** workflow
3. Click **"Run workflow"**
4. **Enable** the **"Create as prerelease (beta)"** checkbox
5. Choose the version bump type:
   - **patch**: Bug fixes and small improvements (0.0.X)
   - **minor**: New features, backward compatible (0.X.0)
   - **major**: Breaking changes (X.0.0)
6. Optionally provide a custom release name (e.g., "Testing WiFi improvements")
7. Click **"Run workflow"**

**What Happens:**
- If current stable version is `v0.1.6` and you select "patch", it creates `v0.1.7b1`
- If `v0.1.7b1` already exists, it creates `v0.1.7b2`
- The release is marked as "Pre-release" on GitHub
- Files are uploaded to S3 with full metadata
- **install.sh is NOT updated** (security feature - users must explicitly download betas)
- **latest.json is NOT updated** (stable version remains the latest)
- DynamoDB records the beta with `isPrerelease: true`

### Installing a Beta Release

Beta releases require **manual download and installation** for security. They are not automatically installed via `install.sh`.

#### On the Raspberry Pi:

```bash
# Download the specific beta tarball
cd ~
curl -fsSL https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7b1.tar.gz -o lacylights-rpi-beta.tar.gz

# Verify checksum (recommended)
# Get SHA256 from: https://dist.lacylights.com/releases/rpi/0.1.7b1.json
echo "EXPECTED_SHA256  lacylights-rpi-beta.tar.gz" | sha256sum -c

# Extract to installation directory
rm -rf ~/lacylights-setup
mkdir -p ~/lacylights-setup
tar xzf lacylights-rpi-beta.tar.gz -C ~/lacylights-setup

# Make scripts executable
chmod +x ~/lacylights-setup/scripts/*.sh
chmod +x ~/lacylights-setup/setup/*.sh
chmod +x ~/lacylights-setup/utils/*.sh

# Run setup
cd ~/lacylights-setup
sudo ./scripts/setup-local-pi.sh
```

#### From Your Development Machine:

```bash
# Download and install on remote Pi
ssh pi@raspberrypi.local << 'EOF'
  cd ~
  curl -fsSL https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7b1.tar.gz -o lacylights-rpi-beta.tar.gz
  rm -rf ~/lacylights-setup
  mkdir -p ~/lacylights-setup
  tar xzf lacylights-rpi-beta.tar.gz -C ~/lacylights-setup
  chmod +x ~/lacylights-setup/scripts/*.sh
  chmod +x ~/lacylights-setup/setup/*.sh
  chmod +x ~/lacylights-setup/utils/*.sh
EOF

# Then run setup
ssh pi@raspberrypi.local "cd ~/lacylights-setup && sudo ./scripts/setup-local-pi.sh"
```

### Beta Release Metadata

Each beta release has a JSON metadata file for verification:

```bash
# View metadata
curl -fsSL https://dist.lacylights.com/releases/rpi/0.1.7b1.json

# Example response:
{
  "version": "0.1.7b1",
  "url": "https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7b1.tar.gz",
  "sha256": "abc123...",
  "releaseDate": "2025-11-24T10:30:00Z",
  "isPrerelease": true,
  "fileSize": 524288
}
```

## Stable Releases

### When to Create a Stable Release

Create a stable release when:
- All beta testing is complete
- Features are ready for production use
- Documentation is up to date
- No known critical issues exist

### Creating a Stable Release

#### Via GitHub Actions (Recommended)

1. Go to the [Actions tab](https://github.com/bbernstein/lacylights-rpi/actions)
2. Select **"Create Release"** workflow
3. Click **"Run workflow"**
4. **Leave** the **"Create as prerelease (beta)"** checkbox **unchecked**
5. Choose the version bump type:
   - **patch**: Bug fixes and small improvements (0.0.X)
   - **minor**: New features, backward compatible (0.X.0)
   - **major**: Breaking changes (X.0.0)
6. Optionally provide a custom release name
7. Click **"Run workflow"**

**What Happens:**
- If current version is `v0.1.6` and you select "patch", it creates `v0.1.7`
- Any existing beta versions (`v0.1.7b1`, `v0.1.7b2`) become obsolete
- The release is marked as "Latest" on GitHub
- Files are uploaded to S3 with full metadata
- **install.sh is updated** on S3 (users can install with one command)
- **latest.json is updated** to point to this version
- DynamoDB records the release with `isPrerelease: false`

### Installing a Stable Release

Stable releases can be installed automatically:

```bash
# Latest stable release (recommended)
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash

# Specific stable version
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash -s -- v0.1.7

# Remote installation
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | \
    bash -s -- latest pi@raspberrypi.local
```

## Raspberry Pi Specific Notes

### VERSION File

The VERSION file is a **plain text file** containing only the version number (without the `v` prefix):

```
0.1.6
```

**Key Points:**
- Single line, no trailing newline required
- No `v` prefix (use `0.1.6`, not `v0.1.6`)
- Automatically created/updated by the release workflow
- Included in every tarball
- Used by scripts to identify the installed version

### Tarball Format

Each release is distributed as a gzipped tarball:

```
lacylights-rpi-{version}.tar.gz
```

**Contents:**
```
.
├── scripts/           # Deployment and setup scripts
│   ├── deploy.sh
│   ├── setup-new-pi.sh
│   └── setup-local-pi.sh
├── setup/             # Modular setup scripts
│   ├── 01-system-setup.sh
│   ├── 02-network-setup.sh
│   ├── 03-database-setup.sh
│   ├── 04-permissions-setup.sh
│   └── 05-service-install.sh
├── config/            # Configuration templates
│   ├── .env.example
│   └── sudoers.d/
├── systemd/           # Service files
│   └── lacylights.service
├── utils/             # Utility scripts
│   ├── check-health.sh
│   ├── view-logs.sh
│   └── wifi-diagnostic.sh
├── docs/              # Documentation
│   ├── DEPLOYMENT.md
│   ├── INITIAL_SETUP.md
│   ├── TROUBLESHOOTING.md
│   └── ...
├── README.md          # Main documentation
├── LICENSE            # MIT License
└── VERSION            # Version number (plain text)
```

### Install.sh Behavior

**For Stable Releases:**
- install.sh is updated on S3 to point to the new version
- `curl ... install.sh | bash` automatically installs the latest stable release
- Includes automatic SHA256 checksum verification
- Works with both local and remote installation modes

**For Beta Releases:**
- install.sh is NOT updated (security feature)
- Users must manually download the specific beta tarball
- Prevents accidental installation of pre-release versions
- Ensures beta testers are intentionally opting in

### Distribution Infrastructure

**S3 Bucket Structure:**
```
s3://lacylights-dist/releases/rpi/
├── install.sh                          # Latest stable installer
├── latest.json                         # Latest stable metadata
├── lacylights-rpi-0.1.6.tar.gz        # Stable release
├── 0.1.6.json                          # Stable metadata
├── lacylights-rpi-0.1.7b1.tar.gz      # Beta release
├── 0.1.7b1.json                        # Beta metadata
└── ...
```

**DynamoDB Table:**
- Table: `lacylights-releases`
- Primary key: `component` (string) - e.g., "rpi"
- Sort key: `version` (string) - e.g., "0.1.7b1"
- Attributes:
  - `url` - Download URL
  - `sha256` - Checksum
  - `releaseDate` - ISO 8601 timestamp
  - `isPrerelease` - Boolean flag
  - `fileSize` - Size in bytes

## Release Checklist

Use this checklist when creating any release:

### Pre-Release
- [ ] All tests pass locally
- [ ] Documentation is up to date
- [ ] CHANGELOG.md updated (if maintained)
- [ ] No uncommitted changes
- [ ] On the correct branch (usually `main` or `feat/*`)
- [ ] For betas: Clear testing plan defined
- [ ] For stable: All beta testing complete

### Creating the Release
- [ ] Go to GitHub Actions → "Create Release"
- [ ] Select correct version bump type (patch/minor/major)
- [ ] Check "Create as prerelease" for betas, uncheck for stable
- [ ] Provide release name (optional but recommended)
- [ ] Click "Run workflow"
- [ ] Wait for workflow to complete successfully

### Post-Release Verification
- [ ] GitHub release created with correct tag
- [ ] Release notes generated correctly
- [ ] Tarball attached to GitHub release
- [ ] VERSION file updated in repository
- [ ] S3 upload successful (check workflow logs)
- [ ] DynamoDB record created (check workflow logs)
- [ ] For stable: latest.json updated
- [ ] For stable: install.sh updated
- [ ] Download and verify tarball integrity
- [ ] Test installation on a test Raspberry Pi

### Announcement (Stable Releases)
- [ ] Update main README.md if needed
- [ ] Announce in relevant channels
- [ ] Update project documentation
- [ ] Notify active users/testers

## Distribution Verification

### Verify S3 Upload

```bash
# Check tarball exists
curl -I https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7.tar.gz

# Check metadata exists
curl https://dist.lacylights.com/releases/rpi/0.1.7.json

# For stable releases, check latest.json
curl https://dist.lacylights.com/releases/rpi/latest.json

# For stable releases, check install.sh
curl -I https://dist.lacylights.com/releases/rpi/install.sh
```

### Verify DynamoDB

```bash
# Query DynamoDB (requires AWS CLI configured)
aws dynamodb get-item \
  --table-name lacylights-releases \
  --key '{"component": {"S": "rpi"}, "version": {"S": "0.1.7"}}'
```

### Verify SHA256 Checksum

```bash
# Download and verify
curl -fsSL https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7.tar.gz -o release.tar.gz
curl -fsSL https://dist.lacylights.com/releases/rpi/0.1.7.json | grep sha256

# Calculate checksum
sha256sum release.tar.gz
# Compare with metadata value
```

### Test Installation

#### Test Stable Release:

```bash
# Test automatic installation
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash

# Verify version
cd ~/lacylights-setup
cat VERSION  # Should show: 0.1.7
```

#### Test Beta Release:

```bash
# Manual installation required
curl -fsSL https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7b1.tar.gz -o beta.tar.gz
mkdir -p ~/lacylights-setup-beta
tar xzf beta.tar.gz -C ~/lacylights-setup-beta
cat ~/lacylights-setup-beta/VERSION  # Should show: 0.1.7b1
```

## Troubleshooting

### Release Workflow Failed

**Check workflow logs first:**
1. Go to Actions tab
2. Click on the failed workflow run
3. Expand failed steps to see error messages

**Common issues:**

#### Permission denied / refusing to allow a Personal Access Token

**Cause:** RELEASE_TOKEN secret is missing or has insufficient permissions.

**Solution:**
1. See [RELEASE_TOKEN_SETUP.md](RELEASE_TOKEN_SETUP.md) for setup instructions
2. Ensure token has "Contents: Read and write" permission
3. Verify secret is named exactly `RELEASE_TOKEN`

#### Tag already exists

**Cause:** The version tag was already created in a previous run.

**Solution:**
```bash
# Delete tag locally and remotely
git tag -d v0.1.7
git push origin :refs/tags/v0.1.7

# Delete GitHub release
gh release delete v0.1.7 --yes

# Re-run the workflow
```

#### AWS upload failed

**Cause:** AWS credentials missing or incorrect, or S3 bucket permissions issue.

**Solution:**
1. Verify AWS secrets are set:
   - `AWS_DIST_ACCESS_KEY_ID`
   - `AWS_DIST_SECRET_ACCESS_KEY`
   - `AWS_DIST_BUCKET`
   - `AWS_DIST_REGION`
   - `AWS_DIST_DYNAMODB_TABLE`
2. Check IAM permissions for the AWS user
3. Verify S3 bucket exists and is accessible

#### Checksum verification fails

**Cause:** Download was corrupted or tampered with.

**Solution:**
1. Delete the downloaded file
2. Re-download from dist.lacylights.com
3. If problem persists, check S3 file integrity
4. Consider recreating the release

### VERSION File Issues

**Wrong format:**
```bash
# Incorrect (has 'v' prefix or extra content)
v0.1.7

# Correct (plain version number)
0.1.7
```

**Fix in repository:**
```bash
echo "0.1.7" > VERSION
git add VERSION
git commit -m "fix: correct VERSION file format"
git push
```

### Beta Version Not Incrementing

**Symptom:** Creating a beta always creates `v0.1.7b1` instead of incrementing.

**Cause:** Git tags are not fetched, or naming is inconsistent.

**Solution:**
1. Verify existing beta tags: `git tag -l 'v0.1.7b*'`
2. Ensure tags are pushed: `git push origin --tags`
3. Check workflow has `fetch-depth: 0` in checkout step

### Install.sh Not Finding Latest Version

**Symptom:** `curl ... install.sh | bash` installs old version.

**Cause:** Only affects stable releases (expected for betas).

**Solution:**
1. Verify latest.json is updated: `curl https://dist.lacylights.com/releases/rpi/latest.json`
2. Check workflow completed successfully for stable release
3. Ensure release was not created as prerelease by mistake
4. Clear any CDN cache if applicable

### Manual Beta Installation Fails

**Symptom:** Tarball download fails or checksum doesn't match.

**Solution:**
```bash
# Verify beta exists on S3
curl -I https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7b1.tar.gz

# Check metadata
curl https://dist.lacylights.com/releases/rpi/0.1.7b1.json

# Verify GitHub release exists
gh release view v0.1.7b1

# If missing, the release workflow may have failed - check Actions tab
```

## Best Practices

### Beta Release Workflow

1. **Create first beta** (`v0.1.7b1`) after implementing new features
2. **Test thoroughly** on development Raspberry Pi
3. **Create additional betas** (`v0.1.7b2`, etc.) as needed to fix issues
4. **Create stable release** (`v0.1.7`) when testing is complete
5. **Beta versions become obsolete** once stable is released (no need to delete)

### Version Naming

- **Clear release names** help identify purpose:
  - Beta: "Testing WiFi improvements"
  - Beta: "Pre-release for Art-Net DMX support"
  - Stable: "LacyLights RPi v0.1.7"
  - Stable: "WiFi stability improvements"

### Testing

- **Always test on real hardware** before stable release
- **Use beta releases** for any risky changes
- **Verify install.sh** works correctly for stable releases
- **Check all documentation** is current before releasing

### Communication

- **Beta releases**: Share directly with testers via URL
- **Stable releases**: Announce broadly, update documentation
- **Breaking changes**: Clearly document in release notes
- **Migration guides**: Provide for major version bumps

## Related Documentation

- [RELEASES.md](RELEASES.md) - General release management overview
- [RELEASE_TOKEN_SETUP.md](RELEASE_TOKEN_SETUP.md) - Setting up release automation token
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deploying code changes
- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Semantic Versioning Specification](https://semver.org/)
