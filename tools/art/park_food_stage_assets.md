# 人才公园餐厅：食材过程与工位资产

这套资产与十道成品使用相同的米制比例、圆角轮廓、奶油木/青绿/珊瑚配色与柔和粗糙度材质。每件有可编辑 `.blend`、独立 `.glb` 和预览 PNG。33 件过程模型总览为 [`food_stage_contact_sheet.png`](../../assets/art/models/food_stage/food_stage_contact_sheet.png)，可用 `python tools/art/build_food_stage_contact_sheet.py` 重建。

## 食材操作状态

统一路径：`res://assets/art/models/food_stage/<id>.glb`。本地源文件为 `tools/art/source/food_stage/<id>.blend`，预览为 `assets/art/models/food_stage/<id>_preview.png`。

| 模型 ID | 适用动作 | 画面中可辨的状态 |
| --- | --- | --- |
| `washed_greens` | 清洗 | 青绿滤盆、整叶叶脉、残叶及大水珠 |
| `washed_fruit` | 果香冰沙清洗 | 青绿滤盆中的珊瑚色果粒、柑橘小块、叶蒂和水珠 |
| `washed_millet` | 椰香小米清洗 | 独立金色米粒、浅色湿谷面、少量谷壳和水珠 |
| `washed_rice` | 米浆与鸡饭清洗 | 独立米粒、青绿色淘米水和滤盆孔位 |
| `washed_shrimp` | 鲜虾肠粉清洗 | 四只珊瑚色弯虾、深色尾扇、水珠和滤盆 |
| `washed_seaweed` | 海苔青蔬饺清洗 | 五条薄片海苔、亮边、水珠和滤盆 |
| `chopped_ingredients` | 切配 | 木板、黄瓜横切片与籽、胡萝卜条、切碎叶、刀痕和小刀 |
| `sliced_bun_veg` | 鸡蛋包切配 | 切开的软面包、可见内部面包芯与黄瓜圆片 |
| `sliced_chicken_spice` | 香料包切配 | 生鸡肉条、香料碎和葱段 |
| `sliced_noodle_greens` | 拌面切配 | 青菜细条、葱圈和未煮面条 |
| `sliced_fruit` | 冰沙切配 | 半切莓果、柑橘片和芒果丁 |
| `sliced_spices` | 香料油备货切配 | 姜片、红椒圈、葱段和八角 |
| `rice_batter_bowl` | 搅拌 | 青瓷碗、柔软米浆、混合纹、竹搅拌棒；GLB 含一条旋转动画 |
| `spice_jar` | 调味/腌制 | 开盖小罐、可见香料油、籽粒、麻绳与罐盖 |
| `steamer_rice_roll` | 蒸制 | 竹蒸笼、衬纸、未蒸米皮和绿色馅料 |
| `steamer_shrimp_roll` | 鲜虾肠粉蒸制 | 竹蒸笼中三条待蒸米皮，露出珊瑚色虾仁与青葱 |
| `steamer_seaweed_dumpling` | 海苔青蔬饺蒸制 | 竹蒸笼中五只未封口青蔬饺，露出海苔馅和手捏褶边 |
| `marinated_chicken` | 腌制 | 生鸡肉块、附着的香料油、青葱和香料碎 |
| `pan_seared_chicken` | 煎制 | 深青搪瓷煎锅、上色鸡排、煎痕、油泡及少量蒸汽 |
| `boiling_noodles` | 煮制 | 蓝色搪瓷锅、面条圈、青菜、汤面及蒸汽 |
| `portioned_tofu` | 分装 | 四块软豆花、姜糖水与姜丝 |
| `garnish_kit` | 点缀 | 三只小碗，分别盛香草、芝麻和柑橘皮 |
| `finished_serving_tray` | 出餐 | 留出主菜位置的木托盘，带小酱杯、餐巾与筷子 |
| `mixed_shrimp_batter` | 鲜虾肠粉搅拌 | 可搬动的青瓷碗中，米浆裹住弯虾、虾尾与青葱，待分装米皮 |
| `mixed_seaweed_dough` | 海苔青蔬饺搅拌 | 可搬动的青瓷碗中，浅绿面团、深色海苔和青菜馅明显分层 |
| `mixed_harbour_noodles` | 港湾拌面搅拌 | 生面圈、切配青菜和香料油同置于转运碗，待下锅 |
| `portioned_coconut_millet` | 椰香小米分装 | 单份椰壳盅里的原味小米与椰浆，还没有成品的水果与薄荷 |
| `portioned_chicken_rice` | 香煎鸡肉饭分装 | 米饭和刚切开的香煎鸡肉同盘，留出青菜、酱汁点缀位置 |
| `portioned_shrimp_roll` | 鲜虾肠粉分装 | 三条未蒸米皮裹虾，置于可移动的衬纸小竹板而非蒸笼 |
| `portioned_seaweed_dumpling` | 海苔青蔬饺分装 | 五只未蒸手捏饺置于撒有米粉的转运板，下一步才入蒸笼 |

模型原点位于器皿底部中心，Godot 中 `+Y` 向上、`+Z` 面向顾客。普通器皿占地约 0.3–0.8 米；煎锅含把手约 0.9 米。实机厨房总览中建议将主要操作物放大到约 0.9–1.15 米宽，保留工作台的点击碰撞与反馈动画。菜品成品仍使用 `res://assets/art/models/food/<recipe_id>.glb`；托盘中部留空，供成品叠放。

米浆碗的 GLB 含一条搅拌动画；只在进行搅拌动作时播放，其他状态可保持首帧。蒸汽、水滴和油泡也保留为可独立驱动的命名节点，厨房视图可按操作时机做轻微升降或缩放。

## 可替换工位设备

| 模型 | 尺寸与摆放 | 可辨细节 |
| --- | --- | --- |
| `res://assets/art/models/park_cafe_counter_unit.glb` | 宽 2.25 × 深 2.66 米，原点地面中心，台面顶约 `Y=0.85` | 奶油石圆角台面、木柜门、侧板刻线、低脚线和金属小拉手 |
| `res://assets/art/models/park_cafe_wash_basin.glb` | 整体宽约 1.94 米、深约 2.17 米，底部中心放在台面顶 | 占据工位主要面积的青绿陶瓷盆、可见水面、后侧九肋沥水架、伸到盆内的金属弯水龙头和珊瑚皂碟；使用中滤盆落入水面，待用滤盆放在沥水区 |

两件设备的 Blender 源文件位于 `tools/art/source/<模型名>.blend`，预览与 GLB 同目录。工位模型只负责外观，现有热点、碰撞和玩法逻辑由厨房场景保持。
