# Agora CLI Go

`agora-cli-go` is the native Go/Cobra rewrite of the TypeScript Agora CLI.

## Build

```bash
go build -o agora .
```

## Usage

```bash
./agora login
./agora init my-nextjs-demo --template nextjs
./agora init my-python-demo --template python
./agora quickstart list
./agora quickstart create my-go-demo --template go --project my-agent-demo
./agora quickstart env write my-go-demo
./agora project doctor
```

`project create` provisions the remote Agora project resource. `quickstart create` clones an official standalone quickstart repo.

## Migration

This project mirrors the `agora-cli-ts` command surface in a native Go binary so the CLI no longer depends on the Node.js runtime.

## Config

The CLI writes its config, session, context, and logs under the Agora CLI config directory. See `config.example.json` for the built-in defaults.
