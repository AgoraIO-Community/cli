.PHONY: build test lint snapshot

build:
	go build -trimpath -o agora .

test:
	go test ./...

lint:
	test -z "$$(gofmt -l .)"

snapshot:
	go run . --help --all --json
