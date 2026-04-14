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

Require-Command cmake
Require-Command git
Require-Command ninja

if (-not (Test-Path -LiteralPath $Repo -PathType Container)) {
    throw "Windows repo path does not exist: $Repo"
}

Set-Location -LiteralPath $Repo

if ($Sync -eq "pull") {
    git pull --ff-only
}

cmake --preset $Preset
cmake --build --preset $Preset --target $Target

if ($RunTests) {
    ctest --test-dir "build/$Preset" --output-on-failure
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
