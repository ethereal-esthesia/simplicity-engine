param(
    [string]$Repo = "C:\Users\shane\Project\simplicity-engine",
    [string]$Preset = "debug",
    [string]$Target = "hello_pixel",
    [ValidateSet("none", "pull")]
    [string]$Sync = "none",
    [switch]$RunTests,
    [switch]$Launch
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\install-hints.ps1"

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw (Get-ParallelsInstallHint -Platform "windows" -Command $Name -RerunHint "rerun the Windows build")
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "${Command} failed with exit code ${LASTEXITCODE}"
    }
}

function Import-VsDevEnvironment {
    if (Get-Command cl -ErrorAction SilentlyContinue) {
        return
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        return
    }

    $installPath = (& $vswhere -latest -products "*" -property installationPath | Select-Object -First 1)
    if (-not $installPath) {
        return
    }

    $vsDevCmd = Join-Path $installPath "Common7\Tools\VsDevCmd.bat"
    if (-not (Test-Path -LiteralPath $vsDevCmd -PathType Leaf)) {
        return
    }

    $architectures = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        @(
            @{ TargetArch = "arm64"; HostArch = "arm64" },
            @{ TargetArch = "x64"; HostArch = "x64" },
            @{ TargetArch = "x64"; HostArch = "arm64" }
        )
    } else {
        @(
            @{ TargetArch = "amd64"; HostArch = "amd64" },
            @{ TargetArch = "x64"; HostArch = "x64" }
        )
    }

    $environment = $null
    foreach ($architecture in $architectures) {
        $environment = cmd.exe /s /c "`"$vsDevCmd`" -arch=$($architecture["TargetArch"]) -host_arch=$($architecture["HostArch"]) >nul && set"
        if ($LASTEXITCODE -ne 0) {
            $environment = $null
            continue
        }

        foreach ($line in $environment) {
            if ($line -match "^([^=]+)=(.*)$") {
                [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process")
            }
        }

        if (Get-Command cl -ErrorAction SilentlyContinue) {
            return
        }

        $environment = $null
    }

    if (-not $environment) {
        return
    }
}

Require-Command cmake
Require-Command git
Require-Command ninja
Import-VsDevEnvironment
Require-Command cl

if (-not (Test-Path -LiteralPath $Repo -PathType Container)) {
    throw "Windows repo path does not exist: $Repo"
}

Set-Location -LiteralPath $Repo

if ($Sync -eq "pull") {
    Invoke-Checked git pull --ff-only
}

Invoke-Checked cmake --preset $Preset
Invoke-Checked cmake --build --preset $Preset --target $Target

if ($RunTests) {
    Invoke-Checked ctest --test-dir "build/$Preset" --output-on-failure
}

if ($Launch) {
    $candidatePaths = @(
        "build/$Preset/$Target.exe",
        "build/$Preset/Debug/$Target.exe",
        "build/$Preset/Release/$Target.exe",
        "build/$Preset/RelWithDebInfo/$Target.exe"
    )

    $executable = $candidatePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $executable) {
        throw "Built executable not found for target '$Target' under build/$Preset"
    }

    Start-Process -FilePath (Resolve-Path -LiteralPath $executable).Path -WorkingDirectory (Split-Path -Parent (Resolve-Path -LiteralPath $executable).Path)
}
