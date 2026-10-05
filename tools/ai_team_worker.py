#!/usr/bin/env python3
"""Persistent multi-agent work queue for Shencheng Daily."""

from __future__ import annotations

import argparse
import json
import os
import time
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

import requests

ROOT = Path(__file__).resolve().parents[1]
QUEUE_DIR = ROOT / "docs" / "ai_team"
TASKS_PATH = QUEUE_DIR / "tasks.jsonl"
STATE_PATH = QUEUE_DIR / "state.json"
OUTPUT_DIR = QUEUE_DIR / "outputs"
LOG_PATH = QUEUE_DIR / "worker.log"
BLACKBOARD_PATH = QUEUE_DIR / "blackboard.json"
MESSAGES_PATH = QUEUE_DIR / "messages.jsonl"
SECRET_PATH = Path.home() / ".codex" / "secrets" / "deepseek_keys.json"

ROLE_PROMPTS = {
    "art_director": "你是《深日记》的美术总监。画风总体温柔治愈：低饱和暖色、柔光、整洁但不冷清，拒绝赛博霓虹和压抑工业风。坚持 16px 网格、2560x1440 城市图和 1280x720 室内图。输出必须是可执行的资产规格、prompt、验收标准和接入路径，不要泛泛而谈。",
    "ui_architect": "你是 Godot 4 UI/技术美术。目标是温柔治愈的暖色生活手账感：减少左上角信息拥挤、统一 Theme、让提示不重叠、所有 UI 资源通过 PresentationManager 和 CSV 稳定 key 接入。输出要包含具体节点、锚点、尺寸、CSV 字段和修改顺序。",
    "world_architect": "你是 2D 开放世界关卡架构师。目标是把传送门式切换逐步改成 2D GTA 式连续城区：相邻街区、连续道路、相机跟随、无重复空气墙，同时保持温柔治愈的整洁市井感。输出具体的数据结构、场景流式加载方案和迁移步骤。",
    "gameplay_planner": "你是资深生活模拟游戏策划。围绕经营、农场、职业、家庭、节日、消费行为设计可触发的场景交互，拒绝无效代码和纯菜单购买，坚持 NPC、实物、动作驱动。",
    "qa_lead": "你是 QA 与自动化负责人。目标是提高测试效率：只跑受影响测试，场景、存档、经济、真实窗口分别建门禁。输出具体脚本、映射规则和可验证断言。",
    "narrative_architect": "你是叙事和 NPC 设计负责人。NPC 必须有性格、作用、生日、作息、暗示和可触发的长期剧情，避免功能重复和提前暴露未解锁系统。",
}

