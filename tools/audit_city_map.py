#!/usr/bin/env python3
"""Read-only CI audit for continuous-city zones, doors, density, and air walls."""

from __future__ import annotations

import csv
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
WORLD_PATH = ROOT / "scripts" / "gameplay" / "world.gd"
BACKDROP_PATH = ROOT / "scripts" / "gameplay" / "area_backdrop.gd"
ZONES_PATH = ROOT / "data" / "scene_zones.csv"

KIND_BUDGETS = {
    "market": 2,
    "residential": 3,
    "nature": 2,
    "commercial": 5,
    "services": 4,
    "industrial": 3,
    "suburb": 3,
    "transit": 2,
    "event": 4,
    "shops": 5,
    "housing": 2,
    "public": 3,
    "labor": 2,
    "logistics": 2,
    "factory": 2,
    "craft": 3,
    "wholesale": 3,
    "riverside": 3,
    "living": 3,
}

VISUAL_OVERLAP_LIMIT = 0.25
MIN_DOOR_GAP = 56.0
MIN_CORRIDOR_CLEARANCE = 42.0
SAME_AREA_INTERACTIONS = {"enter_park", "park_exit", "go_nature"}
TRANSIT_CORRIDORS = (
    ("factory_to_farm", (1680.0, 240.0), (2160.0, 1050.0), {"enter_farm"}),
)


@dataclass(frozen=True)
class Rect:
    x: float
    y: float
    w: float
    h: float

    def contains(self, point: tuple[float, float]) -> bool:
        return self.x <= point[0] <= self.x + self.w and self.y <= point[1] <= self.y + self.h

    def overlap_ratio(self, other: "Rect") -> float:
        left = max(self.x, other.x)
        top = max(self.y, other.y)
        right = min(self.x + self.w, other.x + other.w)
        bottom = min(self.y + self.h, other.y + other.h)
        if right <= left or bottom <= top:
            return 0.0
        overlap = (right - left) * (bottom - top)
        smaller = max(1.0, min(self.w * self.h, other.w * other.h))
        return overlap / smaller


@dataclass(frozen=True)
class Zone:
    area_id: str
    zone_id: str
    rect: Rect
    kind: str
    order: int
    max_entrances: int


@dataclass(frozen=True)
class Interactable:
    interaction_id: str
    position: tuple[float, float]
    visual: Rect
    line: int

    @property
    def door_like(self) -> bool:
        ident = self.interaction_id
        return (
            ident.startswith("enter_")
            or ident.startswith("go_")
            or ident.endswith("_exit")
            or "door" in ident
            or ident in {"home_to_living", "home_living_to_bedroom", "leave_home"}
        )


def fail(message: str) -> None:
    print(f"[FAIL] {message}")


def function_body(text: str, name: str) -> str:
    match = re.search(rf"(?m)^func {re.escape(name)}\b.*?:\s*$", text)
    if not match:
        raise RuntimeError(f"function not found: {name}")
    start = match.end()
    next_func = re.search(r"(?m)^func ", text[start:])
    return text[start:] if not next_func else text[start : start + next_func.start()]


def balanced_calls(text: str, needle: str) -> Iterable[tuple[int, str]]:
    cursor = 0
    while True:
        found = text.find(needle, cursor)
        if found < 0:
            return
        open_paren = text.find("(", found)
        if open_paren < 0:
            return
        depth = 0
        quote = ""
        escaped = False
        index = open_paren
        while index < len(text):
            char = text[index]
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = ""
            else:
                if char in ("'", '"'):
                    quote = char
                elif char == "(":
                    depth += 1
                elif char == ")":
                    depth -= 1
                    if depth == 0:
                        yield found, text[found : index + 1]
                        cursor = index + 1
                        break
            index += 1
        else:
            return


def parse_rect(match: re.Match[str]) -> Rect:
    return Rect(*(float(match.group(i)) for i in range(1, 5)))


def load_zones() -> list[Zone]:
    zones: list[Zone] = []
    with ZONES_PATH.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            raw_budget = (row.get("max_entrances") or "").strip()
            kind = (row.get("kind") or "misc").strip()
            budget = int(raw_budget) if raw_budget else KIND_BUDGETS.get(kind, 0)
            zones.append(
                Zone(
                    area_id=(row.get("area_id") or "").strip(),
                    zone_id=(row.get("zone_id") or "").strip(),
                    rect=Rect(
                        float(row["rect_x"]),
                        float(row["rect_y"]),
                        float(row["rect_w"]),
                        float(row["rect_h"]),
                    ),
                    kind=kind,
                    order=int(row.get("order") or 0),
                    max_entrances=budget,
                )
            )
    return sorted(zones, key=lambda zone: (zone.area_id, zone.order))


def find_zone(zones: list[Zone], area_id: str, point: tuple[float, float]) -> Zone | None:
    for zone in zones:
        if zone.area_id == area_id and zone.rect.contains(point):
            return zone
    return None


