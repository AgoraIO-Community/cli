# Homebrew Distribution

Homebrew tap updates are handled automatically by GoReleaser as part of the release workflow.

## How it works

When a `v*` tag is pushed, GoReleaser:
1. Builds the release archives
2. Computes SHA-256 checksums
3. Generates a Ruby formula from the `brews` block in `.goreleaser.yaml`
4. Opens a PR against the tap repository with the updated formula

No manual checksum management, no template files, no separate workflow.

## Configuration

| Setting | Where |
|---------|-------|
| Tap repository | `vars.HOMEBREW_TAP_REPO` (e.g. `org/homebrew-tap`) |
| Tap write token | `secrets.HOMEBREW_TAP_TOKEN` |

Both are already configured. The `release.yml` workflow splits `HOMEBREW_TAP_REPO` into owner/name for GoReleaser.

## User install

```bash
brew tap <org>/tap
brew install agora
brew upgrade agora
```

## Formula config

See the `brews` block in `.goreleaser.yaml` to change the formula name, description, test command, or PR behavior.
