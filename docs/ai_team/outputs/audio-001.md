# 温柔治愈音频方向与批量资产方案

## 主方案

# 《深城日常》温柔治愈音频方向与批量资产方案（唯一可执行版）

> 主方案 Agent 终裁。以现有 `autoload/audio_manager.gd` + `data/scene_metadata.csv` + `assets/audio/` 三处**已存在事实**为唯一基线，不发明新 Manager、不发明新目录、不发明新 key 命名法。
> 硬约束：温柔治愈、低饱和暖色听觉对应、拒绝压抑工业噪声与赛博霓虹感、无任务面板、无数值属性条、存档兼容。
> 本方案所有"新增"均落在**现有接口可承载**的范围内：`play_music(track_id)` / `play_sfx(sfx_id)` / `get_resolved_audio_path(audio_id)` / `scene_metadata.csv` 的 `music_key`+`ambient_key` 两列。

---

## 0. 前置门禁（阻塞性，未通过不得生成任何音频）

所有命令输出写入 `docs/AUDIO_FACTS.md`，作为本方案唯一事实源。**禁止在方案里出现"若存在则"**——门禁跑完必须给出确定值。

### G0.1 现有音频真实格式与时长
```bash
python -c "import wave,glob; [print(p, wave.open(p).getnchannels(), wave.open(p).getframerate(), wave.open(p).getnframes()/wave.open(p).getframerate()) for p in glob.glob('assets/audio/*.wav')]"
```
**裁决规则**：
- 记录每个 wav 的**声道数 / 采样率 / 时长**。本方案所有新资产必须与**多数派**一致。
- 若多数为 `1ch / 22050Hz` → 新资产统一 `1ch / 22050Hz / 16bit PCM`。
- 若多数为 `2ch / 44100Hz` → 新资产统一 `2ch / 44100Hz / 16bit PCM`。
- 时长：环境音（`*_ambient`）必须 ≥ 20s 且可无缝循环；SFX 必须 ≤ 1.2s。

### G0.2 `ambient_key` 是否被消费（关键裁决）
```bash
grep -rn "ambient_key\|get_scene_ambient\|ambient" --include=*.gd autoload/ scripts/ | grep -v "audio_manager.gd"
```
**裁决**：
- 若 `ambient_key` **无任何消费方** → 本方案**不新增环境音播放通道**，环境音通过 `music_key` 承载（现有 `_refresh_ambient_track` 已按 `music_key` 播放）。`ambient_key` 列保留为**未来预留**，本批不生成对应文件。
- 若 `ambient_key` 有消费方 → 记录消费点，按其接口生成。
- **本方案默认走"无消费方"分支**（现有 `audio_manager.gd` 全文只读 `music_key`，未见 `ambient_key` 读取）。

### G0.3 `PresentationManager.get_scene_music_key` 实现
```bash
grep -n "func get_scene_music_key" -A 15 autoload/presentation_manager.gd
```
**裁决**：确认它读的是 `scene_metadata.csv` 的 `music_key` 列还是硬编码字典。若硬编码 → 本方案第一步是**改为读 CSV**，否则新增场景音乐 key 无法生效。

### G0.4 现有 SFX 触发点清单
```bash
grep -rn "play_sfx(" --include=*.gd autoload/ scripts/ | sort -u
```
**裁决**：列出所有已调用的 `sfx_id`。本方案新增 SFX 必须**不与现有 id 冲突**，且优先复用现有 id（`pickup` / `coin` / `soft_confirm` / `soft_warning` / `door_open` / `serve_bell` / `ui_open` / `ui_close`）。

### G0.5 音频总线配置
```bash
grep -n "bus\|Master\|Music\|SFX" project.godot | head -20
```
**裁决**：现有代码 `_music_player.bus = "Master"` / `_sfx_player.bus = "Master"`。若 `project.godot` 无独立 `Music`/`SFX` 总线 → **本批不新增总线**（避免改动 `SettingsManager` 音量链路），仅靠 `volume_db` 区分。

---

## 1. 决策（先拍板，无歧义）

| # | 争议点 | 最终裁决 | 依据 |
|---|---|---|---|
| D1 | 环境音通道 | **复用 `music_key` 单通道**，不新增 `ambient_key` 播放器 | G0.2；现有 `_refresh_ambient_track` 已按 `music_key` 播放 |
| D2 | 音乐 vs 环境音 | **同一通道，按场景切换**。`music_key` 值以 `*_ambient` 结尾者为环境音，以 `*_theme` 结尾者为短音乐 | 现有 CSV 全部用 `*_ambient`，保持命名一致 |
| D3 | 短音乐触发 | **不新增触发点**。短音乐仅在 `festival_ambient` 与 `menu_ambient` 两处使用（现有代码已支持） | 避免引入未验证的 `play_music` 调用 |
| D4 | 工业区音色 | **禁止机械轰鸣、金属撞击、电流嗡鸣**。工厂环境音 = 远处规律轻响 + 人声低语 + 通风柔风 | 硬约束"拒绝压抑工业噪声" |
| D5 | 赛博霓虹感 | **禁止合成器 pad、sidechain 泵感、高频 shimmer、失真 bass**。夜市/商业区用木质打击 + 人声 + 暖弦 | 硬约束"拒绝赛博霓虹感" |
| D6 | 生成方式 | **程序化合成优先**（`tools/generate_audio.py`），采购为备选。理由：可复现、无版权风险、与 `generate_pixel_art.py` 同构 | 现有项目已有程序化资产生成先例 |
| D7 | 命名 | **严格沿用现有 `snake_case` + `_ambient`/`_sfx` 后缀**。SFX 不加 `_sfx` 后缀（现有 `pickup`/`coin` 无后缀） | 与 `get_resolved_audio_path` 拼接规则一致 |
| D8 | 覆盖路径 | **正式资源放 `assets/audio/formal/`**，与美术 `assets/art/formal/` 同构 | `get_resolved_audio_path` 已优先读 `formal/` |
| D9 | 循环 | 环境音 `AudioStreamWAV.LOOP_FORWARD`（现有代码已设）；SFX 不循环 | 现有 `play_music` 已实现 |
| D10 | 音量 | **不新增音量参数**。环境音 `-8dB`、SFX `-4dB`（现有默认值），由 `SettingsManager.master_volume` 统一调制 | 现有 `_apply_volume` 已实现 |

---

## 2. 八场景音频方向（温柔治愈 + 生活质感）

> 每场景给出：**听觉意象 / 禁止项 / 主色对应（低饱和暖色）/ 时长 / 循环点**

### 2.1 城中村（`street` / `home` / `night_market`）

| 维度 | 内容 |
|---|---|
| 听觉意象 | 远处自行车铃、晾衣绳轻晃、邻居收音机漏音（戏曲/评书，音量极低）、猫叫、拖鞋踩水泥地、夜市的木勺碰碗 |
| 禁止项 | 汽车喇叭、施工电钻、警笛、电子广告屏 |
| 主色对应 | `#d8a75c` 暖橙 → 音色偏**中频木质**，无高频刺点 |
| 时长 | 24s 循环 |
| 循环点 | 第 8s 与第 16s 各有一个"自行车铃"事件，循环时错开 |

### 2.2 早餐店（`breakfast_shop` / `breakfast_kitchen`）

| 维度 | 内容 |
|---|---|
| 听觉意象 | 蒸笼揭盖的"噗"、油条下锅的细密"滋"、瓷碗轻碰、老板娘招呼声（低音量、听不清词）、豆浆机低频嗡（柔化） |
| 禁止项 | 抽油烟机轰鸣、金属锅铲刮铁、高压锅尖叫 |
| 主色对应 | `#e8c26a` 暖黄 → 音色偏**中低频饱满**，高频衰减 |
| 时长 | 20s 循环 |
| 循环点 | 第 5s 蒸笼、第 12s 碗碰、第 18s 招呼声 |

### 2.3 工厂（`factory` / `industrial_district`）

| 维度 | 内容 |
|---|---|
| 听觉意象 | **远处**规律轻响（每 2s 一次，音量 -24dB）、通风口柔风、工人低语（听不清词）、传送带橡胶摩擦（柔化） |
| 禁止项 | 冲压机、气锤、金属撞击、电流嗡鸣、警报 |
| 主色对应 | `#8fc6bf` 雾青 → 音色偏**中频柔和**，无低频压迫 |
| 时长 | 28s 循环 |
| 循环点 | 每 2s 一次轻响，循环点设在两次轻响之间 |

### 2.4 河畔（`riverside` / `seaside_resort`）

| 维度 | 内容 |
|---|---|
| 听觉意象 | 水波轻拍、芦苇沙沙、远处渡轮汽笛（极低音量、单次）、水鸟、风吹衣角 |
| 禁止项 | 快艇、马达、码头机械 |
| 主色对应 | `#6faa8d` 水绿 → 音色偏**宽频柔和**，高频有空气感 |
| 时长 | 32s 循环 |
| 循环点 | 第 10s 水鸟、第 22s 汽笛（单次，循环时错开） |

### 2.5 农田（`farm` / `farm_livestock` / `suburb`）

| 维度 | 内容 |
|---|---|
| 听觉意象 | 风吹麦浪、鸡叫、远处牛铃、锄头入土、溪水细流 |
| 禁止项 | 拖拉机、收割机、农药喷洒 |
| 主色对应 | `#7fae7a` 草绿 → 音色偏**中频自然**，无电子感 |
| 时长 | 30s 循环 |
| 循环点 | 第 6s 鸡叫、第 15s 牛铃、第 24s 锄头 |

### 2.6 宠物（`pet_store`）

| 维度 | 内容 |
|---|---|
| 听觉意象 | 猫呼噜、小狗轻喘、爪子踩木地板、铃铛项圈轻响、鸟笼细鸣 |
| 禁止项 | 犬吠连叫、猫尖叫、笼子金属碰撞 |
| 主色对应 | `#d99a8f` 暖粉 → 音色偏**中高频柔和**，无刺点 |
| 时长 | 22s 循环 |
| 循环点 | 第 4s 呼噜、第 11s 爪步、第 18s 铃铛 |

### 2.7 节日（`festival_ambient`，跨场景复用）

| 维度 | 内容 |
|---|---|
| 听觉意象 | 远处锣鼓（柔化、低音量）、人群笑语（听不清词）、灯笼纸摩擦、糖画勺碰锅、鞭炮**远景**（单次、极低音量） |
| 禁止项 | 近景鞭炮、电子鞭炮、扩音喇叭 |
| 主色对应 | `#e8b45e` 暖金 → 音色偏**中频木质 + 人声** |
| 时长 | 26s 循环 |
| 循环点 | 第 7s 锣鼓、第 14s 笑语、第 21s 糖画 |

### 2.8 家庭（`home` / `home_living`）

| 维度 | 内容 |
|---|---|
| 听觉意象 | 挂钟秒针、水壶将沸未沸的细响、翻书页、窗外远处车流（极低）、木地板轻响 |
| 禁止项 | 电视广告、手机通知、空调外机 |
| 主色对应 | `#d98a83` 暖粉 → 音色偏**中低频温暖** |
| 时长 | 36s 循环（最长，营造"待得住"感） |
| 循环点 | 第 12s 翻书、第 24s 水壶、第 30s 地板 |

---

## 3. 资产清单（唯一事实源）

### 3.1 环境音（`music_key` 承载，`*_ambient` 后缀）

| # | audio_id | 场景 | 时长 | 声道 | 采样率 | 状态 |
|---|---|---|---|---|---|---|
| A01 | `street_ambient` | 城中村主街 | 24s | 按 G0.1 | 按 G0.1 | **已有，需重制** |
| A02 | `home_ambient` | 出租屋 | 36s | 同上 | 同上 | **已有，需重制** |
| A03 | `night_market_ambient` | 夜市 | 24s | 同上 | 同上 | **已有，需重制** |
| A04 | `breakfast_ambient` | 早餐店前厅 | 20s | 同上 | 同上 | **已有，需重制** |
| A05 | `kitchen_ambient` | 早餐店后厨 | 20s | 同上 | 同上 | **已有，需重制** |
| A06 | `industrial_ambient` | 工业区/工厂 | 28s | 同上 | 同上 | **已有，需重制** |
| A07 | `riverside_ambient` | 河畔 | 32s | 同上 | 同上 | **已有，需重制** |
| A08 | `farm_ambient` | 农田/城郊 | 30s | 同上 | 同上 | **已有，需重制** |
| A09 | `livestock_ambient` | 农场圈舍 | 30s | 同上 | 同上 | **已有，需重制** |
| A10 | `store_ambient` | 便利店/宠物店 | 22s | 同上 | 同上 | **已有，需重制** |
| A11 | `festival_ambient` | 节日（跨场景） | 26s | 同上 | 同上 | **已有，需重制** |
| A12 | `commercial_ambient` | 商业区 | 26s | 同上 | 同上 | **已有，需重制** |
| A13 | `market_ambient` | 旧货市场 | 24s | 同上 | 同上 | **已有，需重制** |
| A14 | `park_ambient` | 社区公园 | 28s | 同上 | 同上 | **已有，需重制** |
| A15 | `restaurant_ambient` | 餐馆 | 22s | 同上 | 同上 | **已有，需重制** |
| A16 | `workshop_ambient` | 手艺工坊 | 24s | 同上 | 同上 | **已有，需重制** |
| A17 | `university_ambient` | 夜校/大学 | 26s | 同上 | 同上 | **已有，需重制** |
| A18 | `clinic_ambient` | 诊所 | 24s | 同上 | 同上 | **已有，需重制** |
| A19 | `travel_ambient` | 巴士站/海边/古镇/温泉 | 28s | 同上 | 同上 | **已有，需重制** |
| A20 | `high_end_ambient` | 高端住宅区 | 26s | 同上 | 同上 | **已有，需重制** |
| A21 | `ruins_ambient` | 旧址深处 | 24s | 同上 | 同上 | **已有，需重制** |
| A22 | `day_ambient` | 默认白天 | 30s | 同上 | 同上 | **已有，需重制** |
| A23 | `night_ambient` | 默认夜晚 | 30s | 同上 | 同上 | **已有，需重制** |
| A24 | `rain_ambient` | 雨天 | 28s | 同上 | 同上 | **已有，需重制** |
| A25 | `menu_ambient` | 主菜单 | 32s | 同上 | 同上 | **已有，需重制** |

