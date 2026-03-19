# GitHub Releases Automation Setup

This document explains how to automatically create GitHub releases when CodeMagic successfully builds your app.

## Overview

When CodeMagic finishes a successful build, it can automatically trigger a GitHub Actions workflow that creates a release with:
- App version (from pubspec.yaml)
- Build information
- Download links
- Release notes

## Setup Instructions

### Step 1: Add GITHUB_TOKEN to CodeMagic

1. Go to [CodeMagic Dashboard](https://codemagic.io)
2. Select your app (whispr-mobile)
3. Go to **Settings** → **Environment Variables**
4. Add a new environment variable:
   - **Name**: `GITHUB_TOKEN`
   - **Value**: [GitHub Personal Access Token](https://github.com/settings/tokens)
   - **Secure**: ✅ Yes (encrypt the value)

**To create a GitHub Personal Access Token:**
1. Go to GitHub Settings → Developer settings → [Personal access tokens](https://github.com/settings/tokens)
2. Click "Generate new token"
3. Select scopes:
   - `repo` (full control of private repositories)
   - `workflow` (update GitHub Action workflows)
4. Copy the token and add it to CodeMagic

### Step 2: Configure CodeMagic Post-Build

In your CodeMagic `codemagic.yaml` (in the project root), add a post-build script:

```yaml
workflows:
  default:
    # ... other config ...
    scripts:
      # ... other scripts ...
      - name: Create GitHub Release
        script: |
          #!/bin/bash
          set -e
          chmod +x ./scripts/create-github-release.sh
          ./scripts/create-github-release.sh
```

Or in the CodeMagic web UI:
1. Go to **Settings** → **Build scripts**
2. Click **Add script** under "Post-build"
3. Name: "Create GitHub Release"
4. Script:
   ```bash
   #!/bin/bash
   set -e
   chmod +x ./scripts/create-github-release.sh
   ./scripts/create-github-release.sh
   ```

### Step 3: Verify GitHub Actions Workflows

Check that both workflows are in your repository:
- `.github/workflows/create-release.yml` - Manual release creation
- `.github/workflows/auto-release-codemagic.yml` - Automatic release checking

```bash
ls -la .github/workflows/
```

## How It Works

### Workflow 1: Auto-Release (Scheduled)
- **Trigger**: Runs hourly to check CodeMagic for new builds
- **Action**: Creates a GitHub release if a new successful build is found
- **Benefit**: No manual setup needed in CodeMagic

### Workflow 2: Manual Release
- **Trigger**: Can be triggered manually or by CodeMagic via `repository_dispatch`
- **Action**: Creates a precisely named release with custom changelog
- **Benefit**: More control over release details

### Workflow 3: CodeMagic Post-Build (Recommended)
- **Trigger**: Runs automatically after CodeMagic build completes
- **Action**: Calls GitHub Actions `repository_dispatch` event
- **Benefit**: Immediate release creation

## Testing

### Test the GitHub Release Workflow Manually

1. Go to your repository on GitHub
2. Click **Actions**
3. Select **Create GitHub Release from CodeMagic Build**
4. Click **Run workflow**
5. Enter a version (e.g., `1.0.0`)
6. Leave changelog empty or enter custom notes
7. Click **Run workflow**

### Test the CodeMagic Post-Build Script

1. Trigger a build in CodeMagic
2. Wait for build to complete
3. Check CodeMagic build logs for:
   ```
   ✅ GitHub Release workflow triggered successfully!
   ```
4. Go to GitHub **Releases** tab to verify release was created

## Troubleshooting

### "GITHUB_TOKEN not set" Error

**Problem**: Post-build script fails with "GITHUB_TOKEN not set"

**Solution**:
1. Go to CodeMagic Settings → Environment Variables
2. Verify `GITHUB_TOKEN` is set
3. Make sure it's marked as **Secure** (not plaintext)
4. Regenerate token if suspicious

### Release Not Created

**Problem**: Build succeeds but no release appears

**Solutions**:
1. Check GitHub Actions logs:
   - Go to repository → **Actions** tab
   - Look for failed workflow runs
   
2. Verify environment variable:
   ```bash
   # In CodeMagic logs, you should see:
   📡 Triggering GitHub Release Workflow...
   ✅ GitHub Release workflow triggered successfully!
   ```

3. Check GitHub token permissions:
   - Token must have `repo` and `workflow` scopes
   - Regenerate token if needed

### Website Download Page Not Showing Builds

**Problem**: Release created but download page shows "No builds available"

**Solution**:
1. Check that `GITHUB_TOKEN` is set in website environment (`.env.local`)
2. Verify `/api/builds/latest` endpoint can access GitHub releases:
   ```bash
   curl "https://api.github.com/repos/TECHTUNE-I-T-SOLUTIONS/whispr-mobile/releases/latest" \
     -H "Authorization: token YOUR_GITHUB_TOKEN"
   ```

## Automatic Website Updates

Once releases are created in GitHub, the website automatically:
1. Fetches the latest release from GitHub API
2. Displays build information on the download page
3. Shows download links for iOS and Android
4. Updates changelog from release notes

**Check the download page**: https://your-domain.com/download

## Next Steps

1. ✅ Add `GITHUB_TOKEN` to CodeMagic environment
2. ✅ Configure CodeMagic post-build script
3. ✅ Trigger a test build
4. ✅ Verify release appears on GitHub
5. ✅ Confirm download page shows the release

## References

- [CodeMagic Documentation](https://docs.codemagic.io)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub API - Create a Release](https://docs.github.com/en/rest/releases/releases#create-a-release)
- [Whispr Download Page](/download)

## Support

For issues or questions:
1. Check CodeMagic build logs
2. Check GitHub Actions logs
3. Verify environment variables are set
4. Check firewall/CORS settings
