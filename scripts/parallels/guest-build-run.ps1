$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir "../impl/parallels/guest-build-run.ps1") @args
