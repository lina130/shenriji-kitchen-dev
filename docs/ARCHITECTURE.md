# 技术架构

## 引擎基线

- Godot 4.2+，2D 俯视角，`canvas_items` 拉伸，1280×720 基准分辨率
- GL Compatibility 渲染器，像素纹理使用最近邻过滤
- GDScript 为主要实现语言
- 场景与玩法模块解耦，全部状态通过信号通信

## 全局系统

| Autoload | 职责 |
|---|---|
| `InputSetup` | 运行时注册稳定输入映射 |
| `ConfigDB` | 从 `data/*.csv` 读取固定物价与核心参数 |
| `RandomManager` | 可复现随机、每日刷新锚点 |
| `InventoryManager` | 极简自动堆叠背包与物品定义 |
| `NoticeManager` | 全感知弱提示总线 |
| `TimeSystem` | 分钟、小时、日期、睡眠与跳时 |
| `GameState` | 金钱、精力、健康、地点、房租与核心行为 |
| `SceneRouter` | 地点和出生点路由 |
| `SaveManager` | 单存档读写与版本迁移入口 |

## 场景结构

当前 MVP 使用代码生成的占位色块地图，正式美术阶段再替换为 TileMap 分层架构：

`Main → World → Player / Interactable / HUD`

地点通过 `GameState` 与 `SceneRouter` 切换，不保留常驻属性面板。

## 状态表现

- 精力低：画面轻微压暗、靠近临界时只提示一次、移动速度自然下降
- 时间：时钟只表达生活节奏，不显示“剩余精力”
- 金钱：只显示当前总额，不显示收入报表
- 交互：靠近后出现弱提示，不常驻感叹号