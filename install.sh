#!/usr/bin/env sh
# Agora CLI installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/.../main/install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --version 0.1.4
#   curl -fsSL .../install.sh | INSTALL_DIR=~/.local/bin sh

set -e

GITHUB_REPO="${GITHUB_REPO:-AgoraIO-Extensions/agora-cli}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
VERSION="${VERSION:-}"

# ---- argument parsing -------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --dir)     INSTALL_DIR="$2"; shift 2 ;;
    *)         echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---- platform detection -----------------------------------------------------
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
  darwin|linux) ;;
  *) echo "Unsupported OS: $OS. Install via Homebrew or npm instead." && exit 1 ;;
esac

case "$ARCH" in
  x86_64)        ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH." && exit 1 ;;
esac

# ---- resolve version --------------------------------------------------------
if [ -z "$VERSION" ]; then
  VERSION=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  if [ -z "$VERSION" ]; then
    echo "Could not resolve latest version. Set VERSION explicitly:"
    echo "  VERSION=0.1.4 sh install.sh"
    exit 1
  fi
fi

# ---- download and install ---------------------------------------------------
FILENAME="agora-cli-go_v${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${FILENAME}"

echo "Installing agora ${VERSION} (${OS}/${ARCH}) → ${INSTALL_DIR}/agora"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$URL" -o "$TMP/agora.tar.gz"
tar -xzf "$TMP/agora.tar.gz" -C "$TMP" agora

if [ -w "$INSTALL_DIR" ]; then
  install -m 755 "$TMP/agora" "$INSTALL_DIR/agora"
else
  sudo install -m 755 "$TMP/agora" "$INSTALL_DIR/agora"
fi

echo "Done. Run: agora --help"
