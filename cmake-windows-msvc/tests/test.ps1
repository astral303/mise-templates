#Requires -Version 7.4
# Builds tests/fixture with the template and checks the binaries it produces.
$ErrorActionPreference = "Stop"

if (-not $IsWindows) {
    throw "The cmake-windows-msvc tests need Windows with Visual Studio's MSVC build tools."
}

$templatePath = Join-Path $PSScriptRoot "../mise.toml"
$lockfilePath = Join-Path $PSScriptRoot "mise.lock"
$fixturePath = Join-Path $PSScriptRoot "fixture"
$workRoot = Join-Path ([IO.Path]::GetTempPath()) "cmake-windows-msvc-tests-$([guid]::NewGuid().ToString('N'))"
$peMachineTypes = @{ x64 = 0x8664; x86 = 0x014C }

# Trust only the projects this script creates. Install cmake and ninja only from the URLs and
# sha256 checksums in tests/mise.lock.
$env:MISE_TRUSTED_CONFIG_PATHS = $workRoot
$env:MISE_LOCKED = "1"

function New-FixtureProject {
    param([string] $Name, [string] $TemplateFileName)

    $projectPath = Join-Path $workRoot $Name
    Copy-Item -LiteralPath $fixturePath -Destination $projectPath -Recurse
    Copy-Item -LiteralPath $templatePath -Destination (Join-Path $projectPath $TemplateFileName)
    # mise reads mise.lock for mise.toml and mise.local.lock for mise.local.toml.
    $lockfileName = [IO.Path]::ChangeExtension($TemplateFileName, ".lock")
    Copy-Item -LiteralPath $lockfilePath -Destination (Join-Path $projectPath $lockfileName)
    $projectPath
}

function Invoke-Mise {
    param([string] $ProjectPath, [string[]] $Arguments)

    $output = & mise -C $ProjectPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "mise $($Arguments -join ' ') exited with $($LASTEXITCODE):`n$($output -join "`n")"
    }
}

function Get-MiseFailureOutput {
    param([string] $ProjectPath, [string[]] $Arguments)

    $output = & mise -C $ProjectPath @Arguments 2>&1
    if ($LASTEXITCODE -eq 0) {
        throw "mise $($Arguments -join ' ') succeeded; the case expects it to fail."
    }
    $output -join "`n"
}

function Assert-PeMachineType {
    param([string] $ExecutablePath, [string] $Architecture)

    if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
        throw "$ExecutablePath was not built."
    }
    $bytes = [IO.File]::ReadAllBytes($ExecutablePath)
    $peHeaderOffset = [BitConverter]::ToInt32($bytes, 0x3C)
    $machineType = [BitConverter]::ToUInt16($bytes, $peHeaderOffset + 4)
    $expectedMachineType = $peMachineTypes[$Architecture]
    if ($machineType -ne $expectedMachineType) {
        throw ("{0} has PE machine type 0x{1:X4}; {2} is 0x{3:X4}." -f
            $ExecutablePath, $machineType, $Architecture, $expectedMachineType)
    }
}

$testCases = [ordered]@{
    "x64 build receives a configure argument with spaces and a dot" = {
        $projectPath = New-FixtureProject "x64-argument" "mise.local.toml"
        Invoke-Mise $projectPath @("run", "configure", "--", "-DGREETING=hello world 1.5")
        Invoke-Mise $projectPath @("run", "build")
        $executablePath = Join-Path $projectPath "build/x64-Release/fixture.exe"
        Assert-PeMachineType $executablePath "x64"
        $greeting = & $executablePath
        if ($greeting -ne "hello world 1.5") {
            throw "fixture.exe printed '$greeting', not 'hello world 1.5'."
        }
    }
    "mise run install writes into CMAKE_BUILD_DIR/install" = {
        $projectPath = New-FixtureProject "install" "mise.local.toml"
        Invoke-Mise $projectPath @("run", "install")
        Assert-PeMachineType (Join-Path $projectPath "build/x64-Release/install/bin/fixture.exe") "x64"
    }
    "mise set -E local VCARCH=x86 switches the build to x86" = {
        $projectPath = New-FixtureProject "x86-set" "mise.local.toml"
        Invoke-Mise $projectPath @("set", "-E", "local", "VCARCH=x86")
        Invoke-Mise $projectPath @("run", "build")
        Assert-PeMachineType (Join-Path $projectPath "build/x86-Release/fixture.exe") "x86"
    }
    "VCARCH in mise.local.toml overrides the template used as mise.toml" = {
        $projectPath = New-FixtureProject "x86-layered" "mise.toml"
        Set-Content -LiteralPath (Join-Path $projectPath "mise.local.toml") -Value "[env]`nVCARCH = `"x86`""
        Invoke-Mise $projectPath @("run", "build")
        Assert-PeMachineType (Join-Path $projectPath "build/x86-Release/fixture.exe") "x86"
    }
    "a failed configure reports cmake's exit code, not a PowerShell error" = {
        $projectPath = New-FixtureProject "failed-configure" "mise.local.toml"
        $output = Get-MiseFailureOutput $projectPath @("run", "configure", "--", "-DFIXTURE_FAIL_CONFIGURE=ON")
        if ($output -notmatch "cmake exited with code 1\.") {
            throw "The output does not report cmake's exit code:`n$output"
        }
        if ($output -match "NativeCommandExitException") {
            throw "The output shows a PowerShell error:`n$output"
        }
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
