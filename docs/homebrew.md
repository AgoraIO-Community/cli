# Homebrew Distribution Guide

This guide sets up `agora-cli-go` for Homebrew downloads on macOS and Linux.

Recommended install path:
- Formula (`brew install <tap>/agora`) for macOS + Linux.

Optional:
- Cask (`brew install --cask <tap>/agora-cli-go`) for macOS only.

## 1. Prerequisites

You need:
- A public tap repository (example: `agora/homebrew-tap`)
- GitHub Actions enabled in this CLI repo and the tap repo
- A token that can push and open PRs in the tap repo
- Release artifacts already published by this repo for `v*` tags, including `checksums.txt`

Expected release assets (already produced by your release workflow):
- `agora-cli-go_v<version>_darwin_amd64.tar.gz`
- `agora-cli-go_v<version>_darwin_arm64.tar.gz`
- `agora-cli-go_v<version>_linux_amd64.tar.gz`
- `agora-cli-go_v<version>_linux_arm64.tar.gz`
- `checksums.txt`

## 2. Create the tap repository

Create a repository named `homebrew-tap` under your GitHub org/user.

Then add the standard layout:

```bash
mkdir -p Formula Casks
touch Formula/.keep Casks/.keep
git add Formula/.keep Casks/.keep
git commit -m "chore: initialize homebrew tap layout"
git push
```

## 3. Configure this CLI repository for tap automation

In this repo (`agora-cli-go`) set:

- Repository variable:
  - `HOMEBREW_TAP_REPO=agora/homebrew-tap`
- Repository secret:
  - `HOMEBREW_TAP_TOKEN=<token-with-write-access-to-tap-repo>`

The workflow file that uses these:
- [homebrew-tap.yml](/Users/arlene/Agora/devex/github/cli-workspace/agora-cli-go/.github/workflows/homebrew-tap.yml)

## 4. Understand the generated Homebrew files

Source templates:
- [agora.rb.tmpl](/Users/arlene/Agora/devex/github/cli-workspace/agora-cli-go/packaging/homebrew/Formula/agora.rb.tmpl)
- [agora-cli-go.rb.tmpl](/Users/arlene/Agora/devex/github/cli-workspace/agora-cli-go/packaging/homebrew/Casks/agora-cli-go.rb.tmpl)

Generator script:
- [generate.sh](/Users/arlene/Agora/devex/github/cli-workspace/agora-cli-go/scripts/homebrew/generate.sh)

The script injects version + checksums and emits:
- `packaging/homebrew/generated/Formula/agora.rb`
- `packaging/homebrew/generated/Casks/agora-cli-go.rb`

## 5. Local dry run before your first release automation

Use a real `checksums.txt` from a published release:

```bash
cd agora-cli-go
./scripts/homebrew/generate.sh 0.1.3 /path/to/checksums.txt
```

Validate output:

```bash
sed -n '1,200p' packaging/homebrew/generated/Formula/agora.rb
sed -n '1,200p' packaging/homebrew/generated/Casks/agora-cli-go.rb
```

## 6. Release flow (fully automated tap update)

1. Push a release tag:

```bash
git tag v0.1.4
git push origin v0.1.4
```

2. Existing release workflow publishes artifacts + `checksums.txt`.
3. `Homebrew Tap Update` workflow runs on release publish.
4. Workflow generates formula/cask from release checksums.
5. Workflow opens a PR in your tap repo with updated files.
6. Merge that PR.

## 7. End-user install commands

After tap PR is merged:

Formula (recommended):

```bash
brew tap agora/tap
brew install agora
agora --help
```

macOS cask (optional):

```bash
brew tap agora/tap
brew install --cask agora-cli-go
agora --help
```

Upgrade:

```bash
brew update
brew upgrade agora
```

## 8. Maintenance best practices

- Keep formula as the default installation route for CLI users.
- Keep cask only as optional macOS compatibility path.
- Never hand-edit checksums; always regenerate from release artifacts.
- Keep asset names stable across releases to avoid breaking formula URLs.
- Keep binary name stable as `agora`.
- Add a quick post-release smoke test:
  - `brew install agora`
  - `agora --version`
  - `agora --help`

## 9. Troubleshooting

`Homebrew Tap Update` fails with missing token:
- verify `HOMEBREW_TAP_TOKEN` is set in repo secrets.

Workflow cannot find tap repo:
- verify `HOMEBREW_TAP_REPO` repo variable value (org/repo).

Install fails with checksum mismatch:
- ensure `checksums.txt` belongs to the exact release tag.
- rerun workflow by publishing a new release tag.

