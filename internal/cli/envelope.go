package cli

import (
	"encoding/json"
	"errors"
	"io"
	"os"
	"strings"

	"github.com/spf13/cobra"
)

// jsonEnvelope is the documented top-level shape returned by every JSON-mode
// command. Stable, machine-readable contract for agents/scripts:
//
//	{
//	  "ok":      bool,                  // true on success, false on failure
//	  "command": string,                // stable command label, e.g. "project create"
//	  "data":    object | null,         // command-specific payload, present on success
//	  "error":   { ... } | absent,      // present on failure
//	  "meta":    { "outputMode": "json", "exitCode": 0 }
//	}
//
// See docs/automation.md for per-command data shapes and docs/error-codes.md
// for the canonical error.code catalog.
type jsonEnvelope struct {
	OK      bool           `json:"ok"`
	Command string         `json:"command"`
	Data    any            `json:"data"`
	Error   *envelopeError `json:"error,omitempty"`
	Meta    map[string]any `json:"meta"`
}

// envelopeError is the failure payload nested under jsonEnvelope.Error. The
// fields mirror cliError but are flattened for JSON consumers and include
// the on-disk log file path so users can grep for context.
type envelopeError struct {
	Message     string `json:"message"`
	Code        string `json:"code,omitempty"`
	HTTPStatus  int    `json:"httpStatus,omitempty"`
	RequestID   string `json:"requestId,omitempty"`
	LogFilePath string `json:"logFilePath,omitempty"`
}

// cliError is the structured error type used internally by every command.
// Returning a *cliError lets the envelope renderer surface a stable
// error.code, the upstream HTTP status, and the originating request ID
// for support escalations.
type cliError struct {
	Message    string
	Code       string
	HTTPStatus int
	RequestID  string
}

func (e *cliError) Error() string {
	if e.Message != "" {
		return e.Message
	}
	return e.Code
}

// JSONRequested reports whether the caller asked for JSON output via
// `--json` or `--output json` (or the `=` form). Used by Execute() before
// the cobra root has been built so we can decide whether to print the
// pretty config banner.
func JSONRequested(args []string) bool {
	for index := 0; index < len(args); index++ {
		arg := args[index]
		if arg == "--json" {
			return true
		}
		if arg == "--output" && index+1 < len(args) && args[index+1] == "json" {
			return true
		}
		if strings.HasPrefix(arg, "--output=") && strings.TrimPrefix(arg, "--output=") == "json" {
			return true
		}
	}
	return false
}

// JSONPrettyRequested reports whether the caller asked for indented JSON
// output via `--pretty`.
func JSONPrettyRequested(args []string) bool {
	return hasFlag(args, "--pretty")
}

// EmitJSONError is the package-level entry point for callers (notably
// cmd/main.go and the panic recovery path) that need to print a JSON
// error envelope without a live cobra command in hand.
func EmitJSONError(command string, err error, exitCode int, logFilePath string) error {
	return emitErrorEnvelope(os.Stdout, command, err, exitCode, logFilePath)
}

func readRawFlagValue(args []string, flag string) string {
	for index := 0; index < len(args)-1; index++ {
		if args[index] == flag {
			return args[index+1]
		}
	}
	return ""
}

func hasFlag(args []string, flag string) bool {
	for _, arg := range args {
		if arg == flag {
			return true
		}
	}
	return false
}

func emitEnvelope(out io.Writer, command string, data any, pretty bool) error {
	envelope := jsonEnvelope{
		OK:      true,
		Command: command,
		Data:    data,
		Meta:    map[string]any{"outputMode": "json", "exitCode": 0},
	}
	return encodeJSON(out, envelope, pretty)
}

func emitFailureEnvelopeWithData(out io.Writer, command string, data any, err error, exitCode int, logFilePath string, pretty bool) error {
	return encodeJSON(out, jsonEnvelope{
		OK:      false,
		Command: command,
		Data:    data,
		Error:   envelopeErrorFrom(err, logFilePath),
		Meta:    map[string]any{"outputMode": "json", "exitCode": exitCode},
	}, pretty)
}

