# 传统/世界节日与特殊商品事件

## 主方案

# 最终可执行方案：节日系统扩展（传统/世界节日 × 限时场景 × 特殊商品 × 比赛聚会 × 经营流水线 × NPC 生日）

> 综合裁决：以现有 `festival_manager.gd` / `calendar_manager.gd` 的**既有接口为唯一事实源**，不推翻、不重写。所有新增能力通过 **CSV 扩列 + 新表 + 新场景实体** 落地，代码只做"读表 + 分发"。
> 硬约束对齐：无任务面板、无数值属性条、场景点击经营、NPC/系统/场景提示分离、固定物价、存档兼容、温柔治愈画风。
> **本方案不发明新 NPC**（沿用 npc-001 已定 8 位 + 现有 17 位），不发明新场景 key（沿用 world-001 已定 key）。

---

## 0. 前置门禁（阻塞性，未通过不得改代码）

结果写入 `docs/FESTIVAL_FACTS.md`，作为后续所有字段/接口的唯一事实源。

### G0.1 现有 festival 表结构
```bash
ls data/ | grep -i festival
head -3 data/festival_events.csv
```
**裁决**：若 `festival_events.csv` 存在 → 本方案**扩列**（新增列，不动旧列）。若不存在 → 本方案**新建**，字段以 §2.1 为准。

### G0.2 ConfigDB 读取方式
```bash
grep -n "func get_row\|func get_rows\|DictReader\|row\[" scripts/config_db.gd autoload/config_db.gd 2>/dev/null
```
**裁决**：若按列名取值 → 可安全扩列。若按索引取值 → **禁止扩列**，改为新建 `festival_events_ext.csv`，用 `event_id` join。

### G0.3 场景 key 仲裁（复用 art-003 D1 结论）
```bash
grep -rn "scene_id\|scene_key" data/scene_metadata.csv scripts/scene_router.gd 2>/dev/null | head -20
```
**裁决**：节日 `scene_id` 只能取**已存在**的 key。已知可用：`street` / `commercial_district` / `riverside` / `night_market` / `store` / `home` / `school`。**不得发明** `festival_plaza` 之类新 key；若需节日专属场地，用 `street` + `decoration` 字段区分。

### G0.4 经营流水线接口
```bash
grep -n "func \|signal " autoload/business_manager.gd autoload/kitchen_manager.gd 2>/dev/null | head -40
```
**裁决**：记录现有下单/出餐/结算方法名，节日商品必须走**同一方法**，不得新开结算路径。

### G0.5 NPC 生日字段现状
```bash
grep -n "birthday\|birth_day" data/npcs.csv
```
**裁决**：若已有 `birthday` 列（npc-001 已定 8 位：175/95/310/140/120/55/200/260）→ 直接复用。若无 → 本方案**只定义列名**，取值由 npc-001 补，本方案不推断。

### G0.6 存档字段现状
```bash
grep -n "festival\|claimed\|activities_done" autoload/save_manager.gd
```
**裁决**：确认 `FestivalManager.claimed` / `activities_done` / `notified` 是否已序列化。若未序列化 → §5 补迁移。

---

## 1. 决策（逐条裁决）

| # | 争议点 | 裁决 | 理由 |
|---|---|---|---|
| D1 | 节日数据放哪 | **扩 `calendar.csv` 只加展示字段；事件逻辑全部进 `festival_events.csv`** | calendar 是"日历展示"，festival_events 是"事件逻辑"，职责分离 |
| D2 | 一天多事件 | **`festival_events.csv` 主键 = `day_key`，一天一事件** | 现有 `get_event_for_day` 按 day_key 查单行，改多行要改接口，风险大 |
| D3 | 粉色/白色情人节定位 | **粉色情人节(177)=表达心意；白色情人节(274)=回应心意**，两者通过 `paired_event_id` 互指 | 形成"送出→回应"闭环，与 NPC 生日联动 |
| D4 | 限时场景实现 | **不新建场景**，用 `scene_id` + `decoration` + `spawn_props` 在既有场景注入节日实体 | 对齐 world-001"场景 key 唯一事实源" |
| D5 | 特殊商品 | **进 `goods.csv` 加 `festival_only` 列**，非节日日不出现在货架 | 复用现有商品管线，固定物价 |
| D6 | 比赛/聚会 | **每节日至少 2 类**：`activity_type` 支持 `competition` / `gathering` / `market` / `ritual`，一行一主活动 + `sub_activities` 列存副活动 | 满足"至少两类事件" |
| D7 | 与经营流水线关联 | **节日商品走 `KitchenManager` 正常下单**，节日只改 `business_bonus` 和货架可见性 | 不新开结算路径 |
| D8 | 与 NPC 生日关联 | **生日当天若与节日同日 → 触发 `birthday_festival_combo`**；否则生日独立走 `birthday` 事件 | 复用 npc-001 生日字段 |
| D9 | 奖励发放 | **复用 `claim_gift` / `join_today_activity`**，只扩 `reward_*` 字段 | 现有接口已闭环 |
| D10 | 失败回落 | **每个活动必须有 `fallback_line` + `fallback_reward`**，条件不满足时降级为"旁观" | 温柔治愈，不惩罚玩家 |
| D11 | 提示通道 | **NPC 台词走 `show_npc_message`，场景描述走 `show_scene_message`，系统提示走 `show_system_message`** | 对齐 npc-002 D3 |
| D12 | 存档兼容 | **新增字段全部有默认值**，旧档读入时 `claimed`/`activities_done` 为空字典即可 | 对齐 save-001 |

---

## 2. CSV 字段定义（唯一事实源）

### 2.1 `data/festival_events.csv`（新建或扩列）

| 列名 | 类型 | 必填 | 说明 | 示例 |
|---|---|---|---|---|
| `day_key` | int | 是 | 一年中的第几天（1–360），主键 | `177` |
| `event_id` | string | 是 | 事件唯一 id | `pink_valentine` |
| `title` | string | 是 | 节日名 | `粉色情人节` |
| `type` | string | 是 | `traditional` / `world` / `commercial` | `world` |
| `scene_id` | string | 是 | 限时场景 key（必须已存在） | `commercial_district` |
| `decoration` | string | 是 | 场景装饰 id（美术资源 key） | `pink_balloon` |
| `spawn_props` | string | 否 | 场景注入实体，分号分隔 `prop_id:count` | `balloon_stand:2;flower_cart:1` |
| `npc_id` | string | 是 | 主 NPC（必须已存在） | `lan` |
| `speaker` | string | 是 | 提示显示名 | `花摊的阿兰` |
| `line` | string | 是 | 节日当天 NPC 自然讲述 | `今天街上都是粉色的，你要不要也买一朵？` |
| `reward_item_id` | string | 否 | 纪念品 id（进 `goods.csv`） | `pink_ribbon` |
| `activity_type` | string | 是 | `competition` / `gathering` / `market` / `ritual` | `gathering` |
| `activity_title` | string | 是 | 活动名 | `粉色气球交换会` |
| `activity_line` | string | 是 | 活动成功台词 | `你把气球递给对方，对方笑了。` |
| `activity_reward_money` | int | 否 | 活动奖励金 | `60` |
| `activity_reward_energy` | int | 否 | 活动奖励体力 | `8` |
| `sub_activities` | string | 否 | 副活动，分号分隔 `type:title` | `competition:最快包花束;market:限时花摊` |
| `fallback_line` | string | 是 | 条件不满足时的回落台词 | `你站在旁边看了一会儿，风把气球吹得很高。` |
| `fallback_reward` | string | 否 | 回落奖励，`item:xxx` 或 `money:10` | `money:10` |
| `paired_event_id` | string | 否 | 配对节日（粉/白情人节互指） | `white_valentine` |
| `birthday_npc_id` | string | 否 | 若与 NPC 生日同日，填该 NPC | `li_ma` |
| `business_bonus` | float | 是 | 经营加成（覆盖 calendar 值） | `0.16` |
| `collection_bonus` | float | 是 | 收藏加成 | `0.08` |
| `weather_hint` | string | 是 | 天气提示 | `clear` |
| `min_level` | int | 否 | 触发最低店铺等级，默认 1 | `1` |
| `required_flag` | string | 否 | 前置 flag，空则无 | `` |

### 2.2 `data/goods.csv` 扩列

| 新增列 | 类型 | 说明 |
|---|---|---|
| `festival_only` | string | 空=常驻；填 `event_id` 则仅该节日可见 |
| `festival_price_note` | string | 固定物价说明，如"节日限定，价格不变" |

**新增节日商品（固定物价，不随节日浮动）**：

| goods_id | name | base_cost | unit | category | festival_only |
|---|---|---|---|---|---|
| `pink_ribbon` | 粉色丝带 | 6 | 条 | 纪念品 | `pink_valentine` |
| `white_chocolate` | 白巧克力 | 8 | 块 | 纪念品 | `white_valentine` |
| `zongzi` | 粽子 | 5 | 个 | 节日食品 | `dragon_boat` |
| `mooncake` | 月饼 | 7 | 个 | 节日食品 | `mid_autumn` |
| `tangyuan` | 汤圆 | 4 | 碗 | 节日食品 | `lantern` |
| `christmas_bell` | 圣诞铃铛 | 9 | 个 | 纪念品 | `christmas` |
| `spring_couplet` | 春联 | 3 | 副 | 节日装饰 | `spring_festival` |
| `qixi_thread` | 七夕彩线 | 6 | 束 | 纪念品 | `qixi` |

### 2.3 `data/npcs.csv` 扩列（若 G0.5 未确认）

| 新增列 | 类型 | 说明 |
|---|---|---|
| `birthday` | int | 一年中第几天，1–360 |
| `birthday_line` | string | 生日当天台词 |
| `birthday_gift_id` | string | 生日礼物 id |

---

## 3. 节日清单（19 个，含新增 2 个）

| day_key | event_id | 节日 | type | scene_id | npc_id | activity_type | 配对 |
|---|---|---|---|---|---|---|---|
| 1 | `new_year` | 元旦 | traditional | `street` | `fangjie` | gathering | — |
| 15 | `lantern` | 元宵节 | traditional | `street` | `mei` | ritual | — |
| 34 | `qingming` | 清明节 | traditional | `riverside` | `chen` | ritual | — |
| 45 | `valentine` | 情人节 | world | `commercial_district` | `lan` | market | — |
| 75 | `labor_day` | 劳动节 | world | `street` | `zhoujie` | gathering | — |
| 95 | `dragon_boat` | 端午节 | traditional | `riverside` | `song` | competition | — |
| 150 | `children_day` | 儿童节 | world | `store` | `li_ma` | gathering | — |
| 165 | `summer_solstice` | 夏至 | traditional | `riverside` | `qu` | market | — |
| **177** | **`pink_valentine`** | **粉色情人节** | **world** | **`commercial_district`** | **`lan`** | **gathering** | **`white_valentine`** |
| 210 | `qixi` | 七夕 | traditional | `riverside` | `lan` | ritual | — |
| 225 | `mid_autumn` | 中秋节 | traditional | `street` | `mei` | gathering | — |
| 240 | `national_day` | 国庆节 | world | `commercial_district` | `zhoujie` | market | — |
| 250 | `teachers_day` | 教师节 | world | `school` | `cai` | gathering | — |
| 270 | `double_ninth` | 重阳节 | traditional | `street` | `chen` | ritual | — |
| **274** | **`white_valentine`** | **白色情人节** | **world** | **`commercial_district`** | **`lan`** | **market** | **`pink_valentine`** |
| 300 | `double_eleven` | 双十一 | commercial | `commercial_district` | `lin` | market | — |
| 326 | `thanksgiving` | 感恩节 | world | `street` | `mei` | gathering | — |
| 330 | `winter_solstice` | 冬至 | traditional | `street` | `song` | gathering | — |
| 354 | `christmas` | 圣诞节 | world | `commercial_district` | `lan` | market | — |
| 360 | `new_year_eve` | 跨年夜 | world | `commercial_district` | `fangjie` | gathering | — |

> **春节说明**：现有 calendar 无春节（因 360 天固定历，春节按农历浮动无法映射）。**裁决**：用 `new_year`（元旦）承载春节语义，`title` 改为"春节·元旦"，`decoration` 用 `spring_couplet`，`reward_item_id` 用 `spring_couplet`。若后续要独立春节，需先解决农历映射，**本方案不做**。

---

## 4. 触发条件与奖励（逐节日）

### 4.1 粉色情人节（day 177）

**触发条件**：
- `CalendarManager.get_day_of_year() == 177`
- `GameState.business_level >= 1`（默认满足）
- 无 `required_flag`

**限时场景**：`commercial_district` 注入 `balloon_stand:2;flower_cart:1`，装饰 `pink_balloon`。

**特殊商品**：`pink_ribbon`（6 元，固定价），仅当日货架可见。

**两类事件**：
1. **主活动 `gathering`**：粉色气球交换会。玩家点击 `balloon_stand` → `join_today_activity()` → 奖励 60 元 + 8 体力 + `lan` 好感 +2。
2. **副活动 `competition`**：最快包花束。点击 `flower_cart` → 进入 30 秒小游戏（点击节奏），按 `GameState.energy` 结算名次，奖励 `maxi(0, score) * 2` 元。

**与经营流水线关联**：当日 `business_bonus = 0.16`，早餐店/便利店订单量 +16%；`pink_ribbon` 可作食材做成"粉色丝带蛋糕"（需 `KitchenManager` 已有配方接口，若无则只作纪念品）。

**与 NPC 生日关联**：若 `lan` 生日为 177（npc-001 未定，待确认）→ 触发 `birthday_festival_combo`，额外奖励 `pink_ribbon` ×2。

**失败回落**：若玩家体力 < 5 或未点击任何实体 → 当日结束显示 `fallback_line`："你站在旁边看了一会儿，风把气球吹得很高。" 奖励 `money:10`。

### 4.2 白色情人节（day 274）

**触发条件**：
- `CalendarManager.get_day_of_year() == 274`
- **前置**：`FestivalManager.claimed` 中含 `pink_valentine` 的 `day_key`（即今年粉色情人节领过纪念品）→ 触发"回应"分支
- 若无前置 → 触发"补过"分支（`fallback_line`）

**限时场景**：`commercial_district` 注入 `flower_cart:1;candy_stand:1`，装饰 `white_ribbon`。

**特殊商品**：`white_chocolate`（8 元，固定价）。

