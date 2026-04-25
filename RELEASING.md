# Releasing Agora CLI Go

Releases are automated through GitHub Actions.

## Continuous Integration

The repository runs CI on:
- every push
- every pull request

CI validates the CLI on:
- Linux
- macOS
- Windows

Each CI run:
- sets up Go from `go.mod`
- runs `go test ./...`
- builds the CLI binary

## Automated Releases

Release publishing is tag-driven.

To publish a new release:

```bash
git tag v0.1.4
git push origin v0.1.4
```

Pushing a `v*` tag triggers the release workflow, which:
- runs the Go test suite
- builds cross-platform release artifacts
- packages binaries for Linux, macOS, and Windows
- generates SHA-256 checksums
- publishes or updates the GitHub release automatically

## Release Artifacts

The automated release currently builds:
- `linux/amd64`
- `linux/arm64`
- `darwin/amd64`
- `darwin/arm64`
- `windows/amd64`
- `windows/arm64`

## Local Verification

Before cutting a tag, it is still reasonable to verify locally:

```bash
go test ./...
go build -o agora .
./agora --help
./agora whoami
```

## Notes

- Keep the command surface aligned with `agora-cli-ts` until the TypeScript CLI is fully retired.
- Update the migration notes in `README.md` when the Go CLI becomes the default distribution.
