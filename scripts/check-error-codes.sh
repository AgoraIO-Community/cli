#!/usr/bin/env bash
#
# check-error-codes.sh — verify docs/error-codes.md documents every error code
# emitted by internal/cli/*.go.
#
# Behavior:
#   - Greps every `Code:\s*"FOO"` literal from internal/cli/*.go.
#   - Greps every `Code:\s*"FEATURE_" + ...` dynamic prefix.
#   - Cross-checks against docs/error-codes.md.
#   - Exits non-zero with a clear report when any code is undocumented.
#
# Used by:
#   - `make snapshot-error-codes` (local + CI)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="${REPO_ROOT}/internal/cli"
DOC="${REPO_ROOT}/docs/error-codes.md"

if [ ! -f "$DOC" ]; then
  echo "::error::docs/error-codes.md not found at ${DOC}" >&2
  exit 1
fi

# Collect all literal "FOO_BAR" strings used as Code: values.
# Filter to ALL-CAPS-ish identifiers to avoid catching map keys, ints, etc.
literal_codes="$(grep -hoE 'Code:[[:space:]]*"[A-Z][A-Z0-9_]+"' "${SOURCE_DIR}"/*.go \
  | sed -E 's/^Code:[[:space:]]*"//; s/"$//' \
  | sort -u || true)"

# Collect dynamic prefixes used like Code: "FEATURE_" + strings.ToUpper(...).
# We don't try to enumerate the suffixes; instead we require error-codes.md to
# document the prefix family explicitly (e.g. `FEATURE_<NAME>_PROVISIONING`).
dynamic_prefixes="$(grep -hoE 'Code:[[:space:]]*"[A-Z][A-Z0-9_]+_"[[:space:]]*\+' "${SOURCE_DIR}"/*.go \
  | sed -E 's/^Code:[[:space:]]*"//; s/_"[[:space:]]*\+$//' \
  | sort -u || true)"

missing=()
for code in $literal_codes; do
  # Match `code` enclosed in backticks, or anywhere as a bare token in the doc.
  if ! grep -qE "(\`${code}\`|\b${code}\b)" "$DOC"; then
    missing+=("$code")
  fi
done

# For dynamic prefixes, require *some* mention of the prefix in the doc.
for prefix in $dynamic_prefixes; do
  if ! grep -qE "${prefix}_<[A-Z]+>|${prefix}<NAME>|\`${prefix}_" "$DOC"; then
    missing+=("(dynamic prefix) ${prefix}_*")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "::error::The following error codes are emitted by internal/cli/ but are NOT documented in docs/error-codes.md:" >&2
  for code in "${missing[@]}"; do
    echo "  - ${code}" >&2
  done
  echo >&2
  echo "Either add an entry to docs/error-codes.md, or document the dynamic family explicitly." >&2
  exit 1
fi

count=$(echo "$literal_codes" | grep -c . || true)
prefix_count=$(echo "$dynamic_prefixes" | grep -c . || true)
echo "OK: docs/error-codes.md documents all ${count} static codes and ${prefix_count} dynamic prefix families."
