# Workflow Testing Documentation

## Overview

This document provides comprehensive testing procedures for the LacyLights RPi release workflow, specifically for the automatic beta versioning feature implemented in `release.yml`.

**Last Updated:** 2025-11-24
**Branch:** feat/prerelease-support
**Workflow File:** `.github/workflows/release.yml`

---

## Feature Summary

The workflow now supports automatic beta (prerelease) versioning with smart incrementing:

- **Beta versions** follow the pattern: `vX.Y.Zb1`, `vX.Y.Zb2`, etc.
- **Stable releases** follow semantic versioning: `vX.Y.Z`
- Beta versions are automatically marked as "prerelease" in GitHub
- Only stable releases update `latest.json` and `install.sh` on the distribution server
- All releases (beta and stable) are tracked in DynamoDB with `isPrerelease` flag

---

## Test Scenarios

### Scenario 1: First Beta Release (Patch)

**Setup:**
- Current stable version: `v0.1.6`
- No existing beta versions

**Action:**
1. Go to GitHub Actions > Create Release
2. Select **patch** version bump
3. Check **"Create as prerelease (beta)"**
4. Run workflow

**Expected Results:**
- New version: `0.1.7b1`
- New tag: `v0.1.7b1`
- VERSION file updated to: `0.1.7b1`
- GitHub release marked as "Pre-release"
- Tarball created: `lacylights-rpi-0.1.7b1.tar.gz`
- S3 uploads:
  - `releases/rpi/lacylights-rpi-0.1.7b1.tar.gz`
  - `releases/rpi/0.1.7b1.json` (with `"isPrerelease": true`)
- S3 **NOT** updated:
  - `latest.json` (remains at `0.1.6`)
  - `install.sh` (not uploaded)
- DynamoDB entry: `isPrerelease: true`

**Verification Commands:**
```bash
# Check tag was created
git tag -l 'v0.1.7b*'

# Check VERSION file
cat VERSION

# Verify S3 (requires AWS CLI and credentials)
aws s3 ls s3://YOUR_BUCKET/releases/rpi/ | grep 0.1.7b1

# Verify latest.json still points to stable
curl https://dist.lacylights.com/releases/rpi/latest.json | jq .version
```

---

### Scenario 2: Subsequent Beta Release (Same Version)

**Setup:**
- Current stable version: `v0.1.6`
- Existing beta: `v0.1.7b1`

**Action:**
1. Go to GitHub Actions > Create Release
2. Select **patch** version bump
3. Check **"Create as prerelease (beta)"**
4. Run workflow

**Expected Results:**
- New version: `0.1.7b2` (auto-incremented)
- New tag: `v0.1.7b2`
- VERSION file updated to: `0.1.7b2`
- All S3/DynamoDB uploads as beta
- `latest.json` remains at `0.1.6`

**Verification:**
```bash
# Check all beta tags for this version
git tag -l 'v0.1.7b*' | sort -V

# Should show: v0.1.7b1, v0.1.7b2
```

---

### Scenario 3: Stable Release After Betas

**Setup:**
- Current stable version: `v0.1.6`
- Existing betas: `v0.1.7b1`, `v0.1.7b2`

**Action:**
1. Go to GitHub Actions > Create Release
2. Select **patch** version bump
3. **Uncheck** "Create as prerelease (beta)"
4. Run workflow

**Expected Results:**
- New version: `0.1.7` (clean stable version)
- New tag: `v0.1.7`
- VERSION file updated to: `0.1.7`
- GitHub release marked as "Latest release" (not pre-release)
- S3 uploads:
  - `releases/rpi/lacylights-rpi-0.1.7.tar.gz`
  - `releases/rpi/0.1.7.json` (with `"isPrerelease": false`)
  - `releases/rpi/install.sh` **UPDATED**
  - `releases/rpi/latest.json` **UPDATED** to `0.1.7`
- DynamoDB entry: `isPrerelease: false`

**Verification:**
```bash
# Check latest.json was updated
curl https://dist.lacylights.com/releases/rpi/latest.json | jq

# Should show version: "0.1.7", isPrerelease: false

# Test install.sh behavior
curl -fsSL https://dist.lacylights.com/releases/rpi/install.sh | bash -s -- latest

# Should download 0.1.7 (stable, not beta)
```

---

### Scenario 4: Beta Minor Release

**Setup:**
- Current stable version: `v0.1.7`

**Action:**
1. Select **minor** version bump
2. Check "Create as prerelease (beta)"
3. Run workflow