SEED_TASKS = [
    {
        "id": "ui-001",
        "priority": 10,
        "role": "ui_architect",
        "title": "重构 HUD 信息层级与主题接口",
        "requirement": "解决左上角过杂、提示重叠、按钮状态缺失。给出 theme_tokens、ui_assets、ui_text_styles、PresentationManager API 的具体改造方案，并列出可直接实施的文件修改。",
        "context_files": ["scripts/ui/hud.gd", "scripts/ui/main_menu.gd", "autoload/presentation_manager.gd", "data/theme_tokens.csv", "data/visual_bindings.csv"],
        "status": "pending",
    },
    {
        "id": "world-001",
        "priority": 9,
        "role": "world_architect",
        "title": "连续 2D 城区流式加载架构",
        "requirement": "当前区域仍以 SceneRouter 整体重建。设计 world_graph + chunk streaming，让相邻街区连续行走、镜头不重置、门内和街道都能自然衔接。必须保留现有存档兼容。",
        "context_files": ["scripts/gameplay/world.gd", "autoload/scene_router.gd", "data/scene_zones.csv", "scripts/gameplay/area_backdrop.gd"],
        "status": "pending",
    },
    {
        "id": "art-001",
        "priority": 8,
        "role": "art_director",
        "title": "正式资产母版清单与生成 Prompt",
        "requirement": "基于现有 formal 覆盖层，列出下一批最高收益资产，并给出城市、商业区、工业区、生活区、UI、物品的 FLUX prompt 和验收标准。",
        "context_files": ["docs/ART_ARCHITECTURE.md", "docs/AI_TEAM_AND_ASSET_TOOLCHAIN.md", "tools/generate_pixel_art.py", "data/visual_bindings.csv"],
        "status": "pending",
    },
    {
        "id": "test-001",
        "priority": 7,
        "role": "qa_lead",
        "title": "按改动范围自动选择测试",
        "requirement": "实现一个 PowerShell 或 Python 入口：先做 Godot 编译检查，再根据 git diff 选择 scene-check、world-systems、smoke-test、economy-check、stress-test 或 spot-city。完整七项只在 release 模式运行。",
        "context_files": ["run_tests.ps1", "build_release.ps1", "tests/scene_check.gd", "tests/world_systems_test.gd", "tests/playtest_runner.gd"],
        "status": "pending",
    },
    {
        "id": "art-002",
        "priority": 7,
        "role": "art_director",
        "title": "UI 资源状态与九宫格规范",
        "requirement": "为面板、按钮、槽位、标题、对话气泡建立 normal/hover/pressed/focus/disabled 状态和九宫格切片规范，给出可直接交给图像生成或矢量绘制的资产清单。",
        "context_files": ["assets/art/formal/ui", "scripts/ui/inventory_slot_button.gd", "scripts/ui/hud.gd", "data/theme_tokens.csv"],
        "status": "pending",
    },
    {
        "id": "npc-001",
        "priority": 6,
        "role": "narrative_architect",
        "title": "下一批常驻 NPC 与限时 NPC",
        "requirement": "设计 6 位新 NPC，包含城区位置、日程、生日、提示风格、专长、可触发剧情和解锁条件，避免与现有 NPC 作用重叠。",
        "context_files": ["data/npcs.csv", "data/npc_schedule.csv", "data/npc_dialogue.csv", "data/npc_stories.csv"],
        "status": "pending",
    },
]


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def ensure_queue() -> None:
    QUEUE_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    if not TASKS_PATH.exists():
        with TASKS_PATH.open("w", encoding="utf-8") as fh:
            for task in SEED_TASKS:
                fh.write(json.dumps(task, ensure_ascii=False) + "\n")
    if not STATE_PATH.exists():
        atomic_json(STATE_PATH, {"run_count": 0, "completed_count": 0, "updated_at": now_iso()})
    if not BLACKBOARD_PATH.exists():
        atomic_json(BLACKBOARD_PATH, {"goal": "完成《深日记》开发总案", "constraints": ["无任务面板", "无数值属性条", "场景点击经营", "NPC/系统/场景提示分离", "固定物价", "存档兼容", "画风总体温柔治愈"], "decisions": [], "open_questions": [], "priorities": ["连续城区", "统一 UI/Theme", "正式美术资产", "机制可达性", "高效测试"], "updated_at": now_iso()})
    if not MESSAGES_PATH.exists():
        MESSAGES_PATH.write_text("", encoding="utf-8")


def load_tasks() -> list[dict[str, Any]]:
    ensure_queue()
    tasks: list[dict[str, Any]] = []
    for line in TASKS_PATH.read_text(encoding="utf-8").splitlines():
        if line.strip():
            tasks.append(json.loads(line))
    return tasks


def save_tasks(tasks: list[dict[str, Any]]) -> None:
    tmp = TASKS_PATH.with_suffix(".jsonl.tmp")
    with tmp.open("w", encoding="utf-8") as fh:
        for task in tasks:
            fh.write(json.dumps(task, ensure_ascii=False) + "\n")
    os.replace(tmp, TASKS_PATH)


def atomic_json(path: Path, data: dict[str, Any]) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, path)


def load_state() -> dict[str, Any]:
    ensure_queue()
    return json.loads(STATE_PATH.read_text(encoding="utf-8"))


def load_blackboard() -> dict[str, Any]:
    ensure_queue()
    return json.loads(BLACKBOARD_PATH.read_text(encoding="utf-8"))


def save_blackboard(board: dict[str, Any]) -> None:
    board["updated_at"] = now_iso()
    atomic_json(BLACKBOARD_PATH, board)


def append_message(sender: str, recipient: str, task_id: str, message_type: str, content: str) -> None:
    ensure_queue()
    item = {
        "timestamp": now_iso(),
        "from": sender,
        "to": recipient,
        "task_id": task_id,
        "type": message_type,
        "content": content,
    }
    with MESSAGES_PATH.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(item, ensure_ascii=False) + "\n")