def parse_city_interactables(world: str, layout_scale: float = 1.0) -> list[Interactable]:
    body = function_body(world, "_build_city_map_interactables")
    interactables: list[Interactable] = []
    for start, call in balanced_calls(body, "_add_interactable"):
        id_match = re.search(r'_add_interactable\(\s*"([^"]+)"', call)
        positions = re.findall(r"Vector2\(\s*([-0-9.]+)\s*,\s*([-0-9.]+)\s*\)", call)
        if not id_match or len(positions) < 2:
            continue
        px, py = (float(positions[0][0]) * layout_scale, float(positions[0][1]) * layout_scale)
        vw, vh = (float(positions[1][0]), float(positions[1][1]))
        interactables.append(
            Interactable(
                interaction_id=id_match.group(1),
                position=(px, py),
                visual=Rect(px - vw * 0.5, py - vh * 0.5, vw, vh),
                line=world.count("\n", 0, world.find(body) + start) + 1,
            )
        )
    return interactables


def parse_transitions(world: str) -> dict[str, list[tuple[str, str]]]:
    body = function_body(world, "_on_interaction_requested")
    lines = body.splitlines()
    case_starts: list[tuple[int, str]] = []
    for index, line in enumerate(lines):
        match = re.match(r'^\t\t"([^"]+)":\s*$', line)
        if match:
            case_starts.append((index, match.group(1)))
    transitions: dict[str, list[tuple[str, str]]] = {}
    for index, (start, interaction_id) in enumerate(case_starts):
        end = case_starts[index + 1][0] if index + 1 < len(case_starts) else len(lines)
        block = "\n".join(lines[start:end])
        targets = re.findall(r'SceneRouter\.travel_to\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)', block)
        if targets:
            transitions[interaction_id] = targets
    return transitions


def expected_reverse(interaction_id: str) -> str | None:
    special = {
        "home_door": "leave_home",
        "home_to_living": "home_living_to_bedroom",
        "home_living_to_bedroom": "home_to_living",
    }
    if interaction_id in SAME_AREA_INTERACTIONS:
        return None
    if interaction_id in special:
        return special[interaction_id]
    if interaction_id.startswith("enter_"):
        return interaction_id[len("enter_") :] + "_exit"
    return None


def parse_layout_scale(world: str) -> float:
    match = re.search(r"const CITY_LAYOUT_SCALE\s*:=\s*([0-9.]+)", world)
    return float(match.group(1)) if match else 1.0


def parse_visible_boundaries(backdrop: str) -> list[Rect]:
    match = re.search(
        r"const CITY_BOUNDARY_COLLISIONS\s*:=\s*\[(.*?)\]",
        backdrop,
        re.DOTALL,
    )
    if not match:
        return []
    return [parse_rect(item) for item in re.finditer(r"Rect2\(\s*([-0-9.]+)\s*,\s*([-0-9.]+)\s*,\s*([-0-9.]+)\s*,\s*([-0-9.]+)\s*\)", match.group(1))]


def all_interactable_ids(world: str) -> set[str]:
    ids: set[str] = set()
    for _, call in balanced_calls(world, "_add_interactable"):
        match = re.search(r'_add_interactable\(\s*"([^"]+)"', call)
        if match:
            ids.add(match.group(1))
    return ids


