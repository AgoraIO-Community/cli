# Releasing Agora CLI

Releases are fully automated via GoReleaser. Pushing a `v*` tag is the only manual step.

## Release

```bash
git tag v0.1.7
git push origin v0.1.7
```

The release workflow (`.github/workflows/release.yml`) then:

1. **GoReleaser** builds and publishes everything in parallel:
   - Cross-platform binaries (Linux, macOS, Windows — amd64 + arm64)
   - Archives: `.tar.gz` (Unix), `.zip` (Windows)
   - Linux packages: `.deb`, `.rpm`, `.apk`
   - GitHub release with auto-generated changelog and checksums
   - Docker images → GitHub Container Registry (`ghcr.io/{owner}/agora-cli`)

2. **npm publish** job (currently disabled until npm package access and package names are finalized):
   - Publishes six per-platform packages (`@agoraio/cli-{os}-{arch}`)
   - Publishes the wrapper package (`agoraio-cli`)
   - Requires `NPM_TOKEN` secret

3. **Apt repository** job (triggered by the published release):
   - Downloads `.deb` files from the release
   - Rebuilds the signed apt repo on GitHub Pages
   - Requires `APT_SIGNING_KEY` secret + `APT_SIGNING_KEY_ID` variable

## Local Verification

Before cutting a tag:

```bash
go test ./...
go build -o agora .
./agora --help
./agora whoami

# Dry-run GoReleaser to catch config errors before the real release:
goreleaser release --snapshot --clean
```

## Required Secrets and Variables

| Name | Type | Required for |
|------|------|-------------|
| `NPM_TOKEN` | secret | npm publish when the job is enabled |
| `APT_SIGNING_KEY` | secret | Signed apt repo on GitHub Pages |
| `APT_SIGNING_KEY_ID` | variable | Signed apt repo on GitHub Pages |

Homebrew and Scoop are not part of the current GoReleaser config. Add `brews:` / `scoops:` blocks before documenting them as automated channels.

## Distribution Channels

| Channel | How |
|---------|-----|
| Homebrew | Coming soon; direct installer is current primary macOS path |
| npm (convenience) | Coming soon; publish job exists but is disabled |
| apt/deb (Debian/Ubuntu) | apt-repo.yml → GitHub Pages |
| rpm (RHEL/Fedora) | Release artifact (.rpm via GoReleaser) |
| apk (Alpine/Docker) | Release artifact (.apk via GoReleaser) |
| Scoop (Windows) | Coming soon |
| Docker (GHCR) | GoReleaser dockers block |
| Shell install script | `install.sh` downloads from GitHub Releases |
| Winget (Windows) | Manual: submit PR to microsoft/winget-pkgs |

## One-Time Setup Checklist

- [ ] Enable GitHub Pages on this repo (Settings → Pages → Source: `gh-pages` branch)
- [ ] Generate GPG key for apt signing; set `APT_SIGNING_KEY` and `APT_SIGNING_KEY_ID`
- [ ] Set `NPM_TOKEN` with publish access to `agoraio-cli` and `@agoraio/*`, then enable the npm job
- [ ] Add Homebrew and Scoop GoReleaser blocks before announcing those channels
- [ ] Submit first Winget manifest PR to `microsoft/winget-pkgs` after the first release