**结论**：现有 25 个环境音**全部保留 id**，本批任务是**重制音色**（去工业噪声、去霓虹感），**不新增 id**。

### 3.2 交互音（SFX，无后缀）

| # | sfx_id | 触发点 | 时长 | 音色方向 | 状态 |
|---|---|---|---|---|---|
| S01 | `pickup` | 拾取普通物品 | ≤0.4s | 木质轻碰 + 高频柔化 | **已有，需重制** |
| S02 | `legendary_pickup` | 拾取稀有物品 | ≤0.8s | 木质 + 风铃（无 shimmer） | **已有，需重制** |
| S03 | `coin` | 金钱变化 | ≤0.3s | 瓷碗轻碰（非金属） | **已有，需重制** |
| S04 | `soft_confirm` | 正向提示 | ≤0.5s | 木琴单音（C5） | **已有，需重制** |
| S05 | `soft_warning` | 警告提示 | ≤0.5s | 木琴单音（A4，柔和） | **已有，需重制** |
| S06 | `door_open` | 场景切换 | ≤0.6s | 木门轴轻响 | **已有，需重制** |
| S07 | `serve_bell` | 出餐 | ≤0.5s | 瓷铃（非金属铃） | **已有，需重制** |
| S08 | `ui_open` | 打开 UI | ≤0.3s | 纸页翻动 | **已有，需重制** |
| S09 | `ui_close` | 关闭 UI | ≤0.3s | 纸页合上 | **已有，需重制** |
| S10 | `plant_seed` | 播种 | ≤0.4s | 土块轻落 | **新增** |
| S11 | `water_plant` | 浇水 | ≤0.6s | 水壶细流 | **新增** |
| S12 | `harvest` | 收获 | ≤0.5s | 果实入篮 | **新增** |
| S13 | `pet_interact` | 摸宠物 | ≤0.5s | 呼噜短句 | **新增** |
| S14 | `feed_pet` | 喂宠物 | ≤0.5s | 碗碰 + 轻嚼 | **新增** |
| S15 | `craft_start` | 开始手艺 | ≤0.6s | 工具轻放 | **新增** |
| S16 | `craft_done` | 完成手艺 | ≤0.8s | 木器轻敲 | **新增** |
| S17 | `order_place` | 点餐 | ≤0.4s | 木牌轻放 | **新增** |
| S18 | `order_serve` | 上菜 | ≤0.5s | 瓷盘轻放 | **新增** |
| S19 | `festival_gong` | 节日开始 | ≤1.0s | 远处锣（柔化） | **新增** |
| S20 | `home_clock` | 家庭场景整点 | ≤0.4s | 挂钟单响 | **新增** |

**结论**：现有 9 个 SFX 保留 id 重制，新增 11 个 SFX。**新增 id 必须先在 G0.4 确认无冲突**。

### 3.3 短音乐（`*_theme` 后缀，仅 2 处）

| # | audio_id | 触发点 | 时长 | 音色方向 | 状态 |
|---|---|---|---|---|---|
| M01 | `festival_theme` | 节日开始（替换 `festival_ambient` 前 8s） | 8s | 木琴 + 笛 + 轻鼓 | **新增** |
| M02 | `menu_theme` | 主菜单（替换 `menu_ambient` 前 12s） | 12s | 钢琴 + 弦乐 pad（无 sidechain） | **新增** |

**裁决**：短音乐**不新增触发点**。`festival_theme` 由 `_on_festival_started` 调用 `play_music("festival_theme")`，8s 后由 `_refresh_ambient_track` 切回 `festival_ambient`。`menu_theme` 由主菜单 `_ready` 调用。

---

## 4. 生成方式（程序化合成优先）

### 4.1 新建 `tools/generate_audio.py`

**职责**：用 Python 标准库 `wave` + `numpy`（若可用）或纯 `struct` 合成所有 25 环境音 + 20 SFX + 2 短音乐。

**核心函数签名**：
```python
def synth_ambient(spec: dict) -> bytes:
    """spec = {duration, layers: [{type, freq, amp, mod}], loop_point}"""

def synth_sfx(spec: dict) -> bytes:
    """spec = {duration, envelope: {attack, decay, sustain, release}, partials: [...]}"""

def write_wav(path: str, data: bytes, channels: int, rate: int) -> None:
    """按 G0.1 裁决的格式写入"""
```

**合成规则（硬约束）**：
- **禁止**：`sawtooth` 波形（霓虹感）、`square` 波形（8-bit 感）、`white_noise` 直接输出（工业感）、`FM` 调制指数 > 2（金属感）。
- **允许**：`sine`、`triangle`、`pink_noise`（经 1kHz 低通）、`brown_noise`（经 500Hz 低通）。
- **包络**：所有 SFX 必须 `attack ≥ 5ms`、`release ≥ 50ms`，禁止硬切。
- **环境音**：必须由 ≥ 3 层叠加，每层独立 LFO 调制（频率 0.1–0.5Hz），避免"死循环"感。

### 4.2 采购备选（仅当程序化无法达标时）

| 来源 | 许可 | 适用 | 禁止 |
|---|---|---|---|
| Freesound.org | CC0 / CC-BY | 环境音底噪 | 需逐条听检，剔除工业/霓虹 |
| Pixabay Audio | Pixabay License | SFX | 同上 |
| 自制录音 | 自有 | 生活质感 | 需消音处理 |

**采购流程**：下载 → 听检（对照 §2 禁止项）→ 重采样至 G0.1 格式 → 放入 `assets/audio/formal/` → 在 `docs/AUDIO_FACTS.md` 记录来源与许可。

### 4.3 构建集成

在 `tools/build.py`（或现有构建脚本）中，**在 Godot 资源导入前**插入：
```python
subprocess.run([sys.executable, "tools/generate_audio.py"], check=True)
```
与 `generate_pixel_art.py` 同构。

---

## 5. 命名与接入路径

### 5.1 命名规范（唯一事实源）

| 类型 | 模式 | 示例 | 禁止 |
|---|---|---|---|
| 环境音 | `<scene>_ambient` | `street_ambient` | `street_amb`、`StreetAmbient` |
| 短音乐 | `<scene>_theme` | `festival_theme` | `festival_music` |
| SFX | `<verb>_<noun>` 或 `<noun>` | `pickup`、`plant_seed` | `sfx_pickup`、`pickup_sfx` |
| 覆盖 | `assets/audio/formal/<id>.wav` | `assets/audio/formal/street_ambient.wav` | 改文件名 |

### 5.2 接入路径（三层）

**Layer 1 — 数据层**：`data/scene_metadata.csv` 的 `music_key` 列
- 现有 34 行**全部保留**，仅当场景音色需区分时**新增行**（如 `pet_store` 已有，无需新增）。
- **不新增 `ambient_key` 消费方**（G0.2 裁决）。

**Layer 2 — 代码层**：`autoload/audio_manager.gd`
- **不修改** `play_music` / `play_sfx` / `get_resolved_audio_path` 签名。
- **新增** `_on_festival_started` 中 8s 后切回逻辑：
```gdscript
func _on_festival_started(_day_key: String, _event_id: String) -> void:
    play_music("festival_theme")
    await get_tree().create_timer(8.0).timeout
    _refresh_ambient_track()
```
- **新增** SFX 触发点（在对应业务代码中调用 `AudioManager.play_sfx("plant_seed")` 等）。

**Layer 3 — 资产层**：`assets/audio/formal/`
- 正式资源放此目录，`get_resolved_audio_path` 自动优先读取。
- 基线资源保留在 `assets/audio/`，作为 fallback。

### 5.3 新增 SFX 触发点清单（唯一事实源）

| sfx_id | 触发文件 | 触发函数 | 触发条件 |
|---|---|---|---|
| `plant_seed` | `autoload/farm_manager.gd` | `plant()` | 播种成功 |
| `water_plant` | `autoload/farm_manager.gd` | `water()` | 浇水成功 |
| `harvest` | `autoload/farm_manager.gd` | `harvest()` | 收获成功 |
| `pet_interact` | `scripts/gameplay/pet_interactable.gd` | `on_tap()` | 摸宠物 |
| `feed_pet` | `scripts/gameplay/pet_interactable.gd` | `on_tap()` | 喂食 |
| `craft_start` | `autoload/craft_manager.gd` | `start_craft()` | 开始手艺 |
| `craft_done` | `autoload/craft_manager.gd` | `_on_craft_complete()` | 完成手艺 |
| `order_place` | `autoload/kitchen_manager.gd` | `place_order()` | 点餐 |
| `order_serve` | `autoload/kitchen_manager.gd` | `serve_order()` | 上菜 |
| `festival_gong` | `autoload/festival_manager.gd` | `_on_festival_started()` | 节日开始 |
| `home_clock` | `autoload/time_system.gd` | `_on_hour_changed()` | 家庭场景整点 |

**风险**：若上述文件/函数不存在（如 `craft_manager.gd`），**该 SFX 触发点降级为 P2**，不阻塞本批音频生成。

---

## 6. 验收标准（可证伪断言）

### 6.1 格式验收（CI 门禁）

```bash
python tools/verify_audio.py
```

**断言**：
- A1：`assets/audio/formal/` 下所有 `.wav` 的声道数 == G0.1 裁决值。
- A2：所有 `.wav` 的采样率 == G0.1 裁决值。
- A3：所有 `*_ambient.wav` 时长 ≥ 20s。
- A4：所有 SFX 时长 ≤ 1.2s。
- A5：所有 `.wav` 无削波（峰值 ≤ -1dBFS）。
- A6：所有 `*_ambient.wav` 首尾 100ms 能量差 ≤ 3dB（可循环）。
- A7：所有 SFX 的 `attack ≥ 5ms`（无硬切）。
- A8：所有 `.wav` 频谱在 8kHz 以上能量占比 ≤ 5%（无高频刺点）。
- A9：所有 `.wav` 频谱在 60Hz 以下能量占比 ≤ 10%（无低频压迫）。
- A10：`assets/audio/formal/` 下每个文件在 `data/scene_metadata.csv` 或 §3.2/§3.3 清单中有对应 id。

### 6.2 听感验收（人工，双盲）

**流程**：3 名未参与制作的人员，随机播放 25 环境音 + 20 SFX，按 §2 禁止项打分。

**断言**：
- B1：工业区环境音**无人**判定为"压抑/机械/工业"。
- B2：夜市/商业区环境音**无人**判定为"赛博/霓虹/电子"。
- B3：所有环境音**无人**判定为"冷清/空旷/恐怖"。
- B4：所有 SFX**无人**判定为"刺耳/突兀"。
- B5：早餐店/家庭环境音**≥ 2 人**判定为"温暖/生活感"。

### 6.3 集成验收（Godot 运行时）

```bash
godot --headless --scene-check
```

**断言**：
- C1：进入每个场景，`AudioManager.get_current_track_id()` 返回 `scene_metadata.csv` 中该场景的 `music_key`。
- C2：切换场景无爆音（`_music_player` 切换时无 `pop`）。
- C3：`--smoke-test` 下 `_audio_disabled == true`，无音频播放。
- C4：`SettingsManager.master_volume = 0` 时，`_music_player.volume_db == -24.0`。
- C5：节日开始 8s 后，`get_current_track_id()` 从 `festival_theme` 切回 `festival_ambient`。

### 6.4 存档兼容验收

**断言**：
- D1：存档中无音频相关字段（音频是纯表现层，不入档）。
- D2：读档后 `_refresh_ambient_track` 按当前场景正确播放。

---

## 7. 执行步骤（按顺序）

| # | 步骤 | 产出 | 验证 |
|---|---|---|---|
| 1 | 跑 G0.1–G0.5 门禁 | `docs/AUDIO_FACTS.md` | 5 条命令输出齐全 |
| 2 | 写 `tools/generate_audio.py` | 脚本 | `python tools/generate_audio.py --dry-run` 无报错 |
| 3 | 生成 25 环境音 | `assets/audio/formal/*_ambient.wav` | §6.1 A1–A10 通过 |
| 4 | 生成 20 SFX | `assets/audio/formal/*.wav` | 同上 |
| 5 | 生成 2 短音乐 | `assets/audio/formal/*_theme.wav` | 同上 |
| 6 | 听感验收 | `docs/AUDIO_REVIEW.md` | §6.2 B1–B5 通过 |
| 7 | 接入 `audio_manager.gd` | 节日切回逻辑 | §6.3 C5 通过 |
| 8 | 接入 SFX 触发点 | 11 处调用 | §6.3 C1–C4 通过 |
| 9 | 构建集成 | `tools/build.py` 更新 | 全量构建通过 |
| 10 | 存档兼容测试 | 无字段变更 | §6.4 D1–D2 通过 |

---

## 8. 风险与缓解

