# 餐饮线/工厂线双职业晋升与跳槽

## 主方案

# 餐饮线/工厂线双职业晋升与跳槽 —— 唯一可执行方案

> 综合裁决：以现有 `career_manager.gd` 的**信号驱动 + 隐藏点数 + NPC 暗示**骨架为基线，吸收 `gameplay-001` 的"开局无工作"硬约束与 `npc-002` 的"提示三通道分离"约束，**删除所有进度条/数值展示**，补齐应聘→试工→晋升→师傅认可→跳槽→辞职→被挖走七段闭环。
> **前置裁决**：本方案**不新增场景**，餐饮线复用 `home`（黄姐早餐店）+ `night_market`（老宋夜宵摊，若存在），工厂线复用 `factory`（王师傅车间）。`night_market` 存在性由 G0 门禁判定，不存在则餐饮线只走早餐店。

---

## 一、决策（逐条裁决，无歧义）

| # | 争议点 | 最终裁决 | 理由 |
|---|---|---|---|
| D1 | 开局是否有工作 | **无**。`reset_new_game()` 后 `current_line=""`，`is_employed()==false` | 任务硬约束；现有代码已满足，只需**删除任何自动入职调用** |
| D2 | 进度反馈形式 | **纯 NPC 台词 + 场景事件**。删除 `hidden_points` 的对外暴露，仅内部累积 | 约束"无数值属性条"；`hidden_points` 保留为内部字段但**不写入任何 UI** |
| D3 | 晋升触发 | **师傅认可事件**（`wang`/`huang`/`song` 的 `npc_stories` 阶段推进）→ 满足阈值 → 下一次上班时触发 `promoted` 信号 | 无进度条；靠 NPC 暗示 |
| D4 | 跳槽语义 | **在职跳槽**：先辞职再应聘新线；**被挖走**：在职时被对方师傅主动接触，无需辞职 | 区分主动/被动，制造叙事差异 |
| D5 | 被挖走触发 | 在 A 线达到 rank≥2 且 `hidden_points≥阈值` 时，B 线师傅在**场景偶遇**中主动搭话 | 场景事件驱动，非菜单 |
| D6 | 辞职代价 | **无金钱惩罚**，但 `layoff_count` 不增加；辞职后 `current_line=""`，`hidden_points` 保留 50% | 温柔治愈；保留部分积累避免挫败 |
| D7 | 被辞退 | 连续 `low_performance_streak≥3` 触发 `laid_off`，给遣散费 | 现有信号已定义，保留 |
| D8 | 数据源 | **`data/careers.csv` 为唯一事实源**，新增 `line`/`rank`/`title`/`wage`/`trial_required`/`promote_threshold`/`credential` 列 | 现有 `ConfigDB.get_rows("careers")` 已按此读取 |
| D9 | 与 StaffManager 关系 | **StaffManager 管"店铺雇员"（NPC 帮工），CareerManager 管"玩家职业"**。两者通过 `staff_hired` flag 单向联动 | 避免职责重叠；`huang_2` 故事已用 `staff_hired` |
| D10 | 与 CalendarManager 关系 | **CareerManager 只读 CalendarManager 的 `day`/`hour`/`weekday`**，不反向写入 | 单向依赖，避免循环 |
| D11 | 提示通道 | 全部走 `NoticeManager.show_message(msg, kind, speaker)`，`speaker` 显式传入师傅名 | 符合 `npc-002` D4/D13 |
| D12 | 存档字段 | 新增 `career_state` 子字典，旧档缺失时按默认值补全 | 存档兼容 |

---

## 二、数据字段（唯一事实源）

### 2.1 `data/careers.csv`（改造现有表）

**新增/确认列**（保留原有列，新增列追加在末尾，避免破坏 `row[5]` 索引式读取——G0.3 门禁确认读取方式）：

| 列名 | 类型 | 说明 | 示例 |
|---|---|---|---|
| `career_id` | string | 主键，格式 `{line}_{rank}` | `catering_1` |
| `line` | string | 职业线 ID | `catering` / `factory` |
| `rank` | int | 职级，从 1 开始 | `1` |
| `title` | string | 职级名 | `帮厨` / `学徒` |
| `description` | string | 一句话描述 | `先学会洗菜和备料` |
| `wage` | int | 每班工资（元） | `60` |
| `trial_required` | int | 试工需完成动作数 | `3` |
| `promote_threshold` | float | 晋升所需隐藏点数 | `12.0` |
| `credential` | string | 晋升所需凭证 flag（空=无） | `food_safety_card` |
| `shift_minutes` | int | 每班消耗游戏分钟 | `180` |
| `energy_cost` | float | 每班体力消耗 | `12.0` |
| `work_area` | string | 上班场景 key | `home` / `factory` |
| `master_npc` | string | 师傅 NPC ID | `huang` / `wang` |

**餐饮线（catering）四档**：

| rank | title | wage | promote_threshold | credential |
|---|---|---|---|---|
| 1 | 帮厨 | 60 | 12.0 | — |
| 2 | 掌勺 | 110 | 28.0 | `food_safety_card` |
| 3 | 主厨 | 180 | 50.0 | — |
| 4 | 店长 | 260 | 90.0 | `business_license` |

**工厂线（factory）四档**：

| rank | title | wage | promote_threshold | credential |
|---|---|---|---|---|
| 1 | 学徒 | 70 | 12.0 | — |
| 2 | 熟练工 | 120 | 28.0 | `safety_cert` |
| 3 | 组长 | 190 | 50.0 | — |
| 4 | 车间主管 | 280 | 90.0 | `management_cert` |

### 2.2 `data/career_events.csv`（新建）

场景事件表，驱动"被挖走""师傅认可""跳槽邀请"：

| 列名 | 类型 | 说明 |
|---|---|---|
| `event_id` | string | 主键 |
| `trigger_type` | string | `encounter` / `shift_end` / `story_stage` |
| `line` | string | 目标职业线 |
| `min_rank` | int | 触发所需当前职级 |
| `min_points` | float | 触发所需隐藏点数 |
| `required_flag` | string | 额外 flag 条件 |
| `npc_id` | string | 发起 NPC |
| `scene_key` | string | 触发场景 |
| `message` | string | 台词 |
| `effect` | string | `offer_poach` / `praise` / `warn` |
| `cooldown_days` | int | 冷却天数 |

**示例行**：

```csv
event_id,trigger_type,line,min_rank,min_points,required_flag,npc_id,scene_key,message,effect,cooldown_days
poach_factory_1,encounter,factory,2,30,,wang,home,"王师傅在巷口叫住你，说车间缺个带班的，问你有没有兴趣。",offer_poach,7
poach_catering_1,encounter,catering,2,30,,huang,street,"黄姐端着两碗豆浆过来，说夜宵摊缺个能掌勺的，想不想试试。",offer_poach,7
praise_factory_1,shift_end,factory,1,8,,wang,factory,"王师傅拍了拍你的肩，说今天这几件活干得干净。",praise,0
praise_catering_1,shift_end,catering,1,8,,huang,home,"黄姐尝了一口，没说话，又添了半勺盐。",praise,0
```

### 2.3 `autoload/career_manager.gd` 新增字段

```gdscript
# 新增（保留现有全部字段）
var poach_offer_line := ""          # 被挖走的目标线，空=无
var poach_offer_expire_day := -1    # 挖角邀约过期日
var last_shift_day := -1            # 上次上班的游戏日，防同日重复
var career_event_cooldowns: Dictionary = {}  # event_id -> 冷却结束日
var resigned_lines: Array[String] = []       # 已辞职过的线，用于台词差异
```

### 2.4 存档字段（`SaveManager` 序列化）

```gdscript
"career_state": {
    "current_line": current_line,
    "current_rank": current_rank,
    "shifts_done": shifts_done,
    "hidden_points": hidden_points,
    "application_line": application_line,
    "application_stage": application_stage,
    "trial_progress": trial_progress,
    "trial_required": trial_required,
    "low_performance_streak": low_performance_streak,
    "layoff_count": layoff_count,
    "poach_offer_line": poach_offer_line,
    "poach_offer_expire_day": poach_offer_expire_day,
    "last_shift_day": last_shift_day,
    "career_event_cooldowns": career_event_cooldowns,
    "resigned_lines": resigned_lines,
}
```

**兼容规则**：读档时若 `career_state` 缺失或字段缺失，按 `reset_new_game()` 默认值补全，**不报错**。

---

## 三、状态机

### 3.1 主状态机（`application_stage` + `current_line`）

```
                    ┌─────────────────────────────────────────┐
                    │                                         │
   [UNEMPLOYED] ──register_interest──> [APPLIED] ──start_trial──> [TRIAL]
        ▲                                  │                        │
        │                                  │                        │ perform_trial_action ×N
        │                                  │                        ▼
        │                                  │                   [TRIAL_DONE]
        │                                  │                        │
        │                                  │                  confirm_application
        │                                  │                        ▼
        │                                  │                   [EMPLOYED]
        │                                  │                        │
        │                                  │              ┌─────────┼─────────┐
        │                                  │              │         │         │
        │                                  │         work_shift  promote  poach_offer
        │                                  │              │         │         │
        │                                  │              ▼         ▼         ▼
        │                                  │         [EMPLOYED] [PROMOTED] [POACH_PENDING]
        │                                  │                              │
        │                                  │                    accept_poach / decline_poach
        │                                  │                              │
        │                                  │                              ▼
        │                                  │                        [EMPLOYED(新线)]
        │                                  │
        │                            resign / laid_off
        │                                  │
        └──────────────────────────────────┘
```

**状态枚举**（内部，不对外展示）：

| 状态 | 判定条件 | 可执行动作 |
|---|---|---|
| `UNEMPLOYED` | `current_line=="" and application_line==""` | `register_interest` |
| `APPLIED` | `application_line!="" and application_stage==1` | `start_trial` / `perform_trial_action` |
| `TRIAL` | `application_stage==2` | `perform_trial_action` |
| `TRIAL_DONE` | `application_stage==3` | `confirm_application` |
| `EMPLOYED` | `current_line!="" and current_rank>0` | `work_shift` / `resign` |
| `POACH_PENDING` | `poach_offer_line!=""` | `accept_poach` / `decline_poach` |

### 3.2 晋升子状态机

```
[EMPLOYED rank=N]
    │
    ├─ work_shift() 每次 +hidden_points（基础 4.0 + 表现修正）
    │
    ├─ 师傅认可事件（career_events.csv trigger_type=shift_end）
    │   └─ 触发时 +hidden_points 额外 3.0，并推送 praise 台词
    │
    ├─ hidden_points >= promote_threshold[rank]
    │   ├─ credential 为空 → 下次 work_shift 时触发 promoted
    │   └─ credential 非空 → 检查 GameState.has_flag(credential)
    │       ├─ 有 → 下次 work_shift 时触发 promoted
    │       └─ 无 → 推送 _blocked_credential 提示（师傅暗示"先去把证办了"）
    │
    └─ low_performance_streak >= 3 → laid_off
```

**表现修正规则**（`work_shift` 内计算，不展示）：

| 条件 | hidden_points 增量 |
|---|---|
| 基础 | +4.0 |
| 当日体力 > 70% | +1.0 |
| 当日体力 < 30% | -1.0 |
| 连续上班（`last_shift_day == day-1`） | +0.5 |
| 间隔 > 3 天未上班 | -0.5 |
| 师傅认可事件触发 | +3.0 |

**`low_performance_streak` 判定**：单次 `work_shift` 增量 < 3.0 时 +1，否则归零。

---

## 四、触发点（场景交互，非菜单）

### 4.1 应聘触发

| 场景 | 交互物 | 动作 | 调用 |
|---|---|---|---|
| `home`（早餐店门口） | 招聘木牌 | TAP | `CareerManager.register_interest("catering")` |
| `factory`（车间门口） | 招工告示 | TAP | `CareerManager.register_interest("factory")` |
| `night_market`（若存在） | 老宋摊位旁的纸板 | TAP | `CareerManager.register_interest("catering")` |

**交互物实现**：继承 `WorldInteractable`，`on_tap()` 内调用 `CareerManager.register_interest()`，**不弹菜单**。

### 4.2 试工触发

| 场景 | 交互物 | 动作 | 调用 |
|---|---|---|---|
| `home`（灶台） | 灶台 | TAP | `CareerManager.perform_trial_action("catering")` |
| `factory`（工位） | 工位 | TAP | `CareerManager.perform_trial_action("factory")` |

**试工动作文案**（`_trial_action_text`）：

- 餐饮：`"把这一筐青菜择了"` / `"看着火候，别糊了"` / `"把碗筷摆齐"`
- 工厂：`"把这批零件码好"` / `"跟着师傅走一遍流程"` / `"检查一遍安全扣"`

### 4.3 上班触发

| 场景 | 交互物 | 动作 | 调用 |
|---|---|---|---|
| `home`（灶台，已入职 catering） | 灶台 | TAP | `CareerManager.work_shift()` |
| `factory`（工位，已入职 factory） | 工位 | TAP | `CareerManager.work_shift()` |

**`work_shift()` 前置检查**：

1. `is_employed()` 为真
2. `last_shift_day != CalendarManager.day`（同日不重复）
3. `GameState.energy >= energy_cost`
4. `CalendarManager.hour` 在班次时段内（餐饮 5:00–10:00 / 17:00–22:00；工厂 8:00–12:00 / 13:00–17:00）

### 4.4 晋升触发

**不设独立交互物**。晋升在 `work_shift()` 结算末尾自动判定，通过 `promoted` 信号推送台词：

```gdscript
promoted.emit(line_id, new_title, "%s把新的班表递给你，说以后这摊子你多看着点。" % master_name)
```

### 4.5 师傅认可触发

**由 `career_events.csv` 驱动**，在 `work_shift()` 结算后调用 `_try_career_event("shift_end")`：

