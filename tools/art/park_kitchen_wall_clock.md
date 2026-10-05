# 人才公园餐馆：右侧挂钟

- 资产 ID：`park_kitchen_wall_clock`。可编辑源 `tools/art/source/kitchen/park_kitchen_wall_clock.blend`；生成脚本 `tools/art/make_park_kitchen_wall_clock.py`；游戏模型 `assets/art/models/kitchen/park_kitchen_wall_clock.glb`。
- 尺寸：直径约 0.85 m，实心木壳厚约 0.17 m；材质为深木、米白搪瓷、少量黄铜和绿色刻度。
- Godot 中挂钟根节点位于 `Vector3(10.23, 1.30, -4.820)`，绕局部 X 轴旋转 90 度；钟身背面与右侧备餐间的实体后墙相接。后墙沿 `x=7.49…10.97` 延伸，并与主厨房隔墙及右侧墙衔接，中央后窗在 `x=-7.41…7.41`，因此不会被遮住。动态时针、分针是挂钟根节点子物体，继续使用游戏时间驱动。
- 时段灯位于右侧边柜顶面，各有实体圆形底座。
- Blender 单资产预览 `assets/art/models/kitchen/park_kitchen_wall_clock_preview.png`、游戏实际截图 `output/wall_clock_solid_wall_1280.png` 与 `output/wall_clock_solid_wall_1920.png` 已目视检查。游戏截图中钟面贴在完整后墙上，无遮挡后窗。
- `--talent-park-test` 当前因既有备货两份检查失败，详见 `output/wall_clock_kitchen_test.log`；挂钟资源导入及场景截图成功。
