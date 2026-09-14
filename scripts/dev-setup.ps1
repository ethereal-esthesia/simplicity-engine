param([ValidateSet('windows')][string]$Target = 'windows', [switch]$Check,
      [string]$Storage = "$PSScriptRoot\..\local\dev")
$ErrorActionPreference = 'Stop'
$Logging = $false
try {
    if (!$Check) {
        $Logs = Join-Path $Storage 'logs'
        New-Item -ItemType Directory -Force $Logs | Out-Null
        Start-Transcript -Path (Join-Path $Logs "$(Get-Date -Format yyyyMMdd-HHmmss)-windows.log") | Out-Null
        $Logging = $true
    }
    & "$PSScriptRoot\impl\dev_setup\windows.ps1" -Install:(!$Check)
    Write-Output 'PASSED: setup ready. Run scripts/menu/demo.ps1 -Action test in a Visual Studio developer shell.'
    exit 0
} catch {
    Write-Output "SETUP INCOMPLETE: $_"
    exit 3
} finally {
    if ($Logging) { Stop-Transcript | Out-Null }
}
