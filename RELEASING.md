# Releasing Agora CLI

Releases are fully automated via GoReleaser. Pushing a `v*` tag is the only manual step.

## Release

```bash
git tag v0.1.4
git push origin v0.1.4
```

The release workflow (`.github/workflows/release.yml`) then:

1. **GoReleaser** builds and publishes everything in parallel:
   - Cross-platform binaries (Linux, macOS, Windows — amd64 + arm64)
   - Archives: `.tar.gz` (Unix), `.zip` (Windows)
   - Linux packages: `.deb`, `.rpm`, `.apk`
   - GitHub release with auto-generated changelog and checksums
   - Homebrew tap PR (requires `HOMEBREW_TAP_TOKEN` secret + `HOMEBREW_TAP_REPO` variable)
   - Scoop bucket update (requires `SCOOP_BUCKET_TOKEN` secret + `SCOOP_BUCKET_REPO` variable)
   - Docker images → GitHub Container Registry (`ghcr.io/{owner}/agora-cli`)

2. **npm publish** job (runs after GoReleaser):
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
| `HOMEBREW_TAP_TOKEN` | secret | Homebrew tap PR |
| `HOMEBREW_TAP_REPO` | variable | Homebrew tap PR (e.g. `org/homebrew-tap`) |
| `SCOOP_BUCKET_TOKEN` | secret | Scoop bucket update |
| `SCOOP_BUCKET_REPO` | variable | Scoop bucket update (e.g. `org/scoop-bucket`) |
| `NPM_TOKEN` | secret | npm publish |
| `APT_SIGNING_KEY` | secret | Signed apt repo on GitHub Pages |
| `APT_SIGNING_KEY_ID` | variable | Signed apt repo on GitHub Pages |

Homebrew and Scoop are skipped gracefully if their tokens/repos are not configured.

## Distribution Channels

| Channel | How |
|---------|-----|
| Homebrew (macOS primary) | GoReleaser brews block → tap PR |
| npm (convenience) | Custom publish-npm job in release.yml |
| apt/deb (Debian/Ubuntu) | apt-repo.yml → GitHub Pages |
| rpm (RHEL/Fedora) | Release artifact (.rpm via GoReleaser) |
| apk (Alpine/Docker) | Release artifact (.apk via GoReleaser) |
| Scoop (Windows) | GoReleaser scoops block → bucket repo |
| Docker (GHCR) | GoReleaser dockers block |
| Shell install script | `install.sh` downloads from GitHub Releases |
| Winget (Windows) | Manual: submit PR to microsoft/winget-pkgs |

## One-Time Setup Checklist

- [ ] Create `{org}/scoop-bucket` GitHub repo; set `SCOOP_BUCKET_TOKEN` and `SCOOP_BUCKET_REPO`
- [ ] Enable GitHub Pages on this repo (Settings → Pages → Source: `gh-pages` branch)
- [ ] Generate GPG key for apt signing; set `APT_SIGNING_KEY` and `APT_SIGNING_KEY_ID`
- [ ] Set `NPM_TOKEN` with publish access to `agoraio-cli` and `@agoraio/*`
- [ ] Submit first Winget manifest PR to `microsoft/winget-pkgs` after the first release

See `docs/goreleaser-migration.md` for the full setup guide.
