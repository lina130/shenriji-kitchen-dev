# 技术架构

## 引擎基线

- Godot 4.2+，当前开发及导出验证版本为 4.7.2 stable。
- 2D 俯视角、1280×720 基准分辨率、GL Compatibility。
- GDScript 为主要语言，模块通过信号通信。
- 正式美术阶段仍以 TileMap 分层架构为最终方向；`0.1.0` 使用程序化绘制占位图。

## 全局系统

| Autoload | 职责 |
|---|---|
| `InputSetup` | 稳定输入映射 |
| `ConfigDB` | 读取 `data/*.csv` 固定配置，并支持导出后的 `.csv.txt` 回退 |
| `SettingsManager` | 全屏、主音量与设置持久化 |
| `RandomManager` | 每日可复现随机数 |
| `InventoryManager` | 自动堆叠背包、消耗品和收藏物 |
| `NoticeManager` | 短暂弱提示总线 |
| `TimeSystem` | 分钟、昼夜、日期、睡眠和跳时 |
| `WeatherSystem` | 每日天气及工作、摸金、店铺影响 |
| `CollectionManager` | 每日点位、稀有度、旧物册、出售 |
| `ProgressionManager` | 职业熟练、学习、锻炼与月结统计 |
| `RelationshipManager` | NPC 对话、喜好礼物和隐藏关系阶段 |
| `GameState` | 金钱、体感状态、工作、学习、睡眠、房租 |
| `AudioManager` | 氛围音乐、天气音和交互反馈 |
| `SceneRouter` | 地点与出生点路由 |
| `SaveManager` | 版本化 JSON 存档 |

## 运行结构

`Main → MainMenu / GameHUD / WorldRoot`

- `Main` 负责主菜单、新游戏、继续游戏和场景装配。
- `WorldRoot` 根据地点代码生成占位场景、NPC、交互物和每日摸金点。
- `GameHUD` 只承载必要功能界面和弱提示，不显示精力、健康、幸运、口碑数值。
- 所有 UI 中只有 `Esc` 主菜单暂停时间；背包、地图、账本、商店、对话打开时时间继续流逝。

## 配置发布策略

Godot 会将 `.csv` 自动识别为翻译资源，因此发行包采用双文件策略：

- `data/*.csv`：开发者维护的正式 CSV 源表。
- `data/*.csv.txt`：构建脚本自动生成的纯文本副本，用于导出 PCK 读取。

禁止只修改 `.csv.txt`；每次构建都会从 `.csv` 覆盖副本。