def recent_messages(task_id: str = "", limit: int = 20) -> str:
    if not MESSAGES_PATH.exists():
        return ""
    rows: list[str] = []
    for line in MESSAGES_PATH.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        item = json.loads(line)
        if task_id and item.get("task_id") not in ["", task_id]:
            continue
        rows.append(f"{item.get('from')} -> {item.get('to')} [{item.get('type')}]: {item.get('content', '')[:1200]}")
    return "\n".join(rows[-limit:])


def select_peer_role(role: str) -> str:
    peers = {
        "art_director": "ui_architect",
        "ui_architect": "art_director",
        "world_architect": "gameplay_planner",
        "gameplay_planner": "world_architect",
        "qa_lead": "gameplay_planner",
        "narrative_architect": "gameplay_planner",
    }
    return peers.get(role, "gameplay_planner")


def select_critic_role(primary: str, peer: str) -> str:
    for candidate in ["qa_lead", "world_architect", "ui_architect", "art_director"]:
        if candidate not in [primary, peer]:
            return candidate
    return "gameplay_planner"

def append_log(message: str) -> None:
    ensure_queue()
    with LOG_PATH.open("a", encoding="utf-8") as fh:
        fh.write(f"[{now_iso()}] {message}\n")


def load_keys() -> list[str]:
    env_key = os.environ.get("DEEPSEEK_API_KEY", "").strip()
    keys: list[str] = []
    if SECRET_PATH.exists():
        try:
            data = json.loads(SECRET_PATH.read_text(encoding="utf-8"))
            keys.extend(item["key"] for item in data.get("deepseek", []) if item.get("key"))
        except Exception as exc:
            append_log(f"secret_load_failed: {exc}")
    if env_key:
        keys.insert(0, env_key)
    return list(dict.fromkeys(keys))


def read_context(task: dict[str, Any], max_chars: int = 12000) -> str:
    chunks: list[str] = []
    for rel in task.get("context_files", []):
        path = ROOT / rel
        if path.is_file():
            text = path.read_text(encoding="utf-8", errors="replace")
            chunks.append(f"===== {rel} =====\n{text[:4000]}")
        elif path.is_dir():
            names = sorted(p.name for p in path.iterdir() if p.is_file())
            chunks.append(f"===== {rel} =====\n{chr(10).join(names[:120])}")
    joined = "\n\n".join(chunks)
    return joined[:max_chars]


def call_deepseek(role: str, task: dict[str, Any], extra_context: str = "", key_index: int = 0) -> str:
    keys = load_keys()
    if not keys:
        raise RuntimeError("没有 DeepSeek 密钥")
    if key_index:
        keys = keys[key_index % len(keys):] + keys[:key_index % len(keys)]
    system = ROLE_PROMPTS.get(role, ROLE_PROMPTS["gameplay_planner"])
    blackboard = load_blackboard()
    shared = recent_messages(str(task.get("id", "")), limit=24)
    user = f"""项目根目录：{ROOT}
任务：{task.get('title')}
要求：{task.get('requirement')}
共享黑板：{json.dumps(blackboard, ensure_ascii=False)}
最近消息：\n{shared or "暂无"}
补充资料：\n{extra_context or "暂无"}
只输出可执行结论，结构为：
1. 现状判断
2. 设计方案
3. 需要修改的文件与字段
4. 实施步骤
5. 验证方法
6. 风险与回退

项目上下文：
{read_context(task)}
"""
    last_error = ""
    for index, key in enumerate(keys):
        try:
            response = requests.post(
                "https://api.deepseek.com/chat/completions",
                headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
                json={
                    "model": "deepseek-chat",
                    "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
                    "temperature": 0.35,
                    "max_tokens": 6000,
                },
                timeout=180,
            )
            response.raise_for_status()
            payload = response.json()
            return payload["choices"][0]["message"]["content"]
        except Exception as exc:
            last_error = f"key#{index + 1}: {exc}"
            append_log(f"deepseek_failed role={role} {last_error}")
    raise RuntimeError(last_error or "DeepSeek call failed")