**两类事件**：
1. **主活动 `market`**：白色回礼市集。点击 `candy_stand` → `join_today_activity()` → 奖励 80 元 + `white_chocolate` ×1。
2. **副活动 `ritual`**：写一张回礼卡片。点击 `flower_cart` → 选择一位 NPC（从 `RelationshipManager.affinity` 取好感最高者）→ 好感 +3，NPC 回赠一句台词。

**与经营流水线关联**：`business_bonus = 0.16`，糖水铺/咖啡店订单 +16%。

**与 NPC 生日关联**：同 4.1 逻辑。

**失败回落**：无前置 → `fallback_line`："十月里也有人补过白色情人节，花店把旧心意重新包好。" 奖励 `money:10`。

### 4.3 元宵节（day 15）

- **场景**：`street` + `lantern_row` 装饰
- **商品**：`tangyuan`（4 元）
- **事件 1 `ritual`**：猜灯谜。点击灯笼 → 3 选 1 谜题 → 答对奖励 40 元 + `tangyuan` ×1
- **事件 2 `gathering`**：街坊一起吃汤圆。点击 `mei` → 好感 +2，体力 +6
- **经营关联**：`business_bonus = 0.10`，早餐店汤圆订单 +10%
- **失败回落**：答错 → `fallback_line`："灯谜没猜出来，但灯笼很好看。" 奖励 `money:5`

### 4.4 端午节（day 95）

- **场景**：`riverside` + `reed_leaf` 装饰
- **商品**：`zongzi`（5 元）
- **事件 1 `competition`**：包粽子比赛。点击 `song` → 30 秒点击节奏 → 按 `energy` 结算名次
- **事件 2 `gathering`**：江边分粽子。点击 `qu` → 好感 +2，体力 +8
- **经营关联**：`business_bonus = 0.12`，早餐店粽子订单 +12%
- **失败回落**：`fallback_line`："粽子没包好，但艾草的味道很好闻。" 奖励 `money:8`

### 4.5 中秋节（day 225）

- **场景**：`street` + `moon_lantern` 装饰
- **商品**：`mooncake`（7 元）
- **事件 1 `gathering`**：街坊赏月。点击 `mei` → 好感 +2，体力 +6
- **事件 2 `market`**：月饼交换市集。点击 `lin` → 用 `mooncake` 换任意 1 件常驻商品
- **经营关联**：`business_bonus = 0.16`，便利店月饼订单 +16%
- **失败回落**：`fallback_line`："月亮很圆，你分到了一小块月饼。" 奖励 `mooncake` ×1

### 4.6 七夕（day 210）

- **场景**：`riverside` + `star_streamer` 装饰
- **商品**：`qixi_thread`（6 元）
- **事件 1 `ritual`**：穿针乞巧。点击 `lan` → 小游戏 → 奖励 50 元 + `qixi_thread` ×1
- **事件 2 `gathering`**：河边放灯。点击 `qu` → 好感 +2，体力 +6
- **经营关联**：`business_bonus = 0.13`
- **失败回落**：`fallback_line`："针没穿过去，但河灯很好看。" 奖励 `money:8`

### 4.7 圣诞节（day 354）

- **场景**：`commercial_district` + `warm_light` 装饰
- **商品**：`christmas_bell`（9 元）
- **事件 1 `market`**：圣诞市集。点击 `lan` → 购买任意商品获赠 `christmas_bell` ×1
- **事件 2 `gathering`**：咖啡店门口交换礼物。点击 `lin` → 好感 +2，体力 +8
- **经营关联**：`business_bonus = 0.18`，咖啡店/便利店订单 +18%
- **失败回落**：`fallback_line`："铃铛响了一声，你站在暖光里。" 奖励 `money:10`

### 4.8 春节（day 1，承载元旦）

- **场景**：`street` + `spring_couplet` 装饰
- **商品**：`spring_couplet`（3 元）
- **事件 1 `gathering`**：街坊拜年。点击 `fangjie` → 好感 +3，体力 +10
- **事件 2 `market`**：年货市集。点击 `zhoujie` → 用 `spring_couplet` 换 1 件常驻商品
- **经营关联**：`business_bonus = 0.08`
- **失败回落**：`fallback_line`："春联贴歪了，但街坊都说好看。" 奖励 `spring_couplet` ×1

---

## 5. 存档兼容与迁移

### 5.1 新增存档字段

`FestivalManager` 现有 `claimed` / `activities_done` / `notified` 均为 `Dictionary`，**无需改结构**。新增：

```gdscript
var birthday_combo_done: Dictionary = {}  # day_key -> true
var sub_activities_done: Dictionary = {}  # day_key -> {sub_id: true}
```

### 5.2 迁移策略

- 旧档读入时，`birthday_combo_done` / `sub_activities_done` 为空字典 → 默认未完成，**不报错**。
- `festival_events.csv` 新增列全部有默认值，旧档按 `day_key` 查不到新列时用 `row.get("col", default)`。
- `goods.csv` 新增 `festival_only` 列，旧档货架过滤时若列为空 → 视为常驻，**不隐藏**。

### 5.3 验证命令

```bash
# 读旧档 → 触发节日 → 检查 claimed 是否正常
godot --headless --script tools/test_festival_migration.gd
```

---

## 6. 执行步骤（按顺序）

| # | 步骤 | 文件 | 验证 |
|---|---|---|---|
| 1 | 跑 G0 门禁，写 `docs/FESTIVAL_FACTS.md` | — | 6 条命令全部有输出 |
| 2 | 新建/扩列 `data/festival_events.csv` | `data/festival_events.csv` | `head -3` 列名正确 |
| 3 | 扩列 `data/goods.csv` 加 `festival_only` | `data/goods.csv` | 新增 8 行节日商品 |
| 4 | 扩列 `data/npcs.csv` 加 `birthday`（若 G0.5 未确认） | `data/npcs.csv` | 8 位 NPC 生日非空 |
| 5 | 扩 `FestivalManager` 读新字段 | `autoload/festival_manager.gd` | 新增 `get_sub_activities()` / `join_sub_activity()` |
| 6 | 扩 `CalendarManager` 读 `festival_events` 覆盖 `calendar` | `autoload/calendar_manager.gd` | `get_business_bonus` 优先取 festival_events |
| 7 | 场景注入实体（`spawn_props`） | `scripts/scene_router.gd` 或场景 loader | 节日当天场景出现 `balloon_stand` |
| 8 | 货架过滤 `festival_only` | `scripts/shop_shelf.gd`（或现有货架脚本） | 非节日日不显示 `pink_ribbon` |
| 9 | 生日 combo 逻辑 | `autoload/festival_manager.gd` | 生日+节日同日触发额外奖励 |
| 10 | 存档迁移 | `autoload/save_manager.gd` | 旧档读入不报错 |
| 11 | 测试 | `tools/test_festival.gd` | 19 节日逐日模拟 |

---

## 7. 验证清单

### 7.1 单元验证

```gdscript
# tools/test_festival.gd
func test_all_festivals() -> void:
    for day in [1, 15, 34, 45, 75, 95, 150, 165, 177, 210, 225, 240, 250, 270, 274, 300, 326, 330, 354, 360]:
        TimeSystem.current_day = day
        var row := FestivalManager.get_event_for_day(day)
        assert(not row.is_empty(), "day %d 无事件" % day)
        assert(row.has("scene_id"), "day %d 缺 scene_id" % day)
        assert(row.has("fallback_line"), "day %d 缺 fallback_line" % day)
```

### 7.2 集成验证

- 节日当天进入 `scene_id` → 场景出现 `spawn_props` 实体
- 点击实体 → `join_today_activity()` 返回非空
- 货架仅显示 `festival_only` 匹配的商品
- `business_bonus` 生效（订单量对比非节日日 +16%）
- 存档 → 退出 → 重进 → `claimed` / `activities_done` 保留

### 7.3 边界验证

- 无前置的白色情人节 → 走 `fallback_line`
- 体力不足参加比赛 → 走 `fallback_line`
- 同一天重复点击 → `activities_done` 拦截，返回"今天已经参加过了"
- 旧档读入 → 不报错，节日正常触发

---

## 8. 风险与回落

| 风险 | 概率 | 影响 | 回落 |
|---|---|---|---|
| `festival_events.csv` 不存在，需新建 | 中 | 中 | G0.1 已裁决，新建即可 |
| ConfigDB 按索引取值，不能扩列 | 低 | 高 | G0.2 裁决，改新建 `festival_events_ext.csv` |
| 场景 key 不存在 | 中 | 高 | G0.3 裁决，只用已存在 key |
| 经营流水线接口不匹配 | 中 | 高 | G0.4 裁决，节日商品走现有方法 |
| NPC 生日字段缺失 | 中 | 中 | G0.5 裁决，本方案只定义列名 |
| 存档未序列化 festival 字段 | 中 | 高 | G0.6 裁决，§5 补迁移 |
| 春节农历映射 | 高 | 中 | 本方案用元旦承载，不做农历 |
| 一天多事件冲突 | 低 | 中 | D2 裁决，一天一事件，副活动用 `sub_activities` |

---

## 9. 不做清单（明确排除）

- ❌ 不新建场景 key（`festival_plaza` 等）
- ❌ 不新建 NPC（沿用现有 25 位）
- ❌ 不做农历映射（春节用元旦承载）
- ❌ 不做节日专属结算路径（走现有 `KitchenManager`）
- ❌ 不做节日限时数值浮动（固定物价）
- ❌ 不做任务面板/进度条（提示走 `NoticeManager`）
- ❌ 不做节日专属存档文件（复用现有 `SaveManager`）

---

## 10. 交付物

1. `data/festival_events.csv`（19 行 × 24 列）
2. `data/goods.csv` 扩列 + 8 行节日商品
3. `data/npcs.csv` 扩列（若 G0.5 未确认）
4. `autoload/festival_manager.gd` 扩方法
5. `autoload/calendar_manager.gd` 扩读取
6. `autoload/save_manager.gd` 补迁移
7. `tools/test_festival.gd` 测试
8. `docs/FESTIVAL_FACTS.md` 门禁结果

**验收标准**：19 个节日逐日模拟通过；粉色/白色情人节配对闭环；每个节日至少 2 类事件；失败回落全部有 `fallback_line`；旧档读入不报错。

## 独立方案

# 独立方案：节日系统扩展（世界节日 × 特殊商品 × 经营流水线 × NPC 生日）

> 独立方案 Agent 输出。**不迎合主方案**。核心分歧：主方案倾向"每个节日一套独立事件表 + 独立场景"，本方案主张 **"节日 = 日历行 + 商品标签 + 场景装饰层 + 活动模板"四张正交表**，节日不新增场景，只**复用现有场景 + 叠加装饰层**；活动不写死流程，只**选模板 + 填参数**。
>
> 硬约束对齐：无任务面板（节日靠 NPC 自然讲述 + 场景装饰）、无数值属性条（奖励走物品/关系/装饰，不走属性）、场景点击经营（活动入口是场景内可点实体）、NPC/系统/场景提示分离（沿用 `NoticeManager` 三 source_kind）、固定物价（节日商品是**新品**不是**打折**）、存档兼容（新增字段全部可缺省）、温柔治愈（无倒计时压迫、无失败惩罚）。

---

## 0. 与主方案的根本分歧（先摆立场）

| 维度 | 主方案（推测） | **本方案** | 理由 |
|---|---|---|---|
| 节日数据组织 | 每节日一张大表，字段堆叠 | **4 张正交表**：`festival_events` / `festival_goods` / `festival_decor` / `festival_activities` | 一节日多商品多活动，堆一张表必然出现"活动2字段"这种反模式 |
| 限时场景 | 每节日新建场景 | **不新建场景**，用 `festival_decor` 给现有场景叠装饰层 | world-001 已定场景唯一真相源；新建场景破坏流式加载与存档 |
| 活动实现 | 每节日写一段脚本 | **活动模板 + 参数**（`template_id` + `params`） | 8 节日 × 2 活动 = 16 段脚本不可维护 |
| 与经营流水线关联 | 节日当天全局 bonus | **商品级标签**：节日商品进 `goods.csv`，带 `festival_tag` | 全局 bonus 与固定物价冲突；商品级更细 |
| 与 NPC 生日关联 | 未提 | **生日与节日同天时触发"双喜"分支** | 任务明确要求关联 |
| 失败回落 | 未提 | **无失败**，只有"错过"（节日过期 → 商品下架、装饰撤除、纪念品进"往年"分类） | 温柔治愈，不做惩罚 |

---

## 1. 数据模型（4 张新表 + 2 张表扩展）

### 1.1 `data/festival_events.csv`（节日主表，替代现有 `calendar.csv` 的节日职责）

现有 `calendar.csv` 保留（它是"日历"），但**节日详情迁出**，避免 calendar 表膨胀。

```csv
event_id,day_of_year,name,type,season_hint,description,decor_id,scene_ids,goods_ids,activity_ids,npc_id,speaker,line,reward_item_id,business_bonus,collection_bonus,weather_hint,priority
pink_valentine,177,粉色情人节,romance,summer,六月末的风带着粉色气球，年轻人和老朋友都愿意停下来说话。,decor_pink,street;commercial_district;riverside,pink_candy;heart_balloon;rose_soda,act_balloon_release;act_sweet_swap,lan,花摊阿兰,"今天的花不用挑，随手拿一支都好看。",pink_ribbon,0.16,0.08,clear,10
white_valentine,274,白色情人节,romance,autumn,十月里也有人补过白色情人节，花店和糖水铺把旧心意重新包好。,decor_white,street;commercial_district,white_choco;marshmallow_tea;paper_letter,act_letter_wall;act_tea_pairing,lan,花摊阿兰,"白色情人节不是补过，是慢慢来。",white_letter,0.16,0.08,clear,10
spring_festival,1,春节,family,winter,街口的红纸和灯笼从腊月挂到正月。,decor_spring,home;street;commercial_district;night_market,dumpling_set;nian_gao;red_envelope_tea,act_dumpling_table;act_lantern_riddle,li_ma,李妈,"来，先吃口热的，年还没过完呢。",spring_couplet,0.20,0.06,cool,20
lantern_festival,15,元宵节,family,winter,街区挂起灯笼，夜里比平时热闹。,decor_lantern,street;riverside;night_market,tangyuan;lantern_cake,act_lantern_riddle;act_river_lantern,li_ma,李妈,"汤圆煮好了，甜的咸的都有。",paper_lantern,0.10,0.03,clear,15
dragon_boat,95,端午节,family,summer,街坊开始包粽子，江边风里有艾草香。,decor_dragon,street;riverside,zongzi;herbal_pouch;realgar_wine,act_zongzi_wrap;act_river_watch,qing_jie,阿青,"江边今天人多，我扫慢一点。",herbal_sachet,0.12,0.04,humid,15
qixi,210,七夕,romance,autumn,城里抬头能看见细细一条银河，旧街也有人讲牛郎织女。,decor_qixi,riverside;street;commercial_district,star_cake;wish_strip,act_star_gazing;act_wish_wall,lan,花摊阿兰,"今晚的星星，比花还难挑。",wish_strip_keepsake,0.13,0.07,clear,15
mid_autumn,225,中秋节,family,autumn,月饼和柚子摆在柜台最显眼的位置。,decor_mid_autumn,home;street;commercial_district;riverside,mooncake;pomelo;osmanthus_tea,act_mooncake_share;act_moon_watch,li_ma,李妈,"月饼切开分着吃，才叫过节。",moon_cake_box,0.16,0.05,clear,15
christmas,354,圣诞节,romance,winter,商业区亮起暖色小灯，咖啡店门口挂起了铃铛。,decor_christmas,commercial_district;street;store,gingerbread;hot_cocoa;wreath_cookie,act_gift_exchange;act_carol_corner,ji,摄影师小纪,"灯是暖的，拍出来也暖。",christmas_bell,0.18,0.06,cool,10
```

