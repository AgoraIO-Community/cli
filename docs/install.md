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

Install to a user-writable directory and let the installer add it to your shell rc:

```bash
curl -fsSL https://raw.githubusercontent.com/AgoraIO-Extensions/agora-cli/main/install.sh \
  | INSTALL_DIR="$HOME/.local/bin" sh -s -- --add-to-path
agora --help
```

Run a dry run before installing:

```bash
curl -fsSL https://raw.githubusercontent.com/AgoraIO-Extensions/agora-cli/main/install.sh | sh -s -- --dry-run
```

The Unix installer is idempotent. Re-running with the same `--version` will detect the existing install at `INSTALL_DIR/agora` and exit successfully without re-downloading. Pass `--force` to reinstall.

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

## Unix Installer Flags

```text
--version VERSION       Install a specific version (with or without leading 'v').
--dir INSTALL_DIR       Install directory (default: /usr/local/bin).
--prerelease            Resolve latest including GitHub prereleases.
--list-versions         Print recent published versions and exit.
--force                 Reinstall even if the requested version is present, or
                        proceed past a Homebrew/npm-managed install warning.
--add-to-path           Append INSTALL_DIR to your shell rc file (bash, zsh,
                        fish, or .profile).
--dry-run               Show what would happen without writing any files.
--no-color              Disable colored output.
-q, --quiet             Suppress non-error output.
-v, --verbose           Verbose debug output.
--installer-version     Print this installer's revision and exit.
-h, --help              Show full help.
```

If a Homebrew- or npm-managed `agora` is detected, the installer refuses by default and recommends the package-manager upgrade command. Pass `--force` to install alongside the managed install.

## Supported Environment Variables

Both direct installers support the same core overrides:

- `GITHUB_REPO`: install from a fork or alternate repository.
- `VERSION`: install a specific version. Both `0.1.4` and `v0.1.4` are accepted.
- `INSTALL_DIR`: install to a custom directory.
- `GITHUB_TOKEN` or `GH_TOKEN`: optional GitHub token to avoid API rate limits when resolving the latest release.
- `NO_COLOR`: any non-empty value disables colored output (Unix installer).
- `SUDO`: command for privileged installs (default `sudo`; set to `doas`, `sudo -n`, or empty to disable elevation).

Advanced or test overrides:

- `GITHUB_API_URL`: alternate API base URL.
- `RELEASES_DOWNLOAD_BASE_URL`: alternate release download base URL.
- `RELEASES_PAGE_URL`: alternate releases page URL used in error messages.
- `DOCS_URL`: alternate docs URL printed in the next-steps footer.
- `ISSUES_URL`: alternate issues URL printed in error messages.

## Exit Codes (Unix Installer)

The Unix installer uses a stable exit-code contract for scripted callers:

| Code | Meaning                                                  |
| ---- | -------------------------------------------------------- |
| 0    | success                                                  |
| 1    | generic / unknown error                                  |
| 2    | invalid arguments                                        |
| 3    | missing prerequisite (`curl`, `tar`, `sha256sum`, ...)   |
| 4    | unsupported platform / architecture                      |
| 5    | network or download failure                              |
| 6    | checksum verification failed                             |
| 7    | install or permission failure (non-writable dir, sudo)   |
| 8    | post-install verification failed                         |

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

- On macOS and Linux, prefer `INSTALL_DIR="$HOME/.local/bin"` if you do not want `sudo`. The installer refuses to prompt for `sudo` when `stdin` is not a TTY (the typical `curl | sh` case) and instead prints a clear remediation hint.
- On Windows, choose a writable `-InstallDir` or run PowerShell elevated if you are installing into a system directory.

### "Detected Homebrew-managed install" / "Detected npm-managed install"

The Unix installer refuses to install over an existing Homebrew- or npm-managed `agora` to avoid creating two installs that shadow each other on PATH. Either:

- Use the recommended package-manager upgrade command (`brew upgrade agora` or `npm update -g agoraio-cli`), or
- Re-run the installer with `--force` to install alongside.

### PATH issues

If `agora` installs successfully but is not found:

- macOS and Linux: re-run with `--add-to-path` to update your shell rc automatically, or add `INSTALL_DIR` to your shell profile manually, for example `export PATH="$HOME/.local/bin:$PATH"`.
- Windows: rerun `install.ps1 -AddToPath` or add `%LOCALAPPDATA%\Programs\Agora\bin` to your user PATH manually, then open a new terminal.

### Checksum failures

The installers verify release artifacts against the published `checksums.txt`. If checksum verification fails, the installer prints the expected and actual SHA256 and exits with code `6`. Do not continue with the install. Retry the download, confirm the requested version exists on the GitHub release, and check whether a proxy or cache is rewriting downloads.

### Proxies and restricted networks

The installers rely on your platform's normal HTTP proxy settings. If downloads fail behind a corporate proxy, retry with the appropriate proxy environment configured and prefer a pinned `VERSION`. The Unix installer enables `curl --retry 3 --retry-connrefused` with sane connect and total timeouts by default.

## Security

The Unix installer:

- Restricts `curl` to `--proto =https --tlsv1.2`, refusing plain HTTP and legacy TLS.
- Verifies every artifact against the published `checksums.txt` before installing.
- Installs atomically: the binary is written to a temp path inside `INSTALL_DIR` and renamed only after extraction and checksum verification succeed. Interrupted runs leave no partial binary behind.

For CI, automation, and reproducible environments, pin `VERSION` explicitly instead of relying on the latest release lookup.

## Distribution and Tap Automation

Homebrew packaging templates, generator script, and tap automation workflow are documented in [docs/homebrew.md](homebrew.md).
