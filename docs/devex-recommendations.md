# Agora CLI Go DevEx Recommendations

This document captures the recommended follow-up work to make `agora-cli-go` feel world-class for both human developers and agentic/automation workflows.

The current CLI is already in a strong state:
- clear command taxonomy
- strong help output
- `init` as a high-level onboarding wrapper
- low-level commands preserved for explicit workflows
- framework-aware quickstart env management

The remaining work is primarily around documentation, automation affordances, and a few contract-level polish areas.

## Goals

The final developer experience should satisfy all of the following:

1. A new developer can go from zero to a running demo in under 5 minutes without reading source code.
2. An experienced developer can still use explicit low-level commands for advanced workflows.
3. An automation agent can discover the full command surface, prefer stable JSON output, and rely on documented result shapes.
4. The README and help output reinforce the same mental model instead of forcing users to infer behavior from implementation details.
5. The CLI feels intentional and layered:
   - `init` for onboarding
   - `quickstart` for standalone starter repos
   - `project` for remote Agora resources
   - `add` for future in-place integrations

## Priority 1: Rewrite the README as a Real Product Entry Point

### Problem

The current README is too thin. It gives examples, but it does not fully explain:
- who the CLI is for
- what the primary workflow is
- what the command families mean
- when to use `init` vs `quickstart` vs `project`
- how automation should use `--json`

### Recommendation

Rewrite `README.md` into the following structure:

1. `What This CLI Is`
2. `Install / Build`
3. `Quick Start`
4. `Command Model`
5. `Common Workflows`
6. `Automation / Agent Usage`
7. `Configuration`
8. `Troubleshooting`

### Required README Content

#### 1. What This CLI Is

Add a short explanation like:

- `agora-cli-go` is the native Go CLI for managing Agora auth, projects, quickstarts, and onboarding workflows.
- It supports both high-level setup (`init`) and explicit low-level operations (`project`, `quickstart`).

#### 2. Install / Build

Document:

```bash
go build -o agora .
```

Also document the expected runtime dependencies:
- `git` is required for `quickstart create` and `init`
- the selected quickstart repo may require `pnpm`, `bun`, `go`, or other runtime-specific tools after cloning

#### 3. Quick Start

The first example must use `init`, not low-level commands.

Required examples:

```bash
./agora login
./agora init my-nextjs-demo --template nextjs
```

```bash
./agora init my-python-demo --template python
```

```bash
./agora init my-go-demo --template go
```

Explain clearly that `init` does all of the following:
- creates a new Agora project by default
- enables the default features `rtc` and `convoai`
- clones the selected quickstart
- writes the framework-specific env file
- sets the selected project as current context

#### 4. Command Model

Document the CLI nouns explicitly.

Required content:

- `init`
  Recommended onboarding command. Creates or binds a project, clones a quickstart, writes env, and prints next steps.
- `quickstart`
  Standalone starter repos and quickstart env management.
- `project`
  Remote Agora resource management and project environment export.
- `auth`
  Login/session helpers.
- `config`
  Local CLI defaults.
- `add`
  Reserved for future in-place integrations into an existing codebase.

#### 5. Common Workflows

Include at least these workflow sections:

- `Onboard a new demo`
- `Use an existing project with a quickstart`
- `Update env after changing projects`
- `Inspect project readiness`
- `Use low-level commands directly`

Examples that must be included:

```bash
./agora init my-nextjs-demo --template nextjs
```

```bash
./agora quickstart create my-go-demo --template go --project my-existing-project
./agora quickstart env write my-go-demo --project my-existing-project
```

```bash
./agora project doctor
./agora project doctor --json
```

```bash
./agora --help --all
```

#### 6. Automation / Agent Usage

This section is required for world-class agentic DevEx.

Document all of the following:

- Prefer `--json` for any command consumed by scripts or agents.
- Prefer `init` for end-to-end setup.
- Use low-level commands when the workflow must be decomposed or partially resumed.
- Use `agora --help --all` to inspect the full command tree.

Include specific examples:

```bash
./agora init my-nextjs-demo --template nextjs --json
./agora quickstart create my-python-demo --template python --project my-project --json
./agora quickstart env write my-python-demo --json
./agora project doctor --json
```

#### 7. Configuration

Clarify where config/session/context/logs are stored and mention:
- `config.example.json`
- `agora config get`
- `agora config path`

#### 8. Troubleshooting

Add short entries for:
- login/browser issues
- missing `git`
- quickstart clone failures
- missing app certificate for env injection
- project not selected / `--project` guidance

## Priority 2: Document the JSON Contract for Automation

### Problem

The CLI emits structured JSON envelopes, but the contract is not documented outside the code and tests.

### Recommendation

Create a new doc:

- `docs/automation.md`

This document should explicitly define the machine-consumption contract.

### Required Content

Document that JSON commands return an envelope shaped like:

```json
{
  "ok": true,
  "command": "init",
  "data": {},
  "meta": {
    "outputMode": "json"
  }
}
```

Then define the stable `data` fields for at least:

- `init`
- `project create`
- `project use`
- `project show`
- `project env write`
- `quickstart list`
- `quickstart create`
- `quickstart env write`
- `project doctor`
- `auth status`

