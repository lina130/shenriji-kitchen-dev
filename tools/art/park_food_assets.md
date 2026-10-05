# 人才公园餐厅首批食物模型

十份菜品分别建模，ID 与 `TalentParkRestaurant3D.RECIPES` 完全一致。每份均有独立 `.blend` 源文件、Godot 可导入的 `.glb` 和 900×750 预览图。总览见 [`food_contact_sheet.png`](../../assets/art/models/food/food_contact_sheet.png)。生成脚本为 [`make_park_foods.py`](make_park_foods.py)。

| ID | 菜品 | 主体与器皿设计 |
| --- | --- | --- |
| `garden_rice_roll` | 青园蔬香米卷 | 三段米卷、切面露出青菜与胡萝卜丝、酱汁、白瓷椭圆盘 |
| `macao_spice_bun` | 香料海风包 | 双层软包、香煎鸡肉、紫洋葱、蔬菜、蘸酱和木板 |
| `morning_egg_bun` | 晨光鸡蛋包 | 开合软包、煎蛋、蛋黄、黄瓜、圆瓷盘 |
| `warm_tofu_bowl` | 暖姜豆花碗 | 玉色深碗、豆花块、姜糖水、桂花与小勺 |
| `coconut_millet` | 椰香小米盅 | 椰壳碗、奶香小米与可见谷粒、果丁果片、椰丝、莓果与薄荷 |
| `harbour_noodles` | 港湾拌面 | 蓝釉大碗、盘绕面条、青菜、辣油、筷子 |
| `chicken_rice` | 香煎鸡肉饭 | 米饭球、分切鸡排、酱汁、瓷盘和蘸碟 |
| `bay_shrimp_roll` | 湾畔鲜虾肠粉 | 虾仁露出的肠粉、豉油、青菜和长瓷盘 |
| `seaweed_dumpling` | 海苔青蔬饺 | 五只尖角月牙饺、青蔬馅与海苔点缀、竹蒸笼和蘸碟 |
| `fruit_ice` | 果香冰沙杯 | 磨砂杯、粉色冰沙、奶油、果粒、弯吸管和杯垫 |

## 接入约定

- 路径：`res://assets/art/models/food/<recipe_id>.glb`。
- 每份独立源文件：`tools/art/source/food/<recipe_id>.blend`。
- 每份预览：`assets/art/models/food/<recipe_id>_preview.png`。
- 单位为米，原点在器皿底部中心。glTF/Godot 中 `+Y` 向上、`+Z` 面向顾客。
- 平盘与碗的水平占地约 0.75–1.0 米；冰沙杯约 0.45 米宽。导入比例保持 1.0，放置时让模型原点落在台面高度。
- 模型只负责视觉。小型展示物无需逐块碰撞；餐台的整体交互碰撞应由场景统一控制。
- 单份 GLB 含 19–64 个网格节点，约 0.3–0.84 MiB。建议只实例化正在制作或出餐的菜品，批量陈列时可另制合批低模版。

各模型采用分层实体和柔和 PBR 粗糙度，没有烘焙文字或悬浮标牌。预览中的灰色地台与摄影灯不在导出 GLB 内。
