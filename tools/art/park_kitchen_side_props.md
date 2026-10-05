# 人才公园餐馆：两侧台面陈列素材

这四组资源是餐馆室内台面的正式陈列首版，依据现有柜台尺寸制作，取代六个短圆柱及两排小球占位件。源模型是可编辑的 Blender 文件；运行时用 GLB。生成脚本为 `tools/art/make_park_kitchen_side_props.py`，可用便携 Blender 后台重建。

| 资产 ID | 画面用途与可辨形体 | Blender 源文件 / GLB | 建议在 `_build_side_rooms` 中的 Godot 位置 |
| --- | --- | --- | --- |
| `park_kitchen_pantry_staples` | 米袋、面粉袋、三瓶不同内容物的调味罐、蒜辫 | `tools/art/source/kitchen/park_kitchen_pantry_staples.blend` / `assets/art/models/kitchen/park_kitchen_pantry_staples.glb` | `Vector3(-9.15, 1.26, -3.64)` |
| `park_kitchen_pantry_fresh` | 木条筐中的青菜与胡萝卜、敞开的六孔蛋盒 | `tools/art/source/kitchen/park_kitchen_pantry_fresh.blend` / `assets/art/models/kitchen/park_kitchen_pantry_fresh.glb` | `Vector3(-9.15, 0.815, 2.0)` |
| `park_kitchen_pickup_packing` | 折口打包纸袋、双层餐盒与封口饮料 | `tools/art/source/kitchen/park_kitchen_pickup_packing.blend` / `assets/art/models/kitchen/park_kitchen_pickup_packing.glb` | `Vector3(9.15, 0.96, -2.0)` |
| `park_kitchen_pickup_ready` | 两只木托盘、纸套餐包、饭卷餐盒与夹票 | `tools/art/source/kitchen/park_kitchen_pickup_ready.blend` / `assets/art/models/kitchen/park_kitchen_pickup_ready.glb` | `Vector3(9.0, 1.13, 0.72)` |

四组的原点均在台面表面，实际建模宽度各不超过约 2.4 米，深度按原柜台约 0.65～1.36 米。Blender 中 `-Y` 是面向玩家的一侧，导入 Godot 后对应场景的 `+Z`。既有柜体及顶板可保留；旧台面球体/圆柱陈列应移除。模型材质使用米白纸、蜂蜜木、青瓷、柔绿叶、胡萝卜橙及少量珊瑚色，避免过多同质圆球。

每组均有 `assets/art/models/kitchen/*_preview.png` 预览，已检查单资产形体及材质。集成后的实机宽屏和近景截图尚待检查，故当前不能把它们记为通过游戏内最终验收。四组均为静态陈列，不附带碰撞、交互或动画；后续若要把具体备货物品取放到柜台，应拆出独立可交互模型并建立对应状态。
