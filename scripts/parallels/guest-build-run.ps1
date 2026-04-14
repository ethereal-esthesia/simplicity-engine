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
$script:VsDevEnvironmentAttempts = @()
$script:InstalledMsvcCompilers = @()

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

function Test-ClTargetsArm64 {
    $clPath = (Get-Command cl -ErrorAction SilentlyContinue).Source
    return ($clPath -and ($clPath -match "\\bin\\Host[^\\]+\\arm64\\cl\.exe$"))
}

function Get-ClArchitecture {
    param([string]$Path)

    if ($Path -match "\\bin\\Host([^\\]+)\\([^\\]+)\\cl\.exe$") {
        return [pscustomobject]@{
            Host = $Matches[1].ToLowerInvariant()
            Target = $Matches[2].ToLowerInvariant()
        }
    }

    return $null
}

function Add-VsDevEnvironmentAttempt {
    param(
        [hashtable]$Architecture,
        [string]$ClPath,
        [string]$Status
    )

    $clArchitecture = $null
    if ($ClPath) {
        $clArchitecture = Get-ClArchitecture $ClPath
    }

    $script:VsDevEnvironmentAttempts += [pscustomobject]@{
        RequestedHost = $Architecture["HostArch"]
        RequestedTarget = $Architecture["TargetArch"]
        CompilerHost = if ($clArchitecture) { $clArchitecture.Host } else { $null }
        CompilerTarget = if ($clArchitecture) { $clArchitecture.Target } else { $null }
        ClPath = $ClPath
        Status = $Status
    }
}

function Format-VsDevEnvironmentAttempts {
    if (-not $script:VsDevEnvironmentAttempts) {
        return ""
    }

    $attempts = foreach ($attempt in $script:VsDevEnvironmentAttempts) {
        if ($attempt.ClPath) {
            "requested host=$($attempt.RequestedHost) target=$($attempt.RequestedTarget) -> compiler host=$($attempt.CompilerHost) target=$($attempt.CompilerTarget): $($attempt.ClPath)"
        } else {
            "requested host=$($attempt.RequestedHost) target=$($attempt.RequestedTarget) -> $($attempt.Status)"
        }
    }

    return " Tried Visual Studio environments: $($attempts -join '; ')."
}

function Get-InstalledMsvcCompilers {
    param([string]$InstallPath)

    $compilerRoot = Join-Path $InstallPath "VC\Tools\MSVC"
    if (-not (Test-Path -LiteralPath $compilerRoot -PathType Container)) {
        return @()
    }

    $compilerPaths = Get-ChildItem -Path (Join-Path $compilerRoot "*\bin\Host*\*\cl.exe") -ErrorAction SilentlyContinue
    foreach ($compilerPath in $compilerPaths) {
        $architecture = Get-ClArchitecture $compilerPath.FullName
        if (-not $architecture) {
            continue
        }

        [pscustomobject]@{
            Host = $architecture.Host
            Target = $architecture.Target
            Path = $compilerPath.FullName
        }
    }
}

function Format-InstalledMsvcCompilers {
    if (-not $script:InstalledMsvcCompilers) {
        return ""
    }

    $descriptions = $script:InstalledMsvcCompilers |
        ForEach-Object { "host=$($_.Host) target=$($_.Target)" } |
        Sort-Object -Unique

    return " Installed MSVC compiler targets: $($descriptions -join '; ')."
}

function ConvertTo-EnvironmentMap {
    param([string[]]$Environment)

    $map = @{}
    foreach ($line in $Environment) {
        if ($line -match "^([^=]+)=(.*)$") {
            $map[$Matches[1]] = $Matches[2]
        }
    }
    return $map
}

function Get-ClFromPath {
    param([string]$PathValue)

    foreach ($pathEntry in ($PathValue -split ";")) {
        if (-not $pathEntry) {
            continue
        }

        $candidate = Join-Path $pathEntry "cl.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}

function Import-EnvironmentMap {
    param([hashtable]$Environment)

    foreach ($entry in $Environment.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, "Process")
    }
}

function Import-VsDevEnvironment {
    if (($env:PROCESSOR_ARCHITECTURE -ne "ARM64") -and (Get-Command cl -ErrorAction SilentlyContinue)) {
        return
    }

    if (($env:PROCESSOR_ARCHITECTURE -eq "ARM64") -and (Test-ClTargetsArm64)) {
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
    $script:InstalledMsvcCompilers = @(Get-InstalledMsvcCompilers $installPath)

    $vsDevCmd = Join-Path $installPath "Common7\Tools\VsDevCmd.bat"
    if (-not (Test-Path -LiteralPath $vsDevCmd -PathType Leaf)) {
        return
    }

    $architectures = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        @(
            @{ TargetArch = "arm64"; HostArch = "arm64" },
            @{ TargetArch = "arm64"; HostArch = "x64" },
            @{ TargetArch = "arm64"; HostArch = "amd64" }
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
            Add-VsDevEnvironmentAttempt $architecture $null "VsDevCmd failed"
            $environment = $null
            continue
        }

        $environmentMap = ConvertTo-EnvironmentMap $environment
        $pathValue = $environmentMap["Path"]
        if (-not $pathValue) {
            $pathValue = $environmentMap["PATH"]
        }
        $clPath = Get-ClFromPath $pathValue
        Add-VsDevEnvironmentAttempt $architecture $clPath "no cl.exe on PATH"

        if (($env:PROCESSOR_ARCHITECTURE -eq "ARM64") -and ($clPath -match "\\bin\\Host[^\\]+\\arm64\\cl\.exe$")) {
            Import-EnvironmentMap $environmentMap
            return
        }

        if (($env:PROCESSOR_ARCHITECTURE -ne "ARM64") -and $clPath) {
            Import-EnvironmentMap $environmentMap
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

if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
    $clPath = (Get-Command cl -ErrorAction SilentlyContinue).Source
    if ($clPath -and (-not (Test-ClTargetsArm64))) {
        $clArchitecture = Get-ClArchitecture $clPath
        $architectureDescription = if ($clArchitecture) { "compiler host=$($clArchitecture.Host) target=$($clArchitecture.Target)" } else { "unknown compiler host/target" }
        throw "MSVC was found, but it is not targeting ARM64 ($architectureDescription): $clPath. Install the Visual Studio Build Tools ARM64 C++ tools, then rerun the Windows build. See README.md for installation details.$(Format-VsDevEnvironmentAttempts)$(Format-InstalledMsvcCompilers)"
    }
    if (-not $clPath) {
        throw "MSVC ARM64 target tools were not found. Install the Visual Studio Build Tools ARM64 C++ tools, then rerun the Windows build. See README.md for installation details.$(Format-VsDevEnvironmentAttempts)$(Format-InstalledMsvcCompilers)"
    }
} else {
    Require-Command cl
}

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