def create_review_tasks(tasks: list[dict[str, Any]]) -> int:
    by_id = {task["id"]: task for task in tasks}
    added = 0
    for task in list(tasks):
        if task.get("status") != "implemented":
            continue
        review_id = f"review-{task['id']}"
        if review_id in by_id:
            continue
        review = {
            "id": review_id,
            "priority": max(1, int(task.get("priority", 5)) - 1),
            "role": "qa_lead",
            "title": f"审查实现：{task.get('title')}",
            "requirement": "检查实现是否满足原任务、是否有死代码/不可触达机制、是否需要补测试；给出明确通过或返工结论。",
            "context_files": task.get("context_files", []),
            "source_task": task["id"],
            "implementation_summary": task.get("implementation_summary", ""),
            "implementation_tests": task.get("implementation_tests", ""),
            "status": "pending",
            "created_at": now_iso(),
        }
        tasks.append(review)
        by_id[review_id] = review
        added += 1
    return added


def run_once() -> str:
    tasks = load_tasks()
    create_review_tasks(tasks)
    pending = [task for task in tasks if task.get("status") == "pending"]
    if not pending:
        save_tasks(tasks)
        append_log("no_pending")
        return "NO_PENDING"
    pending.sort(key=lambda item: (int(item.get("priority", 0)), item.get("id", "")), reverse=True)
    task = pending[0]
    task["status"] = "running"
    task["started_at"] = now_iso()
    task["attempts"] = int(task.get("attempts", 0)) + 1
    save_tasks(tasks)
    try:
        output = call_deepseek(str(task.get("role", "gameplay_planner")), task)
        output_path = OUTPUT_DIR / f"{task['id']}.md"
        output_path.write_text(f"# {task.get('title')}\n\n{output}\n", encoding="utf-8")
        task["status"] = "ready_for_codex"
        task["output"] = str(output_path.relative_to(ROOT)).replace("\\", "/")
        task["completed_at"] = now_iso()
        task.pop("error", None)
    except Exception as exc:
        task["status"] = "pending"
        task["error"] = str(exc)
        task["last_error_at"] = now_iso()
    state = load_state()
    state["run_count"] = int(state.get("run_count", 0)) + 1
    state["last_task_id"] = task["id"]
    state["last_status"] = task["status"]
    state["last_output"] = task.get("output", "")
    state["updated_at"] = now_iso()
    atomic_json(STATE_PATH, state)
    save_tasks(tasks)
    append_log(f"task={task['id']} status={task['status']} output={task.get('output', '')}")
    return json.dumps({"id": task["id"], "status": task["status"], "output": task.get("output", ""), "error": task.get("error", "")}, ensure_ascii=False)