```gdscript
func _try_career_event(trigger_type: String) -> void:
    for event_id in ConfigDB.get_rows("career_events"):
        var row := ConfigDB.get_row("career_events", event_id)
        if str(row.get("trigger_type", "")) != trigger_type:
            continue
        if str(row.get("line", "")) != current_line:
            continue
        if current_rank < int(row.get("min_rank", 0)):
            continue
        if hidden_points < float(row.get("min_points", 0.0)):
            continue
        var flag := str(row.get("required_flag", ""))
        if not flag.is_empty() and not GameState.has_flag(flag):
            continue
        if _is_on_cooldown(event_id):
            continue
        _fire_career_event(event_id, row)
```

### 4.6 跳槽/被挖走触发

**被挖走**：`trigger_type=encounter`，在玩家**进入场景时**由 `SceneRouter` 调用 `CareerManager.try_encounter_event(scene_key)`：

```gdscript
func try_encounter_event(scene_key: String) -> void:
    if not is_employed():
        return
    for event_id in ConfigDB.get_rows("career_events"):
        var row := ConfigDB.get_row("career_events", event_id)
        if str(row.get("trigger_type", "")) != "encounter":
            continue
        if str(row.get("scene_key", "")) != scene_key:
            continue
        if str(row.get("line", "")) == current_line:
            continue  # 不挖自己线
        if current_rank < int(row.get("min_rank", 0)):
            continue
        if hidden_points < float(row.get("min_points", 0.0)):
            continue
        if _is_on_cooldown(event_id):
            continue
        _fire_poach_offer(event_id, row)
```

**`_fire_poach_offer`**：设置 `poach_offer_line`，推送台词，**不弹菜单**。玩家在**下一次进入目标线场景**时，通过交互物 TAP 接受/拒绝：

| 场景 | 交互物 | 动作 | 调用 |
|---|---|---|---|
| 目标线场景 | 师傅 NPC 本体 | TAP | `CareerManager.accept_poach()` |
| 任意场景 | 师傅 NPC 本体 | HOLD（长按） | `CareerManager.decline_poach()` |

**接受被挖走**：`current_line` 切换，`current_rank` 从 1 开始，`hidden_points` 保留 70%（对方认可你的能力）。

### 4.7 辞职触发

| 场景 | 交互物 | 动作 | 调用 |
|---|---|---|---|
| 当前线场景 | 师傅 NPC 本体 | HOLD（长按 ≥1.5s） | `CareerManager.resign()` |

**`resign()` 二次确认**：第一次 HOLD 推送 `"确定要辞职吗？再长按一次。"`，3 秒内第二次 HOLD 才执行。

### 4.8 被辞退触发

`work_shift()` 结算时若 `low_performance_streak >= 3`，触发 `laid_off` 信号，给遣散费 `wage * 2`。

---

## 五、与 StaffManager / CalendarManager 的接口

### 5.1 与 StaffManager

**职责边界**：StaffManager 管"店铺雇员 NPC"（如黄姐店里的帮工），CareerManager 管"玩家职业"。

**单向联动**：

| 方向 | 接口 | 说明 |
|---|---|---|
| CareerManager → StaffManager | `StaffManager.has_staff(store_id)` | 玩家晋升到 rank≥3 时，若店铺无雇员，师傅暗示"该招个人了" |
| StaffManager → CareerManager | `GameState.set_flag("staff_hired")` | 已有 flag，`huang_2` 故事用；CareerManager 只读不写 |

**不新增接口**。若需联动，通过 `GameState` flag 中转。

### 5.2 与 CalendarManager

**单向只读**：

| 读取字段 | 用途 |
|---|---|
| `CalendarManager.day` | `last_shift_day` 比较、冷却计算 |
| `CalendarManager.hour` | 班次时段检查 |
| `CalendarManager.weekday` | 周末班次工资 ×1.2（可选，P2） |

**不反向写入**。CareerManager 不推进时间，时间推进由 `work_shift()` 内调用 `TimeSystem.advance_minutes(shift_minutes)` 完成。

### 5.3 与 NoticeManager

**全部提示走单通道**：

```gdscript
NoticeManager.show_message(msg, kind, speaker)
```

- `kind`：`"positive"` / `"hint"` / `"warning"`
- `speaker`：师傅名（`"黄姐"` / `"王师傅"` / `"老宋"`）

**禁止**：`NoticeManager.show_message(msg)` 不传 speaker（违反 `npc-002` D13）。

### 5.4 与 SaveManager

**存档触发点**：

| 动作 | `request_auto_save` reason |
|---|---|
| `register_interest` | `"career_interest"` |
| `start_trial` | `"career_trial_start"` |
| `perform_trial_action` | `"career_trial_action"` |
| `confirm_application` | `"career_hired"` |
| `work_shift` | `"career_shift"` |
| `promoted` | `"career_promoted"` |
| `resign` | `"career_resign"` |
| `accept_poach` | `"career_poach"` |
| `laid_off` | `"career_laid_off"` |

**reason 白名单**：需在 `SaveManager.KEY_NODE_REASONS` 注册以上 9 个 reason，否则 `request_auto_save` 返回 false（`save-001` D11 硬约束）。

---

## 六、执行步骤

### 阶段 0：门禁（阻塞，未过不得改代码）

```bash
# G0.1 确认 careers.csv 现有列与读取方式
grep -rn "careers" --include=*.gd scripts/ autoload/
grep -rn "DictReader\|row\[" --include=*.py . | grep -i career

# G0.2 确认 night_market 场景存在
grep -rn "night_market" data/scene_zones.csv data/scene_metadata.csv

# G0.3 确认 SaveManager.KEY_NODE_REASONS 现状
grep -n "KEY_NODE_REASONS" -A 30 autoload/save_manager.gd

# G0.4 确认 CalendarManager 字段名
grep -n "var day\|var hour\|var weekday" autoload/calendar_manager.gd

# G0.5 确认 WorldInteractable 手势方法签名
grep -n "func on_tap\|func on_hold\|func on_drag" scripts/world_interactable.gd
```

**结果写入 `docs/CAREER_FACTS.md`**，作为后续唯一事实源。

### 阶段 1：数据层

1. 改造 `data/careers.csv`，按 §2.1 补列，填 8 行（餐饮 4 + 工厂 4）
2. 新建 `data/career_events.csv`，按 §2.2 填至少 6 行（每线 3 行：praise / poach / warn）
3. 校验：`python tools/validate_careers.py`（若不存在，本阶段新建）

### 阶段 2：CareerManager 改造

1. 新增 §2.3 字段
2. 实现 `work_shift()`（含表现修正、晋升判定、事件触发）
3. 实现 `resign()` / `accept_poach()` / `decline_poach()`
4. 实现 `try_encounter_event(scene_key)`
5. 实现 `_try_career_event(trigger_type)` / `_fire_career_event` / `_fire_poach_offer`
6. 实现 `_is_on_cooldown(event_id)` / `_set_cooldown(event_id, days)`
7. **删除**任何自动入职调用（`_ready` 内不得调用 `confirm_application`）

### 阶段 3：场景交互物

1. `home` 场景：招聘木牌、灶台（两个 `WorldInteractable` 子类）
2. `factory` 场景：招工告示、工位
3. `night_market`（若存在）：老宋摊位纸板
4. 师傅 NPC 本体：绑定 `on_tap`（接受挖角）/ `on_hold`（辞职）

### 阶段 4：存档兼容

1. `SaveManager` 序列化 `career_state` 子字典
2. 读档时缺失字段按默认值补全
3. 注册 9 个 `KEY_NODE_REASONS`

### 阶段 5：验证

见 §七。

---

## 七、验证

### 7.1 单元测试（`tests/test_career_manager.gd`）

| 用例 | 断言 |
|---|---|
| 开局无工作 | `reset_new_game()` 后 `is_employed()==false` |
| 应聘流程 | `register_interest("catering")` → `application_stage==1` |
| 试工流程 | `perform_trial_action` × `trial_required` → `application_stage==3` |
| 入职 | `confirm_application` → `is_employed_in("catering")` |
| 上班 | `work_shift()` → `shifts_done+1`，`hidden_points` 增加 |
| 晋升 | 手动设 `hidden_points=threshold` → `work_shift()` → `current_rank+1` |
| 凭证阻塞 | 设 `hidden_points=threshold` 但无 credential → `work_shift()` 不晋升，推送提示 |
| 辞职 | `resign()` → `is_employed()==false`，`hidden_points` 保留 50% |
| 被挖走 | 设 `poach_offer_line="factory"` → `accept_poach()` → `current_line=="factory"` |
| 被辞退 | 设 `low_performance_streak=3` → `work_shift()` → `laid_off` 信号 |
| 冷却 | `_set_cooldown("poach_factory_1", 7)` → 7 天内不触发 |
| 存档往返 | 序列化→反序列化→字段一致 |

### 7.2 集成测试（`tests/test_career_integration.gd`）

| 用例 | 断言 |
|---|---|
| 场景交互物 TAP | 模拟 TAP 招聘木牌 → `application_stage==1` |
| 师傅 NPC HOLD | 模拟 HOLD 师傅 → `resign()` 被调用 |
| 进入场景触发挖角 | `try_encounter_event("home")` → `poach_offer_line` 非空 |
| 提示通道 | 所有 `NoticeManager.show_message` 调用均传 speaker |

### 7.3 手动验收（`docs/CAREER_PLAYTEST.md`）

1. 新档开局，确认无工作
2. 走到早餐店，TAP 招聘木牌，确认提示
3. TAP 灶台试工 3 次，确认师傅台词变化
4. 确认入职，TAP 灶台上班，确认工资到账
5. 连续上班至晋升，确认师傅台词变化，**无进度条**
6. 长按师傅辞职，确认二次确认
7. 应聘工厂线，确认被挖角事件触发
8. 接受挖角，确认职级重置但保留部分点数

---

## 八、风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| `careers.csv` 读取方式为索引式，新增列破坏现有代码 | **P0** | G0.1 门禁确认；若索引式，新建 `careers_ext.csv` 用 `career_id` join |
| `night_market` 场景不存在 | **P1** | G0.2 门禁确认；不存在则餐饮线只走早餐店，`career_events.csv` 删除相关行 |
| `WorldInteractable` 无 `on_hold` 方法 | **P1** | G0.5 门禁确认；若无，本方案新增虚方法（与 `ui-002` 协调） |
| `SaveManager.KEY_NODE_REASONS` 未注册新 reason | **P1** | 阶段 4 显式注册；未注册时 `request_auto_save` 返回 false，测试用例覆盖 |
| 旧档 `career_state` 缺失导致读档失败 | **P0** | 读档时按默认值补全，不报错；测试用例覆盖 |
| 晋升阈值过高导致首周无法晋升 | **P2** | `gameplay-001` 已定首周目标"工厂正式工"，`promote_threshold=12.0` 对应约 3 班，可接受 |
| 被挖走事件与 `npc-001` 新 NPC 冲突 | **P2** | 本方案只用现有 NPC（`wang`/`huang`/`song`），不依赖新 NPC |
| 提示通道被 `npc-002` 的 `NoticeArbiter` 抢占 | **P2** | 本方案走 `NoticeManager`，`npc-002` 若迁移到 `NoticeArbiter`，本方案同步迁移 |

---

## 九、交付物清单

| 文件 | 操作 |
|---|---|
| `data/careers.csv` | 改造（补列 + 填 8 行） |
| `data/career_events.csv` | 新建 |
| `autoload/career_manager.gd` | 改造（新增字段 + 7 个方法） |
| `autoload/save_manager.gd` | 改造（序列化 + reason 注册） |
| `scripts/interactables/job_board.gd` | 新建 |
| `scripts/interactables/work_station.gd` | 新建 |
| `scripts/interactables/master_npc.gd` | 新建 |
| `tests/test_career_manager.gd` | 新建 |
| `tests/test_career_integration.gd` | 新建 |
| `docs/CAREER_FACTS.md` | 新建（门禁结果） |
| `docs/CAREER_PLAYTEST.md` | 新建（手动验收） |
| `tools/validate_careers.py` | 新建（数据校验） |

---

**执行顺序**：阶段 0 → 阶段 1 → 阶段 2 → 阶段 3 → 阶段 4 → 阶段 5。**阶段 0 未过，禁止进入阶段 1**。

## 独立方案

# 独立方案：餐饮线/工厂线双职业晋升与跳槽

> 独立方案 Agent 输出。**不迎合主方案**。核心分歧：主方案倾向"扩展 `CareerManager` 单例 + 大量 `application_stage` 整数状态"，本方案主张 **"职业线数据驱动 + 显式状态机 + 事件总线"**，把 `CareerManager` 降级为**薄门面**，真正的状态转移由 `CareerFSM` 纯函数驱动，可单测、可回放、可存档兼容。

---

## 0. 与主方案的根本分歧（先说清楚）

| 维度 | 主方案倾向 | **本方案** | 理由 |
|---|---|---|---|
| 状态载体 | `application_stage: int`（1/2/3） | **枚举 `CareerState` + 显式转移表** | 整数魔法值不可读、不可断言、易越界 |
| 晋升判定 | `hidden_points` 浮点累加 | **`CareerFSM.evaluate(ctx) -> Transition`** 纯函数 | 可单测、可回放、无副作用 |
| 数据来源 | 硬编码在 `career_manager.gd` | **`data/careers.csv` + `data/career_ranks.csv` + `data/career_events.csv`** | 加线不改代码 |
| 与 StaffManager | 未定义 | **StaffManager 只管"班次结算"，CareerManager 只管"身份状态"**，通过 `shift_settled` 信号解耦 | 单一职责 |
| 与 CalendarManager | 未定义 | **CalendarManager 只发 `day_started` / `minute_changed`**，CareerManager 订阅，不反向调用 | 单向依赖 |
| 跳槽/被挖 | 未定义 | **`CareerOffer` 数据结构 + `offer_expires_day`** | 无面板，靠 NPC 口头给 offer |
| 开局 | `reset_new_game()` 清空 | **同，但新增 `has_ever_worked` 标志** | 区分"从没工作"和"辞职后" |

