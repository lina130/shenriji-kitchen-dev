# 左侧贴墙备料柜

- 资产 ID：`park_kitchen_wall_prep_console`。源文件 `tools/art/source/kitchen/park_kitchen_wall_prep_console.blend`，导出 `assets/art/models/kitchen/park_kitchen_wall_prep_console.glb`，复现脚本 `tools/art/make_park_kitchen_wall_prep_console.py`。
- 放置：`_build_side_rooms()` 内世界坐标 `Vector3(-10.82, 0, -0.2)`，紧贴左侧边墙，柜顶约 0.74 m，高后挡板最高约 1.0 m，长约 2.48 m，向室内进深约 0.88 m。
- 设计目的：原先的 1.8 m 竖架在固定厨房俯视镜头中只剩窄侧面，横向三层架及挂钩在地面投出锯齿状大阴影。新柜采用一整块圆角石面、浅色矮后挡板、三扇青瓷色下柜门。顶面三个区域分别放青菜托盘、切配板与刀、米碗及调味瓶；俯视时功能分区与备料用途都能看见。
- 单资产预览：`assets/art/models/kitchen/park_kitchen_wall_prep_console_preview.png`，已目视检查。实机截图：`output/wall_pantry_rework_20260928/console_1280.png`，已目视检查。柜子在左墙形成清晰的三段式顶面，工作人员通道保留，旧竖架造成的锯齿形高阴影消失。整场景俯视时该柜仍偏窄，是墙边空间限制所致；后续如需要更醒目的备料区，应扩展场景左侧空间，而不是再加高层板。
- 静态室内陈列，暂不设置碰撞与取放动画。该柜不改变游戏玩法和存档结构。
