$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$godot = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$releaseDir = Join-Path $projectRoot 'release\windows'
$outputDir = Join-Path $projectRoot 'output'
$game = Join-Path $releaseDir '人才公园餐馆试玩.exe'
$exportLog = Join-Path $outputDir 'talent_park_export.log'
$smokeLog = Join-Path $outputDir 'export_route_smoke.log'
$smokeErrorLog = Join-Path $outputDir 'export_route_smoke_errors.log'
$smokeAppData = Join-Path $outputDir 'export_smoke_appdata'

if (-not (Test-Path -LiteralPath $godot)) {
    throw "找不到 Godot：$godot"
}
New-Item -ItemType Directory -Path $releaseDir, $outputDir, $smokeAppData -Force | Out-Null

$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & $godot --headless --path $projectRoot --export-release 'Windows Desktop' $game *> $exportLog
    $exportStatus = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorAction
}
if ($exportStatus -ne 0 -or -not (Test-Path -LiteralPath $game)) {
    throw "人才公园试玩导出失败，请查看 $exportLog"
}

$originalAppData = $env:APPDATA
try {
    $env:APPDATA = $smokeAppData
    $smoke = Start-Process -FilePath $game -ArgumentList @('--headless', '--', '--entry-route-test') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $smokeLog -RedirectStandardError $smokeErrorLog
    if ($smoke.ExitCode -ne 0 -or -not (Select-String -Path $smokeLog -Pattern 'ENTRY_ROUTE_TEST_PASS' -Quiet)) {
        throw "试玩入口检查失败，请查看 $smokeLog"
    }
} finally {
    $ErrorActionPreference = $previousErrorAction
    $env:APPDATA = $originalAppData
}

Write-Output "已生成：$game"