| # | 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|---|
| R1 | `ambient_key` 实际有消费方（G0.2 裁决错误） | 中 | 高 | 门禁 G0.2 必须先跑；若有消费方，本方案 §5.2 改为双通道 |
| R2 | 程序化合成无法达到"生活质感" | 中 | 中 | 采购备选（§4.2）；先做 3 个场景试点听感验收 |
| R3 | 新增 SFX 触发点文件不存在 | 高 | 低 | 降级 P2，不阻塞音频生成 |
| R4 | 环境音循环点不自然 | 中 | 中 | §6.1 A6 断言 + 人工听检 |
| R5 | 工业区音色仍被判定"压抑" | 中 | 高 | §6.2 B1 双盲验收；不通过则重制 |
| R6 | 音频文件体积过大 | 低 | 中 | 22050Hz 单声道 24s ≈ 1MB；25 个 ≈ 25MB，可接受 |
| R7 | `festival_theme` 8s 切回逻辑与现有 `_refresh_ambient_track` 冲突 | 中 | 中 | 用 `await` + 检查 `FestivalManager.active_event_id` 是否仍有效 |
| R8 | `SettingsManager.master_volume` 链路变更 | 低 | 高 | 本方案不改 `_apply_volume`，仅新增 SFX id |

---

## 9. 交付物清单

| # | 文件 | 类型 | 说明 |
|---|---|---|---|
| 1 | `docs/AUDIO_FACTS.md` | 文档 | 门禁结果，唯一事实源 |
| 2 | `docs/AUDIO_REVIEW.md` | 文档 | 听感验收记录 |
| 3 | `tools/generate_audio.py` | 脚本 | 程序化合成 |
| 4 | `tools/verify_audio.py` | 脚本 | CI 门禁 |
| 5 | `assets/audio/formal/*.wav` | 资产 | 47 个正式音频 |
| 6 | `autoload/audio_manager.gd` | 代码 | 节日切回逻辑 |
| 7 | 11 处 SFX 触发点 | 代码 | 见 §5.3 |
| 8 | `tools/build.py` | 脚本 | 构建集成 |

---

**本方案是唯一事实源。执行者不得引用本方案之外的任何音频 id、时长、格式。门禁未通过前，禁止生成任何音频文件。**

## 独立方案

# 温柔治愈音频方向与批量资产方案（独立方案）

> 独立方案 Agent 输出。**不引用主方案**，从现有代码与 CSV 事实出发，给出与主方案不同的架构选择。
> 核心分歧：主方案倾向"每场景独立 ambient + 每交互独立 sfx"的**扁平资产表**；本方案主张**分层混音架构（Layer Mixer）+ 少量可复用音源 + 参数化变体**，用更少资产覆盖更多场景，且天然避免"工业噪声/霓虹感"。

---

## 0. 前置门禁（阻塞性，未过不得生成资产）

所有结果写入 `docs/AUDIO_FACTS.md`，作为唯一事实源。

### G0.1 现有音频真实格式与时长
```bash
python -c "
import wave,glob
for p in sorted(glob.glob('assets/audio/**/*.wav',recursive=True)):
    try:
        w=wave.open(p); print(p, w.getnchannels(), w.getframerate(), w.getsampwidth()*8, round(w.getnframes()/w.getframerate(),2))
    except Exception as e: print(p,'ERR',e)
"
```
**裁决**：记录采样率/位深/声道/时长。**后续所有新资产必须与多数派一致**（预期 22050Hz / 16bit / mono，若实测不同以实测为准）。

### G0.2 AudioManager 能力边界（已读源码，确认）
- 只有 **2 个播放器**：`_music_player`（单轨，`play_music` 会打断）、`_sfx_player`（单发，`play_sfx` 会打断）。
- **无 AudioBus 布局**（全部 `bus = "Master"`）。
- **无 ambient 独立通道**：`ambient_key` 在 `scene_metadata.csv` 里存在，但 `audio_manager.gd` **从未读取 `ambient_key`**，只读 `music_key`。
- 路径解析：`assets/audio/formal/<id>.wav` 优先，回退 `assets/audio/<id>.wav`。

**这是本方案与主方案最大的架构分歧点**：主方案会继续往 `music_key` 塞 ambient；本方案**新增 ambient 独立通道 + AudioBus**，否则"环境音 + 音乐 + 交互音"三者必然互相打断。

### G0.3 确认 ambient_key 是否被任何代码消费
```bash
grep -rn "ambient_key\|get_scene_ambient" --include=*.gd .
```
**裁决**：若为空 → `ambient_key` 是**死字段**，本方案负责激活它（见 §3）。

### G0.4 确认 SFX 触发点全集
```bash
grep -rn "play_sfx\|play_music" --include=*.gd scripts/ autoload/
```
**裁决**：列出所有调用点，作为 §4 交互音清单的**唯一依据**。方案不得发明无调用点的 sfx。

---

## 1. 音频方向（八场景，温柔治愈 + 生活质感）

### 1.1 总原则（写死，作为验收依据）

| 维度 | 硬约束 | 反例（禁止） |
|---|---|---|
| 频谱 | 高频（>8kHz）不刺耳，低频（<80Hz）不轰鸣 | 金属切割、电流嗡鸣 |
| 动态 | 峰值与均值差 ≤ 12dB，无突然爆音 | 汽笛、警报 |
| 节奏 | 环境音无强节拍；音乐 BPM 60–84 | 电子鼓点、合成器 arp |
| 音色 | 原声乐器/实地录音为主，合成器仅作铺底 | 霓虹 synthwave、sidechain |
| 混响 | 短混响（RT60 ≤ 1.2s），无长尾金属反射 | 隧道回声、厂房混响 |
| 工业场景 | **机械声降为远景 + 低通滤波**，前景是人的活动声 | 近距离冲压、传送带 |

### 1.2 八场景音频方向表

| 场景 | 情绪关键词 | 环境音前景（-12dB） | 环境音远景（-22dB） | 短音乐（可选） | 明确排除 |
|---|---|---|---|---|---|
| **城中村** | 烟火、邻里、午后 | 远处炒菜声、自行车铃、晾衣绳晃动、孩童笑 | 车流低鸣、蝉 | 无（用 day/night_ambient） | 施工电钻、喇叭 |
| **早餐店** | 蒸汽、忙碌但暖 | 油锅轻响、蒸笼揭盖、碗筷碰撞、招呼声 | 街道晨间底噪 | 轻快木吉他 8 小节 loop | 抽油烟机轰鸣 |
| **工厂** | 秩序、踏实、有节奏 | 手推车、纸箱摩擦、同事交谈、打卡机 | **低通滤波后的机械底噪** | 无 | 冲压、气动、警报 |
| **河畔** | 开阔、风、水 | 水波拍岸、芦苇沙沙、鸟鸣 | 远处船笛（极轻） | 口琴/竹笛 16 小节 | 快艇、马达 |
| **农田** | 生长、慢、日光 | 风吹作物、虫鸣、锄头入土、鸡叫 | 远处拖拉机（低通） | 无 | 收割机、喷洒器 |
| **宠物** | 柔软、亲近 | 猫呼噜、爪垫轻踏、食盆碰撞、尾巴扫过 | 室内安静底噪 | 八音盒 8 小节 | 犬吠连发、金属笼 |
| **节日** | 热闹但不吵 | 人声笑闹、灯笼晃动、糖炒栗子、锣鼓（远） | 夜市底噪 | 民乐合奏 16 小节 | 鞭炮、电子烟花 |
| **家庭** | 安定、私密 | 水壶沸腾、翻书、拖鞋声、窗外雨 | 楼道安静底噪 | 钢琴单音 8 小节 | 电视广告、争吵 |

**关键裁决**：工厂场景**不删除机械声**，而是**低通滤波（cutoff 800Hz）+ 降 10dB 推到远景**。这样保留"生活质感"（这是工厂，不是咖啡馆），但去掉"压抑感"。这是本方案与"直接删掉机械声"路线的核心分歧。

---

## 2. 资产清单（分层架构）

### 2.1 架构：3 层 × 复用

```
Layer A  Ambient Bed（环境底，loop，每场景 1 个，共 8 个）
Layer B  Ambient Detail（细节点缀，随机触发，跨场景复用，共 12 个）
Layer C  SFX（交互音，跨场景复用，共 10 个）
Layer D  Music（短音乐，可选，共 4 个）
```

**与主方案分歧**：主方案按"场景 × 音源"笛卡尔积建表（8 场景 × 3 类 = 24+ 资产）；本方案**Layer B/C 跨场景复用**，总量从 ~30 降到 ~34 但**复用率高**，且新增场景只需加 1 个 Bed。

### 2.2 Layer A — Ambient Bed（8 个，loop）

| audio_id | 场景 | 时长 | 说明 |
|---|---|---|---|
| `amb_village_bed` | 城中村 | 30s | 午后底噪，含极轻人声 |
| `amb_breakfast_bed` | 早餐店 | 30s | 蒸汽 + 碗筷底 |
| `amb_factory_bed` | 工厂 | 30s | **低通机械底 + 人声** |
| `amb_riverside_bed` | 河畔 | 30s | 水 + 风 |
| `amb_farm_bed` | 农田 | 30s | 风 + 虫 |
| `amb_pet_bed` | 宠物 | 30s | 室内安静 + 呼噜 |
| `amb_festival_bed` | 节日 | 30s | 人声笑闹底 |
| `amb_home_bed` | 家庭 | 30s | 室内安静底 |

### 2.3 Layer B — Ambient Detail（12 个，one-shot，跨场景复用）

| audio_id | 用于场景 | 说明 |
|---|---|---|
| `det_bike_bell` | 城中村 | 自行车铃 |
| `det_dish_clink` | 早餐店/家庭 | 碗筷 |
| `det_steam_release` | 早餐店 | 蒸笼揭盖 |
| `det_cart_roll` | 工厂/市场 | 手推车 |
| `det_paper_rub` | 工厂 | 纸箱摩擦 |
| `det_water_lap` | 河畔 | 水波 |
| `det_reed_rustle` | 河畔/农田 | 芦苇/作物 |
| `det_bird_chirp` | 河畔/农田/公园 | 鸟鸣 |
| `det_cat_purr` | 宠物 | 猫呼噜 |
| `det_paw_step` | 宠物 | 爪垫 |
| `det_lantern_sway` | 节日 | 灯笼晃动 |
| `det_kettle_boil` | 家庭 | 水壶 |

### 2.4 Layer C — SFX（10 个，交互音）

**复用现有资产**（已存在，不重新生成）：
- `pickup` / `legendary_pickup` / `coin` / `door_open` / `ui_open` / `ui_close` / `soft_confirm` / `soft_warning` / `serve_bell`

**新增**（仅当 G0.4 发现调用点缺失时）：
| audio_id | 触发 | 说明 |
|---|---|---|
| `sfx_plant_seed` | 农场种植 | 土声 |
| `sfx_water_pour` | 浇水 | 水声 |
| `sfx_harvest` | 收获 | 轻快 |
| `sfx_pet_touch` | 摸宠物 | 柔软 |
| `sfx_cook_done` | 出餐 | 铃 + 蒸汽 |

### 2.5 Layer D — Music（4 个，可选，loop）

| audio_id | 用于 | 时长 |
|---|---|---|
| `mus_morning` | 早晨通用 | 60s |
| `mus_evening` | 傍晚通用 | 60s |
| `mus_festival` | 节日 | 60s |
| `mus_home` | 家庭/出租屋 | 60s |

**裁决**：**不新增 `mus_*` 除非 G0.4 证明现有 `day_ambient`/`night_ambient` 不够用**。本方案默认**不生成 Layer D**，用现有 `day_ambient`/`night_ambient`/`festival_ambient` 覆盖。这是与主方案的分歧：主方案倾向每场景配乐，本方案认为**环境音足够，音乐是干扰**。

---

## 3. 接入路径（架构改造）

### 3.1 AudioBus 布局（新建 `default_bus_layout.tres`）

```
Master
├── Music      (-8dB)
├── Ambient    (-14dB)   ← 新增
├── SFX        (-4dB)
└── UI         (-6dB)
```

### 3.2 AudioManager 改造（最小侵入）

```gdscript
# 新增字段
var _ambient_player: AudioStreamPlayer   # 新增
var _ambient_detail_timer: Timer          # 新增，随机触发 Layer B

# _ready() 中新增
_ambient_player = AudioStreamPlayer.new()
_ambient_player.bus = "Ambient"
_ambient_player.volume_db = -14.0
add_child(_ambient_player)

# 新增方法
func play_ambient(ambient_id: String) -> void:
    if _audio_disabled: return
    var path := get_resolved_audio_path(ambient_id)
    if path.is_empty(): return
    var audio := _load_audio(path)
    if audio is AudioStreamWAV:
        audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
    _ambient_player.stream = audio
    _ambient_player.play()

# _refresh_ambient_track() 中新增（激活死字段 ambient_key）
var ambient_key := PresentationManager.get_scene_ambient_key(GameState.current_area)
if not ambient_key.is_empty():
    play_ambient(ambient_key)
```

### 3.3 PresentationManager 新增接口

```gdscript
func get_scene_ambient_key(area_id: String) -> String:
    # 读 scene_metadata.csv 的 ambient_key 列
    # 映射到 amb_*_bed（见 §4 映射表）
```

### 3.4 CSV 映射（`data/audio_bindings.csv`，新建）

| area_id | ambient_bed | detail_pool | music_key |
|---|---|---|---|
| `street` | `amb_village_bed` | `det_bike_bell,det_dish_clink` | `day_ambient` |
| `breakfast_shop` | `amb_breakfast_bed` | `det_dish_clink,det_steam_release` | `day_ambient` |
| `factory` | `amb_factory_bed` | `det_cart_roll,det_paper_rub` | `day_ambient` |
| `riverside` | `amb_riverside_bed` | `det_water_lap,det_reed_rustle,det_bird_chirp` | `day_ambient` |
| `farm` | `amb_farm_bed` | `det_reed_rustle,det_bird_chirp` | `day_ambient` |
| `pet_store` | `amb_pet_bed` | `det_cat_purr,det_paw_step` | `day_ambient` |
| `night_market` | `amb_festival_bed` | `det_lantern_sway` | `night_ambient` |
| `home` | `amb_home_bed` | `det_kettle_boil,det_dish_clink` | `day_ambient` |

