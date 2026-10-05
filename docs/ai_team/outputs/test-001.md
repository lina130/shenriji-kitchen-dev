# 按改动范围自动选择测试

## 主方案

# 测试选择入口方案（run_tests.ps1 重构）

## 0. 结论先行

新增/替换 `run_tests.ps1`，实现：
1. **Godot 编译检查**（`--check-only` + 脚本解析），失败即停，不进入任何测试。
2. **git diff 分类** → 映射到 6 个按需门禁（scene-check / world-systems / smoke-test / economy-check / stress-test / spot-city）。
3. **release 模式**（`-Mode release`）才跑完整七项（含 `--full-simulation` 与真实窗口 `--playtest`）。
4. 输出 `test_plan.json` 供 CI 与人工核对，**可验证断言**在 §5。

---

## 1. 文件清单

| 文件 | 操作 | 说明 |
|---|---|---|
| `run_tests.ps1` | **替换** | 唯一入口，兼容旧调用（无参数=默认按 diff 选测） |
| `tools/test_map.json` | **新增** | 路径 glob → 门禁映射规则（数据驱动，改规则不改脚本） |
| `tools/compile_check.ps1` | **新增** | 独立编译检查（可被 run_tests 调用，也可单独跑） |
| `tools/select_tests.ps1` | **新增** | 纯函数：输入 diff 文件列表，输出选中门禁集合 |
| `.tools/test_userdata/` | 复用 | 隔离 user-data-dir，避免污染玩家存档 |
| `artifacts/test_plan.json` | 新增产物 | 本次选中的门禁、命中规则、diff 摘要 |

> 保留 `build_release.ps1` 不动；`run_tests.ps1 -Mode release` 与其测试段等价，供本地预检。

---

## 2. 门禁定义（与现有测试脚本一一对应）

| 门禁 ID | Godot 参数 | 覆盖范围 | 触发条件（摘要） |
|---|---|---|---|
| `compile` | `--headless --check-only` + 脚本解析 | 全项目 GDScript 语法/资源引用 | **永远先跑** |
| `scene-check` | `-- --scene-check` | `tests/scene_check.gd`：34 个场景可达性、交互物唯一性、zone 布局 | 场景/地图/交互物/WorldGraph 改动 |
| `world-systems` | `-- --world-systems` | `tests/world_systems_test.gd`：农场/宠物/房间/员工/职业/节日/家庭等 | 系统脚本、CSV 数据、Manager 改动 |
| `smoke-test` | `-- --smoke-test` | 启动 → 主菜单 → 新游戏 → 首帧 | `project.godot`、autoload、主场景 |
| `economy-check` | `-- --economy-check` | 经营场景点击、菜单池、工序流水线 | `economy/`、`business/`、菜单/工序 CSV |
| `stress-test` | `-- --stress-test` | 100 月经济压力 | 经济数值、工资、物价、存档结构 |
| `spot-city` | `-- --spot-city` | 城市分区抽样（street/commercial/industrial 等） | `scene_zones.csv`、分区地图、NPC 坐标 |
| `full-simulation` | `-- --full-simulation` | 完整经营与收集模拟 | **仅 release** |
| `playtest` | `--resolution 1280x720 -- --playtest` | 真实窗口 145 步 | **仅 release，非 headless** |

> 说明：任务要求"七项"= scene-check / world-systems / smoke-test / economy-check / stress-test / spot-city / full-simulation（+ playtest 为 release 附加）。按 diff 模式**最多选 6 项**，release 模式**全跑**。

---

## 3. 映射规则（`tools/test_map.json`）

```json
{
  "version": 1,
  "rules": [
    {
      "id": "scene",
      "gates": ["scene-check", "spot-city"],
      "paths": [
        "scenes/**",
        "scripts/gameplay/world.gd",
        "scripts/gameplay/scene_router.gd",
        "scripts/gameplay/world_interactable.gd",
        "data/csv/scene_zones.csv",
        "data/csv/visual_bindings*.csv",
        "autoload/world_graph.gd"
      ]
    },
    {
      "id": "world-systems",
      "gates": ["world-systems"],
      "paths": [
        "scripts/systems/**",
        "scripts/managers/**",
        "autoload/**",
        "data/csv/**",
        "tests/world_systems_test.gd"
      ]
    },
    {
      "id": "smoke",
      "gates": ["smoke-test"],
      "paths": [
        "project.godot",
        "autoload/**",
        "scenes/main_menu.tscn",
        "scenes/game.tscn",
        "scripts/main.gd"
      ]
    },
    {
      "id": "economy",
      "gates": ["economy-check", "stress-test"],
      "paths": [
        "scripts/economy/**",
        "scripts/business/**",
        "data/csv/menu_pool*.csv",
        "data/csv/pipeline*.csv",
        "data/csv/price*.csv",
        "tests/economy_check.gd"
      ]
    },
    {
      "id": "stress",
      "gates": ["stress-test"],
      "paths": [
        "scripts/economy/**",
        "scripts/systems/save*.gd",
        "data/csv/wage*.csv",
        "data/csv/price*.csv"
      ]
    },
    {
      "id": "spot-city",
      "gates": ["spot-city"],
      "paths": [
        "data/csv/scene_zones.csv",
        "data/csv/npc_*.csv",
        "scripts/gameplay/npc*.gd"
      ]
    },
    {
      "id": "ui-theme",
      "gates": ["smoke-test", "scene-check"],
      "paths": [
        "scripts/ui/**",
        "data/csv/theme_tokens.csv",
        "data/csv/ui_text_styles.csv",
        "data/csv/ui_assets.csv",
        "scenes/ui/**"
      ]
    },
    {
      "id": "tests-only",
      "gates": [],
      "paths": ["tests/**", "docs/**", "*.md"]
    }
  ],
  "always": ["compile"],
  "fallback": ["smoke-test", "world-systems"]
}
```

**规则语义**：
- 任一 glob 命中 → 该规则 `gates` 全部加入选中集。
- `tests-only` 命中且**无其他规则命中** → 只跑 `compile`（改测试脚本本身不触发业务门禁）。
- 无任何命中（如只改 README）→ 走 `fallback`。
- `always` 永远先跑。

---

## 4. 脚本实现

### 4.1 `tools/select_tests.ps1`（纯函数，可单测）

```powershell
param(
    [Parameter(Mandatory)][string[]]$ChangedFiles,
    [string]$MapPath = (Join-Path $PSScriptRoot "test_map.json")
)
$ErrorActionPreference = "Stop"
$map = Get-Content -LiteralPath $MapPath -Raw | ConvertFrom-Json

function Test-Glob([string]$path, [string]$pattern) {
    # 支持 ** 与 *，大小写不敏感，统一 / 分隔
    $p = $path -replace '\\','/'
    $rx = [regex]::Escape($pattern -replace '\\','/')
    $rx = $rx -replace '\\\*\\\*', '.*' -replace '\\\*', '[^/]*'
    return [regex]::IsMatch($p, "^$rx$", 'IgnoreCase')
}

$selected = New-Object System.Collections.Generic.HashSet[string]
$hits = @()
foreach ($rule in $map.rules) {
    $matched = @()
    foreach ($f in $ChangedFiles) {
        foreach ($pat in $rule.paths) {
            if (Test-Glob $f $pat) { $matched += $f; break }
        }
    }
    if ($matched.Count -gt 0) {
        $hits += [pscustomobject]@{ rule = $rule.id; files = $matched; gates = $rule.gates }
        foreach ($g in $rule.gates) { [void]$selected.Add($g) }
    }
}

$onlyTests = ($hits.Count -gt 0) -and (($hits | Where-Object { $_.rule -ne 'tests-only' }).Count -eq 0)
if ($selected.Count -eq 0 -and -not $onlyTests) {
    foreach ($g in $map.fallback) { [void]$selected.Add($g) }
}

[pscustomobject]@{
    gates = @($map.always) + @($selected)
    hits  = $hits
    onlyTests = $onlyTests
} | ConvertTo-Json -Depth 6
```

### 4.2 `tools/compile_check.ps1`

```powershell
param(
    [Parameter(Mandatory)][string]$GodotPath,
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$UserDataDir
)
$ErrorActionPreference = "Stop"

# 1) 资源导入 + 语法检查（--check-only 会解析所有 .gd/.tscn）
& $GodotPath --headless --path $Root --user-data-dir $UserDataDir --check-only --quit
if ($LASTEXITCODE -ne 0) { throw "Godot 编译检查失败（--check-only），退出码 $LASTEXITCODE" }

# 2) 逐脚本解析（捕获 --check-only 漏掉的 autoload 循环引用）
$scripts = Get-ChildItem -LiteralPath (Join-Path $Root "scripts") -Recurse -Filter *.gd -File
$bad = @()
foreach ($s in $scripts) {
    $rel = "res://" + ($s.FullName.Substring($Root.Length + 1) -replace '\\','/')
    & $GodotPath --headless --path $Root --user-data-dir $UserDataDir --check-only --script $rel --quit 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { $bad += $rel }
}
if ($bad.Count -gt 0) { throw "以下脚本解析失败：`n$($bad -join "`n")" }

Write-Host "COMPILE_CHECK_PASS"
```

> 若 `--check-only --script` 在当前 Godot 版本不支持，降级为只跑第 1 步，并在 `artifacts/test_plan.json` 记录 `compile_mode: "project_only"`。

### 4.3 `run_tests.ps1`（替换）

```powershell
param(
    [ValidateSet("auto","release")][string]$Mode = "auto",
    [string[]]$ChangedFiles,        # 显式指定；为空则用 git diff
    [string]$Base = "HEAD~1",
    [switch]$DryRun
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$artifacts = Join-Path $root "artifacts"
New-Item -ItemType Directory -Force -Path $artifacts | Out-Null

# --- 定位 Godot ---
$godot = Get-ChildItem -LiteralPath (Join-Path $root ".tools\godot") -Filter "Godot_v*-stable_win64_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $godot) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $cmd) { throw "未找到 Godot 4.2+。请安装或恢复 .tools/godot 便携版。" }
    $godotPath = $cmd.Source
} else { $godotPath = $godot.FullName }

$testData = Join-Path $root ".tools\test_userdata"
New-Item -ItemType Directory -Force -Path $testData | Out-Null

# --- 1. 编译检查（永远先跑）---
Write-Host "==> 编译检查"
& (Join-Path $root "tools\compile_check.ps1") -GodotPath $godotPath -Root $root -UserDataDir $testData

# --- 2. 选择门禁 ---
if ($Mode -eq "release") {
    $gates = @("smoke-test","full-simulation","world-systems","scene-check","economy-check","stress-test","playtest")
    $hits = @()
} else {
    if (-not $ChangedFiles -or $ChangedFiles.Count -eq 0) {
        $ChangedFiles = & git -C $root diff --name-only "$Base...HEAD"
        if (-not $ChangedFiles) { $ChangedFiles = & git -C $root diff --name-only }
    }
    $plan = & (Join-Path $root "tools\select_tests.ps1") -ChangedFiles $ChangedFiles | ConvertFrom-Json
    $gates = $plan.gates | Select-Object -Unique
    $hits = $plan.hits
}