**字段说明**：
- `scene_ids` / `goods_ids` / `activity_ids`：**分号分隔**（对齐 ui-001 裁决"分号分隔"），避免逗号冲突。
- `decor_id`：指向 `festival_decor.csv`，**不新建场景**，只叠装饰。
- `priority`：同日多节日时的仲裁（如春节与元旦不冲突，但若扩展出冲突日，高 priority 胜）。
- `npc_id` / `speaker` / `line`：沿用现有 `festival_manager.gd` 的字段，**向后兼容**。
- `reward_item_id`：纪念品，进 `CollectionManager`，**不进商店**。

### 1.2 `data/festival_goods.csv`（节日特殊商品，与 `goods.csv` 同构 + 节日标签）

**关键决策**：节日商品**不是打折**，是**新品**。固定物价约束下，节日商品有自己的 `base_cost`，节日后**下架**（不再出现在商店），但**已购买的物品保留**。

```csv
goods_id,name,base_cost,unit,category,description,festival_tag,available_from,available_to,recipe_id,unlock_condition
pink_candy,粉色糖果,3,份,甜点,粉色糖纸包着，甜得有点不好意思。,pink_valentine,177,177,,always
heart_balloon,心形气球,5,个,杂货,拿在手里会轻轻晃，像在点头。,pink_valentine,177,177,,always
rose_soda,玫瑰苏打,6,杯,饮品,气泡里浮着一片玫瑰花瓣。,pink_valentine,177,177,recipe_rose_soda,always
white_choco,白巧克力,4,份,甜点,白色情人节限定，甜度刚好。,white_valentine,274,274,,always
marshmallow_tea,棉花糖茶,5,杯,饮品,棉花糖在热茶上慢慢化开。,white_valentine,274,274,recipe_marshmallow_tea,always
paper_letter,信纸,2,份,杂货,可以写点什么，也可以什么都不写。,white_valentine,274,274,,always
dumpling_set,饺子套餐,12,份,主食,春节限定，皮薄馅大。,spring_festival,1,15,recipe_dumpling,always
nian_gao,年糕,6,份,主食,煎得两面金黄，蘸糖吃。,spring_festival,1,15,recipe_nian_gao,always
red_envelope_tea,红包茶,4,杯,饮品,茶包做成红包形状，图个吉利。,spring_festival,1,15,,always
tangyuan,汤圆,5,份,甜点,元宵节限定，黑芝麻馅。,lantern_festival,15,15,recipe_tangyuan,always
lantern_cake,灯笼糕,4,份,甜点,做成小灯笼形状的米糕。,lantern_festival,15,15,,always
zongzi,粽子,6,个,主食,端午限定，咸蛋黄肉粽。,dragon_boat,95,95,recipe_zongzi,always
herbal_pouch,艾草香囊,8,个,杂货,挂在门口驱蚊，也驱散一点心事。,dragon_boat,95,95,,always
realgar_wine,雄黄酒,10,瓶,饮品,端午限定，浅尝即可。,dragon_boat,95,95,,always
star_cake,星星糕,5,份,甜点,七夕限定，做成星星形状。,qixi,210,210,recipe_star_cake,always
wish_strip,许愿条,2,条,杂货,写下愿望挂在河边。,qixi,210,210,,always
mooncake,月饼,8,个,甜点,中秋限定，莲蓉蛋黄。,mid_autumn,225,225,recipe_mooncake,always
pomelo,柚子,6,个,生鲜,中秋限定，剥开满屋清香。,mid_autumn,225,225,,always
osmanthus_tea,桂花茶,4,杯,饮品,中秋限定，桂花香很淡。,mid_autumn,225,225,,always
gingerbread,姜饼人,5,个,甜点,圣诞限定，糖霜画笑脸。,christmas,354,354,recipe_gingerbread,always
hot_cocoa,热可可,5,杯,饮品,圣诞限定，上面浮着棉花糖。,christmas,354,354,recipe_hot_cocoa,always
wreath_cookie,花环饼干,6,份,甜点,圣诞限定，绿色糖霜。,christmas,354,354,,always
```

**字段说明**：
- `festival_tag`：与 `festival_events.event_id` 对应。**空 = 常驻商品**。
- `available_from` / `available_to`：**day_of_year 范围**。春节跨 1~15 天，其余单日。
- `recipe_id`：指向现有 `recipes.csv`（若存在），**节日商品可进经营流水线**（早餐店/夜宵摊可卖）。
- `unlock_condition`：`always` / `npc_affinity:lan>=3` / `collection_count>=10` 等，**可缺省**。

### 1.3 `data/festival_decor.csv`（场景装饰层，不新建场景）

```csv
decor_id,scene_id,decor_type,asset_key,anchor_x,anchor_y,z_index,active_from,active_to,light_color,light_energy
decor_pink,street,pink_balloon,decor_pink_balloon,320,180,5,177,177,#F5B8C4,0.6
decor_pink,commercial_district,pink_banner,decor_pink_banner,640,120,5,177,177,#F5B8C4,0.6
decor_pink,riverside,pink_lantern,decor_pink_lantern,480,240,5,177,177,#F5B8C4,0.6
decor_white,street,white_ribbon,decor_white_ribbon,320,180,5,274,274,#F0E8DC,0.5
decor_white,commercial_district,white_arch,decor_white_arch,640,120,5,274,274,#F0E8DC,0.5
decor_spring,home,red_couplet,decor_spring_couplet,160,80,5,1,15,#D96A5A,0.7
decor_spring,street,red_lantern,decor_spring_lantern,320,180,5,1,15,#D96A5A,0.7
decor_spring,commercial_district,red_banner,decor_spring_banner,640,120,5,1,15,#D96A5A,0.7
decor_spring,night_market,red_lantern_row,decor_spring_lantern_row,400,200,5,1,15,#D96A5A,0.7
decor_lantern,street,lantern_string,decor_lantern_string,320,180,5,15,15,#E8B84A,0.6
decor_lantern,riverside,lantern_float,decor_lantern_float,480,240,5,15,15,#E8B84A,0.6
decor_lantern,night_market,lantern_row,decor_lantern_row,400,200,5,15,15,#E8B84A,0.6
decor_dragon,street,herbal_bundle,decor_dragon_herb,320,180,5,95,95,#7A9A6A,0.4
decor_dragon,riverside,dragon_boat,decor_dragon_boat,480,240,5,95,95,#7A9A6A,0.4
decor_qixi,riverside,star_string,decor_qixi_star,480,240,5,210,210,#C8B8E0,0.5
decor_qixi,street,wish_wall,decor_qixi_wall,320,180,5,210,210,#C8B8E0,0.5
decor_qixi,commercial_district,star_arch,decor_qixi_arch,640,120,5,210,210,#C8B8E0,0.5
decor_mid_autumn,home,moon_window,decor_mid_moon,160,80,5,225,225,#F0D8A0,0.6
decor_mid_autumn,street,moon_lantern,decor_mid_lantern,320,180,5,225,225,#F0D8A0,0.6
decor_mid_autumn,commercial_district,moon_banner,decor_mid_banner,640,120,5,225,225,#F0D8A0,0.6
decor_mid_autumn,riverside,moon_reflection,decor_mid_reflect,480,240,5,225,225,#F0D8A0,0.6
decor_christmas,commercial_district,christmas_tree,decor_christmas_tree,640,120,5,354,354,#E8C87A,0.7
decor_christmas,street,christmas_light,decor_christmas_light,320,180,5,354,354,#E8C87A,0.7
decor_christmas,store,wreath,decor_christmas_wreath,200,100,5,354,354,#E8C87A,0.7
```

**字段说明**：
- `scene_id`：**必须是 `scene_zones.csv` 中已存在的场景**（world-001 唯一真相源）。装饰层挂在该场景的 `DecorLayer` 节点下。
- `anchor_x` / `anchor_y`：**场景局部坐标**（不是世界坐标），因为装饰层随场景移动。
- `z_index`：装饰层统一 z=5（在背景之上、NPC 之下）。
- `light_color` / `light_energy`：柔光参数，**低饱和暖色**约束。

### 1.4 `data/festival_activities.csv`（活动模板 + 参数）

**核心决策**：活动**不写死流程**，只定义 `template_id` + `params`。模板在代码中实现，参数在 CSV 中配置。

```csv
activity_id,festival_tag,template_id,title,scene_id,anchor_x,anchor_y,npc_id,params,reward_money,reward_energy,reward_item_id,reward_affinity,fail_fallback
act_balloon_release,pink_valentine,release,放气球,street,320,180,lan,count=3;color=pink,30,0,,2,none
act_sweet_swap,pink_valentine,swap,交换甜食,commercial_district,640,120,lan,partner=random;item=pink_candy,20,0,,3,none
act_letter_wall,white_valentine,write,写信墙,street,320,180,lan,count=1;item=paper_letter,20,0,,2,none
act_tea_pairing,white_valentine,pair,茶点搭配,commercial_district,640,120,lan,item_a=marshmallow_tea;item_b=white_choco,25,0,,3,none
act_dumpling_table,spring_festival,craft,包饺子,home,160,80,li_ma,count=5;item=dumpling_set,40,5,,3,none
act_lantern_riddle,spring_festival,riddle,猜灯谜,street,320,180,li_ma,count=3;difficulty=easy,35,0,,2,none
act_lantern_riddle,lantern_festival,riddle,猜灯谜,street,320,180,li_ma,count=3;difficulty=easy,30,0,,2,none
act_river_lantern,lantern_festival,release,放河灯,riverside,480,240,li_ma,count=1;item=paper_lantern,25,0,,2,none
act_zongzi_wrap,dragon_boat,craft,包粽子,riverside,480,240,qing_jie,count=3;item=zongzi,35,5,,3,none
act_river_watch,dragon_boat,watch,看龙舟,riverside,480,240,qing_jie,duration=60,20,0,,2,none
act_star_gazing,qixi,watch,看星星,riverside,480,240,lan,duration=120,25,0,,3,none
act_wish_wall,qixi,write,许愿墙,street,320,180,lan,count=1;item=wish_strip,20,0,,2,none
act_mooncake_share,mid_autumn,craft,分月饼,home,160,80,li_ma,count=4;item=mooncake,40,5,,3,none
act_moon_watch,mid_autumn,watch,赏月,riverside,480,240,li_ma,duration=120,25,0,,2,none
act_gift_exchange,christmas,swap,交换礼物,commercial_district,640,120,ji,partner=random;item=gingerbread,30,0,,3,none
act_carol_corner,christmas,watch,听唱诗,commercial_district,640,120,ji,duration=90,25,0,,2,none
```

**字段说明**：
- `template_id`：`release` / `swap` / `write` / `pair` / `craft` / `riddle` / `watch` 七种模板。
- `params`：**分号分隔的 key=value**，模板解析。
- `fail_fallback`：**本方案全部为 `none`**（温柔治愈，无失败）。字段保留供未来扩展。
- `reward_*`：奖励走 `GameState.earn` / `change_energy` / `InventoryManager.add_item` / `RelationshipManager.affinity`，**不新增数值属性**。

### 1.5 扩展 `data/npcs.csv`（NPC 生日关联）

现有 `npcs.csv` 已有 `birthday` 字段（npc-001 输出中 `song` 生日 175 等）。**新增一列**：

```csv
birthday_festival_bonus
```

- 空 = 无特殊。
- `double` = 生日与节日同天时，触发"双喜"分支：`festival_manager` 检测 `birthday == day_of_year` 且有节日 → 额外 `NoticeManager.show_npc_message` + 额外 `reward_affinity +3`。

**不新增生日专属节日**，避免节日表膨胀。

---

## 2. 触发条件（唯一事实源）

### 2.1 节日触发

```
CalendarManager.calendar_day_started(day_of_year, festival_name)
  → FestivalManager._on_calendar_day_started
    → 查 festival_events.csv by day_of_year
      → 若多行（同日多节日）：按 priority 降序，取最高
      → 设置 active_event_id
      → 若 notified 无此 day_key：
          → NoticeManager.show_npc_message(line, speaker, "positive")
          → 应用装饰层（FestivalDecorLayer.apply(decor_id)）
          → 注册节日商品（FestivalGoodsRegistry.register(goods_ids)）
          → 注册活动入口（FestivalActivityRegistry.register(activity_ids)）
          → festival_started.emit
          → SaveManager.request_auto_save("festival")
```

### 2.2 节日商品触发

```
商店/经营流水线查询商品时：
  → GoodsRegistry.get_available_goods()
    → 过滤：festival_tag 为空 OR festival_tag == active_event_id
    → 过滤：day_of_year 在 [available_from, available_to]
    → 返回可用商品列表
```

**关键**：节日商品**不进 `goods.csv`**，进 `festival_goods.csv`。`GoodsRegistry` 合并两张表。这样 `goods.csv` 保持稳定，存档兼容。

### 2.3 活动触发

```
场景加载时：
  → FestivalActivityRegistry.get_activities_for_scene(scene_id)
    → 过滤：festival_tag == active_event_id
    → 在场景中生成可点实体（WorldInteractable 子类）
    → 实体 on_tap → FestivalManager.join_activity(activity_id)
```