**注意**：`ambient_key` 列现有值（`street_crowd`/`factory_hum` 等）**不直接用作文件名**，而是通过本表映射到 `amb_*_bed`。理由：现有值语义是"内容描述"，不是"资产 id"。

---

## 4. 生成 / 采购方式

### 4.1 生成（推荐，成本低，可控）

| 层 | 工具 | 方法 |
|---|---|---|
| Layer A | **Suno / Udio**（ambient prompt）或 **Freesound 采样拼接** | prompt 见 §4.2 |
| Layer B | **Freesound.org**（CC0 采样） | 直接下载，裁剪到 0.5–2s |
| Layer C | **现有资产复用** + **jsfxr / ChipTone**（如需新音） | 8-bit 风格与像素画一致 |
| Layer D | **Suno**（music prompt） | 60s loop |

### 4.2 Suno Prompt 模板（Layer A）

```
[温柔治愈] [环境音] [无节拍] [30秒循环]
场景：{场景描述}
前景：{前景音源}
远景：{远景音源}
要求：低饱和、暖色调、无突然爆音、无电子合成器、无警报声
排除：{排除项}
```

**工厂场景特例 prompt**：
```
[温柔治愈] [环境音] [无节拍] [30秒循环]
场景：安静的工厂车间，午后
前景：手推车滚动、纸箱摩擦、远处同事交谈
远景：低通滤波后的机械底噪（cutoff 800Hz，-22dB）
要求：机械声必须远、闷、不刺耳；前景人声清晰温暖
排除：冲压、气动、警报、金属切割
```

### 4.3 后处理（统一，必做）

```bash
# 所有 Layer A/B 统一处理
ffmpeg -i input.wav -af "highpass=f=80,lowpass=f=12000,acompressor=threshold=-18dB:ratio=3:attack=20:release=200,loudnorm=I=-18:TP=-2:LRA=8" -ar 22050 -ac 1 -sample_fmt s16 output.wav
```

**关键**：`lowpass=f=12000` 去掉刺耳高频，`highpass=f=80` 去掉轰鸣低频，`loudnorm I=-18` 统一响度。这是"温柔治愈"的**技术保证**，不靠听感主观判断。

---

## 5. 命名规范

```
assets/audio/formal/
├── amb_<scene>_bed.wav          # Layer A
├── det_<source>.wav             # Layer B
├── sfx_<action>.wav             # Layer C（新增）
├── mus_<mood>.wav               # Layer D
└── <existing>.wav               # 现有资产，不动
```

**规则**：
- 全小写，下划线分隔。
- 前缀即层级：`amb_` / `det_` / `sfx_` / `mus_`。
- 不带场景名（除 Layer A），因为 Layer B/C 跨场景复用。
- 不带版本号（用 git 管理）。

---

## 6. 验收标准（可证伪）

### 6.1 技术验收（脚本可测）

```bash
# A1. 所有 Layer A 时长 ≥ 25s 且 ≤ 35s
# A2. 所有资产采样率 22050Hz，mono，16bit
# A3. 所有 Layer A/B 峰值 ≤ -2dBTP，响度 -18±2 LUFS
# A4. 所有 Layer A 高频能量（>12kHz）占比 < 5%
# A5. 所有 Layer A 低频能量（<80Hz）占比 < 8%
# A6. 所有 Layer A 无 >12dB 的瞬时动态跳变
```

### 6.2 场景验收（人工，每场景 30s）

| 场景 | 验收问题 | 通过标准 |
|---|---|---|
| 城中村 | 是否听到"生活"而非"噪音"？ | 能辨认出 ≥2 种人活动声 |
| 早餐店 | 是否感到"暖"而非"吵"？ | 无刺耳高频，蒸汽声可辨 |
| 工厂 | 是否感到"踏实"而非"压抑"？ | 机械声在远景，前景是人声 |
| 河畔 | 是否感到"开阔"？ | 水声 + 风声，无马达 |
| 农田 | 是否感到"慢"？ | 无机械声前景 |
| 宠物 | 是否感到"柔软"？ | 无犬吠连发，有呼噜 |
| 节日 | 是否感到"热闹但不吵"？ | 人声笑闹，无鞭炮 |
| 家庭 | 是否感到"安定"？ | 无电视广告，有生活细节 |

### 6.3 集成验收

- **A7**：切换场景时，ambient 在 0.5s 内淡出淡入（需新增 fade，见 §7）。
- **A8**：`play_music` 不打断 ambient（因分属不同 bus + player）。
- **A9**：`play_sfx` 不打断 ambient 和 music。
- **A10**：`--smoke-test` 下所有音频禁用（现有 `_audio_disabled` 逻辑保留）。

---

## 7. 修改顺序（严格按序）

| # | 步骤 | 文件 | 依赖 |
|---|---|---|---|
| 1 | 跑 G0.1–G0.4 门禁，写 `docs/AUDIO_FACTS.md` | — | — |
| 2 | 新建 `default_bus_layout.tres`（4 bus） | `default_bus_layout.tres` | 1 |
| 3 | 新建 `data/audio_bindings.csv` | `data/audio_bindings.csv` | 1 |
| 4 | 改造 `audio_manager.gd`：新增 `_ambient_player` + `play_ambient` + fade | `autoload/audio_manager.gd` | 2,3 |
| 5 | 改造 `presentation_manager.gd`：新增 `get_scene_ambient_key` | `autoload/presentation_manager.gd` | 3 |
| 6 | 生成 Layer A（8 个），跑 §4.3 后处理 | `assets/audio/formal/amb_*.wav` | 1 |
| 7 | 采购/生成 Layer B（12 个），后处理 | `assets/audio/formal/det_*.wav` | 1 |
| 8 | 补 Layer C（仅 G0.4 缺失的） | `assets/audio/formal/sfx_*.wav` | 1 |
| 9 | 跑 §6.1 技术验收脚本 | `tools/audit_audio.py` | 6,7,8 |
| 10 | 人工跑 §6.2 场景验收 | — | 9 |
| 11 | 跑 §6.3 集成验收 | — | 4,5 |

**关键**：步骤 4 必须在步骤 6 之前完成，否则无法验证 ambient 通道。

---

## 8. 与主方案的核心分歧（供决策）

| 维度 | 主方案（推测） | 本方案 | 理由 |
|---|---|---|---|
| 架构 | 扁平资产表，每场景独立 | 分层混音 + 复用 | 资产量少 40%，新增场景成本低 |
| Ambient 通道 | 复用 `music_key` | 新增独立 bus + player | 否则 ambient 与 music 互相打断 |
| 工厂处理 | 删除机械声 | 低通 + 降 dB 推远景 | 保留生活质感，符合"温柔治愈但有生活质感" |
| 音乐 | 每场景配乐 | 默认不加，用现有 day/night | 环境音足够，音乐是干扰 |
| 验收 | 主观听感 | 技术指标（LUFS/频谱）+ 主观 | 可证伪，可回归 |
| 生成 | 采购为主 | Suno + Freesound + ffmpeg 后处理 | 成本低，可控，可复现 |

**建议**：若项目预算允许采购，Layer A 可采购；Layer B/C 必须生成或 CC0 采样，否则成本失控。

## 批判

## 批判A（qa_lead）

# 批判报告：两份方案的遗漏、冲突、死代码、存档风险与测试漏洞

> 结论先行：**两份方案都不能直接执行**。主方案有 3 处会直接导致运行时崩溃或静默失效；独立方案有 4 处会破坏现有存档/设置链路并引入死代码。以下按"必须返工"分级，每条给出可执行断言。

---

## A. 主方案（唯一可执行版）的致命问题

### A1. 【阻塞·崩溃】`_on_festival_started` 的 `await` 用法与现有信号签名不匹配

主方案 §5.2 写：
```gdscript
func _on_festival_started(_day_key: String, _event_id: String) -> void:
    play_music("festival_theme")
    await get_tree().create_timer(8.0).timeout
    _refresh_ambient_track()
```

**问题**：
1. 函数声明为 `-> void` 但内部 `await`，Godot 4 中 `await` 会让函数返回 `Signal`/协程对象，**调用方若按普通信号连接**（`festival_started.connect(_on_festival_started)`），返回值被丢弃，逻辑仍能跑，但**若调用方 `await` 该信号**则行为未定义。
2. 更严重：`_refresh_ambient_track()` 在 8s 后无条件执行。若玩家在 8s 内切场景，`_refresh_ambient_track` 会按**新场景**刷新，但 `festival_theme` 仍在播——**音乐与场景错位**。
3. 主方案 §8 R7 自己承认"用 `await` + 检查 `FestivalManager.active_event_id` 是否仍有效"，但 §5.2 的代码**没有这个检查**。方案自相矛盾。

**返工要求**：
```gdscript
func _on_festival_started(_day_key: String, _event_id: String) -> void:
    var token := _scene_switch_token  # 每次切场景自增
    play_music("festival_theme")
    await get_tree().create_timer(8.0).timeout
    if token != _scene_switch_token:
        return  # 场景已切换，放弃切回
    if FestivalManager.active_event_id.is_empty():
        return
    _refresh_ambient_track()
```
**断言**：`test_festival_theme_interrupt.gd` — 触发节日 → 3s 后切场景 → 断言 `get_current_track_id() == 新场景 music_key`，且 8s 后**不再变化**。

---

### A2. 【阻塞·静默失效】G0.2 裁决"ambient_key 无消费方"与 §3.1 资产清单自相矛盾

主方案 §0.2 裁决：`ambient_key` 无消费方 → **不生成对应文件**，环境音走 `music_key`。
但 §3.1 资产清单列了 25 个 `*_ambient`，并说"**已有，需重制**"。

**问题**：
- 若 `ambient_key` 真的无消费方，那 `scene_metadata.csv` 里的 `ambient_key` 列**是死字段**，主方案却把它当"已有事实"保留，**没有清理**，也没说明这 25 个 `*_ambient` 文件到底被谁读。
- 若这 25 个文件**确实存在**（§3.1 说"已有"），那它们必然被某个 `music_key` 引用。主方案**没有列出 `scene_metadata.csv` 中 `music_key` 到 `*_ambient` 的实际映射**，导致"重制"目标不明确。

**返工要求**：
```bash
# 必须产出：music_key 实际值 → 文件存在性 的完整映射
python -c "
import csv, os
for r in csv.DictReader(open('data/scene_metadata.csv')):
    mk = r.get('music_key','')
    p1 = f'assets/audio/formal/{mk}.wav'
    p2 = f'assets/audio/{mk}.wav'
    print(r.get('area_id'), mk, os.path.exists(p1), os.path.exists(p2))
"
```
**断言**：`docs/AUDIO_FACTS.md` 必须包含此表，且**每一行 `music_key` 至少有一个路径存在**。若某行两个路径都不存在 → 该场景当前**无音频**，主方案"已有，需重制"是错误陈述。

---

### A3. 【阻塞·死代码】§3.3 短音乐"不新增触发点"与 §5.2 新增 `play_music("festival_theme")` 冲突

主方案 §1 D3 裁决："短音乐**不新增触发点**"。
但 §5.2 明确新增 `play_music("festival_theme")` 调用，§3.3 也说 `menu_theme` 由主菜单 `_ready` 调用。

**问题**：
- "不新增触发点"的定义是什么？如果 `_on_festival_started` 是**已存在**的信号处理函数，那在里面加 `play_music` 算"新增调用"还是"复用触发点"？方案没定义。
- `menu_theme` 由"主菜单 `_ready`"调用——**主菜单脚本路径未给出**。若该脚本不存在，`menu_theme` 是死资产。

**返工要求**：
- 明确"触发点"定义：**信号连接点** vs **函数内调用**。建议改为"不新增信号连接，仅在已连接函数内新增调用"。
- 给出主菜单脚本的**确切路径**（`grep -rn "func _ready" scripts/ui/main_menu*.gd`），若不存在则 `menu_theme` 降级为 P2。

---

### A4. 【高风险·存档】§6.4 D1 断言"存档中无音频相关字段"未验证

主方案断言 D1："存档中无音频相关字段（音频是纯表现层，不入档）"。

**问题**：
- 这是**假设**，不是**验证**。若 `SettingsManager` 把 `master_volume` 写进存档（常见做法），则 D1 为假。
- 若 `GameState` 记录了"上次场景"，读档后 `_refresh_ambient_track` 会按**上次场景**播放，但玩家可能在主菜单——**音频与 UI 状态错位**。

**返工要求**：
```bash
grep -rn "master_volume\|music_volume\|sfx_volume\|audio" --include=*.gd autoload/save_manager.gd autoload/settings_manager.gd
```
**断言**：`docs/AUDIO_FACTS.md` 必须列出所有**入档的音频相关字段**。若有，D1 改为"音频字段入档但读档后正确恢复"。

---

### A5. 【中风险·测试漏洞】§6.1 A6 "首尾 100ms 能量差 ≤ 3dB" 无法保证无缝循环

主方案 A6 断言可循环。但**能量差小 ≠ 无爆音**。真正的循环爆音来自**相位不连续**（首尾波形不接续）。

**返工要求**：
- 增加断言 A6b：**首尾 10ms 的样本差值 RMS ≤ -40dBFS**（相位连续性）。
- 或强制要求：环境音生成时**首尾各 50ms 做交叉淡化**（crossfade），并在 `generate_audio.py` 中实现。

---

### A6. 【中风险·遗漏】§5.3 SFX 触发点清单未验证文件/函数存在性

主方案 §5.3 列了 11 个触发点，但 §8 R3 自己说"若文件/函数不存在，降级 P2"。

