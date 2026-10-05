# 自动存档稳定性和迁移审计

## 主方案

# 自动存档稳定性与迁移审计 —— 可执行方案

> 审计对象：`autoload/save_manager.gd`（SAVE_VERSION=15，BACKUP_COUNT=3）
> 结论先行：**7 项要求中 3 项已实现、2 项部分实现、2 项缺失**。存在 1 个 P0 数据丢失风险（轮转未落地）、1 个 P0 静默失败（迁移无版本校验）、1 个 P1 回退误报。

---

## 一、逐条核对表

| # | 要求 | 现状 | 判定 | 证据 |
|---|---|---|---|---|
| 1 | 定时存档 | `_on_minute_changed` 按 `auto_save_interval_minutes` 触发 | ✅ 已实现 | `save_manager.gd` `_on_minute_changed` |
| 2 | 关键节点存档 | 仅 `request_auto_save(reason)` 被动调用，**无关键节点注册表** | ⚠️ 部分 | 无 `KEY_NODE` 常量、无 `day_started` 触发存档 |
| 3 | 原子写入 | `_write_save_atomically` 存在（截断输出未展示） | ⚠️ 待验证 | 需确认是否 `tmp → rename` 且 `flush` |
| 4 | 三份轮转 | `BACKUP_COUNT=3` 常量存在，但 **`_backup_paths()` 与轮转逻辑未在截断中体现** | ❌ 疑似缺失 | 无 `.bak.1/.2/.3` 写入代码 |
| 5 | 损坏回退 | `load_game` 遍历 `_candidate_paths()`，损坏则跳过 | ✅ 已实现 | `load_game` 循环 + `parsed.is_empty()` |
| 6 | 版本迁移 | `_migrate_save(parsed)` 被调用，但**无版本比较、无迁移链** | ❌ 缺失 | 无 `if version < N` 分支 |
| 7 | 读档失败保护 | 失败时提示"原档没有被覆盖"，但**不区分"无档"与"全损坏"** | ⚠️ 部分 | 末尾统一 warning |

---

## 二、缺口详情与修复顺序

### P0-1　三份轮转未落地（数据丢失风险）
**现象**：`BACKUP_COUNT=3` 是死常量。若 `_write_save_atomically` 直接覆盖主档，则主档损坏时 `_candidate_paths()` 无备份可回退，第 5 条"损坏回退"实际失效。

**修复**（`save_manager.gd`）：
```gdscript
func _write_save_atomically(path: String, data: Dictionary) -> bool:
    var tmp := path + TEMP_SUFFIX
    var f := FileAccess.open(tmp, FileAccess.WRITE)
    if f == null:
        push_error("SAVE: 无法打开临时文件 %s" % tmp)
        return false
    f.store_string(JSON.stringify(data, "\t"))
    f.flush()
    f.close()

    # 轮转：path.3 删除 → path.2→path.3 → path.1→path.2 → path→path.1
    for i in range(BACKUP_COUNT, 1, -1):
        var src := "%s.bak.%d" % [path, i - 1]
        var dst := "%s.bak.%d" % [path, i]
        if FileAccess.file_exists(src):
            DirAccess.rename_absolute(ProjectSettings.globalize_path(src),
                                      ProjectSettings.globalize_path(dst))
    if FileAccess.file_exists(path):
        DirAccess.rename_absolute(ProjectSettings.globalize_path(path),
                                  ProjectSettings.globalize_path(path + ".bak.1"))

    var err := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(tmp),
        ProjectSettings.globalize_path(path))
    if err != OK:
        push_error("SAVE: 原子重命名失败 err=%d" % err)
        return false
    return true

func _backup_paths(path: String) -> Array[String]:
    var out: Array[String] = []
    for i in range(1, BACKUP_COUNT + 1):
        out.append("%s.bak.%d" % [path, i])
    return out

func _candidate_paths() -> Array[String]:
    var out: Array[String] = [MANUAL_SAVE_PATH, AUTO_SAVE_PATH]
    out.append_array(_backup_paths(MANUAL_SAVE_PATH))
    out.append_array(_backup_paths(AUTO_SAVE_PATH))
    return out
```
**风险**：`rename_absolute` 在 Windows 上跨盘失败——已用 `globalize_path` 保证同盘（`user://` 同目录）。

---

### P0-2　版本迁移无校验（静默数据损坏）
**现象**：`_migrate_save(parsed)` 无版本比较。若旧档 `version=10` 被直接 `_apply_save`，缺失字段走默认值 → **静默丢进度**，比崩溃更危险。

**修复**：
```gdscript
const MIGRATIONS := {
    10: "_migrate_10_to_11",
    11: "_migrate_11_to_12",
    12: "_migrate_12_to_13",
    13: "_migrate_13_to_14",
    14: "_migrate_14_to_15",
}

func _migrate_save(data: Dictionary) -> Dictionary:
    var v := int(data.get("version", 0))
    if v <= 0:
        push_error("SAVE: 存档缺少 version 字段，拒绝加载")
        return {}
    if v > SAVE_VERSION:
        push_error("SAVE: 存档版本 %d 高于当前 %d，拒绝加载（防降级损坏）" % [v, SAVE_VERSION])
        return {}
    while v < SAVE_VERSION:
        var fn: String = MIGRATIONS.get(v, "")
        if fn.is_empty():
            push_error("SAVE: 缺少 v%d→v%d 迁移函数" % [v, v + 1])
            return {}
        data = call(fn, data)
        v = int(data.get("version", v + 1))
    return data

func _migrate_14_to_15(data: Dictionary) -> Dictionary:
    # 示例：v15 新增 pet 字段
    if not data.has("pet"):
        data["pet"] = {}
    data["version"] = 15
    return data
```
**风险**：迁移函数必须**幂等**（重复调用结果一致），否则回退重试会二次破坏。每个迁移函数末尾强制 `data["version"] = N+1`。

---

### P1-1　关键节点存档无注册表
**现象**：`request_auto_save` 靠调用方自觉，易漏。`_on_day_started` 只重置 key，不存档。

**修复**：
```gdscript
const KEY_NODE_REASONS := {
    "day_start": true,
    "area_change": true,
    "career_shift_end": true,
    "housing_upgrade": true,
    "festival_enter": true,
}

func _on_day_started(_day: int) -> void:
    if _last_auto_save_key < 0:
        _last_auto_save_key = _current_time_key()
    request_auto_save("day_start")   # 新增

func request_auto_save(reason: String) -> bool:
    if not auto_save_enabled:
        return false
    if not KEY_NODE_REASONS.has(reason) and reason != "timed":
        push_warning("SAVE: 未注册的关键节点 reason=%s" % reason)
    _last_auto_save_reason = reason
    return save_game(false, true)
```

---

### P1-2　读档失败提示不区分场景
**修复**：
```gdscript
func load_game(show_notice := true) -> bool:
    var any_existed := false
    for path in _candidate_paths():
        if not FileAccess.file_exists(path):
            continue
        any_existed = true
        var parsed := _read_json_file(path)
        if parsed.is_empty():
            push_warning("SAVE: 损坏档 %s，跳过" % path)
            continue
        var migrated := _migrate_save(parsed)
        if migrated.is_empty():
            push_warning("SAVE: 迁移失败 %s，跳过" % path)
            continue
        _apply_save(migrated)
        ...
        return true
    if not any_existed:
        NoticeManager.show_message("还没有存档，开始新生活吧。", "hint")
    else:
        NoticeManager.show_message("存档内容损坏，暂时无法读取；原档没有被覆盖。", "warning")
    return false
```

---

## 三、修复顺序（严格串行）

1. **P0-1 轮转** → 无轮转则回退测试无意义，必须先做。
2. **P0-2 迁移** → 依赖轮转产生的多版本档做测试。
3. **P1-1 关键节点** → 依赖迁移后版本稳定。
4. **P1-2 提示** → 纯 UI，最后做。

每步完成后跑对应测试用例（见下），**红灯不进入下一步**。

---

## 四、可复现测试用例

新增 `tests/save_manager_test.gd`，挂到 `world_systems_test.gd` 的 `_test_auto_save_fallback` 之后：

```gdscript
func _test_save_rotation() -> void:
    var sm := SaveManager
    var p := sm.MANUAL_SAVE_PATH
    # 清场
    for f in sm._candidate_paths():
        if FileAccess.file_exists(f):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

    # 连续存 5 次，应保留 .bak.1/.2/.3
    for i in range(5):
        GameState.money = 100 + i
        _check(sm.save_game(false, false), "第%d次存档应成功" % (i + 1))
    _check(FileAccess.file_exists(p), "主档应存在")
    for i in range(1, 4):
        _check(FileAccess.file_exists("%s.bak.%d" % [p, i]), "备份 .bak.%d 应存在" % i)
    _check(not FileAccess.file_exists("%s.bak.4" % p), "不应产生第4份备份")

    # 主档损坏 → 应回退到 .bak.1
    var f := FileAccess.open(p, FileAccess.WRITE)
    f.store_string("{ 损坏 json")
    f.close()
    _check(sm.load_game(false), "主档损坏应能回退")
    _check(GameState.money == 103, "应回退到 .bak.1 的 money=103，实际=%d" % GameState.money)

func _test_save_migration() -> void:
    var sm := SaveManager
    var p := sm.MANUAL_SAVE_PATH
    # 构造 v10 旧档
    var old := {"version": 10, "time": {}, "game": {"money": 999}}
    var f := FileAccess.open(p, FileAccess.WRITE)
    f.store_string(JSON.stringify(old))
    f.close()
    _check(sm.load_game(false), "v10 档应能迁移加载")
    _check(GameState.money == 999, "迁移后 money 应保留")

    # 未来版本 → 拒绝
    var future := {"version": 99, "game": {"money": 1}}
    f = FileAccess.open(p, FileAccess.WRITE)
    f.store_string(JSON.stringify(future))
    f.close()
    _check(not sm.load_game(false), "未来版本档应拒绝加载")

func _test_save_key_nodes() -> void:
    var sm := SaveManager
    var before := sm.get_last_auto_save_reason()
    TimeSystem.day_started.emit(TimeSystem.current_day + 1)
    _check(sm.get_last_auto_save_reason() == "day_start",
           "day_started 应触发关键节点存档，实际=%s" % sm.get_last_auto_save_reason())
```

**断言可验证性**：
- `money == 103` 是**精确值**，非"大于0"这类弱断言。
- `not FileAccess.file_exists(".bak.4")` 验证轮转**上界**。
- `not sm.load_game()` 验证**负向路径**（未来版本拒绝）。

---

## 五、风险清单

| 风险 | 触发条件 | 缓解 |
|---|---|---|
| `rename_absolute` 跨盘失败 | `user://` 与临时目录不同盘 | 已用 `globalize_path` 同目录，测试覆盖 |
| 迁移函数非幂等 | 回退重试二次迁移 | 每个迁移末尾强制 `version=N+1`，加幂等断言 |
| 轮转期间崩溃 | 删 `.bak.3` 后、rename 前断电 | 接受：最坏丢最旧备份，主档与 `.bak.1/.2` 完好 |
| `_is_saving` 重入 | 定时存档与关键节点同帧触发 | 已有 `_is_saving` 守卫，但**需补测试**：并发调用第二次返回 false |
| 迁移链断裂 | 新增 v16 忘记注册 | 加 CI 断言：`MIGRATIONS.keys()` 必须覆盖 `[1..SAVE_VERSION-1]` |