def main() -> int:
    world = WORLD_PATH.read_text(encoding="utf-8")
    backdrop = BACKDROP_PATH.read_text(encoding="utf-8")
    zones = load_zones()
    layout_scale = parse_layout_scale(world)
    interactables = parse_city_interactables(world, layout_scale)
    transitions = parse_transitions(world)
    errors: list[str] = []

    street_zones = [zone for zone in zones if zone.area_id == "street"]
    if not street_zones:
        errors.append("street has no zones in scene_zones.csv")

    zone_by_id = {zone.zone_id: zone for zone in street_zones}
    zone_counts = {zone.zone_id: 0 for zone in street_zones}
    zone_visuals: dict[str, list[Interactable]] = {zone.zone_id: [] for zone in street_zones}

    for item in interactables:
        zone = find_zone(street_zones, "street", item.position)
        if zone is None:
            errors.append(f"line {item.line}: {item.interaction_id} is outside every street zone")
            continue
        zone_visuals[zone.zone_id].append(item)
        if item.door_like:
            zone_counts[zone.zone_id] += 1

    for zone in street_zones:
        count = zone_counts[zone.zone_id]
        if count > zone.max_entrances:
            errors.append(
                f"zone {zone.zone_id}: door density {count} exceeds max_entrances {zone.max_entrances}"
            )
        print(f"[OK] density {zone.zone_id}: {count}/{zone.max_entrances}")

        doors = [item for item in zone_visuals[zone.zone_id] if item.door_like]
        for first_index, first in enumerate(doors):
            for second in doors[first_index + 1 :]:
                dx = first.position[0] - second.position[0]
                dy = first.position[1] - second.position[1]
                distance = (dx * dx + dy * dy) ** 0.5
                overlap = first.visual.overlap_ratio(second.visual)
                if distance < MIN_DOOR_GAP or overlap > VISUAL_OVERLAP_LIMIT:
                    errors.append(
                        f"zone {zone.zone_id}: {first.interaction_id}/{second.interaction_id} "
                        f"are too close (gap={distance:.1f}, visual_overlap={overlap:.0%})"
                    )

    for first_index, first in enumerate(interactables):
        if not first.door_like:
            continue
        for second in interactables[first_index + 1 :]:
            if not second.door_like:
                continue
            dx = first.position[0] - second.position[0]
            dy = first.position[1] - second.position[1]
            distance = (dx * dx + dy * dy) ** 0.5
            overlap = first.visual.overlap_ratio(second.visual)
            if distance < MIN_DOOR_GAP or overlap > VISUAL_OVERLAP_LIMIT:
                errors.append(
                    f"street doors {first.interaction_id}/{second.interaction_id} "
                    f"overlap across zones (gap={distance:.1f}, visual_overlap={overlap:.0%})"
                )

    for item in interactables:
        if not item.door_like:
            continue
        if item.interaction_id in SAME_AREA_INTERACTIONS:
            continue
        targets = transitions.get(item.interaction_id, [])
        if not targets:
            errors.append(f"line {item.line}: door {item.interaction_id} has no SceneRouter transition")
            continue
        reverse_id = expected_reverse(item.interaction_id)
        if reverse_id is None:
            errors.append(f"line {item.line}: no reverse-door naming rule for {item.interaction_id}")
            continue
        reverse_targets = transitions.get(reverse_id, [])
        if not reverse_targets:
            errors.append(
                f"door {item.interaction_id} -> {targets[0][0]} is missing paired exit {reverse_id}"
            )
            continue
        if not any(area == "street" for area, _ in reverse_targets):
            errors.append(
                f"door {item.interaction_id}: reverse door {reverse_id} does not return to street"
            )

    for corridor_id, start_raw, end_raw, allowed_ids in TRANSIT_CORRIDORS:
        start = (start_raw[0] * layout_scale, start_raw[1] * layout_scale)
        end = (end_raw[0] * layout_scale, end_raw[1] * layout_scale)
        vx = end[0] - start[0]
        vy = end[1] - start[1]
        length_sq = max(1.0, vx * vx + vy * vy)
        for item in interactables:
            if not item.door_like or item.interaction_id in allowed_ids:
                continue
            wx = item.position[0] - start[0]
            wy = item.position[1] - start[1]
            projection = max(0.0, min(1.0, (wx * vx + wy * vy) / length_sq))
            nearest_x = start[0] + vx * projection
            nearest_y = start[1] + vy * projection
            distance = ((item.position[0] - nearest_x) ** 2 + (item.position[1] - nearest_y) ** 2) ** 0.5
            if distance < MIN_CORRIDOR_CLEARANCE:
                errors.append(
                    f"transit corridor {corridor_id}: {item.interaction_id} is only "
                    f"{distance:.1f}px from the player route"
                )

    all_ids = all_interactable_ids(world)
    paired_forward = 0
    for interaction_id in sorted(all_ids):
        reverse_id = expected_reverse(interaction_id)
        if reverse_id is None:
            continue
        if reverse_id not in all_ids:
            errors.append(f"door {interaction_id} is missing paired interaction {reverse_id}")
            continue
        if reverse_id not in transitions:
            errors.append(f"door {interaction_id} paired with {reverse_id}, but reverse transition is absent")
            continue
        paired_forward += 1

    visible_boundaries = parse_visible_boundaries(backdrop)
    collision_body = function_body(world, "_build_city_map_collisions")
    if len(visible_boundaries) != 4:
        errors.append(f"expected 4 visible city boundary rects, found {len(visible_boundaries)}")
    if "BackdropScript.CITY_BOUNDARY_COLLISIONS" not in collision_body:
        errors.append("street collision builder must use BackdropScript.CITY_BOUNDARY_COLLISIONS")
    if re.search(r"_add_wall\(\s*Rect2", collision_body):
        errors.append("street collision builder contains an unregistered interior wall rect")
    if "_add_circle_obstacle" in collision_body:
        errors.append("street collision builder contains an unregistered circle obstacle")

    print(f"[OK] layout: scale={layout_scale:g}, {len(street_zones)} street zones, {len(interactables)} city interactables")
    print(f"[OK] doors: {sum(zone_counts.values())} door-like street entries checked; {paired_forward} named reverse pairs verified")
    print(f"[OK] air walls: {len(visible_boundaries)} visible boundary rects, 0 interior collision calls")

    if errors:
        for error in errors:
            fail(error)
        print(f"CITY_MAP_AUDIT_FAIL: {len(errors)} issues")
        return 1
    print("CITY_MAP_AUDIT_PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
