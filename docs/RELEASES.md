# Release Management

This document describes how to create and manage releases for the lacylights-rpi repository.

## Overview

The lacylights-rpi repository uses GitHub Actions to automate the release process. When you create a release, it:

1. Calculates the next version number based on semantic versioning
2. Creates a VERSION file with the new version
3. Commits and pushes the version bump
4. Creates a git tag
5. Packages all deployment scripts and configuration files into a tarball
6. Creates a GitHub release with auto-generated release notes
7. Attaches the tarball as a release asset

## Creating a Release

### Via GitHub Actions (Recommended)

1. Go to the [Actions tab](https://github.com/bbernstein/lacylights-rpi/actions)
2. Select **"Create Release"** workflow
3. Click **"Run workflow"**
4. Choose the version bump type:
   - **patch**: Bug fixes and small improvements (0.0.X)
   - **minor**: New features, backward compatible (0.X.0)
   - **major**: Breaking changes (X.0.0)
5. Optionally provide a custom release name
6. Click **"Run workflow"**

The workflow will automatically:
- Calculate the new version (e.g., v0.1.0 → v0.1.1 for patch)
- Create and push a git tag
- Build the release archive
- Create the GitHub release with generated notes
- Output an installation command

### Manual Release (Not Recommended)

If you need to create a release manually:

```bash
# 1. Update VERSION file
echo "1.0.0" > VERSION

# 2. Commit the version bump
git add VERSION
git commit -m "chore: bump version to 1.0.0"
git push origin main

# 3. Create and push tag
git tag v1.0.0
git push origin v1.0.0

# 4. Create release archive
mkdir -p release-temp
cp -r scripts setup config systemd utils docs release-temp/
cp README.md LICENSE VERSION release-temp/
cd release-temp
tar czf ../lacylights-rpi-1.0.0.tar.gz .
cd ..

# 5. Create GitHub release
gh release create v1.0.0 \
    --title "LacyLights RPi v1.0.0" \
    --generate-notes \
    lacylights-rpi-1.0.0.tar.gz
```

## Semantic Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** version (X.0.0): Incompatible changes that require user action
  - Example: Changing directory structure, breaking config file changes

- **MINOR** version (0.X.0): New features that are backward compatible
  - Example: New deployment script features, additional utilities

- **PATCH** version (0.0.X): Bug fixes and small improvements
  - Example: Script bug fixes, documentation updates, minor improvements

## Release Contents

Each release archive contains:

```
lacylights-rpi-{version}.tar.gz
├── scripts/           # Deployment and setup scripts
│   ├── deploy.sh
│   ├── setup-new-pi.sh
│   └── ...
├── setup/             # Modular setup scripts
│   ├── 01-system-setup.sh
│   ├── 02-network-setup.sh
│   └── ...
├── config/            # Configuration templates
│   ├── .env.example
│   └── sudoers.d/
├── systemd/           # Service files
│   └── lacylights.service
├── utils/             # Utility scripts
│   ├── check-health.sh
│   └── ...
├── docs/              # Documentation
│   ├── DEPLOYMENT.md
│   └── ...
├── README.md          # Main documentation
├── LICENSE            # MIT License
└── VERSION            # Version number
```

## Installation from Release

Users can install any release using:

```bash
# Latest release
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash

# Specific version
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | bash -s -- v1.0.0

# Remote installation
curl -fsSL https://raw.githubusercontent.com/bbernstein/lacylights-rpi/main/install.sh | \
    bash -s -- v1.0.0 pi@raspberrypi.local
```

## Release Notes

Release notes are automatically generated from commit messages. To ensure good release notes:

1. **Use conventional commits** for clarity:
   - `feat: add new deployment option`
   - `fix: correct permissions issue in setup script`
   - `docs: update WiFi setup guide`
   - `chore: bump version to 1.0.0`

2. **Write descriptive commit messages** that explain the "why":
   ```
   feat: add health check utility

   Adds a comprehensive health check script that verifies:
   - Service status
   - Network connectivity
   - Database accessibility
   - DMX broadcast configuration
   ```

3. **Reference issues** in commits:
   ```
   fix: resolve WiFi connection timeout issue

   Fixes #42
   ```

## Version History

- **v0.0.0**: Initial version (placeholder)
- Future versions will be listed here as they are created

## Troubleshooting Releases

### Release Creation Failed

If the GitHub Actions workflow fails:

1. **Check the workflow run** for error messages
2. **Common issues**:
   - Permission denied: Ensure RELEASE_TOKEN secret is set correctly
   - Tag already exists: Delete the tag and retry
   - Archive creation failed: Check that all required directories exist

### Tag Already Exists

If you need to recreate a release:

```bash
# Delete tag locally and remotely
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0

# Delete release on GitHub
gh release delete v1.0.0 --yes

# Re-run the workflow
```

### Installation Script Not Found

The install.sh script must be in the main branch for the one-command installation to work. If you've made changes to install.sh:

1. Merge changes to main first
2. Then create the release
3. Users will get the latest install.sh from main

## Best Practices

1. **Test before releasing**: Always test deployment scripts before creating a release
2. **Batch related changes**: Group related changes into a single release
3. **Update documentation**: Ensure README and docs are current before release
4. **Communicate breaking changes**: Use MAJOR version bump and update docs clearly
5. **Keep changelog updated**: Consider maintaining a CHANGELOG.md for significant changes

## Related Documentation

- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Semantic Versioning Specification](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