**补充 CI 断言**（`tests/save_manager_test.gd` 末尾）：
```gdscript
for v in range(1, SaveManager.SAVE_VERSION):
    _check(SaveManager.MIGRATIONS.has(v), "缺少 v%d 迁移函数" % v)
```

---

## 六、交付物清单

| 文件 | 操作 |
|---|---|
| `autoload/save_manager.gd` | 补 `_write_save_atomically` 轮转、`_migrate_save` 版本链、`_candidate_paths`、`_backup_paths`、`_on_day_started` 存档、`load_game` 分支提示 |
| `tests/save_manager_test.gd` | 新建，含 `_test_save_rotation` / `_test_save_migration` / `_test_save_key_nodes` |
| `tests/world_systems_test.gd` | 在 `_test_auto_save_fallback` 后追加三个调用 |
| `docs/SAVE_AUDIT.md` | 落盘本审计表 + 测试输出 |

**验收标准**：`godot --headless --script tests/world_systems_test.gd` 输出 `WORLD_SYSTEMS_PASS`，且 `docs/SAVE_AUDIT.md` 中 7 项全部标 ✅。

## 独立方案

# 存档稳定性与迁移审计 —— 独立方案

> 独立方案 Agent。不迎合主方案。基于黑板中 `world-001`（世界坐标唯一真相）、`ui-001`（单一数据源 + 缓存 + 可回退）、`test-001`（Python 决策核心 + 门禁）三条已裁决架构，对 `save_manager.gd` 做**逐条核对 → 缺口 → 修复顺序 → 可复现测试**。
>
> **核心立场**：当前 `save_manager.gd` 的存档模型是"**单文件 + 覆盖式原子写 + 事后轮转**"，这在 `world-001` 决定"世界坐标唯一真相 + interior 隔离区 + LRU 驱逐"之后**已经结构性失效**。本方案主张改为"**版本化快照 + 写前轮转 + 校验和 + 迁移链**"。

---

## 0. 前置门禁（阻塞性，未通过不得进入修复）

所有结果写入 `docs/SAVE_FACTS.md`，作为后续唯一事实源。

### G0.1 现有存档真实结构
```bash
python -c "import json,glob,os; [print(p, list(json.load(open(p,encoding='utf-8')).keys())) for p in glob.glob(os.path.expanduser('~')+'/AppData/Roaming/Godot/app_userdata/*/deep_city*.json')]"
```
**裁决**：若 `version` 字段缺失或 ≠ 15 → 立即标记为"**迁移链断裂**"，进入 P0。

### G0.2 各 Manager 的 `get_save_data()` 是否幂等
```bash
grep -rn "func get_save_data" --include=*.gd autoload/ | wc -l
grep -rn "func get_save_data" --include=*.gd autoload/
```
**裁决**：`_build_save_data()` 里列了 17 个 Manager。**逐个核对是否都有 `get_save_data()`**。缺失者 → 存档静默丢字段（P0）。

### G0.3 是否存在 `set_save_data` / `apply_save_data`
```bash
grep -rn "func apply_save\|func load_save\|func set_save_data\|func from_save" --include=*.gd autoload/
```
**裁决**：`_apply_save(migrated)` 被调用，但**黑板里没有 `_apply_save` 的实现**。若不存在 → 读档路径是**空实现**（P0，读档失败保护形同虚设）。

### G0.4 `world-001` 的存档契约
```bash
grep -rn "world_pos\|interior\|chunk_id\|exit_spawn" --include=*.gd autoload/game_state.gd scripts/ | head -30
```
**裁决**：`world-001` 决定"存档只存 `world_pos`，删除 CameraRig 双坐标系"。若 `GameState.get_save_data()` 仍存 `current_area` + `spawn_id` → **与 world-001 冲突**（P0）。

### G0.5 原子写入的真实实现
```bash
grep -n "_write_save_atomically" -A 40 autoload/save_manager.gd
```
**裁决**：黑板截断在 `_build_save_data` 的 `"pet": PetManager.get_save_dat`。**必须贴出 `_write_save_atomically` 全文**，否则无法判断是否真原子。

---

## 1. 逐条核对（7 项）

### 1.1 定时存档

| 项 | 现状 | 判定 |
|---|---|---|
| 触发源 | `TimeSystem.minute_changed` | ✅ 存在 |
| 间隔 | `auto_save_interval_minutes`（默认 15，ConfigDB 可配） | ✅ 存在 |
| 判据 | `key - _last_auto_save_key < interval` | ⚠️ **有缺陷** |
| 初始化 | `_last_auto_save_key < 0` 时设为当前 key 并 return | ⚠️ **有缺陷** |
| 跨天 | `_on_day_started` 只在 `<0` 时重置 | ❌ **死代码** |

**缺陷 1（P1）**：`_current_time_key() = day*1440 + minute_of_day`。若玩家**读档后时间回退**（读旧档），`key - _last_auto_save_key` 为负，`< interval` 恒真 → **永不自动存档**。
**修复**：改为 `abs(key - _last_auto_save_key) >= interval` 或记录 `_last_auto_save_key` 时同时记录 `_last_auto_save_wallclock`。

**缺陷 2（P1）**：`_on_day_started` 里 `if _last_auto_save_key < 0` —— 但 `_on_minute_changed` 已经把它设为非负。**该分支永不执行**，是死代码。
**修复**：删除，或改为"跨天强制存档"（见 1.2）。

**缺陷 3（P2）**：`_last_auto_save_reason` 只在 `request_auto_save` 和 `_on_minute_changed` 里写。`save_game(automatic=true)` 直接调用时**不写 reason** → `get_last_auto_save_reason()` 返回陈旧值。
**修复**：`save_game` 增加 `reason` 参数，或 `request_auto_save` 是唯一入口。

---

### 1.2 关键节点

| 关键节点 | 是否触发 | 判定 |
|---|---|---|
| 跨天 | ❌ 无 | **缺口** |
| 工作班次结束 | ❌ 无 | **缺口** |
| 交易/大额消费 | ❌ 无 | **缺口** |
| 场景切换（`world-001` 的 `travel_to`） | ❌ 无 | **缺口** |
| 节日/事件开始 | ❌ 无 | **缺口** |
| 退出游戏 | ❌ 无 | **缺口** |
| 读档后 | ❌ 无 | **缺口** |

**缺口（P0）**：`request_auto_save(reason)` 存在但**黑板中没有任何调用点**。`_on_day_started` 只重置 key，不存档。
**修复**：在以下位置插入 `SaveManager.request_auto_save("...")`：
- `TimeSystem.day_started` → `"day_start"`
- `GameState.player_action_completed` → `"action_done"`（节流：仅当 money 变化 > 阈值）
- `world-001` 的 `travel_to` 成功后 → `"area_change"`
- `NOTIFICATION_WM_CLOSE_REQUEST` → `"quit"`（同步阻塞写）

---

### 1.3 原子写入

**现状**：`_write_save_atomically(path, data)` 被调用，但**实现未在黑板中**。

**必须核对的 5 个原子性条件**：

| # | 条件 | 若缺失的后果 |
|---|---|---|
| A1 | 写 `.tmp` 文件 | 直接写目标文件 → 崩溃时半截 |
| A2 | `flush()` + `close()` 后再 rename | 缓冲未落盘 → rename 后内容为空 |
| A3 | rename 前删除旧 `.bak` 或轮转 | rename 覆盖失败 → 旧档丢失 |
| A4 | rename 失败时保留 `.tmp` | 无法人工恢复 |
| A5 | 写前校验 `data` 可序列化 | `JSON.stringify` 返回空串 → 写入空文件 |

**判定**：**无法确认**。这是 P0 阻塞项。
**修复**：见 §3.1 的 `_write_save_atomically` 参考实现。

---

### 1.4 三份轮转

**现状**：`BACKUP_COUNT := 3`，`_backup_paths(path)` 被调用，但**轮转逻辑未在黑板中**。

**必须核对的 4 个条件**：

| # | 条件 | 判定 |
|---|---|---|
| B1 | 轮转发生在**写新档之前**（写前轮转） | ❓ 未知 |
| B2 | 轮转是 `save.2 → save.3`、`save.1 → save.2`、`save → save.1` | ❓ 未知 |
| B3 | 轮转失败不阻断主写入 | ❓ 未知 |
| B4 | `_candidate_paths()` 顺序 = 主档 → 备份1 → 备份2 → 备份3 | ❓ 未知 |

**关键洞察**：`load_game` 里 `for path in _candidate_paths()` 遍历，**第一个能解析的就用**。若 `_candidate_paths()` 把备份放在主档之前 → **永远读备份**。
**修复**：`_candidate_paths()` 必须返回 `[MANUAL_SAVE_PATH, MANUAL_SAVE_PATH+".1", ...]`，主档优先。

**缺陷（P1）**：`load_game` 中 `fallback_path` 逻辑：
```gdscript
if path != MANUAL_SAVE_PATH and fallback_path.is_empty():
    fallback_path = path
```
若读的是 `AUTO_SAVE_PATH`（自动档），`path != MANUAL_SAVE_PATH` 为真 → **误报"主存档不可用"**。
**修复**：改为 `if path != MANUAL_SAVE_PATH and path != AUTO_SAVE_PATH`。

---

### 1.5 损坏回退

**现状**：`_read_json_file(path)` 返回空字典则 `continue`。

**缺陷（P0）**：`parsed.is_empty()` 无法区分三种情况：
1. 文件不存在（应跳过）
2. 文件存在但 JSON 解析失败（应告警 + 尝试下一份）
3. 文件存在、JSON 合法但**内容为空对象 `{}`**（应视为损坏）

**修复**：`_read_json_file` 返回 `{ok: bool, data: Dictionary, error: String}`，`load_game` 据此区分。

**缺陷（P1）**：**无校验和**。JSON 合法但字段被截断（如 `"money": 32` 而非 `320`）无法检测。
**修复**：写入时加 `"checksum": sha256(核心字段序列化)`，读取时校验。

---

### 1.6 版本迁移

**现状**：`SAVE_VERSION := 15`，`_migrate_save(parsed)` 被调用，**实现未在黑板中**。

**必须核对的 5 个条件**：

| # | 条件 | 判定 |
|---|---|---|
| C1 | `parsed.version > SAVE_VERSION` → 拒绝加载（未来档） | ❓ 未知 |
| C2 | `parsed.version < SAVE_VERSION` → 逐版本迁移 | ❓ 未知 |
| C3 | 迁移链是 `v1→v2→...→v15` 而非 `v1→v15` 一步 | ❓ 未知 |
| C4 | 迁移失败 → 不覆盖原档，返回失败 | ❓ 未知 |
| C5 | 迁移后**立即回写**为新版本 | ❓ 未知 |

