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
$script:ImportedVsDevEnvironment = $false

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

function Normalize-MsvcArchitecture {
    param([string]$Architecture)

    if (-not $Architecture) {
        return $null
    }

    switch ($Architecture.ToLowerInvariant()) {
        "amd64" { return "x64" }
        default { return $Architecture.ToLowerInvariant() }
    }
}

function Get-DesiredMsvcTarget {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        "ARM64" { return "arm64" }
        "AMD64" { return "x64" }
        "x86" { return "x86" }
        default { return "x64" }
    }
}

function Get-ClReportedTarget {
    param([string[]]$Output)

    foreach ($line in $Output) {
        if ($line -match "Compiler Version .+ for ([A-Za-z0-9_]+)") {
            return Normalize-MsvcArchitecture $Matches[1]
        }
    }

    return $null
}

function Get-CurrentClReportedTarget {
    if (-not (Get-Command cl -ErrorAction SilentlyContinue)) {
        return $null
    }

    $output = & cl /Bv 2>&1
    return Get-ClReportedTarget $output
}

function Test-ClTargets {
    param([string]$Target)

    return ((Get-CurrentClReportedTarget) -eq (Normalize-MsvcArchitecture $Target))
}

function Add-VsDevEnvironmentAttempt {
    param(
        [hashtable]$Architecture,
        [string]$ClPath,
        [string]$ReportedTarget,
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
        ReportedTarget = $ReportedTarget
        ClPath = $ClPath
        Status = $Status
    }
}

function Format-VsDevEnvironmentAttempts {
    if (-not $script:VsDevEnvironmentAttempts) {
        return ""
    }

    $attempts = foreach ($attempt in $script:VsDevEnvironmentAttempts) {
        if ($attempt.ClPath -and $attempt.ReportedTarget) {
            "requested host=$($attempt.RequestedHost) target=$($attempt.RequestedTarget) -> cl reports target=$($attempt.ReportedTarget), path host=$($attempt.CompilerHost) target=$($attempt.CompilerTarget): $($attempt.ClPath)"
        } elseif ($attempt.ClPath) {
            "requested host=$($attempt.RequestedHost) target=$($attempt.RequestedTarget) -> $($attempt.Status), path host=$($attempt.CompilerHost) target=$($attempt.CompilerTarget): $($attempt.ClPath)"
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

function Invoke-VsDevClProbe {
    param(
        [string]$VsDevCmd,
        [hashtable]$Architecture
    )

    $output = cmd.exe /s /c "call `"$VsDevCmd`" -arch=$($Architecture["TargetArch"]) -host_arch=$($Architecture["HostArch"]) >nul && cl /Bv 2>&1"
    return Get-ClReportedTarget $output
}

function Import-EnvironmentMap {
    param([hashtable]$Environment)

    foreach ($entry in $Environment.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, "Process")
    }
}

function Import-VsDevEnvironment {
    $targetArch = Get-DesiredMsvcTarget
    if ((Get-Command cl -ErrorAction SilentlyContinue) -and (Test-ClTargets $targetArch)) {
        return
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        return
    }

    $requiredComponent = if ($targetArch -eq "arm64") {
        "Microsoft.VisualStudio.Component.VC.Tools.ARM64"
    } else {
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
    }

    $installPath = (& $vswhere -latest -products "*" -requires $requiredComponent -property installationPath | Select-Object -First 1)
    if (-not $installPath) {
        $fallbackInstallPath = (& $vswhere -latest -products "*" -property installationPath | Select-Object -First 1)
        if ($fallbackInstallPath) {
            $script:InstalledMsvcCompilers = @(Get-InstalledMsvcCompilers $fallbackInstallPath)
        }
        return
    }
    $script:InstalledMsvcCompilers = @(Get-InstalledMsvcCompilers $installPath)

    $vsDevCmd = Join-Path $installPath "Common7\Tools\VsDevCmd.bat"
    if (-not (Test-Path -LiteralPath $vsDevCmd -PathType Leaf)) {
        return
    }

    $hostArchitectures = if ($targetArch -eq "arm64") {
        @(
            "arm64",
            "x64",
            "amd64"
        )
    } elseif ($targetArch -eq "x86") {
        @(
            "x86",
            "x64",
            "amd64"
        )
    } else {
        @(
            "x64",
            "amd64"
        )
    }

    $environment = $null
    foreach ($hostArch in $hostArchitectures) {
        $architecture = @{ TargetArch = $targetArch; HostArch = $hostArch }
        $environment = cmd.exe /s /c "call `"$vsDevCmd`" -arch=$($architecture["TargetArch"]) -host_arch=$($architecture["HostArch"]) >nul && set"
        if ($LASTEXITCODE -ne 0) {
            Add-VsDevEnvironmentAttempt $architecture $null $null "VsDevCmd failed"
            $environment = $null
            continue
        }

        $environmentMap = ConvertTo-EnvironmentMap $environment
        $pathValue = $environmentMap["Path"]
        if (-not $pathValue) {
            $pathValue = $environmentMap["PATH"]
        }
        $clPath = Get-ClFromPath $pathValue
        $reportedTarget = Invoke-VsDevClProbe $vsDevCmd $architecture
        Add-VsDevEnvironmentAttempt $architecture $clPath $reportedTarget "cl.exe did not report a target"

        if ($reportedTarget -eq $targetArch) {
            Import-EnvironmentMap $environmentMap
            $script:ImportedVsDevEnvironment = $true
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

$targetArch = Get-DesiredMsvcTarget
$clPath = (Get-Command cl -ErrorAction SilentlyContinue).Source
if ($script:VsDevEnvironmentAttempts -and -not $script:ImportedVsDevEnvironment) {
    throw "MSVC ${targetArch} target tools were not found. Install Visual Studio Build Tools with the C++ workload, then rerun the Windows build. See README.md for installation details.$(Format-VsDevEnvironmentAttempts)$(Format-InstalledMsvcCompilers)"
}

if ($clPath -and $script:ImportedVsDevEnvironment) {
    $reportedTarget = Get-CurrentClReportedTarget
    if ($reportedTarget -ne $targetArch) {
        $clArchitecture = Get-ClArchitecture $clPath
        $architectureDescription = if ($clArchitecture) { "path host=$($clArchitecture.Host) target=$($clArchitecture.Target)" } else { "unknown compiler path host/target" }
        throw "MSVC was found, but cl reports target=${reportedTarget}; expected target=${targetArch} ($architectureDescription): $clPath. Install Visual Studio Build Tools with the needed C++ target tools, then rerun the Windows build. See README.md for installation details.$(Format-VsDevEnvironmentAttempts)$(Format-InstalledMsvcCompilers)"
    }
}

if ($clPath -and -not $script:ImportedVsDevEnvironment -and $script:InstalledMsvcCompilers) {
    $reportedTarget = Get-CurrentClReportedTarget
    $clArchitecture = Get-ClArchitecture $clPath
    $architectureDescription = if ($clArchitecture) { "path host=$($clArchitecture.Host) target=$($clArchitecture.Target)" } else { "unknown compiler path host/target" }
    Write-Warning "Using existing compiler environment; cl reports target=${reportedTarget}, expected target=${targetArch} ($architectureDescription): $clPath."
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