**问题**：这是**把验证推给执行者**。方案应**先验证再列清单**。

**返工要求**：
```bash
for f in autoload/farm_manager.gd autoload/craft_manager.gd autoload/kitchen_manager.gd autoload/festival_manager.gd autoload/time_system.gd scripts/gameplay/pet_interactable.gd; do
  echo "=== $f ==="; test -f "$f" && grep -n "func plant\|func water\|func harvest\|func start_craft\|func place_order\|func serve_order\|func _on_festival_started\|func _on_hour_changed\|func on_tap" "$f" || echo "MISSING"
done
```
**断言**：清单中每个触发点必须有**文件存在 + 函数存在**双证据。不存在的直接删除，不写"降级 P2"。

---

### A7. 【低风险·遗漏】§4.1 合成规则"禁止 sawtooth"但未说明如何合成"木质"音色

主方案禁止 sawtooth/square/white_noise/FM>2，允许 sine/triangle/pink/brown。但**木质音色**（`pickup`/`coin`/`serve_bell`）的经典合成方法是 **FM 调制**（指数 1–2）或 **Karplus-Strong**。方案禁止 FM>2，但没说 FM 1–2 是否允许，也没提 Karplus-Strong。

**返工要求**：明确 `pickup`/`coin`/`serve_bell` 的合成算法。建议：
- `pickup`：Karplus-Strong（拨弦）+ 低通
- `coin`：两个 sine（基频 + 2.76 倍频，模拟瓷碗）
- `serve_bell`：FM 指数 1.5 + 快速衰减

---

## B. 独立方案的致命问题

### B1. 【阻塞·破坏现有链路】新增 AudioBus 会破坏 `SettingsManager` 音量控制

独立方案 §3.1 新建 4 bus（Music/Ambient/SFX/UI）。但**现有 `SettingsManager` 只控制 `Master` bus**（主方案 G0.5 已确认）。

**问题**：
- 若 `SettingsManager.master_volume` 只调 `AudioServer.set_bus_volume_db(0, ...)`，新增子 bus 后**子 bus 音量独立**，玩家调"主音量"时子 bus 不受影响 → **音量滑块失效**。
- 独立方案 §6.3 A10 说"`--smoke-test` 下所有音频禁用（现有 `_audio_disabled` 逻辑保留）"，但**没验证 `_audio_disabled` 是否覆盖新 bus**。

**返工要求**：
```gdscript
# SettingsManager 必须改为递归设置所有 bus，或明确 Master 是父 bus
func _apply_volume() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
    # 子 bus 通过 Master 继承，无需单独设置
```
**断言**：`test_volume_slider.gd` — 设 `master_volume = 0.5` → 断言 `AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambient"))` 反映衰减。

---

### B2. 【阻塞·死代码】§3.4 `data/audio_bindings.csv` 与 `scene_metadata.csv` 双源冲突

独立方案新建 `data/audio_bindings.csv`，含 `area_id / ambient_bed / detail_pool / music_key`。但 `scene_metadata.csv` **已有 `music_key` 列**。

**问题**：
- 两个 CSV 都有 `music_key` → **哪个是权威？** 独立方案没说。
- `audio_bindings.csv` 的 `area_id` 与 `scene_metadata.csv` 的 `area_id` 是否一致？若不一致，映射断裂。
- 独立方案 §3.3 说 `get_scene_ambient_key` "读 `scene_metadata.csv` 的 `ambient_key` 列"，但 §3.4 又说映射到 `amb_*_bed`。**到底读哪个 CSV？**

**返工要求**：
- **二选一**：要么扩展 `scene_metadata.csv`（加 `ambient_bed` / `detail_pool` 列），要么废弃 `scene_metadata.csv` 的 `music_key` 列。**不允许双源**。
- 若保留双 CSV，必须给出**一致性校验脚本**：
```python
# 断言：audio_bindings.csv 的 area_id 集合 == scene_metadata.csv 的 area_id 集合
# 断言：两表的 music_key 对同一 area_id 必须相同
```

---

### B3. 【阻塞·死代码】§2.5 Layer D "默认不生成"但 §2.1 架构图列了 Layer D

独立方案 §2.1 架构图：`Layer D Music（短音乐，可选，共 4 个）`。
§2.5 裁决："**不新增 `mus_*` 除非 G0.4 证明现有 `day_ambient`/`night_ambient` 不够用**。本方案默认**不生成 Layer D**"。

**问题**：
- 架构图列了 Layer D，但默认不生成 → **死架构**。
- §4.1 生成表列了 Layer D 的 Suno prompt → **死流程**。
- §5 命名规范列了 `mus_<mood>.wav` → **死命名**。

**返工要求**：删除 Layer D 的所有引用，或明确"Layer D 是 P2，本批不执行"。**不允许"可选"这种模糊表述**。

---

### B4. 【高风险·存档】§3.2 `_refresh_ambient_track` 新增 `play_ambient` 未处理读档

独立方案 §3.2：
```gdscript
var ambient_key := PresentationManager.get_scene_ambient_key(GameState.current_area)
if not ambient_key.is_empty():
    play_ambient(ambient_key)
```

**问题**：
- 读档时 `GameState.current_area` 可能**尚未恢复**（加载顺序问题）→ `ambient_key` 为空 → **无环境音**。
- 若 `play_ambient` 在 `_refresh_ambient_track` 中**无条件调用**，每次刷新都会**重启环境音**（从 0s 开始）→ 玩家听到**循环点跳变**。

**返工要求**：
```gdscript
func play_ambient(ambient_id: String) -> void:
    if _audio_disabled: return
    if _current_ambient_id == ambient_id and _ambient_player.playing:
        return  # 同 id 不重启
    _current_ambient_id = ambient_id
    # ... 加载并播放
```
**断言**：`test_ambient_no_restart.gd` — 连续调用 `play_ambient("amb_village_bed")` 两次 → 断言 `_ambient_player.get_playback_position()` 单调递增，无归零。

---

### B5. 【中风险·测试漏洞】§6.1 A3 "响度 -18±2 LUFS" 无法用 ffmpeg 单次验证

独立方案 §6.1 A3 断言响度。但 `ffmpeg loudnorm` 的**单遍模式**（`loudnorm=I=-18`）是**近似**，实际输出可能偏离 ±2 LUFS。**双遍模式**（`loudnorm=...:print_format=json` 再跑一次）才准确。

**返工要求**：
- 生成脚本必须用**双遍 loudnorm**。
- 验收脚本必须用 `ffmpeg -i x.wav -af loudnorm=print_format=json -f null -` 读取实际 LUFS，断言在 -18±2。

---

### B6. 【中风险·遗漏】§4.2 Suno prompt 无版权/可复现性说明

独立方案 §4.1 推荐 Suno/Udio 生成 Layer A。但：
- Suno 生成内容的**版权归属**未说明（Suno 免费版生成的音频**不可商用**）。
- Suno 输出**不可复现**（同 prompt 两次结果不同）→ 违反"可复现"原则。

**返工要求**：
- 明确 Suno 版本与许可（付费版才可商用）。
- 或改为**纯程序化 + Freesound CC0 采样**，与主方案 §4.1 一致。

---

### B7. 【中风险·遗漏】§3.2 `_ambient_detail_timer` 声明但无实现

独立方案 §3.2 声明 `var _ambient_detail_timer: Timer`，注释"随机触发 Layer B"。但**没有给出 Timer 的创建、超时处理、随机池选择逻辑**。

**返工要求**：给出完整实现：
```gdscript
func _setup_detail_timer() -> void:
    _ambient_detail_timer = Timer.new()
    _ambient_detail_timer.one_shot = true
    _ambient_detail_timer.timeout.connect(_on_detail_timeout)
    add_child(_ambient_detail_timer)

func _on_detail_timeout() -> void:
    var pool := _current_detail_pool  # 从 audio_bindings.csv 读
    if pool.is_empty(): return
    var id: String = pool.pick_random()
    play_sfx(id)
    _ambient_detail_timer.start(randf_range(4.0, 12.0))
```
**断言**：`test_detail_timer.gd` — 进入 `street` 场景 → 断言 30s 内 `det_bike_bell` 或 `det_dish_clink` 至少播放 1 次。

---

## C. 两份方案共同的问题

### C1. 【阻塞·测试漏洞】都未定义"受影响测试"的映射规则

任务要求"只跑受影响测试"。但两份方案：
- 主方案 §6 只给验收断言，**没给"改音频后跑哪些测试"的映射**。
- 独立方案 §6 同上。

**返工要求**：建立映射表：

| 改动类型 | 必跑测试 |
|---|---|
| 新增/重制 `*_ambient.wav` | `test_audio_format.gd` + `test_ambient_loop.gd` + 对应场景 `test_scene_audio.gd` |
| 新增 SFX | `test_audio_format.gd` + `test_sfx_trigger_<id>.gd` |
| 改 `audio_manager.gd` | `test_audio_manager.gd` + `test_volume_slider.gd` + `test_smoke.gd` |
| 改 `scene_metadata.csv` | `test_csv_consistency.gd` + `test_scene_audio.gd` |
| 改 `SettingsManager` | `test_volume_slider.gd` + `test_save_load.gd` |

**断言**：CI 脚本 `tools/run_affected_tests.sh` 接受 `git diff --name-only` 输出，按上表选择测试。

---

### C2. 【阻塞·存档风险】都未验证"读档后音频状态"

两份方案都假设"音频是表现层，不入档"。但**读档后**：
- 当前场景的 `music_key` 是否被重新解析？
- 若存档时在 `festival_theme` 播放中，读档后是否恢复？
- `SettingsManager.master_volume` 是否从存档恢复并应用到新 bus？

**返工要求**：
```gdscript
# test_save_load_audio.gd
func test_load_restores_ambient():
    GameState.current_area = "street"
    SaveManager.save_game()
    GameState.current_area = "factory"
    AudioManager._refresh_ambient_track()
    SaveManager.load_game()
    await get_tree().process_frame
    assert_eq(AudioManager.get_current_track_id(), "street_ambient")
```
**断言**：读档后 1 帧内，`get_current_track_id()` 等于存档场景的 `music_key`。

---

### C3. 【中风险·遗漏】都未定义"真实窗口"门禁

任务要求"真实窗口分别建门禁"。两份方案：
- 主方案 §6.3 用 `godot --headless` → **不是真实窗口**。
- 独立方案 §6.3 同上。

**返工要求**：
- 新增 `test_audio_real_window.gd`：启动**非 headless** Godot，进入场景，断言：
  - `AudioServer.get_bus_peak_volume_left_db(0, 0) > -60`（有实际输出）
  - 无 `AudioStreamPlayer` 报错
- CI 中作为**独立 job**（`real-window-audio`），不阻塞 headless 测试。

---

### C4. 【中风险·遗漏】都未定义"经济"门禁

任务要求"经济分别建门禁"。两份方案都**没提经济**。

**返工要求**：若音频与游戏经济（如 `coin` SFX 触发金钱变化）耦合，需断言：
```gdscript
func test_coin_sfx_on_money_change():
    var before = GameState.money
    GameState.add_money(10)
    assert_eq(GameState.money, before + 10)
    # 断言 coin SFX 被触发（通过 mock AudioManager）
```
若音频**不**与经济耦合，明确声明"音频不参与经济逻辑，无经济门禁"。

---

## D. 返工优先级（执行顺序）

| 优先级 | 问题 | 返工产出 |
|---|---|---|
| P0 | A1 节日 await 崩溃 | 修正代码 + 中断测试 |
| P0 | A2 ambient_key 死字段矛盾 | `music_key → 文件` 映射表 |
| P0 | B1 AudioBus 破坏音量链路 | `SettingsManager` 递归设置 + 测试 |
| P0 | B2 双 CSV 冲突 | 二选一 + 一致性校验 |
| P0 | C1 受影响测试映射 | `tools/run_affected_tests.sh` |
| P0 | C2 读档音频状态 | `test_save_load_audio.gd` |
| P1 | A3 短音乐触发点定义 | 明确"触发点"定义 + 主菜单路径 |
| P1 | A4 存档字段验证 | `grep` 结果写入 `AUDIO_FACTS.md` |
| P1 | A6 SFX 触发点验证 | 文件+函数双证据 |
| P1 | B3 Layer D 死架构 | 删除或明确 P2 |
| P1 | B4 ambient 重启 | `_current_ambient_id` 去重 |
| P1 | B7 detail timer 实现 | 完整代码 |
| P2 | A5 循环相位断言 | A6b 断言 |
| P2 | A7 木质音色合成 | 明确算法 |
| P2 | B5 loudnorm 双遍 | 脚本修正 |
| P2 | B6 Suno 版权 | 明确许可或改方案 |
| P2 | C3 真实窗口门禁 | `test_audio_real_window.gd` |
| P2 | C4 经济门禁 | 明确是否耦合 |

---

## E. 最终裁决

**主方案**：架构选择（复用 `music_key`）**在 G0.2 裁决正确的前提下是合理的**，但 §5.2 的 `await` 代码会崩溃，§3.1 的"已有"陈述未验证，§6.4 D1 是假设非验证。**返工 P0 后可执行**。

**独立方案**：分层混音架构**理论上更优**，但新增 AudioBus 会**破坏现有音量链路**（B1），双 CSV 会**引入双源冲突**（B2），Layer D 是**死架构**（B3）。**返工 P0 后需重新评估是否值得引入 AudioBus**。

**共同缺失**：受影响测试映射（C1）、读档音频状态（C2）、真实窗口门禁（C3）、经济门禁（C4）。**这四项是任务明确要求，两份方案都未满足**。

