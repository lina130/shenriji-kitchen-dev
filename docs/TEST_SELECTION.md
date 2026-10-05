# Diff 驱动测试选择

本方案只新增独立入口，不修改现有的 run_tests.ps1。项目仍可以继续使用旧入口，新的选择器用于日常小步开发。

## 文件和路径

项目根目录：

  C:\Users\18257\Desktop\深日记

新增文件：

  C:\Users\18257\Desktop\深日记\tools\test_map.json
  C:\Users\18257\Desktop\深日记\tools\select_tests.py
  C:\Users\18257\Desktop\深日记\tools\run_selected_tests.ps1
  C:\Users\18257\Desktop\深日记\tools\test_selector_test.py
  C:\Users\18257\Desktop\深日记\docs\TEST_SELECTION.md

默认引擎：

  C:\Users\18257\Desktop\深日记\.tools\godot\Godot_v*-stable_win64_console.exe

脚本只查找项目便携目录里的 Godot 控制台版本，不会默认回退到系统 Godot。只有显式传入 -GodotPath 才会使用别的位置。

## 默认行为

不带参数运行时，run_selected_tests.ps1 会：

1. 读取 git diff 与未跟踪文件。
2. 调用 select_tests.py 生成门禁计划。
3. 先执行 Godot 编译检查。
4. 编译失败立即停止，不执行任何门禁。
5. 只执行与改动相关的门禁。

默认使用：

  git diff -M --name-status HEAD
  git ls-files --others --exclude-standard

PR 或 CI 场景使用：

  -Base origin/main

此时使用：

  git diff -M --name-status origin/main...HEAD

显式传入 -IncludeUntracked 时，base 模式也会把工作区未跟踪文件并入计划。

## 映射规则

test_map.json 路径使用正斜杠和 glob。当前规则按实际仓库目录编写，而不是示例中的 data/csv 目录。

| 改动范围 | 选择的门禁 |
|---|---|
| scenes/、world.gd、scene_router.gd、scene_metadata.csv、scene_zones.csv | scene-check、spot-city |
| autoload/、脚本系统、农场、宠物、房间、NPC、剧情、非经济 CSV | world-systems，autoload 额外强制 smoke-test |
| project.godot、export_presets.cfg、scenes/main.tscn、scripts/main.gd | smoke-test |
| 经营、餐饮、菜单、工序、价格、配方、货物 | economy-check |
| 工资、存档结构、经营经理、经济脚本、系统数值 | stress-test，部分经济文件同时选择 economy-check |
| scene_zones.csv、scene_metadata.csv、npcs.csv、npc_schedule.csv | spot-city |
| scripts/ui/、主题 token、UI 资产、视觉绑定 | smoke-test、scene-check |
| 仅 tests/、docs/、Markdown、选择器自身文件 | 只做编译检查 |

没有命中任何规则的非文档文件会保守回退到：

  smoke-test、world-systems

release 模式忽略 diff，固定执行：

  scene-check、world-systems、smoke-test、economy-check、stress-test、spot-city、full-simulation、playtest

## 使用命令

只生成计划，不执行编译和门禁：

  pwsh -NoProfile -File C:\Users\18257\Desktop\深日记\tools\run_selected_tests.ps1 -DryRun

本地工作区自动选择：

  pwsh -NoProfile -File C:\Users\18257\Desktop\深日记\tools\run_selected_tests.ps1

指定基线：

  pwsh -NoProfile -File C:\Users\18257\Desktop\深日记\tools\run_selected_tests.ps1 -Base origin/main

显式指定改动文件：

  pwsh -NoProfile -File C:\Users\18257\Desktop\深日记\tools\run_selected_tests.ps1 -ChangedFiles scenes/main.tscn

发布模式：

  pwsh -NoProfile -File C:\Users\18257\Desktop\深日记\tools\run_selected_tests.ps1 -Mode release

指定计划输出位置：

  pwsh -NoProfile -File C:\Users\18257\Desktop\深日记\tools\run_selected_tests.ps1 -DryRun -PlanPath .tools\my_test_plan.json

默认计划文件写在忽略目录：

  C:\Users\18257\Desktop\深日记\.tools\test_userdata\test_plan.json

## 直接调用 Python 选择器

只查看结果，不运行 Godot：

  python C:\Users\18257\Desktop\深日记\tools\select_tests.py --root C:\Users\18257\Desktop\深日记 --local --json

模拟场景改动：

  python C:\Users\18257\Desktop\深日记\tools\select_tests.py --root C:\Users\18257\Desktop\深日记 --files scenes/main.tscn --json

模拟工资改动：

  python C:\Users\18257\Desktop\深日记\tools\select_tests.py --root C:\Users\18257\Desktop\深日记 --files data/wage.csv --json

release 计划：

  python C:\Users\18257\Desktop\深日记\tools\select_tests.py --root C:\Users\18257\Desktop\深日记 --mode release --files docs/README.md --json

## 编译检查

run_selected_tests.ps1 使用的编译命令是：

  Godot_v*-stable_win64_console.exe --headless --editor --path PROJECT_ROOT --user-data-dir COMPILE_USER_DATA --quit

编译检查失败时退出码非零，脚本立即抛出错误，后面的门禁不会执行。

普通门禁使用：

  Godot_v*-stable_win64_console.exe --headless --path PROJECT_ROOT --user-data-dir GATE_USER_DATA -- --GATE

playtest 不使用 headless，附加真实窗口参数：

  Godot_v*-stable_win64_console.exe --path PROJECT_ROOT --user-data-dir GATE_USER_DATA --resolution 1280x720 -- --playtest

每个门禁使用独立的 .tools/test_userdata 子目录，避免存档互相污染。计划文件使用 .tools/test_userdata 路径，因此不会出现在 git diff 中。

## 选择器自测

纯逻辑自测不启动 Godot：

  python C:\Users\18257\Desktop\深日记\tools\test_selector_test.py

静态语法检查：

  python -m py_compile C:\Users\18257\Desktop\深日记\tools\select_tests.py C:\Users\18257\Desktop\深日记\tools\test_selector_test.py
  python -m json.tool C:\Users\18257\Desktop\深日记\tools\test_map.json

## 失败传播

编译失败：立即停止，退出码非零。

任意门禁失败：立即停止，退出码非零，后续门禁不执行。

选择器失败：run_selected_tests.ps1 停止，不执行 Godot。

DryRun：只写计划并输出 DRY_RUN_OK，不执行 Godot 编译或门禁。

## 与现有脚本的关系

run_tests.ps1 保持不变。

run_stress_test.ps1 保持不变。

build_release.ps1 保持不变。

新的选择器是独立入口，后续确认稳定后，再由单独任务决定是否把 build_release.ps1 接到 release 模式。