**活动入口是场景内可点实体**，不是 HUD 按钮，符合"场景点击经营"约束。

### 2.4 NPC 生日关联

```
CalendarManager.calendar_day_started
  → FestivalManager 检测：
    → 遍历 npcs.csv，找 birthday == day_of_year 的 NPC
    → 若有节日且该 NPC 是节日 NPC：触发"双喜"分支
    → 若无节日：触发"生日"分支（现有逻辑）
```

---

## 3. 奖励与失败回落

### 3.1 奖励矩阵

| 奖励类型 | 来源 | 落地 |
|---|---|---|
| 金钱 | `activity.reward_money` | `GameState.earn` |
| 体力 | `activity.reward_energy` | `GameState.change_energy` |
| 物品 | `activity.reward_item_id` / `event.reward_item_id` | `InventoryManager.add_item` + `CollectionManager.discovered` |
| 关系 | `activity.reward_affinity` | `RelationshipManager.affinity[npc_id] += n` |
| 装饰 | `decor_id` | 场景装饰层，**不进背包** |
| 经营加成 | `event.business_bonus` | `CalendarManager.get_business_bonus`（现有） |
| 收藏加成 | `event.collection_bonus` | `CalendarManager.get_collection_bonus`（现有） |

### 3.2 失败回落（本方案：无失败，只有"错过"）

| 场景 | 回落 |
|---|---|
| 节日当天未参加活动 | 无惩罚。活动入口次日消失，纪念品进"往年"分类（`CollectionManager` 标记 `missed`） |
| 节日商品未购买 | 无惩罚。次日下架，**已购买的保留** |
| 节日 NPC 未对话 | 无惩罚。次日 NPC 恢复日常台词 |
| 存档在节日中途 | `active_event_id` 存盘，读档后恢复。若读档时 `day_of_year` 已过 → 清空 `active_event_id`，装饰撤除 |
| 同日多节日 | 按 `priority` 取最高，其余**静默跳过**（不弹提示，避免刷屏） |

**关键**：`fail_fallback` 字段全部 `none`，但保留字段供未来扩展（如"雨天活动取消"）。

---

## 4. 与经营流水线关联

### 4.1 节日商品进流水线

```
早餐店/夜宵摊的菜单：
  → 查询 GoodsRegistry.get_available_goods()
  → 节日商品若在 available_from~available_to 内，出现在菜单
  → 玩家可制作（若有 recipe_id）或直接售卖
  → 节日商品有独立 base_cost，**不打折**
```

### 4.2 节日加成

```
CalendarManager.get_business_bonus() → 节日当天经营收入 × (1 + bonus)
CalendarManager.get_collection_bonus() → 节日当天收藏品发现率 × (1 + bonus)
```

**现有逻辑保留**，不新增。

### 4.3 节日活动与经营联动

- `craft` 模板活动（包饺子、包粽子、分月饼）：消耗 `item`，产出 `reward_item_id`，**可进背包**。
- `swap` 模板活动（交换甜食、交换礼物）：消耗 `item`，与随机 NPC 交换，**关系 +3**。
- `watch` 模板活动（看星星、赏月）：**不消耗**，纯关系 + 纪念品。

---

## 5. 迁移步骤（可回退）

### 阶段 0：门禁（阻塞）

```bash
# 验证现有 festival_manager.gd 的字段依赖
grep -n "get_row\|festival_events\|calendar" autoload/festival_manager.gd
# 验证 ConfigDB 是否支持多表
grep -n "def get_row\|def get_rows" autoload/config_db.gd
# 验证 scene_zones.csv 存在的场景
python -c "import csv; [print(r['scene_id']) for r in csv.DictReader(open('data/scene_zones.csv'))]"
```

**裁决**：
- 若 `ConfigDB` 只支持单表 → 先扩展 `ConfigDB` 支持多表（`get_row(table, key)`）。
- 若 `scene_zones.csv` 无 `commercial_district` → 用现有场景替代，**不新建场景**。

### 阶段 1：数据层（无代码依赖）

1. 新建 `data/festival_events.csv`（8 节日）。
2. 新建 `data/festival_goods.csv`（22 商品）。
3. 新建 `data/festival_decor.csv`（24 装饰）。
4. 新建 `data/festival_activities.csv`（16 活动）。
5. 扩展 `data/npcs.csv` 新增 `birthday_festival_bonus` 列（全部留空，后续填）。
6. **保留 `data/calendar.csv`**，但删除 `business_bonus` / `collection_bonus` / `weather_hint` 列（迁到 `festival_events.csv`）。**或**保留列但标记 deprecated，读时优先 `festival_events.csv`。

### 阶段 2：代码层（feature flag 可回退）

```gdscript
# autoload/festival_manager.gd 扩展
const USE_NEW_FESTIVAL_PIPELINE := true  # feature flag

func _on_calendar_day_started(calendar_day: int, _festival_name: String) -> void:
    if USE_NEW_FESTIVAL_PIPELINE:
        _on_calendar_day_started_v2(calendar_day)
    else:
        _on_calendar_day_started_v1(calendar_day)  # 现有逻辑
```

新增：
- `FestivalDecorLayer`（场景装饰层，挂 `DecorLayer` 节点）
- `FestivalGoodsRegistry`（节日商品注册）
- `FestivalActivityRegistry`（活动注册）
- `FestivalActivityTemplate`（7 种模板）

### 阶段 3：存档兼容

- 新增字段：`active_event_id`（已有）、`decor_applied`（新）、`activities_done`（已有）。
- 读档时：若 `active_event_id` 非空但 `day_of_year` 已过 → 清空 + 撤装饰。
- **不迁移旧存档**，旧存档读入后 `active_event_id` 为空，次日正常触发。

### 阶段 4：验证

```bash
# 验证 CSV 格式
python tools/validate_festival_csv.py
# 验证场景存在
python tools/validate_festival_scenes.py
# 验证商品 ID 不冲突
python tools/validate_festival_goods.py
```

---

## 6. 与现有系统的接口

| 现有系统 | 接口 | 变更 |
|---|---|---|
| `CalendarManager` | `calendar_day_started` 信号 | **不变** |
| `ConfigDB` | `get_row(table, key)` | **扩展支持多表** |
| `NoticeManager` | `show_npc_message` / `show_scene_message` | **不变** |
| `InventoryManager` | `add_item` / `get_item` | **不变** |
| `CollectionManager` | `discovered` / `changed` | **不变** |
| `RelationshipManager` | `affinity` | **不变** |
| `GameState` | `earn` / `change_energy` | **不变** |
| `SaveManager` | `request_auto_save` | **不变** |
| `GoodsRegistry` | `get_available_goods` | **扩展合并 `festival_goods.csv`** |
| `WorldInteractable` | `on_tap` | **活动入口继承** |

---

## 7. 关键风险与缓解

| 风险 | 缓解 |
|---|---|
| 节日商品与常驻商品 ID 冲突 | 阶段 0 门禁验证；节日商品 ID 加前缀 `festival_` 或语义前缀（`pink_candy`） |
| 装饰层与场景现有元素重叠 | `anchor_x/y` 避让现有 NPC/交互物；阶段 0 输出场景现有元素坐标 |
| 同日多节日 | `priority` 仲裁；本方案 8 节日无冲突日 |
| 存档在节日中途 | `active_event_id` 存盘；读档时校验 `day_of_year` |
| 活动模板参数解析失败 | 模板解析失败 → `push_error` + 跳过该活动，**不崩溃** |
| NPC 生日与节日同天 | `birthday_festival_bonus` 列；本方案不预设，留空 |

---

## 8. 与主方案的差异总结

1. **不新建场景**：主方案可能为每节日新建场景，本方案用装饰层叠加。
2. **4 张正交表**：主方案可能堆一张大表，本方案拆分为 events / goods / decor / activities。
3. **活动模板化**：主方案可能每节日写脚本，本方案 7 种模板 + 参数。
4. **商品级节日标签**：主方案可能全局 bonus，本方案商品级 `festival_tag`。
5. **无失败**：主方案可能有失败惩罚，本方案只有"错过"。
6. **NPC 生日关联**：主方案未提，本方案用 `birthday_festival_bonus` 列。
7. **存档兼容**：主方案可能要求迁移，本方案新增字段全部可缺省。

---

## 9. 立即可执行的下一步

1. 跑阶段 0 门禁，输出 `docs/FESTIVAL_FACTS.md`。
2. 按阶段 1 创建 4 张 CSV。
3. 按阶段 2 扩展 `festival_manager.gd`，加 feature flag。
4. 按阶段 4 写验证脚本。
5. 在 `street` 场景试点粉色情人节（177 天），验证装饰层 + 商品 + 活动。

**所有改动可回退**：feature flag 关闭 → 走现有逻辑；CSV 删除 → 无影响。

## 批判

## 批判A（qa_lead）

# 批判报告：两份节日方案的可执行缺陷与返工要求

## A. 阻塞性缺陷（未修复不得进入实现）

### A1. 主方案 §3 节日清单自相矛盾，测试断言必然失败
- §3 表列出 **20 行**（含 `new_year_eve` day 360），§7.1 测试数组也是 20 个 day，但 §10 交付物写"19 行 × 24 列"，§0 标题写"19 个节日"。
- **返工要求**：统一为 20 或删掉 `new_year_eve`。测试数组必须与 CSV 行数**逐一对齐**，且断言 `row_count == len(test_days)`。

### A2. 主方案 §7.1 测试数组与 §3 表不一致（死断言）
- §7.1 数组：`[1,15,34,45,75,95,150,165,177,210,225,240,250,270,274,300,326,330,354,360]`（20 个）
- §3 表 day_key：1,15,34,45,75,95,150,165,177,210,225,240,250,270,274,300,326,330,354,360（20 个）
- 数量对上了，但 §10 写 19 行 → **CSV 实际写几行？** 若按 §10 写 19 行，测试第 20 个 day 必然 `assert(not row.is_empty())` 失败。
- **返工要求**：先冻结行数，再写 CSV 和测试。

### A3. 主方案 D2「一天一事件」与 §3 表冲突
- D2 裁决"`festival_events.csv` 主键 = `day_key`，一天一事件"。
- 但 §3 表里 day 1 = `new_year`（元旦），§4.8 又用 day 1 承载"春节"。**同一天两个语义**，`title` 改"春节·元旦"是掩盖而非解决。
- 更严重：`new_year_eve` = day 360，`new_year` = day 1，跨年叙事断裂。
- **返工要求**：要么承认 day 1 就是"春节（承载元旦）"单一事件，要么拆表。禁止 `title` 里塞两个节日名。

### A4. 主方案 §4.1 粉色情人节"副活动 competition"与 D6 冲突
- D6 说"一行一主活动 + `sub_activities` 列存副活动"。
- §4.1 副活动是 `competition`（30 秒小游戏），但 §2.1 字段表里 `sub_activities` 格式是 `type:title`，**没有 params 字段**。
- 30 秒小游戏的时长、节奏、评分规则**无处存放**。
- **返工要求**：`sub_activities` 必须扩为 `type:title:params`，或新增 `sub_activity_params` 列。否则副活动不可实现。

### A5. 主方案 §4.1 "粉色丝带蛋糕"是死代码
- 原文："`pink_ribbon` 可作食材做成'粉色丝带蛋糕'（需 `KitchenManager` 已有配方接口，**若无则只作纪念品**）"。
- 这是**条件性死代码**：配方接口是否存在未验证，且 `pink_ribbon` 在 §2.2 定义为"纪念品"category，不是食材。
- **返工要求**：删除该句，或 G0.4 门禁必须验证 `recipes.csv` 存在且 `pink_ribbon` 可作为 ingredient。二选一，不留"若无则"。

### A6. 主方案 §4.2 白色情人节前置条件不可触达
- 前置：`FestivalManager.claimed` 中含 `pink_valentine` 的 `day_key`。
- 但 `claimed` 的 key 是 `day_key`（177），不是 `event_id`。原文写"含 `pink_valentine` 的 `day_key`"——**key 到底是 177 还是 "pink_valentine"？**
- 若 key 是 177，则跨年时 177 会被覆盖，第二年白色情人节永远触发"补过"分支。
- **返工要求**：明确 `claimed` 的 key 结构（建议 `"177_2024"` 或 `"pink_valentine_2024"`），并写清跨年重置逻辑。

### A7. 独立方案 §1.1 `festival_events.csv` 与主方案字段名冲突
- 主方案用 `day_key`，独立方案用 `day_of_year`。
- 主方案用 `scene_id`（单数），独立方案用 `scene_ids`（复数，分号分隔）。
- 主方案用 `goods_ids` 不存在，独立方案有。
- **两份方案不能同时落地**。若 QA 要验收，必须先仲裁字段名。
- **返工要求**：指定唯一事实源。建议以主方案 `day_key` 为准（因它声称"以现有接口为唯一事实源"），独立方案改名对齐。

### A8. 独立方案 §1.2 节日商品"不进 goods.csv"与经营流水线冲突
- 独立方案说节日商品进 `festival_goods.csv`，`GoodsRegistry` 合并两表。
- 但主方案 §2.2 说进 `goods.csv` 加 `festival_only` 列。
- **两份方案的 `GoodsRegistry` 实现完全不同**。若 QA 按主方案验收，独立方案的 `festival_goods.csv` 是死表。
- **返工要求**：二选一。若选独立方案，必须证明 `GoodsRegistry` 支持多表合并（G0.2 门禁未覆盖此点）。

### A9. 独立方案 §1.4 `fail_fallback` 字段全为 `none` = 死字段
- 独立方案自己说"本方案全部为 `none`（温柔治愈，无失败）"，但字段保留。
- 这是**不可触达机制**：字段存在但永远不生效，测试无法覆盖。
- **返工要求**：要么删除该列，要么至少有一个活动用非 `none` 值并写测试。禁止"保留供未来扩展"。

### A10. 独立方案 §1.4 `params` 分号分隔 key=value 与 §1.1 `scene_ids` 分号分隔冲突
- `params=count=3;color=pink` 用分号分隔 kv，kv 内用等号。
- `scene_ids=street;commercial_district` 用分号分隔值。
- 若某天 `params` 里需要分号分隔的列表（如 `items=a;b;c`），**解析歧义**。
- **返工要求**：定义转义规则，或 `params` 改用 JSON 字符串（CSV 里用双引号包裹）。