**关键约束遵守**：无进度条 → 所有进度以 `hidden_points` 存在，**只通过 NPC 台词和场景事件外化**；无数值属性条 → 玩家永远看不到数字。

---

## 1. 数据字段（CSV，唯一事实源）

### 1.1 `data/careers.csv`（职业线定义）

```csv
line_id,line_name,entry_npc,entry_area,trial_speaker,trial_action_text,quit_npc,quit_line,poach_npc,poach_condition
food,餐饮线,huang,home,huang,把一笼包子端到窗口,huang,黄姐说灶台不等人，想走就趁早。,huang,day>=10 and rank>=2
factory,工厂线,wang,factory,wang,把零件按规格码进料箱,wang,王师傅把工牌收回去，说手要稳，心也要稳。,wang,day>=10 and rank>=2
```

**字段说明**：
- `entry_npc`：招聘板/口头招工 NPC（复用现有 `huang`/`wang`，**不新增 NPC**）
- `trial_speaker`：试工时的现场负责人（同 entry_npc，避免新增）
- `quit_npc` / `quit_line`：辞职时的 NPC 与台词（**辞职是场景事件，不是菜单**）
- `poach_npc` / `poach_condition`：被挖走的触发条件（表达式字符串，由 `CareerFSM` 解析）

### 1.2 `data/career_ranks.csv`（岗位阶梯）

```csv
line_id,rank,title,description,promote_hint,demote_hint,shift_wage,energy_cost,required_shifts,required_credential,required_affinity
food,1,帮厨,洗菜、备料、看火候。,黄姐说你手还生，先站灶台边看。,黄姐让你先回去歇几天。,45,8,3,,2
food,2,掌勺,能独立出一份早餐。,黄姐把菜单往你手里一塞，说今天你来。,黄姐说你火候还差一点。,70,10,8,,6
food,3,店长,排班、进货、看账。,黄姐说她可以晚来半小时了。,黄姐说店里还是她说了算。,95,12,20,food_cert,12
factory,1,临时工,搬料、码箱、听哨。,王师傅说先学会停手，再学会赶工。,王师傅让你明天不用来了。,50,9,3,,2
factory,2,正式工,能上机床、能看图纸。,王师傅把班表往你手里一推。,王师傅说你图纸还看不全。,75,11,8,,6
factory,3,带班,分活、盯安全、带新人。,王师傅站在不远处，像个不肯退休的影子。,王师傅说带班不是嗓门大。,100,13,20,factory_cert,12
```

**字段说明**：
- `required_shifts`：晋升所需累计班次数（**不是进度条，是隐藏计数**）
- `required_credential`：需要夜校证书（复用 `teacher_yu` 的 `food_cert`/`factory_cert`，**不新增系统**）
- `required_affinity`：需要与 `entry_npc` 的亲和度（复用现有 `npc_stories` 的 affinity）
- `promote_hint` / `demote_hint`：**NPC 暗示台词**，晋升/降级时通过 `NoticeManager` 以 NPC 口吻发出

### 1.3 `data/career_events.csv`（场景事件触发点）

```csv
event_id,line_id,trigger_type,trigger_value,state_from,state_to,notice_text,speaker,priority
food_trial_start,food,interact,stove,APPLIED,TRIAL,黄姐把你带到灶台边，说先看三笼。,huang,career
food_trial_done,food,shift_count,3,TRIAL,TRIAL_DONE,黄姐尝了一口，没说话，把围裙递给你。,huang,career
food_hired,food,interact,menu_board,TRIAL_DONE,EMPLOYED,黄姐在墙上写了你的名字，说从明天开始算工。,huang,career
food_promote_2,food,shift_count,8,EMPLOYED,RANK_UP,黄姐把菜单往你手里一塞，说今天你来。,huang,career
food_quit,food,interact,back_door,EMPLOYED,UNEMPLOYED,黄姐说灶台不等人，想走就趁早。,huang,career
factory_trial_start,factory,interact,workbench,APPLIED,TRIAL,王师傅把你领到料箱前，说先码三箱。,wang,career
factory_trial_done,factory,shift_count,3,TRIAL,TRIAL_DONE,王师傅翻了翻料箱，说手还行。,wang,career
factory_hired,factory,interact,foreman_desk,TRIAL_DONE,EMPLOYED,王师傅把工牌翻到背面，说先学会停手。,wang,career
factory_promote_2,factory,shift_count,8,EMPLOYED,RANK_UP,王师傅把班表往你手里一推。,wang,career
factory_quit,factory,interact,gate,EMPLOYED,UNEMPLOYED,王师傅把工牌收回去，说手要稳，心也要稳。,wang,career
```

**关键设计**：`trigger_type` 只有三种——`interact`（场景点击）、`shift_count`（班次累计）、`day`（日历）。**没有 `progress_bar` 类型**，符合约束。

---

## 2. 状态机（显式枚举 + 转移表）

### 2.1 状态枚举

```gdscript
# scripts/career/career_state.gd
enum State {
    IDLE,          # 开局：无工作、无申请
    APPLIED,       # 已在招聘板登记
    TRIAL,         # 试工中
    TRIAL_DONE,    # 试工完成，待确认入职
    EMPLOYED,      # 正式在职（rank >= 1）
    RANK_UP,       # 晋升过渡态（同帧转 EMPLOYED，仅用于发信号）
    OFFERED,       # 被挖走，收到 offer（未接受）
    UNEMPLOYED,    # 辞职/被裁后
}
```

**与主方案 `application_stage: int` 的差异**：`OFFERED` 是主方案缺失的状态——被挖走必须有"收到 offer 但未接受"的中间态，否则玩家没有拒绝权。

### 2.2 转移表（纯数据，可单测）

```gdscript
# scripts/career/career_fsm.gd
const TRANSITIONS := {
    State.IDLE:       [State.APPLIED],
    State.APPLIED:    [State.TRIAL, State.IDLE],
    State.TRIAL:      [State.TRIAL_DONE, State.APPLIED],
    State.TRIAL_DONE: [State.EMPLOYED, State.IDLE],
    State.EMPLOYED:   [State.RANK_UP, State.UNEMPLOYED, State.OFFERED],
    State.RANK_UP:    [State.EMPLOYED],
    State.OFFERED:    [State.EMPLOYED, State.UNEMPLOYED],  # 接受=换线，拒绝=留任
    State.UNEMPLOYED: [State.APPLIED],
}

static func can_transition(from: State, to: State) -> bool:
    return to in TRANSITIONS.get(from, [])
```

### 2.3 纯函数评估器

```gdscript
# scripts/career/career_fsm.gd
static func evaluate(ctx: Dictionary) -> Dictionary:
    ## 输入：{state, line_id, rank, shifts_done, affinity, credentials, day, offers}
    ## 输出：{transition: State, reason: String, hint: String, speaker: String}
    var state: int = ctx.state
    var line_id: String = ctx.line_id
    var rank: int = ctx.rank
    var shifts: int = ctx.shifts_done

    # 晋升判定
    if state == State.EMPLOYED:
        var next_rank := rank + 1
        var rank_row := ConfigDB.get_row("career_ranks", "%s_%d" % [line_id, next_rank])
        if not rank_row.is_empty():
            var need_shifts := int(rank_row.get("required_shifts", 999))
            var need_aff := int(rank_row.get("required_affinity", 999))
            var need_cred := str(rank_row.get("required_credential", ""))
            if shifts >= need_shifts and ctx.affinity >= need_aff:
                if need_cred.is_empty() or need_cred in ctx.credentials:
                    return {
                        "transition": State.RANK_UP,
                        "reason": "promote",
                        "hint": str(rank_row.get("promote_hint", "")),
                        "speaker": str(rank_row.get("entry_npc", "")),
                    }
                else:
                    return {
                        "transition": State.EMPLOYED,
                        "reason": "blocked_credential",
                        "hint": "师傅说你手艺够了，但夜校的证还没拿。",
                        "speaker": str(rank_row.get("entry_npc", "")),
                    }
    # 被挖判定
    if state == State.EMPLOYED and ctx.has("poach_offer"):
        return {"transition": State.OFFERED, "reason": "poached", ...}
    return {"transition": state, "reason": "", "hint": "", "speaker": ""}
```

**优势**：`evaluate` 无副作用，输入输出全在 `ctx`，可写 20 个单测覆盖所有分支，主方案的 `hidden_points` 浮点累加无法这样测。

---

## 3. 触发点（场景事件，无面板）

### 3.1 场景交互物（复用 `ui-002` 的 `ClickGestureRouter`）

| 场景 | 交互物 | 手势 | 触发 |
|---|---|---|---|
| `home`（早餐店） | `stove`（灶台） | TAP | `food_trial_start` / 试工动作 |
| `home` | `menu_board`（菜单板） | TAP | `food_hired` / 查看当前岗位暗示 |
| `home` | `back_door`（后门） | HOLD 1.5s | `food_quit`（**长按=辞职，防误触**） |
| `factory` | `workbench`（工作台） | TAP | `factory_trial_start` / 试工动作 |
| `factory` | `foreman_desk`（组长桌） | TAP | `factory_hired` |
| `factory` | `gate`（厂门） | HOLD 1.5s | `factory_quit` |

**关键**：辞职用 **HOLD 1.5s**，不是 TAP。理由：辞职是不可逆操作，长按是"温柔治愈"画风下的自然防误触，且不需要确认弹窗（弹窗=面板，违反约束）。

### 3.2 NPC 暗示（复用 `npc-002` 的 `NoticeManager` 单通道）

晋升/降级/被挖时，**不弹面板**，而是：

```gdscript
NoticeManager.show_message(
    rank_row.promote_hint,      # "黄姐把菜单往你手里一塞，说今天你来。"
    "career",                    # source_kind
    rank_row.entry_npc_name      # speaker
)
```

`source_kind = "career"` 对应 `npc-002` 的 `hint_ceiling` 枚举，优先级高于 `daily`，低于 `system`。

### 3.3 场景事件反馈（非 NPC）

- 晋升后：早餐店墙上**多一块写着你名字的木牌**（场景装饰切换，`AreaBackdrop` 的 `variant` 字段）
- 被挖后：工厂门口**多一张别的厂的招工单**（场景装饰）
- 辞职后：工牌从 HUD 消失（`hud.gd` 订阅 `job_changed` 信号）

---

## 4. 与 StaffManager / CalendarManager 的接口

### 4.1 与 StaffManager（班次结算）

**职责边界**：
- `StaffManager`：管"这一班干了什么、结算多少钱、扣多少体力"
- `CareerManager`：管"我是谁、什么岗位、能不能晋升"

**接口（信号，单向）**：

```gdscript
# staff_manager.gd 新增
signal shift_settled(line_id: String, shifts_done: int, performance: float)

# career_manager.gd 订阅
func _on_shift_settled(line_id: String, shifts_done: int, performance: float) -> void:
    if not is_employed_in(line_id):
        return
    self.shifts_done += shifts_done
    # performance 只用于"低绩效连续 N 次"降级判定，不展示
    if performance < 0.4:
        low_performance_streak += 1
    else:
        low_performance_streak = 0
    _try_evaluate()
```

**关键**：`performance` 是 `StaffManager` 内部计算的浮点，`CareerManager` **只读不写**，且**永不展示给玩家**。

### 4.2 与 CalendarManager（日历）

**接口（信号，单向）**：

```gdscript
# calendar_manager.gd 已有（假设）
signal day_started(day_number: int)
signal minute_changed(total_minutes: int)

# career_manager.gd 订阅
func _on_day_started(day_number: int) -> void:
    # 1. 检查 offer 是否过期
    if _pending_offer.has("expires_day") and day_number > _pending_offer.expires_day:
        _pending_offer.clear()
        NoticeManager.show_message("那张招工单被风吹走了。", "hint", "街坊")
    # 2. 检查被挖条件
    _check_poach_condition(day_number)
    # 3. 检查降级（连续低绩效）
    if low_performance_streak >= 3:
        _demote()
```

**关键**：`CareerManager` **不调用** `CalendarManager` 的任何方法，只订阅信号。反向依赖会形成环。

---

## 5. 存档字段（兼容现有存档）

```gdscript
# 新增到 SaveManager 的 career 段
{
    "career": {
        "state": 0,                    # CareerState 枚举值
        "line_id": "",
        "rank": 0,
        "shifts_done": 0,
        "hidden_points": 0.0,          # 保留主方案字段，兼容
        "low_performance_streak": 0,
        "layoff_count": 0,
        "has_ever_worked": false,      # 新增：区分开局和辞职后
        "pending_offer": {},           # 新增：被挖 offer
        "credentials": [],             # 新增：夜校证书列表
        "version": 2                   # 新增：存档版本
    }
}
```

**迁移**：`version == 1`（主方案）→ `version == 2` 时，`application_stage` 映射到 `state`：
- `0` → `IDLE`
- `1` → `APPLIED`
- `2` → `TRIAL`
- `3` → `TRIAL_DONE`

---

## 6. 迁移步骤（可回退）

| 阶段 | 动作 | 回退方式 |
|---|---|---|
| **S1** | 新建 `data/careers.csv` / `career_ranks.csv` / `career_events.csv`，**不改代码** | 删文件 |
| **S2** | 新建 `scripts/career/career_state.gd` / `career_fsm.gd`，**纯函数，无副作用** | 删文件 |
| **S3** | 为 `career_fsm.gd` 写 20 个单测（`test-001` 的 diff 驱动选择器会命中） | 删测试 |
| **S4** | 重构 `career_manager.gd`：内部状态改为 `CareerState`，`application_stage` 保留为**只读兼容属性** | feature flag `career.fsm.enabled` |
| **S5** | `StaffManager` 新增 `shift_settled` 信号，`CareerManager` 订阅 | flag 关闭时走旧路径 |
| **S6** | 场景交互物接入 `ClickGestureRouter`（依赖 `ui-002`） | 交互物 `visible = false` |
| **S7** | 存档迁移 `version 1 → 2` | 保留 `version 1` 读取分支 |

