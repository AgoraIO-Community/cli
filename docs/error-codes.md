# Agora CLI Error Codes

Structured JSON failures include `error.code` when the CLI can classify the recovery path.

| Code | Exit | Meaning | Recovery |
|------|------|---------|----------|
| `AUTH_UNAUTHENTICATED` | 3 | No usable local session exists. | Run `agora login`. |
| `AUTH_SESSION_EXPIRED` | 3 | The stored session is expired or rejected after refresh. | Run `agora login` again. |
| `PROJECT_NOT_SELECTED` | 1 | No explicit, repo-local, or global project context is available. | Pass `--project`, work inside a bound quickstart, or run `agora project use <project>`. |
| `PROJECT_NOT_FOUND` | 1 | The requested project ID or exact name was not found. | Run `agora project list` and retry with the project ID. |
| `PROJECT_AMBIGUOUS` | 1 | A project name matched multiple projects. | Retry with the project ID. |
| `PROJECT_NO_CERTIFICATE` | 1 | The selected project has no app certificate for env seeding. | Enable an app certificate in Console or select another project. |
| `QUICKSTART_TEMPLATE_REQUIRED` | 1 | `init` needs a template in JSON, CI, or non-TTY mode. | Pass `--template` or run `agora quickstart list`. |
| `QUICKSTART_TEMPLATE_UNKNOWN` | 1 | The template ID is not known to this CLI. | Run `agora quickstart list`. |
| `QUICKSTART_TEMPLATE_UNAVAILABLE` | 1 | The template exists but is not currently available. | Choose an available template. |
| `QUICKSTART_TEMPLATE_ENV_UNSUPPORTED` | 1 | The selected template does not define an env target path. | Choose a template with env support or configure the env file manually. |
| `QUICKSTART_TARGET_EXISTS` | 1 | The clone target already exists. | Choose a new directory. |
| `WORKSPACE_ENV_FILE_MISSING` | 1 | `project doctor --deep` expected a quickstart env file that is missing. | Run the command from `suggestedCommand`. |
| `WORKSPACE_ENV_APP_ID_MISSING` | 1 | A quickstart env file is missing the required app ID key. | Run the command from `suggestedCommand`. |
| `WORKSPACE_ENV_APP_ID_MISMATCH` | 1 | A quickstart env file points at a different app ID. | Run the command from `suggestedCommand`. |

Unknown API errors preserve upstream `code`, `httpStatus`, and `requestId` when the API provides them.