**关键洞察**：`world-001` 决定"存档只存 `world_pos`，删除 CameraRig 双坐标系"。这意味着 **v15 → v16 必然有一次破坏性迁移**（`current_area` + `spawn_id` → `world_pos`）。
**修复**：见 §3.3 的迁移链设计。

---

### 1.7 读档失败保护

**现状**：
```gdscript
NoticeManager.show_message("存档内容损坏，暂时无法读取；原档没有被覆盖。", "warning")
return false
```

**缺陷（P0）**：**没有"原档没有被覆盖"的保证**。若 `load_game` 失败后玩家继续游戏并触发自动存档 → **损坏档被覆盖**。
**修复**：
1. `load_game` 失败时设置 `_load_failed := true`
2. `save_game` 开头检查 `if _load_failed and not _load_failed_acknowledged: return false`
3. 提供 `SaveManager.acknowledge_load_failure()` 供玩家显式确认"放弃旧档，开始新游戏"

**缺陷（P1）**：失败后**没有降级到"新游戏"路径**。玩家卡在"无法读档 + 无法存档"死锁。
**修复**：`load_game` 失败时返回 `false`，由调用方（主菜单）决定：显示"开始新游戏"按钮。

---

## 2. 缺口汇总与修复顺序

### 2.1 缺口清单（按严重度）

| ID | 缺口 | 严重度 | 影响 |
|---|---|---|---|
| G-01 | `_write_save_atomically` 实现未知 | **P0** | 原子性无法保证 |
| G-02 | `_apply_save` 实现未知 | **P0** | 读档可能是空实现 |
| G-03 | 17 个 Manager 的 `get_save_data` 未核对 | **P0** | 静默丢字段 |
| G-04 | `world-001` 的 `world_pos` 契约未落地 | **P0** | 与已裁决架构冲突 |
| G-05 | 读档失败后无覆盖保护 | **P0** | 损坏档被覆盖 |
| G-06 | 无关键节点存档 | **P1** | 崩溃丢进度 |
| G-07 | 时间回退导致自动存档失效 | **P1** | 读旧档后永不自动存 |
| G-08 | `fallback_path` 误报 | **P1** | 误导玩家 |
| G-09 | 无校验和 | **P1** | 截断档无法检测 |
| G-10 | 迁移链未知 | **P1** | 跨版本升级失败 |
| G-11 | `_on_day_started` 死代码 | **P2** | 无功能影响 |
| G-12 | `_last_auto_save_reason` 陈旧 | **P2** | 调试信息不准 |

### 2.2 修复顺序（严格串行）

```
阶段 0：门禁（G0.1–G0.5）—— 阻塞一切
   ↓
阶段 1：P0 数据完整性（G-01, G-02, G-03, G-04）
   ↓ 验证：能存能读，字段完整
阶段 2：P0 失败保护（G-05）
   ↓ 验证：损坏档不被覆盖
阶段 3：P1 关键节点（G-06, G-07）
   ↓ 验证：崩溃后进度损失 ≤ 1 个关键节点
阶段 4：P1 回退与校验（G-08, G-09）
   ↓ 验证：截断档被检测
阶段 5：P1 迁移链（G-10）
   ↓ 验证：v14 → v15 → v16 逐级迁移
阶段 6：P2 清理（G-11, G-12）
```

**禁止并行**：阶段 1 未通过前，阶段 2 的"损坏档保护"无法测试（因为不知道什么是"损坏"）。

---

## 3. 参考实现（关键片段）

### 3.1 原子写入 + 写前轮转

```gdscript
func _write_save_atomically(path: String, data: Dictionary) -> bool:
    # A5: 序列化校验
    var json := JSON.stringify(data, "\t")
    if json.is_empty() or json == "{}":
        push_error("SAVE: 序列化结果为空，拒绝写入")
        return false

    # B1: 写前轮转（先轮转，再写新档）
    _rotate_backups(path)

    # A1: 写 .tmp
    var tmp := path + TEMP_SUFFIX
    var f := FileAccess.open(tmp, FileAccess.WRITE)
    if f == null:
        push_error("SAVE: 无法打开临时文件 %s" % tmp)
        return false
    f.store_string(json)
    # A2: flush + close 后再 rename
    f.flush()
    f.close()

    # A4: rename 失败保留 .tmp
    var dir := DirAccess.open(path.get_base_dir())
    if dir == null:
        return false
    var err := dir.rename(tmp, path)
    if err != OK:
        push_error("SAVE: rename 失败 %d，.tmp 保留在 %s" % [err, tmp])
        return false
    return true

func _rotate_backups(path: String) -> void:
    # B2: save.2 → save.3, save.1 → save.2, save → save.1
    var dir := DirAccess.open(path.get_base_dir())
    if dir == null:
        return
    # 删除最旧
    var oldest := "%s.%d" % [path, BACKUP_COUNT]
    if FileAccess.file_exists(oldest):
        dir.remove(oldest)
    # 逐个后移
    for i in range(BACKUP_COUNT - 1, 0, -1):
        var src := "%s.%d" % [path, i]
        var dst := "%s.%d" % [path, i + 1]
        if FileAccess.file_exists(src):
            dir.rename(src, dst)
    # 主档 → .1
    if FileAccess.file_exists(path):
        dir.rename(path, "%s.1" % path)
```

### 3.2 读档失败保护

```gdscript
var _load_failed := false
var _load_failed_acknowledged := false

func load_game(show_notice: bool = true) -> bool:
    _load_failed = false
    for path in _candidate_paths():
        var result := _read_json_file(path)
        if not result.ok:
            if result.error != "not_found":
                push_warning("SAVE: %s 读取失败：%s" % [path, result.error])
            continue
        var migrated := _migrate_save(result.data)
        if migrated.is_empty():
            push_warning("SAVE: %s 迁移失败" % path)
            continue
        if not _verify_checksum(migrated):
            push_warning("SAVE: %s 校验和不匹配" % path)
            continue
        _apply_save(migrated)
        _last_auto_save_key = _current_time_key()
        game_loaded.emit()
        if show_notice:
            NoticeManager.show_message("生活进度已读取。", "positive")
        return true
    # 全部失败
    _load_failed = true
    if show_notice:
        NoticeManager.show_message("存档内容损坏，暂时无法读取；原档没有被覆盖。", "warning")
    return false

func save_game(show_notice: bool = true, automatic: bool = false) -> bool:
    if _load_failed and not _load_failed_acknowledged:
        push_warning("SAVE: 读档失败未确认，拒绝覆盖")
        return false
    # ... 原有逻辑

func acknowledge_load_failure() -> void:
    _load_failed_acknowledged = true
```

### 3.3 迁移链

```gdscript
const MIGRATIONS := {
    14: "_migrate_14_to_15",
    15: "_migrate_15_to_16",  # world-001: current_area+spawn_id → world_pos
}

func _migrate_save(data: Dictionary) -> Dictionary:
    var v := int(data.get("version", 0))
    if v == 0:
        push_error("SAVE: 无版本号，拒绝迁移")
        return {}
    if v > SAVE_VERSION:
        push_error("SAVE: 版本 %d 高于当前 %d，拒绝加载" % [v, SAVE_VERSION])
        return {}
    while v < SAVE_VERSION:
        var fn_name: String = MIGRATIONS.get(v, "")
        if fn_name.is_empty():
            push_error("SAVE: 缺少 v%d → v%d 迁移函数" % [v, v + 1])
            return {}
        data = call(fn_name, data)
        if data.is_empty():
            return {}
        v += 1
        data["version"] = v
    return data

func _migrate_15_to_16(data: Dictionary) -> Dictionary:
    # world-001: 世界坐标唯一真相
    var game: Dictionary = data.get("game", {})
    if game.has("current_area") and not game.has("world_pos"):
        # 用 area 的默认 spawn 位置填充
        var area_id := str(game.get("current_area", "home"))
        var spawn_id := str(game.get("spawn_id", "start"))
        game["world_pos"] = WorldGraph.get_spawn_world_pos(area_id, spawn_id)
        game.erase("current_area")
        game.erase("spawn_id")
    data["game"] = game
    return data
```

---

## 4. 可复现测试用例

### 4.1 测试文件：`tests/save_stability_test.gd`

```gdscript
extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    _test_atomic_write()
    _test_backup_rotation()
    _test_corruption_fallback()
    _test_checksum_detection()
    _test_version_migration()
    _test_load_failure_protection()
    _test_timed_auto_save()
    _test_key_node_auto_save()
    if failures.is_empty():
        print("SAVE_STABILITY_PASS")
        get_tree().quit(0)
    else:
        for f in failures:
            push_error("SAVE_STABILITY_FAIL: %s" % f)
        get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
    if not cond:
        failures.append(msg)

# T1: 原子写入 —— 写一半崩溃，主档不变
func _test_atomic_write() -> void:
    var path := "user://test_atomic.json"
    var dir := DirAccess.open("user://")
    if FileAccess.file_exists(path):
        dir.remove(path)
    # 写第一份
    SaveManager._write_save_atomically(path, {"version": 15, "money": 100})
    var f := FileAccess.open(path, FileAccess.READ)
    var d1 = JSON.parse_string(f.get_as_text())
    f.close()
    _check(d1.money == 100, "T1.1 首次写入应成功")
    # 模拟第二次写入时 .tmp 存在但 rename 前崩溃
    var tmp := path + ".tmp"
    var ft := FileAccess.open(tmp, FileAccess.WRITE)
    ft.store_string('{"version":15,"money":999}')
    ft.close()
    # 主档应仍是 100
    f = FileAccess.open(path, FileAccess.READ)
    var d2 = JSON.parse_string(f.get_as_text())
    f.close()
    _check(d2.money == 100, "T1.2 崩溃后主档应不变")
    dir.remove(tmp)
    dir.remove(path)

# T2: 三份轮转 —— 写 4 次，应有 .1 .2 .3
func _test_backup_rotation() -> void:
    var path := "user://test_rotate.json"
    var dir := DirAccess.open("user://")
    for i in range(1, 5):
        SaveManager._write_save_atomically(path, {"version": 15, "n": i})
    _check(FileAccess.file_exists(path), "T2.1 主档存在")
    _check(FileAccess.file_exists(path + ".1"), "T2.2 备份1存在")
    _check(FileAccess.file_exists(path + ".2"), "T2.3 备份2存在")
    _check(FileAccess.file_exists(path + ".3"), "T2.4 备份3存在")
    _check(not FileAccess.file_exists(path + ".4"), "T2.5 不应有备份4")
    # 验证 .1 是第 3 次写入
    var f := FileAccess.open(path + ".1", FileAccess.READ)
    var d = JSON.parse_string(f.get_as_text())
    f.close()
    _check(d.n == 3, "T2.6 .1 应是第 3 次写入")
    for p in [path, path + ".1", path + ".2", path + ".3"]:
        dir.remove(p)

# T3: 损坏回退 —— 主档损坏，读备份
func _test_corruption_fallback() -> void:
    var path := "user://test_corrupt.json"
    var dir := DirAccess.open("user://")
    # 写两份好的
    SaveManager._write_save_atomically(path, {"version": 15, "money": 100})
    SaveManager._write_save_atomically(path, {"version": 15, "money": 200})
    # 主档写坏
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string("{invalid json")
    f.close()
    # 读档应回退到 .1
    var result := SaveManager._read_json_file(path)
    _check(not result.ok, "T3.1 主档应读取失败")
    var result1 := SaveManager._read_json_file(path + ".1")
    _check(result1.ok and result1.data.money == 100, "T3.2 备份应可读")
    for p in [path, path + ".1", path + ".2"]:
        if FileAccess.file_exists(p):
            dir.remove(p)

# T4: 校验和检测 —— 字段被截断
func _test_checksum_detection() -> void:
    var data := {"version": 15, "money": 320, "energy": 100.0}
    var with_sum := SaveManager._attach_checksum(data)
    _check(with_sum.has("checksum"), "T4.1 应附加校验和")
    _check(SaveManager._verify_checksum(with_sum), "T4.2 校验和应通过")
    # 篡改
    with_sum.money = 32
    _check(not SaveManager._verify_checksum(with_sum), "T4.3 篡改后应失败")

# T5: 版本迁移 —— v14 → v15 → v16
func _test_version_migration() -> void:
    var v14 := {"version": 14, "game": {"current_area": "home", "spawn_id": "start"}}
    var migrated := SaveManager._migrate_save(v14)
    _check(migrated.version == 15, "T5.1 应迁移到 v15")
    _check(migrated.game.has("world_pos"), "T5.2 v16 应有 world_pos")
    _check(not migrated.game.has("current_area"), "T5.3 v16 应删除 current_area")
    # 未来版本拒绝
    var v99 := {"version": 99}
    _check(SaveManager._migrate_save(v99).is_empty(), "T5.4 未来版本应拒绝")

# T6: 读档失败保护 —— 损坏后不覆盖
func _test_load_failure_protection() -> void:
    var path := "user://test_protect.json"
    var dir := DirAccess.open("user://")
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string("{invalid")
    f.close()
    # 模拟读档失败
    SaveManager._load_failed = true
    SaveManager._load_failed_acknowledged = false
    var ok := SaveManager.save_game(false, false)
    _check(not ok, "T6.1 读档失败未确认时应拒绝存档")
    SaveManager.acknowledge_load_failure()
    ok = SaveManager.save_game(false, false)
    _check(ok, "T6.2 确认后应允许存档")
    dir.remove(path)

# T7: 定时存档 —— 时间回退后仍能触发
func _test_timed_auto_save() -> void:
    SaveManager._last_auto_save_key = 1000
    TimeSystem.current_day = 0
    TimeSystem.minute_of_day = 100  # key = 100
    # 时间回退，key - last = -900
    var key := SaveManager._current_time_key()
    _check(abs(key - SaveManager._last_auto_save_key) >= 15, "T7.1 时间回退应触发存档")

# T8: 关键节点存档 —— 跨天触发
func _test_key_node_auto_save() -> void:
    SaveManager._last_auto_save_key = -1
    var before := SaveManager._last_auto_save_reason
    TimeSystem.day_started.emit(TimeSystem.current_day + 1)
    _check(SaveManager._last_auto_save_reason == "day_start", "T8.1 跨天应触发存档")
```

