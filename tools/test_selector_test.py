from __future__ import annotations

import argparse
import importlib.util
import json
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
MAP_PATH = TOOLS_DIR / "test_map.json"
SELECTOR_PATH = TOOLS_DIR / "select_tests.py"


def load_selector():
    spec = importlib.util.spec_from_file_location("test_selector_logic", SELECTOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load select_tests.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


selector = load_selector()
test_map = selector.load_map(MAP_PATH)


def choose(paths, mode="auto"):
    return selector.select_from_files(paths, mode, test_map)


class TestSelectorLogic(unittest.TestCase):
    def test_docs_only_runs_compile_only(self):
        result = choose(["docs/README.md"])
        self.assertEqual(result["gates"], [])
        self.assertEqual(result["always"], ["compile"])
        self.assertIn("compile only", result["reason"])

    def test_selector_files_do_not_trigger_game_gates(self):
        result = choose([
            "tools/select_tests.py",
            "tools/test_map.json",
            "tools/run_selected_tests.ps1",
            "tools/test_selector_test.py",
        ])
        self.assertEqual(result["gates"], [])
        self.assertEqual(result["tags"], [])

    def test_scene_change_selects_scene_and_spot_city(self):
        result = choose(["scenes/main.tscn"])
        self.assertIn("scene-check", result["gates"])
        self.assertIn("spot-city", result["gates"])
        self.assertNotIn("economy-check", result["gates"])

    def test_world_systems_change_does_not_select_scene(self):
        result = choose(["scripts/gameplay/farm_plot_layer.gd"])
        self.assertIn("world-systems", result["gates"])
        self.assertNotIn("scene-check", result["gates"])

    def test_autoload_change_forces_smoke_and_world(self):
        result = choose(["autoload/game_state.gd"])
        self.assertIn("smoke-test", result["gates"])
        self.assertIn("world-systems", result["gates"])

    def test_project_file_selects_smoke(self):
        result = choose(["project.godot"])
        self.assertEqual(result["gates"], ["smoke-test"])

    def test_price_change_selects_economy_without_stress(self):
        result = choose(["data/price.csv"])
        self.assertIn("economy-check", result["gates"])
        self.assertNotIn("stress-test", result["gates"])

    def test_wage_change_selects_economy_and_stress(self):
        result = choose(["data/wage.csv"])
        self.assertIn("economy-check", result["gates"])
        self.assertIn("stress-test", result["gates"])

    def test_test_script_change_selects_its_gate(self):
        result = choose(["tests/scene_check.gd"])
        self.assertEqual(result["gates"], ["scene-check"])

    def test_unknown_non_doc_file_uses_conservative_fallback(self):
        result = choose(["src/unknown_system.gd"])
        self.assertIn("smoke-test", result["gates"])
        self.assertIn("world-systems", result["gates"])
        self.assertTrue(result["unknown_fallback"])

    def test_release_mode_selects_full_suite(self):
        result = choose(["docs/README.md"], mode="release")
        self.assertEqual(result["gates"], test_map["release_tests"])
        self.assertIn("full-simulation", result["gates"])
        self.assertIn("playtest", result["gates"])

    def test_name_status_parser_handles_rename(self):
        parsed = selector.parse_name_status("M\told.gd\nR100\told.gd\tnew.gd\nA\tscene.tscn\n")
        self.assertEqual(parsed, ["old.gd", "old.gd", "new.gd", "scene.tscn"])

    def test_map_has_all_wrapper_gates(self):
        for gate in ["scene-check", "world-systems", "smoke-test", "economy-check", "stress-test", "spot-city"]:
            self.assertIn(gate, test_map["gates"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--verbose", action="store_true")
    args, remaining = parser.parse_known_args()
    unittest.main(argv=[__file__, *remaining], verbosity=2 if args.verbose else 1)