$planOut = [pscustomobject]@{
    mode = $Mode
    base = $Base
    changed = @($ChangedFiles)
    gates = @($gates)
    hits = @($hits)
    timestamp = (Get-Date).ToString("o")
}
$planOut | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $artifacts "test_plan.json") -Encoding UTF8
Write-Host ("选中门禁: " + ($gates -join ", "))

if ($DryRun) { exit 0 }

# --- 3. 执行 ---
function Invoke-Gate([string]$gate) {
    Write-Host "==> $gate"
    switch ($gate) {
        "smoke-test"      { & $godotPath --headless --path $root --user-data-dir $testData -- --smoke-test }
        "world-systems"   { & $godotPath --headless --path $root --user-data-dir $testData -- --world-systems }
        "scene-check"     { & $godotPath --headless --path $root --user-data-dir $testData -- --scene-check }
        "economy-check"   { & $godotPath --headless --path $root --user-data-dir $testData -- --economy-check }
        "stress-test"     { & $godotPath --headless --path $root --user-data-dir $testData -- --stress-test }
        "spot-city"       { & $godotPath --headless --path $root --user-data-dir $testData -- --spot-city }
        "full-simulation" { & $godotPath --headless --path $root --user-data-dir $testData -- --full-simulation }
        "playtest"        { & $godotPath --path $root --user-data-dir $testData --resolution 1280x720 -- --playtest }
        default           { throw "未知门禁: $gate" }
    }
    if ($LASTEXITCODE -ne 0) { throw "$gate 失败，退出码 $LASTEXITCODE" }
}

foreach ($g in $gates) { Invoke-Gate $g }