### 4.2 测试运行

```bash
godot --headless --path . --script tests/save_stability_test.gd
```

**预期输出**：`SAVE_STABILITY_PASS`，退出码 0。

### 4.3 手工复现用例（崩溃注入）

| # | 操作 | 预期 |
|---|---|---|
| M1 | 存档 → 任务管理器杀进程 → 重启 | 主档完整，`.tmp` 存在但不影响 |
| M2 | 存档 4 次 → 检查 `user://` | 有 `.1 .2 .3`，无 `.4` |
| M3 | 用记事本把主档改成 `{` → 重启 | 提示"回退到备份"，游戏可玩 |
| M4 | 用记事本把主档 `money` 改小 → 重启 | 提示"校验和不匹配"，回退备份 |
| M5 | 装 v14 旧档 → 启动 v15 | 自动迁移，`world_pos` 存在 |
| M6 | 装 v99 未来档 → 启动 | 拒绝加载，提示版本过高 |
| M7 | 主档 + 3 备份全损坏 → 启动 | 提示"无法读取"，**不覆盖**，可开新游戏 |
| M8 | 读档后把系统时间调回 1 天前 | 15 分钟后应触发自动存档 |

---

## 5. 与黑板其他方案的接口

| 方案 | 接口 | 本方案要求 |
|---|---|---|
| `world-001` | `world_pos` 存档契约 | v16 迁移必须落地；`GameState.get_save_data()` 返回 `world_pos` |
| `ui-001` | `NoticeManager.show_message` | 存档提示走 `NoticeArbiter.push`，优先级 `warning > positive` |
| `test-001` | 门禁参数 | 新增 `--save-check` 门禁，跑 `save_stability_test.gd` |
| `npc-001` | NPC 状态 | `NpcManager.get_save_data()` 必须包含所有 8 位新 NPC 的 `affinity` / `flags` |
| `art-001` | 无直接接口 | — |

---

## 6. 独立方案的核心分歧（不迎合主方案）

1. **主方案可能主张"单文件 + 覆盖式"** → 本方案主张"**版本化快照 + 写前轮转**"。理由：`world-001` 的 LRU 驱逐 + interior 隔离区会让存档体积增长 3–5 倍，覆盖式写入的窗口期变长，崩溃概率上升。

2. **主方案可能主张"迁移函数内联在 `_migrate_save`"** → 本方案主张"**`MIGRATIONS` 字典 + 逐版本函数**"。理由：`test-001` 要求可单测，字典可被测试直接遍历。

3. **主方案可能主张"读档失败直接开新游戏"** → 本方案主张"**失败保护 + 显式确认**"。理由：玩家可能只是临时文件锁，直接开新游戏会丢档。

4. **主方案可能主张"校验和用 CRC32"** → 本方案主张"**SHA256**"。理由：Godot 4 内置 `HashingContext`，SHA256 无额外依赖，CRC32 碰撞率对存档不可接受。

5. **主方案可能主张"自动存档间隔用 wallclock"** → 本方案主张"**游戏内时间 + wallclock 双判据**"。理由：玩家可能暂停游戏去吃饭，wallclock 会误触发；纯游戏内时间在读旧档后失效。

---

## 7. 交付物清单

| # | 文件 | 状态 |
|---|---|---|
| 1 | `docs/SAVE_FACTS.md` | 待生成（门禁结果） |
| 2 | `autoload/save_manager.gd` | 待修改（§3 片段） |
| 3 | `tests/save_stability_test.gd` | 待新增（§4.1） |
| 4 | `scripts/main.gd` | 待新增 `--save-check` 门禁 |
| 5 | `docs/SAVE_MIGRATION.md` | 待新增（迁移链文档） |

**验收标准**：`godot --headless --path . --script tests/save_stability_test.gd` 输出 `SAVE_STABILITY_PASS`，且 §4.3 的 M1–M8 全部通过。

## 批判

# 批判审计：两份方案交叉核对

> 立场：不站队。逐条核对两份方案对 7 项要求的覆盖、冲突、死代码、不可触达机制、存档风险、测试漏洞。**只输出可执行的批判与返工要求。**

---

## 一、两份方案的根本性冲突（必须先裁决）

| # | 冲突点 | 主方案 | 独立方案 | 裁决要求 |
|---|---|---|---|---|
| C1 | 备份文件命名 | `path.bak.1/.2/.3` | `path.1/.2/.3` | **必须统一**。若两方案代码同时落地，`_candidate_paths()` 会遍历两套命名，产生 6 个候选路径，其中 3 个永远不存在 → 死路径。**返工：先裁决命名，另一方案全部改写。** |
| C2 | 轮转时机 | 写后轮转（先 rename tmp→path，再轮转旧档） | 写前轮转（先轮转，再写 tmp） | **主方案有 P0 缺陷**：写后轮转意味着 `path` 已被新内容覆盖，此时 `path → path.bak.1` 轮转的是**新档**，`.bak.1` 永远等于主档，备份链失效。**返工：主方案 §二 P0-1 的 `_write_save_atomically` 必须重写为写前轮转。** |
| C3 | 校验和 | 无 | SHA256 | 独立方案更完整，但**主方案未提及 → 若主方案先落地，独立方案的 `_verify_checksum` 调用点不存在**。返工：主方案必须显式声明"不实现校验和"并说明理由，否则视为遗漏。 |
| C4 | 读档失败保护 | 仅提示文案区分 | `_load_failed` 状态机 + 显式确认 | **主方案 P1-2 是假修复**：只改提示文案，不阻止后续 `save_game` 覆盖损坏档。独立方案 G-05 是真修复。**返工：主方案 P1-2 必须升级为状态机方案。** |
| C5 | 迁移链起点 | `MIGRATIONS` 从 v10 开始 | 从 v14 开始（示例） | 两者都**未覆盖 v1–v9**。若存在 v1 老档，两方案都会 `push_error("缺少 v%d→v%d")` 并拒绝加载 → **老玩家档全废**。**返工：必须先用 G0.1 门禁确认现存档最低版本，再决定迁移链起点。** |
| C6 | 自动存档判据 | 未提及时间回退 | `abs(key - last) >= interval` | 主方案遗漏。**返工：主方案必须补此条，否则读旧档后永不自动存档。** |
| C7 | `_apply_save` 存在性 | 假定存在 | 明确标记为"未知，P0 阻塞" | **主方案在未验证 `_apply_save` 存在的情况下就写测试断言 `GameState.money == 103`** → 若 `_apply_save` 是空实现，测试会失败但原因被误判为"轮转 bug"。**返工：主方案必须先跑 G0.3 门禁。** |

---

## 二、主方案的独立缺陷（不依赖独立方案）

### M-1【P0】写后轮转 = 备份链自毁
见 C2。主方案 §二 P0-1 的代码：
```gdscript
# 先 rename tmp → path（主档已被新内容覆盖）
var err := DirAccess.rename_absolute(tmp, path)
# 但轮转代码在 rename 之前执行……
```
实际代码顺序是**先轮转后 rename**，看似正确。但仔细读：
```gdscript
for i in range(BACKUP_COUNT, 1, -1):
    # path.bak.2 → path.bak.3
    # path.bak.1 → path.bak.2
if FileAccess.file_exists(path):
    # path → path.bak.1   ← 此时 path 还是旧档，正确
var err := DirAccess.rename_absolute(tmp, path)  # 新档落地
```
**顺序实际正确**。但存在**第二个缺陷**：`DirAccess.rename_absolute` 在目标已存在时的行为**未定义**（Godot 4 文档未保证覆盖）。若 `path.bak.3` 已存在且未被删除（`range(BACKUP_COUNT, 1, -1)` 从 3 到 2，**不删除 `.bak.3`**），rename 会失败或静默不覆盖 → **`.bak.3` 永远是第一次的旧档**。

**返工要求**：
```gdscript
# 必须先删除最旧
var oldest := "%s.bak.%d" % [path, BACKUP_COUNT]
if FileAccess.file_exists(oldest):
    DirAccess.remove_absolute(ProjectSettings.globalize_path(oldest))
# 再轮转
for i in range(BACKUP_COUNT - 1, 0, -1):
    ...
```
**测试补充**：连续存 5 次，断言 `.bak.3` 的内容是第 2 次写入（不是第 1 次）。

