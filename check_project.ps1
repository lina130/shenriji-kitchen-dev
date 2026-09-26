$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$godot = Get-ChildItem -LiteralPath (Join-Path $root ".tools\godot") -Filter "Godot_v*-stable_win64_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $godot) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $command) { throw "未找到 Godot。请安装 Godot 4.2+，或恢复 .tools/godot 中的便携版。" }
    $godotPath = $command.Source
} else {
    $godotPath = $godot.FullName
}
& $godotPath --headless --editor --path $root --quit
exit $LASTEXITCODE