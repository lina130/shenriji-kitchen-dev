#!/usr/bin/env python3
"""Select Godot gates from git changes.

This file is intentionally standalone. It does not modify or import the
existing run_tests.ps1. The PowerShell wrapper tools/run_selected_tests.ps1
uses the JSON emitted by this script.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Iterable

DEFAULT_MAP = Path(__file__).with_name("test_map.json")


def normalize_path(value: str) -> str:
    path = str(value or "").strip().replace("\\", "/")
    while path.startswith("./"):
        path = path[2:]
    return path


def glob_to_regex(pattern: str) -> re.Pattern[str]:
    pattern = normalize_path(pattern)
    pieces: list[str] = []
    index = 0
    while index < len(pattern):
        if pattern.startswith("**/", index):
            pieces.append("(?:.*/)?")
            index += 3
        elif pattern.startswith("**", index):
            pieces.append(".*")
            index += 2
        elif pattern[index] == "*":
            pieces.append("[^/]*")
            index += 1
        elif pattern[index] == "?":
            pieces.append("[^/]")
            index += 1
        else:
            pieces.append(re.escape(pattern[index]))
            index += 1
    return re.compile("^" + "".join(pieces) + "$", re.IGNORECASE)


def matches_any(path: str, patterns: Iterable[str]) -> bool:
    normalized = normalize_path(path)
    return any(glob_to_regex(pattern).match(normalized) for pattern in patterns)


def is_ignored(path: str, ignored_patterns: Iterable[str]) -> bool:
    return matches_any(path, ignored_patterns)


def normalize_files(files: Iterable[str], ignored_patterns: Iterable[str]) -> tuple[list[str], list[str]]:
    kept: list[str] = []
    ignored: list[str] = []
    for raw in files:
        path = normalize_path(raw)
        if not path:
            continue
        if is_ignored(path, ignored_patterns):
            ignored.append(path)
        else:
            kept.append(path)
    return sorted(set(kept)), sorted(set(ignored))


def parse_name_status(output: str) -> list[str]:
    files: list[str] = []
    for line in output.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        status = parts[0].strip()
        if status.startswith(("R", "C")) and len(parts) >= 3:
            files.extend([parts[1], parts[2]])
        elif len(parts) >= 2:
            files.append(parts[1])
    return files


def _run_git(root: Path, args: list[str]) -> str:
    command = ["git", "-C", str(root), "-c", "core.quotepath=false", *args]
    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "git command failed"
        raise RuntimeError(message)
    return result.stdout


def collect_changed_files(root: Path, base: str = "", local: bool = True, include_untracked: bool = False) -> list[str]:
    if base:
        diff_args = ["diff", "-M", "--name-status", base + "...HEAD"]
    elif local:
        diff_args = ["diff", "-M", "--name-status", "HEAD"]
    else:
        diff_args = ["diff", "-M", "--name-status", "HEAD~1...HEAD"]

    files = parse_name_status(_run_git(root, diff_args))
    if include_untracked or local:
        untracked = _run_git(root, ["ls-files", "--others", "--exclude-standard"])
        files.extend(line.strip() for line in untracked.splitlines() if line.strip())
    return sorted(set(normalize_path(path) for path in files if normalize_path(path)))


def load_map(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    required = ["version", "always", "test_order", "release_tests", "gates", "rules"]
    missing = [key for key in required if key not in data]
    if missing:
        raise ValueError("test map missing fields: " + ", ".join(missing))
    known_gates = set(data["gates"])
    for gate in data["release_tests"]:
        if gate not in known_gates:
            raise ValueError("release test references unknown gate: " + gate)
    for rule in data["rules"]:
        if "id" not in rule or "paths" not in rule or "gates" not in rule:
            raise ValueError("each rule needs id, paths and gates")
        unknown = [gate for gate in rule["gates"] if gate not in known_gates]
        if unknown:
            raise ValueError("rule %s references unknown gates: %s" % (rule["id"], ", ".join(unknown)))
    return data


def _rule_hits(files: list[str], rules: list[dict[str, Any]]) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    for rule in rules:
        excluded = rule.get("exclude", [])
        matched = [
            path
            for path in files
            if matches_any(path, rule.get("paths", [])) and not matches_any(path, excluded)
        ]
        if matched:
            hits.append({
                "id": rule["id"],
                "rule": rule["id"],
                "gates": list(rule.get("gates", [])),
                "files": sorted(set(matched)),
            })
    return hits


def _support_only(files: list[str], map_data: dict[str, Any]) -> bool:
    patterns = map_data.get("tests_only_paths", [])
    return bool(files) and all(matches_any(path, patterns) for path in files)


def select_from_files(files: list[str], mode: str = "auto", map_data: dict[str, Any] | None = None) -> dict[str, Any]:
    data = map_data or load_map(DEFAULT_MAP)
    kept, ignored = normalize_files(files, data.get("ignored_paths", []))
    gate_order = list(data["test_order"])
    gate_configs = data["gates"]

    if mode == "release":
        selected = [gate for gate in data["release_tests"] if gate in gate_configs]
        result = {
            "version": data["version"],
            "mode": mode,
            "files": kept,
            "ignored_files": ignored,
            "matched_rules": [],
            "forced_rules": [],
            "tags": [],
            "gates": selected,
            "always": list(data.get("always", ["compile"])),
            "requires_compile": True,
            "unknown_fallback": False,
            "reason": "release mode: run all release gates",
        }
        return result

    if not kept:
        return {
            "version": data["version"],
            "mode": mode,
            "files": kept,
            "ignored_files": ignored,
            "matched_rules": [],
            "forced_rules": [],
            "tags": [],
            "gates": [],
            "always": list(data.get("always", ["compile"])),
            "requires_compile": True,
            "unknown_fallback": False,
            "reason": "no changed files",
        }

    hits = _rule_hits(kept, data.get("rules", []))
    forced_hits = _rule_hits(kept, data.get("force_rules", []))
    direct_gates = {gate for hit in hits for gate in hit["gates"]}
    forced_gates = {gate for hit in forced_hits for gate in hit["gates"]}
    selected_gates = direct_gates | forced_gates

    support_only = _support_only(kept, data)
    unknown_fallback = False
    if support_only and not forced_gates:
        selected_gates = set()
        reason = "only tests/docs/selector changed; compile only"
    elif not selected_gates:
        selected_gates = set(data.get("fallback", []))
        unknown_fallback = True
        reason = "no rule matched; conservative fallback"
    else:
        matched_names = [hit["id"] for hit in hits]
        forced_names = [hit["id"] for hit in forced_hits]
        if matched_names and forced_names:
            reason = "matched rules: " + ", ".join(matched_names) + "; forced: " + ", ".join(forced_names)
        elif forced_names:
            reason = "forced rules: " + ", ".join(forced_names)
        elif matched_names:
            reason = "matched rules: " + ", ".join(matched_names)
        else:
            reason = "selected by fallback"

    ordered_gates = [
        gate
        for gate in gate_order
        if gate in selected_gates and not bool(gate_configs[gate].get("release_only", False))
    ]
    tags = sorted({hit["id"] for hit in hits} | {hit["id"] for hit in forced_hits})
    return {
        "version": data["version"],
        "mode": mode,
        "files": kept,
        "ignored_files": ignored,
        "matched_rules": hits,
        "forced_rules": forced_hits,
        "tags": tags,
        "gates": ordered_gates,
        "always": list(data.get("always", ["compile"])),
        "requires_compile": True,
        "unknown_fallback": unknown_fallback,
        "reason": reason,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Select Godot gates from changed files.")
    parser.add_argument("--root", default=".", help="Project root. Defaults to the current directory.")
    parser.add_argument("--map", default="", help="Path to test_map.json. Defaults to the file next to this script.")
    parser.add_argument("--base", default="", help="Git base ref. Uses <base>...HEAD.")
    parser.add_argument("--local", action="store_true", help="Use worktree versus HEAD and include untracked files.")
    parser.add_argument("--include-untracked", action="store_true", help="Include untracked files on top of a base diff.")
    parser.add_argument("--files", nargs="*", default=None, help="Explicit changed files; skips git collection.")
    parser.add_argument("--mode", choices=["auto", "release"], default="auto")
    parser.add_argument("--json", action="store_true", help="Emit one JSON object for the PowerShell wrapper.")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    map_path = Path(args.map).resolve() if args.map else DEFAULT_MAP.resolve()
    try:
        test_map = load_map(map_path)
        if args.files is not None:
            raw_files: list[str] = []
            for value in args.files:
                raw_files.extend(value.split(","))
            files = normalize_files(raw_files, test_map.get("ignored_paths", []))[0]
        else:
            local = args.local or not args.base
            files = collect_changed_files(
                root,
                base=args.base,
                local=local,
                include_untracked=args.include_untracked,
            )
        result = select_from_files(files, args.mode, test_map)
    except Exception as error:  # Keep the shell wrapper simple and machine-readable.
        if args.json:
            print(json.dumps({"error": str(error)}, ensure_ascii=False))
        else:
            print("TEST_SELECTION_ERROR: " + str(error), file=sys.stderr)
        return 3

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print("mode: " + result["mode"])
        print("gates: " + (", ".join(result["gates"]) or "(compile only)"))
        print("reason: " + result["reason"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