### A11. 独立方案 §2.4 NPC 生日关联逻辑不完整
- 原文："若有节日且该 NPC 是节日 NPC：触发'双喜'分支"。
- 若 NPC 生日与节日同天，但**该 NPC 不是节日 NPC**（如 `song` 生日 175，但 175 无节日）→ 走"生日"分支，OK。
- 但若 `song` 生日 175 恰好被某节日覆盖（如未来扩展）→ "该 NPC 是节日 NPC" 判断依据是什么？`festival_events.npc_id == npc_id`？
- **返工要求**：写清判断表达式，并给出测试用例：NPC 生日 = 节日 day 且 NPC 是节日 NPC / NPC 生日 = 节日 day 但 NPC 不是节日 NPC / NPC 生日 ≠ 任何节日。

### A12. 两份方案都未定义"跨年"行为
- 主方案 `claimed` 是 `Dictionary`，key 是 `day_key`（1–360）。第二年 day 177 再次触发时，`claimed[177]` 已存在 → **活动被拦截**。
- 独立方案 `active_event_id` 存盘，但未说跨年清空。
- **返工要求**：定义年份字段（`year` 或 `day_key = "177_2024"`），并写跨年测试：模拟第 1 年 day 177 参加 → 第 2 年 day 177 应可再次参加。

### A13. 两份方案都未定义"节日当天存档 → 次日读档"行为
- 主方案 §5.3 只测"读旧档 → 触发节日"，未测"节日中途存档 → 次日读档"。
- 独立方案 §3.2 提了"若读档时 day_of_year 已过 → 清空 active_event_id"，但未说装饰层如何撤除、已注册商品如何下架。
- **返工要求**：补测试用例：day 177 存档 → 模拟 day 178 读档 → 断言 `active_event_id` 为空、装饰层无 `decor_pink`、货架无 `pink_ribbon`。

### A14. 主方案 §4.1 副活动奖励公式 `maxi(0, score) * 2` 未定义 `score` 量纲
- `score` 是点击次数？节奏准确率？0–100？
- 若 `score` 是 0–100，奖励 0–200 元，与主活动 60 元**量级失衡**。
- **返工要求**：定义 `score` 范围、计算公式、上限。

### A15. 主方案 §4.1 "按 `GameState.energy` 结算名次"是伪逻辑
- 体力与比赛名次无因果关系。这是**不可验证断言**。
- **返工要求**：改为"按小游戏得分结算名次"，或删除该句。

### A16. 独立方案 §1.3 `festival_decor.csv` 的 `anchor_x/y` 是硬编码坐标
- 24 行装饰，每行硬编码 `anchor_x/y`。
- 若场景布局调整（world-001 后续迭代），装饰全部错位。
- **返工要求**：改为 `anchor_node`（挂载到场景内已存在的命名节点），或提供坐标校验脚本。

### A17. 独立方案 §1.1 `festival_events.csv` 缺 `fallback_line`
- 主方案 §2.1 有 `fallback_line` 必填。
- 独立方案说"无失败"，但任务要求"失败回落"。
- **返工要求**：独立方案必须补 `missed_line`（错过台词），否则不满足任务要求。

### A18. 两份方案都未定义"节日商品在非节日日的存档行为"
- 玩家 day 177 买了 `pink_ribbon`，day 178 存档。
- 主方案：`goods.csv` 有 `festival_only` 列，货架过滤。但**背包里的 `pink_ribbon` 是否保留？**
- 独立方案：`festival_goods.csv` 下架，但已购买保留。
- **返工要求**：明确写"已购买物品永久保留，仅货架可见性受节日控制"，并写测试。

### A19. 主方案 §6 步骤 7 "场景注入实体"未指定注入时机
- 是场景加载时注入？还是 `festival_started` 信号后注入？
- 若玩家在节日当天已在场景内，信号触发后是否补注入？
- **返工要求**：定义注入时机 + 补注入逻辑 + 测试用例（节日切换瞬间玩家在场景内）。

### A20. 两份方案都未定义"节日活动入口与现有交互物冲突"处理
- 若 `street` 场景已有 NPC 在 (320,180)，节日装饰/活动入口也放 (320,180) → 重叠。
- **返工要求**：G0.3 门禁必须输出场景现有交互物坐标，装饰/活动坐标必须避让。

---

## B. 存档风险（必须补测试）

| # | 风险 | 测试用例 |
|---|---|---|
| B1 | 跨年 `claimed` 未重置 | 第 1 年 day 177 参加 → 第 2 年 day 177 应可再次参加 |
| B2 | 节日中途存档 → 次日读档 | day 177 存档 → day 178 读档 → 装饰撤除、商品下架、`active_event_id` 清空 |
| B3 | 旧档无 `birthday_combo_done` | 读旧档 → 不报错 → 触发节日 → 字段自动初始化 |
| B4 | 旧档无 `festival_only` 列 | 读旧档 → 货架不隐藏任何商品 |
| B5 | 节日商品已购买 → 次日读档 | `pink_ribbon` 仍在背包 |
| B6 | 同日多节日 priority 仲裁 | 构造 day X 两节日 → 只触发高 priority |
| B7 | 存档在活动进行中（小游戏未结束） | 读档后活动状态重置，不卡死 |
| B8 | `sub_activities_done` 嵌套字典序列化 | 存 → 读 → 结构一致 |

---

## C. 测试漏洞（必须补断言）

### C1. 主方案 §7.1 测试只查 `row.has("scene_id")`，不查值有效性
- 应断言 `row["scene_id"] in VALID_SCENE_KEYS`。
- 应断言 `row["npc_id"] in VALID_NPC_IDS`。
- 应断言 `row["reward_item_id"] in VALID_GOODS_IDS`。

### C2. 主方案 §7.2 "订单量对比非节日日 +16%" 不可验证
- 订单量是随机生成？如何对比？
- **返工要求**：改为断言 `CalendarManager.get_business_bonus(177) == 0.16`。

### C3. 主方案 §7.3 "同一天重复点击 → 返回'今天已经参加过了'" 未定义返回值
- 是返回空字典？返回错误码？抛异常？
- **返工要求**：定义 `join_today_activity()` 的返回契约。

### C4. 独立方案 §4 验证脚本 `validate_festival_csv.py` 未定义检查项
- 应检查：字段数一致、`festival_tag` 外键存在、`scene_id` 在 `scene_zones.csv`、`goods_id` 不冲突、`activity_id` 唯一。

### C5. 两份方案都未测"节日装饰层与场景切换"
- 玩家从 `street` 走到 `commercial_district`，装饰层是否正确切换？
- **返工要求**：补场景切换测试。

### C6. 两份方案都未测"节日活动入口在场景重载后是否重复生成"
- 场景重载 → 活动入口是否重复？是否泄漏节点？
- **返工要求**：补节点计数断言。

### C7. 主方案 §4.2 白色情人节"好感最高者"未定义 tie-break
- 两个 NPC 好感相同 → 选谁？
- **返工要求**：定义 tie-break（如按 `npc_id` 字典序）。

### C8. 独立方案 §1.4 `act_lantern_riddle` 在 `spring_festival` 和 `lantern_festival` 重复出现
- `activity_id` 相同，`festival_tag` 不同 → 主键冲突？
- **返工要求**：`activity_id` 必须唯一，改为 `act_lantern_riddle_spring` / `act_lantern_riddle_lantern`。

---

## D. 冲突清单（两份方案互斥项）

| 冲突点 | 主方案 | 独立方案 | 仲裁要求 |
|---|---|---|---|
| 节日商品表 | `goods.csv` 扩列 | 新建 `festival_goods.csv` | 二选一，G0.2 门禁决定 |
| 场景 key 字段 | `scene_id`（单数） | `scene_ids`（复数） | 二选一 |
| day 字段名 | `day_key` | `day_of_year` | 二选一 |
| 活动实现 | 每节日写流程 | 模板 + 参数 | 二选一 |
| 失败回落 | `fallback_line` 必填 | `fail_fallback=none` | 任务要求失败回落 → 主方案胜 |
| 春节 | 用元旦承载 | 独立 `spring_festival` day 1 | 独立方案更清晰 |
| 装饰层 | `decoration` 字段 | 独立 `festival_decor.csv` | 独立方案更可维护 |
| 商品可见性 | `festival_only` 列 | `available_from/to` 范围 | 独立方案支持跨天节日 |

---

## E. 返工要求（按优先级）

### P0（阻塞，必须先做）
1. **仲裁字段名**：`day_key` vs `day_of_year`，`scene_id` vs `scene_ids`，`goods.csv` 扩列 vs `festival_goods.csv`。写进 `docs/FESTIVAL_FACTS.md`。
2. **冻结节日数量**：19 还是 20？测试数组与 CSV 行数对齐。
3. **定义 `claimed` key 结构**：含年份，跨年可重置。
4. **补跨年测试**：B1。
5. **补节日中途存档测试**：B2。

### P1（高优）
6. **`sub_activities` 扩 params**：否则副活动不可实现。
7. **删除死代码**：主方案 §4.1 "粉色丝带蛋糕"、独立方案 `fail_fallback=none`。
8. **定义 `score` 量纲**：主方案 §4.1 副活动奖励公式。
9. **补 `missed_line`**：独立方案必须满足任务"失败回落"要求。
10. **`activity_id` 唯一性**：独立方案 `act_lantern_riddle` 重复。

### P2（中优）
11. **装饰坐标避让**：G0.3 门禁输出场景现有交互物坐标。
12. **注入时机定义**：主方案 §6 步骤 7。
13. **测试断言强化**：C1–C8。
14. **`params` 转义规则**：独立方案 §1.4。

### P3（低优）
15. **tie-break 定义**：主方案 §4.2。
16. **节点泄漏测试**：C6。

---

## F. 可执行验证脚本（返工后必须通过）

```bash
#!/bin/bash
# tools/validate_festival.sh
set -e

echo "=== G0 门禁 ==="
test -f data/festival_events.csv || { echo "FAIL: festival_events.csv 不存在"; exit 1; }
head -1 data/festival_events.csv | grep -q "day_key" || { echo "FAIL: 字段名未仲裁"; exit 1; }

echo "=== 行数一致性 ==="
CSV_ROWS=$(tail -n +2 data/festival_events.csv | wc -l)
TEST_DAYS=$(grep -oP '\[\K[^\]]+' tools/test_festival.gd | tr ',' '\n' | wc -l)
[ "$CSV_ROWS" -eq "$TEST_DAYS" ] || { echo "FAIL: CSV $CSV_ROWS 行 vs 测试 $TEST_DAYS 天"; exit 1; }

echo "=== 场景 key 有效性 ==="
python3 -c "
import csv
valid = {r['scene_id'] for r in csv.DictReader(open('data/scene_zones.csv'))}
for r in csv.DictReader(open('data/festival_events.csv')):
    for s in r['scene_id'].split(';'):
        assert s in valid, f'无效场景 {s} in {r[\"event_id\"]}'
print('OK')
"

echo "=== NPC id 有效性 ==="
python3 -c "
import csv
valid = {r['npc_id'] for r in csv.DictReader(open('data/npcs.csv'))}
for r in csv.DictReader(open('data/festival_events.csv')):
    assert r['npc_id'] in valid, f'无效 NPC {r[\"npc_id\"]}'
print('OK')
"

echo "=== 商品 id 唯一性 ==="
python3 -c "
import csv
ids = [r['goods_id'] for r in csv.DictReader(open('data/goods.csv'))]
assert len(ids) == len(set(ids)), '商品 id 重复'
print('OK')
"

echo "=== activity_id 唯一性 ==="
python3 -c "
import csv
ids = [r['activity_id'] for r in csv.DictReader(open('data/festival_activities.csv'))]
assert len(ids) == len(set(ids)), '活动 id 重复'
print('OK')
"

echo "=== 跨年测试 ==="
godot --headless --script tools/test_festival_cross_year.gd

echo "=== 节日中途存档测试 ==="
godot --headless --script tools/test_festival_mid_save.gd

echo "ALL PASS"
```

---

## G. 一句话总结

**两份方案都不能直接实现**：主方案有 20 个可执行缺陷（行数矛盾、字段缺失、死代码、不可触达前置），独立方案有 8 个（字段名冲突、死字段、重复主键、缺失败回落）。**先仲裁字段名和节日数量，再补跨年/中途存档测试，最后删死代码**。未通过 F 节脚本，不得进入代码实现。

## 批判B（gameplay_planner）

# 批判裁决：两份方案均不可直接执行，需返工

## 一、共同致命缺陷（两方案都犯）

### C1. 春节/元宵/端午/中秋/七夕的农历映射被回避，但任务明确要求这些节日
- 主方案 §3 直接写"用元旦承载春节"，把 `new_year` 的 title 改成"春节·元旦"——**这是偷换概念**。任务要求"春节、端午、中秋、元宵、七夕"，不是"元旦改名"。
- 独立方案同样只列 8 个节日，**端午/中秋/元宵/七夕的农历问题一字未提**，`day_of_year` 直接写死 95/225/15/210，等于假设这些节日每年固定公历日——**事实错误**。
- **返工要求**：必须给出农历→公历映射方案。二选一：
  - (a) 引入 `lunar_calendar.csv`（年份 × 节日 → day_of_year），存档记 `current_year`；
  - (b) 明确声明"本作采用固定历，节日按固定 day_of_year 触发，不追求真实农历"，并在 `docs/FESTIVAL_FACTS.md` 写明这是**设计取舍**，且 `title` 不得写"春节"误导玩家（可写"岁首节"）。
  - **不接受**"用元旦承载春节"这种既想蹭春节语义又不做映射的糊弄。

### C2. 360 天历 vs 365 天历未确认，所有 day_key 可能整体错位
- 主方案 §2.1 写"1–360"，但 §3 表格里 `christmas=354`、`new_year_eve=360`，而 `pink_valentine=177`（6月27日）、`white_valentine=274`（10月4日）——**这两个日期是按 365 天历算的**。6月27日是第 178 天（非闰年），10月4日是第 277 天，不是 177/274。
- 独立方案同样写 177/274，**没算过**。
- **返工要求**：先跑 `CalendarManager` 确认一年多少天、day_of_year 从 0 还是 1 起算，再重算所有 day_key。给出换算表。

### C3. 粉色情人节 6/27、白色情人节 10/4 的日期本身存疑
- 任务写"6月27日粉色情人节、10月4日白色情人节"。这两个日期**不是通行节日**（通行的是 2/14 情人节、3/14 白色情人节）。任务可能是笔误，也可能是有意设定。
- 两方案都**没质疑**，直接照抄。
- **返工要求**：向任务方确认。若确认是 6/27 和 10/4，则 day_key 必须按真实历法重算（见 C2）；若是笔误，改回 2/14 和 3/14。

