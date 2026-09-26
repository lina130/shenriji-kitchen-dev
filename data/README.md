# 数据配置

- `items.csv`：便利店即时消费品。
- `collectibles.csv`：四级旧物、成交基准价、NPC 喜好、旧货行情分类。
- `balance.csv`：打工、房租、体力、摆摊与旧址参数。
- `weather.csv`：天气权重和经营影响。
- `npcs.csv`：NPC 身份、常驻区域、偏好礼物。
- `ruins.csv`：旧址探索点、经济解锁条件、时长与稀有度加成。
- `goods.csv`：食材基准成本与市场分类。
- `recipes.csv`：菜品配方、劳力、脑力、制作时间和售价。
- `business.csv`：库存容量、补货成本、营业时长、店铺升级参数。
- `bank.csv`：银行利率和彩票价格。

第一行为字段名，第一列为唯一键。正式平衡调整必须修改 `.csv` 源表。

构建脚本会生成同名 `.csv.txt` 副本，用于 Godot 导出后的 PCK 读取。不要单独修改 `.csv.txt`。