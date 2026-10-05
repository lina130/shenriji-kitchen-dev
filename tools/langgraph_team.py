#!/usr/bin/env python3
"""LangGraph-based multi-agent orchestration for Shencheng Daily."""

from __future__ import annotations

import argparse
import asyncio
import json
import operator
import os
import sys
from pathlib import Path
from typing import Annotated, Any, TypedDict

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import END, START, StateGraph
from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from ai_team_worker import (  # noqa: E402
    OUTPUT_DIR,
    QUEUE_DIR,
    ROLE_PROMPTS,
    append_log,
    append_message,
    create_review_tasks,
    load_blackboard,
    load_keys,
    load_state,
    load_tasks,
    now_iso,
    read_context,
    recent_messages,
    save_blackboard,
    save_tasks,
    atomic_json,
    STATE_PATH,
    select_critic_role,
    select_peer_role,
)

CHECKPOINT_DB = QUEUE_DIR / "langgraph_checkpoints.sqlite"


class TeamState(TypedDict, total=False):
    task: dict[str, Any]
    primary_output: str
    peer_output: str
    critique: str
    final_plan: str
    errors: Annotated[list[str], operator.add]


def make_model(key: str, role: str) -> ChatOpenAI:
    return ChatOpenAI(
        model="deepseek-chat",
        api_key=key,
        base_url="https://api.deepseek.com",
        temperature=0.35,
        max_tokens=6000,
        timeout=180,
        max_retries=3,
    )


def token_usage(message: Any) -> int:
    usage = getattr(message, "usage_metadata", None) or {}
    return int(usage.get("input_tokens", 0)) + int(usage.get("output_tokens", 0))


async def invoke_with_retry(model: ChatOpenAI, messages: list[Any], label: str, attempts: int = 4) -> Any:
    last_error: Exception | None = None
    for attempt in range(attempts):
        try:
            response = await model.ainvoke(messages)
            append_log(f"model_ok label={label} tokens={token_usage(response)} attempt={attempt + 1}")
            return response
        except Exception as exc:
            last_error = exc
            append_log(f"model_retry label={label} attempt={attempt + 1} error={exc}")
            if attempt + 1 < attempts:
                await asyncio.sleep(2 ** attempt)
    raise RuntimeError(f"{label} failed after {attempts} attempts: {last_error}")


def shared_context(task: dict[str, Any]) -> str:
    board = load_blackboard()
    shared = recent_messages(str(task.get("id", "")), limit=24)
    return f"""项目根目录：{QUEUE_DIR.parents[1]}
共享黑板：{json.dumps(board, ensure_ascii=False)}
最近消息：
{shared or "暂无"}
任务上下文：
{read_context(task)}
"""


def primary_prompt(task: dict[str, Any]) -> str:
    return f"""你是主方案 Agent。
任务：{task.get('title')}
要求：{task.get('requirement')}
{shared_context(task)}
输出可执行方案，必须写清文件、字段、步骤、验证和风险。"""


def peer_prompt(task: dict[str, Any]) -> str:
    return f"""你是独立方案 Agent。不要迎合主方案，独立解决同一问题。
任务：{task.get('title')}
要求：{task.get('requirement')}
{shared_context(task)}
输出可执行方案，优先提出不同架构和更高效实现。"""


def critique_prompt(state: TeamState) -> str:
    task = state["task"]
    return f"""你是批判 Agent。检查两份方案中的遗漏、冲突、死代码、不可触达机制、存档风险和测试漏洞。
任务：{task.get('title')}
要求：{task.get('requirement')}
主方案：
{state.get('primary_output', '')}
独立方案：
{state.get('peer_output', '')}
只输出可执行的批判和返工要求。"""


