# Configuration and Packaging

## Settings composition

```python
@dataclass(frozen=True, slots=True)
class MailSettings:
    smtp_url: str


def build_app(environment: Mapping[str, str]) -> App:
    settings = Settings.from_environment(environment)
    return App(mailer=Mailer(settings.mail))
```

Read raw env/secret-provider values at the boundary. Validate types, required fields, and
cross-field invariants once. Pass `MailSettings` rather than the entire application Settings when
the consumer needs only mail configuration.

Define source precedence deliberately, for example: defaults < config file < environment < CLI.
Do not let every module re-read sources independently.

## Secrets

- collect through a secret manager or secure environment injection;
- redact values while allowing key/source diagnostics;
- rotate without source changes;
- avoid passing secrets in argv when process listings can expose them;
- keep local `.env` ignored and provide only `.env.example` names/shapes.

## Imports and resources

Imports execute module code once and cache it in `sys.modules`. Keep module scope declarative:
definitions, cheap constants, and deterministic metadata.

Use:

```python
from importlib.resources import files

template = files("my_package.templates").joinpath("message.txt").read_text()
```

Avoid `os.chdir`, `sys.path.append`, and paths relative to an assumed cwd.

## Dependencies and environments

Use the repository's declared tool and lockfile. Keep `pyproject.toml` as the dependency/tooling
source of truth when adopted. Verify clean installation in CI. Separate runtime, test, lint, and
optional dependencies according to the tool's supported model.

Recreate a venv from locked inputs. Do not install project dependencies globally or treat an IDE
interpreter selection as proof that CLI/service launch uses the same interpreter.