**Feature flag**：`ProjectSettings.get_setting("career.fsm.enabled", false)`，false 时 `CareerManager` 走主方案的 `application_stage` 整数路径。

---

## 7. 与主方案的差异总结（为什么本方案更优）

1. **可测试性**：`CareerFSM.evaluate` 是纯函数，20 个单测覆盖所有分支；主方案的 `hidden_points` 浮点累加无法单测。
2. **可扩展性**：加第三条线（如"物流线"）只需加 3 行 CSV，不改代码；主方案需改 `career_manager.gd`。
3. **状态可读性**：`CareerState.EMPLOYED` 比 `application_stage == 3` 可读；`OFFERED` 状态是主方案缺失的。
4. **职责清晰**：`StaffManager` 管班次、`CareerManager` 管身份、`CalendarManager` 管时间，三者单向依赖，无环。
5. **约束遵守**：辞职用 HOLD 1.5s 而非弹窗，晋升用 NPC 台词而非进度条，被挖用场景装饰而非面板。

**唯一风险**：`CareerFSM` 的 `evaluate` 需要 `ctx` 包含所有字段，若 `StaffManager` 未及时发 `shift_settled`，晋升会延迟一天。缓解：`_on_day_started` 时补一次 `_try_evaluate()`。

## 批判

## 批判A（qa_lead）

# 批判报告：两份方案的可执行缺陷与返工要求

## 一、致命冲突（必须先裁决，否则无法开工）

### C1. 两份方案对"状态载体"的定义互斥，且都未验证现有代码
- 主方案：`application_stage: int`（1/2/3）+ `current_line` 双字段联合判定状态。
- 独立方案：`CareerState` 枚举 + `TRANSITIONS` 表，`application_stage` 降级为只读兼容属性。
- **两份方案都没有 G0 门禁确认 `career_manager.gd` 现有字段名**。主方案 §2.3 说"保留现有全部字段"，独立方案 §5 说"保留 `hidden_points` 兼容"——**两份都在假设现有字段，但都没列出实际字段清单**。

**返工要求**：
1. 先跑 `grep -n "^var \|^signal \|^func " autoload/career_manager.gd`，把实际字段/信号/方法**逐行贴进 `docs/CAREER_FACTS.md`**。
2. 若现有代码已有 `application_stage`，独立方案的"只读兼容属性"必须给出**双向同步代码**（写 `state` 时同步 `application_stage`，反之亦然），否则旧调用点读到脏值。
3. 若现有代码**没有** `application_stage`，主方案 §3.1 状态表全部作废，需重写。

### C2. 两份方案的"被挖走"语义互斥，且主方案自相矛盾
- 主方案 D4：被挖走 = 在职时对方师傅主动接触，**无需辞职**；§4.6 又说"接受被挖走：`current_line` 切换，`current_rank` 从 1 开始"。
- **矛盾点**：如果无需辞职，那原线的 `hidden_points`、`shifts_done`、`low_performance_streak` 怎么处理？主方案只说"保留 70%"，但没说 `shifts_done` 是否清零。若不清零，新线 rank=1 的 `required_shifts=3` 会被旧线累计值直接满足——**玩家一跳槽就秒晋升**。
- 独立方案 §2.1 有 `OFFERED` 中间态，主方案 §3.1 状态表**没有 OFFERED**，但 §4.6 又要求"下一次进入目标线场景时 TAP 接受/拒绝"——**没有 OFFERED 态，`poach_offer_line` 非空时玩家处于什么状态？** 主方案状态表里 `EMPLOYED` 和 `POACH_PENDING` 并列，但 `POACH_PENDING` 的判定条件是 `poach_offer_line != ""`，而 `EMPLOYED` 的判定是 `current_line != "" and current_rank > 0`——**两个条件可同时为真，状态机非互斥**。

**返工要求**：
1. 明确 `accept_poach()` 时 `shifts_done`、`low_performance_streak`、`hidden_points` 三个字段的**逐字段处置**（清零/保留/按比例）。
2. 主方案状态表改为**互斥优先级表**：`POACH_PENDING` 优先级高于 `EMPLOYED`，或合并为 `EMPLOYED` 的子状态。
3. 补一条断言：`accept_poach()` 后 `shifts_done == 0`（或明确保留值），且新线 rank=1 不会因旧线累计值秒晋升。

### C3. 两份方案的"辞职"交互互斥，且主方案的二次确认有死锁风险
- 主方案 §4.7：HOLD ≥1.5s → 推送"再长按一次" → 3 秒内第二次 HOLD 才执行。
- 独立方案 §3.1：HOLD 1.5s 直接执行，无二次确认。
- **主方案死锁风险**：`WorldInteractable` 的 `on_hold` 若在第一次 HOLD 后**不重置计时器**，第二次 HOLD 会被识别为同一次长按的延续，永远进不了"第二次"。主方案 §4.7 没说明"3 秒内"的计时器由谁维护、存在哪里、存档时是否序列化。

**返工要求**：
1. 明确二次确认的计时器字段名、归属对象、是否入存档。
2. 若 `WorldInteractable` 无 `on_hold` 方法（主方案 §8 风险表自己承认 P1），**两份方案的辞职交互全部作废**，需先确认 `ui-002` 的 `ClickGestureRouter` 是否提供 HOLD 手势。
3. 补一条集成测试：模拟两次 HOLD，断言 `resign()` 只被调用一次。

---

## 二、数据层缺陷

### C4. 主方案 `careers.csv` 的"新增列追加在末尾"假设未验证
主方案 §2.1 说"保留原有列，新增列追加在末尾，避免破坏 `row[5]` 索引式读取"，但 §8 风险表又说"若索引式，新建 `careers_ext.csv` 用 `career_id` join"——**同一份方案里给了两个互斥的缓解措施**。

**返工要求**：
1. G0.1 必须确认 `ConfigDB.get_rows("careers")` 返回的是 `Dictionary` 还是 `Array`。
2. 若是 `Array`（索引式），**主方案 §2.1 的"追加在末尾"直接作废**，必须走 `careers_ext.csv` join 路径，且 §2.1 的所有列名需重新映射。
3. 若是 `Dictionary`，独立方案 §1.1 的 `careers.csv` 与主方案 §2.1 的 `careers.csv` **列名冲突**（主方案用 `career_id`/`line`/`rank`，独立方案用 `line_id`/`line_name`/`entry_npc`），必须二选一。

### C5. 两份方案的 CSV 主键格式不兼容
- 主方案：`career_id = "{line}_{rank}"`，如 `catering_1`。
- 独立方案：`career_ranks.csv` 用 `line_id,rank` 两列联合主键，无 `career_id`。
- **冲突**：若两份方案的数据文件同时存在，`ConfigDB.get_row("career_ranks", "food_1")` 在独立方案下**查不到**（因为独立方案没有 `career_id` 列）。

**返工要求**：
1. 统一主键格式。建议 `career_ranks.csv` 增加 `career_id` 列，值 = `{line_id}_{rank}`，与主方案对齐。
2. 补一条数据校验：`career_id` 全局唯一，且 `line_id` + `rank` 组合唯一。

### C6. 独立方案的 `poach_condition` 表达式字符串无解析器
独立方案 §1.1 定义 `poach_condition = "day>=10 and rank>=2"`，但 §2.3 的 `evaluate` 里只检查 `ctx.has("poach_offer")`——**表达式字符串从未被解析**。这是死代码。

**返工要求**：
1. 要么删除 `poach_condition` 列，改为 `min_day` / `min_rank` 两个数值列（与主方案 §2.2 的 `min_rank`/`min_points` 对齐）。
2. 要么实现 `_eval_condition(expr, ctx)` 解析器，并补单测覆盖 `and`/`or`/比较运算符。
3. 无论选哪个，**必须给出 `poach_condition` 的实际消费点代码**，否则该列是死数据。

### C7. 主方案 `career_events.csv` 的 `effect` 列无消费点
主方案 §2.2 定义 `effect = offer_poach / praise / warn`，但 §4.5 `_try_career_event` 和 §4.6 `try_encounter_event` 都**没有根据 `effect` 分支**——`_fire_career_event` 和 `_fire_poach_offer` 是两个独立方法，`effect` 列从未被读取。

**返工要求**：
1. 要么删除 `effect` 列，用 `trigger_type` 区分（`encounter` → poach，`shift_end` → praise）。
2. 要么在 `_fire_career_event` 内 `match row.effect` 分支，并补测试覆盖三种 effect。

---

## 三、状态机缺陷

### C8. 主方案状态机不可达状态
主方案 §3.1 状态表：
- `APPLIED`：`application_line != "" and application_stage == 1`
- `TRIAL`：`application_stage == 2`
- `TRIAL_DONE`：`application_stage == 3`

**问题**：`application_stage == 0` 时是什么状态？`UNEMPLOYED` 的判定是 `current_line == "" and application_line == ""`——若玩家 `register_interest` 后 `resign`（虽然逻辑上不该发生），`application_line != ""` 但 `application_stage == 0`，**不属于任何状态**。

**返工要求**：
1. 补 `application_stage == 0` 的显式状态（建议 `IDLE`）。
2. 补一条断言：任意字段组合下，状态判定**有且仅有一个**为真。

### C9. 主方案晋升子状态机的 `credential` 阻塞无出口
主方案 §3.2：`credential` 非空且 `GameState.has_flag(credential)` 为假 → 推送 `_blocked_credential` 提示。
**问题**：提示推送后，玩家如何获得 credential？主方案 §2.1 的 `credential` 示例是 `food_safety_card` / `safety_cert` / `business_license` / `management_cert`——**这四个 flag 由谁设置？** 主方案全文未提。

**返工要求**：
1. 明确每个 credential 的获取途径（哪个 NPC、哪个场景、哪个交互物）。
2. 若 credential 系统不存在，**主方案 §2.1 的 `credential` 列全部作废**，晋升阈值需重新设计。
3. 补一条测试：`credential` 未获得时，`work_shift()` 不晋升且推送提示；获得后，下次 `work_shift()` 晋升。

### C10. 独立方案 `TRANSITIONS` 表的 `OFFERED → UNEMPLOYED` 语义不明
独立方案 §2.2：`State.OFFERED: [State.EMPLOYED, State.UNEMPLOYED]`，注释"接受=换线，拒绝=留任"。
**矛盾**：拒绝 offer 应该是留在**原线**（`EMPLOYED`），不是 `UNEMPLOYED`。`OFFERED → UNEMPLOYED` 是死转移。

**返工要求**：
1. 删除 `OFFERED → UNEMPLOYED`，或明确该转移的触发条件（如"offer 过期且玩家已辞职"）。
2. 补一条测试：`decline_poach()` 后 `state == EMPLOYED` 且 `current_line` 不变。

### C11. 独立方案 `evaluate` 的 `ctx.has("poach_offer")` 与 `ctx` 字段清单不符
独立方案 §2.3 注释：`ctx = {state, line_id, rank, shifts_done, affinity, credentials, day, offers}`——**字段名是 `offers`（复数）**，但代码里检查 `ctx.has("poach_offer")`（单数）。**字段名不一致，运行时报错**。

**返工要求**：
1. 统一字段名。
2. 补一条测试：`ctx` 缺字段时 `evaluate` 返回原状态而非崩溃。

---

## 四、接口缺陷

### C12. 主方案与 StaffManager 的"单向联动"是死接口
主方案 §5.1：
- `CareerManager → StaffManager`：`StaffManager.has_staff(store_id)`，用于"玩家晋升到 rank≥3 时，若店铺无雇员，师傅暗示该招个人了"。
- **问题**：这个暗示的触发点在哪？主方案 §4.4 说晋升在 `work_shift()` 末尾自动判定，但 `work_shift()` 内**没有调用 `StaffManager.has_staff`**。这是死接口。

**返工要求**：
1. 要么在 `work_shift()` 晋升分支内显式调用 `StaffManager.has_staff`，并补测试。
2. 要么删除该接口，`staff_hired` flag 由 `huang_2` 故事独立管理。

### C13. 独立方案 `shift_settled` 信号与主方案 `work_shift()` 职责重叠
- 主方案：`work_shift()` 在 `CareerManager` 内，自己算 `hidden_points`、自己判定晋升。
- 独立方案：`StaffManager` 发 `shift_settled(line_id, shifts_done, performance)`，`CareerManager` 订阅。
- **冲突**：若两份方案同时实施，`work_shift()` 和 `shift_settled` 会**双重计数** `shifts_done`。

**返工要求**：
1. 明确 `work_shift()` 是否保留。若保留，它只负责"触发班次"，不负责"结算"；结算全部走 `shift_settled`。
2. 补一条测试：一次上班后 `shifts_done` 只 +1。

### C14. 两份方案都未定义 `CalendarManager` 的班次时段校验失败时的行为
主方案 §4.3 前置检查第 4 条：`CalendarManager.hour` 在班次时段内。**若不在时段内，`work_shift()` 返回什么？** 主方案未说。独立方案 §4.2 只订阅 `day_started`，未提时段。

**返工要求**：
1. 明确 `work_shift()` 在非班次时段的返回值（`false`？推送提示？静默失败？）。
2. 补一条测试：非班次时段调用 `work_shift()`，断言 `shifts_done` 不变且推送提示。

---

## 五、存档风险

### C15. 主方案 `career_state` 子字典的 `resigned_lines: Array[String]` 序列化未验证
主方案 §2.4 存档字段含 `resigned_lines: Array[String]`。**Godot 的 `JSON.stringify` 对 `Array[String]` 的支持需验证**——若 `SaveManager` 用 JSON，`Array[String]` 会退化为 `Array`，读档时类型不匹配。

**返工要求**：
1. 确认 `SaveManager` 的序列化格式（JSON / `ConfigFile` / 二进制）。
2. 若是 JSON，`resigned_lines` 改为 `Array`（无类型），读档时手动转 `Array[String]`。
3. 补一条测试：存档往返后 `resigned_lines` 类型和内容一致。

