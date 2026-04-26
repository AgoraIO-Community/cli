#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <version-without-v> <checksums-file> [output-dir]"
  exit 1
fi

version="$1"
checksums_file="$2"
output_dir="${3:-packaging/homebrew/generated}"

if [[ ! -f "$checksums_file" ]]; then
  echo "checksums file not found: $checksums_file"
  exit 1
fi

tmpl_formula="packaging/homebrew/Formula/agora.rb.tmpl"
tmpl_cask="packaging/homebrew/Casks/agora-cli-go.rb.tmpl"

for required in "$tmpl_formula" "$tmpl_cask"; do
  if [[ ! -f "$required" ]]; then
    echo "template not found: $required"
    exit 1
  fi
done

get_sha() {
  local filename="$1"
  local sha
  sha="$(awk -v f="$filename" '$2==f {print $1}' "$checksums_file" | head -n1)"
  if [[ -z "$sha" ]]; then
    echo "missing checksum for $filename"
    exit 1
  fi
  printf "%s" "$sha"
}

sha_darwin_amd64="$(get_sha "agora-cli-go_v${version}_darwin_amd64.tar.gz")"
sha_darwin_arm64="$(get_sha "agora-cli-go_v${version}_darwin_arm64.tar.gz")"
sha_linux_amd64="$(get_sha "agora-cli-go_v${version}_linux_amd64.tar.gz")"
sha_linux_arm64="$(get_sha "agora-cli-go_v${version}_linux_arm64.tar.gz")"

mkdir -p "${output_dir}/Formula" "${output_dir}/Casks"

render() {
  local src="$1"
  local dst="$2"
  sed \
    -e "s/__VERSION__/${version}/g" \
    -e "s/__SHA_DARWIN_AMD64__/${sha_darwin_amd64}/g" \
    -e "s/__SHA_DARWIN_ARM64__/${sha_darwin_arm64}/g" \
    -e "s/__SHA_LINUX_AMD64__/${sha_linux_amd64}/g" \
    -e "s/__SHA_LINUX_ARM64__/${sha_linux_arm64}/g" \
    "$src" > "$dst"
}

render "$tmpl_formula" "${output_dir}/Formula/agora.rb"
render "$tmpl_cask" "${output_dir}/Casks/agora-cli-go.rb"

echo "Generated:"
echo "  ${output_dir}/Formula/agora.rb"
echo "  ${output_dir}/Casks/agora-cli-go.rb"

