# mise-templates

mise configurations for building third-party projects. Each template is a directory with a `mise.toml` and a README. Copy the `mise.toml` into a project as:

- `mise.local.toml` to build a third-party project
- `mise.toml` to start a project of your own

## Templates

| Template | Builds |
| --- | --- |
| [`cmake-windows-msvc`](cmake-windows-msvc) | CMake projects on Windows with Ninja and MSVC (the Visual Studio C++ compiler), for x64 or x86 |

## Tests

- Each template's tests are in `<template>/tests/`.
- `.github/workflows/<template>.yml` runs them on the template's platform.
- Tools and actions are pinned to exact versions or commit SHAs.
- Workflows run on a named runner image such as `windows-2025`. GitHub updates that image's contents weekly.
