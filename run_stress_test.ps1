$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$godot = Get-ChildItem -LiteralPath (Join-Path $root ".tools\godot") -Filter "Godot_v*-stable_win64_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $godot) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $command) { throw "未找到 Godot 4.2+。" }
    $godotPath = $command.Source
} else {
    $godotPath = $godot.FullName
}
$testData = Join-Path $root ".tools\test_userdata"
New-Item -ItemType Directory -Force -Path $testData | Out-Null
& $godotPath --headless --path $root --user-data-dir $testData -- --stress-test
exit $LASTEXITCODE