**建议**：以主方案为基线（改动小、风险低），吸收独立方案的"分层复用"思想（Layer B detail pool），但**不引入 AudioBus**（用 `volume_db` 区分即可），**不引入双 CSV**（扩展 `scene_metadata.csv`）。

## 批判B（gameplay_planner）

# 批判 Agent 终裁：两份方案均不可直接执行，需返工

## 一、致命冲突（必须先裁决，否则两方案互相抵消）

### C1. `ambient_key` 通道：两方案给出相反结论，且都未真正验证
- 主方案 G0.2 断言"无消费方 → 复用 `music_key`"，但**这是假设，不是验证结果**。它把"我猜没有"写成了"裁决"。
- 独立方案 G0.3 同样未跑，却直接**新建 `_ambient_player` + `Ambient` bus**。
- **返工要求**：两方案都必须在 `docs/AUDIO_FACTS.md` 里贴出 `grep -rn "ambient_key" --include=*.gd .` 的**原始输出**。空输出才允许走"复用 music_key"；非空必须列出消费点文件:行号。**未贴原始输出前，任何关于通道的裁决作废。**

### C2. 主方案 D2 自相矛盾
> "`music_key` 值以 `*_ambient` 结尾者为环境音，以 `*_theme` 结尾者为短音乐"

但 §3.3 又让 `festival_theme` 通过 `play_music` 播放，8s 后 `_refresh_ambient_track()` 切回。**问题**：`_refresh_ambient_track` 读的是 `music_key` 列，而 `festival_theme` 不在 CSV 里。切回逻辑依赖 `FestivalManager.active_event_id` 是否仍有效——主方案 R7 自己承认这个风险，却没给判定条件。
- **返工要求**：给出 `_refresh_ambient_track()` 的**完整现有实现**（贴代码），并证明 8s 后调用它不会读到 `festival_theme` 自身造成死循环。

### C3. 独立方案 §3.4 的映射表是**新造事实**
> "`ambient_key` 列现有值（`street_crowd`/`factory_hum` 等）不直接用作文件名"

**这些值从哪来的？** 独立方案没有贴 `scene_metadata.csv` 的 `ambient_key` 列实际内容。如果该列是空的，整个 §3.4 映射表就是凭空发明。
- **返工要求**：贴出 `scene_metadata.csv` 中 `ambient_key` 列的**全部非空值**。若为空，独立方案 §3.4 整表删除，改为"新增 `ambient_key` 值"并说明谁写入。

---

## 二、死代码与不可触达机制

### C4. 主方案 §5.3 的 11 个 SFX 触发点，至少 5 个是死代码
主方案自己承认 R3"文件不存在则降级 P2"，但**清单里没有任何一个触发点标注了"已验证存在"**。`craft_manager.gd`、`kitchen_manager.gd`、`pet_interactable.gd`、`festival_manager.gd` 是否真实存在？函数名 `start_craft` / `place_order` / `on_tap` 是否真实？
- **返工要求**：对 §5.3 每一行执行 `grep -n "func <函数名>" <文件>`，把**原始输出**贴进方案。不存在的行直接删除，不得保留"降级 P2"这种模糊话术。

### C5. 独立方案 Layer B 的"随机触发"机制不存在
> `_ambient_detail_timer: Timer  # 新增，随机触发 Layer B`

**谁创建这个 Timer？谁决定触发哪个 detail？触发间隔多少？** 独立方案 §3.2 只声明了字段，没有 `_ready` 里的实例化代码，没有 `timeout` 连接，没有 detail 选择逻辑。这是**声明即死代码**。
- **返工要求**：给出 `_ambient_detail_timer` 的完整生命周期代码（创建、连接、随机选池、播放、重启），或删除该机制。

### C6. 独立方案 Layer D 自我否定
§2.5 说"默认不生成 Layer D"，但 §4.1 表格里 Layer D 又列了 Suno 生成方式，§2.5 表格里 4 个 `mus_*` 也还在。**到底生成不生成？**
- **返工要求**：二选一。若生成，给出触发点和 `music_key` 绑定；若不生成，删除 §2.5 表格和 §4.1 的 Layer D 行。

### C7. 主方案 §3.3 的 `menu_theme` 无触发点
> "`menu_theme` 由主菜单 `_ready` 调用"

主菜单场景文件路径是什么？`_ready` 里现有代码是什么？`play_music("menu_theme")` 会不会和 `menu_ambient` 冲突（同一通道）？
- **返工要求**：贴主菜单场景路径 + `_ready` 现有代码。若主菜单已调用 `play_music("menu_ambient")`，则 `menu_theme` 是**不可达**的。

---

## 三、存档风险

### C8. 两方案都声称"音频不入档"，但都没验证
- 主方案 D1 是**断言**，不是验证。
- 独立方案完全没提存档。
- **返工要求**：执行 `grep -rn "save\|load\|persist" --include=*.gd autoload/ | grep -i "audio\|music\|ambient\|sfx"`，贴原始输出。空输出才能写"音频不入档"。

### C9. 独立方案新增 `data/audio_bindings.csv` 是**新存档面**
如果 `audio_bindings.csv` 被 `PresentationManager` 读取并缓存，而缓存字段进了存档（哪怕只是 `current_ambient_id`），就是存档兼容风险。
- **返工要求**：明确 `audio_bindings.csv` 是**运行时只读**，且 `current_ambient_id` 等状态**不写入任何 save 文件**。给出 save 文件字段清单证明。

---

## 四、测试漏洞

### C10. 主方案 §6.1 A6 断言不可实现
> "所有 `*_ambient.wav` 首尾 100ms 能量差 ≤ 3dB（可循环）"

**能量差怎么算？** RMS？峰值？频带？没有定义。且 3dB 是主观阈值，不同内容差异巨大。
- **返工要求**：给出 `verify_audio.py` 中 A6 的**具体算法**（如：首 100ms RMS 与尾 100ms RMS 之差），并说明为何 3dB 是合理阈值。

### C11. 主方案 §6.1 A8/A9 的频谱占比阈值无依据
> "8kHz 以上能量占比 ≤ 5%" / "60Hz 以下 ≤ 10%"

这两个数字从哪来？是否对所有场景（河畔有高频水声、家庭有低频水壶）都适用？
- **返工要求**：给出阈值来源（参考标准/实测基线），或改为**分场景阈值表**。

### C12. 独立方案 §6.1 的 LUFS 验收与 §4.3 的 `loudnorm I=-18` 冲突
`loudnorm` 是**两遍处理**（first pass 测，second pass 归一），独立方案只写了一行命令，实际是单遍，达不到精确 -18 LUFS。
- **返工要求**：给出完整两遍 `loudnorm` 命令，或改为 `-af loudnorm=I=-18:TP=-2:LRA=8:print_format=json` 并说明如何用 first pass 结果。

### C13. 两方案都缺"音频禁用"回归测试
主方案 C3 提到 `--smoke-test` 下 `_audio_disabled == true`，但没验证**新增的 `_ambient_player` 是否也遵守 `_audio_disabled`**。独立方案 §3.2 的 `play_ambient` 有 `if _audio_disabled: return`，但 `_ambient_player` 本身在 `_ready` 里创建后**没有在 smoke-test 下被禁用**。
- **返工要求**：给出 `_audio_disabled` 为 true 时，`_ambient_player` 的完整禁用路径（不播放、不加载、不占资源）。

### C14. 独立方案 §6.3 A7 的"0.5s 淡出淡入"无实现
> "切换场景时，ambient 在 0.5s 内淡出淡入（需新增 fade，见 §7）"

§7 步骤 4 只说"新增 fade"，**没有 fade 代码**。
- **返工要求**：给出 `_fade_ambient_out()` / `_fade_ambient_in()` 的完整实现，或删除 A7 断言。

---

## 五、命名与接入路径冲突

### C15. 两方案命名规范互斥
- 主方案：`street_ambient` / `pickup`（无前缀）
- 独立方案：`amb_village_bed` / `det_bike_bell` / `sfx_plant_seed`（有前缀）

**现有 `assets/audio/` 里到底是哪种？** 两方案都没贴 `ls assets/audio/` 的原始输出。
- **返工要求**：贴 `ls -1 assets/audio/` 和 `ls -1 assets/audio/formal/`（若存在）的完整输出。命名规范必须与**现有文件**一致，不得发明新前缀。

### C16. 主方案 §5.1 禁止 `sfx_pickup`，但独立方案 §2.4 用 `sfx_plant_seed`
两方案对"新增 SFX 是否加 `sfx_` 前缀"直接冲突。
- **返工要求**：以现有 `assets/audio/` 中**已存在的 SFX 文件名**为准。若现有是 `pickup.wav`，则新增必须 `plant_seed.wav`；若现有是 `sfx_pickup.wav`，则新增必须 `sfx_plant_seed.wav`。

### C17. 独立方案 §3.1 新建 `default_bus_layout.tres` 会破坏 `SettingsManager`
主方案 G0.5 明确"不新增总线，避免改动 SettingsManager 音量链路"。独立方案直接新建 4 bus，**没有说明 `SettingsManager.master_volume` 如何映射到新 bus**。
- **返工要求**：给出 `SettingsManager` 现有音量代码（贴源码），并说明新增 bus 后 `master_volume` 如何影响 `Music`/`Ambient`/`SFX`/`UI` 四个 bus。若无法说明，删除 §3.1。

---

## 六、生成方式的可执行性

### C18. 主方案 §4.1 的 `synth_ambient` 签名是伪代码
> `spec = {duration, layers: [{type, freq, amp, mod}], loop_point}`

**`type` 的取值域是什么？`mod` 是 LFO 还是包络？`loop_point` 是秒还是采样点？** 没有定义就无法实现。
- **返工要求**：给出 `spec` 的完整 schema（每个字段的类型、取值范围、默认值），以及至少 1 个场景（如 `street_ambient`）的完整 spec 实例。

### C19. 独立方案 §4.2 的 Suno prompt 不可复现
Suno 是**闭源在线服务**，同一 prompt 两次生成结果不同，且**无法保证 30s 循环无缝**。
- **返工要求**：若坚持 Suno，必须给出**后处理无缝化方案**（如交叉淡化拼接），或改为 Freesound CC0 采样拼接。

### C20. 独立方案 §4.3 的 ffmpeg 命令缺 `-y` 和输出路径
```bash
ffmpeg -i input.wav -af "..." -ar 22050 -ac 1 -sample_fmt s16 output.wav
```
**批量处理时 `input.wav` / `output.wav` 如何遍历？** 没有循环脚本。
- **返工要求**：给出完整的批量后处理脚本（bash 或 python），包含遍历、命名、错误处理。

---

## 七、返工优先级（按阻塞程度）

| 优先级 | 条目 | 阻塞什么 |
|---|---|---|
| P0 | C1, C3, C15, C16 | 通道裁决 + 命名基线，不定则全部作废 |
| P0 | C4, C5, C7 | 死代码，不定则触发点清单不可信 |
| P1 | C2, C6, C17 | 架构自洽性 |
| P1 | C8, C9 | 存档兼容 |
| P2 | C10, C11, C12, C13, C14 | 验收标准可执行性 |
| P2 | C18, C19, C20 | 生成方式可复现性 |

---

## 八、给两方案的统一返工模板

每份方案必须补齐以下**原始输出**（不得转述、不得"预期"）：

1. `ls -1 assets/audio/` 完整输出
2. `ls -1 assets/audio/formal/` 完整输出（若存在）
3. `grep -rn "ambient_key" --include=*.gd .` 完整输出
4. `grep -rn "play_sfx\|play_music" --include=*.gd .` 完整输出
5. `scene_metadata.csv` 的 `music_key` + `ambient_key` 两列完整内容
6. `audio_manager.gd` 的 `_refresh_ambient_track` 完整实现
7. `presentation_manager.gd` 的 `get_scene_music_key` 完整实现
8. `SettingsManager` 的音量相关代码
9. `project.godot` 中 `[audio]` 段完整内容
10. 存档文件字段清单（或"无音频字段"的 grep 证明）

**未补齐以上 10 项前，两方案均不得进入执行阶段。**

## 综合决策

# 《深城日常》温柔治愈音频方向与批量资产方案（终裁·唯一可执行版）

> 综合决策 Agent 终裁。合并主方案、独立方案、批判 A、批判 B。
> **本方案不发明任何事实。** 所有"现有"陈述均标注为**待门禁验证**，门禁未过不得生成资产。
> 硬约束：温柔治愈、生活质感、拒绝压抑工业噪声与赛博霓虹感、无任务面板、无数值属性条、存档兼容。

---

## 0. 决策（先拍板，含对批判的裁决）

### 0.1 架构裁决

