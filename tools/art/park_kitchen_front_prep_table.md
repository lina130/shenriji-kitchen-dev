# 人才公园餐馆前排备餐桌

- 资产 ID：`park_kitchen_front_prep_table`。
- Blender 源文件：`tools/art/source/kitchen/park_kitchen_front_prep_table.blend`；复现脚本：`tools/art/make_park_kitchen_front_prep_table.py`。
- 运行时模型：`assets/art/models/kitchen/park_kitchen_front_prep_table.glb`。
- 单资产预览：`assets/art/models/kitchen/park_kitchen_front_prep_table_preview.png`；俯视检查图：`assets/art/models/kitchen/park_kitchen_front_prep_table_top_preview.png`。

## 尺寸与接入

模型原点在地面正中央，台面长 **14.0 m**、深 **2.05 m**；连续石面顶约高 0.675 m，五块实体落位板的内衬承载面统一高 **0.722 m**，边缘止挡最高约 0.761 m，服务铃略高。建议在当前厨房场景 `Vector3(0, 0, 3.90)` 以零旋转实例化。此时桌体后沿在世界 Z 约 2.875，前沿约 4.925；前缘会越过原有 z≈4.56 的前墙装饰条，接入时须一起调整那条装饰和前方活动空间。

台面已预留、但 **没有放置任何成品菜或半成品**：左侧两块半成品落位本地 X 为 **-5.65 / -3.83**，板宽各 1.56 m；中央组合双餐板中心 **-0.75**、板宽 **3.70 m**，能容纳 3.46 m 组合托盘并在两侧保留边距；单餐暂存板中心 **2.20**、宽 1.65 m；右侧交接板中心 **5.18**、宽 3.10 m。相邻板之间留 0.26～0.61 m 的石面间隔。建议动态托盘底部世界 Y 设为 **0.722 m**，按各板中心布置。左侧导轨、中央浅止挡、右侧夹票座和小服务铃均在空板边缘。

## 画面检查

已目视检查新版斜视图与俯视图：家具由七组独立腿架、六组带抽屉/开放碟格/青瓷门的柜仓、上下纵梁和连续圆角浅石台面组成；下柜门与腿架间有明确缝隙。五块落位板是有厚度的实体板，最高承载面比石面约高 4.7 cm，容器放在板上时不应有贴图感。暖木、浅石、青瓷、亚麻和少量黄铜沿用本店配色。单资产无角色碰撞、动画或可交互食物；游戏内近景截图与动态托盘交叠须在接入后确认。
