# 美术重构预留架构

后续美术大改不直接改业务逻辑，所有表现资源通过稳定 key 查询。

## 表现层入口

- `PresentationManager`：统一读取场景、角色、物品、UI、字体绑定。
- `data/scene_metadata.csv`：场景显示名、背景 key、音乐、环境音、UI 强调色。
- `data/visual_bindings.csv`：实体到 sprite / portrait / icon / font role 的映射。
- `data/theme_tokens.csv`：颜色、字体角色和字号 token。

## 美术目录约定

后续正式资源建议放在：

- `assets/art/scenes/<background_key>/`
- `assets/art/characters/<npc_id>/world.png`、`world_1..4.png`、`portrait.png`
- `assets/art/characters/<npc_id>/actions/<action>_1..4.png`
- 当前动作键：`work`、`eat`、`sleep`、`interact`、`pickup`
- `assets/art/items/<item_id>/icon.png`
- `assets/art/ui/<theme>/panel.png`、`button.png`
- `assets/fonts/<font_role>/`

代码只依赖 key，不依赖固定文件名。替换美术时改 CSV 绑定即可。

## 提示来源

所有短提示必须区分来源：

- `system`：存档、读档、版本、不可交互系统状态。
- `npc`：人物说的话、工作提示、剧情、员工事件。
- `scene`：物件、地点、环境和现场操作反馈。

NPC 提示必须符合该 NPC 的性格和用途；场景提示不能说成人物台词；系统提示不伪装成 NPC。

接口：
- `NoticeManager.show_system_message(...)`
- `NoticeManager.show_npc_message(...)`
- `NoticeManager.show_scene_message(...)`

## 正式资源覆盖

- 正式资源统一放到 `assets/art/formal/`，目录结构与程序化基线完全一致。
- `PresentationManager.get_resolved_asset_path()` 会优先读取 formal 下的同名文件；没有正式资源时才回退到程序化基线。
- 角色、场景、物品、UI 和字体绑定都不需要改业务代码，只替换 PNG 或调整 CSV 绑定即可。
- `assets/art/formal/README.txt` 记录了目录示例。

## 资产生成

首版像素资产由 `tools/generate_pixel_art.py` 生成，构建脚本会自动运行并先执行 Godot 资源导入。生成内容包括场景背景、四帧角色行走、五类动作帧、NPC 肖像、物品图标、UI 面板和按钮。该脚本是可复现占位基线，后续可直接替换 PNG 或扩展生成规则。

## 场景拆分原则

- 一个场景只承载一个主要节奏，避免交互物重叠。
- 前厅/后厨、室内/室外、经营区/生活区可以拆分。
- 新场景先登记 `scene_metadata.csv` 和 `SceneRouter.VALID_AREAS`，再接 World 交互。
- 碰撞只对应可见物体，不留无视觉依据的空气墙。
