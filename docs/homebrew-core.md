# Homebrew Core Submission Guide

This guide covers getting from a custom tap install to:

```bash
brew install agora
```

Important distinction:
- GoReleaser can update your custom tap automatically.
- `homebrew/core` still requires a manual upstream PR and Homebrew maintainer review.

## Current gaps addressed in this repo

These are now handled:
- explicit OSS license file at repo root (`LICENSE`)
- source-build formula draft for `homebrew/core` in:
  - `packaging/homebrew/Formula/agora-core.rb.draft`

## What still must happen for `brew install agora`

1. A formula PR must be opened and merged in `Homebrew/homebrew-core`.
2. The formula name must be accepted (`agora` may be renamed during review if needed).
3. The formula must pass Homebrew audit and CI.

## Step-by-step

### 1) Cut a stable release tag first

Use your signed commit/tag flow:

```bash
git tag v0.1.4
git push origin v0.1.4
```

### 2) Compute source tarball SHA256

Homebrew core formula should build from source tarball:

```bash
VERSION=0.1.4
curl -L "https://github.com/agora/cli-workspace/agora-cli-go/archive/refs/tags/v${VERSION}.tar.gz" | shasum -a 256
```

Save the SHA output for step 3.

### 3) Materialize the draft formula

Start from:
- `packaging/homebrew/Formula/agora-core.rb.draft`

Replace:
- `__VERSION__` with release version (for example `0.1.4`)
- `__SHA256__` with source tarball SHA from step 2

Then save as `agora.rb` for submission.

### 4) Local formula validation

```bash
brew update
export HOMEBREW_NO_INSTALL_FROM_API=1
brew audit --new --formula ./agora.rb
brew install --build-from-source ./agora.rb
brew test agora
```

If install/test fails, iterate before opening PR.

### 5) Prepare `homebrew/core` branch and commit

```bash
brew tap --force homebrew/core
cd "$(brew --repository homebrew/core)"
git checkout -b agora-cli-new-formula
mkdir -p Formula/a
cp /absolute/path/to/agora.rb Formula/a/agora.rb
git add Formula/a/agora.rb
git commit -m "agora 0.1.4 (new formula)"
```

### 6) Open PR to `Homebrew/homebrew-core`

```bash
gh repo fork Homebrew/homebrew-core --clone=false
git push --set-upstream origin agora-cli-new-formula
gh pr create \
  --repo Homebrew/homebrew-core \
  --title "agora 0.1.4 (new formula)" \
  --body "Adds the Agora CLI formula."
```

### 7) Respond to maintainer review quickly

Common reviewer asks:
- rename formula if name conflict/ambiguity
- adjust `desc` wording
- tighten/expand `test do`
- update URL/sha after a new patch release

## If `agora` name is rejected

Fallback plan:
- submit as `agora-cli`
- update your docs to:

```bash
brew install agora-cli
```

Then optionally add alias guidance in your custom tap.

## Practical expectations

- First PR may take iterations.
- GoReleaser automation is excellent for your tap, but not a substitute for core review.
- Once merged into core, users can install without tap:

```bash
brew install agora
```