def synthesis_prompt(state: TeamState) -> str:
    task = state["task"]
    return f"""你是综合决策 Agent。把主方案、独立方案和批判合并成唯一可执行方案。
任务：{task.get('title')}
要求：{task.get('requirement')}
主方案：
{state.get('primary_output', '')}
独立方案：
{state.get('peer_output', '')}
批判：
{state.get('critique', '')}
输出最终方案：决策、修改文件、步骤、验证、风险、回退。"""


async def build_and_run(task: dict[str, Any]) -> dict[str, Any]:
    keys = load_keys()
    if len(keys) < 1:
        raise RuntimeError("没有 DeepSeek 密钥")
    primary_key = keys[0]
    peer_key = keys[1 % len(keys)]
    critic_key = keys[2 % len(keys)]
    synth_key = keys[3 % len(keys)]
    primary = str(task.get("role", "gameplay_planner"))
    peer = select_peer_role(primary)
    critic = select_critic_role(primary, peer)
    critic_alt = "qa_lead" if critic != "qa_lead" else "gameplay_planner"
    synthesizer = "gameplay_planner" if primary != "gameplay_planner" else "world_architect"
    model_primary = make_model(primary_key, primary)
    model_peer = make_model(peer_key, peer)
    model_critic = make_model(critic_key, critic)
    model_critic_alt = make_model(peer_key, critic_alt)
    model_synth = make_model(synth_key, synthesizer)

    async def propose_primary(state: TeamState) -> dict[str, Any]:
        msg = await invoke_with_retry(model_primary, [
            SystemMessage(content=ROLE_PROMPTS.get(primary, ROLE_PROMPTS["gameplay_planner"])),
            HumanMessage(content=primary_prompt(state["task"])),
        ], "primary")
        return {"primary_output": str(msg.content)}

    async def propose_peer(state: TeamState) -> dict[str, Any]:
        msg = await invoke_with_retry(model_peer, [
            SystemMessage(content=ROLE_PROMPTS.get(peer, ROLE_PROMPTS["gameplay_planner"])),
            HumanMessage(content=peer_prompt(state["task"])),
        ], "peer")
        return {"peer_output": str(msg.content)}

    async def critique(state: TeamState) -> dict[str, Any]:
        prompt = critique_prompt(state)
        first, second = await asyncio.gather(
            invoke_with_retry(model_critic, [
                SystemMessage(content=ROLE_PROMPTS.get(critic, ROLE_PROMPTS["qa_lead"])),
                HumanMessage(content=prompt),
            ], "critic-a"),
            invoke_with_retry(model_critic_alt, [
                SystemMessage(content=ROLE_PROMPTS.get(critic_alt, ROLE_PROMPTS["qa_lead"])),
                HumanMessage(content=prompt),
            ], "critic-b"),
        )
        return {"critique": f"## 批判A（{critic}）\n\n{first.content}\n\n## 批判B（{critic_alt}）\n\n{second.content}"}

    async def synthesize(state: TeamState) -> dict[str, Any]:
        msg = await invoke_with_retry(model_synth, [
            SystemMessage(content=ROLE_PROMPTS.get(synthesizer, ROLE_PROMPTS["gameplay_planner"])),
            HumanMessage(content=synthesis_prompt(state)),
        ], "synthesizer")
        return {"final_plan": str(msg.content)}

    builder = StateGraph(TeamState)
    builder.add_node("primary", propose_primary)
    builder.add_node("peer", propose_peer)
    builder.add_node("critique", critique)
    builder.add_node("synthesize", synthesize)
    builder.add_edge(START, "primary")
    builder.add_edge(START, "peer")
    builder.add_edge("primary", "critique")
    builder.add_edge("peer", "critique")
    builder.add_edge("critique", "synthesize")
    builder.add_edge("synthesize", END)

    async with AsyncSqliteSaver.from_conn_string(str(CHECKPOINT_DB)) as checkpointer:
        graph = builder.compile(checkpointer=checkpointer)
        result = await graph.ainvoke({"task": task}, config={"configurable": {"thread_id": task["id"]}})
    result["team"] = {"primary": primary, "peer": peer, "critic": critic, "critic_alt": critic_alt, "synthesizer": synthesizer, "engine": "langgraph", "keys": len(keys)}
    return result