### C16. 独立方案 `version 1 → 2` 迁移的 `application_stage` 映射不完整
独立方案 §5：`application_stage` 映射到 `state`：`0→IDLE, 1→APPLIED, 2→TRIAL, 3→TRIAL_DONE`。
**问题**：`application_stage == 3` 映射到 `TRIAL_DONE`，但旧档若已 `confirm_application`（`current_line != ""`），`application_stage` 可能仍是 3——**映射后玩家变成"试工完成但未入职"，丢失已入职状态**。

**返工要求**：
1. 迁移逻辑改为：先判 `current_line != ""` → `EMPLOYED`；否则按 `application_stage` 映射。
2. 补一条测试：旧档 `current_line="catering", application_stage=3` → 迁移后 `state == EMPLOYED`。

### C17. 两份方案都未定义"存档中途辞职"的原子性
主方案 §5.4 存档触发点含 `resign` → `"career_resign"`。**若 `resign()` 执行到一半（`current_line` 已清空，`hidden_points` 未按 50% 保留）时崩溃，读档后状态不一致**。

**返工要求**：
1. `resign()` 内先算好所有新值到局部变量，再一次性赋值，最后 `request_auto_save`。
2. 补一条测试：模拟 `resign()` 中途异常，断言存档中 `current_line` 和 `hidden_points` 要么都是旧值，要么都是新值。

---

## 六、测试漏洞

### C18. 主方案 §7.1 单元测试缺"状态互斥"断言
主方案 §7.1 有 12 个用例，但**没有一条断言状态互斥**。§3.1 的 `EMPLOYED` 和 `POACH_PENDING` 可同时为真（见 C2），测试无法发现。

**返工要求**：
1. 补用例：`poach_offer_line != ""` 且 `current_line != ""` 时，`get_state()` 返回唯一值。
2. 补用例：`application_stage` 越界（如 99）时，`get_state()` 返回 `IDLE` 而非崩溃。

### C19. 主方案 §7.2 集成测试"提示通道"断言不可执行
主方案 §7.2："所有 `NoticeManager.show_message` 调用均传 speaker"。
**问题**：如何断言"所有"？GDScript 无反射拦截 `show_message` 调用。**该测试用例不可执行**。

**返工要求**：
1. 改为：`NoticeManager` 增加 `_last_speaker` 字段，测试断言每次调用后 `_last_speaker != ""`。
2. 或改为：`NoticeManager.show_message` 内 `assert(not speaker.is_empty())`，测试触发所有 career 路径，断言无 assert 失败。

### C20. 独立方案 §6 S3"20 个单测"无具体清单
独立方案 §6 S3："为 `career_fsm.gd` 写 20 个单测"。**没有列出 20 个用例是什么**，无法验证覆盖率。

**返工要求**：
1. 列出 20 个用例的 `(state, ctx, expected_transition)` 三元组。
2. 必须覆盖：所有 `TRANSITIONS` 合法转移、所有非法转移返回原状态、`credential` 阻塞、`affinity` 不足、`shifts` 不足、`poach_offer` 存在/不存在、`ctx` 缺字段。

### C21. 两份方案都缺"被辞退"的完整测试
主方案 §7.1 有"被辞退"用例：`low_performance_streak=3 → work_shift() → laid_off 信号`。
**问题**：`low_performance_streak` 的判定是"单次 `work_shift` 增量 < 3.0 时 +1"（§3.2），但测试直接设 `low_performance_streak=3`，**跳过了增量计算逻辑**。增量计算本身无测试。

**返工要求**：
1. 补用例：体力 20%（<30%）→ `work_shift()` → 增量 = 4.0 - 1.0 = 3.0，`low_performance_streak` 不变（因为 3.0 不小于 3.0）。
2. 补用例：体力 20% 且间隔 >3 天 → 增量 = 4.0 - 1.0 - 0.5 = 2.5 < 3.0 → `low_performance_streak +1`。
3. 补用例：连续 3 次低增量 → `laid_off` 信号。

### C22. 独立方案缺"被挖走 offer 过期"测试
独立方案 §4.2 `_on_day_started` 检查 offer 过期，但 §6 迁移步骤和 §7 差异总结**都没有测试用例**。

**返工要求**：
1. 补用例：设 `pending_offer.expires_day = 5`，`day_started(6)` → `pending_offer` 清空且推送提示。
2. 补用例：`day_started(5)` → `pending_offer` 保留。

---

## 七、死代码与不可触达机制

### C23. 主方案 §2.2 `career_events.csv` 的 `cooldown_days` 列在 `praise` 事件上无意义
主方案 §2.2 示例：`praise_factory_1` 的 `cooldown_days=0`。**0 天冷却 = 无冷却**，但 `_is_on_cooldown` 仍会被调用。若 `_set_cooldown(event_id, 0)` 写入 `career_event_cooldowns[event_id] = day + 0 = day`，下次同日触发时 `day > day` 为假，**不会冷却**——逻辑正确但冗余。

**返工要求**：
1. `cooldown_days <= 0` 时跳过 `_set_cooldown` 调用，避免无意义写入存档。
2. 补一条测试：`cooldown_days=0` 的事件可连续触发。

### C24. 主方案 §4.6 的 `decline_poach()` 绑定在"任意场景的师傅 NPC 本体 HOLD"
**问题**：玩家在 `home` 场景收到工厂线 offer（`poach_offer_line="factory"`），但 `home` 场景里**没有王师傅**。玩家如何拒绝？主方案说"任意场景的师傅 NPC 本体 HOLD"——**哪个师傅？** 黄姐 HOLD 是辞职，王师傅不在场。

**返工要求**：
1. 明确 `decline_poach()` 的触发交互物。建议：offer 过期自动拒绝（独立方案 §4.2 的做法），或当前线师傅 TAP 时弹"你最近心不在焉"暗示。
2. 若坚持 HOLD，必须指定**当前线师傅**的 HOLD 在 `poach_offer_line != ""` 时改为 `decline_poach()` 而非 `resign()`——**同一手势双语义，需明确优先级**。

### C25. 独立方案 §3.3"场景装饰切换"无实现路径
独立方案 §3.3："晋升后早餐店墙上多一块写着你名字的木牌（`AreaBackdrop` 的 `variant` 字段）"。
**问题**：`AreaBackdrop` 是否存在于代码库？`variant` 字段是否支持运行时切换？**未验证**。

**返工要求**：
1. G0 门禁增加：`grep -rn "AreaBackdrop\|variant" scripts/ autoload/`。
2. 若不存在，删除 §3.3，改为纯 NPC 台词反馈。

---

## 八、返工优先级

| 优先级 | 缺陷 | 阻塞对象 |
|---|---|---|
| **P0** | C1（现有字段未验证） | 两份方案全部 |
| **P0** | C4（CSV 读取方式未验证） | 数据层 |
| **P0** | C2（被挖走字段处置） | 状态机 + 存档 |
| **P0** | C16（存档迁移丢状态） | 存档 |
| **P1** | C3（辞职二次确认死锁） | 交互层 |
| **P1** | C9（credential 无获取途径） | 晋升系统 |
| **P1** | C13（双重计数） | 接口层 |
| **P1** | C18/C19/C21（测试不可执行） | 验证层 |
| **P2** | C6/C7（死列） | 数据层 |
| **P2** | C10/C11（死转移/字段名） | 独立方案状态机 |
| **P2** | C24/C25（不可触达交互） | 交互层 |

---

## 九、合并建议（若必须二选一）

**主方案更适合当前代码库**，理由：
1. 主方案明确"不新增场景"，独立方案依赖 `AreaBackdrop`（C25 未验证）。
2. 主方案的 `careers.csv` 改造路径与现有 `ConfigDB.get_rows("careers")` 对齐，独立方案新增两个 CSV 但未验证 `ConfigDB` 是否支持多表 join。
3. 主方案的 `hidden_points` 浮点累加虽不可单测，但**独立方案的 `CareerFSM.evaluate` 依赖 `ctx` 完整传递，而 `ctx` 的组装点未定义**（C11）——独立方案的可测试性优势在实现层被抵消。

**但主方案必须吸收独立方案的三点**：
1. `OFFERED` 中间态（解决 C2 状态非互斥）。
2. `has_ever_worked` 标志（区分开局和辞职后，主方案缺失）。
3. `version` 字段（存档迁移，主方案缺失）。

**最终返工要求**：以主方案为基线，合并独立方案的 `OFFERED` 态、`has_ever_worked`、`version` 字段，**先过 G0 门禁（C1/C4/C25），再裁决 C2/C3/C9/C13**，否则禁止进入阶段 1。

## 批判B（gameplay_planner）

# 批判报告：双方案交叉审查

## 一、主方案致命问题

### P0-1 状态机自相矛盾（死代码）
§3.1 状态表定义 `APPLIED` 判定为 `application_line!="" and application_stage==1`，但 §4.2 试工触发直接调 `perform_trial_action`，§3.1 转移图又要求 `APPLIED --start_trial--> TRIAL`。**`start_trial` 方法全文未定义**，§四触发点表里也没有任何交互物调用它。结果：`APPLIED` 状态无法离开，试工入口不存在，整条职业线不可达。

**返工要求**：明确 `perform_trial_action` 是否隐含 `start_trial`。若是，删除转移图中的 `start_trial` 边；若否，在 §4.2 补一个"灶台首次 TAP 触发 start_trial"的交互，并给出 `start_trial()` 签名。

### P0-2 存档字段与状态机不一致
§2.4 存档写入 `application_stage`，但 §3.1 状态表用 `application_stage==1/2/3` 判定，而 §3.1 转移图里 `TRIAL_DONE` 的判定条件**未定义**（只写了 `application_stage==3`，但谁把它从 2 改成 3？`perform_trial_action` 的推进逻辑全文缺失）。

**返工要求**：补 `perform_trial_action` 的完整伪代码，明确 `trial_progress` 与 `application_stage` 的推进关系，以及 `trial_progress >= trial_required` 时 `application_stage` 如何从 2 变 3。

### P0-3 `night_market` 门禁未过就写死依赖
§4.1、§4.6、§八风险表都依赖 `night_market`，但 §阶段0 G0.2 是阻塞门禁。**方案在门禁未执行的情况下，已经把 `night_market` 写进了触发点表和 `career_events.csv` 示例**。若场景不存在，§4.1 第三行、§4.6 的 `poach_catering_1`（`scene_key=street`）全部是死数据。

**返工要求**：`career_events.csv` 的示例行不得引用未确认存在的场景。`poach_catering_1` 的 `scene_key=street` 也需门禁确认 `street` 存在。所有场景 key 必须来自 G0.2 的实测输出。

### P0-4 `careers.csv` 索引式读取风险被降级为 P0 但未阻塞
§八风险表把"索引式读取"标为 P0，但 §阶段1 直接要求"改造 `data/careers.csv` 补列"。**P0 风险未缓解就进入执行阶段**，违反自己定的"阶段0未过禁止进入阶段1"。

**返工要求**：阶段1 拆为 1a（门禁确认读取方式）和 1b（改造）。若为索引式，必须走 `careers_ext.csv` join 方案，不得改原表。

### P1-1 `low_performance_streak` 判定逻辑与表现修正冲突
§3.2 表现修正表：基础 +4.0，体力<30% 时 -1.0，间隔>3天 -0.5。最差情况 +2.5。§3.2 又说"单次增量 < 3.0 时 streak+1"。**体力<30% 且间隔>3天时增量为 2.5，会触发 streak**，但这是玩家"累了"而非"表现差"，语义错误。

**返工要求**：`low_performance_streak` 的判定应基于 `performance` 而非 `hidden_points` 增量，或明确"体力低导致的低增量不计入 streak"。

### P1-2 被挖走后 `hidden_points` 保留 70%，但 `current_rank` 从 1 开始
§4.6 接受被挖走：`current_rank` 从 1 开始，`hidden_points` 保留 70%。但晋升阈值是按 rank 查表的（`promote_threshold[rank]`）。**rank=1 时阈值 12.0，若保留 70% 后 hidden_points=35，玩家一次 work_shift 就跳级**。

**返工要求**：明确 `hidden_points` 是"当前 rank 内累积"还是"跨 rank 累积"。若是前者，被挖走后应清零；若是后者，晋升判定应改为 `hidden_points >= 累计阈值`。

### P1-3 `resign()` 二次确认的 3 秒窗口无状态字段
§4.7 要求"3 秒内第二次 HOLD 才执行"，但 §2.3 新增字段里**没有 `resign_pending_until` 之类的字段**。3 秒窗口如何跨帧保持？存档时若在窗口内退出，重进后窗口是否有效？

**返工要求**：新增 `resign_pending_until_msec: int` 字段，明确存档行为（建议不存档，重进后窗口失效）。

### P1-4 `try_encounter_event` 的 `line` 过滤逻辑错误
§4.6 代码：`if str(row.get("line", "")) == current_line: continue  # 不挖自己线`。但 `career_events.csv` 示例中 `poach_factory_1` 的 `line=factory`，`poach_catering_1` 的 `line=catering`。**`line` 字段语义是"目标线"还是"发起线"？** 若 `poach_factory_1` 是"工厂线挖人"，则 `line=factory` 表示目标线，过滤逻辑应为 `if row.line == current_line: continue`（不挖自己线）——但这样 `poach_factory_1` 在玩家是工厂线时被跳过，正确；玩家是餐饮线时触发，正确。**但 §4.6 的 `_fire_poach_offer` 设置 `poach_offer_line` 时用的是 `row.line`，即目标线**。逻辑自洽，但字段命名 `line` 歧义。

**返工要求**：`career_events.csv` 的 `line` 列改名为 `target_line`，避免与 `current_line` 混淆。

