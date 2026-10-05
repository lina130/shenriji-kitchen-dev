"""Patch a freshly exported Godot web build with one-tap touch calibration.

Run after `godot --export-release Web release/web/index.html`, before zipping.
"""

from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "release" / "web"
HTML = WEB / "index.html"
ENGINE_JS = WEB / "index.js"
SOURCE = Path(__file__).with_name("mobile_touch_calibration.js")
SCRIPT_TAG = '<script src="mobile_touch_calibration.js"></script>'

html = HTML.read_text(encoding="utf-8")
if SCRIPT_TAG not in html:
    anchor = '<script src="index.js"></script>'
    assert html.count(anchor) == 1, "Godot web shell changed: index.js anchor missing"
    assert html.count("engine.startGame({") == 1, "Godot web shell changed: startup anchor missing"
    completion = "}, displayFailureNotice);\n\t}\n}());"
    assert html.count(completion) == 1, "Godot web shell changed: startup completion missing"
    html = html.replace(anchor, anchor + "\n\t\t" + SCRIPT_TAG, 1)
    html = html.replace(
        "engine.startGame({",
        "window.mobileTouchCalibration.waitForEntry().then(() => engine.startGame({",
        1,
    )
    html = html.replace(
        completion,
        "}, displayFailureNotice)).catch(displayFailureNotice);\n\t}\n}());",
        1,
    )
    HTML.write_text(html, encoding="utf-8")

engine_js = ENGINE_JS.read_text(encoding="utf-8")
old_coordinates = "const x=(evt.clientX-rect.x)*rw;const y=(evt.clientY-rect.y)*rh;"
new_coordinates = (
    "const bias=typeof evt.identifier===\"number\"&&globalThis.mobileTouchCalibration"
    "?globalThis.mobileTouchCalibration.getOffset():[0,0];"
    "const x=(evt.clientX+bias[0]-rect.x)*rw;"
    "const y=(evt.clientY+bias[1]-rect.y)*rh;"
)
if new_coordinates not in engine_js:
    assert engine_js.count(old_coordinates) == 1, "Godot web input function changed"
    engine_js = engine_js.replace(old_coordinates, new_coordinates, 1)

ENGINE_JS.write_text(engine_js, encoding="utf-8")

shutil.copy2(SOURCE, WEB / SOURCE.name)
print("Mobile touch calibration installed:", HTML)