For each one, specify:
- which fields are required
- which fields are optional
- which fields are intended for display only
- which fields are safe for agents to branch on

### Required Detail for `init`

Document fields including:
- `action`
- `template`
- `projectAction`
- `projectId`
- `projectName`
- `region`
- `path`
- `envPath`
- `enabledFeatures`
- `nextSteps`
- `status`

Clarify expected values:
- `projectAction` is `created` or `existing`
- `status` is currently `ready`

## Priority 3: Make the Default README and Help Flows Match Exactly

### Problem

The CLI help and README should reinforce the same workflows. Right now they are close, but not fully synchronized.

### Recommendation

After the README rewrite, verify that all of the following are aligned:

- root README examples
- `agora --help`
- `agora init --help`
- `agora quickstart --help`
- `agora quickstart env write --help`
- `agora project --help`

### Required Action

Add or update tests so help text and README do not drift badly over time.

Recommended test coverage:

- README contains `agora init`
- README contains `--help --all`
- `init --help` describes default project creation and `--project`
- `quickstart env write --help` explicitly distinguishes Next.js vs Python/Go env conventions

## Priority 4: Improve Human-Friendly Next-Step Output

### Problem

`init` already prints next steps, which is good, but it can go further.

### Recommendation

Refine the pretty output for `init` to be more action-oriented.

### Desired Behavior

Pretty output should include:
- what was created or reused
- where the app was cloned
- which env file was written
- exactly what the developer should run next

Potential format:

```text
Init
Template       : nextjs
Project        : my-nextjs-demo
Project Action : created
Path           : /path/to/my-nextjs-demo
Env Path       : .env.local
Features       : rtc, convoai
Status         : ready

Next Steps
- cd my-nextjs-demo
- pnpm install
- pnpm dev
```

### Additional Recommendation

If practical, derive next-step install commands from template metadata instead of hardcoding them inside multiple branches. This makes future templates easier to add.

## Priority 5: Add Template Metadata for Runtime-Specific Guidance

### Problem

Template behavior is currently partly encoded in conditionals. The CLI will scale better if more of this is data-driven.

### Recommendation

Extend `quickstartTemplate` with additional optional metadata fields such as:

- `InstallCommand`
- `RunCommand`
- `EnvDocsSummary`
- `SupportsInit`

This is not mandatory immediately, but it is recommended if more templates will be added.

### Desired Outcome

Template records should eventually be able to drive:
- help examples
- next-step output
- README snippets
- future template listing enhancements

## Priority 6: Clarify Low-Level vs Convenience Commands in Docs

### Problem

The CLI now has both a clean onboarding wrapper (`init`) and a full low-level surface. That is a strength, but only if it is explained clearly.

### Recommendation

In both README and help docs, explicitly state:

- `init` is the recommended path
- low-level commands remain available for:
  - partial workflows
  - advanced workflows
  - automation that wants more control
  - re-running env sync without cloning again

### Required Low-Level Flow Example

Include a compact but explicit advanced example:

```bash
./agora project create my-agent-demo --feature rtc --feature convoai
./agora quickstart create my-go-demo --template go --project my-agent-demo
./agora quickstart env write my-go-demo --project my-agent-demo
```

## Priority 7: Improve Agentic Discoverability

### Problem

The CLI is already reasonably automation-friendly, but agents should not have to inspect code to understand the surface area.

### Recommendation

Document a small set of agent best practices in `docs/automation.md` and optionally in the README:

- use `--json`
- use `--help --all` for full tree discovery
- use `init` for end-to-end setup
- use `quickstart env write` to re-sync env files after changing project selection
- use `project doctor --json` for readiness checks

### Stretch Recommendation

If desired later, add a dedicated machine-readable command such as:

- `agora commands --json`

This would return the command tree and key metadata in JSON, which is excellent for agentic tooling, but it is not required immediately because `--help --all` already improves discoverability substantially.

## Priority 8: Add README and Docs Coverage in Tests

### Problem

The CLI behavior is tested well, but the docs can still drift.

### Recommendation

Add lightweight tests that assert:

- `README.md` contains `agora init`
- `README.md` contains `quickstart env write`
- `README.md` contains `--help --all`
- the automation doc exists and contains `--json`

These do not need to be exhaustive content snapshot tests. They just need to catch accidental regression of the public onboarding contract.

## Recommended Execution Order

Implement the work in this order:

1. Rewrite `README.md`
2. Add `docs/automation.md`
3. Synchronize help examples and README language
4. Improve `init` next-step output if needed
5. Add doc-presence / doc-content tests
6. Optionally refactor template metadata to reduce branching

## Definition of Done

This DevEx improvement work is complete when all of the following are true:

1. A developer can land on the README and understand the difference between `init`, `project`, and `quickstart` immediately.
2. The README uses `init` as the primary onboarding flow.
3. Automation guidance exists and explicitly recommends `--json`.
4. The JSON envelope and major command result shapes are documented.
5. The CLI help and README examples are aligned.
6. Low-level commands remain documented as advanced/explicit workflows.
7. Tests cover the most important public docs guarantees.

## Non-Goals

This document does not require:

- removing low-level commands
- exposing `add` publicly before it is implemented
- changing the current project/env semantics
- adding dependency installation to `init`

Those can be considered separately.
