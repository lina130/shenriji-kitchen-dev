param(
    [ValidateSet("auto", "release")]
    [string]$Mode = "auto",
    [string]$Base = "",
    [switch]$Local,
    [switch]$IncludeUntracked,
    [string[]]$ChangedFiles = @(),
    [string]$GodotPath = "",
    [string]$Python = "",
    [switch]$DryRun,
    [string]$PlanPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    throw "无法确定脚本目录。请从项目内运行 tools/run_selected_tests.ps1。"
}

$root = Split-Path -Parent $PSScriptRoot
$toolsDir = Join-Path $root "tools"
$selectorPath = Join-Path $toolsDir "select_tests.py"
$mapPath = Join-Path $toolsDir "test_map.json"

if (-not (Test-Path -LiteralPath $selectorPath)) {
    throw "缺少测试选择器: $selectorPath"
}
if (-not (Test-Path -LiteralPath $mapPath)) {
    throw "缺少测试映射: $mapPath"
}

function Resolve-PythonCommand {
    if (-not [string]::IsNullOrWhiteSpace($Python)) {
        if (-not (Test-Path -LiteralPath $Python)) {
            throw "指定的 Python 不存在: $Python"
        }
        return @((Resolve-Path -LiteralPath $Python).Path)
    }

    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $pythonCommand) {
        return @($pythonCommand.Source)
    }

    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $pyLauncher) {
        return @($pyLauncher.Source, "-3")
    }

    throw "未找到 Python 3。请安装 Python 3 或使用 -Python 指定解释器。"
}

function Resolve-PortableGodot {
    if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
        if (-not (Test-Path -LiteralPath $GodotPath)) {
            throw "指定的 Godot 不存在: $GodotPath"
        }
        return (Resolve-Path -LiteralPath $GodotPath).Path
    }

    $portableDir = Join-Path $root ".tools\godot"
    if (-not (Test-Path -LiteralPath $portableDir)) {
        throw "缺少项目便携引擎目录: $portableDir"
    }

    $portable = Get-ChildItem -LiteralPath $portableDir -Filter "Godot_v*-stable_win64_console.exe" -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($null -eq $portable) {
        throw "未在项目便携目录找到 Godot_v*-stable_win64_console.exe: $portableDir"
    }
    return $portable.FullName
}

$pythonCommand = @(Resolve-PythonCommand)
$pythonExe = [string]$pythonCommand[0]
$pythonPrefix = @()
if ($pythonCommand.Count -gt 1) {
    $pythonPrefix = @($pythonCommand[1..($pythonCommand.Count - 1)])
}

$selectorArgs = @($selectorPath, "--root", $root, "--mode", $Mode, "--json")
if ($ChangedFiles.Count -gt 0) {
    $selectorArgs += "--files"
    $selectorArgs += @($ChangedFiles)
}
elseif (-not [string]::IsNullOrWhiteSpace($Base)) {
    $selectorArgs += @("--base", $Base)
    if ($IncludeUntracked) {
        $selectorArgs += "--include-untracked"
    }
}
else {
    $selectorArgs += "--local"
}

$selectorAllArgs = @($pythonPrefix + $selectorArgs)
$selectorOutput = & $pythonExe @selectorAllArgs
if ($LASTEXITCODE -ne 0) {
    throw "测试选择器失败，退出码 $LASTEXITCODE。"
}

try {
    $plan = $selectorOutput | ConvertFrom-Json
}
catch {
    throw "测试选择器没有返回合法 JSON: $($_.Exception.Message)"
}
if ($null -ne $plan.error) {
    throw "测试选择器错误: $($plan.error)"
}

if ([string]::IsNullOrWhiteSpace($PlanPath)) {
    $PlanPath = Join-Path $root ".tools\test_userdata\test_plan.json"
}
elseif (-not [System.IO.Path]::IsPathRooted($PlanPath)) {
    $PlanPath = Join-Path $root $PlanPath
}
$planDirectory = Split-Path -Parent $PlanPath
New-Item -ItemType Directory -Force -Path $planDirectory | Out-Null
$plan | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $PlanPath -Encoding UTF8

Write-Host "测试模式: $Mode" -ForegroundColor Cyan
Write-Host "测试计划: $PlanPath"
Write-Host "选中门禁: $((@($plan.gates) -join ', '))" -ForegroundColor Yellow
Write-Host "选择原因: $($plan.reason)"

if ($DryRun) {
    Write-Host "DRY_RUN_OK" -ForegroundColor Green
    exit 0
}

$godotExe = Resolve-PortableGodot

$compileUserData = Join-Path $root (".tools\test_userdata\compile-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $compileUserData | Out-Null
Write-Host "编译检查: --headless --editor --quit" -ForegroundColor Cyan
& $godotExe --headless --editor --path $root --user-data-dir $compileUserData --quit
$compileCode = $LASTEXITCODE
if ($compileCode -ne 0) {
    throw "编译检查失败，已停止，不运行任何门禁。退出码 $compileCode"
}

$map = Get-Content -LiteralPath $mapPath -Raw | ConvertFrom-Json
foreach ($gate in @($plan.gates)) {
    if ([string]::IsNullOrWhiteSpace([string]$gate)) {
        continue
    }

    $gateProperty = $map.gates.PSObject.Properties[[string]$gate]
    if ($null -eq $gateProperty) {
        throw "test_map.json 未定义门禁: $gate"
    }
    $gateConfig = $gateProperty.Value

    $gateUserData = Join-Path $root (".tools\test_userdata\" + [string]$gate + "-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $gateUserData | Out-Null

    $godotArgs = @()
    if ([bool]$gateConfig.headless) {
        $godotArgs += "--headless"
    }
    $godotArgs += @("--path", $root, "--user-data-dir", $gateUserData)
    if ($null -ne $gateConfig.extra_args) {
        foreach ($extra in @($gateConfig.extra_args)) {
            $godotArgs += [string]$extra
        }
    }
    $godotArgs += @("--", "--" + [string]$gate)

    Write-Host "运行门禁: $gate" -ForegroundColor Cyan
    & $godotExe @godotArgs
    if ($LASTEXITCODE -ne 0) {
        throw "$gate 失败，退出码 $LASTEXITCODE"
    }
}

Write-Host "SELECTED_TESTS_PASS" -ForegroundColor Green
exit 0
