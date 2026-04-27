# Install Agora CLI Go

This page lists the supported installation paths for Agora CLI and the direct installers for macOS, Linux, and Windows.

## Direct Installers

### macOS and Linux

Install the latest release:

```bash
curl -fsSL https://raw.githubusercontent.com/AgoraIO-Extensions/agora-cli/main/install.sh | sh
agora --help
```

Install a pinned version:

```bash
curl -fsSL https://raw.githubusercontent.com/AgoraIO-Extensions/agora-cli/main/install.sh | sh -s -- --version 0.1.4
agora --help
```

Install to a user-writable directory:

```bash
curl -fsSL https://raw.githubusercontent.com/AgoraIO-Extensions/agora-cli/main/install.sh | INSTALL_DIR="$HOME/.local/bin" sh
export PATH="$HOME/.local/bin:$PATH"
agora --help
```

### Windows (PowerShell)

Install the latest release:

```powershell
irm https://raw.githubusercontent.com/AgoraIO-Extensions/agora-cli/main/install.ps1 | iex
agora --help
```

Install a pinned version and add the default install directory to your user PATH:

```powershell
$env:VERSION = "0.1.4"
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/AgoraIO-Extensions/agora-cli/main/install.ps1))) -AddToPath
agora --help
```

The Windows installer installs `agora.exe` into `%LOCALAPPDATA%\Programs\Agora\bin` by default.

If your PowerShell execution policy blocks inline scripts, download `install.ps1` first and run it with `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

## Supported Environment Variables

Both direct installers support the same core overrides:

- `GITHUB_REPO`: install from a fork or alternate repository.
- `VERSION`: install a specific version. Both `0.1.4` and `v0.1.4` are accepted.
- `INSTALL_DIR`: install to a custom directory.
- `GITHUB_TOKEN` or `GH_TOKEN`: optional GitHub token to avoid API rate limits when resolving the latest release.

Advanced/test overrides:

- `GITHUB_API_URL`: alternate API base URL.
- `RELEASES_DOWNLOAD_BASE_URL`: alternate release download base URL.
- `RELEASES_PAGE_URL`: alternate releases page URL used in error messages.

## Package Managers

The direct installers are not the only supported path. Package managers remain first-class options:

### npm

```bash
npm install -g agoraio-cli
agora --help
```

Requires Node.js 18+.

### Homebrew Formula

```bash
brew tap agora/tap
brew install agora
agora --help
```

For the eventual no-tap install path (`brew install agora` via `homebrew/core`), follow [docs/homebrew-core.md](homebrew-core.md).

Upgrade:

```bash
brew update
brew upgrade agora
```

### Homebrew Cask (macOS Optional)

```bash
brew tap agora/tap
brew install --cask agora-cli-go
agora --help
```

### Scoop (Windows)

Scoop is supported by the release pipeline through the configured bucket. If your team distributes Agora CLI through Scoop, prefer that bucket for managed Windows installs.

## Build From Source

Requirements:

- Go toolchain from `go.mod`
- `git`

```bash
go build -o agora .
./agora --help
```

## Troubleshooting

### GitHub API rate limits

If latest-version resolution fails, retry with a pinned version or provide `GITHUB_TOKEN` / `GH_TOKEN`:

```bash
GITHUB_TOKEN=your-token-here VERSION=0.1.4 sh install.sh
```

```powershell
$env:GITHUB_TOKEN = "your-token-here"
$env:VERSION = "0.1.4"
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/AgoraIO-Extensions/agora-cli/main/install.ps1)))
```

### Permission errors

- On macOS and Linux, prefer `INSTALL_DIR="$HOME/.local/bin"` if you do not want `sudo`.
- On Windows, choose a writable `-InstallDir` or run PowerShell elevated if you are installing into a system directory.

### PATH issues

If `agora` installs successfully but is not found:

- macOS and Linux: add `INSTALL_DIR` to your shell profile, for example `export PATH="$HOME/.local/bin:$PATH"`.
- Windows: rerun `install.ps1 -AddToPath` or add `%LOCALAPPDATA%\Programs\Agora\bin` to your user PATH manually, then open a new terminal.

### Checksum failures

The installers verify release artifacts against the published `checksums.txt`. If checksum verification fails, do not continue with the install. Retry the download, confirm the requested version exists on the GitHub release, and check whether a proxy or cache is rewriting downloads.

### Proxies and restricted networks

The installers rely on your platform's normal HTTP proxy settings. If downloads fail behind a corporate proxy, retry with the appropriate proxy environment configured and prefer a pinned `VERSION`.

## Security Note

The direct installers verify downloaded artifacts against the release `checksums.txt` before installing. For CI, automation, and reproducible environments, pin `VERSION` explicitly instead of relying on the latest release lookup.

## Distribution and Tap Automation

Homebrew packaging templates, generator script, and tap automation workflow are documented in [docs/homebrew.md](homebrew.md).