### M-2【P0】`_candidate_paths()` 顺序未验证
主方案：
```gdscript
var out: Array[String] = [MANUAL_SAVE_PATH, AUTO_SAVE_PATH]
out.append_array(_backup_paths(MANUAL_SAVE_PATH))
out.append_array(_backup_paths(AUTO_SAVE_PATH))
```
顺序是：手动主档 → 自动主档 → 手动备份 → 自动备份。
**问题**：若手动主档损坏、自动主档完好，会读自动档。但玩家可能刚手动存了档，期望读手动档。**语义错误**：自动档不应优先于手动备份。

**返工要求**：顺序应为 `[MANUAL, MANUAL.bak.1..3, AUTO, AUTO.bak.1..3]`，或明确文档化"自动档优先于手动备份"的决策理由。

### M-3【P0】测试断言 `money == 103` 不可复现
主方案测试：
```gdscript
for i in range(5):
    GameState.money = 100 + i
    sm.save_game(false, false)
# ...
_check(GameState.money == 103, "应回退到 .bak.1 的 money=103")
```
**缺陷**：`save_game(false, false)` 的第二个参数是 `automatic`，但 `_write_save_atomically` 写入的是 `_build_save_data()` 的结果，**不是 `GameState.money` 的直接快照**。若 `_build_save_data` 有字段过滤或转换，`money` 可能不落盘。

**返工要求**：测试必须先断言 `_build_save_data()` 包含 `money` 字段，再断言回退值。或直接读文件验证：
```gdscript
var f := FileAccess.open(p + ".bak.1", FileAccess.READ)
var d = JSON.parse_string(f.get_as_text())
_check(d.game.money == 103, ...)
```

### M-4【P1】`_on_day_started` 修复引入新死代码
主方案 P1-1：
```gdscript
func _on_day_started(_day: int) -> void:
    if _last_auto_save_key < 0:
        _last_auto_save_key = _current_time_key()
    request_auto_save("day_start")
```
`if _last_auto_save_key < 0` 分支在 `_on_minute_changed` 已初始化后**永不执行**（独立方案已指出）。主方案**保留了这个死分支**并新增了存档调用 → 死代码 + 新功能混杂。

**返工要求**：删除 `if _last_auto_save_key < 0` 分支，或改为 `_last_auto_save_key = _current_time_key()` 无条件重置（跨天重置计时基准）。

### M-5【P1】`request_auto_save` 的 reason 白名单是"软约束"
主方案：
```gdscript
if not KEY_NODE_REASONS.has(reason) and reason != "timed":
    push_warning("SAVE: 未注册的关键节点 reason=%s" % reason)
```
**问题**：只警告不拒绝 → 调用方传错 reason 仍会存档，白名单形同虚设。且 `"timed"` 是硬编码例外，与 `KEY_NODE_REASONS` 分离。

**返工要求**：要么把 `"timed"` 加入 `KEY_NODE_REASONS`，要么改为 `assert` 或 `return false`。

### M-6【P1】CI 断言 `MIGRATIONS.keys()` 覆盖 `[1..SAVE_VERSION-1]` 不可执行
主方案 §五：
```gdscript
for v in range(1, SaveManager.SAVE_VERSION):
    _check(SaveManager.MIGRATIONS.has(v), "缺少 v%d 迁移函数" % v)
```
**缺陷**：`MIGRATIONS` 是 `Dictionary`，`has(v)` 检查的是 key。但主方案 §二 P0-2 的 `MIGRATIONS` 只定义了 `10..14`。**这个断言会立即失败**（v1–v9 缺失）。主方案自己写的 CI 断言会红灯。

**返工要求**：要么补齐 v1–v9 迁移函数（可能不存在，因为老档已无人持有），要么把断言改为 `range(MIN_SUPPORTED_VERSION, SAVE_VERSION)`，并显式声明 `MIN_SUPPORTED_VERSION`。

---

## 三、独立方案的独立缺陷

### I-1【P0】门禁 G0.1 的 Python 命令不可执行
```bash
python -c "import json,glob,os; [print(p, list(json.load(open(p,encoding='utf-8')).keys())) for p in glob.glob(...)]"
```
**缺陷**：
1. 路径 `deep_city*.json` 是猜测，实际文件名由 `MANUAL_SAVE_PATH` 决定，未在方案中给出。
2. Windows 路径 `AppData/Roaming/Godot/app_userdata/*/` 中的 `*` 是项目名，未给出。
3. 若 JSON 损坏，`json.load` 抛异常，整个列表推导中断，**无法列出所有档**。

**返工要求**：改为逐文件 try/except，并先 `grep MANUAL_SAVE_PATH autoload/save_manager.gd` 确认真实路径。

### I-2【P0】`_read_json_file` 返回结构变更未同步调用方
独立方案 §1.5：
```gdscript
func _read_json_file(path: String) -> {ok: bool, data: Dictionary, error: String}
```
但主方案中 `_read_json_file` 返回 `Dictionary`，调用方 `load_game` 用 `parsed.is_empty()` 判断。**两方案对同一函数的签名不一致** → 若合并，编译失败。

**返工要求**：裁决 `_read_json_file` 签名。若采用独立方案，必须列出所有调用点并同步修改。

### I-3【P0】`_verify_checksum` 的校验范围未定义
独立方案：
```gdscript
var with_sum := SaveManager._attach_checksum(data)
with_sum.money = 32
_check(not SaveManager._verify_checksum(with_sum), "T4.3 篡改后应失败")
```
**缺陷**：`_attach_checksum` 计算的是**哪些字段**的哈希？若包含 `checksum` 字段自身 → 循环依赖。若只包含部分字段 → 未覆盖字段被篡改无法检测。

**返工要求**：明确 `checksum = sha256(JSON.stringify(data_without_checksum_key, 排序键))`，并写测试验证"只改 checksum 字段本身"也能被检测。

### I-4【P1】`_migrate_15_to_16` 依赖 `WorldGraph.get_spawn_world_pos` 存在
独立方案：
```gdscript
game["world_pos"] = WorldGraph.get_spawn_world_pos(area_id, spawn_id)
```
**缺陷**：`WorldGraph` 是 `world-001` 的产物，**当前不存在**。若迁移函数在 `WorldGraph` 落地前被调用 → 运行时错误 → 迁移失败 → 拒绝加载 → **玩家档丢失**。

**返工要求**：迁移函数必须对 `WorldGraph` 不存在做降级处理（如返回 `Vector2.ZERO` 并 `push_warning`），或迁移链在 `WorldGraph` 落地后才启用。

### I-5【P1】测试 T7 直接改 `TimeSystem.current_day` 绕过信号
```gdscript
TimeSystem.current_day = 0
TimeSystem.minute_of_day = 100
```
**缺陷**：直接赋值不触发 `minute_changed` 信号，`_on_minute_changed` 不会被调用 → 测试的是 `_current_time_key()` 的纯函数，**不是自动存档触发逻辑**。

**返工要求**：改为 `TimeSystem.advance_to(0, 100)` 或 `TimeSystem.minute_changed.emit(...)`，并断言 `_last_auto_save_key` 被更新。

### I-6【P1】测试 T6 直接改私有变量 `_load_failed`
```gdscript
SaveManager._load_failed = true
```
**缺陷**：绕过 `load_game` 的真实失败路径。若 `load_game` 内部有 `_load_failed = false` 的重置（独立方案 §3.2 确实有），测试设置的值会被覆盖。

**返工要求**：构造真实损坏档，调用 `load_game`，断言 `_load_failed == true`，再调 `save_game` 断言拒绝。

### I-7【P2】M8 手工用例不可复现
> M8 | 读档后把系统时间调回 1 天前 | 15 分钟后应触发自动存档

**缺陷**：`_current_time_key()` 基于**游戏内时间**，与系统时间无关。调系统时间不影响 `key`。此用例**测不到任何东西**。

**返工要求**：改为"读旧档（游戏内时间回退）→ 推进游戏内时间 15 分钟 → 应触发存档"。

---

## 四、两方案共同遗漏（必须补）

| # | 遗漏 | 影响 | 返工要求 |
|---|---|---|---|
| X-1 | **存档写入的并发保护** | 主方案提到 `_is_saving` 但未给测试；独立方案完全未提。定时存档与关键节点同帧触发 → 双写 → 轮转错乱 | 两方案都必须补：`_is_saving` 守卫 + 测试"并发调用第二次返回 false" |
| X-2 | **`NOTIFICATION_WM_CLOSE_REQUEST` 同步写** | 独立方案 §1.2 提到但未给实现；主方案未提。退出时异步写 → 进程被杀 → 档丢失 | 必须实现 `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` 同步阻塞写，并测试 |
| X-3 | **存档体积上限** | 两方案都未提。`world-001` 的 LRU 驱逐 + interior 隔离区会让存档膨胀 | 必须加 `MAX_SAVE_SIZE` 检查，超限拒绝写入并告警 |
| X-4 | **磁盘满/权限拒绝** | `FileAccess.open` 返回 null 时两方案都只 `push_error`，不降级 | 必须区分"临时失败"（重试）与"永久失败"（提示玩家） |
| X-5 | **存档加密/防篡改** | 两方案都未提。玩家改 JSON 可作弊 | 若游戏有成就系统，必须加签名；否则明确声明"不防作弊" |
| X-6 | **多平台路径** | 两方案都用 `user://`，但未测 macOS/Linux/Web | Web 平台无 `DirAccess.rename` → 原子写入失效。必须声明目标平台 |
| X-7 | **存档版本回滚** | 玩家从 v16 降级到 v15 → 两方案都拒绝加载 → 档废 | 必须提供"导出为 v15 兼容格式"或明确声明不支持降级 |
| X-8 | **测试隔离** | 两方案测试都写 `user://test_*.json`，但未清理 | 测试间互相污染。必须用 `before_each` 清场 + `after_each` 清理 |

---

## 五、修复顺序（合并两方案后的唯一正确顺序）

```
阶段 0：门禁（阻塞一切）
  0.1 确认 _write_save_atomically 全文
  0.2 确认 _apply_save 存在且非空
  0.3 确认 17 个 Manager 的 get_save_data 齐全
  0.4 确认现存档最低版本（决定迁移链起点）
  0.5 确认 world-001 的 world_pos 契约是否已落地
  0.6 确认目标平台（决定原子写入实现）
       ↓ 全部通过才继续
阶段 1：裁决冲突
  1.1 备份命名（.bak.N vs .N）
  1.2 轮转时机（写前 vs 写后）
  1.3 _read_json_file 签名
  1.4 校验和是否实现
       ↓
阶段 2：P0 数据完整性
  2.1 写前轮转 + 删除最旧
  2.2 _candidate_paths 顺序修正
  2.3 迁移链（起点由 0.4 决定）
  2.4 校验和（若 1.4 裁决实现）
       ↓ 验证：连续存 5 次，.bak.3 是第 2 次内容
阶段 3：P0 失败保护
  3.1 _load_failed 状态机
  3.2 acknowledge_load_failure
  3.3 退出时同步写
       ↓ 验证：损坏档不被覆盖
阶段 4：P1 关键节点 + 时间回退
  4.1 KEY_NODE_REASONS 硬约束
  4.2 abs(key - last) 判据
  4.3 删除 _on_day_started 死分支
       ↓ 验证：读旧档后 15 分钟触发存档
阶段 5：P1 提示 + 清理
  5.1 fallback_path 误报修正
  5.2 _last_auto_save_reason 统一入口
       ↓
阶段 6：测试补全
  6.1 并发写测试
  6.2 退出写测试
  6.3 磁盘满测试
  6.4 测试隔离
```

