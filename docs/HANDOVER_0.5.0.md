# 《深日记》0.5.0 交接文档

> 给接手的人/模型：先读这份，再读 `docs/DESIGN_0.5.0_pipeline_and_staff.md`。
> 项目当前是「0.4.0 已发行 + 0.5.0 大量未提交改动」的中间状态。

---

## 1. 项目基本情况

- 路径：`C:\Users\18257\Desktop\深日记`
- 引擎：Godot 4.7.2（便携版在 `.tools/godot/`）
- 类型：2D 都市生活经营模拟（深圳城中村题材），GDScript
- 桌面最新版：`C:\Users\18257\Desktop\深日记_最新版.exe`（已更新为 0.5.0，哈希与 release/windows 版本一致）
- 构建设计约定：`build_release.ps1` 跑测试 → 导出 → 复制到桌面最新版 → 打 zip 到 `release/`

### 怎么跑测试
```powershell
# 控制台便携版
$godot = ".tools\godot\Godot_v4.7.2-stable_win64_console.exe"

& $godot --headless --path . --user-data-dir .tools\test_userdata -- --smoke-test
& $godot --headless --path . --user-data-dir .tools\test_userdata -- --full-simulation
& $godot --headless --path . --user-data-dir .tools\test_userdata -- --world-systems   # 本次新增
& $godot --headless --path . --user-data-dir .tools\test_userdata -- --scene-check
& $godot --headless --path . --user-data-dir .tools\test_userdata -- --economy-check
& $godot --headless --path . --user-data-dir .tools\test_userdata -- --stress-test
& $godot --path . --resolution 1280x720 -- --playtest        # 真实窗口，不要加 --headless
```
测试入口都在 `scripts/main.gd` 的 `_ready()` 里按命令行参数分发。

### 本次会话的测试结果
- `--smoke-test`：**通过**
- `--full-simulation`：**通过**（98 天集齐 24 件旧物，总资产 5 万+）
- `--world-systems`：**通过**（农场/宠物/房间/人手/早餐/作息/新场景）
- `--scene-check`、`--economy-check`：**通过**
- `--playtest`（真实窗口）：**最近一次有效运行是 49 步通过，但 0.5.0 改动后尚未重跑**，必须重跑
- `--stress-test`（100 月）：0.4.0 时代通过，0.5.0 改动后**需重跑确认**

---

## 2. 0.5.0 已经做完并验证的部分

### 新系统（都已接入 autoload 和存档）
| 系统 | 文件 | 数据表 | 说明 |
|---|---|---|---|
| 农场供应链 | `autoload/farm_manager.gd` | `data/crops.csv` | 6 块地、按游戏日生长、受季节限制、浇水 +25%；收割产物**直接进餐馆仓库且成本基准为 0**，利润高于批发 |
| 宠物养成 | `autoload/pet_manager.gd` | `data/pets.csv`、`data/petshop.csv` | 喂食/陪玩/睡觉/洗澡/训练/表演/成长阶段；6 种宠物各带经营加成，按“照料度 × 成长度”缩放 |
| 房间装扮 | `autoload/room_manager.gd` | `data/furniture.csv` | 10 件家具、分类摆放、生活加成；家居超市买下即摆 |
| 店铺人手（基础版） | `autoload/staff_manager.gd` | `data/staff.csv` | 好感度达标才能雇，常驻每日扣工钱，提供厨房速度/耐心/早餐营收/进货折扣 |
| NPC 作息 | `scripts/gameplay/npc_actor.gd` | `data/npc_schedule.csv`、`data/npc_dialogue.csv` | 按小时在不同场景出现，对话分早/中/晚 |

### 新增场景（从城中村街道进入）
城郊农场、宠物商店、家居超市、楼下早餐店 —— 均有独立底图（`area_backdrop.gd`）、碰撞、可交互物、`scene_router.gd` 合法区域。

### 扩充内容
- `data/items.csv`：新增食物/饮品/宠物用品/装饰/种子
- `data/goods.csv`：新增番茄、玉米、牛奶、猪肉
- `data/recipes.csv`：新增早餐类（豆浆/鲜肉包/汤河粉）
- 图鉴面板汇总旧物/宠物/农场/家具/人手（`hud.open_encyclopedia`，**尚未绑按键**）

### 关键接线位置（改动时要一起看）
- `project.godot` → `[autoload]` 新增 FarmManager / PetManager / RoomManager / StaffManager
- `autoload/config_db.gd` → 注册了 crops/pets/petshop/furniture/staff/npc_schedule/npc_dialogue/breakfast/breakfast_menu
- `autoload/game_state.gd` → `_on_day_started` 和 `reset_new_game` 已调用四个新 Manager
- `autoload/save_manager.gd` → 存档键 `farm/pet/room/staff`（`SAVE_VERSION = 4`）
- `autoload/input_setup.gd` → 新增按键 `J`(农场) `P`(宠物) `R`(房间)
- `scripts/main.gd` → 新增 `--world-systems` 等测试分发 + `kitchen_requested` 信号接线
- `autoload/kitchen_manager.gd` → 新增 `start_shift_for(location)`、`_candidate_recipes()`；早餐只派 category=`早餐` 的订单
- `autoload/business_manager.gd` → 新增 `add_farm_goods()`（农场入库、零成本）；早餐类菜谱**始终解锁**

---

## 3. 本轮已完成