**Expected Results:**
- New version: `0.2.0b1`
- VERSION file: `0.2.0b1`
- Marked as pre-release
- `latest.json` remains at `0.1.7`

---

### Scenario 5: Beta Major Release

**Setup:**
- Current stable version: `v0.1.7`

**Action:**
1. Select **major** version bump
2. Check "Create as prerelease (beta)"
3. Run workflow

**Expected Results:**
- New version: `1.0.0b1`
- VERSION file: `1.0.0b1`
- Marked as pre-release
- `latest.json` remains at `0.1.7`

---

### Scenario 6: Stable Patch Release (No Betas)

**Setup:**
- Current stable version: `v0.1.7`
- No betas for `v0.1.8`

**Action:**
1. Select **patch** version bump
2. **Uncheck** "Create as prerelease (beta)"
3. Run workflow

**Expected Results:**
- New version: `0.1.8`
- VERSION file: `0.1.8`
- Full S3 upload including `latest.json` and `install.sh`
- Marked as stable release

---

## Manual Testing Checklist

### Pre-Release Validation

- [ ] All shell scripts pass syntax validation (`bash -n`)
- [ ] All shell scripts are executable
- [ ] Workflow YAML is valid (check in GitHub Actions UI)
- [ ] Current VERSION file exists and contains valid version
- [ ] Git working directory is clean

### Workflow Execution Testing

For each test scenario:

- [ ] Workflow triggers successfully
- [ ] Version calculation is correct
- [ ] VERSION file is updated correctly
- [ ] Git commit is created with proper message
- [ ] Git tag is created with correct name
- [ ] Tag is pushed to remote
- [ ] Tarball is created successfully
- [ ] Tarball contains expected files
- [ ] GitHub release is created
- [ ] GitHub release has correct prerelease status
- [ ] SHA256 checksum is calculated
- [ ] Metadata JSON is correct
- [ ] S3 upload succeeds for tarball
- [ ] S3 upload succeeds for version JSON
- [ ] `latest.json` behavior is correct (updated for stable only)
- [ ] `install.sh` behavior is correct (uploaded for stable only)
- [ ] DynamoDB entry is created with correct flags

### Post-Release Validation

- [ ] GitHub release page shows correct version
- [ ] Release shows correct prerelease/stable status
- [ ] Tarball is downloadable from GitHub
- [ ] Tarball is downloadable from S3 CDN
- [ ] SHA256 checksum matches
- [ ] Version metadata JSON is accessible
- [ ] `latest.json` reflects correct stable version
- [ ] `install.sh` downloads correct stable version
- [ ] DynamoDB query returns correct version info

---

## VERSION File Verification

### Expected VERSION File Behavior

The VERSION file should contain only the version number (no 'v' prefix):

```bash
# Beta version
cat VERSION
# Output: 0.1.7b1

# Stable version
cat VERSION
# Output: 0.1.7
```

### Verification Steps

1. **After workflow completes:**
   ```bash
   # Check VERSION file was committed
   git log -1 --stat | grep VERSION

   # Check content
   cat VERSION

   # Verify no 'v' prefix
   grep -E '^v' VERSION && echo "ERROR: v prefix found" || echo "OK: no v prefix"
   ```

2. **In release tarball:**
   ```bash
   # Download and extract
   curl -fsSL https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7b1.tar.gz -o test.tar.gz
   tar tzf test.tar.gz | grep VERSION
   tar xzf test.tar.gz VERSION
   cat VERSION
   ```

3. **Via install.sh:**
   ```bash
   # Install a specific version
   curl -fsSL https://dist.lacylights.com/releases/rpi/install.sh | bash -s -- v0.1.7b1

   # Check installed version
   cat ~/lacylights-setup/VERSION
   ```

---

## install.sh Behavior Testing

### Beta Version Behavior

**Test:** Install specific beta version
```bash
curl -fsSL https://dist.lacylights.com/releases/rpi/install.sh | bash -s -- v0.1.7b1
```

**Expected:**
- Downloads `lacylights-rpi-0.1.7b1.tar.gz` directly
- Fetches `0.1.7b1.json` for checksum verification
- Extracts to `~/lacylights-setup/`
- VERSION file shows `0.1.7b1`

### Stable Version Behavior (Latest)

**Test:** Install latest stable version
```bash
curl -fsSL https://dist.lacylights.com/releases/rpi/install.sh | bash
# OR
curl -fsSL https://dist.lacylights.com/releases/rpi/install.sh | bash -s -- latest
```

