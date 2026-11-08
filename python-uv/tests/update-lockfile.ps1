#Requires -Version 7.4
# Regenerates tests/mise.lock for the versions in the template's [tools], for every CI platform.
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Lock a copy outside the repository: the repository's .miserc.toml hides the template from mise.
$projectPath = Join-Path ([IO.Path]::GetTempPath()) "python-uv-lock-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $projectPath | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "../mise.toml") -Destination $projectPath
    $env:MISE_TRUSTED_CONFIG_PATHS = $projectPath
    mise -C $projectPath lock --platform windows-x64,linux-x64,macos-arm64
    Copy-Item -LiteralPath (Join-Path $projectPath "mise.lock") -Destination (Join-Path $PSScriptRoot "mise.lock") -Force
} finally {
    Remove-Item -LiteralPath $projectPath -Recurse -Force
}
