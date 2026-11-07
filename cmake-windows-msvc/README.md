# cmake-windows-msvc

This template builds CMake projects on Windows with Ninja and MSVC (the Visual Studio C++ compiler), for x64 or x86.

## Requirements

- Visual Studio or Visual Studio Build Tools with the **Desktop development with C++** workload (tested with Build Tools 2022)
- PowerShell 7.4 or later (`pwsh`)
- mise

## Setup

Run these in the project root:

1. Download the template as `mise.local.toml`:

   ```pwsh
   Invoke-WebRequest https://raw.githubusercontent.com/astral303/mise-templates/main/cmake-windows-msvc/mise.toml -OutFile mise.local.toml
   ```

   To keep `mise.local.toml` out of the project's commits, list it in your global gitignore.

2. Trust it and install CMake and Ninja:

   ```pwsh
   mise trust
   mise install
   ```

3. Build:

   ```pwsh
   mise run build
   ```

   The build output is in `build/x64-Release`.

## Tasks

| Task | Runs |
| --- | --- |
| `mise run configure` | `cmake -S . -B <CMAKE_BUILD_DIR> -G Ninja` |
| `mise run build` | `configure` if `CMAKE_BUILD_DIR` has no `build.ninja`, then `cmake --build` |
| `mise run install` | `configure`, `cmake --build`, then `cmake --install` |
| `mise run shell` | pwsh with the MSVC environment and `$env:CMAKE_BUILD_DIR` set, for running cmake by hand |

Arguments after `--` are appended to the cmake command, for example `mise run build -- --target app` or `mise run configure -- --fresh`.

## Settings

`mise set -E local NAME=value` changes a setting in `mise.local.toml`. Plain `mise set` writes to the project's `mise.toml` if there is one, and `mise.local.toml` overrides that value.

With `CMAKE_BUILD_DIR` empty, each `VCARCH` and `CMAKE_BUILD_TYPE` combination has its own build directory, so switching back to a combination reuses its earlier build. Relative paths in `CMAKE_BUILD_DIR` and `CMAKE_INSTALL_PREFIX` start at the project root.

| Setting | Default | Meaning |
| --- | --- | --- |
| `VCARCH` | `x64` | Target architecture: `x64` or `x86` |
| `CMAKE_BUILD_TYPE` | `Release` | Build type: `Debug`, `Release`, `RelWithDebInfo`, or `MinSizeRel` |
| `CMAKE_BUILD_DIR` | empty | Directory the tasks pass to `cmake -B`. Empty means `build/<VCARCH>-<CMAKE_BUILD_TYPE>`. |
| `CMAKE_INSTALL_PREFIX` | empty | Directory `mise run install` writes to. Empty means `<CMAKE_BUILD_DIR>/install`. |
| `CMAKE_POLICY_VERSION_MINIMUM` | `3.5` | Lets CMake 4 configure projects and bundled libraries that declare `cmake_minimum_required` below 3.5 |

## Limitations

- The `configure`, `build`, `install` and `shell` tasks replace tasks with the same names in the project's `mise.toml`.
- pwsh splits an unquoted argument such as `-DNAME=1.5` at the dot. Quote `-D` arguments: `mise run configure -- "-DNAME=1.5"`.
- After a `CMAKE_INSTALL_PREFIX` change, some projects install to the old directory until you run `mise run configure -- --fresh`.
- With several Visual Studio installations, the template uses the newest installation with the MSVC x64/x86 build tools.

## Tests

`tests/test.ps1` builds `tests/fixture` with the template and checks that:

- an x64 build receives a configure argument with spaces and a dot
- `mise run install` writes into `<CMAKE_BUILD_DIR>/install`
- `mise set -E local VCARCH=x86` switches the build to x86
- `VCARCH` in `mise.local.toml` overrides the template used as `mise.toml`

Run it from the repository root on Windows:

```pwsh
pwsh -NoProfile -File cmake-windows-msvc/tests/test.ps1
```

When cmake or ninja is missing, the script installs it only from the URL and sha256 checksum in `tests/mise.lock`. GitHub Actions runs it on `windows-2025` when files under `cmake-windows-msvc/` change, and weekly.

## Updating cmake or ninja

1. Change the version in `[tools]`.
2. Regenerate `tests/mise.lock`:

   ```pwsh
   pwsh -NoProfile -File cmake-windows-msvc/tests/update-lockfile.ps1
   ```

3. Run the tests.