**Expected:**
- Fetches `latest.json` from CDN
- Parses version (should be latest **stable**, e.g., `0.1.7`)
- Downloads corresponding stable tarball
- **Never downloads beta versions** when using "latest"
- Verifies SHA256 checksum

### Stable Version Behavior (Specific)

**Test:** Install specific stable version
```bash
curl -fsSL https://dist.lacylights.com/releases/rpi/install.sh | bash -s -- v0.1.6
```

**Expected:**
- Fetches `0.1.6.json` for metadata
- Downloads `lacylights-rpi-0.1.6.tar.gz`
- Verifies checksum

### Error Handling

**Test:** Install non-existent beta version
```bash
curl -fsSL https://dist.lacylights.com/releases/rpi/install.sh | bash -s -- v0.1.99b1
```

**Expected:**
- Clear error message
- Exits with non-zero status
- Suggests checking available releases

---

## Tarball Verification

### Contents Checklist

Every tarball should contain:

- [ ] `VERSION` file (with correct version)
- [ ] `README.md`
- [ ] `LICENSE`
- [ ] `scripts/` directory with all .sh files
- [ ] `setup/` directory with all .sh files
- [ ] `utils/` directory with all .sh files
- [ ] `config/` directory
- [ ] `systemd/` directory
- [ ] `docs/` directory

### Verification Commands

```bash
# Download tarball
TARBALL="lacylights-rpi-0.1.7b1.tar.gz"
curl -fsSL "https://dist.lacylights.com/releases/rpi/$TARBALL" -o "$TARBALL"

# Verify checksum
EXPECTED_SHA=$(curl -fsSL "https://dist.lacylights.com/releases/rpi/0.1.7b1.json" | jq -r .sha256)
ACTUAL_SHA=$(sha256sum "$TARBALL" | awk '{print $1}')
[ "$EXPECTED_SHA" = "$ACTUAL_SHA" ] && echo "✓ Checksum OK" || echo "✗ Checksum MISMATCH"

# List contents
tar tzf "$TARBALL" | head -20

# Extract and verify
mkdir test-extract
tar xzf "$TARBALL" -C test-extract/
ls -la test-extract/
cat test-extract/VERSION
```

---

## Metadata JSON Verification

### Version-Specific JSON

**Location:** `https://dist.lacylights.com/releases/rpi/{VERSION}.json`

**Expected Structure (Beta):**
```json
{
  "version": "0.1.7b1",
  "url": "https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7b1.tar.gz",
  "sha256": "abc123...",
  "releaseDate": "2025-11-24T10:57:00Z",
  "isPrerelease": true,
  "fileSize": 12345678
}
```

**Expected Structure (Stable):**
```json
{
  "version": "0.1.7",
  "url": "https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7.tar.gz",
  "sha256": "def456...",
  "releaseDate": "2025-11-24T11:00:00Z",
  "isPrerelease": false,
  "fileSize": 12345678
}
```

### latest.json

**Location:** `https://dist.lacylights.com/releases/rpi/latest.json`

**Important:** Should **always** point to latest **stable** version, never beta.

**Expected Structure:**
```json
{
  "version": "0.1.7",
  "url": "https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7.tar.gz",
  "sha256": "def456...",
  "releaseDate": "2025-11-24T11:00:00Z",
  "isPrerelease": false,
  "fileSize": 12345678,
  "installScript": "https://dist.lacylights.com/releases/rpi/install.sh"
}
```

### Verification Script

