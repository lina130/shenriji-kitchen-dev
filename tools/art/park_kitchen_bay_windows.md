# 人才公园餐馆后墙窗景资产

当前厨房原有的后墙只有平面蓝绿色块。此组资源为同一套四开间木框全景窗的白天与夜间变体，窗内做了分层的深圳湾水面、人才公园绿地和后海楼群剪影。主框、横档、窗台、远景、步道栏杆、树、灯、海面反光都是可编辑的 Blender 实体，不含贴在场景里的地名文字。夜间楼宇窗户与步道灯使用轻微自发光材质；室内总体光线仍需由游戏灯光随时钟调整。

| 变体 | GLB | Blender 源文件 | 静态预览 |
| --- | --- | --- | --- |
| 白天 | `assets/art/models/kitchen/park_kitchen_bay_window_day.glb` | `tools/art/source/kitchen/park_kitchen_bay_window_day.blend` | `assets/art/models/kitchen/park_kitchen_bay_window_day_preview.png` |
| 夜间 | `assets/art/models/kitchen/park_kitchen_bay_window_evening.glb` | `tools/art/source/kitchen/park_kitchen_bay_window_evening.blend` | `assets/art/models/kitchen/park_kitchen_bay_window_evening_preview.png` |

生成源脚本为 `tools/art/make_park_kitchen_bay_windows.py`，已用项目内 Blender 5.2.1 后台运行并检查了两张预览。

## 接入尺寸与坐标

- 单件宽 **14.72 m**，原点在窗台底面中心；从底面到顶梁 **1.68 m**。深度约 **0.45 m**，最前缘为窗台。模型使用米，`+Z` 为 Blender 的竖直方向，`-Y` 朝餐厅内部；Godot 导入后向室内对应 `+Z`。
- 在当前 `_stage` 中两件均放在 `Vector3(0, 0.77, -4.79)`，`scale = Vector3.ONE`。分别以 `visible` 切换，**只显示一个**。夜景适用于晚市及夜间；可以在切换时短暂做透明淡入，但最好不要同时渲染两个变体。
- 接入时移除 `_build_room_shell()` 中目前 `x = [-4.56, -1.52, 1.52, 4.56]` 四块纯色玻璃与前景绿色块及配套旧窗框，避免重叠、遮挡。保留墙体与侧墙。新资源为有深度的浅窗景，放在旧实墙内侧；要做真实透视窗外世界时，可再把实墙开孔并将远景后移。
- 四个主开间宽 3.66 m，窗框比例与原有窗格位置相近。若厨房镜头角度或主柜台高度变化，请在实机截图确认窗景没有被顶部 HUD 和后排备料柜遮住。

## 艺术与性能范围

两组的室外楼群是**风格化后海意象**，包括连续天际线、收分的“春笋”轮廓与低矮体育馆形体；不是导航数据或建筑的测绘复刻。用户要求的地图 1:1 空间关系应在独立的地图制作阶段验证，不能把此室内窗景当成地理还原的证据。

GLB 每件约 0.9 MB，远景楼宇和海面光点按材质合并了网格，其他窗框与树木保留独立可编辑部件。当前只有静态双变体；风雨和夕阳中间态、玻璃上的反射动画、动态路人尚未制作。白天/夜间的 Blender 预览已查看，Godot 厨房内的实际构图、亮度和导入材质需要集成后再验收。