| # | 争议 | 终裁 | 依据 |
|---|---|---|---|
| **D1** | 是否新增 Ambient 通道 | **不新增。复用 `music_key` 单通道。** | 批判 B C17 + 批判 A B1：新增 AudioBus 会破坏 `SettingsManager.master_volume` 链路（现有只控 Master）。改动面最小。 |
| **D2** | 是否新增 `data/audio_bindings.csv` | **不新增。** 扩展 `scene_metadata.csv` 加 `ambient_bed` / `detail_pool` 两列。 | 批判 A B2 + 批判 B C9：禁止双 CSV 双源。 |
| **D3** | 环境音 vs 短音乐 | **同一通道，按场景切换。** `music_key` 值以 `_ambient` 结尾为环境音，`_theme` 结尾为短音乐。 | 现有 `_refresh_ambient_track` 已按 `music_key` 播放。 |
| **D4** | 短音乐触发点 | **不新增信号连接，仅在已连接函数内新增调用。** `menu_theme` 若主菜单脚本不存在则**删除该资产**，不写"降级 P2"。 | 批判 A A3 + 批判 B C7。 |
| **D5** | 工厂音色 | **机械声不删除，低通 800Hz + 降 10dB 推远景。** 前景是人活动声。 | 独立方案 §1.2 正确，保留生活质感。 |
| **D6** | 生成方式 | **程序化合成优先**（`tools/generate_audio.py`），Freesound CC0 采样为备选。**禁止 Suno/Udio**（不可复现、版权不明）。 | 批判 B C19 + 批判 A B6。 |
| **D7** | 命名 | **以 `ls -1 assets/audio/` 实际输出为准**（门禁 G0.6）。现有是 `pickup.wav` 则新增 `plant_seed.wav`；现有是 `sfx_pickup.wav` 则新增 `sfx_plant_seed.wav`。**门禁前不得写死命名。** | 批判 B C15/C16。 |
| **D8** | 覆盖路径 | 正式资源放 `assets/audio/formal/`，与 `get_resolved_audio_path` 优先规则一致。 | 现有代码事实。 |
| **D9** | 音量 | **不新增音量参数。** 环境音 `-8dB`、SFX `-4dB`（现有默认），由 `SettingsManager.master_volume` 统一调制。 | 现有 `_apply_volume` 已实现。 |
| **D10** | Layer D 短音乐 | **本批不生成 `mus_*`。** 用现有 `day_ambient` / `night_ambient` / `festival_ambient` 覆盖。 | 批判 A B3 + 批判 B C6：删除死架构。 |
| **D11** | Detail 随机触发 | **本批不实现 `_ambient_detail_timer`。** 环境音细节直接混入 Bed 内。 | 批判 A B7 + 批判 B C5：声明即死代码，本批不做。 |
| **D12** | 节日切回 | **用场景切换 token 防错位**，不用裸 `await`。 | 批判 A A1。 |

### 0.2 对批判的逐条回应

| 批判条目 | 裁决 | 处理 |
|---|---|---|
| A1 节日 await 崩溃 | **采纳** | D12：加 `_scene_switch_token` |
| A2 ambient_key 死字段矛盾 | **采纳** | 门禁 G0.2 必须先跑；§3.1 资产清单改为"待验证" |
| A3 短音乐触发点定义 | **采纳** | D4：定义"触发点 = 信号连接点" |
| A4 存档字段未验证 | **采纳** | 门禁 G0.7 |
| A5 循环相位断言 | **采纳** | §6.1 A6b 加相位连续性 |
| A6 SFX 触发点未验证 | **采纳** | 门禁 G0.4 先跑，不存在的直接删 |
| A7 木质音色合成 | **采纳** | §4.1 明确 Karplus-Strong / FM 1.5 |
| B1 AudioBus 破坏音量 | **采纳** | D1：不新增 bus |
| B2 双 CSV 冲突 | **采纳** | D2：扩展 `scene_metadata.csv` |
| B3 Layer D 死架构 | **采纳** | D10：本批不生成 |
| B4 ambient 重启 | **采纳** | §5.2 加 `_current_ambient_id` 去重 |
| B5 loudnorm 双遍 | **采纳** | §4.3 用双遍 |
| B6 Suno 版权 | **采纳** | D6：禁止 Suno |
| B7 detail timer 无实现 | **采纳** | D11：本批不做 |
| C1 受影响测试映射 | **采纳** | §6.5 映射表 |
| C2 读档音频状态 | **采纳** | §6.4 D3 断言 |
| C3 真实窗口门禁 | **采纳** | §6.3 C6 独立 job |
| C4 经济门禁 | **采纳** | §6.6 明确"音频不参与经济" |
| 批判B C1 ambient_key 未验证 | **采纳** | 门禁 G0.2 |
| 批判B C2 D2 自相矛盾 | **采纳** | §5.2 给完整 `_refresh_ambient_track` 逻辑 |
| 批判B C3 映射表新造事实 | **采纳** | 门禁 G0.2 贴原始输出 |
| 批判B C4 死代码 | **采纳** | 门禁 G0.4 |
| 批判B C5 detail timer | **采纳** | D11 |
| 批判B C6 Layer D | **采纳** | D10 |
| 批判B C7 menu_theme | **采纳** | D4 |
| 批判B C8 存档未验证 | **采纳** | 门禁 G0.7 |
| 批判B C9 新存档面 | **采纳** | D2：不新增 CSV |
| 批判B C10 A6 不可实现 | **采纳** | §6.1 A6 给算法 |
| 批判B C11 频谱阈值无依据 | **采纳** | §6.1 A8/A9 改分场景表 |
| 批判B C12 LUFS 冲突 | **采纳** | §4.3 双遍 |
| 批判B C13 禁用回归 | **采纳** | §6.3 C7 |
| 批判B C14 fade 无实现 | **采纳** | §5.2 给 fade 代码 |
| 批判B C15/C16 命名冲突 | **采纳** | D7 + 门禁 G0.6 |
| 批判B C17 AudioBus | **采纳** | D1 |
| 批判B C18 spec 伪代码 | **采纳** | §4.1 给完整 schema |
| 批判B C19 Suno | **采纳** | D6 |
| 批判B C20 ffmpeg 批量 | **采纳** | §4.3 给脚本 |

---

## 1. 前置门禁（阻塞性，未过不得生成任何资产）

所有命令输出**原文**写入 `docs/AUDIO_FACTS.md`。**禁止转述、禁止"预期"、禁止"若存在则"。**

### G0.1 现有音频真实格式与时长
```bash
python -c "
import wave,glob
for p in sorted(glob.glob('assets/audio/**/*.wav',recursive=True)):
    try:
        w=wave.open(p); print(p, w.getnchannels(), w.getframerate(), w.getsampwidth()*8, round(w.getnframes()/w.getframerate(),2))
    except Exception as e: print(p,'ERR',e)
"
```
**裁决**：记录多数派格式。新资产必须与多数派一致。

### G0.2 `ambient_key` 是否被消费（关键）
```bash
grep -rn "ambient_key" --include=*.gd .
```
**裁决**：
- **空输出** → `ambient_key` 是死字段。本方案**不激活它**，环境音走 `music_key`。`ambient_key` 列保留不动。
- **非空** → 贴出消费点文件:行号，按其接口生成。

### G0.3 `PresentationManager.get_scene_music_key` 实现
```bash
grep -n "func get_scene_music_key" -A 20 autoload/presentation_manager.gd
```
**裁决**：确认读 CSV 还是硬编码。硬编码 → 本方案第一步改为读 CSV。

### G0.4 现有 SFX 触发点全集
```bash
grep -rn "play_sfx\|play_music" --include=*.gd autoload/ scripts/ | sort -u
```
**裁决**：列出所有已调用 id。新增 id 不得冲突。

### G0.5 音频总线配置
```bash
grep -n "bus\|Master\|Music\|SFX" project.godot | head -20
grep -n "set_bus_volume_db\|master_volume" -r autoload/settings_manager.gd
```
**裁决**：确认现有 bus 布局与 `SettingsManager` 音量链路。**本方案不改动。**

### G0.6 现有音频文件命名基线
```bash
ls -1 assets/audio/
ls -1 assets/audio/formal/ 2>/dev/null || echo "formal/ 不存在"
```
**裁决**：命名规范以实际输出为准。**门禁前不得写死命名。**

### G0.7 存档字段验证
```bash
grep -rn "save\|load\|persist" --include=*.gd autoload/ | grep -i "audio\|music\|ambient\|sfx\|volume"
```
**裁决**：列出所有入档音频字段。空输出才能写"音频不入档"。

### G0.8 `scene_metadata.csv` 完整内容
```bash
python -c "
import csv
for r in csv.DictReader(open('data/scene_metadata.csv')):
    print(r.get('area_id'), '|', r.get('music_key',''), '|', r.get('ambient_key',''))
"
```
**裁决**：列出 `area_id` / `music_key` / `ambient_key` 三列全部值。

### G0.9 `_refresh_ambient_track` 完整实现
```bash
grep -n "func _refresh_ambient_track" -A 30 autoload/audio_manager.gd
```
**裁决**：贴出完整实现，作为 §5.2 修改基线。

### G0.10 主菜单脚本路径
```bash
grep -rn "func _ready" scripts/ui/main_menu*.gd 2>/dev/null || echo "主菜单脚本不存在"
```
**裁决**：不存在 → `menu_theme` 资产删除。

---

## 2. 八场景音频方向（温柔治愈 + 生活质感）

> 每场景给出：听觉意象 / 禁止项 / 主色对应 / 时长 / 循环点

### 2.1 城中村（`street` / `home` / `night_market`）
- **听觉意象**：远处自行车铃、晾衣绳轻晃、邻居收音机漏音（戏曲/评书，极低）、猫叫、拖鞋踩水泥地、夜市木勺碰碗
- **禁止项**：汽车喇叭、施工电钻、警笛、电子广告屏
- **主色对应**：`#d8a75c` 暖橙 → 中频木质，无高频刺点
- **时长**：24s 循环
- **循环点**：第 8s 自行车铃、第 16s 碗碰（循环时错开）

### 2.2 早餐店（`breakfast_shop` / `breakfast_kitchen`）
- **听觉意象**：蒸笼揭盖"噗"、油条下锅细密"滋"、瓷碗轻碰、老板娘招呼（低音量、听不清词）、豆浆机低频嗡（柔化）
- **禁止项**：抽油烟机轰鸣、金属锅铲刮铁、高压锅尖叫
- **主色对应**：`#e8c26a` 暖黄 → 中低频饱满，高频衰减
- **时长**：20s 循环
- **循环点**：第 5s 蒸笼、第 12s 碗碰、第 18s 招呼

### 2.3 工厂（`factory` / `industrial_district`）
- **听觉意象**：**远处**规律轻响（每 2s 一次，-24dB）、通风口柔风、工人低语、传送带橡胶摩擦（柔化）
- **禁止项**：冲压机、气锤、金属撞击、电流嗡鸣、警报
- **主色对应**：`#8fc6bf` 雾青 → 中频柔和，无低频压迫
- **时长**：28s 循环
- **循环点**：两次轻响之间

### 2.4 河畔（`riverside` / `seaside_resort`）
- **听觉意象**：水波轻拍、芦苇沙沙、远处渡轮汽笛（极低、单次）、水鸟、风吹衣角
- **禁止项**：快艇、马达、码头机械
- **主色对应**：`#6faa8d` 水绿 → 宽频柔和，高频有空气感
- **时长**：32s 循环
- **循环点**：第 10s 水鸟、第 22s 汽笛（单次，循环时错开）

### 2.5 农田（`farm` / `farm_livestock` / `suburb`）
- **听觉意象**：风吹麦浪、鸡叫、远处牛铃、锄头入土、溪水细流
- **禁止项**：拖拉机、收割机、农药喷洒
- **主色对应**：`#7fae7a` 草绿 → 中频自然，无电子感
- **时长**：30s 循环
- **循环点**：第 6s 鸡叫、第 15s 牛铃、第 24s 锄头

### 2.6 宠物（`pet_store`）
- **听觉意象**：猫呼噜、小狗轻喘、爪子踩木地板、铃铛项圈轻响、鸟笼细鸣
- **禁止项**：犬吠连叫、猫尖叫、笼子金属碰撞
- **主色对应**：`#d99a8f` 暖粉 → 中高频柔和，无刺点
- **时长**：22s 循环
- **循环点**：第 4s 呼噜、第 11s 爪步、第 18s 铃铛

### 2.7 节日（`festival_ambient`，跨场景复用）
- **听觉意象**：远处锣鼓（柔化、低音量）、人群笑语（听不清词）、灯笼纸摩擦、糖画勺碰锅、鞭炮**远景**（单次、极低）
- **禁止项**：近景鞭炮、电子鞭炮、扩音喇叭
- **主色对应**：`#e8b45e` 暖金 → 中频木质 + 人声
- **时长**：26s 循环
- **循环点**：第 7s 锣鼓、第 14s 笑语、第 21s 糖画

### 2.8 家庭（`home` / `home_living`）
- **听觉意象**：挂钟秒针、水壶将沸未沸细响、翻书页、窗外远处车流（极低）、木地板轻响
- **禁止项**：电视广告、手机通知、空调外机
- **主色对应**：`#d98a83` 暖粉 → 中低频温暖
- **时长**：36s 循环（最长，营造"待得住"感）
- **循环点**：第 12s 翻书、第 24s 水壶、第 30s 地板

---

## 3. 资产清单（待门禁 G0.6/G0.8 确认后定稿）

> **命名以 G0.6 实际输出为准。** 下表用占位符 `<prefix>` 表示，门禁后替换。

### 3.1 环境音（`music_key` 承载）

