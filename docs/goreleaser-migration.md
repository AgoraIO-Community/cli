# GoReleaser Migration Guide

## Do I need Cloudsmith?

No. GitHub hosts everything:

| Need | GitHub service |
|------|---------------|
| Binary archives (.tar.gz, .zip) | GitHub Releases |
| Linux packages (.deb, .rpm, .apk) | GitHub Releases |
| Docker images | GitHub Container Registry (GHCR) — free for public repos |
| apt repository (with `apt-get update` support) | GitHub Pages |

The only non-GitHub service is **npmjs.com** for the npm packages — which was already the case before this migration.

## What Changed

| Before | After |
|--------|-------|
| Hand-rolled matrix build in `release.yml` | Single `goreleaser-action` call |
| Custom checksum generation | GoReleaser built-in |
| `homebrew-tap.yml` workflow | GoReleaser `brews` block (delete the old workflow after verifying) |
| No Scoop support | GoReleaser `scoops` block |
| No Docker images | GoReleaser `dockers` block → GHCR |
| No Linux packages | GoReleaser `nfpms` block → .deb, .rpm, .apk |
| No shell install script | `install.sh` at repo root |
| No apt repository | `apt-repo.yml` workflow → GitHub Pages |

Archive names and checksums are unchanged so existing Homebrew formulas and install scripts continue to work.

## One-Time Setup

### 1. Install GoReleaser locally

```bash
brew install goreleaser
```

Verify the config before your first real release:
```bash
goreleaser release --snapshot --clean
```

### 2. Scoop bucket

Create a new public GitHub repo named `scoop-bucket` under your org.

Create a GitHub Personal Access Token (classic or fine-grained) with `contents: write` permission to that repo. Add it as:
- Secret `SCOOP_BUCKET_TOKEN`
- Variable `SCOOP_BUCKET_REPO` = `{org}/scoop-bucket`

### 3. GitHub Pages (for the apt repository)

Enable GitHub Pages on this repo:
- **Settings → Pages → Source: Deploy from a branch → Branch: `gh-pages`**

The first release will create the `gh-pages` branch automatically. No content needs to exist there beforehand.

### 4. GPG signing key for apt

Generate a dedicated signing key (do this locally, not in CI):

```bash
gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Agora CLI
Name-Email: devex@agora.io
Expire-Date: 0
%no-protection
EOF
```

Find the key ID:
```bash
gpg --list-secret-keys --keyid-format LONG devex@agora.io
# Output: sec   rsa4096/ABCDEF1234567890 ...
#                       ^^^^^^^^^^^^^^^^ this is the key ID
```

Export the private key and store it as secret `APT_SIGNING_KEY`:
```bash
gpg --armor --export-secret-keys ABCDEF1234567890
```

Set the key ID as variable `APT_SIGNING_KEY_ID` = `ABCDEF1234567890`.

The public key is published automatically to `https://{pages-url}/apt/gpg.key` by the apt-repo workflow. Include this URL in your install documentation.

### 5. npm token

If not already configured: create an npm token with publish access to:
- `agoraio-cli` (unscoped package)
- `@agoraio` scope

Store as secret `NPM_TOKEN`.

### 6. Verify Homebrew tap variables are set

The `release.yml` workflow reads `vars.HOMEBREW_TAP_REPO` (e.g., `org/homebrew-tap`) and `secrets.HOMEBREW_TAP_TOKEN`. These should already be set from the previous setup. GoReleaser silently skips the Homebrew step if `HOMEBREW_TAP_OWNER` is empty.

## Post-Migration Cleanup

After verifying the first GoReleaser release works end-to-end:

1. Open the first Winget PR manually (see below)

## Winget (Windows Package Manager)

GoReleaser has experimental Winget support, but it requires a PAT with cross-repo write access. The easiest path for the first submission is manual:

1. After the first GoReleaser release, note the Windows `.zip` download URLs and SHA-256s from `checksums.txt`
2. Use [wingetcreate](https://github.com/microsoft/winget-create) to generate the manifests:
   ```powershell
   wingetcreate create `
     https://github.com/.../releases/download/v0.1.4/agora-cli-go_v0.1.4_windows_amd64.zip `
     --id AgoraIO.AgoraCLI `
     --version 0.1.4 `
     --name "Agora CLI" `
     --publisher "Agora" `
     --token $env:GITHUB_TOKEN
   ```
3. This opens a PR to `microsoft/winget-pkgs` automatically

For subsequent releases, add the `wingets` block to `.goreleaser.yaml` and a `WINGET_TOKEN` secret.

## User-Facing Install Docs

After setup, the install story becomes:

```bash
# macOS (primary)
brew install {org}/tap/agora

# Linux — shell script (all distros)
curl -fsSL https://raw.githubusercontent.com/{org}/agora-cli/main/install.sh | sh

# Linux — Debian/Ubuntu (with apt-get upgrade support)
curl -fsSL https://{pages-url}/apt/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/agora.gpg
echo "deb [signed-by=/usr/share/keyrings/agora.gpg] https://{pages-url}/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/agora.list
sudo apt-get update && sudo apt-get install agora-cli

# Windows — Scoop
scoop bucket add agora https://github.com/{org}/scoop-bucket
scoop install agora-cli

# Windows — Winget (after first submission)
winget install AgoraIO.AgoraCLI

# Any platform — npm (convenience)
npm install -g agoraio-cli
```