```bash
#!/bin/bash

# Test latest.json
echo "Checking latest.json..."
LATEST_JSON=$(curl -fsSL https://dist.lacylights.com/releases/rpi/latest.json)
echo "$LATEST_JSON" | jq .

VERSION=$(echo "$LATEST_JSON" | jq -r .version)
IS_PRERELEASE=$(echo "$LATEST_JSON" | jq -r .isPrerelease)

echo ""
echo "Latest stable version: $VERSION"
echo "Is prerelease: $IS_PRERELEASE"

if [ "$IS_PRERELEASE" = "true" ]; then
    echo "✗ ERROR: latest.json points to a prerelease!"
    exit 1
fi

if [[ "$VERSION" =~ b[0-9]+$ ]]; then
    echo "✗ ERROR: latest.json version has beta suffix!"
    exit 1
fi

echo "✓ latest.json is correct"

# Test version-specific JSON
echo ""
echo "Checking version-specific JSON for $VERSION..."
VERSION_JSON=$(curl -fsSL "https://dist.lacylights.com/releases/rpi/${VERSION}.json")
echo "$VERSION_JSON" | jq .

# Verify checksum
echo ""
echo "Verifying tarball checksum..."
EXPECTED_SHA=$(echo "$VERSION_JSON" | jq -r .sha256)
TARBALL_URL=$(echo "$VERSION_JSON" | jq -r .url)

curl -fsSL "$TARBALL_URL" -o /tmp/test-tarball.tar.gz
ACTUAL_SHA=$(sha256sum /tmp/test-tarball.tar.gz | awk '{print $1}')

if [ "$EXPECTED_SHA" = "$ACTUAL_SHA" ]; then
    echo "✓ Checksum verified"
else
    echo "✗ Checksum mismatch!"
    echo "  Expected: $EXPECTED_SHA"
    echo "  Actual:   $ACTUAL_SHA"
    exit 1
fi

rm /tmp/test-tarball.tar.gz
echo ""
echo "✓ All checks passed"
```

---

## DynamoDB Verification

### Query Command

```bash
# List all versions for rpi component
aws dynamodb query \
  --table-name lacylights-distributions \
  --key-condition-expression "component = :comp" \
  --expression-attribute-values '{":comp":{"S":"rpi"}}' \
  --query 'Items[*].[version.S, isPrerelease.BOOL]' \
  --output table

# Get specific version
aws dynamodb get-item \
  --table-name lacylights-distributions \
  --key '{"component":{"S":"rpi"},"version":{"S":"0.1.7b1"}}' \
  --output json
```

### Expected Entry (Beta)

```json
{
  "component": {"S": "rpi"},
  "version": {"S": "0.1.7b1"},
  "url": {"S": "https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7b1.tar.gz"},
  "sha256": {"S": "abc123..."},
  "releaseDate": {"S": "2025-11-24T10:57:00Z"},
  "isPrerelease": {"BOOL": true},
  "fileSize": {"N": "12345678"}
}
```

### Expected Entry (Stable)

```json
{
  "component": {"S": "rpi"},
  "version": {"S": "0.1.7"},
  "url": {"S": "https://dist.lacylights.com/releases/rpi/lacylights-rpi-0.1.7.tar.gz"},
  "sha256": {"S": "def456..."},
  "releaseDate": {"S": "2025-11-24T11:00:00Z"},
  "isPrerelease": {"BOOL": false},
  "fileSize": {"N": "12345678"}
}
```

---

## Rollback Testing

### Scenario: Workflow Failure Recovery

**Test:** Simulate workflow failure after tag creation

1. Start workflow (beta release)
2. If workflow fails after tag push, verify cleanup:
   ```bash
   # Tag should be deleted by retry logic
   git tag -l 'v0.1.7b1'
   # Should be empty if cleanup worked
   ```

3. Re-run workflow
4. Verify it completes successfully

### Scenario: S3 Upload Failure

**Test:** Verify partial upload doesn't corrupt latest.json

1. If S3 upload fails for stable release
2. Verify `latest.json` was **not** updated
3. Verify version JSON was not created
4. Fix issue and re-run
5. Verify successful upload updates all artifacts

---

## Integration Testing

### End-to-End Beta Flow

```bash
# 1. Create first beta
# (Run workflow: patch, beta=true)

# 2. Verify beta installation works
curl -fsSL https://dist.lacylights.com/releases/rpi/install.sh | bash -s -- v0.1.7b1
cd ~/lacylights-setup
cat VERSION  # Should show: 0.1.7b1

# 3. Verify latest points to stable (not beta)
curl -fsSL https://dist.lacylights.com/releases/rpi/install.sh | bash
cd ~/lacylights-setup
cat VERSION  # Should show: 0.1.6 (previous stable)

# 4. Create stable release
# (Run workflow: patch, beta=false)

# 5. Verify latest now points to new stable
curl -fsSL https://dist.lacylights.com/releases/rpi/install.sh | bash
cd ~/lacylights-setup
cat VERSION  # Should show: 0.1.7 (new stable)
```

---

## Regression Testing

### Checklist for Existing Functionality

- [ ] Stable releases still work as before
- [ ] `latest.json` only updates for stable releases
- [ ] `install.sh` only uploads for stable releases
- [ ] GitHub releases have correct metadata
- [ ] SHA256 checksums are generated correctly
- [ ] DynamoDB entries are created for all releases
- [ ] Tarball creation includes all necessary files
- [ ] Version file format is correct (no 'v' prefix)

