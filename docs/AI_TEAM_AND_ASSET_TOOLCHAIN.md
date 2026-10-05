# AI 团队协作与游戏素材工具链调研

> 调研日期：2026-09-27。Star 数为当日 GitHub API 查询结果。

## 1. 结论

本项目适合采用多角色 Agent + 可验证工具链 + 数据驱动资产接口，而不是让单个 Agent 直接生成全部代码和素材。

推荐分层：

1. 架构层：维护总案、数据表、存档兼容和验收门禁。
2. 玩法层：按系统拆成小任务，每次只改一个闭环并跑相关单项测试。
3. 世界层：用 Tiled 或 LDtk 做地图源文件，Godot 负责运行时加载和业务交互。
4. 美术层：用 Aseprite 或 Pixelorama 做动画源文件，Godot 导入插件转成 SpriteFrames 或 AnimationPlayer。
5. QA 层：分区、碰撞、出口、密度、经济、存档迁移分别自动检查。

## 2. AI 团队实践参考

- MetaGPT：70.6k stars，MIT。参考产品经理、架构师、工程师、QA 的角色分工。https://github.com/FoundationAgents/MetaGPT
- ChatDev 2.0：34.4k stars，Apache-2.0。参考多 Agent 协作剧本和迭代修复流程。https://github.com/OpenBMB/ChatDev
- OpenHands：89.3k stars，MIT。参考具备终端和浏览器操作能力的 Coding Agent。https://github.com/OpenHands/OpenHands
- Aider：49.2k stars，Apache-2.0。参考终端内代码编辑、仓库地图和小步提交工作流。https://github.com/Aider-AI/aider
- SWE-agent：20.4k stars，MIT。参考 Issue 到代码修改再到测试验证的闭环。https://github.com/SWE-agent/SWE-agent
- vibecosystem：534 stars，MIT。提供大量 Agent、Skill、Hook 组合实践，可作为角色库参考并自行审查冗余。https://github.com/vibeeval/vibecosystem
- AI_Teammates_in_SE3：85 stars。研究资料，适合阅读 AI 团队成员如何改变软件工程协作方式。https://github.com/SAILResearch/AI_Teammates_in_SE3
- Generative Agents：22.2k stars，Apache-2.0。参考 NPC 记忆、日程、关系和社会行为模拟。https://github.com/joonspk-research/generative_agents
- Voyager：7.2k stars，MIT。参考开放环境中探索、学习、技能库和迭代的 Agent 循环。https://github.com/MineDojo/Voyager

本项目建议角色：architecture-agent、gameplay-agent、world-agent、narrative-agent、art-agent、qa-agent。不要让多个 Agent 同时改同一个大文件。

## 3. 地图工具链

### Tiled

- Tiled Map Editor：12.9k stars。https://github.com/mapeditor/tiled
- YATI：295 stars，MIT，Godot 4 Tiled 导入器。https://github.com/Kiamo2/YATI
- godot-tiled-importer：901 stars，MIT。https://github.com/vnen/godot-tiled-importer

适合大型城市地图、道路、建筑底层、碰撞层、对象层和分区矩形。建议对象层记录 door_id、zone_id、scene_id。

### LDtk

- LDtk：4.2k stars，MIT。https://github.com/deepnight/ldtk
- godot-ldtk-importer：258 stars，MIT。https://github.com/heygleeson/godot-ldtk-importer
- amano-ldtk-importer：84 stars，MIT。https://github.com/afk-mario/amano-ldtk-importer

适合房间、街区、室内和支线场景。建议 LDtk 负责摆放，data/scene_zones.csv 负责运行时分区与密度校验。

### Godot 原生与辅助工具

- Godot 4 TileMapLayer 和 Terrain 适合最终运行时与碰撞拼装。
- blobsmith-autotile-wirer：小型 MIT 工具，适合参考自动地形接线。
- img2tilemap：适合把现有 PNG 地图拆成 TileSet 和 TileMapLayer。
- 后续地图改动必须同时更新场景分区数据，不能只改背景图。

## 4. 角色、动画与物品工具链

- godot-aseprite-wizard：1.37k stars，MIT，导入 Aseprite 动画到 Godot。https://github.com/viniciusgerevini/godot-aseprite-wizard
- Importality：537 stars，MIT，支持多格式栅格与动画导入。https://github.com/nklbdev/godot-4-importality
- godot-4-aseprite-importers：100 stars，MIT。https://github.com/nklbdev/godot-4-aseprite-importers
- Pixelorama：Godot 生态免费像素编辑器。https://github.com/Orama-Interactive/Pixelorama
- Aseprite：成熟商业级像素动画工具，注意许可证和二进制发行条款。https://github.com/aseprite/aseprite
- FrameForge：AI 游戏素材生成工具参考，134 stars，Apache-2.0。https://github.com/Fantety/FrameForge

建议：Aseprite 源文件放 art_source，导出中间帧到 assets/art，最终由 PresentationManager 稳定 key 读取。物品统一分类、尺寸、色板、透明边距和命名。

## 5. 本项目落地顺序

1. 先规范数据：scene_zones.csv 已作为分区来源。
2. 再接 LDtk 或 Tiled：一个场景只选一个编辑器作为源，避免双源冲突。
3. 再统一导入器：地图、Aseprite、物品图标分别走独立导入脚本。
4. 最后替换正式资产：只替换 PNG、OGG、字体，不改业务逻辑和稳定 key。
5. 每个里程碑跑分区、碰撞、出口、存档迁移、经济模拟和真实窗口门禁。

## 6. 许可证审查

- 确认仓库、字体、音频、生成模型服务条款。
- 不提交来源不明的头像、字体、地图贴图或音乐。
- 保存 AI 生成记录和人工修改记录。
- 对 CC BY、CC BY-SA、GPL、LGPL、商业字体建立白名单策略。
- 发行前生成第三方许可证清单并随包附带。

## 7. 对本游戏的直接建议

- 城市主图：Tiled 或 LDtk 做源，运行时保留 Godot TileMapLayer 和数据表。
- 室内与店铺：LDtk 场景文件，进入时由 Godot 加载，不再手写大量坐标。
- NPC：Aseprite 多动作源文件加 PresentationManager 绑定。
- 物品：统一尺寸、色板、透明边距和命名。
- UI：字体和面板使用主题 token，不在业务代码中写死。
- AI 团队：按角色分工，但所有改动必须经过统一测试门禁和版本控制。