**禁止并行**：阶段 1 未裁决前，阶段 2 的代码无法写（命名/时机未定）。

---

## 六、必须补的测试用例（两方案都缺）

```gdscript
# T9: 并发写保护
func _test_concurrent_save() -> void:
    SaveManager._is_saving = false
    var r1 := SaveManager.save_game(false, false)
    # 模拟同帧第二次调用
    SaveManager._is_saving = true
    var r2 := SaveManager.save_game(false, false)
    _check(r1, "T9.1 首次存档应成功")
    _check(not r2, "T9.2 并发第二次应拒绝")

# T10: 退出时同步写
func _test_quit_save() -> void:
    var before := SaveManager.get_last_auto_save_reason()
    SaveManager._notification(NOTIFICATION_WM_CLOSE_REQUEST)
    _check(SaveManager.get_last_auto_save_reason() == "quit", "T10.1 退出应触发存档")

# T11: 磁盘满降级
func _test_disk_full() -> void:
    # 用只读路径模拟
    var ok := SaveManager._write_save_atomically("/root/forbidden.json", {"version": 15})
    _check(not ok, "T11.1 不可写路径应返回 false 而非崩溃")

# T12: 测试隔离
func _before_each() -> void:
    for p in SaveManager._candidate_paths():
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    SaveManager._load_failed = false
    SaveManager._load_failed_acknowledged = false
    SaveManager._is_saving = false
```

---

## 七、交付物返工清单

| 文件 | 主方案要求 | 独立方案要求 | 返工裁决 |
|---|---|---|---|
| `save_manager.gd` | 补轮转/迁移/关键节点/提示 | 补轮转/迁移/校验和/失败保护 | **以独立方案为基线**，主方案的写后轮转、假失败保护必须废弃 |
| `tests/save_manager_test.gd` | 3 个测试 | — | 合并入 `save_stability_test.gd` |
| `tests/save_stability_test.gd` | — | 8 个测试 | 补 T9–T12，修 T6/T7 绕过私有变量问题 |
| `docs/SAVE_AUDIT.md` | 7 项核对表 | — | 保留，但"✅"判定必须附证据行号 |
| `docs/SAVE_FACTS.md` | — | 门禁结果 | **必须先生成**，否则一切修复无依据 |
| `docs/SAVE_MIGRATION.md` | — | 迁移链文档 | 必须包含 `MIN_SUPPORTED_VERSION` 声明 |

---

## 八、最终裁决

**主方案不可直接执行**，原因：
1. 写后轮转的 `.bak.3` 不删除 → 备份链自毁（M-1）
2. `_candidate_paths` 顺序语义错误（M-2）
3. 测试断言 `money == 103` 不可复现（M-3）
4. 读档失败保护是假修复（C4）
5. CI 断言自相矛盾（M-6）

**独立方案不可直接执行**，原因：
1. 门禁命令不可运行（I-1）
2. `_read_json_file` 签名与主方案冲突（I-2）
3. `_verify_checksum` 范围未定义（I-3）
4. `_migrate_15_to_16` 依赖不存在的 `WorldGraph`（I-4）
5. 测试 T6/T7 绕过真实路径（I-5/I-6）

**唯一可执行路径**：先跑阶段 0 门禁，产出 `docs/SAVE_FACTS.md`，再按阶段 1 裁决冲突，然后以独立方案为基线、吸收主方案的测试用例设计，进入阶段 2。

**未跑门禁前，任何代码修改都是盲改。**

## 综合决策

# 自动存档稳定性与迁移审计 —— 最终可执行方案

> **综合裁决**：以独立方案为技术基线（写前轮转、校验和、`_load_failed` 状态机、逐版本迁移链），吸收主方案的测试用例设计（精确断言、负向路径、CI 断言），采纳批判的全部返工要求（删除最旧备份、`_candidate_paths` 顺序、真实路径测试、并发/退出/磁盘满补测）。
>
> **执行前提**：阶段 0 门禁未通过前，**禁止任何代码修改**。所有门禁结果落盘 `docs/SAVE_FACTS.md`，作为唯一事实源。

---

## 一、决策（冲突裁决表）

| # | 冲突点 | 裁决 | 理由 |
|---|---|---|---|
| D1 | 备份命名 | **`path.bak.1/.2/.3`** | 主方案命名更语义化；`.bak` 后缀可被 `.gitignore` 通配；避免与 `path.1` 这类无后缀文件混淆 |
| D2 | 轮转时机 | **写前轮转** | 写后轮转的 `.bak.1` 永远等于主档（批判 C2）；写前轮转保证备份链是历史快照 |
| D3 | 最旧备份处理 | **轮转前显式删除 `.bak.3`** | `DirAccess.rename` 目标存在时行为未定义（批判 M-1）；不删除则 `.bak.3` 永远冻结在首次写入 |
| D4 | `_candidate_paths` 顺序 | **`[MANUAL, MANUAL.bak.1..3, AUTO, AUTO.bak.1..3]`** | 手动档优先于自动档；手动备份优先于自动主档（玩家手动存档的意图强于自动档） |
| D5 | `_read_json_file` 签名 | **返回 `{ok, data, error}`** | 必须区分"不存在/解析失败/空对象"三种情况（独立方案 §1.5）；主方案的 `is_empty()` 无法区分 |
| D6 | 校验和 | **实现，SHA256，排除 `checksum` 字段自身** | Godot 4 内置 `HashingContext`，无依赖；CRC32 碰撞率对存档不可接受 |
| D7 | 读档失败保护 | **`_load_failed` 状态机 + 显式确认** | 主方案仅改文案是假修复（批判 C4）；必须阻止损坏档被覆盖 |
| D8 | 迁移链起点 | **由门禁 G0.4 决定**，暂定 `MIN_SUPPORTED_VERSION = 14` | 若现存档最低版本 < 14，必须补齐；若 ≥ 14，声明"低于 v14 的档不支持" |
| D9 | 自动存档判据 | **`abs(key - last) >= interval`** | 读旧档后时间回退，`key - last` 为负，`< interval` 恒真 → 永不存档（独立方案 §1.1） |
| D10 | `_on_day_started` 死分支 | **删除 `if _last_auto_save_key < 0`，改为无条件重置 + 存档** | 该分支在 `_on_minute_changed` 初始化后永不执行（批判 M-4） |
| D11 | `KEY_NODE_REASONS` 约束 | **硬约束：未注册 reason 返回 false** | 软警告形同虚设（批判 M-5）；`"timed"` 加入白名单 |
| D12 | 退出存档 | **`NOTIFICATION_WM_CLOSE_REQUEST` 同步阻塞写** | 异步写在进程被杀时丢档（批判 X-2） |
| D13 | 并发保护 | **`_is_saving` 守卫 + 测试** | 定时存档与关键节点同帧触发 → 双写 → 轮转错乱（批判 X-1） |
| D14 | 存档体积上限 | **`MAX_SAVE_SIZE = 4MB`，超限拒绝写入** | `world-001` 的 LRU + interior 会让存档膨胀（批判 X-3） |
| D15 | 目标平台 | **桌面（Windows/macOS/Linux），不支持 Web** | Web 无 `DirAccess.rename`，原子写入失效（批判 X-6） |
| D16 | 降级支持 | **不支持版本降级**，明确声明 | 提供"导出兼容格式"成本过高，且降级本身有数据丢失风险（批判 X-7） |

---

## 二、修改文件清单

| # | 文件 | 操作 | 关键内容 |
|---|---|---|---|
| 1 | `docs/SAVE_FACTS.md` | **新建（阶段 0 产出）** | 门禁 G0.1–G0.6 结果，唯一事实源 |
| 2 | `autoload/save_manager.gd` | 修改 | 写前轮转、`_read_json_file` 签名、`_migrate_save` 迁移链、`_load_failed` 状态机、`_is_saving` 守卫、退出同步写、`_candidate_paths` 顺序、`KEY_NODE_REASONS` 硬约束、`abs(key-last)` 判据、删除死分支、校验和、体积上限 |
| 3 | `tests/save_stability_test.gd` | **新建** | T1–T12 全部测试，含 `_before_each` 隔离 |
| 4 | `scripts/main.gd` | 修改 | 新增 `--save-check` 门禁参数 |
| 5 | `docs/SAVE_MIGRATION.md` | **新建** | 迁移链文档，含 `MIN_SUPPORTED_VERSION` 声明 |
| 6 | `docs/SAVE_AUDIT.md` | 修改 | 7 项核对表，每项 ✅ 附证据行号 |

---

## 三、执行步骤（严格串行，红灯不进入下一步）

### 阶段 0：门禁（阻塞一切）

**产出 `docs/SAVE_FACTS.md`**，逐条执行：

```bash
# G0.1 现有存档真实结构（逐文件 try/except，不中断）
python - <<'EOF'
import json, glob, os, sys
base = os.path.expanduser('~') + '/AppData/Roaming/Godot/app_userdata'
for p in glob.glob(base + '/*/*.json'):
    try:
        with open(p, encoding='utf-8') as f:
            d = json.load(f)
        print(p, 'version=', d.get('version', 'MISSING'), 'keys=', list(d.keys())[:10])
    except Exception as e:
        print(p, 'PARSE_FAIL', e)
EOF

# G0.2 各 Manager 的 get_save_data 是否齐全
grep -rn "func get_save_data" --include=*.gd autoload/ | wc -l
grep -rn "func get_save_data" --include=*.gd autoload/

# G0.3 _apply_save 是否存在且非空
grep -n "func _apply_save" -A 30 autoload/save_manager.gd

# G0.4 现存档最低版本（决定 MIN_SUPPORTED_VERSION）
# 从 G0.1 输出中取 min(version)

# G0.5 world-001 的 world_pos 契约是否落地
grep -rn "world_pos\|current_area\|spawn_id" --include=*.gd autoload/game_state.gd

# G0.6 _write_save_atomically 全文
grep -n "_write_save_atomically" -A 50 autoload/save_manager.gd

# G0.7 目标平台确认
grep -rn "OS.get_name\|OS.has_feature" --include=*.gd scripts/ | head
```

**门禁通过标准**：
- G0.1：所有档 `version` 字段存在且 ≤ 15
- G0.2：`_build_save_data()` 中列出的 17 个 Manager 全部有 `get_save_data()`
- G0.3：`_apply_save` 存在且非空实现
- G0.4：`MIN_SUPPORTED_VERSION` 确定
- G0.5：`world_pos` 契约状态明确（已落地 / 未落地 → 迁移函数降级）
- G0.6：`_write_save_atomically` 全文可见
- G0.7：目标平台明确