func emitErrorEnvelope(out io.Writer, command string, err error, exitCode int, logFilePath string) error {
	meta := map[string]any{
		"outputMode": "json",
		"exitCode":   exitCode,
	}
	envelopeErr := envelopeErrorFrom(err, logFilePath)
	return encodeJSON(out, jsonEnvelope{
		OK:      false,
		Command: command,
		Data:    nil,
		Error:   envelopeErr,
		Meta:    meta,
	}, JSONPrettyRequested(os.Args[1:]))
}

func encodeJSON(out io.Writer, value any, pretty bool) error {
	enc := json.NewEncoder(out)
	if pretty {
		enc.SetIndent("", "  ")
	}
	return enc.Encode(value)
}

func envelopeErrorFrom(err error, logFilePath string) *envelopeError {
	out := &envelopeError{
		Message:     err.Error(),
		LogFilePath: logFilePath,
	}
	var structured *cliError
	if errors.As(err, &structured) {
		out.Code = structured.Code
		out.HTTPStatus = structured.HTTPStatus
		out.RequestID = structured.RequestID
	}
	return out
}

// jsonPrettyFromContext returns whether the in-flight command was invoked
// with `--pretty`. Stored in the command Context() by PersistentPreRunE.
func jsonPrettyFromContext(cmd *cobra.Command) bool {
	pretty, _ := cmd.Context().Value(contextKeyJSONPretty{}).(bool)
	return pretty
}

// Exit-code plumbing: commands signal a non-1 exit by either returning an
// *exitError directly or by storing the desired code under exitCodeKey{} in
// the cobra command context (see exitIfNeeded).
type exitError struct{ code int }

func (e *exitError) Error() string { return "" }

// renderedError marks an error whose user-facing output (pretty or JSON)
// has already been printed. The top-level Execute() loop swallows the
// extra Cobra "Error: ..." message in that case.
type renderedError struct{ err error }

func (e *renderedError) Error() string { return e.err.Error() }

// ExitCode unwraps an *exitError to retrieve its desired process exit code.
// Returns (0, false) when err is nil or not an *exitError.
func ExitCode(err error) (int, bool) {
	var exitErr *exitError
	if errors.As(err, &exitErr) {
		return exitErr.code, true
	}
	return 0, false
}

// exitCodeForError translates a structured *cliError into the exit-code
// contract documented in docs/error-codes.md (auth failures → 3; everything
// else → 1).
func exitCodeForError(err error) int {
	var structured *cliError
	if errors.As(err, &structured) {
		switch structured.Code {
		case "AUTH_UNAUTHENTICATED", "AUTH_SESSION_EXPIRED":
			return 3
		}
	}
	return 1
}

// ErrorRendered reports whether err is a *renderedError, signaling that
// the user-facing output has already been emitted.
func ErrorRendered(err error) bool {
	var rendered *renderedError
	return errors.As(err, &rendered)
}

func exitIfNeeded(cmd *cobra.Command) error {
	if code, ok := cmd.Context().Value(exitCodeKey{}).(int); ok && code != 0 {
		return &exitError{code: code}
	}
	return nil
}

type exitCodeKey struct{}

// outputModeValue is the pflag.Value adapter that backs `--output` /
// `agora config set output ...` so Cobra and our config code share one
// implementation of the json/pretty validator.
type outputModeValue struct{ target *string }

func newOutputModeValue(target *string) *outputModeValue { return &outputModeValue{target: target} }

func (v *outputModeValue) String() string {
	if v.target == nil {
		return ""
	}
	return *v.target
}

func (v *outputModeValue) Set(value string) error {
	if value != "json" && value != "pretty" {
		return errors.New("--output must be one of: json, pretty")
	}
	*v.target = value
	return nil
}

func (v *outputModeValue) Type() string { return "output" }
