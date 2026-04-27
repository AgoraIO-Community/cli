# Distribution Plan

This document covers every installation target for `agora-cli-go`, how to implement each one, and what ongoing maintenance it requires.

**Current state:** Homebrew (macOS primary), npm Node-shim wrapper (convenience).

---

## Foundation: Migrate to GoReleaser

Before adding new distribution channels, migrate the hand-rolled `release.yml` to [GoReleaser](https://goreleaser.com). Almost every Tier 1 and Tier 2 channel below is either automated or dramatically simplified by GoReleaser. The npm publish job stays custom (GoReleaser has no npm support).

**What it replaces / extends:**

| Task | Current | With GoReleaser |
|------|---------|----------------|
| Cross-platform builds | manual matrix | `.goreleaser.yaml` `builds` block |
| Archives (tar.gz/zip) | manual | automatic |
| Checksums | manual | automatic |
| GitHub release | `softprops/action-gh-release` | `goreleaser/goreleaser-action` |
| Homebrew tap | custom shell script | `brews` block |
| .deb package | missing | `nfpms` block |
| .rpm package | missing | `nfpms` block |
| .apk package | missing | `nfpms` block |
| Scoop manifest | missing | `scoops` block |
| Winget manifest | missing | `winget` block |

**Migration steps:**

1. Install GoReleaser locally: `brew install goreleaser`
2. Run `goreleaser init` in the repo root — it generates a starter `.goreleaser.yaml`
3. Replace the `build` and `publish` jobs in `release.yml` with:
   ```yaml
   - uses: goreleaser/goreleaser-action@v6
     with:
       version: '~> v2'
       args: release --clean
     env:
       GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
       NPM_TOKEN: ${{ secrets.NPM_TOKEN }}   # keep the npm job as a separate step
   ```
4. Keep `publish-npm` as a separate job after goreleaser — GoReleaser has no npm support
5. Run `goreleaser release --snapshot --clean` locally to validate the config

**Key `.goreleaser.yaml` sections to configure:**

```yaml
builds:
  - env: [CGO_ENABLED=0]
    goos: [linux, darwin, windows]
    goarch: [amd64, arm64]
    ldflags: ["-s -w -X main.version={{.Version}}"]

nfpms:
  - package_name: agora-cli
    vendor: Agora
    homepage: https://agora.io
    maintainer: Agora DevEx <devex@agora.io>
    description: Agora developer onboarding CLI
    license: MIT
    formats: [deb, rpm, apk]
    bindir: /usr/local/bin

brews:
  - name: agora
    repository:
      owner: AgoraIO-Extensions
      name: homebrew-tap

scoops:
  - repository:
      owner: AgoraIO-Extensions
      name: scoop-bucket
    homepage: https://agora.io
    description: Agora developer onboarding CLI
    license: MIT
```

**Cost:** ~1 day to migrate, saves weeks of maintenance across all channels.

---

## Priority Tiers

| Channel | OS | Audience | Effort | Priority |
|---------|----|----------|--------|----------|
| Shell install script | Linux + macOS | all developers | low | **Tier 1** |
| Winget | Windows | Windows developers | low | **Tier 1** |
| Scoop | Windows | Windows developers | low | **Tier 1** |
| apt / .deb | Debian/Ubuntu | Linux devs + CI | medium | **Tier 2** |
| rpm / .rpm | RHEL/Fedora/CentOS | enterprise Linux | medium | **Tier 2** |
| apk / Alpine | Alpine Linux | Docker + CI | medium | **Tier 2** |
| Snap | most Linux distros | Linux convenience | medium | **Tier 3** |
| Chocolatey | Windows | enterprise Windows | medium | **Tier 3** |
| AUR | Arch Linux | enthusiast devs | low | **Tier 3** |
| Nix | NixOS + any OS | nix users | medium | **Tier 3** |
| MSI installer | Windows | enterprise / IT | high | **Tier 4** |
| Docker image | any | CI + containers | low | **Tier 3** |

---

## Tier 1

### Shell Install Script

**What it is:** A hosted shell script that auto-detects OS/arch, downloads the right binary from GitHub releases, and places it on `$PATH`. The universal fallback — works on any Linux distro and macOS without any package manager.

**Audience:** Anyone not using Homebrew, npm, or a package manager. Common in CI bootstrap steps and Docker `RUN` layers.

**User experience:**
```bash
curl -fsSL https://cli.agora.io/install.sh | sh
# or with a specific version:
curl -fsSL https://cli.agora.io/install.sh | sh -s -- --version 0.1.4
```

**Implementation:**

Create `install.sh` at the repo root (or `scripts/install.sh`). Key logic:

```bash
#!/usr/bin/env sh
set -e

VERSION="${VERSION:-latest}"
GITHUB_REPO="AgoraIO-Extensions/agora-cli"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# Detect OS and arch
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Resolve latest version
if [ "$VERSION" = "latest" ]; then
  VERSION=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
fi

FILENAME="agora-cli-go_v${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${FILENAME}"

# Download, extract, install
TMP=$(mktemp -d)
curl -fsSL "$URL" -o "$TMP/agora.tar.gz"
tar -xzf "$TMP/agora.tar.gz" -C "$TMP"
install -m 755 "$TMP/agora" "$INSTALL_DIR/agora"
rm -rf "$TMP"

echo "agora ${VERSION} installed to ${INSTALL_DIR}/agora"
```

**Hosting:** Host at a stable URL. Options:
- GitHub raw: `https://raw.githubusercontent.com/AgoraIO-Extensions/agora-cli/main/install.sh` (works, but tied to the `main` branch)
- Custom domain: `https://cli.agora.io/install.sh` — preferred; routes to the GitHub raw URL via redirect or CDN. Stable even if the repo moves.

**Maintenance:** Update whenever the archive naming convention changes. Test on Ubuntu, Debian, Alpine, macOS after each release. Add to release checklist.

---

### Winget (Windows Package Manager)

**What it is:** Microsoft's official package manager, built into Windows 10 (1809+) and Windows 11. Growing fast — it's what `winget install <package>` uses.

**Audience:** Windows developers. Should be the primary Windows install method.

**User experience:**
```powershell
winget install AgoraIO.AgoraCLI
# upgrade:
winget upgrade AgoraIO.AgoraCLI
```

**Implementation:**

Winget packages are submitted as YAML manifest files to the [winget-pkgs](https://github.com/microsoft/winget-pkgs) public repository.

Manifest structure (3 files per version):
```
manifests/a/AgoraIO/AgoraCLI/0.1.4/
  AgoraIO.AgoraCLI.yaml             (version manifest)
  AgoraIO.AgoraCLI.installer.yaml   (installer manifest)
  AgoraIO.AgoraCLI.locale.en-US.yaml (locale manifest)
```

The installer manifest points to the Windows `.zip` release artifact. Winget validates SHA-256.

GoReleaser's `winget` block generates and submits this PR automatically:
```yaml
winget:
  - name: AgoraCLI
    publisher: AgoraIO
    publisher_url: https://agora.io
    short_description: Agora developer onboarding CLI
    license: MIT
    repository:
      owner: microsoft
      name: winget-pkgs
      branch: "agora-{{.Version}}"
      pull_request:
        enabled: true
        draft: false
```

**Without GoReleaser:** Use the [wingetcreate](https://github.com/microsoft/winget-create) tool to generate manifests from a release URL, then open a PR to winget-pkgs.

**Maintenance:** Each release requires a new manifest PR to winget-pkgs. GoReleaser automates this. Manual process takes ~10 minutes per release. The PR is typically merged within 24-48 hours by Microsoft's bot.

**One-time setup:** Create a Microsoft Partner Center account at https://partner.microsoft.com to verify publisher identity. Not strictly required for initial submission but needed for publisher namespace ownership.

---

### Scoop (Windows)

**What it is:** A developer-focused Windows package manager. Installs to user home directory without admin rights. Very popular with developers who don't want to elevate.

**Audience:** Windows developers. Complementary to Winget — many developers have both.

**User experience:**
```powershell
scoop bucket add agora https://github.com/AgoraIO-Extensions/scoop-bucket
scoop install agora-cli
# upgrade:
scoop update agora-cli
```

Or if submitted to the main community bucket:
```powershell
scoop install agora-cli
```

**Implementation:**

Create a new GitHub repo `AgoraIO-Extensions/scoop-bucket` containing JSON manifests:

`bucket/agora-cli.json`:
```json
{
  "version": "0.1.4",
  "description": "Agora developer onboarding CLI",
  "homepage": "https://agora.io",
  "license": "MIT",
  "architecture": {
    "64bit": {
      "url": "https://github.com/AgoraIO-Extensions/agora-cli/releases/download/v0.1.4/agora-cli-go_v0.1.4_windows_amd64.zip",
      "hash": "<sha256>",
      "bin": "agora.exe"
    },
    "arm64": {
      "url": "https://github.com/AgoraIO-Extensions/agora-cli/releases/download/v0.1.4/agora-cli-go_v0.1.4_windows_arm64.zip",
      "hash": "<sha256>",
      "bin": "agora.exe"
    }
  },
  "checkver": {
    "github": "https://github.com/AgoraIO-Extensions/agora-cli"
  },
  "autoupdate": {
    "architecture": {
      "64bit": {
        "url": "https://github.com/AgoraIO-Extensions/agora-cli/releases/download/v$version/agora-cli-go_v$version_windows_amd64.zip"
      },
      "arm64": {
        "url": "https://github.com/AgoraIO-Extensions/agora-cli/releases/download/v$version/agora-cli-go_v$version_windows_arm64.zip"
      }
    }
  }
}
```

GoReleaser's `scoops` block generates this manifest and commits it to the bucket repo on each release.

**Without GoReleaser:** Manually update the JSON file and commit to the bucket repo after each GitHub release. The `checkver`/`autoupdate` fields allow `scoop update` to auto-detect new versions, but the manifest itself still needs to be updated.

**One-time setup:** Create `AgoraIO-Extensions/scoop-bucket` repo. Set up a GitHub token secret (`SCOOP_TAP_TOKEN`) with write access to that repo.

**Maintenance:** GoReleaser handles it. Without GoReleaser, update `agora-cli.json` on each release (~5 minutes).

---

## Tier 2

### apt / .deb (Debian, Ubuntu, and derivatives)

**What it is:** The native package format for Debian-family distros, which includes Ubuntu — the most common Linux distro in CI environments (GitHub Actions default runners, most Docker base images in developer contexts).

**Audience:** Ubuntu/Debian developers, any CI pipeline running on Debian-family Linux.

**User experience (option A — direct .deb download):**
```bash
curl -fsSL -o agora-cli.deb \
  https://github.com/AgoraIO-Extensions/agora-cli/releases/download/v0.1.4/agora-cli_0.1.4_linux_amd64.deb
sudo dpkg -i agora-cli.deb
```

**User experience (option B — hosted apt repository):**
```bash
curl -fsSL https://apt.agora.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/agora.gpg
echo "deb [signed-by=/usr/share/keyrings/agora.gpg] https://apt.agora.io stable main" \
  | sudo tee /etc/apt/sources.list.d/agora.list
sudo apt-get update
sudo apt-get install agora-cli
```

**Implementation:**

GoReleaser generates .deb files automatically via the `nfpms` block (see Foundation section). The .deb is included as a release artifact alongside the archives.

For option A (release artifact only): no additional infrastructure. Users download the .deb directly.

For option B (hosted repository): requires a package repository server. Options:
- **Cloudsmith** (recommended): managed apt/deb/rpm/apk hosting; has a free tier. Add a GoReleaser `publishers` block to push artifacts to Cloudsmith on release.
- **GitHub Pages + reprepro**: free, self-hosted on GitHub Pages. More operational work.
- **Packagecloud.io**: managed hosting, simpler than self-hosting.

For the Cloudsmith approach, add to GoReleaser:
```yaml
publishers:
  - name: cloudsmith
    ids: [packages]
    dir: dist
    cmd: cloudsmith push deb agora/cli/any-distro/any-version {{ .ArtifactPath }}
    env:
      - CLOUDSMITH_API_KEY={{ .Env.CLOUDSMITH_API_KEY }}
```

**One-time setup:** Create the apt repo (Cloudsmith account or GitHub Pages setup). Generate and publish a GPG signing key. Update install docs.

**Maintenance:** GoReleaser pushes new packages automatically. GPG key rotation every 1-2 years.

**CI-specific note:** For GitHub Actions workflows in consuming projects, a simple `wget` + `dpkg -i` of the .deb from GitHub releases is often sufficient and requires no repository setup. Document this as the recommended CI path.

---

### rpm / .rpm (RHEL, Fedora, CentOS, Amazon Linux)

**What it is:** The native package format for Red Hat-family distros. Fedora is the upstream, RHEL/CentOS/Rocky Linux/AlmaLinux are enterprise variants. Amazon Linux 2/2023 is rpm-based — important for AWS-heavy shops.

**Audience:** Enterprise developers, AWS Lambda/EC2 environments, Fedora users.

**User experience (direct .rpm download):**
```bash
sudo dnf install https://github.com/AgoraIO-Extensions/agora-cli/releases/download/v0.1.4/agora-cli_0.1.4_linux_amd64.rpm
# or with yum:
sudo yum install https://...
```

**Implementation:**

GoReleaser generates .rpm files via the same `nfpms` block as .deb (add `rpm` to the formats list). The .rpm lands in the GitHub release automatically.

For a hosted dnf/yum repository, the same hosting options apply as for apt (Cloudsmith supports rpm natively).

**Without a hosted repo:** Direct .rpm URLs from GitHub releases work with `dnf install <url>` — no local download needed. This is often sufficient for developer tools.

**Maintenance:** Minimal beyond GoReleaser integration. rpm signing requires a GPG key (same one as deb works).

---

### apk / Alpine Linux

**What it is:** Alpine Linux's native package format. Alpine is the default base image for many Docker images (`node:alpine`, `python:alpine`, etc.). Critical for containerized build and CI environments.

**Audience:** Docker-based CI pipelines, anyone using Alpine as a base image.

**User experience:**
```dockerfile
# In a Dockerfile (direct binary, no package manager needed — simplest approach)
RUN wget -qO- https://github.com/AgoraIO-Extensions/agora-cli/releases/download/v0.1.4/agora-cli-go_v0.1.4_linux_amd64.tar.gz \
    | tar -xz -C /usr/local/bin

# Or with native apk (once hosted in an apk repository):
RUN apk add --no-cache agora-cli --repository https://apk.agora.io/stable
```

**Implementation:**

GoReleaser generates .apk files via `nfpms` (add `apk` to the formats list). The .apk lands in the GitHub release.

For Alpine Docker usage, the direct binary download (`wget + tar`) is the simplest approach and has no additional infrastructure requirements. Document this as the recommended Dockerfile pattern.

For a native Alpine package repo: Cloudsmith supports apk. Alternatively, open a PR to [aports](https://github.com/alpinelinux/aports) (Alpine's official package tree) — this is high-effort but makes `apk add agora-cli` work without any repository config.

**Docker pattern to document:**

```dockerfile
ARG AGORA_CLI_VERSION=0.1.4
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && \
    wget -qO- "https://github.com/AgoraIO-Extensions/agora-cli/releases/download/v${AGORA_CLI_VERSION}/agora-cli-go_v${AGORA_CLI_VERSION}_linux_${ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin agora && \
    chmod +x /usr/local/bin/agora
```

---

## Tier 3

### Snap (Cross-distro Linux)

**What it is:** Canonical's universal Linux package format. Works on Ubuntu, Debian, Fedora, Arch, and most other distros via `snapd`. Provides auto-updates and sandboxing.

**Audience:** Linux users who want automatic updates without managing a package repository.

**User experience:**
```bash
sudo snap install agora-cli
```

**Implementation:**

Create `snap/snapcraft.yaml` in the repo root:
```yaml
name: agora-cli
base: core22
version: git
summary: Agora developer onboarding CLI
description: Manage Agora authentication, projects, and quickstarts.
grade: stable
confinement: strict

apps:
  agora-cli:
    command: bin/agora
    plugs: [network, home]

parts:
  agora-cli:
    plugin: go
    source: .
    build-snaps: [go/1.24/stable]
```

Publish to the [Snap Store](https://snapcraft.io) (create an Ubuntu One account). CI integration:
```yaml
- uses: snapcore/action-publish@v1
  env:
    SNAPCRAFT_STORE_CREDENTIALS: ${{ secrets.SNAPCRAFT_TOKEN }}
  with:
    snap: "*.snap"
    release: stable
```

**Consideration:** Snap's strict confinement may conflict with `git` access (needed for `quickstart create`). Use `classic` confinement if strict proves too limiting, but classic requires Canonical approval. Test this before committing to the Snap path.

**Maintenance:** Snap auto-updates consumers. Snapcraft.yaml may need updating on Go version bumps.

---

### Chocolatey (Windows)

**What it is:** The original Windows package manager, widely used in enterprise Windows environments and corporate IT. Less developer-organic than Scoop but common in managed fleets.

**Audience:** Enterprise Windows environments, IT-managed machines, CI runners configured with Chocolatey.

**User experience:**
```powershell
choco install agora-cli
choco upgrade agora-cli
```

**Implementation:**

Create a Chocolatey package (NuGet format):
```
agora-cli.nuspec               package metadata
tools/
  chocolateyInstall.ps1        download + install logic
  chocolateyUninstall.ps1      uninstall logic
  VERIFICATION.txt             checksum documentation
  LICENSE.txt
```

`chocolateyInstall.ps1` downloads the .zip from GitHub releases and installs to `$env:ChocolateyInstall\bin`.

Submit to [community.chocolatey.org](https://community.chocolatey.org). Packages go through moderation (1-5 days for new, faster for updates).

GoReleaser does not have native Chocolatey support. Options:
- Use [chocolatey-au](https://github.com/majkinetor/au) to automate version updates
- Manually update and submit on each release (~15 min)

**Maintenance:** Higher than Scoop/Winget because Chocolatey moderation adds latency. Manual updates unless automated. Consider lower priority given Winget's rapid adoption.

---

### AUR (Arch Linux)

**What it is:** The Arch User Repository — a community-driven package repository for Arch Linux, Manjaro, and EndeavourOS. Not officially supported by Arch but widely used.

**Audience:** Small but engaged developer segment. Arch users tend to be technical and vocal.

**User experience:**
```bash
yay -S agora-cli        # or any AUR helper
paru -S agora-cli
```

**Implementation:**

Create a `PKGBUILD` file in a new repo (AUR packages are their own git repos at `aur.archlinux.org`):

```bash
# PKGBUILD
pkgname=agora-cli
pkgver=0.1.4
pkgrel=1
pkgdesc="Agora developer onboarding CLI"
arch=('x86_64' 'aarch64')
url="https://github.com/AgoraIO-Extensions/agora-cli"
license=('MIT')
source_x86_64=("$url/releases/download/v$pkgver/agora-cli-go_v${pkgver}_linux_amd64.tar.gz")
source_aarch64=("$url/releases/download/v$pkgver/agora-cli-go_v${pkgver}_linux_arm64.tar.gz")
# sha256sums must be updated each release

package() {
  install -Dm755 agora "$pkgdir/usr/bin/agora"
}
```

Register an Arch Linux account, generate an SSH key, push to `aur@aur.archlinux.org:agora-cli.git`.

**Maintenance:** Update `pkgver` and `sha256sums` after each release. No moderation queue — push directly. Can automate with a GitHub Action that commits to the AUR repo after each release.

---

### Nix / nixpkgs

**What it is:** The Nix package manager and NixOS distribution. Growing rapidly in developer tooling. Nix works on macOS and Linux (not just NixOS). Developer-friendly: reproducible, declarative, no system pollution.

**Audience:** Nix users (growing), NixOS users, developers using `nix develop` or `nix shell` for dev environments.

**User experience:**
```bash
# Run without installing:
nix run github:AgoraIO-Extensions/agora-cli

# Add to a flake devShell:
inputs.agora-cli.url = "github:AgoraIO-Extensions/agora-cli";

# Install persistently:
nix profile install github:AgoraIO-Extensions/agora-cli
```

**Or via nixpkgs (after upstreaming):**
```bash
nix-env -iA nixpkgs.agora-cli
```

**Implementation:**

Create `flake.nix` in the repo root:
```nix
{
  description = "Agora CLI";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }: {
    packages = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"] (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        default = pkgs.buildGoModule {
          pname = "agora-cli";
          version = "0.1.4";
          src = ./.;
          vendorHash = null;   # update each release
        };
      }
    );
  };
}
```

To upstream to nixpkgs (makes `nix-env -iA nixpkgs.agora-cli` work): open a PR to [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) with a derivation in `pkgs/by-name/ag/agora-cli/package.nix`. This is a medium-effort one-time action; subsequent updates need PRs to bump the version hash.

**Maintenance:** `flake.nix` — update `vendorHash` on dependency changes. nixpkgs PR — open a new PR per version (or use automation like `nixpkgs-update`).

---

### Docker Image

**What it is:** An official Docker image containing the `agora` binary. Useful as a base for CI jobs and for consuming the CLI in Docker-native workflows.

**Audience:** CI pipelines, Dockerfile-heavy projects, anyone who wants a hermetic `agora` without touching the host system.

**User experience:**
```bash
docker run --rm -it ghcr.io/agoraio-extensions/agora-cli:latest --help
docker run --rm -v $(pwd):/work -w /work ghcr.io/agoraio-extensions/agora-cli:latest project doctor --json
```

**Implementation:**

Add a minimal `Dockerfile`:
```dockerfile
FROM scratch
COPY agora /usr/local/bin/agora
ENTRYPOINT ["/usr/local/bin/agora"]
```

Or based on Alpine for shell access:
```dockerfile
FROM alpine:3.20
RUN apk add --no-cache ca-certificates git
COPY agora /usr/local/bin/agora
ENTRYPOINT ["agora"]
```

GoReleaser `dockers` block builds and pushes multi-arch images:
```yaml
dockers:
  - image_templates:
      - "ghcr.io/agoraio-extensions/agora-cli:{{ .Version }}-amd64"
    goarch: amd64
    dockerfile: Dockerfile
    use: buildx
    build_flag_templates:
      - "--platform=linux/amd64"
  - image_templates:
      - "ghcr.io/agoraio-extensions/agora-cli:{{ .Version }}-arm64"
    goarch: arm64
    ...

docker_manifests:
  - name_template: "ghcr.io/agoraio-extensions/agora-cli:{{ .Version }}"
    image_templates:
      - "ghcr.io/agoraio-extensions/agora-cli:{{ .Version }}-amd64"
      - "ghcr.io/agoraio-extensions/agora-cli:{{ .Version }}-arm64"
```

Host on GitHub Container Registry (GHCR) — free for public repos, no DockerHub rate limits.

**Note:** `quickstart create` and `init` shell out to `git clone`. The Alpine-based image is required for these commands; the `scratch` image will only work for commands that don't need `git`.

**Maintenance:** GoReleaser builds and pushes automatically. Update `FROM alpine:X.Y` on security advisories.

---

## Tier 4

### MSI Installer (Windows)

**What it is:** A traditional Windows installer package. Adds the binary to `%PATH%` via an installer wizard or silent install.

**Audience:** Enterprise IT departments that need to deploy tools via Group Policy, SCCM, or MDM. Individual developers generally prefer Winget or Scoop.

**User experience:**
```powershell
# Silent install
msiexec /i agora-cli-0.1.4-x64.msi /quiet /norestart
```

**Implementation:**

Use [WiX Toolset v4](https://wixtoolset.org/) or GoReleaser's MSI support (via `nsis` or a WiX plugin). Requires:
1. A WiX source file (`.wxs`) defining installer UI, registry entries, and PATH configuration
2. A code signing certificate to avoid SmartScreen warnings (required for enterprise trust)
3. CI integration to build and sign the MSI

**Cost:** Code signing certificates cost ~$300-500/year (EV cert recommended to avoid SmartScreen). WiX authoring is non-trivial. Estimate 3-5 days initial setup.

**Recommendation:** Defer until there is explicit enterprise customer demand. Winget + Scoop cover the developer audience well without the signing overhead.

---

## Execution Order

1. **Now:** Shell install script — one file, no infrastructure, unblocks all Linux users immediately
2. **Now:** Scoop bucket — 1 hour to create the repo and manifest
3. **Now:** Winget manifest — 30 minutes, submit PR to winget-pkgs
4. **Next release:** GoReleaser migration — unlocks .deb/.rpm/.apk + automates Scoop/Winget going forward
5. **After GoReleaser:** Cloudsmith apt/deb/rpm/apk hosting — document the one-liner `apt install` path
6. **Document Docker pattern** — one-paragraph addition to README with the `wget + tar` Dockerfile snippet
7. **Later:** Snap, AUR, Nix, Chocolatey — based on user demand

---

## Secrets Required

| Secret | Used by | Notes |
|--------|---------|-------|
| `NPM_TOKEN` | npm publish job | Publish access to `agoraio-cli` and `@agoraio/*` |
| `HOMEBREW_TAP_TOKEN` | GoReleaser brews block | Write access to `AgoraIO-Extensions/homebrew-tap` |
| `SCOOP_BUCKET_TOKEN` | GoReleaser scoops block | Write access to `AgoraIO-Extensions/scoop-bucket` |
| `CLOUDSMITH_API_KEY` | deb/rpm/apk hosting | Cloudsmith account API key |
| `SNAPCRAFT_TOKEN` | Snap publish | Ubuntu One / Snapcraft credentials |

Winget and AUR updates go through public PRs and do not need secrets in CI.
