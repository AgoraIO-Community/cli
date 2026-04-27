#!/usr/bin/env sh
# Agora CLI installer for macOS and Linux.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/.../main/install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --version 0.1.4
#   curl -fsSL .../install.sh | INSTALL_DIR=~/.local/bin sh
#   curl -fsSL .../install.sh | GITHUB_TOKEN=... sh

set -e
if (set -o pipefail) >/dev/null 2>&1; then
  set -o pipefail
fi

GITHUB_REPO="${GITHUB_REPO:-AgoraIO-Extensions/agora-cli}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
VERSION="${VERSION:-}"
SUDO="${SUDO:-sudo}"
GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"
RELEASES_DOWNLOAD_BASE_URL="${RELEASES_DOWNLOAD_BASE_URL:-https://github.com/${GITHUB_REPO}/releases/download}"
RELEASES_PAGE_URL="${RELEASES_PAGE_URL:-https://github.com/${GITHUB_REPO}/releases}"
AUTH_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

usage() {
  cat <<EOF
Install Agora CLI for macOS and Linux.

Usage:
  sh install.sh [--version VERSION] [--dir INSTALL_DIR]

Options:
  --version VERSION   Install a specific version (with or without leading "v")
  --dir INSTALL_DIR   Install directory (default: ${INSTALL_DIR})
  -h, --help          Show this help

Environment:
  GITHUB_REPO                 GitHub repository (default: ${GITHUB_REPO})
  INSTALL_DIR                 Install directory (default: ${INSTALL_DIR})
  VERSION                     Version to install when --version is omitted
  GITHUB_TOKEN / GH_TOKEN     Optional token to avoid GitHub API rate limits
  SUDO                        Command used for privileged installs (default: ${SUDO})
  GITHUB_API_URL              Override GitHub API base URL
  RELEASES_DOWNLOAD_BASE_URL  Override release download base URL
  RELEASES_PAGE_URL           Override releases page URL
EOF
}

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

download_file() {
  url=$1
  output=$2
  mode=${3:-download}

  if [ "$mode" = "api" ] && [ -n "$AUTH_TOKEN" ]; then
    curl -fsSL \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${AUTH_TOKEN}" \
      "$url" -o "$output"
    return
  fi

  if [ "$mode" = "api" ]; then
    curl -fsSL -H "Accept: application/vnd.github+json" "$url" -o "$output"
    return
  fi

  curl -fsSL "$url" -o "$output"
}

download_or_fail() {
  url=$1
  output=$2
  mode=${3:-download}

  if download_file "$url" "$output" "$mode"; then
    return 0
  fi

  warn "Failed to download: $url"
  warn "Release page: ${RELEASES_PAGE_URL}"
  if [ "$mode" = "api" ]; then
    die "Could not resolve the latest release. Set VERSION explicitly or provide GITHUB_TOKEN / GH_TOKEN if you are hitting rate limits."
  fi

  die "Download failed. Check your network or proxy settings, or try again with VERSION pinned."
}

sha256_file() {
  file=$1

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return 0
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return 0
  fi

  die "Missing required command: sha256sum or shasum"
}

run_elevated() {
  # Allow values such as SUDO="sudo -n" while keeping call sites simple.
  eval "$SUDO" '"$@"'
}

nearest_existing_dir() {
  target=$1

  while [ ! -d "$target" ]; do
    parent=$(dirname "$target")
    if [ "$parent" = "$target" ]; then
      break
    fi
    target=$parent
  done

  printf '%s\n' "$target"
}

user_can_write_install_dir() {
  probe=$(nearest_existing_dir "$INSTALL_DIR")
  [ -w "$probe" ]
}

install_binary() {
  source_bin=$1
  temp_dest=$2
  final_dest=$3

  if [ -n "$USE_SUDO" ]; then
    run_elevated mkdir -p "$INSTALL_DIR"
    if command -v install >/dev/null 2>&1; then
      run_elevated install -m 755 "$source_bin" "$temp_dest"
    else
      run_elevated cp "$source_bin" "$temp_dest"
      run_elevated chmod 755 "$temp_dest"
    fi
    run_elevated mv -f "$temp_dest" "$final_dest"
    return
  fi

  mkdir -p "$INSTALL_DIR"
  if command -v install >/dev/null 2>&1; then
    install -m 755 "$source_bin" "$temp_dest"
  else
    cp "$source_bin" "$temp_dest"
    chmod 755 "$temp_dest"
  fi
  mv -f "$temp_dest" "$final_dest"
}

normalize_version() {
  VERSION=$(printf '%s' "$VERSION" | sed 's/^v//')
}

show_existing_install() {
  if ! command -v agora >/dev/null 2>&1; then
    return 0
  fi

  current_path=$(command -v agora)
  current_version=$("$current_path" --version 2>/dev/null || true)
  if [ -n "$current_version" ]; then
    log "Existing install: ${current_version} (${current_path})"
  else
    log "Existing install detected at ${current_path}"
  fi
}