### P1-5 `praise` 事件无冷却，会刷屏
§2.2 示例 `praise_factory_1` 的 `cooldown_days=0`，§4.5 `_try_career_event` 每次 `work_shift` 后都调用。**玩家连续上班会每次触发 praise，台词重复**。

**返工要求**：`praise` 类事件必须有冷却，或改为"每个 rank 只触发一次"（用 flag 记录）。

### P2-1 `weekday` 工资 ×1.2 标为 P2 但未定义
§5.2 写"周末班次工资 ×1.2（可选，P2）"，但 §2.1 `careers.csv` 无 `weekend_multiplier` 列，§3.2 表现修正表也无此项。**P2 功能无数据支撑**。

**返工要求**：删除或补全数据列与计算逻辑。

### P2-2 `resigned_lines` 字段无使用点
§2.3 新增 `resigned_lines: Array[String]`，注释"用于台词差异"，但全文**无任何代码读取该字段**。死字段。

**返工要求**：补使用点（如 `resign()` 时若 `line in resigned_lines`，台词不同），或删除。

---

## 二、独立方案致命问题

### P0-1 `CareerFSM.evaluate` 的 `ctx` 字段未定义完整
§2.3 注释写 `ctx: {state, line_id, rank, shifts_done, affinity, credentials, day, offers}`，但代码里用了 `ctx.has("poach_offer")`（单数），注释里是 `offers`（复数）。**字段名不一致，调用方无法构造 ctx**。

**返工要求**：给出 `ctx` 的完整 schema（字段名、类型、来源），并明确 `poach_offer` 与 `offers` 的关系。

### P0-2 `career_ranks.csv` 的 `entry_npc` 列不存在
§2.3 代码：`"speaker": str(rank_row.get("entry_npc", ""))`。但 §1.2 `career_ranks.csv` 的列是 `line_id,rank,title,description,promote_hint,demote_hint,shift_wage,energy_cost,required_shifts,required_credential,required_affinity`。**无 `entry_npc` 列**。`speaker` 永远为空字符串，违反 `npc-002` D13（必须传 speaker）。

**返工要求**：`career_ranks.csv` 补 `entry_npc` 列，或从 `careers.csv` join 获取。

### P0-3 `career_events.csv` 的 `state_from`/`state_to` 与 FSM 转移表冲突
§1.3 示例 `food_trial_start` 的 `state_from=APPLIED, state_to=TRIAL`，但 §2.2 转移表 `APPLIED: [TRIAL, IDLE]` 允许。**但 `food_hired` 的 `state_from=TRIAL_DONE, state_to=EMPLOYED`，转移表 `TRIAL_DONE: [EMPLOYED, IDLE]` 允许**。问题在 `food_promote_2`：`state_from=EMPLOYED, state_to=RANK_UP`，转移表允许。**但 `RANK_UP` 是过渡态，§2.1 说"同帧转 EMPLOYED"，那么 `state_to=RANK_UP` 的事件如何触发 `RANK_UP -> EMPLOYED` 的转移？** 无代码。

**返工要求**：明确 `RANK_UP` 过渡态的进入与退出机制。建议删除 `RANK_UP`，晋升直接 `EMPLOYED -> EMPLOYED`（rank+1），用信号 `rank_changed` 通知。

### P0-4 `trigger_type=shift_count` 的 `trigger_value` 语义歧义
§1.3 `food_trial_done` 的 `trigger_type=shift_count, trigger_value=3`。但 §1.2 `career_ranks.csv` 的 `required_shifts=3` 也是 3。**两个 3 是同一个计数还是不同计数？** 若是同一个，`career_events.csv` 的 `shift_count` 触发与 `career_ranks.csv` 的 `required_shifts` 重复；若是不同，需明确各自计数来源。

**返工要求**：统一为 `career_ranks.csv` 的 `required_shifts` 驱动，删除 `career_events.csv` 的 `shift_count` 类型，或明确两者关系。

### P1-1 `StaffManager.shift_settled` 信号是新增，但未定义 `performance` 计算
§4.1 新增 `signal shift_settled(line_id, shifts_done, performance)`，但 `performance` 如何计算**全文未定义**。§4.1 只说"`StaffManager` 内部计算的浮点"。

**返工要求**：给出 `performance` 的计算公式（体力、时长、随机因子等），否则 `low_performance_streak` 判定无依据。

### P1-2 `_check_poach_condition` 未定义
§4.2 `_on_day_started` 调用 `_check_poach_condition(day_number)`，但该方法**全文未定义**。§1.1 `careers.csv` 的 `poach_condition` 是表达式字符串（`day>=10 and rank>=2`），**表达式解析器未定义**。

**返工要求**：给出 `poach_condition` 的解析方案（GDScript `Expression` 类？自定义解析？），或改为结构化字段（`min_day`, `min_rank`）。

### P1-3 `_demote()` 未定义
§4.2 `_on_day_started` 调用 `_demote()`，但该方法**全文未定义**。§1.2 `career_ranks.csv` 有 `demote_hint` 列，但降级逻辑（rank-1？清零？）未定义。

**返工要求**：给出 `_demote()` 完整逻辑，明确降级后 `shifts_done` 是否清零、`rank` 是否可降到 0。

### P1-4 存档 `version` 迁移只覆盖 `application_stage`，遗漏其他字段
§5 迁移规则只映射 `application_stage -> state`，但主方案的 `hidden_points`、`trial_progress`、`trial_required`、`poach_offer_line`、`poach_offer_expire_day`、`last_shift_day`、`career_event_cooldowns`、`resigned_lines` **全部未映射**。旧档读入后这些字段丢失。

**返工要求**：补全所有字段的迁移规则，或明确"旧档这些字段丢弃，按默认值补全"。

### P1-5 Feature flag `career.fsm.enabled` 无定义位置
§6 提到 `ProjectSettings.get_setting("career.fsm.enabled", false)`，但**未说明在 `project.godot` 中注册**，也未说明 flag 关闭时 `CareerManager` 如何走旧路径（旧路径代码是否保留？）。

**返工要求**：明确 flag 注册位置，以及 flag 关闭时的代码分支。

### P2-1 `AreaBackdrop.variant` 字段未确认存在
§3.3 "晋升后早餐店墙上多一块写着你名字的木牌（`AreaBackdrop` 的 `variant` 字段）"。**`AreaBackdrop` 和 `variant` 字段未在门禁中确认**。

**返工要求**：加入门禁检查，或改为其他已确认的场景装饰机制。

### P2-2 `hud.gd` 订阅 `job_changed` 信号，但信号未定义
§3.3 "工牌从 HUD 消失（`hud.gd` 订阅 `job_changed` 信号）"。**`job_changed` 信号全文未定义**。

**返工要求**：在 `CareerManager` 中定义 `signal job_changed(line_id, rank)`，或在 §4.1 接口中补充。

---

## 三、两方案共同遗漏

### C-1 无"被辞退"的完整路径
主方案 §4.8 有 `laid_off`，独立方案 §4.2 有 `_demote()` 但无 `laid_off`。**两方案都未定义"被辞退后能否再应聘同一条线"**。若不能，玩家永久失去一条线；若能，`layoff_count` 的作用是什么？

**返工要求**：明确被辞退后的再应聘规则，以及 `layoff_count` 的具体影响（如"被辞退 2 次后该线不再录用"）。

### C-2 无"试工失败"路径
两方案的试工都是"完成 N 次动作即通过"。**若玩家试工期间体力耗尽、或长时间不完成，是否有失败/超时机制？**

**返工要求**：明确试工是否有失败条件，若无，说明理由（温柔治愈画风）。

### C-3 无"多线并行"规则
两方案都假设玩家同时只在一个线。**若玩家在餐饮线在职，能否同时应聘工厂线？** 主方案 §4.6 被挖走是"在职时被接触"，但主动应聘另一条线呢？

**返工要求**：明确"在职时能否应聘其他线"，以及 `application_line` 与 `current_line` 的关系。

### C-4 无"工资到账"的具体实现
两方案都提到 `wage`，但**工资如何进入玩家资产？** 主方案 §4.3 `work_shift()` 只说"工资到账"，独立方案 §4.1 `shift_settled` 信号也未定义工资结算。

**返工要求**：明确工资结算接口（`EconomyManager.add_money(wage)`？`GameState.money += wage`？），以及是否受 `weekday` 影响。

### C-5 无"NPC 亲和度"来源
独立方案 §1.2 `required_affinity` 依赖 `entry_npc` 的亲和度，但**亲和度如何增长？** 主方案完全未涉及亲和度。

**返工要求**：明确亲和度来源（对话？送礼？共事次数？），以及是否复用现有 `npc_stories` 的 affinity。

### C-6 无"凭证获取"路径
两方案都要求 `food_safety_card` / `safety_cert` 等凭证，但**凭证如何获取？** 主方案 §3.2 只说"检查 `GameState.has_flag(credential)`"，独立方案 §1.2 说"复用 `teacher_yu` 的 `food_cert`"。

**返工要求**：明确凭证获取路径（夜校？考试？），以及 `teacher_yu` 是否已实现该功能。

### C-7 无"场景交互物与现有场景的挂载方式"
两方案都列出交互物（招聘木牌、灶台、工位），但**这些交互物如何挂载到现有场景？** 是新建 `.tscn` 还是运行时 `add_child`？场景文件是否已存在？

**返工要求**：明确交互物的挂载方式，以及是否需要修改现有场景文件。

### C-8 无"提示通道冲突"处理
主方案 §5.3 走 `NoticeManager.show_message`，独立方案 §3.2 也走 `NoticeManager`。但**两方案都未处理与 `npc-002` 的 `NoticeArbiter` 的冲突**。若 `NoticeArbiter` 已实现，`NoticeManager` 是否被废弃？

**返工要求**：明确 `NoticeManager` 与 `NoticeArbiter` 的关系，以及本方案应调用哪个。

---

## 四、返工优先级

| 优先级 | 问题 | 返工要求 |
|---|---|---|
| **P0** | 主 P0-1 状态机死代码 | 补 `start_trial` 或删除转移边 |
| **P0** | 主 P0-2 试工推进逻辑缺失 | 补 `perform_trial_action` 伪代码 |
| **P0** | 主 P0-3 未确认场景写死依赖 | 所有场景 key 来自 G0.2 实测 |
| **P0** | 主 P0-4 P0 风险未阻塞 | 阶段1 拆 1a/1b |
| **P0** | 独 P0-1 ctx schema 不一致 | 给出完整 schema |
| **P0** | 独 P0-2 entry_npc 列缺失 | 补列或 join |
| **P0** | 独 P0-3 RANK_UP 过渡态无退出 | 删除 RANK_UP 或补退出机制 |
| **P0** | 独 P0-4 shift_count 语义歧义 | 统一或明确关系 |
| **P1** | 主 P1-1 streak 语义错误 | 基于 performance 判定 |
| **P1** | 主 P1-2 被挖后跳级 | 明确 hidden_points 累积范围 |
| **P1** | 主 P1-3 辞职窗口无字段 | 补 `resign_pending_until_msec` |
| **P1** | 主 P1-4 line 字段歧义 | 改名 `target_line` |
| **P1** | 主 P1-5 praise 刷屏 | 补冷却或一次性 flag |
| **P1** | 独 P1-1 performance 未定义 | 给出计算公式 |
| **P1** | 独 P1-2 poach_condition 未定义 | 给出解析方案 |
| **P1** | 独 P1-3 _demote 未定义 | 给出完整逻辑 |
| **P1** | 独 P1-4 迁移遗漏字段 | 补全迁移规则 |
| **P1** | 独 P1-5 feature flag 未定义 | 明确注册位置 |
| **P2** | 主 P2-1 weekday 无数据 | 删除或补全 |
| **P2** | 主 P2-2 resigned_lines 死字段 | 补使用点或删除 |
| **P2** | 独 P2-1 AreaBackdrop 未确认 | 门禁检查 |
| **P2** | 独 P2-2 job_changed 未定义 | 补信号定义 |
| **共同** | C-1 至 C-8 | 逐条明确 |

---

## 五、结论

**主方案**：骨架完整但**状态机有死代码（P0-1/P0-2），门禁未过就写死依赖（P0-3），P0 风险未阻塞（P0-4）**。不可直接执行。

**独立方案**：设计理念更优（纯函数 FSM、数据驱动），但**接口定义不完整（P0-1/P0-2），状态机有未定义过渡（P0-3），触发语义歧义（P0-4）**。同样不可直接执行。

**两方案共同遗漏**：被辞退再应聘、试工失败、多线并行、工资结算、亲和度来源、凭证获取、交互物挂载、提示通道冲突。**这些是执行前必须补齐的**。

**建议**：以独立方案的 FSM 架构为骨架，吸收主方案的 `career_events.csv` 事件表设计，**先补齐上述 P0 问题，再进入阶段0门禁**。

## 综合决策

# 餐饮线/工厂线双职业晋升与跳槽 —— 最终可执行方案

> **裁决原则**：以**独立方案的 FSM 架构**为骨架（纯函数可测、数据驱动、状态互斥），吸收**主方案的 `career_events.csv` 事件表**与"不新增场景"约束，**逐条消解批判 A/B 的全部 P0/P1**。所有未验证项降级为**门禁阻塞项**，门禁未过禁止进入编码阶段。

---

## 一、决策（逐条裁决，无歧义）

### 1.1 架构裁决

