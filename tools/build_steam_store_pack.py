from pathlib import Path
import csv
import json
from PIL import Image, ImageDraw, ImageFont, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "release" / "steam_store"
SCENES = ROOT / "assets" / "art" / "scenes"
FONT_CANDIDATES = [Path("C:/Windows/Fonts/msyh.ttc"), Path("C:/Windows/Fonts/simhei.ttf")]

def ensure(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)

def font(size: int):
    for path in FONT_CANDIDATES:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()

def scene_image(area_id: str) -> Image.Image:
    path = SCENES / area_id / "background.png"
    if not path.exists():
        return Image.new("RGB", (1280, 720), (22, 34, 39))
    return Image.open(path).convert("RGB")

def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    width, height = image.size
    scale = max(target_w / width, target_h / height)
    resized = image.resize((max(1, int(width * scale)), max(1, int(height * scale))), Image.Resampling.NEAREST)
    left = max(0, (resized.width - target_w) // 2)
    top = max(0, (resized.height - target_h) // 2)
    return resized.crop((left, top, left + target_w, top + target_h))

def add_overlay(image: Image.Image, alpha: int = 120) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.rectangle((0, 0, image.width, image.height), fill=(4, 12, 16, alpha))
    return Image.alpha_composite(image.convert("RGBA"), overlay)

def draw_text_block(image: Image.Image, title: str, subtitle: str, title_size: int, subtitle_size: int) -> Image.Image:
    result = add_overlay(image)
    draw = ImageDraw.Draw(result)
    title_font = font(title_size)
    subtitle_font = font(subtitle_size)
    margin = max(18, int(image.width * 0.045))
    title_box = draw.textbbox((0, 0), title, font=title_font)
    subtitle_box = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    title_h = title_box[3] - title_box[1]
    subtitle_h = subtitle_box[3] - subtitle_box[1]
    total_h = title_h + subtitle_h + max(8, int(title_size * 0.25))
    y = max(margin, image.height - total_h - margin * 2)
    draw.text((margin, y), title, font=title_font, fill=(244, 214, 143, 255), stroke_width=2, stroke_fill=(9, 20, 24, 255))
    draw.text((margin, y + title_h + max(8, int(title_size * 0.25))), subtitle, font=subtitle_font, fill=(205, 231, 224, 255), stroke_width=1, stroke_fill=(9, 20, 24, 255))
    draw.rectangle((0, 0, image.width - 1, image.height - 1), outline=(238, 190, 95, 220), width=3)
    return result.convert("RGB")

def make_capsule(source: Image.Image, size: tuple[int, int], title: str, subtitle: str, title_size: int, subtitle_size: int, path: Path) -> None:
    base = cover(source, size)
    base = ImageEnhance.Color(base).enhance(0.88)
    save(draw_text_block(base, title, subtitle, title_size, subtitle_size), path)

def save(image: Image.Image, path: Path) -> None:
    ensure(path.parent)
    image.save(path, "PNG")

def save_text(text: str, path: Path) -> None:
    ensure(path.parent)
    path.write_text(text, encoding="utf-8")

def write_store_copy() -> None:
    zh = "# 深日记\n\n一款无强制主线、无数值属性面板的深圳都市生活模拟游戏。\n\n从城中村一间出租屋开始，打工、学手艺、摆摊、开店、种地、养鸡、钓鱼、旅行、认识街坊，慢慢把日子过起来。\n\n## 特色\n\n- 餐饮多工序实时经营。\n- 早市、午市、晚市独立菜单。\n- 100 件城市收藏物。\n- 招聘、员工诉求、培养、离职和留人。\n- 餐饮与工厂职业线。\n- 农场种植和养殖。\n- 18 个以上生活场景和限时 NPC。\n- 13 个全年节日。\n- 轻量合作房间。\n\n当前版本为 0.5.0 开发版，正式美术、Steamworks SDK、完整联机经济同步仍在持续制作。\n"
    en = "# Deep City Daily\n\nA no-quest, no-stat-panel life simulation set in a contemporary southern Chinese city.\n\nStart from a small rented room, work shifts, learn skills, run a food stall or restaurant, farm, keep animals, fish, travel, collect forgotten objects, and build a life at your own pace.\n\n## Features\n\n- Multi-stage real-time food production.\n- Separate morning, lunch, and dinner menus.\n- More than 100 city collectibles.\n- Staff hiring, morale, fatigue, resignation, and retention.\n- Restaurant and factory career lines.\n- Farming and livestock.\n- More than 18 life scenes and limited-time NPCs.\n- 13 yearly festivals.\n- Lightweight co-op rooms.\n\nCurrent build: 0.5.0 development build. Final art, the Steamworks SDK, and full co-op economy synchronization are still in progress.\n"
    save_text(zh, OUT / "store_description_zh.md")
    save_text(en, OUT / "store_description_en.md")

def write_steam_config() -> None:
    app_build = """"appbuild"
{
    "appid" "APPID_HERE"
    "desc" "Deep City Daily 0.5.0"
    "buildoutput" "..\\steam_build_output"
    "contentroot" "..\\windows"
    "setlive" ""
    "preview" "0"
    "depots"
    {
        "DEPOT_ID_HERE"
        {
            "File" "..\\windows\\*"
        }
    }
}
"""
    save_text(app_build, OUT / "steam_app_build.vdf")
    save_text("APPID_HERE\n", OUT / "steam_appid.txt")
    cloud = {"files": ["deep_city_save.json", "deep_city_autosave.json", "photos/*"], "description": "Deep City Daily save data and photo album. Replace with Steam Cloud config after app id assignment."}
    save_text(json.dumps(cloud, ensure_ascii=False, indent=2), OUT / "steam_cloud_config.json")
    tags = {"genres": ["Simulation", "Life Sim", "City Builder"], "features": ["Single-player", "Co-op", "Steam Achievements", "Steam Cloud"], "languages": ["Simplified Chinese", "English"]}
    save_text(json.dumps(tags, ensure_ascii=False, indent=2), OUT / "store_tags.json")

def write_achievements() -> None:
    rows = []
    path = ROOT / "data" / "achievements.csv"
    if path.exists():
        with path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
    payload = []
    for row in rows:
        payload.append({"api_name": row.get("achievement_id", ""), "display_name": row.get("name", ""), "description": row.get("description", ""), "hidden": str(row.get("hidden", "false")).lower() == "true"})
    save_text(json.dumps(payload, ensure_ascii=False, indent=2), OUT / "achievements_steam.json")

def write_checklist() -> None:
    text = "# Steam 发行准备清单\n\n已完成：\n\n- 生成商店头图、主图、小胶囊和开发截图。\n- 撰写中文和英文商店介绍。\n- 导出成就定义、云存档文件清单和商店标签。\n- 生成 steam_app_build.vdf 模板。\n- 发行包 Windows 可执行文件由 build_release.ps1 生成并校验哈希。\n\n仍需外部条件：\n\n- 填入真实 Steam App ID 和 Depot ID。\n- 接入 Steamworks SDK 插件并完成登录、成就和云存档联调。\n- 上传构建并提交 Valve 审核。\n- 准备预告片和最终商业级美术、音轨。\n"
    save_text(text, OUT / "release_checklist.md")

def validate() -> None:
    required = {"capsule_header_616x353.png": (616, 353), "capsule_small_231x87.png": (231, 87), "capsule_main_1920x620.png": (1920, 620), "screenshot_street_1280x720.png": (1280, 720), "screenshot_restaurant_1280x720.png": (1280, 720), "screenshot_farm_1280x720.png": (1280, 720)}
    for name, size in required.items():
        path = OUT / name
        if not path.exists() or Image.open(path).size != size:
            raise SystemExit(f"STEAM_STORE_PACK_FAIL: {name}")
    for name in ["store_description_zh.md", "store_description_en.md", "steam_app_build.vdf", "achievements_steam.json", "steam_cloud_config.json", "release_checklist.md"]:
        if not (OUT / name).exists():
            raise SystemExit(f"STEAM_STORE_PACK_FAIL: {name}")

def main() -> None:
    ensure(OUT)
    street = scene_image("street")
    restaurant = scene_image("restaurant")
    farm = scene_image("farm")
    make_capsule(street, (616, 353), "深日记", "DEEP CITY DAILY", 48, 20, OUT / "capsule_header_616x353.png")
    make_capsule(farm, (231, 87), "深日记", "DEEP CITY DAILY", 22, 9, OUT / "capsule_small_231x87.png")
    make_capsule(restaurant, (1920, 620), "深日记", "DEEP CITY DAILY", 92, 32, OUT / "capsule_main_1920x620.png")
    save(cover(street, (1280, 720)).convert("RGB"), OUT / "screenshot_street_1280x720.png")
    save(cover(restaurant, (1280, 720)).convert("RGB"), OUT / "screenshot_restaurant_1280x720.png")
    save(cover(farm, (1280, 720)).convert("RGB"), OUT / "screenshot_farm_1280x720.png")
    write_store_copy()
    write_steam_config()
    write_achievements()
    write_checklist()
    validate()
    print(f"STEAM_STORE_PACK_OK: {OUT}")

if __name__ == "__main__":
    main()