async def run_tasks(limit: int = 1, task_id: str = "") -> list[dict[str, Any]]:
    tasks = load_tasks()
    create_review_tasks(tasks)
    pending = [task for task in tasks if task.get("status") == "pending"]
    if task_id:
        pending = [task for task in pending if task["id"] == task_id]
    pending.sort(key=lambda item: (int(item.get("priority", 0)), item.get("id", "")), reverse=True)
    pending = pending[:limit]
    results: list[dict[str, Any]] = []
    for task in pending:
        task["status"] = "running"
        task["started_at"] = now_iso()
        task["attempts"] = int(task.get("attempts", 0)) + 1
        append_message("langgraph", str(task.get("role", "gameplay_planner")), task["id"], "assignment", task.get("requirement", ""))
    save_tasks(tasks)

    max_concurrency = max(1, int(os.environ.get("AI_TEAM_MAX_CONCURRENCY", "6")))
    sem = asyncio.Semaphore(max_concurrency)

    async def run_one(task: dict[str, Any]) -> dict[str, Any]:
      async with sem:
        try:
            result = await build_and_run(task)
            final_plan = str(result.get("final_plan", ""))
            output_path = OUTPUT_DIR / f"{task['id']}.md"
            output_path.write_text(
                f"# {task.get('title')}\n\n## 主方案\n\n{result.get('primary_output', '')}\n\n"
                f"## 独立方案\n\n{result.get('peer_output', '')}\n\n## 批判\n\n{result.get('critique', '')}\n\n"
                f"## 综合决策\n\n{final_plan}\n",
                encoding="utf-8",
            )
            append_message("langgraph", "codex", task["id"], "decision", final_plan)
            return {
                "id": task["id"],
                "status": "ready_for_codex",
                "output": str(output_path.relative_to(QUEUE_DIR.parents[1])).replace("\\", "/"),
                "team": result.get("team", {}),
                "summary": final_plan[:1600],
            }
        except Exception as exc:
            append_message("langgraph", "blackboard", task["id"], "error", str(exc))
            return {"id": task["id"], "status": "pending", "error": str(exc)}

    concurrent = await asyncio.gather(*(run_one(task) for task in pending))
    task_map = {task["id"]: task for task in tasks}
    for item in concurrent:
        task = task_map[item["id"]]
        task["status"] = item["status"]
        if item.get("output"):
            task["output"] = item["output"]
        if item.get("team"):
            task["team"] = item["team"]
        if item.get("error"):
            task["error"] = item["error"]
        else:
            task.pop("error", None)
            task["completed_at"] = now_iso()
        results.append(item)
    if results:
        board = load_blackboard()
        for item in results:
            if item.get("summary"):
                board.setdefault("decisions", []).append({"task_id": item["id"], "summary": item["summary"], "timestamp": now_iso(), "engine": "langgraph"})
        board["decisions"] = board.get("decisions", [])[-80:]
        save_blackboard(board)
        state = load_state()
        state["run_count"] = int(state.get("run_count", 0)) + len(results)
        state["last_task_id"] = results[-1]["id"]
        state["last_status"] = results[-1]["status"]
        state["last_output"] = results[-1].get("output", "")
        state["updated_at"] = now_iso()
        atomic_json(STATE_PATH, state)
    save_tasks(tasks)
    append_log(f"langgraph_batch={len(results)} " + ",".join(item["id"] + ":" + item["status"] for item in results))
    return results


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--limit", type=int, default=1)
    parser.add_argument("--task-id", default="")
    parser.add_argument("--batch", type=int, default=0)
    args = parser.parse_args()
    limit = args.batch or args.limit
    if args.once or args.batch or args.task_id:
        results = asyncio.run(run_tasks(limit=limit, task_id=args.task_id))
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return 0
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
