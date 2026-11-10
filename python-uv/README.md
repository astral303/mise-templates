# python-uv

This template sets up a `pyproject.toml` Python project with uv and a pinned Python. mise creates the project's `.venv` and activates it, so `python` and the project's console scripts run from it.

## Requirements

- mise
- Windows, Linux or macOS. The tests run on all three.

## Setup

Run these in the project root:

1. Download the template as `mise.local.toml`:

   ```pwsh
   Invoke-WebRequest https://raw.githubusercontent.com/astral303/mise-templates/main/python-uv/mise.toml -OutFile mise.local.toml
   ```

   ```sh
   curl -fsSL -o mise.local.toml https://raw.githubusercontent.com/astral303/mise-templates/main/python-uv/mise.toml
   ```

   To keep `mise.local.toml` out of the project's commits, list it in your global gitignore.

2. If the project's `requires-python` excludes Python 3.14, pin a version it allows:

   ```
   mise use --pin -E local python@3.12
   ```

3. Trust the template and install Python and uv:

   ```
   mise trust
   mise install
   ```

4. Create the environment:

   ```
   mise exec -- uv sync
   ```

   `uv sync` writes `uv.lock` if the project has none, and installs the dependencies into `.venv`. From then on, mise activates `.venv` under `mise exec` and in shells where mise is activated.

## Usage

- Add a dependency with `mise exec -- uv add <package>`, or with `uv add <package>` in a shell where mise is activated.
- After changing the Python version, run `mise exec -- uv sync`. uv rebuilds `.venv` on the new Python.
- To match a project's `.python-version`, pin that version with `mise use --pin -E local python@<version>`.

## Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| `python` in `[tools]` | `3.14.9` | The pinned Python, for uv and `.venv`. `mise use --pin -E local python@<version>` changes it. |
| `uv` in `[tools]` | `0.13.5` | uv for `uv sync`, `uv add` and creating `.venv` |
| `python.uv_venv_auto` | `create\|source` | Create `.venv` when the project has a `uv.lock`, then activate it |
| `UV_PYTHON` | path of the pinned Python's executable; empty until that Python is installed | Makes uv use the pinned Python |

## Limitations

- mise creates and activates `.venv` only in a project with a `uv.lock`. Until the first `uv sync` or `uv lock`, `python` runs the pinned Python directly.
- The pinned Python overrides the project's `.python-version`.
- `uv python find` can report a different interpreter than the one uv uses for the project, such as the version in `.python-version`. `uv run python --version` shows the one uv uses.

## Tests

`tests/test.ps1` sets up `tests/fixture` with the template and checks that:

- `uv sync` builds `.venv` on the pinned Python, and mise activates it
- `uv run` reuses the `.venv` from `uv sync`
- `mise env` succeeds before the pinned Python is installed
- `UV_PYTHON` overrides the project's `.python-version`
- `mise exec -- uv add` installs the package into `.venv`

Run it from the repository root:

```pwsh
pwsh -NoProfile -File python-uv/tests/test.ps1
```

When Python or uv is missing, the script installs it only from the URL and sha256 checksum in `tests/mise.lock`. The `uv add` case downloads `iniconfig` from PyPI. GitHub Actions runs the tests on Windows, Linux and macOS when files under `python-uv/` change, and weekly.

## Updating Python or uv

1. Change the version in `[tools]`.
2. Regenerate `tests/mise.lock`:

   ```pwsh
   pwsh -NoProfile -File python-uv/tests/update-lockfile.ps1
   ```

3. Run the tests.