def run_team_once() -> str:
    tasks = load_tasks()
    create_review_tasks(tasks)
    pending = [task for task in tasks if task.get("status") == "pending"]
    if not pending:
        save_tasks(tasks)
        append_log("team_no_pending")
        return "NO_PENDING"
    pending.sort(key=lambda item: (int(item.get("priority", 0)), item.get("id", "")))
    task = pending[0]
    primary = str(task.get("role", "gameplay_planner"))
    peer = select_peer_role(primary)
    critic = select_critic_role(primary, peer)
    synthesizer = "gameplay_planner" if primary != "gameplay_planner" else "world_architect"
    task["status"] = "running"
    task["started_at"] = now_iso()
    task["attempts"] = int(task.get("attempts", 0)) + 1
    save_tasks(tasks)
    append_message("orchestrator", primary, task["id"], "assignment", task.get("requirement", ""))
    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            primary_future = pool.submit(call_deepseek, primary, task, "", 0)
            peer_future = pool.submit(call_deepseek, peer, task, "", 1)
            primary_output = primary_future.result()
            peer_output = peer_future.result()
        append_message(primary, "blackboard", task["id"], "proposal", primary_output)
        append_message(peer, primary, task["id"], "peer_proposal", peer_output)
        critique = call_deepseek(
            critic,
            task,
            f"主方案（{primary}）：\n{primary_output}\n\n独立方案（{peer}）：\n{peer_output}\n\n请重点找出遗漏、冲突、死代码、不可触达机制和验收漏洞。",
            0,
        )
        append_message(critic, "blackboard", task["id"], "critique", critique)
        final_plan = call_deepseek(
            synthesizer,
            task,
            f"主方案：\n{primary_output}\n\n独立方案：\n{peer_output}\n\n批判：\n{critique}\n\n请综合成唯一可执行方案，明确决策、文件、步骤、测试和风险。",
            1,
        )
        append_message(synthesizer, "codex", task["id"], "decision", final_plan)
        output_path = OUTPUT_DIR / f"{task['id']}.md"
        output_path.write_text(
            f"# {task.get('title')}\n\n## 多 Agent 主方案\n\n{primary_output}\n\n## 独立方案\n\n{peer_output}\n\n## 批判与风险\n\n{critique}\n\n## 综合决策\n\n{final_plan}\n",
            encoding="utf-8",
        )
        task["status"] = "ready_for_codex"
        task["output"] = str(output_path.relative_to(ROOT)).replace("\\", "/")
        task["team"] = {"primary": primary, "peer": peer, "critic": critic, "synthesizer": synthesizer}
        task["completed_at"] = now_iso()
        task.pop("error", None)
        board = load_blackboard()
        board.setdefault("decisions", []).append({
            "task_id": task["id"],
            "title": task.get("title", ""),
            "summary": final_plan[:1600],
            "timestamp": now_iso(),
        })
        board["decisions"] = board["decisions"][-80:]
        save_blackboard(board)
    except Exception as exc:
        task["status"] = "pending"
        task["error"] = str(exc)
        task["last_error_at"] = now_iso()
        append_message("orchestrator", "blackboard", task["id"], "error", str(exc))
    state = load_state()
    state["run_count"] = int(state.get("run_count", 0)) + 1
    state["last_task_id"] = task["id"]
    state["last_status"] = task["status"]
    state["last_output"] = task.get("output", "")
    state["updated_at"] = now_iso()
    atomic_json(STATE_PATH, state)
    save_tasks(tasks)
    append_log(f"team_task={task['id']} status={task['status']} output={task.get('output', '')}")
    return json.dumps({"id": task["id"], "status": task["status"], "output": task.get("output", ""), "error": task.get("error", "")}, ensure_ascii=False)

def mark_implemented(task_id: str, summary: str, tests: str) -> str:
    tasks = load_tasks()
    for task in tasks:
        if task.get("id") == task_id:
            task["status"] = "implemented"
            task["implementation_summary"] = summary
            task["implementation_tests"] = tests
            task["implemented_at"] = now_iso()
            append_message("codex", task_id, task_id, "implementation", f"{summary}\n测试：{tests}")
            board = load_blackboard()
            board.setdefault("artifacts", []).append({"task_id": task_id, "summary": summary, "tests": tests, "timestamp": now_iso()})
            board["artifacts"] = board["artifacts"][-80:]
            save_blackboard(board)
            created = create_review_tasks(tasks)
            save_tasks(tasks)
            state = load_state()
            state["completed_count"] = int(state.get("completed_count", 0)) + 1
            state["updated_at"] = now_iso()
            atomic_json(STATE_PATH, state)
            return f"IMPLEMENTED {task_id} reviews_added={created}"
    return f"NOT_FOUND {task_id}"


def print_status() -> None:
    tasks = load_tasks()
    state = load_state()
    counts: dict[str, int] = {}
    for task in tasks:
        counts[task.get("status", "unknown")] = counts.get(task.get("status", "unknown"), 0) + 1
    print(json.dumps({"state": state, "task_counts": counts, "tasks": tasks}, ensure_ascii=False, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--team-once", action="store_true")
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--interval", type=int, default=1200)
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--blackboard", action="store_true")
    parser.add_argument("--seed", action="store_true")
    parser.add_argument("--mark-implemented")
    parser.add_argument("--summary", default="")
    parser.add_argument("--tests", default="")
    args = parser.parse_args()

    ensure_queue()
    if args.seed:
        print("QUEUE_READY")
        return 0
    if args.blackboard:
        print(json.dumps(load_blackboard(), ensure_ascii=False, indent=2))
        return 0
    if args.status:
        print_status()
        return 0
    if args.team_once:
        print(run_team_once())
        return 0
    if args.mark_implemented:
        print(mark_implemented(args.mark_implemented, args.summary, args.tests))
        return 0
    if args.once:
        print(run_once())
        return 0
    if args.watch:
        while True:
            print(run_once(), flush=True)
            time.sleep(max(60, args.interval))
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
