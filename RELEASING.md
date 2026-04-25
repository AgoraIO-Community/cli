# Releasing Agora CLI Go

## Build

```bash
go test ./...
go build -o agora .
```

## Verify

```bash
./agora --help
./agora whoami
```

## Release Notes

- Ship the native Go binary as the production Agora CLI.
- Keep the command surface aligned with `agora-cli-ts` until the TypeScript CLI is fully retired.
- Update the migration notes in `README.md` when the Go CLI becomes the default distribution.