| # | 争议点 | 最终裁决 | 依据 |
|---|---|---|---|
| A1 | 状态载体 | **`CareerState` 枚举 + `TRANSITIONS` 转移表**（独立方案）。`application_stage` 若存在则保留为**只读派生属性**，由 `state` 单向计算，不反向同步 | 批判A C1：整数魔法值不可断言；批判B 主P0-1：`start_trial` 死代码 |
| A2 | 晋升判定 | **`CareerFSM.evaluate(ctx) -> Dictionary` 纯函数**，无副作用，可单测 | 批判A C20：需 20 个可枚举用例 |
| A3 | 数据源 | **`data/careers.csv`（线定义）+ `data/career_ranks.csv`（阶梯）+ `data/career_events.csv`（事件）** 三表。主键统一为 `career_id = "{line_id}_{rank}"` | 批判A C5：主键格式冲突 |
| A4 | 被挖走语义 | **新增 `OFFERED` 中间态**（独立方案）。接受 = 换线且 `shifts_done=0`、`hidden_points=0`、`low_performance_streak=0`；拒绝 = 留原线 | 批判A C2：状态非互斥 + 秒晋升；批判B 主P1-2 |
| A5 | 辞职交互 | **HOLD 1.5s 直接执行，无二次确认**（独立方案）。理由：二次确认的 3 秒窗口无字段承载（批判B 主P1-3），且弹窗违反"无面板"约束 | 批判A C3：死锁风险 |
| A6 | 被辞退 | `low_performance_streak >= 3` → `laid_off`，给遣散费 `wage * 2`。**被辞退后该线 7 天内不可再应聘**（`layoff_count` 不叠加惩罚） | 批判B C-1 |
| A7 | 试工失败 | **无失败条件**。温柔治愈画风，试工只进不退 | 批判B C-2 |
| A8 | 多线并行 | **在职时不可主动应聘其他线**（`register_interest` 在 `is_employed()` 时返回 false 并推送师傅暗示）。**仅被挖走可换线** | 批判B C-3 |
| A9 | 工资结算 | `work_shift()` 内调用 `EconomyManager.add_money(wage)`（若不存在则 `GameState.money += wage`）。**无周末倍率**（删除主方案 P2-1 死数据） | 批判B C-4、主P2-1 |
| A10 | 亲和度来源 | **复用现有 `npc_stories` 的 affinity**，通过 `GameState.get_affinity(npc_id)` 读取。不新增系统 | 批判B C-5 |
| A11 | 凭证获取 | **复用 `teacher_yu` 夜校**。凭证 flag：`food_cert` / `factory_cert`。若 `teacher_yu` 未实现，**凭证列全部置空**，晋升不阻塞 | 批判A C9、批判B C-6 |
| A12 | 提示通道 | 统一走 `NoticeManager.show_message(msg, kind, speaker)`，`speaker` 必填。若 `NoticeArbiter` 已存在，**本方案调用 `NoticeArbiter.post()`**，门禁确认 | 批判B C-8 |
| A13 | 交互物挂载 | **运行时 `add_child` 到场景根节点**，不修改现有 `.tscn`。交互物继承 `WorldInteractable`，通过 `SceneRouter` 在 `scene_loaded` 时注入 | 批判B C-7 |
| A14 | 存档 | **`version: 2`**，`career_state` 子字典。旧档 `version 1` 迁移：先判 `current_line != ""` → `EMPLOYED`，否则按 `application_stage` 映射 | 批判A C16、批判B 独P1-4 |
| A15 | 开局 | `reset_new_game()` 后 `state = IDLE`，`has_ever_worked = false`。**删除任何自动入职调用** | 任务硬约束 |

### 1.2 状态互斥优先级（解决批判A C2/C8）

`get_state()` 按**优先级从高到低**返回唯一状态：

```
1. OFFERED        : poach_offer_line != "" and poach_offer_expire_day >= day
2. UNEMPLOYED     : current_line == "" and has_ever_worked == true
3. EMPLOYED       : current_line != "" and current_rank > 0
4. TRIAL_DONE     : application_line != "" and trial_progress >= trial_required
5. TRIAL          : application_line != "" and trial_progress > 0
6. APPLIED        : application_line != "" and trial_progress == 0
7. IDLE           : 以上皆否
```

**断言**：任意字段组合下，`get_state()` 返回唯一值。补测试覆盖。

---

## 二、数据字段（唯一事实源）

### 2.1 `data/careers.csv`（线定义，改造现有表）

**门禁 G0.1 确认读取方式后决定**：
- 若 `ConfigDB.get_rows("careers")` 返回 `Dictionary` → 直接补列
- 若返回 `Array`（索引式）→ **不改原表**，新建 `data/careers_ext.csv`，用 `career_id` join

| 列名 | 类型 | 说明 | 示例 |
|---|---|---|---|
| `line_id` | string | 线 ID | `food` / `factory` |
| `line_name` | string | 线名 | `餐饮线` / `工厂线` |
| `entry_npc` | string | 招聘 NPC | `huang` / `wang` |
| `entry_area` | string | 招聘场景 | `home` / `factory` |
| `trial_action_text` | string | 试工动作文案 | `把一笼包子端到窗口` |
| `quit_line` | string | 辞职台词 | `黄姐说灶台不等人，想走就趁早。` |
| `poach_min_day` | int | 被挖最小天数 | `10` |
| `poach_min_rank` | int | 被挖最小职级 | `2` |

**删除**：`poach_condition` 表达式字符串（批判A C6 死代码），改为 `poach_min_day` / `poach_min_rank` 两个数值列。

### 2.2 `data/career_ranks.csv`（岗位阶梯，新建）

| 列名 | 类型 | 说明 |
|---|---|---|
| `career_id` | string | 主键 = `{line_id}_{rank}` |
| `line_id` | string | 线 ID |
| `rank` | int | 职级，从 1 开始 |
| `title` | string | 职级名 |
| `description` | string | 一句话描述 |
| `promote_hint` | string | 晋升台词 |
| `demote_hint` | string | 降级台词 |
| `shift_wage` | int | 每班工资 |
| `energy_cost` | float | 每班体力消耗 |
| `required_shifts` | int | 晋升所需累计班次 |
| `required_credential` | string | 所需凭证 flag（空=无） |
| `required_affinity` | int | 所需亲和度 |
| `entry_npc` | string | 师傅 NPC（**批判B 独P0-2 补列**） |

**餐饮线（food）三档**：

| rank | title | shift_wage | required_shifts | required_credential | required_affinity |
|---|---|---|---|---|---|
| 1 | 帮厨 | 45 | 3 | — | 2 |
| 2 | 掌勺 | 70 | 8 | — | 6 |
| 3 | 店长 | 95 | 20 | `food_cert` | 12 |

**工厂线（factory）三档**：

| rank | title | shift_wage | required_shifts | required_credential | required_affinity |
|---|---|---|---|---|---|
| 1 | 临时工 | 50 | 3 | — | 2 |
| 2 | 正式工 | 75 | 8 | — | 6 |
| 3 | 带班 | 100 | 20 | `factory_cert` | 12 |

**删除**：主方案的 `hidden_points` 浮点累加（批判A C20 不可单测），改为 `shifts_done` 整数计数。

### 2.3 `data/career_events.csv`（场景事件，新建）

| 列名 | 类型 | 说明 |
|---|---|---|
| `event_id` | string | 主键 |
| `target_line` | string | 目标线（**批判B 主P1-4 改名**） |
| `trigger_type` | string | `interact` / `shift_count` / `day` |
| `trigger_value` | string | 交互物 key / 班次数 / 天数 |
| `state_from` | string | 源状态 |
| `state_to` | string | 目标状态 |
| `notice_text` | string | 台词 |
| `speaker` | string | 说话 NPC |
| `cooldown_days` | int | 冷却天数（0=无冷却，**批判A C23**） |
| `once_per_rank` | bool | 是否每 rank 只触发一次（**批判B 主P1-5**） |

**示例行**（场景 key 全部来自 G0.2 实测）：

```csv
event_id,target_line,trigger_type,trigger_value,state_from,state_to,notice_text,speaker,cooldown_days,once_per_rank
food_trial_start,food,interact,stove,APPLIED,TRIAL,黄姐把你带到灶台边，说先看三笼。,huang,0,false
food_trial_done,food,shift_count,3,TRIAL,TRIAL_DONE,黄姐尝了一口，没说话，把围裙递给你。,huang,0,true
food_hired,food,interact,menu_board,TRIAL_DONE,EMPLOYED,黄姐在墙上写了你的名字，说从明天开始算工。,huang,0,true
food_praise_1,food,shift_count,5,EMPLOYED,EMPLOYED,黄姐说今天火候稳了。,huang,3,false
food_quit,food,interact,back_door,EMPLOYED,UNEMPLOYED,黄姐说灶台不等人，想走就趁早。,huang,0,false
factory_trial_start,factory,interact,workbench,APPLIED,TRIAL,王师傅把你领到料箱前，说先码三箱。,wang,0,false
factory_trial_done,factory,shift_count,3,TRIAL,TRIAL_DONE,王师傅翻了翻料箱，说手还行。,wang,0,true
factory_hired,factory,interact,foreman_desk,TRIAL_DONE,EMPLOYED,王师傅把工牌翻到背面，说先学会停手。,wang,0,true
factory_praise_1,factory,shift_count,5,EMPLOYED,EMPLOYED,王师傅说这几件活干得干净。,wang,3,false
factory_quit,factory,interact,gate,EMPLOYED,UNEMPLOYED,王师傅把工牌收回去，说手要稳，心也要稳。,wang,0,false
```

**删除**：`effect` 列（批判A C7 死列），由 `state_from`/`state_to` 区分。

### 2.4 `autoload/career_manager.gd` 字段（门禁 G0.1 后确认现有字段，以下为新增）

```gdscript
# 新增
var state: int = CareerState.IDLE
var line_id := ""
var rank := 0
var shifts_done := 0
var low_performance_streak := 0
var layoff_count := 0
var has_ever_worked := false
var credentials: Array = []              # 无类型，JSON 兼容（批判A C15）
var pending_offer: Dictionary = {}       # {target_line, expires_day, npc_id}
var last_shift_day := -1
var event_cooldowns: Dictionary = {}     # event_id -> 冷却结束日
var event_fired_once: Dictionary = {}    # event_id -> true（once_per_rank）
var layoff_until_day: Dictionary = {}    # line_id -> 可再应聘日
var resign_pending_until_msec := 0       # 批判B 主P1-3，不入存档
```

**删除**：`hidden_points`（改为 `shifts_done`）、`application_stage`（改为 `state`）、`resigned_lines`（批判B 主P2-2 死字段）。

### 2.5 存档字段（`version: 2`）

```gdscript
"career_state": {
    "version": 2,
    "state": state,
    "line_id": line_id,
    "rank": rank,
    "shifts_done": shifts_done,
    "low_performance_streak": low_performance_streak,
    "layoff_count": layoff_count,
    "has_ever_worked": has_ever_worked,
    "credentials": credentials,          # Array，读档时手动转
    "pending_offer": pending_offer,
    "last_shift_day": last_shift_day,
    "event_cooldowns": event_cooldowns,
    "event_fired_once": event_fired_once,
    "layoff_until_day": layoff_until_day,
}
```

**迁移规则（批判A C16）**：
1. 若 `career_state.version == 2` → 直接读
2. 若 `version == 1` 或缺失：
   - `current_line != ""` → `state = EMPLOYED`, `line_id = current_line`, `rank = current_rank`
   - 否则按 `application_stage` 映射：`0→IDLE, 1→APPLIED, 2→TRIAL, 3→TRIAL_DONE`
   - 其余字段按默认值补全
3. **不报错**，缺失字段一律默认值

---

## 三、状态机

### 3.1 状态枚举

```gdscript
# scripts/career/career_state.gd
class_name CareerState
enum {
    IDLE,          # 开局：无工作、无申请
    APPLIED,       # 已在招聘板登记
    TRIAL,         # 试工中
    TRIAL_DONE,    # 试工完成，待确认入职
    EMPLOYED,      # 正式在职（rank >= 1）
    OFFERED,       # 被挖走，收到 offer（未接受）
    UNEMPLOYED,    # 辞职/被裁后
}
```

**删除**：`RANK_UP` 过渡态（批判B 独P0-3）。晋升直接 `EMPLOYED → EMPLOYED`（rank+1），用 `rank_changed` 信号通知。

### 3.2 转移表（纯数据）

```gdscript
const TRANSITIONS := {
    CareerState.IDLE:       [CareerState.APPLIED],
    CareerState.APPLIED:    [CareerState.TRIAL, CareerState.IDLE],
    CareerState.TRIAL:      [CareerState.TRIAL_DONE, CareerState.APPLIED],
    CareerState.TRIAL_DONE: [CareerState.EMPLOYED, CareerState.IDLE],
    CareerState.EMPLOYED:   [CareerState.EMPLOYED, CareerState.OFFERED, CareerState.UNEMPLOYED],
    CareerState.OFFERED:    [CareerState.EMPLOYED],   # 接受=换线后 EMPLOYED，拒绝=留原线 EMPLOYED
    CareerState.UNEMPLOYED: [CareerState.APPLIED],
}
```

**删除**：`OFFERED → UNEMPLOYED`（批判A C10 死转移）。

### 3.3 纯函数评估器

