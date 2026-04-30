package cli

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/spf13/cobra"
)

// jsonProgressFor returns a progressEmitter for long-running operations.
// JSON mode emits NDJSON on stdout for agents/scripts. Pretty TTY mode emits
// compact status lines on stderr so humans can see that work is progressing.
func jsonProgressFor(a *App, cmd *cobra.Command, command string) progressEmitter {
	if a == nil || cmd == nil {
		return nil
	}
	if a.resolveOutputMode(cmd) != outputJSON {
		if isTTY(os.Stderr) {
			return makePrettyProgressEmitter(cmd.ErrOrStderr())
		}
		return nil
	}
	return makeJSONProgressEmitter(cmd.OutOrStdout(), command)
}

// progressEmitter writes a single progress event. Callers may pass nil for a
// no-op (used in pretty mode where step-by-step text already prints to stderr).
//
// The wire format is one JSON object per line (NDJSON) on stdout:
//
//	{"event":"progress","command":"<command>","stage":"<stage>","message":"...","timestamp":"..."}
//
// The terminal envelope follows on its own line, also as a complete JSON
// object. Agents should parse line-by-line until they see an object with
// `"ok"` set, which indicates the final envelope.
//
// Stages are stable strings; agents may match on them. See
// docs/automation.md for the full taxonomy.
type progressEmitter func(stage, message string, fields map[string]any)

// makeJSONProgressEmitter returns a progressEmitter that writes one NDJSON
// line per call to out. Writes are serialized so concurrent callers can not
// interleave bytes. Callers may pass the same emitter to multiple goroutines.
func makeJSONProgressEmitter(out io.Writer, command string) progressEmitter {
	if out == nil {
		return nil
	}
	var mu sync.Mutex
	return func(stage, message string, fields map[string]any) {
		event := map[string]any{
			"event":     "progress",
			"command":   command,
			"stage":     stage,
			"message":   message,
			"timestamp": time.Now().UTC().Format(time.RFC3339Nano),
		}
		for k, v := range fields {
			if _, reserved := event[k]; reserved {
				continue
			}
			event[k] = v
		}
		b, err := json.Marshal(event)
		if err != nil {
			return
		}
		mu.Lock()
		defer mu.Unlock()
		_, _ = out.Write(b)
		_, _ = out.Write([]byte("\n"))
	}
}

func makePrettyProgressEmitter(out io.Writer) progressEmitter {
	if out == nil {
		return nil
	}
	var mu sync.Mutex
	return func(_, message string, _ map[string]any) {
		message = strings.TrimSpace(message)
		if message == "" {
			return
		}
		mu.Lock()
		defer mu.Unlock()
		_, _ = fmt.Fprintf(out, "- %s\n", message)
	}
}

// emit is a small convenience that no-ops when the emitter is nil. Use this
// from any path that may or may not have a real emitter wired in.
func (e progressEmitter) emit(stage, message string, fields map[string]any) {
	if e == nil {
		return
	}
	e(stage, message, fields)
}
