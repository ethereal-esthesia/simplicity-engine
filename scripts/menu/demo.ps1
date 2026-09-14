param([ValidateSet('build','test','run')][string]$Action = 'test')
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path "$PSScriptRoot\..\..").Path
& "$PSScriptRoot\..\impl\dev_setup\windows.ps1"
$Build = Join-Path $Root 'build\menu-windows'
cmake -S $Root -B $Build -G Ninja -DCMAKE_BUILD_TYPE=Debug
if ($LASTEXITCODE -ne 0) { throw 'Configure failed. Use a Visual Studio developer shell.' }
cmake --build $Build --parallel 4
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
if ($Action -eq 'test') {
    ctest --test-dir $Build --output-on-failure
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    & "$Build\test_menu.exe" --native
    if ($LASTEXITCODE -ne 0) { throw 'Native menu test failed.' }
} elseif ($Action -eq 'run') { & "$Build\menu_demo.exe" }