verify_installed_binary() {
  binary_path=$1

  if "$binary_path" --version >/dev/null 2>&1; then
    return 0
  fi

  "$binary_path" --help >/dev/null 2>&1
}

resolve_version() {
  latest_json="${TMP}/latest.json"
  latest_url="${GITHUB_API_URL%/}/repos/${GITHUB_REPO}/releases/latest"

  download_or_fail "$latest_url" "$latest_json" api
  VERSION=$(
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' "$latest_json" \
      | sed -n '1p'
  )
  normalize_version

  if [ -z "$VERSION" ]; then
    die "Could not parse the latest release version. Set VERSION explicitly."
  fi
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --version)
        [ $# -ge 2 ] || die "Missing value for --version"
        VERSION=$2
        shift 2
        ;;
      --version=*)
        VERSION=${1#--version=}
        shift
        ;;
      --dir)
        [ $# -ge 2 ] || die "Missing value for --dir"
        INSTALL_DIR=$2
        shift 2
        ;;
      --dir=*)
        INSTALL_DIR=${1#--dir=}
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

parse_args "$@"
normalize_version

need_cmd curl
need_cmd tar
need_cmd awk
need_cmd sed

OS=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m 2>/dev/null)

case "$OS" in
  darwin|linux) ;;
  msys*|mingw*|cygwin*)
    die "Windows detected from a POSIX shell. Use install.ps1, Scoop, or npm instead."
    ;;
  *)
    die "Unsupported OS: ${OS}. Install via Homebrew, npm, Scoop, or a release package instead."
    ;;
esac

case "$ARCH" in
  x86_64|amd64)   ARCH="amd64" ;;
  aarch64|arm64)  ARCH="arm64" ;;
  *)
    die "Unsupported architecture: ${ARCH}."
    ;;
esac

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

if [ -z "$VERSION" ]; then
  resolve_version
fi

[ -n "$VERSION" ] || die "VERSION cannot be empty."

FILENAME="agora-cli-go_v${VERSION}_${OS}_${ARCH}.tar.gz"
ARCHIVE_URL="${RELEASES_DOWNLOAD_BASE_URL%/}/v${VERSION}/${FILENAME}"
CHECKSUMS_URL="${RELEASES_DOWNLOAD_BASE_URL%/}/v${VERSION}/checksums.txt"
ARCHIVE_PATH="${TMP}/${FILENAME}"
CHECKSUMS_PATH="${TMP}/checksums.txt"
EXTRACTED_BINARY="${TMP}/agora"
DESTINATION="${INSTALL_DIR}/agora"
TEMP_DESTINATION="${INSTALL_DIR}/.agora.tmp.$$"

show_existing_install
log "Installing agora ${VERSION} (${OS}/${ARCH}) -> ${DESTINATION}"

download_or_fail "$ARCHIVE_URL" "$ARCHIVE_PATH"
download_or_fail "$CHECKSUMS_URL" "$CHECKSUMS_PATH"

EXPECTED_SHA=$(
  awk -v file="$FILENAME" '
    NF >= 2 {
      name = $2
      sub(/^\*/, "", name)
      if (name == file) {
        print $1
        exit
      }
    }
  ' "$CHECKSUMS_PATH"
)

[ -n "$EXPECTED_SHA" ] || die "Could not find checksum for ${FILENAME} in checksums.txt."

ACTUAL_SHA=$(sha256_file "$ARCHIVE_PATH")
[ "$EXPECTED_SHA" = "$ACTUAL_SHA" ] || die "Checksum verification failed for ${FILENAME}."

tar -xzf "$ARCHIVE_PATH" -C "$TMP" agora || die "Could not extract agora from ${FILENAME}."
[ -f "$EXTRACTED_BINARY" ] || die "Expected binary not found after extraction."

USE_SUDO=""
if ! user_can_write_install_dir; then
  [ -n "$SUDO" ] || die "Install directory is not writable. Set INSTALL_DIR to a writable path or configure SUDO."
  set -- $SUDO
  [ $# -gt 0 ] || die "SUDO is empty. Set INSTALL_DIR to a writable path or configure SUDO."
  need_cmd "$1"
  USE_SUDO=1
fi

install_binary "$EXTRACTED_BINARY" "$TEMP_DESTINATION" "$DESTINATION"
verify_installed_binary "$DESTINATION" || die "Installed binary did not start correctly."

log "Installed agora to ${DESTINATION}"
if command -v agora >/dev/null 2>&1; then
  log "Current PATH resolves agora to $(command -v agora)"
else
  warn "agora is not on your PATH yet."
  warn "Add it with: export PATH=\"${INSTALL_DIR}:\$PATH\""
fi

log "Done. Run: agora --help"