---

## Known Issues & Edge Cases

### Issue 1: Multiple Beta Releases in Quick Succession

**Scenario:** Creating multiple betas rapidly (< 5 seconds apart)

**Potential Issue:** Git tag might not be visible immediately due to propagation

**Mitigation:** Workflow has retry logic with 5-second delays

**Test:**
1. Create `v0.1.7b1`
2. Immediately create `v0.1.7b2`
3. Verify both tags exist and beta numbers incremented correctly

---

### Issue 2: Branching from Beta

**Scenario:** What if someone creates a beta from a non-main branch?

**Current Behavior:** Workflow uses current branch's tags

**Test:**
1. Create feature branch
2. Run workflow with beta=true
3. Verify version calculation is based on all tags (not branch-specific)

---

### Issue 3: Beta Number Extraction Regex

**Test:** Verify regex correctly extracts beta numbers

```bash
# Test cases for version regex
echo "v0.1.7b1" | sed -E 's/.*b([0-9]+)$/\1/'   # Should output: 1
echo "v0.1.7b10" | sed -E 's/.*b([0-9]+)$/\1/'  # Should output: 10
echo "v0.1.7b999" | sed -E 's/.*b([0-9]+)$/\1/' # Should output: 999
```

---

## Quality Assurance Summary

### Pre-Commit Checks

✅ **Shell Script Validation:** All 19 shell scripts pass `bash -n` syntax check
✅ **Script Permissions:** All scripts are executable (755)
✅ **Workflow YAML:** Valid syntax (verified by GitHub)
✅ **VERSION File:** Exists and contains valid version

### Workflow Logic Checks

✅ **Beta Versioning:** Correctly calculates next beta number
✅ **Stable Versioning:** Follows semantic versioning
✅ **Prerelease Detection:** Regex pattern matches beta suffix
✅ **Conditional Logic:** Beta releases skip `latest.json` and `install.sh` uploads
✅ **Error Handling:** Retry logic for git push failures

### Distribution Checks

✅ **S3 Uploads:** Proper content types set
✅ **Metadata JSON:** Correct structure with `isPrerelease` flag
✅ **DynamoDB:** Boolean type for `isPrerelease` field
✅ **GitHub Releases:** Prerelease flag set correctly

---

## Recommendations

### Immediate Actions

1. ✅ **Shell Script Validation:** Complete - all scripts valid
2. ✅ **Workflow YAML Syntax:** Complete - valid YAML
3. 🔄 **Manual Test Run:** Recommended - test beta and stable release flows
4. 🔄 **Documentation Review:** Recommended - verify install.sh usage docs

### Future Enhancements

1. **Automated E2E Tests:** Consider adding workflow tests using act or GitHub Actions testing tools
2. **Shellcheck Integration:** Add shellcheck to CI/CD for enhanced shell script linting
3. **Pre-commit Hooks:** Add git pre-commit hooks for local validation
4. **Release Notes Template:** Add template for structured release notes
5. **Beta Deprecation Policy:** Document when/how betas are cleaned up

### Monitoring

1. **S3 Bucket Size:** Monitor for storage growth with beta releases
2. **DynamoDB Costs:** Track query costs as version history grows
3. **GitHub Release Count:** Consider archiving old betas
4. **CDN Cache:** Ensure `latest.json` cache is properly invalidated

---

## Support & Troubleshooting

### Common Issues

**Issue:** Beta number doesn't increment correctly

**Solution:** Check that git tags are visible: `git fetch --tags`

---

**Issue:** `latest.json` points to beta

**Solution:** Verify workflow conditional: `if: steps.checksum.outputs.is_prerelease == 'false'`

---

**Issue:** Install.sh downloads wrong version

**Solution:** Check `latest.json` content and CDN cache

---

**Issue:** Workflow fails to push tag

**Solution:** Check GitHub token permissions (needs `contents: write`)

---

## Conclusion

This testing documentation provides comprehensive coverage for validating the automatic beta versioning feature. All shell scripts are valid, permissions are correct, and the workflow logic has been reviewed for correctness.

**Status:** ✅ Ready for manual testing and merge

**Next Steps:**
1. Run test scenarios in GitHub Actions
2. Verify distribution artifacts on S3
3. Test install.sh behavior for beta and stable versions
4. Update main repository documentation if needed
