# 人才公园餐馆：左侧贴墙收纳架

- 资产 ID：`park_kitchen_wall_pantry`。
- 可编辑源：`tools/art/source/kitchen/park_kitchen_wall_pantry.blend`；重建脚本：`tools/art/make_park_kitchen_wall_pantry.py`。
- 游戏模型：`assets/art/models/kitchen/park_kitchen_wall_pantry.glb`；单资产预览：`assets/art/models/kitchen/park_kitchen_wall_pantry_preview.png`。
- 尺寸：沿墙约 **2.40 m**，从墙向室内伸出约 **0.62 m**，最高约 **1.85 m**。原点在现有地面，Blender 的 +X 指向餐馆室内。主材质是蜂蜜木、柔绿搪瓷、米色布和少量黄铜。
- 建议在 `_build_side_rooms()` 中通过 `_place_side_prop("park_kitchen_wall_pantry", Vector3(-10.82, 0.0, -0.55))` 放置。墙面中心线 `x=-10.95`；背板嵌入墙内约 2 cm，柜体最内侧到 `x≈-10.20`。沿场景 Z 跨约 `-1.75 … 0.65`，避开 `z=-3.64` 的干货台和 `z=2.0` 的鲜货台。NPC 基础位置 `x=-8.80`，与柜体留约 1.4 m。
- 柜体落地；层板由背板、立柱和托架支撑，布巾与炊具挂于实体铜钩，罐与篮筐接触层板。该模型暂为静态装饰，不含碰撞或点击区域，避免遮挡 NPC 和备货点击。
- Blender 单资产预览已人工检查：家具与物件接触关系正常。游戏内集成后仍须用正常宽屏和近景检查实际遮挡及尺度，未计作最终美术验收。
