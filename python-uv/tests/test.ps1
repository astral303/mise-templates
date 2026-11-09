#Requires -Version 7.4
# Sets up tests/fixture with the template and checks the .venv that uv and mise produce.
$ErrorActionPreference = "Stop"

$templatePath = Join-Path $PSScriptRoot "../mise.toml"
$lockfilePath = Join-Path $PSScriptRoot "mise.lock"
$fixturePath = Join-Path $PSScriptRoot "fixture"
$workRoot = Join-Path ([IO.Path]::GetTempPath()) "python-uv-tests-$([guid]::NewGuid().ToString('N'))"
$pinnedPythonVersion = [regex]::Match((Get-Content -Raw $templatePath), '(?m)^python = "([^"]+)"').Groups[1].Value
if (-not $pinnedPythonVersion) {
    throw "The template's [tools] has no python = `"<version>`" line."
}

# Trust only the projects this script creates. Install Python and uv only from the URLs and
# sha256 checksums in tests/mise.lock. Keep uv from downloading a Python of its own, so a
# project that bypasses the pinned Python fails instead of quietly using another one.
$env:MISE_TRUSTED_CONFIG_PATHS = $workRoot
$env:MISE_LOCKED = "1"
$env:UV_PYTHON_DOWNLOADS = "never"

function New-FixtureProject {
    param([string] $Name)

    $projectPath = Join-Path $workRoot $Name
    Copy-Item -LiteralPath $fixturePath -Destination $projectPath -Recurse
    Copy-Item -LiteralPath $templatePath -Destination (Join-Path $projectPath "mise.local.toml")
    Copy-Item -LiteralPath $lockfilePath -Destination (Join-Path $projectPath "mise.local.lock")
    $projectPath
}

function Invoke-Mise {
    param([string] $ProjectPath, [string[]] $Arguments)

    $output = & mise -C $ProjectPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "mise $($Arguments -join ' ') exited with $($LASTEXITCODE):`n$($output -join "`n")"
    }
    $output
}

function Assert-ActivatedVenv {
    param([string] $ProjectPath)

    # Compare real paths: on macOS the temporary directory is reached through a /var symlink.
    $script = 'import os, sys; print(os.path.samefile(sys.prefix, sys.argv[1])); print(sys.version.split()[0])'
    $output = Invoke-Mise $ProjectPath @("exec", "--", "python", "-c", $script, (Join-Path $ProjectPath ".venv"))
    $isProjectVenv, $version = ($output | Select-Object -Last 2)
    if ($isProjectVenv -ne "True") {
        throw "python on PATH does not run from $ProjectPath/.venv:`n$($output -join "`n")"
    }
    if ($version -ne $pinnedPythonVersion) {
        throw "The .venv runs Python $version, not the pinned $pinnedPythonVersion."
    }
}

$testCases = [ordered]@{
    "uv sync builds .venv on the pinned Python, and mise activates it" = {
        $projectPath = New-FixtureProject "sync"
        Invoke-Mise $projectPath @("exec", "--", "uv", "sync") | Out-Null
        Assert-ActivatedVenv $projectPath
    }
    "uv run reuses the .venv from uv sync" = {
        $projectPath = New-FixtureProject "rerun"
        Invoke-Mise $projectPath @("exec", "--", "uv", "sync") | Out-Null
        $markerPath = Join-Path $projectPath ".venv/marker"
        Set-Content -LiteralPath $markerPath -Value "uv sync built this .venv"
        foreach ($run in 1, 2) {
            Invoke-Mise $projectPath @("exec", "--", "uv", "run", "python", "-c", "pass") | Out-Null
            if (-not (Test-Path -LiteralPath $markerPath)) {
                throw "uv run #$run rebuilt .venv."
            }
        }
    }
    "mise env succeeds before the pinned Python is installed" = {
        $projectPath = New-FixtureProject "uninstalled-python"
        $configPath = Join-Path $projectPath "mise.local.toml"
        # Pin a Python version mise does not have: tools.python stays undefined.
        $config = (Get-Content -Raw -LiteralPath $configPath) -replace '(?m)^python = "[^"]+"', 'python = "3.11.99"'
        Set-Content -LiteralPath $configPath -Value $config -NoNewline
        $output = & mise -C $projectPath env 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "mise env exited with $($LASTEXITCODE):`n$($output -join "`n")"
        }
    }
    "UV_PYTHON overrides the project's .python-version" = {
        $projectPath = New-FixtureProject "python-version"
        Set-Content -LiteralPath (Join-Path $projectPath ".python-version") -Value "3.13"
        Invoke-Mise $projectPath @("exec", "--", "uv", "sync") | Out-Null
        Assert-ActivatedVenv $projectPath
    }
    "mise exec -- uv add installs the package into .venv" = {
        $projectPath = New-FixtureProject "add"
        Invoke-Mise $projectPath @("exec", "--", "uv", "add", "iniconfig==2.1.0") | Out-Null
        $script = 'import iniconfig, os, sys; print(os.path.commonpath([os.path.realpath(iniconfig.__file__), os.path.realpath(sys.prefix)]) == os.path.realpath(sys.prefix))'
        $isInVenv = Invoke-Mise $projectPath @("exec", "--", "python", "-c", $script) | Select-Object -Last 1
        if ($isInVenv -ne "True") {
            throw "iniconfig was not installed into $projectPath/.venv."
        }
        Assert-ActivatedVenv $projectPath
    }
}

New-Item -ItemType Directory -Path $workRoot | Out-Null
$failedCount = 0
foreach ($testCase in $testCases.GetEnumerator()) {
    try {
        & $testCase.Value
        Write-Output "PASS  $($testCase.Key)"
    } catch {
        $failedCount++
        Write-Output "FAIL  $($testCase.Key)"
        Write-Output $_.Exception.Message
    }
}

if ($failedCount -gt 0) {
    Write-Output "$failedCount of $($testCases.Count) cases failed. Projects kept in $workRoot"
    exit 1
}
Remove-Item -LiteralPath $workRoot -Recurse -Force
Write-Output "All $($testCases.Count) cases passed."