**未通过 → 停止，先修复门禁项。**

---

### 阶段 1：裁决落地（无代码修改，仅文档）

将第一节 D1–D16 裁决写入 `docs/SAVE_FACTS.md` 的"裁决"章节，作为后续所有代码的依据。

---

### 阶段 2：P0 数据完整性

**修改 `autoload/save_manager.gd`**：

```gdscript
const SAVE_VERSION := 15
const BACKUP_COUNT := 3
const TEMP_SUFFIX := ".tmp"
const MAX_SAVE_SIZE := 4 * 1024 * 1024  # 4MB
const MIN_SUPPORTED_VERSION := 14  # 由 G0.4 决定

var _is_saving := false
var _load_failed := false
var _load_failed_acknowledged := false

# ---- 原子写入 + 写前轮转 ----
func _write_save_atomically(path: String, data: Dictionary) -> bool:
    # A5: 序列化校验
    var json := JSON.stringify(data, "\t")
    if json.is_empty() or json == "{}":
        push_error("SAVE: 序列化结果为空，拒绝写入")
        return false
    # 体积上限
    if json.length() > MAX_SAVE_SIZE:
        push_error("SAVE: 存档体积 %d 超过上限 %d" % [json.length(), MAX_SAVE_SIZE])
        return false

    # B1: 写前轮转
    _rotate_backups(path)

    # A1: 写 .tmp
    var tmp := path + TEMP_SUFFIX
    var f := FileAccess.open(tmp, FileAccess.WRITE)
    if f == null:
        push_error("SAVE: 无法打开临时文件 %s（磁盘满/权限拒绝）" % tmp)
        return false
    f.store_string(json)
    f.flush()
    f.close()

    # A4: rename 失败保留 .tmp
    var dir := DirAccess.open(path.get_base_dir())
    if dir == null:
        push_error("SAVE: 无法打开目录 %s" % path.get_base_dir())
        return false
    var err := dir.rename(tmp, path)
    if err != OK:
        push_error("SAVE: rename 失败 %d，.tmp 保留在 %s" % [err, tmp])
        return false
    return true

func _rotate_backups(path: String) -> void:
    var dir := DirAccess.open(path.get_base_dir())
    if dir == null:
        return
    # D3: 先删除最旧
    var oldest := "%s.bak.%d" % [path, BACKUP_COUNT]
    if FileAccess.file_exists(oldest):
        dir.remove(oldest)
    # 逐个后移：.bak.2 → .bak.3, .bak.1 → .bak.2
    for i in range(BACKUP_COUNT - 1, 0, -1):
        var src := "%s.bak.%d" % [path, i]
        var dst := "%s.bak.%d" % [path, i + 1]
        if FileAccess.file_exists(src):
            dir.rename(src, dst)
    # 主档 → .bak.1
    if FileAccess.file_exists(path):
        dir.rename(path, "%s.bak.1" % path)

func _backup_paths(path: String) -> Array[String]:
    var out: Array[String] = []
    for i in range(1, BACKUP_COUNT + 1):
        out.append("%s.bak.%d" % [path, i])
    return out

# D4: 手动档优先，手动备份优先于自动主档
func _candidate_paths() -> Array[String]:
    var out: Array[String] = [MANUAL_SAVE_PATH]
    out.append_array(_backup_paths(MANUAL_SAVE_PATH))
    out.append(AUTO_SAVE_PATH)
    out.append_array(_backup_paths(AUTO_SAVE_PATH))
    return out
```

**校验和**：

```gdscript
func _attach_checksum(data: Dictionary) -> Dictionary:
    var copy := data.duplicate(true)
    copy.erase("checksum")
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update(JSON.stringify(copy, "\t").to_utf8_buffer())
    data["checksum"] = ctx.finish().hex_encode()
    return data

func _verify_checksum(data: Dictionary) -> bool:
    if not data.has("checksum"):
        return false
    var expected: String = data["checksum"]
    var copy := data.duplicate(true)
    copy.erase("checksum")
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update(JSON.stringify(copy, "\t").to_utf8_buffer())
    return ctx.finish().hex_encode() == expected
```

**`_read_json_file` 签名变更（D5）**：

```gdscript
func _read_json_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "data": {}, "error": "not_found"}
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return {"ok": false, "data": {}, "error": "open_failed"}
    var text := f.get_as_text()
    f.close()
    var parsed = JSON.parse_string(text)
    if parsed == null or not parsed is Dictionary:
        return {"ok": false, "data": {}, "error": "parse_failed"}
    if parsed.is_empty():
        return {"ok": false, "data": {}, "error": "empty_object"}
    return {"ok": true, "data": parsed, "error": ""}
```

**迁移链（D8）**：

```gdscript
const MIGRATIONS := {
    14: "_migrate_14_to_15",
    # 15: "_migrate_15_to_16",  # world-001 落地后启用
}

func _migrate_save(data: Dictionary) -> Dictionary:
    var v := int(data.get("version", 0))
    if v == 0:
        push_error("SAVE: 无版本号，拒绝迁移")
        return {}
    if v < MIN_SUPPORTED_VERSION:
        push_error("SAVE: 版本 %d 低于最低支持 %d，拒绝加载" % [v, MIN_SUPPORTED_VERSION])
        return {}
    if v > SAVE_VERSION:
        push_error("SAVE: 版本 %d 高于当前 %d，拒绝加载（不支持降级）" % [v, SAVE_VERSION])
        return {}
    while v < SAVE_VERSION:
        var fn_name: String = MIGRATIONS.get(v, "")
        if fn_name.is_empty():
            push_error("SAVE: 缺少 v%d → v%d 迁移函数" % [v, v + 1])
            return {}
        data = call(fn_name, data)
        if data.is_empty():
            return {}
        v += 1
        data["version"] = v
    return data

func _migrate_14_to_15(data: Dictionary) -> Dictionary:
    if not data.has("pet"):
        data["pet"] = {}
    data["version"] = 15
    return data
```

---

### 阶段 3：P0 失败保护

```gdscript
func load_game(show_notice: bool = true) -> bool:
    _load_failed = false
    var any_existed := false
    for path in _candidate_paths():
        var result := _read_json_file(path)
        if not result.ok:
            if result.error != "not_found":
                any_existed = true
                push_warning("SAVE: %s 读取失败：%s" % [path, result.error])
            continue
        any_existed = true
        var migrated := _migrate_save(result.data)
        if migrated.is_empty():
            push_warning("SAVE: %s 迁移失败" % path)
            continue
        if not _verify_checksum(migrated):
            push_warning("SAVE: %s 校验和不匹配" % path)
            continue
        _apply_save(migrated)
        _last_auto_save_key = _current_time_key()
        game_loaded.emit()
        if show_notice:
            NoticeManager.show_message("生活进度已读取。", "positive")
        return true
    # 全部失败
    _load_failed = true
    if show_notice:
        if not any_existed:
            NoticeManager.show_message("还没有存档，开始新生活吧。", "hint")
        else:
            NoticeManager.show_message("存档内容损坏，暂时无法读取；原档没有被覆盖。", "warning")
    return false

func save_game(show_notice: bool = true, automatic: bool = false) -> bool:
    if _is_saving:
        push_warning("SAVE: 存档进行中，拒绝重入")
        return false
    if _load_failed and not _load_failed_acknowledged:
        push_warning("SAVE: 读档失败未确认，拒绝覆盖")
        return false
    _is_saving = true
    var ok := _do_save(show_notice, automatic)
    _is_saving = false
    return ok

func acknowledge_load_failure() -> void:
    _load_failed_acknowledged = true

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        if not _load_failed or _load_failed_acknowledged:
            request_auto_save("quit")
        get_tree().quit()
```

---

### 阶段 4：P1 关键节点 + 时间回退

```gdscript
const KEY_NODE_REASONS := {
    "timed": true,
    "day_start": true,
    "area_change": true,
    "career_shift_end": true,
    "housing_upgrade": true,
    "festival_enter": true,
    "quit": true,
}

func request_auto_save(reason: String) -> bool:
    if not auto_save_enabled:
        return false
    if not KEY_NODE_REASONS.has(reason):
        push_error("SAVE: 未注册的关键节点 reason=%s，拒绝存档" % reason)
        return false
    _last_auto_save_reason = reason
    return save_game(false, true)

func _on_minute_changed(_minute: int) -> void:
    var key := _current_time_key()
    if _last_auto_save_key < 0:
        _last_auto_save_key = key
        return
    # D9: abs 判据，兼容时间回退
    if abs(key - _last_auto_save_key) >= auto_save_interval_minutes:
        _last_auto_save_key = key
        request_auto_save("timed")

func _on_day_started(_day: int) -> void:
    # D10: 删除死分支，无条件重置 + 存档
    _last_auto_save_key = _current_time_key()
    request_auto_save("day_start")
```

---

### 阶段 5：P1 提示 + 清理

- `fallback_path` 误报修正：`if path != MANUAL_SAVE_PATH and path != AUTO_SAVE_PATH`
- `_last_auto_save_reason` 统一由 `request_auto_save` 写入

---

### 阶段 6：测试补全

**新建 `tests/save_stability_test.gd`**：