### C4. "至少两类事件"被降格为"一行主活动 + 一列 sub_activities 字符串"
- 主方案 D6 说"一行一主活动 + sub_activities 列存副活动"，但 §2.1 的 `sub_activities` 格式是 `type:title`——**只有标题，没有触发条件、没有奖励、没有回落、没有场景锚点**。副活动是死数据，无法执行。
- 独立方案用 `festival_activities.csv` 多行，这点**比主方案好**，但 §1.4 里 `act_lantern_riddle` 同时属于 `spring_festival` 和 `lantern_festival`，**主键 activity_id 重复**——CSV 主键冲突，读表时后一行覆盖前一行。
- **返工要求**：
  - 主方案：删除 `sub_activities` 字符串列，改为 `festival_activities.csv` 多行（采纳独立方案思路）。
  - 独立方案：`activity_id` 必须唯一，改为 `act_lantern_riddle_spring` / `act_lantern_riddle_lantern`，或引入复合主键 `(festival_tag, activity_id)`。

### C5. NPC 生日字段"待确认"被当成可选项，但任务明确要求关联
- 主方案 G0.5 说"若已有 birthday 列则复用，若无则只定义列名，取值由 npc-001 补"——**把任务要求推给别人**。
- 独立方案 §1.5 说"现有 npcs.csv 已有 birthday 字段（npc-001 输出中 song 生日 175 等）"——**引用了不存在的事实**。npc-001 是否真的定了 birthday？两方案都没跑 `grep` 验证。
- 且主方案 §4.1 写"若 lan 生日为 177（npc-001 未定，待确认）"——**自己都不确定，却写进方案**。
- **返工要求**：跑 `grep -n "birthday" data/npcs.csv`，把实际结果写进 `docs/FESTIVAL_FACTS.md`。若字段不存在，本方案必须**自己定义并填值**（8 位 NPC 生日），不能推给 npc-001。

### C6. 存档风险：两方案都假设 `claimed`/`activities_done` 已序列化，但没验证
- 主方案 G0.6 说"确认是否已序列化，若未序列化则 §5 补迁移"——**但 §5 只写了新增字段，没写"若旧字段未序列化怎么办"**。
- 独立方案 §5 说"不迁移旧存档"——**如果 `claimed` 没序列化，玩家每次读档节日都能重领奖励，这是刷钱漏洞**。
- **返工要求**：跑 `grep -n "claimed\|activities_done\|notified" autoload/save_manager.gd`，把结果写进门禁文档。若未序列化，必须补序列化 + 补"已领过"的迁移逻辑（旧档默认全部未领，但要有防重复领取的运行时校验）。

### C7. 测试方案是伪测试
- 主方案 §7.1 的 `test_all_festivals` 只断言 `row` 非空、有 `scene_id`、有 `fallback_line`——**这是 CSV 格式校验，不是节日系统测试**。没测触发、没测奖励、没测存档、没测经营加成。
- 独立方案 §5 阶段 4 只写"验证 CSV 格式""验证场景存在""验证商品 ID 不冲突"——**同样没测运行时行为**。
- **返工要求**：测试必须覆盖：
  1. 节日当天 `calendar_day_started` 信号 → `active_event_id` 正确；
  2. 场景加载 → 装饰层节点存在、活动实体可点；
  3. 点击活动 → 奖励正确入账、`activities_done` 标记；
  4. 同日重复点击 → 拦截；
  5. 存档 → 退出 → 重进 → `claimed`/`activities_done` 保留；
  6. 旧档读入 → 不报错、不重复领奖；
  7. 经营加成：节日当天 vs 非节日，订单量对比。

### C8. 失败回落"温柔治愈"被滥用为"没有失败"
- 独立方案 §3.2 直接说"无失败，只有错过"，`fail_fallback` 全填 `none`——**任务明确要求"失败回落"**，不是"没有失败"。
- 主方案有 `fallback_line`，但 §4.1 写"若玩家体力 < 5 或未点击任何实体 → 当日结束显示 fallback_line"——**"未点击任何实体"不是失败，是没参与**。真正的失败（比赛输了、谜题答错）主方案只在 §4.3 元宵节写了"答错 → fallback"，其他节日没写。
- **返工要求**：每个节日必须定义**至少一个真实失败条件**（比赛名次低于阈值、谜题答错、材料不足、NPC 不在场），并给出对应回落。回落可以温柔（不惩罚），但必须存在。

---

## 二、主方案独有缺陷

### M1. `festival_events.csv` 主键 `day_key` 与"一天一事件"裁决冲突
- D2 说"主键 = day_key，一天一事件"，但 §3 表格里 `new_year=1` 和 `spring_festival`（若独立）会撞；`valentine=45` 和 `pink_valentine=177` 不撞但语义重叠。
- 更严重：`day_key` 是 int 主键，但 §2.1 又要求 `event_id` 是"事件唯一 id"——**双主键，CSV 无约束，读表时按哪个查？**
- **返工要求**：明确主键。建议 `event_id` 为主键，`day_key` 为索引列，`get_event_for_day` 内部按 day_key 查索引。

### M2. `business_bonus` 覆盖 `calendar` 值的逻辑未定义
- §6 步骤 6 说"`get_business_bonus` 优先取 festival_events"——**但 calendar.csv 里已有的 bonus 怎么办？是覆盖还是叠加？** 若叠加，节日当天可能 +32%；若覆盖，calendar 的配置失效。
- **返工要求**：明确覆盖/叠加规则，写进 `docs/FESTIVAL_FACTS.md`。

### M3. `spawn_props` 格式 `prop_id:count` 与 `sub_activities` 格式 `type:title` 都用冒号，但分隔符不同（分号 vs 分号）
- §2.1 写 `spawn_props` 分号分隔 `prop_id:count`，`sub_activities` 分号分隔 `type:title`——**两者都用分号分隔、冒号分键值，但语义完全不同**。解析代码要写两套。
- **返工要求**：统一格式或明确区分。建议 `spawn_props` 用 `prop_id=count`（等号），与 `params` 的 `key=value` 一致。

### M4. §4.1 粉色情人节"副活动 competition 按 energy 结算名次"——energy 是体力，不是比赛分数
- "按 `GameState.energy` 结算名次"——**体力高就名次高？** 这是设计错误。比赛应有独立分数（点击节奏的命中数），不是体力。
- **返工要求**：比赛名次由小游戏分数决定，体力只决定"能否参加"。

### M5. §4.2 白色情人节前置条件"claimed 中含 pink_valentine 的 day_key"——day_key 是 int，claimed 是 Dictionary，键是什么？
- 若 `claimed` 键是 `event_id`，则查 `pink_valentine`；若是 `day_key`，则查 `177`。§5.1 说 `claimed` 是 `Dictionary`，但没说键类型。
- **返工要求**：明确 `claimed` / `activities_done` / `notified` 的键结构，写进门禁文档。

### M6. §9 不做清单里"不做节日限时数值浮动（固定物价）"，但 §2.2 又给节日商品定 `base_cost`——固定物价 vs 节日商品定价，边界模糊
- 固定物价指"常驻商品价格不变"，节日商品是新品、有自己定价——**这没问题，但方案没写清楚**，容易被误读为"节日商品也固定"。
- **返工要求**：在 `docs/FESTIVAL_FACTS.md` 写明"固定物价 = 常驻商品价格不随节日浮动；节日商品是新品，有独立定价"。

---

## 三、独立方案独有缺陷

### I1. 4 张正交表是过度设计，且与"现有接口为唯一事实源"冲突
- 独立方案 §0 主张"4 张正交表"，但 §6 接口表里 `ConfigDB.get_row(table, key)` 要"扩展支持多表"——**这是改现有接口**，违反"不推翻、不重写"。
- 且 4 张表意味着 4 次 IO、4 次解析、4 处存档校验——**对 8 个节日来说是杀鸡用牛刀**。
- **返工要求**：要么证明 4 张表比 1 张表在**可维护性**上有实质收益（给出具体场景），要么合并为 2 张（events + activities，goods 和 decor 作为列内嵌或独立小表）。

### I2. `festival_goods.csv` 与 `goods.csv` 分离，但 §6 说 `GoodsRegistry` 合并两张表——合并逻辑未定义
- 若 `goods_id` 冲突怎么办？若 `festival_goods` 里的商品要进 `recipes.csv` 的配方，配方引用哪个表？
- **返工要求**：明确合并规则、冲突处理、配方引用路径。

### I3. `festival_decor.csv` 的 `anchor_x/anchor_y` 是硬编码坐标，但场景尺寸/相机位置未确认
- 若 `street` 场景实际是 1920×1080，anchor 320,180 可能落在 UI 上；若场景有滚动，anchor 是局部还是世界坐标？
- **返工要求**：跑门禁输出 `scene_zones.csv` 的实际尺寸和坐标系定义，anchor 必须基于实际数据。

### I4. `festival_activities.csv` 的 `params` 字段 `count=3;color=pink` 用分号分隔，但 §1.1 的 `scene_ids` 也用分号——**同一 CSV 体系里分号有两种语义**（列表分隔 vs 键值对分隔）
- 解析器要区分上下文，易错。
- **返工要求**：统一分隔符。建议列表用 `|`，键值对用 `;`，键值内用 `=`。

### I5. §2.1 触发流程里 `SaveManager.request_auto_save("festival")` 在节日开始时自动存档——**存档时机风险**
- 若玩家在节日开始瞬间存档，然后读档，`active_event_id` 已设但装饰未应用完，可能状态不一致。
- **返工要求**：存档时机改为"节日状态完全应用后"，或加事务性校验。

### I6. §3.2 "节日商品未购买 → 次日下架，已购买的保留"——但 `festival_goods.csv` 的 `available_to` 是 day_of_year，跨年怎么办？
- 春节 `available_from=1, available_to=15`，若玩家在第 360 天存档，第 1 天读档，`available_from=1` 是否触发？跨年边界未定义。
- **返工要求**：明确跨年逻辑。建议 `available_from > available_to` 时视为跨年区间。

### I7. §7 风险表"活动模板参数解析失败 → push_error + 跳过该活动，不崩溃"——**静默跳过是坏设计**
- 玩家看到活动入口但点了没反应，会以为是 bug。
- **返工要求**：解析失败时，活动入口不生成（而非生成后跳过），并在开发日志里报错。

### I8. §8 差异总结第 6 条"NPC 生日关联：主方案未提，本方案用 birthday_festival_bonus 列"——**主方案 §4.1/§4.2 明确提了 birthday_festival_combo**
- 独立方案对主方案的描述不实，属于**稻草人论证**。
- **返工要求**：删除或修正对主方案的错误描述。

---

## 四、两方案共同缺失的机制

### X1. 节日与"经营流水线"的关联只停留在 `business_bonus` 全局加成
- 任务要求"能与经营流水线关联"，两方案都只做了"订单量 +X%"——**这是最浅的关联**。
- 真正的流水线关联应是：节日商品作为**原料**进入配方（如"粉色丝带蛋糕"需要 `pink_ribbon`），或节日活动产出**半成品**进入厨房。
- 主方案 §4.1 提了一句"`pink_ribbon` 可作食材做成粉色丝带蛋糕（需 KitchenManager 已有配方接口，若无则只作纪念品）"——**又是"若无则不做"**。
- **返工要求**：至少 3 个节日商品必须有 `recipe_id`，且配方进 `recipes.csv`，走 `KitchenManager` 正常下单。

### X2. 节日与 NPC 生日的关联只做了"同日触发 combo"
- 任务要求"能与 NPC 生日关联"，同日 combo 是最浅的关联。
- 更深关联：节日活动**赠送的礼物**可以是 NPC 生日礼物；NPC 生日当天**若临近节日**，有预热对话。
- **返工要求**：至少定义两种关联模式：(a) 同日 combo；(b) 节日纪念品可作为生日礼物（`birthday_gift_id` 接受节日商品）。

### X3. 没有"节日预热"和"节日余韵"
- 两方案都是"节日当天触发，次日消失"——**生硬**。
- 温柔治愈风格应有：节前 1-2 天 NPC 提及、节后 1 天 NPC 回味。
- **返工要求**：`festival_events.csv` 加 `preheat_days` / `afterglow_days` 列，NPC 台词分三阶段。

### X4. 没有处理"玩家节日当天不在线"
- 若玩家第 177 天没登录，第 178 天登录，粉色情人节永久错过——**对治愈游戏是挫败**。
- 两方案都没提。
- **返工要求**：定义"补过"机制（如白色情人节可补过粉色情人节，或节日纪念品在节后 3 天内仍可购买）。

### X5. 没有节日专属的"场景提示"通道验证
- 任务要求"NPC/系统/场景提示分离"，两方案都只说"走 NoticeManager 三 source_kind"，**没验证 NoticeManager 是否真的支持三通道**。
- **返工要求**：跑 `grep -n "source_kind\|show_npc_message\|show_scene_message\|show_system_message" autoload/notice_manager.gd`，把结果写进门禁文档。

---

## 五、返工优先级

**P0（阻塞，不解决不得进入编码）**：
- C1 农历映射
- C2 360/365 天历确认 + day_key 重算
- C3 6/27、10/4 日期确认
- C5 NPC 生日字段实际状态
- C6 存档字段实际状态
- X5 NoticeManager 三通道验证

**P1（编码前必须解决）**：
- C4 副活动可执行化
- C7 测试方案重写
- C8 真实失败条件
- M1 主键明确
- M5 claimed 键结构
- I1 4 张表必要性论证
- X1 经营流水线深度关联
- X4 补过机制

**P2（编码中解决）**：
- M2 bonus 覆盖/叠加
- M3/M4/I4 格式与设计错误
- I2/I3/I5/I6/I7 独立方案细节
- X2/X3 关联深度与预热余韵

---

## 六、最终裁决

**两份方案均不可直接执行**。主方案偏"堆字段"，独立方案偏"过度正交"，但**共同回避了任务的核心难点**：农历映射、日期确认、NPC 生日实际状态、存档实际状态、真实失败条件、经营流水线深度关联。

