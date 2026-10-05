$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$version = "0.5.0"
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

if (Get-Command python -ErrorAction SilentlyContinue) {
    Write-Host "生成像素美术资产..."
    & python (Join-Path $root "tools\generate_pixel_art.py")
    if ($LASTEXITCODE -ne 0) { throw "像素美术资产生成失败。" }
    & python (Join-Path $root "tools\generate_audio_placeholders.py")
    if ($LASTEXITCODE -ne 0) { throw "占位音频资产生成失败。" }
}

Write-Host "导入新增美术资源..."
& $godotPath --headless --editor --path $root --quit
if ($LASTEXITCODE -ne 0) { throw "美术资源导入失败。" }

Get-ChildItem -LiteralPath (Join-Path $root "data") -Filter "*.csv" -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination ($_.FullName + ".txt") -Force
}

function Invoke-GodotTest([string]$label, [string[]]$arguments) {
    Write-Host "运行 $label..."
    & $godotPath @arguments
    if ($LASTEXITCODE -ne 0) { throw "$label 失败，已停止打包。" }
}

$previousAppData = $env:APPDATA
$testUserData = Join-Path $root (".tools\test_userdata\build_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force -Path $testUserData | Out-Null
$env:APPDATA = $testUserData

Invoke-GodotTest "冒烟测试" @("--headless", "--path", $root, "--", "--smoke-test")
Invoke-GodotTest "完整经营与收集模拟" @("--headless", "--path", $root, "--", "--full-simulation")
Invoke-GodotTest "农场宠物房间员工与早餐检查" @("--headless", "--path", $root, "--", "--world-systems")
Invoke-GodotTest "实体场景检查" @("--headless", "--path", $root, "--", "--scene-check")
Invoke-GodotTest "经营场景操作检查" @("--headless", "--path", $root, "--", "--economy-check")
Invoke-GodotTest "100 月经济压力测试" @("--headless", "--path", $root, "--", "--stress-test")
Invoke-GodotTest "真实窗口玩家操作测试" @("--path", $root, "--resolution", "1280x720", "--", "--playtest")
$env:APPDATA = $previousAppData

if (Get-Command python -ErrorAction SilentlyContinue) {
    Write-Host "生成 Steam 商店素材包..."
    & python (Join-Path $root "tools\build_steam_store_pack.py")
    if ($LASTEXITCODE -ne 0) { throw "Steam 商店素材包生成失败。" }
}

Write-Host "导出 Windows 发布版..."
& $godotPath --headless --path $root --export-release "Windows Desktop" "release/windows/深城日常.exe"
if ($LASTEXITCODE -ne 0) { throw "Godot 导出失败。" }

$readme = @"
《深城日常》垂直切片 ${version}

运行：
双击“深城日常.exe”。

操作：
WASD / 方向键移动
鼠标左键直接点击经营对象；鼠标右键保留附近互动
I 背包
C 旧物册
M 地图
B 生活账本
J 农场
P 宠物
R 房间装扮提示
H 招工与离职
F1 图鉴 / 商品工序
F2 工作与岗位
F3 服装与穿着
F5 手动保存
F9 读取
Esc 暂停或返回

本版新增：
- 不同商品拥有不同多工序流水线，半成品要手动挪到对应设备。
- 早市、午市、晚市使用不同菜单池，换市会清空未完成备料并损失错过客流。
- 城中村招工与离职：工资期望、诉求、士气、疲劳、欠薪、包住、技能成长和春节返乡潮。
- 早餐店顾客排队与点餐台出餐，和餐馆流水线共用同一套工序。
- 定时自动存档与关键节点自动存档，原子写入并保留 3 份轮转备份。
- 图鉴快捷键、房间手动摆放和多套布置。
- 角色开局待业，餐饮/工厂双职业线和隐含晋升。
- 服装购买、13 个全年节日事件、限定摊主与收集物和四个生活圈地图。
- 亲自经营为主动玩法，有员工时才有很慢的被动收入。
- 星露谷式农场工具与天气经济、NPC 剧情章节和偶发事件。
- 经营操作全部改为场景点击，提示改为 NPC 对话气泡。
- 修复开场空弹窗、部分场景空气墙和无出口问题。
- 早餐店拆分前厅/后厨，新增河边自然景观和多性格、限时出场 NPC。
- 新游戏加入 NPC 剧情章节、偶发事件，背包物品全部显示用途。
- 新增节日场景装饰、年度见闻和限定收集物日期池。
- 新增 8 位 NPC 的个人支线，会随职业、住房、兴趣和旅行经历推进。
- F6 好友合作房间支持真实 ENet 会话和远程玩家位置同步。
- 发行构建会生成 Steam 商店图片、双语文案、成就清单和上传模板。
- 合作房间由房主同步共同资金、库存、店铺、农场、员工和房间状态。
- 角色动画扩展为四帧行走与工作、吃饭、睡觉、交互、拾取动作。
- 城市收藏扩展到 100 件旧物，覆盖五类行情与送礼偏好。
- 新增独立农场圈舍、家畜喂养和蛋奶肉入库。
- 新增物流仓配与手艺技工职业线。
- 人生注脚扩展到四十条生活路线。
- 新增城中村夜市、夜间食材采购、节日小食摊和帮工收入。
- 新增高端住宅区、高层公寓和云端花园住宅。
- 新增物流港仓和手艺工坊两个独立职业场景。
- 新增孩子成长、居家照看和家庭阶段反馈。
- 偶发事件扩展到三十四条生活事件。
- 偶发事件扩展到五十条，覆盖通勤、节日、农场、夜市、维修、宠物和孩子。
- 背包升级为快捷栏+背包+木箱+收购箱，支持扩容和次日结算。
- 餐厅和早餐店支持鼠标左键直点，NPC 不在经营场景来回巡逻。
- 房间装扮改为场景装修模式，支持空位换家具、点地面移动和滚轮旋转。
- 主街扩为多分区城市大地图，场景切换使用门/入口，地图面板显示当前位置。
- 出租屋拆为卧室和生活区，宠物、冰箱、木箱与收购箱不再挤在卧室。
- 玩家选中的物品会绘制在角色手边。
- 新增 NPC 生日、粉色情人节、白色情人节、七夕、教师节、感恩节和圣诞节。
- 成家后新增纪念日、共同夜晚和伴侣约会，也可以离婚并重新开始。
- 真实窗口 Playtest 扩展到 145 步。
"@
Set-Content -LiteralPath (Join-Path $windowsDir "运行说明.txt") -Value $readme -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $root "docs\RELEASE_NOTES_0.5.0.md") -Destination (Join-Path $windowsDir "发行说明.md") -Force
Copy-Item -LiteralPath (Join-Path $root "docs\KNOWN_ISSUES.md") -Destination (Join-Path $windowsDir "已知问题.md") -Force
Copy-Item -LiteralPath (Join-Path $root "docs\游戏预览_0.4.0.png") -Destination (Join-Path $windowsDir "游戏预览.png") -Force

$exePath = Join-Path $windowsDir "深城日常.exe"
$latestExePath = Join-Path ([Environment]::GetFolderPath("Desktop")) "深城日常_最新版.exe"
Copy-Item -LiteralPath $exePath -Destination $latestExePath -Force
$hash = Get-FileHash -LiteralPath $exePath -Algorithm SHA256
$latestHash = Get-FileHash -LiteralPath $latestExePath -Algorithm SHA256
if ($hash.Hash -ne $latestHash.Hash) { throw "桌面最新版哈希与发布版不一致。" }
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
Write-Host "Steam 商店素材：$(Join-Path $root "release\steam_store")"
Write-Host "发布包完成：$zipPath"
Write-Host "桌面最新版：$latestExePath"
Write-Host "桌面版 SHA256：$($latestHash.Hash)"
