param([switch]$Install)
$ErrorActionPreference = 'Stop'
if ($Install) {
    foreach ($package in @('Kitware.CMake', 'Ninja-build.Ninja')) {
        winget install --id $package -e --silent
        if ($LASTEXITCODE -ne 0) { Write-Warning "Check winget result for $package (may already be installed)." }
    }
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (!(Test-Path $vswhere) -or !(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)) {
        winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override '--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
        if ($LASTEXITCODE -ne 0) { throw 'C++ toolchain setup failed.' }
    }
}
foreach ($tool in @('cmake', 'ninja')) {
    if (!(Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool missing; run with -Install and reopen the developer shell." }
}
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (!(Get-Command cl -ErrorAction SilentlyContinue)) {
    if (!(Test-Path $vswhere)) { throw 'MSVC missing; run with -Install.' }
    $CompilerInstall = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (!$CompilerInstall) { throw 'Visual Studio C++ workload missing; run with -Install.' }
}
Write-Output 'Windows menu setup: ready; build in a Visual Studio developer shell.'