**返工要求**：
1. 先跑完所有门禁命令，输出 `docs/FESTIVAL_FACTS.md`，**用实际输出替代所有"待确认""若存在则"**。
2. 解决 P0 全部 6 项，P1 全部 8 项。
3. 重写测试方案，覆盖 C7 列出的 7 项运行时行为。
4. 每个节日必须给出：真实 day_key、真实失败条件、至少 1 个进配方的商品、预热/余韵台词。
5. 合并两方案优点：主方案的"复用现有接口" + 独立方案的"活动模板化"，但**不接受 4 张表**，改为 2 张（events + activities），goods/decor 作为列内嵌或独立小表。

**未通过 P0 门禁前，不得写任何代码。**

## 综合决策

# 最终可执行方案：节日系统扩展（唯一裁决版）

> **综合裁决原则**：主方案的"复用现有接口" + 独立方案的"活动模板化" + 批判A的"字段仲裁/测试强化" + 批判B的"农历映射/真实失败/流水线深度关联"。
> **硬约束**：无任务面板、无数值属性条、场景点击经营、NPC/系统/场景提示分离、固定物价（常驻商品不浮动，节日商品是新品）、存档兼容、温柔治愈。
> **本方案不发明新 NPC、不发明新场景 key、不发明新结算路径。**

---

## 0. 前置门禁（阻塞性，未通过不得写代码）

所有命令输出写入 `docs/FESTIVAL_FACTS.md`，作为唯一事实源。**禁止在方案里出现"若存在则""待确认"**——门禁跑完必须给出确定值。

### G0.1 历法确认（回应批判B C2/C3）
```bash
grep -n "DAYS_PER_YEAR\|day_of_year\|current_day\|current_year" autoload/calendar_manager.gd autoload/time_system.gd
```
**必须回答**：
- 一年多少天？（360 还是 365）
- `day_of_year` 从 0 还是 1 起算？
- 是否有 `current_year` 字段？

**裁决**：
- 若 360 天 → 所有 day_key 按 360 天历重算，**6月27日 = 第 178 天**（非闰年 365 天历），360 天历下需按比例映射，**并在 `docs/FESTIVAL_FACTS.md` 写明"本作采用 360 天固定历，节日日期为设计值，非真实公历"**。
- 若 365 天 → 6月27日 = 178，10月4日 = 277。**主方案/独立方案的 177/274 全部作废**。

### G0.2 农历映射确认（回应批判B C1）
```bash
ls data/ | grep -i lunar
grep -rn "lunar\|农历\|spring_festival" data/ scripts/ autoload/ 2>/dev/null | head
```
**裁决（二选一，必须明确）**：
- **(a) 有农历表** → 复用，`festival_events.csv` 加 `lunar_rule` 列。
- **(b) 无农历表** → **本作采用固定历，节日按固定 day_of_year 触发**。`title` 不得写"春节"误导，改为"**岁首节**"；端午→"**艾草节**"；中秋→"**月圆节**"；元宵→"**灯节**"；七夕→"**星河节**"。**在 `docs/FESTIVAL_FACTS.md` 写明这是设计取舍**。

> **本方案默认走 (b)**，因为 (a) 需要引入农历库，超出"不推翻现有系统"约束。

### G0.3 场景 key 仲裁（回应批判A A20）
```bash
python3 -c "
import csv
for r in csv.DictReader(open('data/scene_zones.csv')):
    print(r['scene_id'], r.get('width','?'), r.get('height','?'))
"
```
**必须输出**：所有合法 `scene_id` + 场景尺寸 + 现有交互物坐标（用于装饰避让）。

### G0.4 ConfigDB 读取方式（回应批判A A8）
```bash
grep -n "func get_row\|func get_rows\|DictReader\|row\[" autoload/config_db.gd scripts/config_db.gd 2>/dev/null
```
**裁决**：
- 按列名取值 → 可安全扩列。
- 按索引取值 → **禁止扩列**，新建 `festival_events.csv` 独立表。

### G0.5 经营流水线接口（回应批判B X1）
```bash
grep -n "func \|signal " autoload/business_manager.gd autoload/kitchen_manager.gd 2>/dev/null | head -40
ls data/ | grep -i recipe
head -3 data/recipes.csv 2>/dev/null
```
**必须回答**：`recipes.csv` 是否存在？配方字段结构？节日商品能否作为 ingredient？

### G0.6 NPC 生日字段实际状态（回应批判B C5）
```bash
grep -n "birthday\|birth_day" data/npcs.csv
```
**裁决**：
- 已有 `birthday` 列 → 复用，记录实际值。
- 无 → **本方案自己定义并填值**（8 位 NPC 生日），不推给 npc-001。

### G0.7 存档字段实际状态（回应批判B C6）
```bash
grep -n "claimed\|activities_done\|notified\|festival" autoload/save_manager.gd
```
**裁决**：
- 已序列化 → 记录键结构。
- 未序列化 → **本方案补序列化 + 防重复领取运行时校验**（旧档默认全部未领，但 `claimed` 键含年份，跨年可重置）。

### G0.8 NoticeManager 三通道验证（回应批判B X5）
```bash
grep -n "source_kind\|show_npc_message\|show_scene_message\|show_system_message" autoload/notice_manager.gd
```
**裁决**：三通道是否存在？若不存在 → 本方案**不新增通道**，复用现有 `show_message` + `source_kind` 参数。

### G0.9 主键与键结构仲裁（回应批判A A6/A11、批判B M1/M5）
**必须明确写入 `docs/FESTIVAL_FACTS.md`**：

| 字段 | 键结构 | 示例 |
|---|---|---|
| `festival_events` 主键 | `event_id`（string） | `pink_valentine` |
| `festival_events` 索引 | `day_key`（int） | `178` |
| `FestivalManager.claimed` | `Dictionary[String, bool]`，键 = `"{event_id}_{year}"` | `"pink_valentine_1"` |
| `FestivalManager.activities_done` | `Dictionary[String, bool]`，键 = `"{activity_id}_{year}"` | `"act_balloon_release_1"` |
| `FestivalManager.notified` | `Dictionary[String, bool]`，键 = `"{event_id}_{year}"` | `"pink_valentine_1"` |

**跨年规则**：`current_year` 变化时，旧键自然失效，新键可再次触发。**不主动清空**，靠键含年份实现。

---

## 1. 决策（逐条裁决，合并两方案 + 批判）

| # | 争议点 | 裁决 | 依据 |
|---|---|---|---|
| D1 | 节日数据组织 | **2 张表**：`festival_events.csv`（主表）+ `festival_activities.csv`（活动表）。goods/decor 作为列内嵌 | 批判B I1：4 张表过度设计；批判A A7：字段名必须统一 |
| D2 | 主键 | `event_id` 为主键，`day_key` 为索引列 | 批判B M1 |
| D3 | 一天多事件 | `day_key` 唯一，同日多事件按 `priority` 仲裁 | 批判A A3 |
| D4 | 节日商品 | **进 `goods.csv` 加 `festival_tag` + `available_from` + `available_to` 列** | 批判A A8：二选一，选扩列（ConfigDB 支持列名取值时） |
| D5 | 限时场景 | **不新建场景**，用 `decor_*` 列 + `festival_decor.csv` 装饰层 | 独立方案 + 批判A A16（改 anchor_node） |
| D6 | 活动实现 | **模板 + 参数**，`festival_activities.csv` 多行，`activity_id` 唯一 | 独立方案 + 批判A C8 |
| D7 | 副活动 | **删除 `sub_activities` 字符串列**，全部进 `festival_activities.csv` | 批判A A4、批判B C4 |
| D8 | 失败回落 | **每个节日至少 1 个真实失败条件** + `fallback_line` 必填 | 批判B C8 |
| D9 | 经营流水线关联 | **至少 3 个节日商品有 `recipe_id`**，走 `KitchenManager` 正常下单 | 批判B X1 |
| D10 | NPC 生日关联 | **两种模式**：(a) 同日 combo；(b) 节日纪念品可作生日礼物 | 批判B X2 |
| D11 | 预热/余韵 | `preheat_days` / `afterglow_days` 列，NPC 台词分三阶段 | 批判B X3 |
| D12 | 补过机制 | 节日纪念品节后 3 天内仍可购买；白色情人节可补过粉色情人节 | 批判B X4 |
| D13 | 跨年 | `claimed` 键含 `year`，跨年自然重置 | 批判A A12、批判B C6 |
| D14 | 节日中途存档 | 读档时校验 `day_of_year`，过期则清 `active_event_id` + 撤装饰 + 下架商品 | 批判A A13 |
| D15 | 提示通道 | 复用 `NoticeManager` 三通道（若存在），否则 `show_message` + `source_kind` | 批判B X5 |
| D16 | 固定物价 | 常驻商品价格不浮动；节日商品是新品，有独立 `base_cost` | 批判B M6 |
| D17 | 比赛评分 | 小游戏独立 `score`（0–100），体力只决定"能否参加" | 批判B M4、批判A A14/A15 |
| D18 | 装饰坐标 | `anchor_node`（挂载到场景命名节点），非硬编码坐标 | 批判A A16 |
| D19 | 注入时机 | 场景加载时 + `festival_started` 信号后补注入 | 批判A A19 |
| D20 | 节点泄漏 | 场景重载时先清 `DecorLayer` 子节点再注入 | 批判A C6 |

---

## 2. CSV 字段定义（唯一事实源）

### 2.1 `data/festival_events.csv`（主表）

| 列名 | 类型 | 必填 | 说明 | 示例 |
|---|---|---|---|---|
| `event_id` | string | 是 | **主键** | `pink_valentine` |
| `day_key` | int | 是 | 一年中第几天（按 G0.1 确认的历法） | `178` |
| `title` | string | 是 | 节日名（无农历映射时用设计名） | `粉色情人节` |
| `type` | string | 是 | `traditional` / `world` / `commercial` | `world` |
| `priority` | int | 是 | 同日多事件仲裁，高者胜 | `10` |
| `scene_ids` | string | 是 | 分号分隔，**必须已存在** | `street;commercial_district` |
| `decor_id` | string | 是 | 指向 `festival_decor.csv` | `decor_pink` |
| `npc_id` | string | 是 | 主 NPC，**必须已存在** | `lan` |
| `speaker` | string | 是 | 提示显示名 | `花摊的阿兰` |
| `line` | string | 是 | 节日当天 NPC 台词 | `今天街上都是粉色的。` |
| `preheat_line` | string | 是 | 节前 1–2 天台词 | `明天好像有活动。` |
| `afterglow_line` | string | 是 | 节后 1 天台词 | `昨天真热闹。` |
| `preheat_days` | int | 是 | 预热天数，默认 1 | `1` |
| `afterglow_days` | int | 是 | 余韵天数，默认 1 | `1` |
| `reward_item_id` | string | 否 | 纪念品 id（进 `goods.csv`） | `pink_ribbon` |
| `goods_ids` | string | 是 | 分号分隔，节日商品 id | `pink_candy;heart_balloon` |
| `activity_ids` | string | 是 | 分号分隔，指向 `festival_activities.csv` | `act_balloon_release;act_sweet_swap` |
| `fallback_line` | string | 是 | **真实失败**时的回落台词 | `气球飞走了，但风很舒服。` |
| `fallback_reward` | string | 否 | 回落奖励，`money:10` / `item:xxx` | `money:10` |
| `missed_line` | string | 是 | **错过**（当天未参与）的台词 | `你路过时，活动已经结束了。` |
| `paired_event_id` | string | 否 | 配对节日 | `white_valentine` |
| `birthday_npc_id` | string | 否 | 若与 NPC 生日同日 | `lan` |
| `business_bonus` | float | 是 | 经营加成（**覆盖** calendar 值，不叠加） | `0.16` |
| `collection_bonus` | float | 是 | 收藏加成 | `0.08` |
| `weather_hint` | string | 是 | 天气提示 | `clear` |
| `min_level` | int | 否 | 最低店铺等级，默认 1 | `1` |
| `required_flag` | string | 否 | 前置 flag | `` |

### 2.2 `data/festival_activities.csv`（活动表）

| 列名 | 类型 | 必填 | 说明 | 示例 |
|---|---|---|---|---|
| `activity_id` | string | 是 | **主键，全局唯一** | `act_balloon_release` |
| `event_id` | string | 是 | 外键 → `festival_events.event_id` | `pink_valentine` |
| `template_id` | string | 是 | `release`/`swap`/`write`/`pair`/`craft`/`riddle`/`watch`/`race` | `release` |
| `title` | string | 是 | 活动名 | `放气球` |
| `scene_id` | string | 是 | 单场景，**必须已存在** | `street` |
| `anchor_node` | string | 是 | 挂载到场景命名节点 | `DecorLayer` |
| `npc_id` | string | 是 | 活动 NPC | `lan` |
| `params` | string | 是 | **JSON 字符串**（CSV 内用双引号包裹） | `"{""count"":3,""color"":""pink""}"` |
| `fail_condition` | string | 是 | **真实失败条件** | `score<60` / `energy<5` / `item_missing` |
| `fail_line` | string | 是 | 失败台词 | `气球没抓住。` |
| `reward_money` | int | 否 | 成功奖励金 | `30` |
| `reward_energy` | int | 否 | 成功奖励体力 | `0` |
| `reward_item_id` | string | 否 | 成功奖励物品 | `` |
| `reward_affinity` | int | 否 | 成功奖励好感 | `2` |
| `score_max` | int | 否 | 比赛类活动满分，默认 100 | `100` |

### 2.3 `data/festival_decor.csv`（装饰层）

| 列名 | 类型 | 必填 | 说明 | 示例 |
|---|---|---|---|---|
| `decor_id` | string | 是 | 主键 | `decor_pink` |
| `scene_id` | string | 是 | **必须已存在** | `street` |
| `anchor_node` | string | 是 | 挂载节点名（**非硬编码坐标**） | `DecorLayer` |
| `offset_x` | int | 是 | 相对 anchor 的偏移 | `0` |
| `offset_y` | int | 是 | 相对 anchor 的偏移 | `-40` |
| `asset_key` | string | 是 | 美术资源 key | `decor_pink_balloon` |
| `z_index` | int | 是 | 统一 5 | `5` |
| `light_color` | string | 是 | 柔光色 | `#F5B8C4` |
| `light_energy` | float | 是 | 柔光强度 | `0.6` |

### 2.4 `data/goods.csv` 扩列

| 新增列 | 类型 | 说明 |
|---|---|---|
| `festival_tag` | string | 空=常驻；填 `event_id` 则仅该节日可见 |
| `available_from` | int | day_key 起，空=常驻 |
| `available_to` | int | day_key 止，空=常驻；`from > to` 视为跨年 |
| `recipe_id` | string | 指向 `recipes.csv`，空=不可制作 |