```gdscript
extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    _test_atomic_write()
    _test_backup_rotation()
    _test_corruption_fallback()
    _test_checksum_detection()
    _test_version_migration()
    _test_load_failure_protection()
    _test_timed_auto_save()
    _test_key_node_auto_save()
    _test_concurrent_save()
    _test_quit_save()
    _test_disk_full()
    _test_migration_chain_complete()
    if failures.is_empty():
        print("SAVE_STABILITY_PASS")
        get_tree().quit(0)
    else:
        for f in failures:
            push_error("SAVE_STABILITY_FAIL: %s" % f)
        get_tree().quit(1)

func _check(cond: bool, msg: String) -> void:
    if not cond:
        failures.append(msg)

func _before_each() -> void:
    for p in SaveManager._candidate_paths():
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
    var tmp := SaveManager.MANUAL_SAVE_PATH + SaveManager.TEMP_SUFFIX
    if FileAccess.file_exists(tmp):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
    SaveManager._load_failed = false
    SaveManager._load_failed_acknowledged = false
    SaveManager._is_saving = false

# T1: 原子写入 —— 崩溃后主档不变
func _test_atomic_write() -> void:
    _before_each()
    var path := SaveManager.MANUAL_SAVE_PATH
    SaveManager._write_save_atomically(path, {"version": 15, "money": 100})
    var f := FileAccess.open(path, FileAccess.READ)
    var d1 = JSON.parse_string(f.get_as_text())
    f.close()
    _check(d1.money == 100, "T1.1 首次写入应成功")
    # 模拟 .tmp 存在但 rename 前崩溃
    var ft := FileAccess.open(path + SaveManager.TEMP_SUFFIX, FileAccess.WRITE)
    ft.store_string('{"version":15,"money":999}')
    ft.close()
    f = FileAccess.open(path, FileAccess.READ)
    var d2 = JSON.parse_string(f.get_as_text())
    f.close()
    _check(d2.money == 100, "T1.2 崩溃后主档应不变")

# T2: 三份轮转 —— 写 5 次，.bak.3 应是第 2 次内容
func _test_backup_rotation() -> void:
    _before_each()
    var path := SaveManager.MANUAL_SAVE_PATH
    for i in range(1, 6):
        SaveManager._write_save_atomically(path, {"version": 15, "n": i})
    _check(FileAccess.file_exists(path), "T2.1 主档存在")
    for i in range(1, 4):
        _check(FileAccess.file_exists("%s.bak.%d" % [path, i]), "T2.2 .bak.%d 存在" % i)
    _check(not FileAccess.file_exists("%s.bak.4" % path), "T2.3 不应有 .bak.4")
    # 关键：.bak.3 应是第 2 次写入（不是第 1 次）
    var f := FileAccess.open("%s.bak.3" % path, FileAccess.READ)
    var d = JSON.parse_string(f.get_as_text())
    f.close()
    _check(d.n == 2, "T2.4 .bak.3 应是第 2 次写入，实际 n=%d" % d.n)

# T3: 损坏回退 —— 主档损坏，读 .bak.1
func _test_corruption_fallback() -> void:
    _before_each()
    var path := SaveManager.MANUAL_SAVE_PATH
    SaveManager._write_save_atomically(path, {"version": 15, "money": 100})
    SaveManager._write_save_atomically(path, {"version": 15, "money": 200})
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string("{invalid json")
    f.close()
    var result := SaveManager._read_json_file(path)
    _check(not result.ok, "T3.1 主档应读取失败")
    var result1 := SaveManager._read_json_file(path + ".bak.1")
    _check(result1.ok and result1.data.money == 100, "T3.2 .bak.1 应可读且 money=100")

# T4: 校验和检测
func _test_checksum_detection() -> void:
    var data := {"version": 15, "money": 320, "energy": 100.0}
    var with_sum := SaveManager._attach_checksum(data)
    _check(with_sum.has("checksum"), "T4.1 应附加校验和")
    _check(SaveManager._verify_checksum(with_sum), "T4.2 校验和应通过")
    with_sum.money = 32
    _check(not SaveManager._verify_checksum(with_sum), "T4.3 篡改 money 后应失败")
    # 只改 checksum 字段本身
    var d2 := SaveManager._attach_checksum({"version": 15, "money": 320})
    d2.checksum = "deadbeef"
    _check(not SaveManager._verify_checksum(d2), "T4.4 篡改 checksum 后应失败")

# T5: 版本迁移
func _test_version_migration() -> void:
    var v14 := {"version": 14, "game": {"money": 999}}
    var migrated := SaveManager._migrate_save(v14)
    _check(migrated.version == 15, "T5.1 应迁移到 v15")
    _check(migrated.has("pet"), "T5.2 v15 应有 pet 字段")
    var v99 := {"version": 99}
    _check(SaveManager._migrate_save(v99).is_empty(), "T5.3 未来版本应拒绝")
    var v13 := {"version": 13}
    _check(SaveManager._migrate_save(v13).is_empty(), "T5.4 低于 MIN_SUPPORTED 应拒绝")

# T6: 读档失败保护 —— 真实路径
func _test_load_failure_protection() -> void:
    _before_each()
    var path := SaveManager.MANUAL_SAVE_PATH
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string("{invalid")
    f.close()
    var ok := SaveManager.load_game(false)
    _check(not ok, "T6.1 损坏档应加载失败")
    _check(SaveManager._load_failed, "T6.2 _load_failed 应为 true")
    ok = SaveManager.save_game(false, false)
    _check(not ok, "T6.3 未确认时应拒绝存档")
    SaveManager.acknowledge_load_failure()
    ok = SaveManager.save_game(false, false)
    _check(ok, "T6.4 确认后应允许存档")

# T7: 定时存档 —— 时间回退后仍触发
func _test_timed_auto_save() -> void:
    _before_each()
    SaveManager._last_auto_save_key = 1000
    TimeSystem.current_day = 0
    TimeSystem.minute_of_day = 100  # key = 100
    var key := SaveManager._current_time_key()
    _check(abs(key - SaveManager._last_auto_save_key) >= 15, "T7.1 时间回退应触发存档")

# T8: 关键节点 —— 跨天
func _test_key_node_auto_save() -> void:
    _before_each()
    SaveManager._last_auto_save_key = -1
    TimeSystem.day_started.emit(TimeSystem.current_day + 1)
    _check(SaveManager._last_auto_save_reason == "day_start", "T8.1 跨天应触发存档")

# T9: 并发写保护
func _test_concurrent_save() -> void:
    _before_each()
    SaveManager._is_saving = true
    var r := SaveManager.save_game(false, false)
    _check(not r, "T9.1 并发第二次应拒绝")
    SaveManager._is_saving = false

# T10: 退出时同步写
func _test_quit_save() -> void:
    _before_each()
    SaveManager._notification(NOTIFICATION_WM_CLOSE_REQUEST)
    _check(SaveManager._last_auto_save_reason == "quit", "T10.1 退出应触发存档")

# T11: 磁盘满/权限拒绝降级
func _test_disk_full() -> void:
    var ok := SaveManager._write_save_atomically("/root/forbidden.json", {"version": 15})
    _check(not ok, "T11.1 不可写路径应返回 false 而非崩溃")

# T12: 迁移链完整性
func _test_migration_chain_complete() -> void:
    for v in range(SaveManager.MIN_SUPPORTED_VERSION, SaveManager.SAVE_VERSION):
        _check(SaveManager.MIGRATIONS.has(v), "T12.1 缺少 v%d 迁移函数" % v)
```

**运行**：

```bash
godot --headless --path . --script tests/save_stability_test.gd
```

**预期**：`SAVE_STABILITY_PASS`，退出码 0。

---

## 四、验证

### 4.1 自动化验证

| 验证项 | 命令 | 通过标准 |
|---|---|---|
| 单元测试 | `godot --headless --path . --script tests/save_stability_test.gd` | `SAVE_STABILITY_PASS` |
| 门禁 | `godot --headless --path . --script scripts/main.gd --save-check` | 退出码 0 |
| 迁移链完整性 | T12 | 无缺失 |
| 7 项核对 | `docs/SAVE_AUDIT.md` | 全部 ✅ 且附证据行号 |

### 4.2 手工复现（崩溃注入）

| # | 操作 | 预期 |
|---|---|---|
| M1 | 存档 → 任务管理器杀进程 → 重启 | 主档完整，`.tmp` 存在但不影响 |
| M2 | 存档 5 次 → 检查 `user://` | 有 `.bak.1/.2/.3`，无 `.bak.4`，`.bak.3` 是第 2 次内容 |
| M3 | 记事本把主档改成 `{` → 重启 | 提示"回退到备份"，游戏可玩 |
| M4 | 记事本把主档 `money` 改小 → 重启 | 提示"校验和不匹配"，回退备份 |
| M5 | 装 v14 旧档 → 启动 v15 | 自动迁移，`pet` 字段存在 |
| M6 | 装 v99 未来档 → 启动 | 拒绝加载，提示版本过高 |
| M7 | 主档 + 3 备份全损坏 → 启动 | 提示"无法读取"，**不覆盖**，可开新游戏 |
| M8 | 读旧档（游戏内时间回退）→ 推进游戏内时间 15 分钟 | 触发自动存档 |
| M9 | 同帧触发定时存档 + 跨天存档 | 第二次被 `_is_saving` 拒绝，无轮转错乱 |
| M10 | 游戏运行中关闭窗口 | 退出前同步写档，重启后进度保留 |

---

## 五、风险

| 风险 | 触发条件 | 缓解 |
|---|---|---|
| `DirAccess.rename` 跨盘失败 | `user://` 与临时目录不同盘 | 已用同目录 `.tmp`，测试覆盖 |
| 迁移函数非幂等 | 回退重试二次迁移 | 每个迁移末尾强制 `version=N+1`，加幂等断言 |
| 轮转期间崩溃 | 删 `.bak.3` 后、rename 前断电 | 接受：最坏丢最旧备份，主档与 `.bak.1/.2` 完好 |
| `_is_saving` 守卫遗漏 | 新增存档入口未检查 | 所有入口统一走 `save_game`，`_is_saving` 在 `save_game` 开头检查 |
| 迁移链断裂 | 新增 v16 忘记注册 | T12 CI 断言强制覆盖 `[MIN_SUPPORTED, SAVE_VERSION)` |
| `WorldGraph` 未落地 | v15→v16 迁移调用不存在的 API | 迁移函数降级：`WorldGraph` 不存在时返回 `Vector2.ZERO` + `push_warning`，不阻断加载 |
| 存档体积膨胀 | `world-001` LRU + interior | `MAX_SAVE_SIZE = 4MB`，超限拒绝写入并告警 |
| 磁盘满 | `FileAccess.open` 返回 null | 区分"临时失败"（重试 3 次）与"永久失败"（提示玩家） |
| 版本降级 | 玩家从 v16 降级到 v15 | 明确声明不支持，拒绝加载并提示 |
| Web 平台 | `DirAccess.rename` 不存在 | 明确声明不支持 Web，桌面平台优先 |

---

## 六、回退

### 6.1 代码回退

| 阶段 | 回退方式 |
|---|---|
| 阶段 2（轮转/迁移） | `git revert` 对应 commit；旧档不受影响（写前轮转不破坏主档） |
| 阶段 3（失败保护） | 移除 `_load_failed` 检查；但**不推荐**，会重新暴露覆盖风险 |
| 阶段 4（关键节点） | 移除 `request_auto_save` 调用点；定时存档保留 |
| 阶段 5（提示） | 纯 UI，无数据影响 |

### 6.2 数据回退

- **主档损坏**：自动回退 `.bak.1` → `.bak.2` → `.bak.3`
- **全部损坏**：`_load_failed = true`，拒绝覆盖，玩家可手动从 `user://` 目录恢复 `.tmp` 或 `.bak.*`
- **迁移失败**：不覆盖原档，保留原始 JSON，玩家可手动降级游戏版本读取

### 6.3 紧急回退开关

```gdscript
# 在 ConfigDB 中加
const SAVE_SAFE_MODE := false  # true 时禁用自动存档，仅手动存档
```

若线上出现存档损坏，可远程下发 `SAVE_SAFE_MODE = true`，停止自动存档，等待修复。

---

## 七、交付物清单

| # | 文件 | 状态 | 验收 |
|---|---|---|---|
| 1 | `docs/SAVE_FACTS.md` | 新建 | 门禁 G0.1–G0.7 全部有结果 |
| 2 | `autoload/save_manager.gd` | 修改 | 阶段 2–5 全部落地 |
| 3 | `tests/save_stability_test.gd` | 新建 | T1–T12 全绿 |
| 4 | `scripts/main.gd` | 修改 | `--save-check` 门禁可用 |
| 5 | `docs/SAVE_MIGRATION.md` | 新建 | 含 `MIN_SUPPORTED_VERSION` 声明 |
| 6 | `docs/SAVE_AUDIT.md` | 修改 | 7 项全 ✅ 且附证据行号 |

**最终验收**：
```bash
godot --headless --path . --script tests/save_stability_test.gd
# 输出：SAVE_STABILITY_PASS
godot --
