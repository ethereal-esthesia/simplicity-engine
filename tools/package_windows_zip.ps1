param(
    [string]$ArchLabel = "x64"
)

$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RootDir

New-Item -ItemType Directory -Force -Path "dist" | Out-Null

cmake --preset release
cmake --build --preset release

$stageDir = Join-Path "dist" "simplicity-engine-windows-$ArchLabel"
if (Test-Path $stageDir) {
    Remove-Item -Recurse -Force $stageDir
}
New-Item -ItemType Directory -Path $stageDir | Out-Null

Copy-Item "build/release/hello_pixel.exe" (Join-Path $stageDir "hello_pixel.exe")

$zipPath = Join-Path "dist" "simplicity-engine-windows-$ArchLabel.zip"
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

Compress-Archive -Path (Join-Path $stageDir "*") -DestinationPath $zipPath
Write-Host "Created $zipPath"