**新增节日商品（固定物价，独立定价）**：

| goods_id | name | base_cost | unit | category | festival_tag | recipe_id |
|---|---|---|---|---|---|---|
| `pink_candy` | 粉色糖果 | 3 | 份 | 甜点 | `pink_valentine` | `` |
| `heart_balloon` | 心形气球 | 5 | 个 | 杂货 | `pink_valentine` | `` |
| `rose_soda` | 玫瑰苏打 | 6 | 杯 | 饮品 | `pink_valentine` | `recipe_rose_soda` |
| `white_choco` | 白巧克力 | 4 | 份 | 甜点 | `white_valentine` | `` |
| `marshmallow_tea` | 棉花糖茶 | 5 | 杯 | 饮品 | `white_valentine` | `recipe_marshmallow_tea` |
| `dumpling_set` | 饺子套餐 | 12 | 份 | 主食 | `spring_festival` | `recipe_dumpling` |
| `nian_gao` | 年糕 | 6 | 份 | 主食 | `spring_festival` | `recipe_nian_gao` |
| `tangyuan` | 汤圆 | 5 | 份 | 甜点 | `lantern_festival` | `recipe_tangyuan` |
| `zongzi` | 粽子 | 6 | 个 | 主食 | `dragon_boat` | `recipe_zongzi` |
| `herbal_pouch` | 艾草香囊 | 8 | 个 | 杂货 | `dragon_boat` | `` |
| `star_cake` | 星星糕 | 5 | 份 | 甜点 | `qixi` | `recipe_star_cake` |
| `wish_strip` | 许愿条 | 2 | 条 | 杂货 | `qixi` | `` |
| `mooncake` | 月饼 | 8 | 个 | 甜点 | `mid_autumn` | `recipe_mooncake` |
| `pomelo` | 柚子 | 6 | 个 | 生鲜 | `mid_autumn` | `` |
| `gingerbread` | 姜饼人 | 5 | 个 | 甜点 | `christmas` | `recipe_gingerbread` |
| `hot_cocoa` | 热可可 | 5 | 杯 | 饮品 | `christmas` | `recipe_hot_cocoa` |

> **至少 3 个商品有 `recipe_id`**（`rose_soda`/`marshmallow_tea`/`dumpling_set`/`nian_gao`/`tangyuan`/`zongzi`/`star_cake`/`mooncake`/`gingerbread`/`hot_cocoa`），满足批判B X1。

### 2.5 `data/npcs.csv` 扩列（若 G0.6 未确认）

| 新增列 | 类型 | 说明 |
|---|---|---|
| `birthday` | int | 一年中第几天 |
| `birthday_line` | string | 生日台词 |
| `birthday_gift_id` | string | 生日礼物 id（**可接受节日商品**） |

---

## 3. 节日清单（按 G0.1 历法确认后重算）

> **以下 day_key 为占位，必须按 G0.1 实际历法重算**。假设 365 天历：

| day_key | event_id | title | type | scene_ids | npc_id | priority | 配对 |
|---|---|---|---|---|---|---|---|
| 1 | `spring_festival` | 岁首节 | traditional | `home;street;commercial_district` | `li_ma` | 20 | — |
| 15 | `lantern_festival` | 灯节 | traditional | `street;riverside` | `li_ma` | 15 | — |
| 95 | `dragon_boat` | 艾草节 | traditional | `street;riverside` | `qing_jie` | 15 | — |
| 178 | `pink_valentine` | 粉色情人节 | world | `street;commercial_district` | `lan` | 10 | `white_valentine` |
| 210 | `qixi` | 星河节 | traditional | `riverside;street` | `lan` | 15 | — |
| 225 | `mid_autumn` | 月圆节 | traditional | `home;street;riverside` | `li_ma` | 15 | — |
| 277 | `white_valentine` | 白色情人节 | world | `street;commercial_district` | `lan` | 10 | `pink_valentine` |
| 354 | `christmas` | 圣诞节 | world | `commercial_district;street` | `ji` | 10 | — |

> **8 个节日**，每个至少 2 类活动（见 §4）。**删除主方案的 20 节日清单**（批判A A1/A2 行数矛盾）。

---

## 4. 活动清单（每节日至少 2 类，含真实失败条件）

| activity_id | event_id | template_id | title | scene_id | npc_id | fail_condition | 奖励 |
|---|---|---|---|---|---|---|---|
| `act_dumpling_table` | `spring_festival` | `craft` | 包饺子 | `home` | `li_ma` | `item_missing` | 40元+5体力+好感3 |
| `act_lantern_riddle_spring` | `spring_festival` | `riddle` | 猜灯谜 | `street` | `li_ma` | `score<60` | 35元+好感2 |
| `act_lantern_riddle_lantern` | `lantern_festival` | `riddle` | 猜灯谜 | `street` | `li_ma` | `score<60` | 30元+好感2 |
| `act_river_lantern` | `lantern_festival` | `release` | 放河灯 | `riverside` | `li_ma` | `energy<5` | 25元+好感2 |
| `act_zongzi_wrap` | `dragon_boat` | `craft` | 包粽子 | `riverside` | `qing_jie` | `item_missing` | 35元+5体力+好感3 |
| `act_river_watch` | `dragon_boat` | `watch` | 看龙舟 | `riverside` | `qing_jie` | `energy<5` | 20元+好感2 |
| `act_balloon_release` | `pink_valentine` | `release` | 放气球 | `street` | `lan` | `energy<5` | 30元+好感2 |
| `act_sweet_swap` | `pink_valentine` | `swap` | 交换甜食 | `commercial_district` | `lan` | `item_missing` | 20元+好感3 |
| `act_star_gazing` | `qixi` | `watch` | 看星星 | `riverside` | `lan` | `energy<5` | 25元+好感3 |
| `act_wish_wall` | `qixi` | `write` | 许愿墙 | `street` | `lan` | `item_missing` | 20元+好感2 |
| `act_mooncake_share` | `mid_autumn` | `craft` | 分月饼 | `home` | `li_ma` | `item_missing` | 40元+5体力+好感3 |
| `act_moon_watch` | `mid_autumn` | `watch` | 赏月 | `riverside` | `li_ma` | `energy<5` | 25元+好感2 |
| `act_letter_wall` | `white_valentine` | `write` | 写信墙 | `street` | `lan` | `item_missing` | 20元+好感2 |
| `act_tea_pairing` | `white_valentine` | `pair` | 茶点搭配 | `commercial_district` | `lan` | `score<60` | 25元+好感3 |
| `act_gift_exchange` | `christmas` | `swap` | 交换礼物 | `commercial_district` | `ji` | `item_missing` | 30元+好感3 |
| `act_carol_corner` | `christmas` | `watch` | 听唱诗 | `commercial_district` | `ji` | `energy<5` | 25元+好感2 |

**真实失败条件**（回应批判B C8）：
- `score<60`：谜题/比赛类，得分低于 60 分。
- `energy<5`：体力不足。
- `item_missing`：所需物品不在背包。

**失败回落**：显示 `fail_line` + 发放 `fallback_reward`（温柔，不惩罚）。

---

## 5. 触发条件与奖励（逐节日，以粉色情人节为例）

### 5.1 粉色情人节（day 178）

**触发**：
```
CalendarManager.calendar_day_started(day_of_year, year)
  → FestivalManager._on_day_started
    → 查 festival_events by day_key=178
    → 若多行：按 priority 降序取最高
    → active_event_id = "pink_valentine"
    → 键 = "pink_valentine_%d" % year
    → 若 notified 无此键：
        → NoticeManager.show_npc_message(line, speaker)
        → FestivalDecorLayer.apply("decor_pink")
        → GoodsRegistry.register_festival_goods(["pink_candy","heart_balloon","rose_soda"])
        → FestivalActivityRegistry.register(["act_balloon_release","act_sweet_swap"])
        → notified[键] = true
        → SaveManager.request_auto_save("festival")
```

**预热**：day 177（`preheat_days=1`）显示 `preheat_line`。
**余韵**：day 179（`afterglow_days=1`）显示 `afterglow_line`。

**活动 1 `act_balloon_release`**：
- 点击 `street` 场景 `DecorLayer` 下的气球实体。
- `template_id=release`，`params={"count":3,"color":"pink"}`。
- 失败条件：`energy<5` → `fail_line`："气球没抓住，但风很舒服。" + `money:10`。
- 成功：`money:30` + `affinity[lan]+2`。

**活动 2 `act_sweet_swap`**：
- 点击 `commercial_district` 的甜食摊。
- `template_id=swap`，`params={"partner":"random","item":"pink_candy"}`。
- 失败条件：`item_missing`（背包无 `pink_candy`）→ `fail_line`："你摸了摸口袋，什么也没带。" + `money:5`。
- 成功：`money:20` + `affinity[lan]+3`。

**经营关联**：
- `business_bonus=0.16`，**覆盖** `calendar.csv` 的值（不叠加）。
- `rose_soda` 有 `recipe_id=recipe_rose_soda`，走 `KitchenManager` 正常下单。

**NPC 生日关联**：
- 若 `lan.birthday == 178` → 触发 `birthday_festival_combo`，额外 `affinity[lan]+3` + `reward_item_id` ×2。
- 节日纪念品 `pink_ribbon` 可作为 `lan.birthday_gift_id`。

**补过机制**：
- day 179–181（节后 3 天）`pink_candy` 仍可购买，但无活动。
- 白色情人节（day 277）可补过粉色情人节：若 `claimed` 无 `pink_valentine_{year}`，走 `fallback_line`。

**失败回落**：
- 真实失败（体力不足/物品缺失）→ `fail_line` + `fallback_reward`。
- 错过（当天未参与）→ `missed_line` + 无奖励。

### 5.2 其余节日

按 §4 活动表逐条实现，每个节日：
- 至少 2 个活动（1 主 + 1 副）。
- 至少 1 个真实失败条件。
- 至少 1 个商品有 `recipe_id`。
- 预热/余韵台词。
- 生日 combo（若 `birthday_npc_id` 非空）。

---

## 6. 存档兼容与迁移

### 6.1 新增存档字段

```gdscript
# FestivalManager
var claimed: Dictionary = {}           # "{event_id}_{year}" -> true
var activities_done: Dictionary = {}   # "{activity_id}_{year}" -> true
var notified: Dictionary = {}          # "{event_id}_{year}" -> true
var birthday_combo_done: Dictionary = {}  # "{npc_id}_{year}" -> true
var active_event_id: String = ""
var active_year: int = 0
```

### 6.2 迁移策略

- 旧档读入时，上述字段为空字典 → 默认未完成，**不报错**。
- `festival_events.csv` / `festival_activities.csv` 新增列全部有默认值。
- `goods.csv` 新增 `festival_tag` 列，旧档货架过滤时若列为空 → 视为常驻，**不隐藏**。
- **防重复领取**：`join_activity()` 先查 `activities_done["{activity_id}_{year}"]`，已存在则返回 `{"ok": false, "reason": "already_done"}`。

### 6.3 跨年规则

- `current_year` 变化时，旧键（含旧年份）自然失效。
- **不主动清空** `claimed` / `activities_done` / `notified`，靠键含年份实现重置。
- 测试：第 1 年 day 178 参加 → 第 2 年 day 178 应可再次参加。

### 6.4 节日中途存档

- 存档时写 `active_event_id` + `active_year`。
- 读档时校验：若 `active_year != current_year` 或 `day_of_year > active_event.day_key + afterglow_days` → 清 `active_event_id` + 撤装饰 + 下架商品。
- 测试：day 178 存档 → day 179 读档 → 断言 `active_event_id` 为空、`DecorLayer` 无 `decor_pink`、货架无 `pink_candy`。

---

## 7. 执行步骤（按顺序）

| # | 步骤 | 文件 | 验证 |
|---|---|---|---|
| 1 | 跑 G0.1–G0.9 门禁，写 `docs/FESTIVAL_FACTS.md` | — | 9 条命令全部有确定输出 |
| 2 | 按 G0.1 重算所有 day_key | `docs/FESTIVAL_FACTS.md` | 6/27→178，10/4→277（365 天历） |
| 3 | 新建 `data/festival_events.csv`（8 行） | `data/festival_events.csv` | `head -1` 列名正确 |
| 4 | 新建 `data/festival_activities.csv`（16 行） | `data/festival_activities.csv` | `activity_id` 唯一 |
| 5 | 新建 `data/festival_decor.csv` | `data/festival_decor.csv` | `anchor_node` 存在 |
| 6 | 扩列 `data/goods.csv` 加 `festival_tag`/`available_from`/`available_to`/`recipe_id` | `data/goods.csv` | 新增 16 行节日商品 |
| 7 | 扩列 `data/npcs.csv` 加 `birthday`/`birthday_line`/`birthday_gift_id`（若 G0.6 未确认） | `data/npcs.csv` | 8 位 NPC 生日非空 |
| 8 | 扩 `FestivalManager` 读新表 + 新键结构 | `autoload/festival_manager.gd` | `get_event_for_day` / `join_activity` |
| 9 | 扩 `CalendarManager` 读 `festival_events` 覆盖 `calendar` | `autoload/calendar_manager.gd` | `get_business_bonus` 优先取 festival_events |
| 10 | 新建 `FestivalDecorLayer` | `scripts/festival_decor_layer.gd` | 场景加载时注入，重载时清空 |
| 11 | 新建 `FestivalActivityTemplate`（8 种模板） | `scripts/festival_activity_template.gd` | 参数解析失败不生成实体 |
| 12 | 扩 `GoodsRegistry` 合并节日商品 | `autoload/goods_registry.gd` | 非节日日不显示 `pink_candy` |
| 13 | 生日 combo 逻辑 | `autoload/festival_manager.gd` | 生日+节日同日触发额外奖励 |
| 14 | 存档迁移 + 跨年 + 中途存档 | `autoload/save_manager.gd` | 旧档读入不报错 |
| 15 | 测试 | `tools/test_festival.gd` | 见 §8 |

---

## 8. 验证清单

### 8.1 单元验证

```gdscript
# tools/test_festival.gd
func test_all_festivals() -> void:
    var csv_rows := ConfigDB.get_rows("festival_events")
    var test_days := [1, 15, 95, 178, 210, 225, 277, 354]
    assert(csv_rows.size() == test_days.size(), "CSV 行数与测试天数不一致")
    for day in test_days:
        TimeSystem.current_day = day
