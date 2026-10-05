# 《深日记》本地模组接口

当前版本支持对配置表进行安全的数据扩展，不加载第三方脚本。

## 模组目录

将模组放在：

`user://mods/<mod_id>/`

实际 Windows 路径通常为：

`%APPDATA%\Godot\app_userdata\深日记\mods\<mod_id>\`

## mod.json

```json
{
  "id": "example_mod",
  "name": "示例模组",
  "version": "1.0.0",
  "game_version": "0.5.0",
  "description": "说明文字"
}
```

主次版本号必须与当前游戏一致，补丁版本可以不同。

## 数据文件

在模组目录下创建 `data/`，文件名必须与目标配置表同名：

```
mods/example_mod/
  mod.json
  data/
    items.csv
    recipes.csv
    random_events.csv
```

- 已存在的行按照主键覆盖。
- 新行会追加。
- NPC 日程和对话会追加多行。
- 未知配置表会被跳过并记录警告。
- 模组只能改数据，不能加载脚本，避免破坏存档和发行安全。

## 当前稳定配置表

items、collectibles、goods、recipes、calendar、festival_events、crops、farm_tools、farm_animals、random_events、scene_metadata、fish、housing、travel_destinations、enterprises、achievements、life_endings、hobbies、courses、pets、furniture、staff、npc_schedule、npc_dialogue、npc_stories、night_market、careers、clothing 等。

## 测试

`--world-systems` 会自动创建临时模组，验证 CSV 合并、运行时物品刷新和模组移除后的基础配置恢复。