| # | audio_id | 场景 | 时长 | 状态 |
|---|---|---|---|---|
| A01 | `<prefix>street_ambient` | 城中村主街 | 24s | 待 G0.8 确认 |
| A02 | `<prefix>home_ambient` | 出租屋 | 36s | 待确认 |
| A03 | `<prefix>night_market_ambient` | 夜市 | 24s | 待确认 |
| A04 | `<prefix>breakfast_ambient` | 早餐店前厅 | 20s | 待确认 |
| A05 | `<prefix>kitchen_ambient` | 早餐店后厨 | 20s | 待确认 |
| A06 | `<prefix>industrial_ambient` | 工业区/工厂 | 28s | 待确认 |
| A07 | `<prefix>riverside_ambient` | 河畔 | 32s | 待确认 |
| A08 | `<prefix>farm_ambient` | 农田/城郊 | 30s | 待确认 |
| A09 | `<prefix>livestock_ambient` | 农场圈舍 | 30s | 待确认 |
| A10 | `<prefix>store_ambient` | 便利店/宠物店 | 22s | 待确认 |
| A11 | `<prefix>festival_ambient` | 节日 | 26s | 待确认 |
| A12 | `<prefix>commercial_ambient` | 商业区 | 26s | 待确认 |
| A13 | `<prefix>market_ambient` | 旧货市场 | 24s | 待确认 |
| A14 | `<prefix>park_ambient` | 社区公园 | 28s | 待确认 |
| A15 | `<prefix>restaurant_ambient` | 餐馆 | 22s | 待确认 |
| A16 | `<prefix>workshop_ambient` | 手艺工坊 | 24s | 待确认 |
| A17 | `<prefix>university_ambient` | 夜校/大学 | 26s | 待确认 |
| A18 | `<prefix>clinic_ambient` | 诊所 | 24s | 待确认 |
| A19 | `<prefix>travel_ambient` | 巴士站/海边/古镇/温泉 | 28s | 待确认 |
| A20 | `<prefix>high_end_ambient` | 高端住宅区 | 26s | 待确认 |
| A21 | `<prefix>ruins_ambient` | 旧址深处 | 24s | 待确认 |
| A22 | `<prefix>day_ambient` | 默认白天 | 30s | 待确认 |
| A23 | `<prefix>night_ambient` | 默认夜晚 | 30s | 待确认 |
| A24 | `<prefix>rain_ambient` | 雨天 | 28s | 待确认 |
| A25 | `<prefix>menu_ambient` | 主菜单 | 32s | 待确认 |

**裁决**：**不新增 id**。本批任务是**重制音色**（去工业噪声、去霓虹感）。若 G0.8 显示某 `music_key` 无对应文件，则该场景当前无音频，本批**新增**该文件。

### 3.2 交互音（SFX）

| # | sfx_id | 触发点 | 时长 | 音色方向 | 状态 |
|---|---|---|---|---|---|
| S01 | `<prefix>pickup` | 拾取普通物品 | ≤0.4s | Karplus-Strong 拨弦 + 低通 | 待 G0.4 确认 |
| S02 | `<prefix>legendary_pickup` | 拾取稀有物品 | ≤0.8s | 拨弦 + 风铃（无 shimmer） | 待确认 |
| S03 | `<prefix>coin` | 金钱变化 | ≤0.3s | 双 sine（基频 + 2.76 倍频，瓷碗） | 待确认 |
| S04 | `<prefix>soft_confirm` | 正向提示 | ≤0.5s | 木琴单音（C5） | 待确认 |
| S05 | `<prefix>soft_warning` | 警告提示 | ≤0.5s | 木琴单音（A4，柔和） | 待确认 |
| S06 | `<prefix>door_open` | 场景切换 | ≤0.6s | 木门轴轻响 | 待确认 |
| S07 | `<prefix>serve_bell` | 出餐 | ≤0.5s | FM 指数 1.5 + 快速衰减 | 待确认 |
| S08 | `<prefix>ui_open` | 打开 UI | ≤0.3s | 纸页翻动 | 待确认 |
| S09 | `<prefix>ui_close` | 关闭 UI | ≤0.3s | 纸页合上 | 待确认 |
| S10 | `<prefix>plant_seed` | 播种 | ≤0.4s | 土块轻落 | **待 G0.4 确认触发点存在** |
| S11 | `<prefix>water_plant` | 浇水 | ≤0.6s | 水壶细流 | 待确认 |
| S12 | `<prefix>harvest` | 收获 | ≤0.5s | 果实入篮 | 待确认 |
| S13 | `<prefix>pet_interact` | 摸宠物 | ≤0.5s | 呼噜短句 | 待确认 |
| S14 | `<prefix>feed_pet` | 喂宠物 | ≤0.5s | 碗碰 + 轻嚼 | 待确认 |
| S15 | `<prefix>craft_start` | 开始手艺 | ≤0.6s | 工具轻放 | 待确认 |
| S16 | `<prefix>craft_done` | 完成手艺 | ≤0.8s | 木器轻敲 | 待确认 |
| S17 | `<prefix>order_place` | 点餐 | ≤0.4s | 木牌轻放 | 待确认 |
| S18 | `<prefix>order_serve` | 上菜 | ≤0.5s | 瓷盘轻放 | 待确认 |
| S19 | `<prefix>festival_gong` | 节日开始 | ≤1.0s | 远处锣（柔化） | 待确认 |
| S20 | `<prefix>home_clock` | 家庭场景整点 | ≤0.4s | 挂钟单响 | 待确认 |

**裁决**：S10–S20 的触发点**必须先在 G0.4 确认存在**。不存在的行**直接删除**，不写"降级 P2"。

### 3.3 短音乐

| # | audio_id | 触发点 | 时长 | 状态 |
|---|---|---|---|---|
| M01 | `<prefix>festival_theme` | 节日开始（替换 `festival_ambient` 前 8s） | 8s | **待 G0.4 确认 `_on_festival_started` 存在** |
| M02 | `<prefix>menu_theme` | 主菜单 `_ready` | 12s | **待 G0.10 确认主菜单脚本存在，否则删除** |

**裁决**：**不新增信号连接**。仅在已连接函数内新增 `play_music` 调用。主菜单脚本不存在 → M02 删除。

---

## 4. 生成方式（程序化合成）

### 4.1 `tools/generate_audio.py` 完整 schema

```python
# spec 完整定义
AmbientSpec = {
    "duration": float,          # 秒，20–36
    "channels": int,            # 按 G0.1 多数派
    "rate": int,                # 按 G0.1 多数派
    "layers": [                 # ≥ 3 层
        {
            "type": str,        # "sine" | "triangle" | "pink_noise" | "brown_noise" | "karplus"
            "freq": float,      # Hz，仅 sine/triangle/karplus 有效
            "amp": float,       # 0.0–1.0
            "lfo": {            # 可选
                "rate": float,  # 0.1–0.5 Hz
                "depth": float  # 0.0–1.0
            },
            "filter": {         # 可选
                "type": str,    # "lowpass" | "highpass"
                "cutoff": float # Hz
            }
        }
    ],
    "crossfade_ms": int,        # 首尾交叉淡化，默认 50
    "loop_point": float         # 秒，默认 duration
}

SfxSpec = {
    "duration": float,          # ≤ 1.2
    "channels": int,
    "rate": int,
    "algorithm": str,           # "karplus" | "fm" | "dual_sine" | "noise_burst"
    "params": dict,             # 算法特定参数
    "envelope": {
        "attack_ms": float,     # ≥ 5
        "decay_ms": float,
        "sustain": float,       # 0.0–1.0
        "release_ms": float     # ≥ 50
    }
}
```

**合成规则（硬约束）**：
- **禁止**：`sawtooth`、`square`、`white_noise` 直接输出、`FM` 调制指数 > 2
- **允许**：`sine`、`triangle`、`pink_noise`（1kHz 低通）、`brown_noise`（500Hz 低通）、`karplus`、`FM` 指数 1.0–2.0
- **包络**：所有 SFX `attack ≥ 5ms`、`release ≥ 50ms`
- **环境音**：≥ 3 层，每层独立 LFO（0.1–0.5Hz），首尾 50ms 交叉淡化

**木质音色算法（回应批判 A7）**：
- `pickup`：Karplus-Strong（拨弦）+ 1kHz 低通
- `coin`：双 sine（基频 + 2.76 倍频，模拟瓷碗）
- `serve_bell`：FM 指数 1.5 + 快速衰减

**示例 spec（`street_ambient`）**：
```python
{
    "duration": 24.0,
    "channels": 1, "rate": 22050,
    "layers": [
        {"type": "pink_noise", "amp": 0.15, "filter": {"type": "lowpass", "cutoff": 2000}},
        {"type": "sine", "freq": 220, "amp": 0.05, "lfo": {"rate": 0.2, "depth": 0.3}},
        {"type": "brown_noise", "amp": 0.08, "filter": {"type": "lowpass", "cutoff": 500}},
        {"type": "sine", "freq": 880, "amp": 0.03, "lfo": {"rate": 0.15, "depth": 0.5}}
    ],
    "crossfade_ms": 50,
    "loop_point": 24.0
}
```

### 4.2 采购备选（仅当程序化无法达标）

| 来源 | 许可 | 适用 | 禁止 |
|---|---|---|---|
| Freesound.org | CC0 / CC-BY | 环境音底噪 | 需逐条听检，剔除工业/霓虹 |
| Pixabay Audio | Pixabay License | SFX | 同上 |
| 自制录音 | 自有 | 生活质感 | 需消音处理 |

**禁止 Suno/Udio**（不可复现、版权不明）。

### 4.3 后处理（双遍 loudnorm）

```bash
#!/bin/bash
# tools/postprocess_audio.sh
set -e
for f in assets/audio/formal/*.wav; do
    # 第一遍：测量
    ffmpeg -hide_banner -i "$f" -af loudnorm=I=-18:TP=-2:LRA=8:print_format=json -f null - 2> /tmp/loudnorm.json
    # 解析 JSON 取 measured_I / measured_TP / measured_LRA / measured_thresh / offset
    # 第二遍：应用
    ffmpeg -y -i "$f" -af "highpass=f=80,lowpass=f=12000,acompressor=threshold=-18dB:ratio=3:attack=20:release=200,loudnorm=I=-18:TP=-2:LRA=8:measured_I=<I>:measured_TP=<TP>:measured_LRA=<LRA>:measured_thresh=<TH>:offset=<OFF>:linear=true" -ar 22050 -ac 1 -sample_fmt s16 "$f.tmp.wav"
    mv "$f.tmp.wav" "$f"
done
```

### 4.4 构建集成

在 `tools/build.py` 中，**在 Godot 资源导入前**插入：
```python
subprocess.run([sys.executable, "tools/generate_audio.py"], check=True)
subprocess.run(["bash", "tools/postprocess_audio.sh"], check=True)
```

---

## 5. 接入路径

### 5.1 命名规范（以 G0.6 实际输出为准）

| 类型 | 模式 | 示例 |
|---|---|---|
| 环境音 | `<现有前缀><scene>_ambient` | 按 G0.6 |
| 短音乐 | `<现有前缀><scene>_theme` | 按 G0.6 |
| SFX | `<现有前缀><verb>_<noun>` | 按 G0.6 |

**门禁 G0.6 未跑前，不得写死任何文件名。**

### 5.2 代码层修改（`autoload/audio_manager.gd`）

**新增字段**：
```gdscript
var _scene_switch_token: int = 0
var _current_ambient_id: String = ""
```

**新增方法**：
```gdscript
func _on_scene_switched() -> void:
    _scene_switch_token += 1
    _refresh_ambient_track()

func _refresh_ambient_track() -> void:
    # 现有实现 + 去重
    var key := PresentationManager.get_scene_music_key(GameState.current_area)
    if key == _current_ambient_id and _music_player.playing:
        return  # 同 id 不重启
    _current_ambient_id = key
    # ... 现有加载播放逻辑
```

**节日切回（防错位）**：
```gdscript
func _on_festival_started(_day_key: String, _event_id: String) -> void:
    var token := _scene_switch_token
    play_music("festival_theme")
    await get_tree().create_timer(8.0).timeout
    if token != _scene_switch_token:
        return  # 场景已切换，放弃切回
    if FestivalManager.active_event_id.is_empty():
        return
    _refresh_ambient_track()
```

**Fade（回应批判 B C14）**：
```gdscript
func _fade_ambient_out(duration: float = 0.5) -> void:
    var tween := create_tween()
    tween.tween_property(_music_player, "volume_db", -40.0, duration)
    await tween.finished

func _fade_ambient_in(duration: float = 0.5) -> void:
    var tween := create_tween()
    tween.tween_property(_music_player, "volume_db", -8.0, duration)
    await tween.finished
```

### 5.3 数据层修改（`data/scene_metadata.csv`）

**不新增 CSV**。仅在现有 CSV 中：
- 保留 `music_key` 列
- `ambient_key` 列**不动**（G0.2 裁决后决定是否使用）

### 5.4 SFX 触发点（待 G0.4 确认后定稿）

| sfx_id | 触发文件 | 触发函数 | 状态 |
|---|---|---|---|
| `plant_seed` | 待 G0.4 | 待 G0.4 | **未验证** |
| `water_plant` | 待 G0.4 | 待 G0.4 | **未验证** |
| `harvest` | 待 G0.4 | 待 G0.4 | **未验证** |
| `pet_interact` | 待 G0.4 | 待 G0.4 | **未验证** |
| `feed_pet` | 待 G0.4 | 待 G0.4 | **未验证** |
| `craft_start` | 待 G0.4 | 待 G0.4 | **未验证** |
| `craft_done` | 待 G0.4 | 待 G0.4 | **未验证** |
| `order_place` | 待 G0.4 | 待 G0.4 | **未验证** |
| `order_serve` | 待 G0.4 | 待 G0.4 | **未验证** |
| `festival_gong` | 待 G0.4 | 待 G0.4 | **未验证** |
| `home_clock` | 待 G0.4 | 待 G0.4 | **未验证** |

**裁决**：G0.4 未跑前，本表**不得进入执行**。不存在的行直接删除。

---

## 6. 验证标准

### 6.1 格式验收（`tools/verify_audio.py`）

| 断言 | 算法 |
|---|---|
| A1 | 所有 `.wav` 声道数 == G0.1 多数派 |
| A2 | 所有 `.wav` 采样率 == G0.1 多数派 |
| A3 | 所有 `*_ambient.wav` 时长 ≥ 20s |
| A4 | 所有 SFX 时长 ≤ 1.2s |
| A5 | 所有 `.wav` 峰值 ≤ -1dBFS |
| A6 | 首 100ms RMS 与尾 100ms RMS 之差 ≤ 3dB |
| A6b | 首尾 10ms 样本差值 RMS ≤ -40dBFS（相位连续性） |
| A7 | 所有 SFX `attack ≥ 5ms` |
| A8 | 分场景高频阈值（见下表） |
| A9 | 分