Write-Host "ALL_SELECTED_TESTS_PASS"
```

---

## 5. 可验证断言

| # | 断言 | 验证命令 | 期望 |
|---|---|---|---|
| A1 | 编译失败即停，不跑任何门禁 | 故意在 `scripts/main.gd` 加 `func (` | 退出码 ≠0，`artifacts/test_plan.json` **不存在** |
| A2 | 只改 `docs/README.md` → 只跑 compile | `.\run_tests.ps1 -ChangedFiles docs/README.md -DryRun` | `gates == ["compile"]` |
| A3 | 改 `scenes/street.tscn` → 触发 scene-check + spot-city | `-ChangedFiles scenes/street.tscn -DryRun` | `gates` 含 `scene-check`、`spot-city`，不含 `economy-check` |
| A4 | 改 `data/csv/price.csv` → 触发 economy-check + stress-test | `-ChangedFiles data/csv/price.csv -DryRun` | `gates` 含 `economy-check`、`stress-test` |
| A5 | 改 `tests/scene_check.gd` → 只跑 compile | `-ChangedFiles tests/scene_check.gd -DryRun` | `gates == ["compile"]` |
| A6 | 无命中 → fallback | `-ChangedFiles CHANGELOG.md -DryRun` | `gates` 含 `smoke-test`、`world-systems` |
| A7 | release 模式跑全七项 | `.\run_tests.ps1 -Mode release -DryRun` | `gates` 长度 = 7，且含 `playtest` |
| A8 | 门禁失败传播 | 临时把 `scene_check.gd` 的 `quit(0)` 改 `quit(1)` | 退出码 ≠0，后续门禁不执行 |
| A9 | user-data-dir 隔离 | 跑完后检查 `%APPDATA%\Godot\app_userdata\深日记` | 无新增文件 |
| A10 | 计划可审计 | 每次运行后 `artifacts/test_plan.json` 存在且含 `hits` | `hits[].rule` 与改动文件对应 |

---

## 6. 执行步骤（人工/CI）

```powershell
# 本地按 diff 选测（默认）
.\run_tests.ps1

# 指定基线
.\run_tests.ps1 -Base origin/main

# 只看计划不执行
.\run_tests.ps1 -DryRun

# 手动指定改动（CI 传入）
.\run_tests.ps1 -ChangedFiles "scripts/economy/market.gd","data/csv/price.csv"

# 发布前全量
.\run_tests.ps1 -Mode release
```

CI 建议：
```yaml
- run: pwsh -File run_tests.ps1 -Base ${{ github.event.pull_request.base.sha }}
- uses: actions/upload-artifact@v4
  with: { name: test_plan, path: artifacts/test_plan.json }
```

---

## 7. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| `--check-only --script` 在 Godot 4.2 不支持 | 编译检查降级 | 脚本自动降级并记录 `compile_mode`；CI 断言 `compile_mode` 字段存在 |
| glob 匹配过宽（如 `data/csv/**` 命中所有规则） | 选测退化为全量 | 规则按**最具体优先**排序；`select_tests.ps1` 输出 `hits` 供人工审计；A3/A4 断言覆盖 |
| `git diff` 在浅克隆下无 `HEAD~1` | 选测失败 | 脚本回退到 `git diff --name-only`（工作区）；CI 用 `-Base` 显式传 |
| `playtest` 需要真实窗口，CI 无显示 | release 模式 CI 失败 | release 模式在 CI 中加 `-SkipPlaytest` 开关（本方案预留，未实现则 CI 用 `-DryRun` 校验计划） |
| 新增规则未同步 `test_map.json` | 漏测 | 每次新增目录时在 PR 模板要求更新 `test_map.json`；A10 断言 `hits` 非空 |
| `stress-test` 耗时长（100 月） | 反馈慢 | 仅在 `economy/**` 或 `price/wage` CSV 改动时触发；其余走 `economy-check` |
| user-data-dir 与 build_release 冲突 | 存档污染 | 统一 `.tools/test_userdata`；build_release 的测试段建议改为调用 `run_tests.ps1 -Mode release` |

---

## 8. 与共享黑板约束的对齐

- **存档兼容**：所有门禁使用隔离 `user-data-dir`，不触碰玩家存档；`stress-test` 覆盖存档结构变更。
- **固定物价**：`data/csv/price*.csv` 改动强制触发 `economy-check` + `stress-test`，防止物价漂移。
- **场景点击经营**：`economy-check` 覆盖点击路径；`scene-check` 覆盖交互物唯一性。
- **NPC/系统/场景提示分离**：`world-systems` 覆盖 `_test_presentation_interfaces`；`scene-check` 覆盖场景侧。
- **高效测试**：按 diff 选测，典型 PR 只跑 1–2 个门禁，release 才全量。

---

## 9. 交付物

1. `run_tests.ps1`（替换）
2. `tools/compile_check.ps1`（新增）
3. `tools/select_tests.ps1`（新增）
4. `tools/test_map.json`（新增）
5. `artifacts/test_plan.json`（运行产物，加入 `.gitignore`）
6. 本文档作为 `docs/TEST_SELECTION.md` 落库

**下一步**：确认 `--check-only --script` 在当前 Godot 版本可用性（跑一次 `tools/compile_check.ps1` 看是否降级），以及 `--spot-city` 参数是否已在 `main.gd` 注册；若未注册，需在 `main.gd` 补 `--spot-city` 分支，否则 `spot-city` 门禁会静默通过。

## 独立方案

# 独立方案：`run_tests.ps1` 重构 —— 编译门禁 + diff 驱动测试选择

> 独立方案 Agent 输出。不迎合主方案。目标：**用最少的 Godot 进程启动次数，覆盖 diff 影响面**。核心洞察：Godot 每次 `--headless` 启动约 3–8 秒，现有 `run_tests.ps1` 无条件跑 2 项、`build_release.ps1` 无条件跑 7 项，是当前 CI 最大浪费点。

---

## 一、与主方案的架构分歧（先说结论）

| 维度 | 主方案倾向 | 本独立方案 | 理由 |
|---|---|---|---|
| 入口语言 | PowerShell | **PowerShell 薄壳 + Python 决策核心** | diff→测试映射是纯数据逻辑，Python 可单测、可复用、跨平台；PS 只负责调 Godot |
| 测试选择 | 按文件路径前缀匹配 | **按"影响面标签"匹配** | 路径前缀脆弱（`scripts/gameplay/farm.gd` 到底算 world 还是 economy？），标签由映射表显式声明 |
| 编译检查 | 单独一次 `--editor --quit` | **复用首次测试进程的 `--check-only` 预检 + 一次 `--editor --quit` 仅当有 `.gd` 变更** | 无 `.gd` 变更时跳过导入，省一次启动 |
| 七项全跑 | release 模式 | release 模式 **+ 显式 `-Full` 开关** | 允许本地手动全跑，不绑死 release |
| 失败策略 | 遇错即停 | **编译失败即停；测试失败收集全部后汇总退出** | 一次跑完知道所有坏点，避免修一个跑一次 |
| 并行 | 未提 | **可选 `-Parallel`：无状态测试并行** | scene-check / world-systems / economy-check 互不写同一 userdata 时可并行 |

**关键分歧**：主方案把"选择逻辑"写进 PS 的 `switch`，本方案把它抽成 `tools/select_tests.py`，输出 JSON，PS 消费。这样选择逻辑可被 `pytest` 覆盖，且未来 CI（GitHub Actions / 自建）可直接调 Python。

---

## 二、影响面标签体系（核心设计）

不按文件路径选测试，按**标签**选。每个测试声明它覆盖哪些标签；diff 命中哪些标签，就跑哪些测试。

### 2.1 标签定义

| 标签 | 含义 | 触发文件模式 |
|---|---|---|
| `scene` | 场景/区域/交互物结构 | `scenes/**`, `scripts/gameplay/world*.gd`, `scripts/gameplay/area*.gd`, `data/scene_zones.csv` |
| `world` | 世界系统（农场/宠物/房间/员工/剧情/家庭…） | `scripts/systems/**`, `scripts/gameplay/farm*.gd`, `scripts/gameplay/pet*.gd`, `data/*.csv`（非 economy 表） |
| `economy` | 经营/物价/工序/市场 | `scripts/economy/**`, `scripts/gameplay/business*.gd`, `data/goods*.csv`, `data/recipes*.csv`, `data/prices*.csv` |
| `ui` | HUD/主题/提示 | `scripts/ui/**`, `data/csv/theme_*.csv`, `data/csv/ui_*.csv`, `scenes/ui/**` |
| `npc` | NPC 定义/日程/支线 | `scripts/npc/**`, `data/npc*.csv`, `data/dialogue*.csv` |
| `save` | 存档/兼容 | `scripts/save/**`, `scripts/autoload/save*.gd`, `data/save_schema*.json` |
| `art` | 美术/音频资产 | `assets/**`, `tools/generate_*.py` |
| `build` | 构建/导出/CI | `*.ps1`, `tools/*.py`, `export_presets.cfg`, `project.godot` |
| `docs` | 文档 | `docs/**`, `*.md` |

### 2.2 测试 → 标签映射（唯一事实源）

```python
# tools/test_map.py
TEST_MAP = {
    "scene-check":   {"tags": {"scene", "world"},           "weight": 1},
    "world-systems": {"tags": {"world", "npc", "save"},     "weight": 1},
    "smoke-test":    {"tags": {"scene", "world", "economy", "ui", "npc", "save"}, "weight": 1},
    "economy-check": {"tags": {"economy"},                  "weight": 1},
    "stress-test":   {"tags": {"economy", "save"},          "weight": 1},
    "spot-city":     {"tags": {"scene", "world", "ui"},     "weight": 1},
    "playtest":      {"tags": {"ui", "scene"},              "weight": 1, "windowed": True},
}
```

**选择规则**：
1. 计算 diff 命中的标签集合 `T`。
2. 选中所有 `tags ∩ T ≠ ∅` 的测试。
3. **兜底**：若 `T` 为空（如只改 docs）→ 不跑任何测试，直接通过。
4. **兜底**：若 `T` 含 `build` 或 `project.godot` → 强制加 `smoke-test`（构建配置破坏面最大）。
5. **兜底**：若 diff 触及 `scripts/autoload/**` → 强制加 `smoke-test` + `world-systems`（autoload 是全局单例，破坏面最大）。
6. **release 模式**：忽略选择，跑全部七项。

### 2.3 为什么不用路径前缀

反例：`scripts/gameplay/farm.gd` 改一行。
- 路径前缀方案：命中 `scripts/gameplay/` → 跑 scene-check + world-systems。
- 标签方案：`farm.gd` 在 `test_map` 的 `world` 标签 → 只跑 world-systems。
- **省一次 Godot 启动**，且语义正确（farm 不改场景结构）。

---

## 三、编译检查策略（省启动次数）

现有 `build_release.ps1` 用 `--headless --editor --path $root --quit` 做导入。这是**最贵的一次启动**（编辑器模式加载全部资源）。

本方案：
1. **先跑 `--check-only` 预检**：`godot --headless --path $root --check-only --script res://scripts/main.gd`（或项目主脚本）。这能捕获 GDScript 语法错误，**不加载资源**，约 1–2 秒。
2. **仅当 diff 含 `.gd` 或 `.tscn` 或 `project.godot`** 才跑 `--editor --quit` 做完整导入。
3. 若 diff 只含 `.csv` / `.png` / `.md` → 跳过导入，直接进测试。

**收益**：纯数据改动（CSV 调价、文案）从"导入 + 测试"降到"仅测试"。

---

## 四、可执行实现

### 4.1 `tools/select_tests.py`（决策核心，可单测）

```python
#!/usr/bin/env python3
"""根据 git diff 选择测试。输出 JSON 到 stdout。"""
from __future__ import annotations
import argparse, json, subprocess, sys
from pathlib import Path

# ---- 标签规则（唯一事实源）----
TAG_RULES: list[tuple[str, list[str]]] = [
    ("scene",   ["scenes/", "scripts/gameplay/world", "scripts/gameplay/area",
                 "data/scene_zones.csv"]),
    ("world",   ["scripts/systems/", "scripts/gameplay/farm", "scripts/gameplay/pet",
                 "scripts/gameplay/room", "scripts/gameplay/staff",
                 "scripts/gameplay/story", "scripts/gameplay/family"]),
    ("economy", ["scripts/economy/", "scripts/gameplay/business",
                 "data/goods", "data/recipes", "data/prices"]),
    ("ui",      ["scripts/ui/", "scenes/ui/", "data/csv/theme_", "data/csv/ui_"]),
    ("npc",     ["scripts/npc/", "data/npc", "data/dialogue"]),
    ("save",    ["scripts/save/", "scripts/autoload/save", "data/save_schema"]),
    ("art",     ["assets/", "tools/generate_"]),
    ("build",   [".ps1", "tools/", "export_presets.cfg", "project.godot"]),
    ("docs",    ["docs/", ".md"]),
]

TEST_MAP: dict[str, dict] = {
    "scene-check":   {"tags": {"scene", "world"}},
    "world-systems": {"tags": {"world", "npc", "save"}},
    "smoke-test":    {"tags": {"scene", "world", "economy", "ui", "npc", "save"}},
    "economy-check": {"tags": {"economy"}},
    "stress-test":   {"tags": {"economy", "save"}},
    "spot-city":     {"tags": {"scene", "world", "ui"}},
    "playtest":      {"tags": {"ui", "scene"}, "windowed": True},
}
ALL_TESTS = list(TEST_MAP.keys())

# 强制升级规则：命中这些路径 → 追加测试
FORCE_RULES: list[tuple[list[str], list[str]]] = [
    (["scripts/autoload/"], ["smoke-test", "world-systems"]),
    (["project.godot", "export_presets.cfg"], ["smoke-test"]),
]

def git_changed_files(root: Path, base: str) -> list[str]:
    """返回相对 root 的变更文件列表。base 为空则用 HEAD。"""
    args = ["git", "-C", str(root), "diff", "--name-only"]
    if base:
        args.append(base)
    else:
        args += ["HEAD"]
    # 同时纳入未跟踪文件（新文件常是新增场景/系统）
    tracked = subprocess.run(args, capture_output=True, text=True, check=True).stdout
    untracked = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--others", "--exclude-standard"],
        capture_output=True, text=True, check=True).stdout
    files = [f.strip() for f in (tracked + "\n" + untracked).splitlines() if f.strip()]
    return sorted(set(files))

def classify(files: list[str]) -> set[str]:
    tags: set[str] = set()
    for f in files:
        for tag, patterns in TAG_RULES:
            if any(p in f for p in patterns):
                tags.add(tag)
    return tags

def select(files: list[str], mode: str) -> dict:
    if mode == "release":
        return {"tests": ALL_TESTS, "tags": sorted(classify(files)),
                "reason": "release 模式：全量七项"}
    tags = classify(files)
    if not tags:
        return {"tests": [], "tags": [], "reason": "无相关变更（仅文档/空 diff）"}
    chosen = [t for t, spec in TEST_MAP.items() if spec["tags"] & tags]
    # 强制升级
    forced: list[str] = []
    for patterns, extra in FORCE_RULES:
        if any(any(p in f for p in patterns) for f in files):
            forced += extra
    chosen = sorted(set(chosen) | set(forced))
    # 去重后按固定顺序输出，保证可复现
    ordered = [t for t in ALL_TESTS if t in chosen]
    return {"tests": ordered, "tags": sorted(tags),
            "reason": f"命中标签 {sorted(tags)}" + (f"；强制追加 {forced}" if forced else "")}

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--base", default="")
    ap.add_argument("--mode", choices=["auto", "release", "full"], default="auto")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    files = git_changed_files(root, args.base)
    mode = "release" if args.mode == "full" else args.mode
    result = select(files, mode)
    result["files"] = files
    result["need_import"] = any(
        f.endswith((".gd", ".tscn", ".tres", ".import")) or f == "project.godot"
        for f in files
    )
    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(f"标签: {result['tags']}")
        print(f"测试: {result['tests'] or '（无）'}")
        print(f"原因: {result['reason']}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

### 4.2 `run_tests.ps1`（薄壳，只调 Godot）

```powershell
param(
    [ValidateSet("auto","release","full")][string]$Mode = "auto",
    [string]$Base = "",
    [switch]$Parallel,
    [switch]$NoCompileCheck
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---- 1. 定位 Godot ----
$godot = Get-ChildItem -LiteralPath (Join-Path $root ".tools\godot") `
    -Filter "Godot_v*-stable_win64_console.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $godot) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $cmd) { throw "未找到 Godot 4.2+。请安装或恢复 .tools/godot 便携版。" }
    $godotPath = $cmd.Source
} else { $godotPath = $godot.FullName }

# ---- 2. 决策：调 Python 选测试 ----
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { throw "需要 Python 3 运行 tools/select_tests.py。" }
$json = & python (Join-Path $root "tools\select_tests.py") `
    --root $root --base $Base --mode $Mode --json
if ($LASTEXITCODE -ne 0) { throw "测试选择失败。" }
$plan = $json | ConvertFrom-Json

Write-Host "== 测试计划 ==" -ForegroundColor Cyan
Write-Host "  标签: $($plan.tags -join ', ')"
Write-Host "  测试: $(if ($plan.tests) { $plan.tests -join ', ' } else { '（无）' })"
Write-Host "  原因: $($plan.reason)"

# ---- 3. 编译检查 ----
$testData = Join-Path $root ".tools\test_userdata"
New-Item -ItemType Directory -Force -Path $testData | Out-Null

if (-not $NoCompileCheck) {
    Write-Host "== 编译检查 ==" -ForegroundColor Cyan
    # 3a. 快速语法预检（不加载资源）
    & $godotPath --headless --path $root --user-data-dir $testData `
        --check-only --script "res://scripts/main.gd"
    if ($LASTEXITCODE -ne 0) { throw "GDScript 语法检查失败。" }
    # 3b. 仅当有 .gd/.tscn/project.godot 变更才做完整导入
    if ($plan.need_import) {
        Write-Host "  检测到脚本/场景变更，执行资源导入..."
        & $godotPath --headless --editor --path $root --user-data-dir $testData --quit
        if ($LASTEXITCODE -ne 0) { throw "资源导入失败。" }
    } else {
        Write-Host "  无脚本/场景变更，跳过导入。"
    }
}

# ---- 4. 执行测试 ----
if (-not $plan.tests -or $plan.tests.Count -eq 0) {
    Write-Host "无测试需要运行，通过。" -ForegroundColor Green
    exit 0
}

$failures = @()
function Invoke-GodotTest([string]$name) {
    Write-Host "== 运行 $name ==" -ForegroundColor Cyan
    $args = @("--headless", "--path", $root, "--user-data-dir", $testData, "--", "--$name")
    if ($name -eq "playtest") {
        $args = @("--path", $root, "--resolution", "1280x720", "--", "--playtest")
    }
    & $godotPath @args
    if ($LASTEXITCODE -ne 0) { $script:failures += $name }
}

if ($Parallel -and $plan.tests.Count -gt 1) {
    # 并行：每个测试独立 userdata，避免存档互踩
    $jobs = foreach ($t in $plan.tests) {
        Start-Job -ScriptBlock {
            param($godotPath, $root, $t)
            $ud = Join-Path $root ".tools\test_userdata_$t"
            New-Item -ItemType Directory -Force -Path $ud | Out-Null
            & $godotPath --headless --path $root --user-data-dir $ud -- --$t
            [pscustomobject]@{ Test = $t; Code = $LASTEXITCODE }
        } -ArgumentList $godotPath, $root, $t
    }
    $jobs | Wait-Job | Receive-Job | ForEach-Object {
        if ($_.Code -ne 0) { $failures += $_.Test }
    }
    $jobs | Remove-Job
} else {
    foreach ($t in $plan.tests) { Invoke-GodotTest $t }
}

# ---- 5. 汇总 ----
if ($failures.Count -gt 0) {
    Write-Host "失败: $($failures -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "全部通过。" -ForegroundColor Green
exit 0
```

### 4.3 `build_release.ps1` 的改动（仅两行）

```powershell
# 原：无条件跑七项
# 新：release 模式走 run_tests.ps1，全量
& (Join-Path $root "run_tests.ps1") -Mode release
if ($LASTEXITCODE -ne 0) { throw "测试失败，已停止打包。" }
```

删除 `build_release.ps1` 里重复的 `Invoke-GodotTest` 定义与七次调用，**单一测试入口**。

---

## 五、与现有测试脚本的对接

现有 `tests/scene_check.gd` / `world_systems_test.gd` 通过 `-- --scene-check` / `-- --world-systems` 触发。本方案**不改测试脚本**，只改调度。需要确认的 CLI 参数（`--economy-check` / `--stress-test` / `--spot-city`）是否已在 `scripts/main.gd` 的 `_parse_args` 中注册——若未注册，需补：

```gdscript
# scripts/main.gd 中
match arg:
    "--scene-check":   run_scene_check()
    "--world-systems": run_world_systems()
    "--smoke-test":    run_smoke_test()
    "--economy-check": run_economy_check()
    "--stress-test":   run_stress_test()
    "--spot-city":     run_spot_city()
    "--playtest":      run_playtest()
```

**验证命令**（开工前必跑）：
```bash
grep -n '"--' scripts/main.gd | grep -E 'scene-check|world-systems|smoke-test|economy-check|stress-test|spot-city|playtest'
```
若缺项，先补注册再启用本方案对应测试。

---

## 六、测试选择逻辑的自测（`tools/test_select_tests.py`）

```python
from tools.select_tests import select, classify

def test_docs_only():
    assert select(["docs/README.md"], "auto")["tests"] == []

def test_farm_change_only_world():
    r = select(["scripts/gameplay/farm.gd"], "auto")
    assert "world-systems" in r["tests"]
    assert "scene-check" not in r["tests"]  # farm 不改场景结构

def test_autoload_forces_smoke():
    r = select(["scripts/autoload/game_state.gd"], "auto")
    assert "smoke-test" in r["tests"]
    assert "world-systems" in r["tests"]

def test_project_godot_forces_smoke():
    r = select(["project.godot"], "auto")
    assert "smoke-test" in r["tests"]

def test_release_runs_all():
    r = select(["docs/x.md"], "release")
    assert set(r["tests"]) == set(TEST_MAP.keys())

def test_economy_csv():
    r = select(["data/goods.csv"], "auto")
    assert "economy-check" in r["tests"]
    assert "scene-check" not in r["tests"]
```

---

## 七、收益量化

| 场景 | 现有 | 本方案 | 节省 |
|---|---|---|---|
| 只改 `docs/` | 2 次启动（smoke + world） | 0 次 | 100% |
| 只改 `data/goods.csv` | 2 次 | 1 次（economy-check）+ 0 导入 | ~60% |
| 只改 `scripts/gameplay/farm.gd` | 2 次 + 1 导入 | 1 次（world-systems）+ 1 导入 | ~40% |
| 改 `scripts/autoload/` | 2 次 | 2 次（强制 smoke + world） | 0%（但语义正确） |
| release 打包 | 7 次 + 1 导入 | 7 次 + 1 导入 | 0%（但入口统一） |

**关键收益不在单次节省，而在**：
1. 选择逻辑可单测，不再靠人肉维护 PS `switch`。
2. `--check-only` 预检把语法错误挡在导入之前，报错更快。
3. 并行开关让本地全跑从串行 7×5s 降到 ~10s。

---

## 八、落地顺序

1. 写 `tools/select_tests.py` + `tools/test_select_tests.py`，`pytest` 通过。
2. 确认 `scripts/main.gd` 已注册全部 `--xxx` 参数（缺则补）。
3. 替换 `run_tests.ps1`，本地跑 `-Mode auto` 验证选择正确。
4. 改 `build_release.ps1` 调 `run_tests.ps1 -Mode release`，删重复代码。
5. 在 CI 中把 `run_tests.ps1 -Mode auto -Base origin/main` 作为 PR 门禁。

**不做的事**：不改任何 `tests/*.gd` 内容；不引入新测试框架；不碰 Godot 版本。

## 批判

# 批判报告：两份测试选择方案的遗漏、冲突与返工要求

---

## 一、致命问题（阻塞落地，必须先修）

### C1. 两份方案都假设 `--check-only --script` 存在，但都没验证，且主方案的降级路径是错的

**主方案** §4.2 用 `--check-only --script res://...` 逐脚本解析，§7 承认"若不支持则降级为只跑第 1 步"。但：

- Godot 4.2 的 `--check-only` 是**编辑器模式**参数，配合 `--script` 时行为是"运行该脚本的 `_init` 后退出"，**不是语法检查**。真正的语法检查是 `--headless --editor --quit`（导入即解析）或 `--check-only` 单独用。
- 主方案的降级路径"只跑第 1 步"——第 1 步是 `--check-only --quit`，**这个组合在 Godot 4.2 里不解析任何脚本**，只做项目加载。等于编译检查形同虚设。
- 独立方案 §三 同样用 `--check-only --script res://scripts/main.gd`，只检查一个文件，**漏掉其余所有脚本**。

**返工要求**：
1. 落地前必须实测三条命令，把结果写进方案：
   - `godot --headless --path <root> --check-only --quit`（退出码？是否解析脚本？）
   - `godot --headless --path <root> --editor --quit`（退出码？耗时？）
   - `godot --headless --path <root> --script res://scripts/main.gd --check-only`（是否只跑 main？）
2. 编译检查的**唯一可靠手段**是 `--headless --editor --quit`（导入即全量解析）。若嫌慢，用 `--import`（Godot 4.3+）或缓存 `.godot/`。**不要用 `--check-only --script` 冒充全量语法检查。**
3. 主方案 §5 断言 A1"编译失败即停"必须改成用 `--editor --quit` 触发，否则断言本身不可验证。

---

### C2. 两份方案的"门禁 ID"与"CLI 参数"映射不一致，且都未验证 `main.gd` 是否注册

- 主方案 §2 表格：门禁 `smoke-test` → 参数 `-- --smoke-test`；`spot-city` → `-- --spot-city`。
- 独立方案 §五 承认"需确认 `--economy-check` / `--stress-test` / `--spot-city` 是否已注册"，并给了 grep 命令——**但没跑**。
- 主方案 §9 末尾也承认"若未注册，需在 `main.gd` 补 `--spot-city` 分支，否则 `spot-city` 门禁会静默通过"。

**这是死代码/不可触达机制的典型**：门禁被"选中"了，但 Godot 收到未知参数后**默认退出码 0**，测试静默通过，CI 绿灯，实际没测。

**返工要求**：
1. 落地前跑 `grep -n '"--' scripts/main.gd`，把**实际注册的参数列表**贴进方案。
2. 在 `run_tests.ps1` 里加**参数存在性预检**：启动前用 `-- --list-gates`（需在 `main.gd` 新增）或静态 grep，缺参数直接 fail，不允许静默通过。
3. 每个门禁的 Godot 退出码语义必须明确：`quit(0)` = 通过，`quit(1)` = 失败，**未知参数必须 `quit(2)`**。主方案 A8 只测了 scene_check 改 `quit(1)`，没测未知参数。

---

### C3. 两份方案的 diff 基线语义不同，且都有浅克隆/未跟踪文件漏洞

- 主方案：`git diff --name-only "$Base...HEAD"`，Base 默认 `HEAD~1`。**浅克隆下 `HEAD~1` 不存在**，回退到 `git diff --name-only`（工作区）——但 CI 里工作区是干净的，回退后**返回空**，走 fallback 跑 smoke+world，**漏测**。
- 独立方案：`git diff --name-only <base>` + `git ls-files --others`。**`git diff <base>` 是 base 与工作区的 diff，不是 base 与 HEAD**。CI 里 checkout 后工作区=HEAD，所以这是对的；但本地开发时工作区有未提交改动，会把**未提交改动也算进去**，与"PR 门禁"语义不符。
- 两份方案都**没处理 rename**（`git diff --name-only` 对 rename 只显示新路径，旧路径丢失，可能漏触发旧路径对应的门禁）。
- 两份方案都**没处理删除文件**（删了 `scripts/economy/market.gd`，diff 显示该路径，触发 economy-check——对；但删了 `data/csv/price.csv`，主方案触发 economy+stress，独立方案触发 economy——都对，但都没显式测）。

**返工要求**：
1. 统一基线语义：**PR 门禁用 `git diff --name-only <base>...HEAD`（三点，merge-base）**；本地用 `git diff --name-only HEAD`（工作区 vs HEAD）+ `git ls-files --others`。
2. 浅克隆检测：`git rev-parse --is-shallow-repository`，为 true 时**报错退出**，不静默回退。
3. 加 `--diff-filter=ACMR` 显式排除删除？不——删除也要触发。改为 `git diff --name-status`，把 `D` 状态的文件也纳入。
4. rename 用 `git diff -M --name-status`，取旧+新两个路径。

---

## 二、严重问题（会导致漏测或误报）

### C4. 主方案的 glob 实现有 bug，`**` 替换顺序错误

主方案 §4.1：

```powershell
$rx = [regex]::Escape($pattern -replace '\\','/')
$rx = $rx -replace '\\\*\\\*', '.*' -replace '\\\*', '[^/]*'
```

`[regex]::Escape("scenes/**")` → `scenes/\*\*`（反斜杠转义星号）。然后 `-replace '\\\*\\\*', '.*'` 匹配的是**字面 `\*\*`**——但 `[regex]::Escape` 输出的是 `\*\*`（反斜杠+星号+反斜杠+星号），PowerShell 字符串里 `'\\\*\\\*'` 是 `\*\*`，**能匹配**。但顺序问题：先替换 `**` 再替换 `*`，`scenes/**` → `scenes/.*`，正确。`data/csv/*.csv` → `data/csv/[^/]*\.csv`，正确。

**但 `scripts/**/*.gd` 会变成 `scripts/.*/[^/]*\.gd`**——`**` 后必须跟 `/`，导致 `scripts/main.gd`（无中间目录）**不匹配**。这是经典 glob bug。

**返工要求**：改用成熟实现。PowerShell 用 `[System.Management.Automation.WildcardPattern]` 或直接调 Python 的 `fnmatch`/`pathspec`。**不要手写 glob→regex。**

---

### C5. 独立方案的"标签"体系有语义漏洞：`smoke-test` 的 tags 包含所有标签，等于永远被选中

独立方案 §2.2：

```python
"smoke-test": {"tags": {"scene", "world", "economy", "ui", "npc", "save"}},
```

选择规则"选中所有 `tags ∩ T ≠ ∅` 的测试"——**只要 diff 命中任何一个标签，smoke-test 必被选中**。这等于 smoke-test 永远跑，与"按需选测"目标矛盾。

独立方案 §七 收益表里"只改 `data/goods.csv` → 1 次（economy-check）"——**错**，按它的规则 smoke-test 也会被选中（economy ∈ smoke.tags），实际是 2 次。

**返工要求**：
1. smoke-test 的 tags 应改为**只覆盖"启动路径"**：`{"build", "autoload", "main_scene"}`，或干脆用 `FORCE_RULES` 显式触发，不放进 tags 交集。
2. 修正 §七 收益表，或改选择规则为"smoke-test 仅在 build/autoload/project.godot 变更时跑"。

---

### C6. 主方案的 `tests-only` 规则与 fallback 逻辑冲突

主方案 §3 规则语义：

> `tests-only` 命中且**无其他规则命中** → 只跑 `compile`。
> 无任何命中（如只改 README）→ 走 `fallback`。

但 `docs/**` 和 `*.md` 在 `tests-only` 的 paths 里。改 `docs/README.md`：
- `tests-only` 命中 → `onlyTests = true` → 不跑 fallback → 只跑 compile。✓（A2 断言）
- 改 `CHANGELOG.md`：`*.md` 命中 `tests-only` → 同上 → 只跑 compile。**但 A6 断言说"无命中 → fallback，gates 含 smoke+world"**。

**A2 和 A6 自相矛盾**：`CHANGELOG.md` 命中 `*.md`，属于 `tests-only`，按规则只跑 compile，但 A6 期望 fallback。**A6 断言会失败。**

**返工要求**：
1. 明确 `tests-only` 的语义：是"改测试/文档本身不触发业务门禁"，还是"改文档走 fallback"？
2. 若前者，A6 的 `CHANGELOG.md` 应改为**不在任何规则 paths 里的文件**（如 `LICENSE`），或删掉 A6。
3. 若后者，`tests-only` 的 paths 不应包含 `*.md`。

---

### C7. 两份方案都没处理"测试脚本自身改动"的循环依赖

- 主方案：改 `tests/scene_check.gd` → `tests-only` 命中 → 只跑 compile。**但改测试脚本本身应该跑该测试**，否则测试脚本写错了没人发现。
- 独立方案：`tests/` 不在任何 TAG_RULES 里 → `classify` 返回空 → "无相关变更" → 不跑任何测试。**同样漏测。**

**返工要求**：
1. 改 `tests/<name>.gd` → 强制跑 `<name>` 对应的门禁。需要 `tests/` 文件名 → 门禁 ID 的映射。
2. 或至少：改 `tests/**` → 跑所有门禁（测试脚本是共享基础设施）。

---

### C8. 存档风险：两份方案的 user-data-dir 隔离都不完整

- 主方案：所有门禁共用 `.tools/test_userdata`。**并行时（独立方案 §4.2）每个测试用 `.tools/test_userdata_$t`**，但主方案串行共用——`stress-test` 写存档后 `smoke-test` 读到脏存档，**测试间污染**。
- 独立方案：并行用独立目录，**串行时共用 `$testData`**——同样污染。
- 两份方案都**没清理** user-data-dir。跑 100 次后 `.tools/test_userdata` 累积垃圾，且**上次失败的存档会影响下次**。
- 两份方案都**没验证** Godot 是否真的用了 `--user-data-dir`。Godot 4.2 的 `--user-data-dir` 参数**存在**，但若路径含空格或中文，可能静默失败回退到 `%APPDATA%`。主方案 A9 断言"跑完后 `%APPDATA%\Godot\app_userdata\深日记` 无新增文件"——**但没测路径含空格的情况**。

**返工要求**：
1. 每个门禁用**独立** user-data-dir：`.tools/test_userdata/<gate>`。
2. 每次运行前**清空**该目录（或至少 `stress-test` 前清空）。
3. 加断言：跑完后检查 `%APPDATA%\Godot\app_userdata\` 下**无任何**项目相关目录新增。
4. 路径含空格/中文的测试用例。

---

### C9. 主方案的 `stress-test` 触发条件与"固定物价"约束冲突

主方案 §3 `stress` 规则 paths 含 `data/csv/price*.csv`，`economy` 规则也含 `data/csv/price*.csv`。改 price.csv → 同时命中 economy 和 stress → 跑 economy-check + stress-test。

但主方案 §8 说"`data/csv/price*.csv` 改动强制触发 `economy-check` + `stress-test`，防止物价漂移"——**stress-test 是 100 月经济压力测试，不是物价校验**。物价漂移应该由 economy-check 或专门的 price-check 覆盖。**stress-test 跑 100 月只会发现"经济崩溃"，不会发现"某个物价错了 0.01"**。

**返工要求**：
1. 明确 stress-test 的覆盖目标：是"经济系统稳定性"还是"物价正确性"？若是前者，price.csv 改动**不应**触发 stress-test（除非改的是工资/利率等系统性参数）。
2. 若确实需要物价校验，新增 `price-check` 门禁，或在 economy-check 里加断言。

---

## 三、中等问题（影响可维护性）

### C10. 主方案的 `select_tests.ps1` 输出 JSON 但 `run_tests.ps1` 消费时字段名不一致

主方案 §4.1 输出：

```powershell
[pscustomobject]@{
    gates = @($map.always) + @($selected)
    hits  = $hits
    onlyTests = $onlyTests
}
```

§4.3 消费：

```powershell
$plan = & ... | ConvertFrom-Json
$gates = $plan.gates | Select-Object -Unique
$hits = $plan.hits
```

字段名一致。**但 `$plan.gates` 是 `compile` + selected，而 §4.3 的 release 分支 `$gates = @("smoke-test",...)` 不含 `compile`**——release 模式下 compile 由 §4.3 开头的 `compile_check.ps1` 单独跑，但 `test_plan.json` 的 `gates` 字段**不含 compile**，与 auto 模式不一致。**审计时无法从 test_plan.json 判断 compile 是否跑过。**

**返工要求**：`test_plan.json` 的 `gates` 字段统一包含 `compile`，或加 `compile_ran: true` 字段。

---

### C11. 独立方案的 `--mode full` 与 `--mode release` 语义重复

独立方案 §4.1：

```python
ap.add_argument("--mode", choices=["auto", "release", "full"], default="auto")
...
mode = "release" if args.mode == "full" else args.mode
```

`full` 和 `release` 完全等价。**死代码。** 要么删 `full`，要么给 `full` 不同语义（如"跑所有测试但跳过 playtest"）。

---

### C12. 独立方案的 `need_import` 判断漏掉 `.import` 文件

独立方案 §4.1：

```python
result["need_import"] = any(
    f.endswith((".gd", ".tscn", ".tres", ".import")) or f == "project.godot"
    for f in files
)
```

`.import` 文件是 Godot 自动生成的，**不会出现在 git diff 里**（除非误提交）。真正需要导入的是 `.png` / `.wav` / `.glb` 等**源资产**。改 `assets/player.png` → `need_import` 为 false → 跳过导入 → 测试用旧导入结果 → **误报通过**。

**返工要求**：`need_import` 应检查 `.png` / `.jpg` / `.wav` / `.ogg` / `.glb` / `.gltf` / `.svg` / `.ttf` 等源资产扩展名。

---

### C13. 两份方案都没处理"Godot 进程挂起"

Godot `--headless` 跑测试时若死循环，**永不退出**。CI 会挂到超时（默认 6 小时）。两份方案都没加超时。

**返工要求**：
1. `Invoke-Gate` 用 `Start-Process -PassThru` + `Wait-Process -Timeout`，超时 kill 并标记失败。
2. 超时阈值按门禁区分：smoke 60s，stress 300s，playtest 600s。

---

### C14. 主方案的 A9 断言不可执行

> A9 | user-data-dir 隔离 | 跑完后检查 `%APPDATA%\Godot\app_userdata\深日记` | 无新增文件

**"无新增文件"需要基线快照**。方案没说要先快照。且 `%APPDATA%` 在 CI（Linux）上不存在。**断言不可执行。**

**返工要求**：改为"跑前记录 `%APPDATA%\Godot\app_userdata\` 下所有目录 mtime，跑后对比"，或"跑前删除该目录，跑后断言不存在"。

---

## 四、测试漏洞（断言覆盖不足）

### C15. 两份方案都缺"选择逻辑的负向测试"

主方案 §5 断言 A1–A10，独立方案 §6 六个 pytest。**都缺**：
- 改 `scripts/economy/market.gd` **不应**触发 scene-check（主方案 A3 只测了正向）。
- 改 `data/csv/theme_tokens.csv` **应**触发 smoke + scene-check（主方案 ui-theme 规则），但**没有断言**。
- 改 `scripts/autoload/world_graph.gd` 同时命中 scene 和 world-systems 和 smoke（autoload 在三个规则里），**应**跑三个门禁，但**没有断言**。
- 空 diff（`git diff` 返回空）**应**走 fallback，但**没有断言**。

**返工要求**：补负向断言，每个规则至少一个"命中"和"不命中"用例。

---

### C16. 两份方案都没测"门禁失败后 test_plan.json 是否仍写入"

主方案 §4.3：`test_plan.json` 在**选测后、执行前**写入。若 `compile_check.ps1` 失败（§4.3 第 1 步），**脚本 throw，test_plan.json 不存在**——A1 断言"test_plan.json 不存在"，**对**。但若 `smoke-test` 失败（第 3 步），test_plan.json **已写入**，记录了选中的门禁。**这是期望行为吗？** 方案没说。

**返工要求**：明确 test_plan.json 的写入时机语义。建议：选测后立即写（记录计划），执行后**追加** `results` 字段（记录每个门禁的退出码）。

---

### C17. 独立方案的并行模式有竞态

独立方案 §4.2：

```powershell
$jobs = foreach ($t in $plan.tests) {
    Start-Job -ScriptBlock {
        param($godotPath, $root, $t)
        $ud = Join-Path $root ".tools\test_userdata_$t"
        ...
    } -ArgumentList $godotPath, $root, $t
}
```

- `Start-Job` 启动的是**新 PowerShell 进程**，`$LASTEXITCODE` 在 job 里**不可靠**（job 的 `$LASTEXITCODE` 是 job 内最后一条命令的，但 `Receive-Job` 拿到的 `$_.Code` 是 job 内 `$LASTEXITCODE` 的快照——**若 Godot 是最后一条命令，OK；但 `New-Item` 在 Godot 前，`$LASTEXITCODE` 可能被 `New-Item` 污染**）。
- 更严重：`Start-Job` 的 `-ScriptBlock` 里 `& $godotPath` 的输出**不会实时显示**，CI 日志里看不到测试进度。
- `$jobs | Wait-Job | Receive-Job` 若某个 job 挂起，`Wait-Job` 无超时，**永久挂起**。

**返工要求**：
1. 用 `Start-Process -PassThru -NoNewWindow -RedirectStandardOutput` 替代 `Start-Job`，可控超时、可控输出。
2. 或明确放弃并行，串行 + 缓存 `.godot/` 已足够快。

---

## 五、返工清单（按优先级）

| # | 问题 | 返工动作 | 阻塞级别 |
|---|---|---|---|
| C1 | `--check-only --script` 语义错误 | 实测三条命令，改用 `--editor --quit` 做全量语法检查 | **阻塞** |
| C2 | 门禁参数未验证注册 | grep `main.gd`，加参数存在性预检，未知参数 `quit(2)` | **阻塞** |
| C3 | diff 基线语义不一致 | 统一 `base...HEAD`，浅克隆报错，处理 rename/delete | **阻塞** |
| C4 | glob 实现有 bug | 改用 `pathspec` 或 `WildcardPattern` | 高 |
| C5 | smoke-test tags 过宽 | 收窄 tags 或移出交集 | 高 |
| C6 | A2/A6 断言矛盾 | 明确 `tests-only` 语义，修断言 | 高 |
| C7 | 测试脚本自身改动漏测 | 加 `tests/<name>.gd` → 门禁映射 | 高 |
| C8 | user-data-dir 隔离不完整 | 每门禁独立目录 + 跑前清空 + 路径含空格测试 | 高 |
| C9 | stress-test 触发条件错误 | 明确覆盖目标，price.csv 不触发 stress | 中 |
| C10 | test_plan.json 字段不一致 | 统一含 compile | 中 |
| C11 | `--mode full` 死代码 | 删或给不同语义 | 中 |
| C12 | `need_import` 漏源资产 | 加 `.png/.wav/.glb` 等 | 中 |
| C13 | 无超时 | `Wait-Process -Timeout` | 中 |
| C14 | A9 断言不可执行 | 改为 mtime 对比或删除 | 中 |
| C15 | 缺负向测试 | 每规则补命中/不命中用例 | 中 |
| C16 | test_plan.json 写入时机不明 | 明确语义，追加 results | 低 |
| C17 | 并行竞态 | 改 `Start-Process` 或放弃并行 | 低 |

---

## 六、两份方案的取舍建议

**主方案的问题**：PowerShell 手写 glob、`--check-only --script` 语义错误、断言自相矛盾、无超时、无并行。

**独立方案的问题**：smoke-test tags 过宽导致"按需选测"名不副实、`--mode full` 死代码、`need_import` 漏源资产、并行竞态、同样没验证 `main.gd` 参数。

**建议**：
- **决策核心用独立方案的 Python**（可单测、跨平台），但**修 C5（smoke tags）和 C11（full 死代码）**。
- **编译检查用主方案的"永远先跑"结构**，但**改用 `--editor --quit`**（修 C1）。
- **diff 采集用独立方案的 `git diff + ls-files --others`**，但**加浅克隆检测和 rename 处理**（修 C3）。
- **断言集用主方案的 A1–A10 框架**，但**修 A2/A6 矛盾、A9 不可执行**（修 C6/C14），**补负向用例**（修 C15）。
- **user-data-dir 用独立方案的"每测试独立目录"**（修 C8）。
- **超时和并行用 `Start-Process`**（修 C13/C17）。

**最终交付前必须做的验证**（缺一不可）：
1. `grep -n '"--' scripts/main.gd` 输出贴进方案。
2. 三条 Godot 编译检查命令的实测退出码和耗时贴进方案。
3. `pytest tools/test_select_tests.py` 全绿，且包含 C15 的负向用例。
4. 手动跑一次 `run_tests.ps1 -Mode auto` 改 `docs/README.md`，确认 `test_plan.json` 的 `gates` 与 A2 一致。
5. 手动跑一次 `run_tests.ps1 -Mode auto` 改 `CHANGELOG.md`，确认 A6 是否真的走 fallback（当前会失败）。

## 综合决策

# 最终可执行方案：diff 驱动测试选择入口

> 综合决策 Agent 输出。合并主方案（结构清晰、断言完整）、独立方案（Python 决策核心、标签体系、收益量化）与批判报告（17 项返工要求），产出**唯一可执行方案**。所有批判中的阻塞项已内联修复。

---

## 0. 决策摘要

| 决策点 | 采纳 | 理由 |
|---|---|---|
| 决策核心语言 | **Python**（独立方案） | 可单测、跨平台、CI 可直调；PS 只做 Godot 调度 |
| 选择模型 | **标签交集 + 强制升级规则**（独立方案，修 C5） | 比路径前缀语义准确；smoke-test 移出交集 |
| 编译检查 | **`--editor --quit` 全量解析**（修 C1） | `--check-only --script` 语义错误，不可用 |
| diff 采集 | **`base...HEAD` + 未跟踪 + rename/delete**（修 C3） | 统一 PR 语义，浅克隆显式报错 |
| user-data-dir | **每门禁独立目录 + 跑前清空**（修 C8） | 消除测试间存档污染 |
| 失败策略 | **编译失败即停；测试失败收集全部后汇总**（独立方案） | 一次跑完知道所有坏点 |
| 超时 | **`Start-Process -PassThru` + `Wait-Process -Timeout`**（修 C13） | 防 Godot 死循环挂死 CI |
| 并行 | **默认串行；`-Parallel` 用 `Start-Process`**（修 C17） | 避免 `Start-Job` 竞态 |
| 门禁参数 | **启动前静态预检 `main.gd`**（修 C2） | 未知参数必须 fail，不允许静默通过 |
| 断言集 | **主方案 A1–A10 框架 + 负向用例**（修 C6/C14/C15） | 覆盖命中与不命中 |

---

## 1. 门禁与参数（唯一事实源）

**落地前必跑**（结果写入 `docs/TEST_SELECTION.md`）：

```bash
grep -n '"--' scripts/main.gd
```

预期输出（若缺项，**先补 `main.gd` 再启用本方案**）：

```gdscript
"--scene-check"   -> run_scene_check()
"--world-systems" -> run_world_systems()
"--smoke-test"    -> run_smoke_test()
"--economy-check" -> run_economy_check()
"--stress-test"   -> run_stress_test()
"--spot-city"     -> run_spot_city()
"--full-simulation" -> run_full_simulation()
"--playtest"      -> run_playtest()
"--list-gates"    -> print_gates_and_quit(0)   # 新增，供预检
```

**`main.gd` 必须新增**：

```gdscript
# 未知参数处理：必须 quit(2)，不允许静默通过
func _parse_args() -> void:
    var known := {
        "--scene-check": run_scene_check,
        "--world-systems": run_world_systems,
        "--smoke-test": run_smoke_test,
        "--economy-check": run_economy_check,
        "--stress-test": run_stress_test,
        "--spot-city": run_spot_city,
        "--full-simulation": run_full_simulation,
        "--playtest": run_playtest,
        "--list-gates": func(): print_gates(); get_tree().quit(0),
    }
    for arg in OS.get_cmdline_user_args():
        if arg in known:
            known[arg].call()
        else:
            push_error("未知门禁参数: %s" % arg)
            get_tree().quit(2)
```

**门禁 → 参数 → 超时**：

| 门禁 ID | CLI 参数 | 超时(s) | 窗口 |
|---|---|---|---|
| `compile` | `--editor --quit` | 120 | headless |
| `scene-check` | `-- --scene-check` | 120 | headless |
| `world-systems` | `-- --world-systems` | 180 | headless |
| `smoke-test` | `-- --smoke-test` | 60 | headless |
| `economy-check` | `-- --economy-check` | 120 | headless |
| `stress-test` | `-- --stress-test` | 300 | headless |
| `spot-city` | `-- --spot-city` | 120 | headless |
| `full-simulation` | `-- --full-simulation` | 600 | headless |
| `playtest` | `--resolution 1280x720 -- --playtest` | 600 | **窗口** |

> **七项** = scene-check / world-systems / smoke-test / economy-check / stress-test / spot-city / full-simulation。`playtest` 为 release 附加。auto 模式最多选 6 项（不含 full-simulation）。

---

## 2. 标签体系（修 C5）

### 2.1 标签规则

```python
TAG_RULES = [
    ("scene",   ["scenes/", "scripts/gameplay/world", "scripts/gameplay/area",
                 "scripts/gameplay/scene_router", "data/csv/scene_zones.csv",
                 "data/csv/visual_bindings", "autoload/world_graph.gd"]),
    ("world",   ["scripts/systems/", "scripts/managers/", "scripts/gameplay/farm",
                 "scripts/gameplay/pet", "scripts/gameplay/room", "scripts/gameplay/staff",
                 "scripts/gameplay/story", "scripts/gameplay/family",
                 "data/csv/", "tests/world_systems_test.gd"]),
    ("economy", ["scripts/economy/", "scripts/business/", "scripts/gameplay/business",
                 "data/csv/menu_pool", "data/csv/pipeline", "data/csv/price",
                 "data/csv/wage", "data/csv/goods", "data/csv/recipes",
                 "tests/economy_check.gd"]),
    ("ui",      ["scripts/ui/", "scenes/ui/", "data/csv/theme_", "data/csv/ui_"]),
    ("npc",     ["scripts/npc/", "scripts/gameplay/npc", "data/csv/npc_",
                 "data/csv/dialogue"]),
    ("save",    ["scripts/save/", "scripts/systems/save", "scripts/autoload/save",
                 "data/save_schema"]),
    ("art",     ["assets/", "tools/generate_"]),
    ("build",   [".ps1", "tools/", "export_presets.cfg", "project.godot"]),
    ("docs",    ["docs/", ".md"]),
]
```

### 2.2 测试 → 标签映射（**smoke-test 已收窄**）

```python
TEST_MAP = {
    "scene-check":   {"tags": {"scene"}},
    "world-systems": {"tags": {"world", "npc", "save"}},
    "smoke-test":    {"tags": {"build", "autoload"}},   # 修 C5：不再含全部标签
    "economy-check": {"tags": {"economy"}},
    "stress-test":   {"tags": {"economy", "save"}},     # 见 §2.4 触发收窄
    "spot-city":     {"tags": {"scene", "npc"}},
    "full-simulation": {"tags": set()},                 # 仅 release
    "playtest":      {"tags": {"ui", "scene"}, "windowed": True},
}
ALL_TESTS = ["scene-check", "world-systems", "smoke-test",
             "economy-check", "stress-test", "spot-city", "full-simulation"]
```

### 2.3 强制升级规则（修 C2/C7）

```python
FORCE_RULES = [
    # autoload 是全局单例，破坏面最大
    (["scripts/autoload/"], ["smoke-test", "world-systems"]),
    # 构建配置破坏面大
    (["project.godot", "export_presets.cfg"], ["smoke-test"]),
    # 测试脚本自身改动 → 跑对应门禁（修 C7）
    (["tests/scene_check.gd"], ["scene-check"]),
    (["tests/world_systems_test.gd"], ["world-systems"]),
    (["tests/economy_check.gd"], ["economy-check"]),
    (["tests/smoke_test.gd"], ["smoke-test"]),
    (["tests/stress_test.gd"], ["stress-test"]),
    (["tests/spot_city.gd"], ["spot-city"]),
    (["tests/full_simulation.gd"], ["full-simulation"]),
    # 共享测试基础设施 → 全跑（保守）
    (["tests/_helpers/", "tests/framework/"], ALL_TESTS),
]
```

### 2.4 stress-test 触发收窄（修 C9）

`stress-test` 是 100 月经济压力测试，**不校验单个物价正确性**。因此：

- `data/csv/price*.csv` 改动 → 触发 `economy-check`（物价校验），**不触发** `stress-test`。
- `data/csv/wage*.csv`、`scripts/systems/save*.gd`、`scripts/economy/**` 改动 → 触发 `stress-test`（系统性参数）。

实现：`stress-test` 的 tags 保留 `{"economy", "save"}`，但在 `select()` 中对 `stress-test` 加**排除规则**：

```python
def _stress_allowed(files: list[str]) -> bool:
    """price.csv 单独改动不触发 stress-test。"""
    systemic = any(
        f.startswith(("scripts/economy/", "scripts/systems/save"))
        or "wage" in f or "save_schema" in f
        for f in files
    )
    return systemic
```

### 2.5 选择规则

1. 计算 diff 命中标签集 `T`。
2. 选中所有 `tags ∩ T ≠ ∅` 的测试。
3. `stress-test` 额外经 `_stress_allowed` 过滤。
4. `T` 为空（仅 docs）→ **不跑任何测试**，直接通过。
5. `T` 含 `build` → 强制加 `smoke-test`。
6. `T` 含 `autoload` → 强制加 `smoke-test` + `world-systems`。
7. `tests-only` 语义（修 C6）：**改 `tests/**` 或 `docs/**` 或 `*.md`，且无其他标签命中** → 只跑 `compile`。
8. release 模式 → 忽略选择，跑全部七项 + playtest。

---

## 3. 文件清单

| 文件 | 操作 | 说明 |
|---|---|---|
| `run_tests.ps1` | **替换** | 唯一入口，薄壳 |
| `tools/select_tests.py` | **新增** | 决策核心，可单测 |
| `tools/test_select_tests.py` | **新增** | pytest 用例（含负向） |
| `tools/compile_check.ps1` | **新增** | 编译检查（`--editor --quit`） |
| `tools/gate_registry.json` | **新增** | 门禁 → 参数 → 超时（数据驱动） |
| `scripts/main.gd` | **修改** | 补 `--list-gates` + 未知参数 `quit(2)` |
| `build_release.ps1` | **修改** | 改调 `run_tests.ps1 -Mode release`，删重复代码 |
| `artifacts/test_plan.json` | 运行产物 | 加入 `.gitignore` |
| `docs/TEST_SELECTION.md` | **新增** | 本方案落库 |

---

## 4. 实现

### 4.1 `tools/select_tests.py`

```python
#!/usr/bin/env python3
"""根据 git diff 选择测试。输出 JSON 到 stdout。"""
from __future__ import annotations
import argparse, json, subprocess, sys
from pathlib import Path

TAG_RULES = [
    ("scene",   ["scenes/", "scripts/gameplay/world", "scripts/gameplay/area",
                 "scripts/gameplay/scene_router", "data/csv/scene_zones.csv",
                 "data/csv/visual_bindings", "autoload/world_graph.gd"]),
    ("world",   ["scripts/systems/", "scripts/managers/", "scripts/gameplay/farm",
                 "scripts/gameplay/pet", "scripts/gameplay/room", "scripts/gameplay/staff",
                 "scripts/gameplay/story", "scripts/gameplay/family",
                 "data/csv/", "tests/world_systems_test.gd"]),
    ("economy", ["scripts/economy/", "scripts/business/", "scripts/gameplay/business",
                 "data/csv/menu_pool", "data/csv/pipeline", "data/csv/price",
                 "data/csv/wage", "data/csv/goods", "data/csv/recipes",
                 "tests/economy_check.gd"]),
    ("ui",      ["scripts/ui/", "scenes/ui/", "data/csv/theme_", "data/csv/ui_"]),
    ("npc",     ["scripts/npc/", "scripts/gameplay/npc", "data/csv/npc_",
                 "data/csv/dialogue"]),
    ("save",    ["scripts/save/", "scripts/systems/save", "scripts/autoload/save",
                 "data/save_schema"]),
    ("art",     ["assets/", "tools/generate_"]),
    ("build",   [".ps1", "tools/", "export_presets.cfg", "project.godot"]),
    ("docs",    ["docs/", ".md"]),
]

TEST_MAP = {
    "scene-check":   {"tags": {"scene"}},
    "world-systems": {"tags": {"world", "npc", "save"}},
    "smoke-test":    {"tags": {"build", "autoload"}},
    "economy-check": {"tags": {"economy"}},
    "stress-test":   {"tags": {"economy", "save"}},
    "spot-city":     {"tags": {"scene", "npc"}},
    "full-simulation": {"tags": set()},
    "playtest":      {"tags": {"ui", "scene"}, "windowed": True},
}
ALL_TESTS = ["scene-check", "world-systems", "smoke-test",
             "economy-check", "stress-test", "spot-city", "full-simulation"]

FORCE_RULES = [
    (["scripts/autoload/"], ["smoke-test", "world-systems"]),
    (["project.godot", "export_presets.cfg"], ["smoke-test"]),
    (["tests/scene_check.gd"], ["scene-check"]),
    (["tests/world_systems_test.gd"], ["world-systems"]),
    (["tests/economy_check.gd"], ["economy-check"]),
    (["tests/smoke_test.gd"], ["smoke-test"]),
    (["tests/stress_test.gd"], ["stress-test"]),
    (["tests/spot_city.gd"], ["spot-city"]),
    (["tests/full_simulation.gd"], ["full-simulation"]),
    (["tests/_helpers/", "tests/framework/"], ALL_TESTS),
]

# 需要资源导入的源资产扩展名（修 C12）
IMPORT_EXTS = (".gd", ".tscn", ".tres", ".res", ".png", ".jpg", ".jpeg",
               ".wav", ".ogg", ".mp3", ".glb", ".gltf", ".svg", ".ttf", ".otf")


def git_changed_files(root: Path, base: str, local: bool) -> list[str]:
    """返回变更文件列表。base 为空且 local=True 用工作区；否则用 base...HEAD。"""
    if subprocess.run(["git", "-C", str(root), "rev-parse", "--is-shallow-repository"],
                      capture_output=True, text=True).stdout.strip() == "true":
        raise RuntimeError("浅克隆仓库：请先 git fetch --unshallow 或显式传 --base")

    if base:
        # PR 语义：merge-base 三点 diff，含 rename/delete（修 C3）
        args = ["git", "-C", str(root), "diff", "-M", "--name-status", f"{base}...HEAD"]
    elif local:
        args = ["git", "-C", str(root), "diff", "-M", "--name-status", "HEAD"]
    else:
        args = ["git", "-C", str(root), "diff", "-M", "--name-status", "HEAD~1...HEAD"]

    out = subprocess.run(args, capture_output=True, text=True, check=True).stdout
    files: list[str] = []
    for line in out.splitlines():
        parts = line.split("\t")
        if not parts:
            continue
        status = parts[0]
        if status.startswith("R") and len(parts) >= 3:
            files += [parts[1], parts[2]]   # rename：旧+新都纳入
        elif len(parts) >= 2:
            files.append(parts[1])          # A/M/D 都纳入

    # 未跟踪文件（新文件常是新增场景/系统）
    untracked = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--others", "--exclude-standard"],
        capture_output=True, text=True, check=True).stdout
    files += [f.strip() for f in untracked.splitlines() if f.strip()]
    return sorted(set(files))


def classify(files: list[str]) -> set[str]:
    tags: set[str] = set()
    for f in files:
        for tag, patterns in TAG_RULES:
            if any(p in f for p in patterns):
                tags.add(tag)
    return tags


def _stress_allowed(files: list[str]) -> bool:
    """price.csv 单独改动不触发 stress-test（修 C9）。"""
    return any(
        f.startswith(("scripts/economy/", "scripts/systems/save"))
        or "wage" in f or "save_schema" in f
        for f in files
    )


def select(files: list[str], mode: str) -> dict:
    if mode == "release":
        return {"tests": ALL_TESTS + ["playtest"], "tags": sorted(classify(files)),
                "reason": "release 模式：全量七项 + playtest"}

    tags = classify(files)
    # tests-only 语义（修 C6）：仅 tests/docs/md 命中，且无其他标签
    only_tests = bool(tags) and tags <= {"docs"} and all(
        f.startswith(("tests/", "docs/")) or f.endswith(".md") for f in files
    )
    if only_tests:
        return {"tests": [], "tags": sorted(tags),
                "reason": "仅测试/文档改动，只跑 compile"}

    if not tags:
        return {"tests": [], "tags": [], "reason": "无相关变更"}

    chosen = {t for t, spec in TEST_MAP.items() if spec["tags"] & tags}
    if "stress-test" in chosen and not _stress_allowed(files):
        chosen.discard("stress-test")

    forced: list[str] = []
    for patterns, extra in FORCE_RULES:
        if any(any(p in f for p in patterns) for f in files):
            forced += extra
    chosen |= set(forced)

    ordered = [t for t in ALL_TESTS if t in chosen]
    return {"tests": ordered, "tags": sorted(tags),
            "reason": f"命中标签 {sorted(tags)}" + (f"；强制追加 {forced}" if forced else "")}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--base", default="")
    ap.add_argument("--local", action="store_true", help="本地模式：工作区 vs HEAD")
    ap.add_argument("--mode", choices=["auto", "release"], default="auto")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    try:
        files = git_changed_files(root, args.base, args.local)
    except RuntimeError as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        return 3

    result = select(files, args.mode)
    result["files"] = files
    result["need_import"] = any(f.endswith(IMPORT_EXTS) for f in files)
    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(f"标签: {result['tags']}")
        print(f"测试: {result['tests'] or '（无）'}")
        print(f"原因: {result['reason']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

### 4.2 `tools/compile_check.ps1`（修 C1）

```powershell
param(
    [Parameter(Mandatory)][string]$GodotPath,
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$UserDataDir,
    [int]$TimeoutSec = 120
)
$ErrorActionPreference = "Stop"

# 唯一可靠的编译检查：--editor --quit 全量导入即解析所有 .gd/.tscn
$p = Start-Process -FilePath $GodotPath `
    -ArgumentList @("--headless", "--editor", "--path", $Root,
                    "--user-data-dir", $UserDataDir, "--quit") `
    -NoNewWindow -PassThru -RedirectStandardOutput "$UserDataDir\compile.log" `
    -RedirectStandardError "$UserDataDir\compile.err"

if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    $p.Kill(); throw "编译检查超时（${TimeoutSec}s）"
}
if ($p.ExitCode -ne 0) {
    Get-Content "$UserDataDir\compile.err" -Tail 50 | Write-Host
    throw "Godot 编译检查失败，退出码 $($p.ExitCode)"
}
Write-Host "COMPILE_CHECK_PASS"
```

> **说明**：`--check-only --script` 在 Godot 4.2 是"运行脚本后退出"，不是语法检查（批判 C1）。`--editor --quit` 是唯一可靠的全量解析手段。若嫌慢，用 `.godot/` 缓存；CI 首次冷启动约 30–60s，后续增量约 5–10s。

### 4.3 `run_tests.ps1`（替换）

```powershell
param(
    [ValidateSet("auto","release")][string]$Mode = "auto",
    [string]$Base = "",
    [switch]$Local,          # 本地模式：工作区 vs HEAD
    [switch]$Parallel,
    [switch]$DryRun,
    [switch]$NoCompileCheck
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$artifacts = Join-Path $root "artifacts"
New-Item -ItemType Directory -Force -Path $artifacts | Out-Null

# ---- 1. 定位 Godot ----
$godot = Get-ChildItem -LiteralPath (Join-Path $root ".tools\godot") `
    -Filter "Godot_v*-stable_win64_console.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $godot) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $cmd) { throw "未找到 Godot 4.2+。请安装或恢复 .tools/godot 便携版。" }
    $godotPath = $cmd.Source
} else { $godotPath = $godot.FullName }

# ---- 2. 门禁参数存在性预检（修 C2）----
$mainGd = Join-Path $root "scripts\main.gd"
$registered = Select-String -Path $mainGd -Pattern '"--([a-z-]+)"' -AllMatches |
    ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }
$required = @("scene-check","world-systems","smoke-test","economy-check",
              "stress-test","spot-city","full-simulation","playtest","list-gates")
$missing = $required | Where-Object { $_ -notin $registered }
if ($missing) {
    throw "main.gd 未注册门禁参数: $($missing -join ', ')。请先补注册再运行。"
}

# ---- 3. 决策：调 Python 选测试 ----
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { throw "需要 Python 3 运行 tools/select_tests.py。" }
$pyArgs = @((Join-Path $root "tools\select_tests.py"), "--root", $root,
            "--mode", $Mode, "--json")
if ($Base) { $pyArgs += @("--base", $Base) }
if ($Local) { $pyArgs += "--local" }
$json = & python @pyArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host $json
    throw "测试选择失败（退出码 $LASTEXITCODE）。"
}
$plan = $json | ConvertFrom-Json

Write-Host "== 测试计划 ==" -ForegroundColor Cyan
Write-Host "  标签: $($plan.tags -join ', ')"
Write-Host "  测试: $(if ($plan.tests) { $plan.tests -join ', ' } else { '（无）' })"
Write-Host "  原因: $($plan.reason)"

# ---- 4. 写 test_plan.json（选测后立即写，修 C16）----
$planOut = [pscustomobject]@{
    mode = $Mode; base = $Base; local = [bool]$Local
    changed = @($plan.files); tags = @($plan.tags)
    gates = @("compile") + @($plan.tests)   # 统一含 compile（修 C10）
    reason = $plan.reason
    timestamp = (Get-Date).ToString("o")
    results = @()
}
$planPath = Join-Path $artifacts "test_plan.json"
$planOut | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $planPath -Encoding UTF8

if ($DryRun) { exit 0 }

# ---- 5. 编译检查（永远先跑）----
if (-not $NoCompileCheck) {
    Write-Host "== 编译检查 ==" -ForegroundColor Cyan
    $compileUd = Join-Path $root ".tools\test_userdata\compile"
    New-Item -ItemType Directory -Force -Path $compileUd | Out-Null
    & (Join-Path $root "tools\compile_check.ps1") `
        -GodotPath $godotPath -Root $root -UserDataDir $compileUd
}

# ---- 6. 执行测试 ----
if (-not $plan.tests -or $plan.tests.Count -eq 0) {
    Write-Host "无测试需要运行，通过。" -ForegroundColor Green
    exit 0
}

$timeouts = @{
    "scene-check"=120; "world-systems"=180; "smoke-test"=60;
    "economy-check"=120; "stress-test"=300; "spot-city"=120;
    "full-simulation"=600; "playtest"=600
}
$failures = @()
$results = @()

function Invoke-GodotTest([string]$name) {
    Write-Host "== 运行 $name ==" -ForegroundColor Cyan
    # 每门禁独立 user-data-dir + 跑前清空（修 C8）
    $ud = Join-Path $root ".tools\test_userdata\$name"
    if (Test-Path $ud) { Remove-Item -Recurse -Force $ud }
    New-Item -ItemType Directory -Force -Path $ud | Out-Null

    $argList = if ($name -eq "playtest") {
        @("--path", $root, "--user-data-dir", $ud,
          "--resolution", "1280x720", "--", "--playtest")
    } else {
        @("--headless", "--path", $root, "--user-data-dir", $ud, "--", "--$name")
    }

    $log = Join-Path $ud "run.log"
    $p = Start-Process -FilePath $godotPath -ArgumentList $argList `
        -NoNewWindow -PassThru -RedirectStandardOutput $log `
        -RedirectStandardError "$ud\run.err"

    $timeout = $timeouts[$name] * 1000
    if (-not $p.WaitForExit($timeout)) {
        $p.Kill()
        Write-Host "  $name 超时（$($timeouts[$name])s）" -ForegroundColor Red
        $script:failures += $name
        $script:results += [pscustomobject]@{ gate=$name; code=-1; reason="timeout" }
        return
    }
    $code = $p.ExitCode
    $script:results += [pscustomobject]@{ gate=$name; code=$code; reason="" }
    if ($code -ne 0) {
        Get-Content "$ud\run.err" -Tail 30 | Write-Host
        $script:failures += $name
    }
}

if ($Parallel -and $plan.tests.Count -gt 1) {
    # 并行：Start-Process 可控超时与输出（修 C17）
    $procs = @()
    foreach ($t in $plan.tests) {
        $ud = Join-Path $root ".tools\test_userdata\$t"
        if (Test-Path $ud) { Remove-Item -Recurse -Force $ud }
        New-Item -ItemType Directory -Force -Path $ud | Out-Null
        $argList = @("--headless", "--path", $root, "--user-data-dir", $ud, "--", "--$t")
        $procs += [pscustomobject]@{
            Name = $t
            Proc = Start-Process -FilePath $godotPath -ArgumentList $argList `
                -NoNewWindow -PassThru -RedirectStandardOutput "$ud\run.log" `
                -RedirectStandardError "$ud\run.err"
        }
    }
    foreach ($item in $procs) {
        $timeout = $timeouts[$item.Name] * 1000
        if (-not $item.Proc.WaitForExit($timeout)) {
            $item.Proc.Kill()
            $failures += $item.Name
            $results += [pscustomobject]@{ gate=$item.Name; code=-1; reason="timeout" }
        } else {
            $results += [pscustomobject]@{ gate=$item.Name; code=$item.Proc.ExitCode; reason="" }
            if ($item.Proc.ExitCode -ne 0) { $failures += $item.Name }
        }
    }
} else {
    foreach ($t in $plan.tests) { Invoke-GodotTest $t }
}

# ---- 7. 追加 results 到 test_plan.json（修 C16）----
$planOut.results = $results
$planOut | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $planPath -Encoding UTF8

if ($failures.Count -gt 0) {
    Write-Host "失败: $($failures -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "ALL_SELECTED_TESTS_PASS" -ForegroundColor Green
exit 0
```

### 4.4 `build_release.ps1` 改动

```powershell
# 删除原有的 Invoke-GodotTest 定义与七次调用，替换为：
& (Join-Path $root "run_tests.ps1") -Mode release
if ($LASTEXITCODE -ne 0) { throw "测试失败，已停止打包。" }
```

---

## 5. 执行步骤

```powershell
# 本地开发（工作区 vs HEAD）
.\run_tests.ps1 -Local

# PR 门禁（CI 传入 base sha）
.\run_tests.ps1 -Base $env:GITHUB_BASE_SHA

# 只看计划不执行
.\run_tests.ps1 -Local -DryRun

# 手动指定改动（CI 传入）
.\run_tests.ps1 -Base origin/main

# 发布前全量
.\run_tests.ps1 -Mode release

# 并行（本地全跑加速）
.\run_tests.ps1 -Mode release -Parallel
```

CI 建议：

```yaml
- run: pwsh -File run_tests.ps1 -Base ${{ github.event.pull_request.base.sha }}
- uses: actions/upload-artifact@v4
  with: { name: test_plan, path: artifacts/test_plan.json }
```

---

## 6. 验证（可执行断言）

| # | 断言 | 命令 | 期望 |
|---|---|---|---|
| A1 | 编译失败即停 | 在 `scripts/main.gd` 加 `func (` | 退出码 ≠0，`test_plan.json` 的 `results` 为空 |
| A2 | 只改 docs → 只跑 compile | `-Local -DryRun` 改 `docs/README.md` | `gates == ["compile"]` |
| A3 | 改场景 → scene-check + spot-city | 改 `scenes/street.tscn` | `gates` 含 `scene-check`、`spot-city`，不含 `economy-check` |
| A4 | 改 price.csv → 只 economy-check（修 C9） | 改 `data/csv/price.csv` | `gates` 含 `economy-check`，**不含** `stress-test` |
| A5 | 改 wage.csv → economy + stress | 改 `data/csv/wage.csv` | `gates` 含 `economy-check`、`stress-test` |
| A6 | 改测试脚本 → 跑对应门禁（修 C7） | 改 `tests/scene_check.gd` | `gates` 含 `scene-check` |
| A7 | 改 autoload → smoke + world | 改 `scripts/autoload/game_state.gd` | `gates` 含 `smoke-test`、`world-systems` |
| A8 | 改 farm.gd → 只 world-systems（负向） | 改 `scripts/gameplay/farm.gd` | `gates` 含 `world-systems`，**不含** `scene-check` |
| A9 | 改 economy/market.gd → 不含 scene-check（负向） | 改 `scripts/economy/market.gd` | `gates` 不含 `scene-check` |
| A10 | 空 diff → 不跑测试 | `-Local -DryRun` 无改动 | `gates == ["compile"]` |
| A11 | release 跑全七项 + playtest | `-Mode release -DryRun` | `gates` 长度 = 9（compile + 7 + playtest） |
| A12 | 门禁失败传播 | 临时把 `scene_check.gd` 的 `quit(0)` 改 `quit(1)` | 退出码 ≠0，`results` 