```gdscript
# scripts/career/career_fsm.gd
static func evaluate(ctx: Dictionary) -> Dictionary:
    ## ctx schema（批判B 独P0-1 统一字段名）：
    ## {
    ##   state: int, line_id: String, rank: int, shifts_done: int,
    ##   affinity: int, credentials: Array, day: int,
    ##   pending_offer: Dictionary,   # 单数，与字段名一致
    ##   low_performance_streak: int,
    ## }
    ## 返回：{transition: int, reason: String, hint: String, speaker: String}
    var state: int = ctx.get("state", CareerState.IDLE)
    var line_id: String = ctx.get("line_id", "")
    var rank: int = ctx.get("rank", 0)
    var shifts: int = ctx.get("shifts_done", 0)
    var affinity: int = ctx.get("affinity", 0)
    var credentials: Array = ctx.get("credentials", [])
    var day: int = ctx.get("day", 0)
    var offer: Dictionary = ctx.get("pending_offer", {})

    # 1. offer 过期检查
    if not offer.is_empty() and day > int(offer.get("expires_day", -1)):
        return {"transition": state, "reason": "offer_expired",
                "hint": "那张招工单被风吹走了。", "speaker": "街坊"}

    # 2. 被挖判定（优先级最高）
    if state == CareerState.EMPLOYED and not offer.is_empty():
        return {"transition": CareerState.OFFERED, "reason": "poached",
                "hint": str(offer.get("notice_text", "")),
                "speaker": str(offer.get("npc_id", ""))}

    # 3. 晋升判定
    if state == CareerState.EMPLOYED:
        var next_rank := rank + 1
        var rank_row := ConfigDB.get_row("career_ranks", "%s_%d" % [line_id, next_rank])
        if not rank_row.is_empty():
            var need_shifts := int(rank_row.get("required_shifts", 999))
            var need_aff := int(rank_row.get("required_affinity", 999))
            var need_cred := str(rank_row.get("required_credential", ""))
            if shifts >= need_shifts and affinity >= need_aff:
                if need_cred.is_empty() or need_cred in credentials:
                    return {"transition": CareerState.EMPLOYED, "reason": "promote",
                            "hint": str(rank_row.get("promote_hint", "")),
                            "speaker": str(rank_row.get("entry_npc", ""))}
                else:
                    return {"transition": CareerState.EMPLOYED, "reason": "blocked_credential",
                            "hint": "师傅说你手艺够了，但夜校的证还没拿。",
                            "speaker": str(rank_row.get("entry_npc", ""))}

    # 4. 降级判定
    if state == CareerState.EMPLOYED and int(ctx.get("low_performance_streak", 0)) >= 3:
        return {"transition": CareerState.EMPLOYED, "reason": "demote",
                "hint": "师傅让你先回去歇几天。",
                "speaker": str(ctx.get("entry_npc", ""))}

    return {"transition": state, "reason": "", "hint": "", "speaker": ""}
```

**关键**：`ctx` 缺字段时用 `get()` 默认值，**不崩溃**（批判A C11）。

### 3.4 晋升子流程

```
[EMPLOYED rank=N]
    │
    ├─ work_shift() → StaffManager.settle_shift() → 发 shift_settled 信号
    │   └─ CareerManager._on_shift_settled() → shifts_done += 1
    │
    ├─ _try_evaluate() → CareerFSM.evaluate(ctx)
    │   ├─ reason == "promote" → rank += 1，推送 promote_hint
    │   ├─ reason == "blocked_credential" → 推送提示，不晋升
    │   └─ reason == "demote" → rank -= 1（最低 1），推送 demote_hint
    │
    └─ _try_career_event("shift_count") → 触发 praise 等事件
```

**`performance` 计算（批判B 独P1-1）**：

```gdscript
# StaffManager 内
func _calc_performance(energy_ratio: float, shift_minutes: int) -> float:
    var base := 0.7
    if energy_ratio > 0.7: base += 0.2
    elif energy_ratio < 0.3: base -= 0.3
    if shift_minutes >= 180: base += 0.1
    return clamp(base, 0.0, 1.0)
```

`low_performance_streak` 判定：`performance < 0.4` 时 +1，否则归零。**与 `hidden_points` 增量无关**（批判B 主P1-1）。

---

## 四、触发点（场景交互，无面板）

### 4.1 交互物挂载（批判B C-7）

**运行时注入**，不修改现有 `.tscn`：

```gdscript
# SceneRouter 内
func _on_scene_loaded(scene_key: String) -> void:
    var root := get_tree().current_scene
    for row in ConfigDB.get_rows("career_events"):
        if row.trigger_type != "interact": continue
        if row.scene_key != scene_key: continue
        var node := WorldInteractable.new()
        node.interact_key = row.trigger_value
        node.event_id = row.event_id
        root.add_child(node)
    CareerManager.try_encounter_event(scene_key)
```

### 4.2 交互物清单（场景 key 来自 G0.2 实测）

| 场景 | 交互物 key | 手势 | 触发 |
|---|---|---|---|
| `home` | `stove` | TAP | `food_trial_start` / 试工动作 |
| `home` | `menu_board` | TAP | `food_hired` |
| `home` | `back_door` | HOLD 1.5s | `food_quit` |
| `factory` | `workbench` | TAP | `factory_trial_start` |
| `factory` | `foreman_desk` | TAP | `factory_hired` |
| `factory` | `gate` | HOLD 1.5s | `factory_quit` |

**若 `night_market` 存在**（G0.2 确认）：新增 `song_stall` 交互物，触发 `food_trial_start`（老宋线）。

### 4.3 被挖走触发

`SceneRouter._on_scene_loaded()` 调用 `CareerManager.try_encounter_event(scene_key)`：

```gdscript
func try_encounter_event(scene_key: String) -> void:
    if state != CareerState.EMPLOYED: return
    for row in ConfigDB.get_rows("careers"):
        if row.entry_area != scene_key: continue
        if row.line_id == line_id: continue          # 不挖自己线
        if CalendarManager.day < int(row.poach_min_day): continue
        if rank < int(row.poach_min_rank): continue
        if _is_layoff_blocked(row.line_id): continue
        _fire_poach_offer(row)
```

**`_fire_poach_offer`**：设置 `pending_offer = {target_line, expires_day: day+7, npc_id, notice_text}`，推送台词，**不弹菜单**。

### 4.4 接受/拒绝被挖走

| 场景 | 交互物 | 手势 | 调用 |
|---|---|---|---|
| 目标线场景 | 师傅 NPC 本体 | TAP | `accept_poach()` |
| 当前线场景 | 当前线师傅 NPC | HOLD 1.5s | `decline_poach()`（**批判A C24**：当前线师傅 HOLD 在 `pending_offer` 非空时语义改为拒绝） |

**`accept_poach()` 字段处置（批判A C2）**：

```gdscript
func accept_poach() -> void:
    var new_line := pending_offer.target_line
    # 原子性：先算局部变量，再一次性赋值（批判A C17）
    var new_state := CareerState.EMPLOYED
    var new_line_id := new_line
    var new_rank := 1
    var new_shifts := 0                    # 清零，防秒晋升
    var new_streak := 0
    var new_offer := {}
    # 一次性赋值
    state = new_state
    line_id = new_line_id
    rank = new_rank
    shifts_done = new_shifts
    low_performance_streak = new_streak
    pending_offer = new_offer
    has_ever_worked = true
    NoticeManager.show_message("师傅拍了拍你的肩，说欢迎。", "positive", _master_name(new_line))
    request_auto_save("career_poach")
```

### 4.5 辞职触发

| 场景 | 交互物 | 手势 | 调用 |
|---|---|---|---|
| 当前线场景 | 当前线师傅 NPC | HOLD 1.5s | `resign()` |

**无二次确认**（裁决 A5）。`resign()` 原子性：

```gdscript
func resign() -> void:
    var new_state := CareerState.UNEMPLOYED
    var new_line := ""
    var new_rank := 0
    var new_shifts := 0
    state = new_state
    line_id = new_line
    rank = new_rank
    shifts_done = new_shifts
    has_ever_worked = true
    NoticeManager.show_message(_quit_line(line_id), "hint", _master_name(line_id))
    request_auto_save("career_resign")
```

### 4.6 被辞退触发

`_on_shift_settled` 内若 `low_performance_streak >= 3`：

```gdscript
func _laid_off() -> void:
    var severance := _current_wage() * 2
    EconomyManager.add_money(severance)
    layoff_until_day[line_id] = CalendarManager.day + 7
    layoff_count += 1
    state = CareerState.UNEMPLOYED
    line_id = ""
    rank = 0
    shifts_done = 0
    NoticeManager.show_message("师傅把工牌收回去，说手要稳，心也要稳。", "warning", _master_name(line_id))
    request_auto_save("career_laid_off")
```

---

## 五、与 StaffManager / CalendarManager 的接口

### 5.1 与 StaffManager（批判A C13 双重计数）

**职责边界**：
- `StaffManager`：管班次结算（工资、体力、`performance`）
- `CareerManager`：管身份状态（`state`、`rank`、`shifts_done`）

**接口（信号，单向）**：

```gdscript
# staff_manager.gd 新增
signal shift_settled(line_id: String, performance: float)

# career_manager.gd 订阅
func _on_shift_settled(settled_line: String, performance: float) -> void:
    if settled_line != line_id: return
    shifts_done += 1                          # 唯一计数点
    if performance < 0.4:
        low_performance_streak += 1
    else:
        low_performance_streak = 0
    if low_performance_streak >= 3:
        _laid_off()
        return
    _try_evaluate()
    _try_career_event("shift_count")
```

**`work_shift()` 保留但降级为"触发班次"**，不负责结算：

```gdscript
func work_shift() -> bool:
    if state != CareerState.EMPLOYED: return false
    if last_shift_day == CalendarManager.day: return false
    if not _in_shift_hours(): 
        NoticeManager.show_message("现在不是上班的点。", "hint", _master_name(line_id))
        return false
    if GameState.energy < _current_energy_cost():
        NoticeManager.show_message("今天实在没力气了。", "hint", _master_name(line_id))
        return false
    last_shift_day = CalendarManager.day
    StaffManager.settle_shift(line_id, _current_shift_minutes())  # 发 shift_settled
    return true
```

**删除**：主方案 §5.1 的 `StaffManager.has_staff(store_id)` 死接口（批判A C12）。

### 5.2 与 CalendarManager（单向只读）

```gdscript
# career_manager.gd 订阅
func _on_day_started(day_number: int) -> void:
    # 1. offer 过期
    if not pending_offer.is_empty() and day_number > int(pending_offer.get("expires_day", -1)):
        pending_offer = {}
        NoticeManager.show_message("那张招工单被风吹走了。", "hint", "街坊")
    # 2. 补一次 evaluate（防 shift_settled 延迟）
    _try_evaluate()
```

**不反向调用** `CalendarManager` 任何方法。

### 5.3 与 NoticeManager / NoticeArbiter（批判B C-8）

**门禁 G0.6 确认**：
- 若 `NoticeArbiter` 存在 → 调用 `NoticeArbiter.post(msg, kind, speaker, priority)`
- 否则 → 调用 `NoticeManager.show_message(msg, kind, speaker)`

**统一封装**：

```gdscript
func _notify(msg: String, kind: String, speaker: String) -> void:
    assert(not speaker.is_empty(), "speaker 不得为空")
    if Engine.has_singleton("NoticeArbiter"):
        NoticeArbiter.post(msg, kind, speaker, "career")
    else:
        NoticeManager.show_message(msg, kind, speaker)
```

### 5.4 与 SaveManager

**reason 白名单**（需在 `KEY_NODE_REASONS` 注册）：

| reason | 触发点 |
|---|---|
| `career_interest` | `register_interest` |
| `career_trial_start` | `start_trial` |
| `career_trial_action` | `perform_trial_action` |
| `career_hired` | `confirm_application` |
| `career_shift` | `_on_shift_settled` |
| `career_promoted` | `_try_evaluate` promote 分支 |
| `career_resign` | `resign` |
| `career_poach` | `accept_poach` |
| `career_laid_off` | `_laid_off` |

---

## 六、执行步骤

### 阶段 0：门禁（阻塞，未过禁止进入阶段 1）

```bash
# G0.1 career_manager.gd 现有字段/信号/方法
grep -n "^var \|^signal \|^func " autoload/career_manager.gd

# G0.2 careers.csv 读取方式
grep -rn "careers" --include=*.gd scripts/ autoload/
grep -rn "func get_rows\|func get_row" autoload/config_db.gd

# G0.3 场景存在性
grep -rn "night_market\|street" data/scene_zones.csv data/scene_metadata.csv

# G0.4 SaveManager.KEY_NODE_REASONS
grep -n "KEY_NODE_REASONS" -A 30 autoload/save_manager.gd

# G0.5 CalendarManager 字段
grep -n "var day\|var hour\|var weekday\|signal day_started" autoload/calendar_manager.gd

# G0.6 NoticeArbiter 存在性
grep -rn "NoticeArbiter\|NoticeManager" autoload/ scripts/

# G0.7 WorldInteractable 手势方法
grep -n "func on_tap\|func on_hold\|func on_drag" scripts/world_interactable.gd

# G0.8 AreaBackdrop / variant 存在性（批判A C25）
grep -rn "AreaBackdrop\|variant" scripts/ autoload/

# G0.9 teacher_yu 凭证功能（批判B C-6）
grep -rn "teacher_yu\|food_cert\|factory_cert" scripts/ autoload/ data/

# G0.10 EconomyManager 存在性（批判B C-4）
grep -rn "EconomyManager\|GameState.money" autoload/ scripts/
```

**结果写入 `docs/CAREER_FACTS.md`**，作为唯一事实源。**任何未确认项，对应功能降级或删除**。

### 阶段 1：数据层

1. **1a**：按 G0.2 结果决定 `careers.csv` 改造路径（直接补列 / `careers_ext.csv` join）
2. **1b**：新建 `data/career_ranks.csv`（6 行：food 3 + factory 3）
3. **1c**：新建 `data/career_events.csv`（10 行，场景 key 来自 G0.3）
4. **1d**：新建 `tools/validate_careers.py`，校验：
   - `career_id` 全局唯一
   - `line_id + rank` 组合唯一
   - `required_credential` 若非空，必须在 `credentials` 白名单内
   - `trigger_value` 若为 `interact`，场景 key 必须在 G0.3 实测列表内

### 阶段 2：CareerFSM + CareerManager

1. 新建 `scripts/career/career_state.gd`（枚举）
2. 新建 `scripts/career/career_fsm.gd`（`TRANSITIONS` + `evaluate`）
3. 重构 `autoload/career_manager.gd`：
   - 按 §2.4 新增字段
   - 实现 `register_interest` / `start_trial` / `perform_trial_action` / `confirm_application`
   - 实现 `work_shift` / `resign` / `accept_poach` / `decline_poach`
   - 实现 `try_encounter_event` / `_try_career_event` / `_try_evaluate`
   - 实现 `_on_shift_settled` / `_on_day_started`
   - 实现 `get_state()`（按 §1.2 优先级）
   - **删除**任何自动入职调用

###
