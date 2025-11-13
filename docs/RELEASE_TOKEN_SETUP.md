# Setting Up RELEASE_TOKEN for Automated Releases

The release workflow needs special permissions to push commits and tags to the protected `main` branch. This document explains how to set up the required token.

## Why is this needed?

GitHub's default `GITHUB_TOKEN` has limited permissions and cannot bypass branch protection rules. To allow the automated release workflow to:
- Commit VERSION file changes to main
- Push git tags
- Create releases

...we need a Personal Access Token (PAT) with elevated permissions.

## Setup Steps

### 1. Create a Personal Access Token

1. Go to **GitHub Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
   - Or go directly to: https://github.com/settings/tokens?type=beta

2. Click **"Generate new token"**

3. Configure the token:
   - **Token name**: `LacyLights RPi Release Token`
   - **Expiration**: 90 days (or longer, requires renewal)
   - **Repository access**: Select "Only select repositories"
     - Choose `bbernstein/lacylights-rpi`

4. **Permissions** → **Repository permissions**:
   - **Contents**: Read and write ✅
   - **Metadata**: Read (automatically selected)
   - **Pull requests**: Read and write (optional, if you want PR creation)

5. Click **"Generate token"**

6. **IMPORTANT**: Copy the token immediately - you won't see it again!
   - It will look like: `github_pat_11A...` (starts with `github_pat_`)

### 2. Add Token to Repository Secrets

1. Go to your repository: https://github.com/bbernstein/lacylights-rpi

2. Click **Settings** → **Secrets and variables** → **Actions**

3. Click **"New repository secret"**

4. Configure the secret:
   - **Name**: `RELEASE_TOKEN` (must be exactly this)
   - **Secret**: Paste the token you copied
   - Click **"Add secret"**

### 3. Verify Setup

The workflow is already configured to use `RELEASE_TOKEN`. Once you've added the secret:

1. Go to **Actions** → **Create Release**
2. Click **"Run workflow"**
3. Select version bump type
4. Click **"Run workflow"**

The workflow should now successfully:
- ✅ Commit VERSION file to main
- ✅ Push the commit
- ✅ Create and push the tag
- ✅ Create the release

## Alternative: Classic Personal Access Token

If you prefer classic tokens:

1. Go to **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **"Generate new token (classic)"**
3. Configure:
   - **Note**: `LacyLights RPi Release Token`
   - **Expiration**: 90 days or longer
   - **Scopes**:
     - ✅ `repo` (Full control of private repositories)
       - This includes `repo:status`, `repo_deployment`, `public_repo`, `repo:invite`, `security_events`
4. Generate and copy the token
5. Add as repository secret named `RELEASE_TOKEN`

## Troubleshooting

### "refusing to allow a Personal Access Token to create or update workflow"

If you see this error, it means:
- The token needs `workflow` scope (for classic tokens)
- Or the fine-grained token needs "Workflows: Read and write" permission

To fix:
1. Edit your token
2. Add the workflow permission
3. Save changes
4. Retry the workflow

### "Resource not accessible by integration"

This means the token doesn't have sufficient permissions:
1. Verify the token has "Contents: Read and write"
2. Verify the token is for the correct repository
3. Make sure you added it as `RELEASE_TOKEN` (exact name)

### "remote: Permission to push refused"

This could mean:
1. Token expired - create a new one
2. Token was deleted - create a new one
3. Token lacks permissions - check permissions above

### Branch protection is still blocking pushes

If you have branch protection rules:

1. Go to **Settings** → **Branches** → **Branch protection rules**
2. Edit the rule for `main`
3. Under "Allow force pushes", enable it OR
4. Under "Allow specified actors to bypass required pull requests", add your GitHub username or the GitHub Actions bot

## Security Considerations

1. **Token Expiration**: Set an expiration date and calendar reminder to renew
2. **Minimal Scope**: Only grant permissions needed (Contents: Read and write)
3. **Repository-Specific**: Limit token to only lacylights-rpi repository
4. **Rotation**: Rotate tokens periodically (every 90 days recommended)
5. **Audit**: Review token usage in Settings → Developer settings → Personal access tokens

## Token Renewal Process

When your token expires:

1. Go to **GitHub Settings** → **Developer settings** → **Personal access tokens**
2. Find the expired token
3. Click **Regenerate token** (or create a new one)
4. Copy the new token
5. Update the repository secret:
   - Go to repository **Settings** → **Secrets and variables** → **Actions**
   - Click **RELEASE_TOKEN**
   - Click **Update secret**
   - Paste the new token
   - Click **Update secret**

## Using RELEASE_TOKEN vs GITHUB_TOKEN

| Feature | GITHUB_TOKEN | RELEASE_TOKEN (PAT) |
|---------|--------------|---------------------|
| Bypass branch protection | ❌ No | ✅ Yes |
| Push to main | ❌ No (if protected) | ✅ Yes |
| Create tags | ✅ Yes | ✅ Yes |
| Trigger other workflows | ❌ No | ✅ Yes |
| Expires | Never | Yes (90 days typical) |
| Setup required | None (automatic) | Manual |

## Summary

1. Create fine-grained PAT with "Contents: Read and write" for lacylights-rpi
2. Add as repository secret named `RELEASE_TOKEN`
3. Workflow will use it automatically
4. Set calendar reminder to renew before expiration

The workflow checks for `RELEASE_TOKEN` and falls back to `GITHUB_TOKEN` if not available, but the latter won't work with branch protection.
