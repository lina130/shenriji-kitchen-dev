$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$version = "0.2.0"
$windowsDir = Join-Path $root "release\windows"
New-Item -ItemType Directory -Force -Path $windowsDir | Out-Null

$godot = Get-ChildItem -LiteralPath (Join-Path $root ".tools\godot") -Filter "Godot_v*-stable_win64_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $godot) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $command) { throw "未找到 Godot 4.2+，也无法使用项目便携版。" }
    $godotPath = $command.Source
} else {
    $godotPath = $godot.FullName
}

Get-ChildItem -LiteralPath (Join-Path $root "data") -Filter "*.csv" -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination ($_.FullName + ".txt") -Force
}

Write-Host "运行自动测试..."
& $godotPath --headless --path $root -- --smoke-test
if ($LASTEXITCODE -ne 0) { throw "自动测试失败，已停止打包。" }

Write-Host "运行 100 月经济压力测试..."
& $godotPath --headless --path $root -- --stress-test
if ($LASTEXITCODE -ne 0) { throw "经济压力测试失败，已停止打包。" }

Write-Host "运行真实窗口玩家操作测试..."
& $godotPath --path $root --resolution 1280x720 -- --playtest
if ($LASTEXITCODE -ne 0) { throw "真实窗口玩家操作测试失败，已停止打包。" }

Write-Host "导出 Windows 发布版..."
& $godotPath --headless --path $root --export-release "Windows Desktop" "release/windows/深城日常.exe"
if ($LASTEXITCODE -ne 0) { throw "Godot 导出失败。" }

$readme = @"
《深城日常》垂直切片 $version

运行：
双击“深城日常.exe”。

操作：
WASD / 方向键移动
鼠标右键与身边物件、人物互动
I 背包
C 旧物册
M 地图
B 生活账本
F5 保存
F9 读取
Esc 暂停或返回

说明：
本版本采用旧货行情、立即出售、柜台寄卖、摊位扩张和熟客口碑组成的长线经济循环，并开放四个旧址探索点。
背包、地图和账本打开时游戏时间仍会继续。
"@
Set-Content -LiteralPath (Join-Path $windowsDir "运行说明.txt") -Value $readme -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $root "docs\RELEASE_NOTES_0.2.0.md") -Destination (Join-Path $windowsDir "发行说明.md") -Force
Copy-Item -LiteralPath (Join-Path $root "docs\KNOWN_ISSUES.md") -Destination (Join-Path $windowsDir "已知问题.md") -Force
Copy-Item -LiteralPath (Join-Path $root "docs\游戏预览_0.2.0.png") -Destination (Join-Path $windowsDir "游戏预览.png") -Force

$exePath = Join-Path $windowsDir "深城日常.exe"
$hash = Get-FileHash -LiteralPath $exePath -Algorithm SHA256
$hashLine = "$($hash.Hash)  深城日常.exe"
Set-Content -LiteralPath (Join-Path $root "release\SHA256SUMS.txt") -Value $hashLine -Encoding utf8

$zipPath = Join-Path $root "release\深城日常_${version}_win64.zip"
$releaseFiles = @(
    (Join-Path $windowsDir "深城日常.exe"),
    (Join-Path $windowsDir "运行说明.txt"),
    (Join-Path $windowsDir "发行说明.md"),
    (Join-Path $windowsDir "已知问题.md"),
    (Join-Path $windowsDir "游戏预览.png")
)
Compress-Archive -Path $releaseFiles -DestinationPath $zipPath -Force
$zipHash = Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
Add-Content -LiteralPath (Join-Path $root "release\SHA256SUMS.txt") -Value "$($zipHash.Hash)  深城日常_${version}_win64.zip"
Write-Host "发布包完成：$zipPath"