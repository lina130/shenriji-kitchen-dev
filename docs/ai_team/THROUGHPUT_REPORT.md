# AI 团队吞吐量与闭环报告

生成时间：2026-09-27 17:52 +08:00

## 本轮实测

| 指标 | 数值 |
|---|---:|
| LangGraph 批次 | 6 个任务 |
| 模型调用 | 30 次（每任务：主方案、独立方案、双批判、综合决策） |
| 总 token | 692,519 |
| 单次平均 token | 23,084 |
| 耗时 | 约 66 秒 |
| 平均吞吐 | 约 10,493 token/秒 |
| 并行度 | 6 个任务同时运行；提案阶段实际并发 12 次模型调用 |
| 模型来源 | DeepSeek 两把密钥轮转 |

本批产物：

- `docs/ai_team/outputs/career-001.md`
- `docs/ai_team/outputs/festival-001.md`
- `docs/ai_team/outputs/economy-002.md`
- `docs/ai_team/outputs/wardrobe-001.md`
- `docs/ai_team/outputs/map-003.md`
- `docs/ai_team/outputs/farm-001.md`

更早一批同样并行 6 个任务，产出：

- `art-003.md`、`ui-002.md`、`world-002.md`
- `npc-002.md`、`save-001.md`、`gameplay-001.md`

## 计划任务自动跑批实测

| 指标 | 数值 |
|---|---:|
| 触发方式 | Windows 计划任务 ShenchengAITeam20m 自动触发 |
| 时间 | 2026-09-27 18:08–18:09 +08:00 |
| LangGraph 任务 | 4 个 |
| 模型调用 | 20 次（每任务：主方案、独立方案、双批判、综合决策） |
| 总 token | 508,899 |
| 单次平均 token | 25,445 |
| 耗时 | 约 67 秒 |
| 平均吞吐 | 约 7,596 token/秒 |
| 产物 | npc-003、audio-001、pet-001、housing-002 |

这说明计划任务不是空转：即使没有人工触发，18:07 的定时轮次也自动消费了队列并产出了 4 份可执行方案。

## 编排引擎

- 引擎：LangGraph StateGraph。
- 工作流：主方案 || 独立方案 -> 双批判 -> 综合决策。
- 持久化：`docs/ai_team/langgraph_checkpoints.sqlite`。
- 共享一致性：`blackboard.json`、`messages.jsonl`、`tasks.jsonl`。
- 容错：每次模型调用最多 4 次指数退避重试。
- 并发控制：`AI_TEAM_MAX_CONCURRENCY`，默认 6；每个任务内部仍有提案/批判并行。
- token 记录：`worker.log` 的 `model_ok ... tokens=...`。

## 持续工作机制

- Windows 计划任务：`ShenchengAITeam20m`，每 20 分钟触发。
- 触发脚本：`tools/run_ai_team_20m.ps1`。
- 若已有 LangGraph 进程，计划任务直接跳过，不重复占用密钥。
- 计划任务下次运行时间可通过 `Get-ScheduledTaskInfo -TaskName ShenchengAITeam20m` 查看。

## Codex 子代理闭环

当前同时运行 3 个 Codex 子代理，每个只写不重叠文件范围：

1. 自动存档稳定性：`autoload/save_manager.gd` 等。
2. 早餐店点击经营：`autoload/kitchen_manager.gd`、`scripts/ui/hud.gd` 等。
3. 城区分区与无空气墙：`scripts/gameplay/world.gd`、`scene_zones.csv` 等。

已有的 Codex 子代理成果：

- 测试选择器：`tools/select_tests.py`、`tools/run_selected_tests.ps1`、13 项自测通过。
- UI 提示仲裁：`scripts/ui/notice_arbiter.gd`，HUD 左上角单卡、NPC 底部、系统右上。
- 连续城区：`--playtest --spot-city` 的 58 步通过，`--scene-check` 通过。

## 结论

多 agent 不是摆设：当前是“LangGraph 批量方案生产 + Codex 子代理并行落地 + 计划任务持续补给”的三层循环。token 吞吐量已经从单任务串行提升到 10k token/秒量级。后续不靠重复全量测试刷时长，而是用测试选择器只跑受影响门禁，把预算放在机制落地和可玩性上。