1. **多工序流水线**：`recipes.csv` 已加入 `pipeline` 和 `phases`；不同商品工序不同，半成品进入托盘后需手动挪到对应工位。
2. **时段轮换**：早市 06:00–10:30、午市 10:30–15:00、晚市 17:00–23:00；菜单、耐心、价格和需求倍率均已接入。
3. **城中村招工离职**：员工工资期望、诉求、士气、疲劳、欠薪、包住、技能、招聘渠道、春节返乡和多种离职/留人事件已完成。
4. **早餐店点击机制**：顾客排队、点餐台出餐与多工序流水线共用 `KitchenManager`。
5. **一天时长**：默认约现实 48 分钟，`real_seconds_per_game_minute` 可在 `data/balance.csv` 调整。
6. **自动存档**：每 15 游戏分钟及关键节点保存；手动/自动分开、原子替换、3 份轮转备份、损坏自动回退、版本迁移均已完成。
7. **图鉴与房间**：`F1` 打开图鉴；房间支持手动摆放和多套布置。
8. **新增需求**：不同姓名/能力的候选员工、慢速被动经营、实时随机客流、节日限定商品、服装购买、城中村/商业区/工业区/城郊四生活圈地图、玩家餐饮/工厂双职业线和隐含晋升已完成。
9. **窗口体验**：Windows 默认最大化启动，1600×900 初始尺寸，最小分辨率 1280×720，可正常缩放。
10. **交互与场景细化**：经营操作全部场景点击；提示统一为 NPC 对话气泡；早餐店拆分前厅/后厨；新增河边自然景观；NPC 加入性格、用途和限时出场。
11. **轻量叙事**：新游戏 NPC 开场章节、行为触发剧情、每日偶发事件。
12. **发行**：版本升至 `0.5.0`，发行说明与已知问题已更新，`build_release.ps1` 已加入全部 7 项测试。Windows release 与桌面最新版已导出，SHA256 一致（当前 6802E075DE0897AE5456D777C0098453A9ECCC6500910CF3D739FE3B03E939C4）。

## 4. 环境与工具坑（重要，能省很多时间）

本次开发中 `exec_command` 的 shell 选择很不稳定，经常被路由到 **cmd.exe**，导致：
- 多行 here-string（`@'...'@`）报 `''' is not recognized`；
- 含引号/分号的 `python -c` 长命令被截断（`SyntaxError: unterminated string literal`）；
- 连续多条命令里 `> file` 只保留第一条语句的输出。

**可靠做法（已验证）**：
- 写文件用 **`node_repl`**（`mcp__node_repl::js` → `fs.writeFileSync`），中文与多行都稳。
- 只能命令行时，用**单行、短命令**；避免 `\n`/`\t`（JSON 会转义成真换行/制表符破坏语句），需要换行用 `chr(10)`。
- GDScript 里 `->` 在 cmd 的 `echo` 中要写成 `-^>`；`<` 写成 `^<`。

## 5. 代码里的坑

- `config_db._load_table` 对 `npc_id` 为键的 `npc_schedule`/`npc_dialogue` 会把多行**聚合成数组**；判断条件写得比较脆（依赖表名），改动时小心。
- `RoomManager.placed` 的 key 是**分类**（如 `light`），值是家具 id；`is_placed` 按值查。
- `PetManager.feed` 需要背包里有 `pet_feed`。
- `FarmManager.get_available_crops` 只在 `has_farm` 为真时返回结果；季节由 `CalendarManager.get_season_id` 决定（一年 12 个月 × 30 天，1–2 月冬、3–5 春…）。
- 早餐菜谱靠 category=`早餐` 在 `business_manager.get_unlocked_recipe_ids` 里强制解锁。
- 自动存档已完成：定时/关键节点自动保存、手动与自动档分离、原子写入、3 份轮转、损坏回退和 v15 迁移都已接入。
- `hud.gd` 的 `_add_action_button(parent, ...)` 会 `parent.add_child(button)`，传进去的容器**必须先在场景树里**，否则按钮不显示。

## 6. 提交状态

工作区有大量未提交改动（0.5.0 全部内容），最近一次已提交是 0.4.0 相关。建议完成 0.5.0 后**一次性提交**并打 tag。

## 7. 2026-09-27 城市与居住场景增量

- 出租屋拆为 `home` 卧室与 `home_living` 生活区；卧室只留床、书桌、装修和卧室门，冰箱/木箱/收购箱/收音机/宠物/家人/住房升级都在生活区。
- 主街改成 2560×1440 城市大地图，按城中村、商业区、工业区、城郊自然区分区；场景入口按物理位置放置。
- `M` 地图面板显示城市俯瞰图、所属分区和当前位置标记。
- 场景切换使用门/入口交互；`WorldInteractable` 对门和路线绘制专门提示。
- 玩家选中快捷栏物品时会绘制在角色手边。
- 房间装修为场景模式：点空位换家具、点地面移动、滚轮旋转。
- 工厂招聘为登记→现场试工 3 轮→王师傅确认入职。
- 城市大地图只保留最外边界碰撞，已移除未对应画面的空气墙。
- 警告：写文件时务必使用 `fs.writeFile(path, content, encoding)`；曾有脚本误写成 `fs.writeFile(path, encoding)` 把 `world.gd` 覆盖成字面量 `utf8`。本轮已从线程历史完整恢复。
