from pathlib import Path
import csv
import math
import random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
ART = ROOT / "assets" / "art"

SCENE_PALETTES = {
    "home": ((198, 174, 137), (91, 67, 56), (126, 90, 70), (75, 113, 108)),
    "home_living": ((184, 164, 134), (78, 61, 54), (145, 113, 83), (93, 137, 126)),
    "street": ((102, 107, 103), (51, 61, 65), (174, 139, 88), (72, 112, 111)),
    "commercial_district": ((99, 111, 124), (47, 57, 65), (205, 126, 96), (97, 150, 167)),
    "high_end_district": ((151, 161, 174), (57, 68, 83), (206, 188, 143), (122, 153, 165)),
    "industrial_district": ((89, 98, 104), (40, 54, 61), (135, 147, 151), (95, 117, 119)),
    "logistics_port": ((99, 119, 137), (40, 57, 73), (196, 139, 74), (92, 122, 146)),
    "craft_workshop": ((154, 129, 98), (69, 52, 43), (188, 131, 85), (105, 121, 124)),
    "suburb": ((126, 151, 104), (66, 103, 70), (185, 171, 128), (95, 132, 112)),
    "riverside": ((105, 144, 96), (56, 99, 111), (139, 160, 111), (111, 151, 160)),
    "restaurant": ((219, 193, 148), (91, 63, 51), (184, 102, 76), (213, 158, 90)),
    "breakfast_shop": ((229, 210, 174), (91, 65, 52), (209, 164, 88), (185, 122, 79)),
    "breakfast_kitchen": ((214, 195, 162), (91, 65, 52), (179, 112, 76), (211, 172, 101)),
    "market": ((190, 158, 116), (75, 60, 52), (211, 112, 93), (145, 108, 69)),
    "night_market": ((62, 58, 73), (25, 28, 41), (218, 132, 82), (134, 84, 139)),
    "wholesale": ((157, 154, 137), (65, 74, 73), (184, 141, 95), (137, 118, 84)),
    "farm": ((95, 125, 85), (47, 74, 44), (126, 156, 107), (122, 91, 62)),
    "farm_livestock": ((154, 131, 101), (79, 62, 48), (197, 164, 112), (128, 104, 73)),
    "pet_store": ((216, 196, 166), (90, 70, 64), (201, 158, 143), (167, 131, 111)),
    "furniture_store": ((207, 212, 221), (63, 74, 92), (154, 166, 187), (139, 149, 171)),
    "clothing_store": ((216, 196, 190), (75, 60, 65), (183, 146, 142), (216, 215, 202)),
    "store": ((213, 195, 144), (37, 70, 78), (115, 150, 154), (239, 201, 104)),
    "bank": ((184, 198, 197), (41, 72, 82), (82, 125, 141), (214, 203, 131)),
    "factory": ((89, 101, 106), (38, 56, 63), (119, 133, 138), (75, 94, 101)),
    "park": ((95, 134, 102), (49, 86, 68), (112, 169, 170), (164, 164, 132)),
    "recycle": ((112, 117, 108), (48, 59, 57), (98, 114, 107), (131, 144, 128)),
    "ruins": ((17, 27, 32), (8, 16, 20), (36, 52, 58), (67, 85, 91)),
}

NPC_PALETTES = {
    "mei": ((217, 138, 131), (73, 55, 56), (232, 184, 146), (95, 120, 117)),
    "wang": ((131, 185, 178), (55, 74, 78), (222, 172, 128), (58, 78, 91)),
    "lin": ((232, 189, 102), (83, 62, 54), (236, 190, 149), (67, 96, 112)),
    "chen": ((157, 166, 196), (69, 68, 77), (219, 170, 130), (84, 76, 67)),
    "huang": ((229, 184, 106), (94, 58, 47), (233, 181, 139), (164, 92, 69)),
    "azhen": ((214, 141, 144), (72, 48, 58), (236, 185, 148), (126, 83, 113)),
    "qiang": ((119, 143, 139), (48, 62, 63), (205, 158, 119), (48, 75, 79)),
    "xiaoyu": ((183, 155, 207), (76, 55, 84), (233, 187, 151), (91, 132, 158)),
    "player": ((233, 180, 93), (33, 50, 56), (236, 190, 149), (55, 80, 92)),
}

def parse_color(value, fallback=(180, 150, 130)):
    raw = str(value).strip().lstrip("#")
    if len(raw) != 6:
        return fallback
    try:
        return tuple(int(raw[index:index+2], 16) for index in (0, 2, 4))
    except ValueError:
        return fallback

def palette_from_color(value, seed_text=""):
    accent = parse_color(value)
    rng = random.Random(sum(ord(char) for char in str(seed_text)))
    hair = tuple(max(18, min(95, int(channel * 0.36 + rng.randint(-6, 6)))) for channel in accent)
    skin = (226 + rng.randint(-8, 8), 178 + rng.randint(-8, 8), 137 + rng.randint(-8, 8))
    secondary = tuple(max(28, min(210, int(channel * 0.62 + 38))) for channel in accent)
    return (accent, hair, skin, secondary)

def ensure(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)

def save(img: Image.Image, path: Path) -> None:
    ensure(path.parent)
    img.save(path, "PNG")

def clamp(value):
    return max(0, min(255, int(value)))

def shade(color, amount):
    if amount >= 0:
        return tuple(clamp(c + (255 - c) * amount) for c in color)
    return tuple(clamp(c * (1.0 + amount)) for c in color)

def blend(a, b, amount):
    return tuple(clamp(a[i] * (1.0 - amount) + b[i] * amount) for i in range(3))

def noise_rect(draw: ImageDraw.ImageDraw, box, color, chance=0.12, seed=1, step=4):
    rng = random.Random(seed)
    x0, y0, x1, y1 = box
    for y in range(y0, y1, step):
        for x in range(x0, x1, step):
            if rng.random() < chance:
                draw.rectangle((x, y, min(x + step - 1, x1), min(y + step - 1, y1)), fill=color)

def draw_window(draw, x, y, w, h, color, lit=False):
    frame = shade(color, -0.55)
    draw.rectangle((x - 2, y - 2, x + w + 1, y + h + 1), fill=frame)
    draw.rectangle((x, y, x + w, y + h), fill=shade(color, 0.38 if lit else 0.05))
    draw.line((x, y + h // 2, x + w, y + h // 2), fill=frame, width=1)
    draw.line((x + w // 2, y, x + w // 2, y + h), fill=frame, width=1)

def draw_tree(draw, x, y, scale, dark, leaf, trunk):
    draw.ellipse((x - 44 * scale, y + 48 * scale, x + 48 * scale, y + 64 * scale), fill=shade(dark, -0.15))
    draw.rectangle((x - 7 * scale, y + 18 * scale, x + 7 * scale, y + 60 * scale), fill=trunk)
    for offset, radius in ((-30, 34), (0, 45), (30, 34), (-14, 32), (16, 32)):
        cx = x + offset * scale
        cy = y + (32 if offset == 0 else 42) * scale
        draw.ellipse((cx - radius * scale, cy - radius * scale, cx + radius * scale, cy + radius * scale), fill=leaf)
        draw.ellipse((cx - (radius - 8) * scale, cy - (radius - 8) * scale, cx + (radius - 8) * scale, cy + (radius - 8) * scale), fill=shade(leaf, 0.18))
    draw.ellipse((x - 8 * scale, y + 52 * scale, x + 8 * scale, y + 60 * scale), fill=shade(dark, -0.22))

def draw_lamp(draw, x, y, dark, accent):
    draw.ellipse((x - 15, y + 80, x + 15, y + 94), fill=shade(dark, -0.25))
    draw.rectangle((x - 3, y, x + 3, y + 86), fill=shade(dark, 0.08))
    draw.rectangle((x - 6, y - 6, x + 6, y + 3), fill=accent)
    draw.rectangle((x - 10, y + 2, x + 10, y + 8), fill=shade(accent, 0.15))

def draw_scene(area_id: str, palette, formal: bool = False) -> Image.Image:
    base, dark, mid, accent = palette
    img = Image.new("RGB", (1280, 720), base)
    d = ImageDraw.Draw(img)
    rng = random.Random(sum(ord(c) for c in area_id) + 20260927)

    sky_top = shade(base, 0.22)
    sky_bottom = blend(base, mid, 0.55)
    for y in range(0, 330, 8):
        amount = y / 330.0
        d.rectangle((0, y, 1280, y + 7), fill=blend(sky_top, sky_bottom, amount))

    urban = {"street", "commercial_district", "industrial_district", "high_end_district", "logistics_port", "craft_workshop"}
    nature = {"riverside", "park", "suburb", "farm"}
    interior = {"home", "home_living", "restaurant", "breakfast_shop", "breakfast_kitchen", "market", "night_market", "wholesale", "pet_store", "furniture_store", "clothing_store", "store", "bank", "factory", "recycle", "ruins"}

    if area_id in urban:
        road_y = 442
        d.rectangle((0, road_y, 1280, 720), fill=shade(dark, 0.10))
        d.rectangle((0, road_y - 26, 1280, road_y), fill=shade(mid, -0.05))
        d.rectangle((0, road_y + 112, 1280, road_y + 132), fill=blend(dark, mid, 0.25))
        for x in range(24, 1280, 112):
            d.rectangle((x, road_y + 64, x + 54, road_y + 72), fill=shade(accent, 0.18))
        for index, x in enumerate(range(18, 1270, 142)):
            height = 150 + ((index * 37) % 105)
            building = blend(mid, dark, 0.20 + (index % 3) * 0.08)
            d.rectangle((x, 122 - height // 5, x + 126, 385), fill=building, outline=shade(dark, -0.12), width=3)
            d.rectangle((x + 8, 132 - height // 5, x + 118, 144 - height // 5), fill=shade(building, 0.18))
            for wx in range(x + 16, x + 112, 34):
                for wy in range(178 - height // 5, 360, 42):
                    draw_window(d, wx, wy, 18, 24, accent, rng.random() < 0.42)
            if index % 3 == 0:
                d.rectangle((x + 34, 386, x + 92, 398), fill=accent)
        for x in range(70, 1280, 190):
            draw_lamp(d, x, 250, dark, accent)
        d.line((0, 315, 1280, 286), fill=shade(dark, 0.12), width=2)
        noise_rect(d, (0, road_y, 1280, 720), shade(dark, 0.03), 0.08, 17, 8)
    elif area_id in nature:
        far = blend(mid, base, 0.45)
        d.polygon([(0, 390), (180, 248), (350, 380), (520, 230), (760, 392), (1000, 260), (1280, 380), (1280, 720), (0, 720)], fill=far)
        d.polygon([(0, 452), (220, 332), (470, 462), (720, 326), (970, 458), (1280, 350), (1280, 720), (0, 720)], fill=shade(mid, -0.06))
        if area_id == "riverside":
            d.rectangle((0, 395, 1280, 590), fill=blend(accent, mid, 0.18))
            for i in range(24):
                y = 408 + i * 8
                d.line((40 + i * 18, y, 390 + i * 31, y), fill=shade(accent, 0.24), width=2)
        for x in range(80, 1240, 180):
            draw_tree(d, x, 310 + (x % 90), 0.82 + (x % 3) * 0.10, dark, shade(mid, 0.08), shade(dark, 0.12))
        if area_id == "farm":
            for row in range(4):
                for col in range(7):
                    x = 330 + col * 92
                    y = 485 + row * 42
                    d.rectangle((x, y, x + 74, y + 28), fill=shade(dark, 0.06), outline=shade(dark, -0.12))
                    for sx in range(x + 8, x + 72, 16):
                        d.line((sx, y + 6, sx, y + 24), fill=shade(mid, 0.02), width=2)
        noise_rect(d, (0, 360, 1280, 720), shade(dark, 0.06), 0.10, 23, 8)
    elif area_id in interior:
        wall = blend(base, mid, 0.32)
        floor = blend(mid, dark, 0.48)
        d.rectangle((0, 0, 1280, 430), fill=wall)
        d.rectangle((0, 430, 1280, 720), fill=floor)
        d.rectangle((0, 414, 1280, 438), fill=shade(dark, 0.14))
        for x in range(0, 1280, 96):
            d.line((x, 438, x + 130, 720), fill=shade(floor, 0.08), width=2)
        for y in range(500, 720, 62):
            d.line((0, y, 1280, y), fill=shade(floor, 0.06), width=2)
        noise_rect(d, (0, 0, 1280, 430), shade(wall, 0.04), 0.06, 31, 8)
        for x in range(90, 1180, 250):
            draw_window(d, x, 145, 96, 86, accent, rng.random() < 0.45)
        if area_id != "home_living":
            for x in range(120, 1220, 180):
                d.rectangle((x, 330, x + 120, 420), fill=shade(dark, 0.13), outline=shade(dark, -0.12), width=3)
                d.rectangle((x + 8, 340, x + 112, 354), fill=shade(accent, 0.12))
        for x in range(180, 1180, 260):
            d.line((x, 0, x, 104), fill=shade(dark, 0.16), width=3)
            d.ellipse((x - 26, 82, x + 26, 132), fill=shade(accent, 0.12), outline=shade(dark, -0.08), width=3)
        if area_id == "home":
            d.rectangle((1122, 300, 1238, 422), fill=shade(dark, 0.06), outline=shade(accent, 0.18), width=4)
            d.rectangle((1140, 318, 1220, 422), fill=shade(mid, -0.10), outline=shade(dark, -0.12), width=3)
            d.circle((1204, 372), 5, fill=shade(accent, 0.22))
        elif area_id == "home_living":
            # Compact living room: doors stay on the side walls, daily-use areas are visually separated.
            d.rectangle((42, 300, 156, 422), fill=shade(dark, 0.06), outline=shade(accent, 0.18), width=4)
            d.rectangle((60, 318, 138, 422), fill=shade(mid, -0.10), outline=shade(dark, -0.12), width=3)
            d.rectangle((1122, 300, 1238, 422), fill=shade(dark, 0.06), outline=shade(accent, 0.18), width=4)
            d.rectangle((1140, 318, 1220, 422), fill=shade(mid, -0.10), outline=shade(dark, -0.12), width=3)
            d.ellipse((168, 416, 548, 604), fill=shade(accent, -0.20))
            d.rounded_rectangle((178, 350, 520, 520), radius=28, fill=shade(mid, -0.16), outline=shade(dark, -0.12), width=4)
            d.rounded_rectangle((202, 370, 496, 470), radius=20, fill=shade(accent, -0.04), outline=shade(dark, -0.06), width=3)
            d.rectangle((222, 390, 294, 450), fill=shade(accent, 0.10))
            d.rectangle((316, 390, 388, 450), fill=shade(accent, 0.10))
            d.rectangle((410, 390, 482, 450), fill=shade(accent, 0.10))
            d.rounded_rectangle((548, 482, 776, 586), radius=18, fill=shade(mid, 0.02), outline=shade(dark, -0.10), width=4)
            d.rectangle((578, 504, 746, 520), fill=shade(accent, 0.12))
            d.rounded_rectangle((562, 132, 758, 286), radius=18, fill=shade(dark, 0.05), outline=shade(dark, -0.12), width=4)
            d.rectangle((586, 158, 734, 258), fill=shade(mid, -0.12), outline=shade(accent, 0.10), width=3)
            d.rectangle((244, 158, 428, 286), fill=shade(mid, -0.18), outline=shade(dark, -0.12), width=4)
            d.rectangle((260, 176, 412, 270), fill=shade(accent, 0.08), outline=shade(dark, -0.06), width=3)
            d.line((334, 176, 334, 270), fill=shade(dark, -0.08), width=3)
            d.rounded_rectangle((828, 492, 1008, 586), radius=14, fill=shade(mid, -0.10), outline=shade(dark, -0.12), width=4)
            d.line((850, 510, 986, 510), fill=shade(accent, 0.18), width=4)
            d.line((850, 534, 954, 534), fill=shade(accent, 0.10), width=4)
            d.rounded_rectangle((1000, 188, 1108, 428), radius=16, fill=shade(dark, 0.02), outline=shade(accent, 0.12), width=3)
            for poster_y in range(220, 400, 54):
                d.rectangle((1020, poster_y, 1088, poster_y + 28), fill=shade(accent, 0.08), outline=shade(dark, -0.05), width=2)
    else:
        noise_rect(d, (0, 0, 1280, 720), shade(mid, 0.02), 0.10, 41, 8)
        d.rectangle((0, 0, 1280, 38), fill=shade(dark, -0.12))
        d.rectangle((0, 682, 1280, 720), fill=shade(dark, -0.12))

    # Foreground props, all with grounded shadows to avoid floating objects.
    for i in range(7):
        x = 72 + i * 188
        y = 594 + (i % 2) * 18
        d.ellipse((x - 8, y + 28, x + 62, y + 44), fill=shade(dark, -0.18))
        d.rectangle((x, y, x + 52, y + 30), fill=shade(mid, -0.04), outline=shade(dark, -0.10), width=2)
        d.rectangle((x + 7, y - 14, x + 45, y + 2), fill=shade(accent, 0.10))

    if formal:
        if area_id == "home":
            d.polygon([(110, 110), (470, 20), (620, 420), (250, 540)], fill=shade(base, 0.25))
            d.polygon([(145, 112), (452, 38), (560, 390), (270, 484)], fill=shade(base, 0.10))
            d.rounded_rectangle((120, 420, 560, 680), radius=28, fill=blend(mid, accent, 0.22), outline=shade(dark, -0.08), width=3)
            d.rounded_rectangle((160, 448, 520, 650), radius=22, outline=shade(accent, 0.12), width=3)
            d.ellipse((720, 500, 1120, 650), fill=shade(accent, -0.12))
            d.rectangle((690, 80, 1120, 440), fill=shade(dark, 0.05), outline=shade(dark, -0.12), width=4)
            d.rectangle((730, 120, 1080, 390), fill=shade(accent, 0.18), outline=shade(dark, 0.02), width=3)
        elif area_id == "street":
            for x, w, h, c in [(90, 180, 90, accent), (310, 130, 60, mid), (500, 190, 78, shade(accent, 0.12)), (760, 150, 64, shade(mid, 0.16)), (980, 210, 88, accent)]:
                d.rounded_rectangle((x, 165 - h, x + w, 330), radius=12, fill=shade(c, -0.12), outline=shade(dark, -0.10), width=3)
                d.rectangle((x + 18, 205 - h, x + w - 18, 250 - h), fill=shade(c, 0.18))
            for x in range(90, 1200, 190):
                d.line((x, 80, x + 80, 135), fill=shade(dark, -0.12), width=3)
                d.ellipse((x - 20, 120, x + 20, 145), fill=shade(accent, 0.10))
            for x in range(70, 1220, 180):
                d.ellipse((x - 50, 620, x + 80, 655), fill=blend(dark, accent, 0.28))
        elif area_id == "restaurant":
            for x in range(120, 1180, 190):
                d.line((x, 0, x, 92), fill=shade(dark, -0.06), width=4)
                d.ellipse((x - 34, 78, x + 34, 132), fill=shade(accent, 0.12), outline=shade(dark, -0.10), width=3)
                d.arc((x - 26, 120, x + 26, 176), 200, 340, fill=(230, 220, 180), width=2)
            for x, y in [(260, 560), (660, 590), (1030, 555)]:
                d.rectangle((x, y, x + 130, y + 52), fill=shade(dark, 0.10), outline=shade(dark, -0.12), width=3)
                d.rectangle((x + 14, y + 12, x + 116, y + 34), fill=shade(accent, 0.18))
        elif area_id == "farm":
            d.polygon([(880, 360), (1040, 240), (1200, 360), (1200, 540), (880, 540)], fill=shade(dark, 0.14), outline=shade(dark, -0.12))
            d.rectangle((1000, 160, 1014, 420), fill=shade(dark, 0.02))
            d.line((940, 160, 1074, 160), fill=shade(dark, 0.02), width=5)
            d.line((1007, 160, 940, 180), fill=shade(dark, 0.02), width=4)
            for x in range(80, 800, 90):
                d.rectangle((x, 500, x + 8, 610), fill=shade(dark, 0.10))
                d.rectangle((x, 540, x + 72, 550), fill=shade(dark, 0.10))
        elif area_id == "night_market":
            for x, w, h, c in [(70, 220, 80, accent), (360, 160, 54, mid), (570, 230, 92, shade(accent, 0.18)), (860, 180, 70, shade(mid, 0.20)), (1080, 130, 48, accent)]:
                d.rounded_rectangle((x, 160 - h, x + w, 350), radius=12, fill=shade(c, -0.18), outline=shade(c, 0.14), width=4)
                d.rectangle((x + 16, 205 - h, x + w - 16, 250 - h), fill=shade(c, 0.24))
            for x in range(100, 1200, 220):
                d.line((x, 40, x, 145), fill=shade(dark, 0.10), width=3)
                d.ellipse((x - 28, 118, x + 28, 164), fill=shade(accent, 0.22), outline=shade(dark, -0.12), width=3)
            for x in range(60, 1220, 170):
                d.ellipse((x - 60, 610, x + 100, 660), fill=blend(dark, accent, 0.30))
    # Soft edge darkening is kept subtle so the play area remains readable.
    d.rectangle((0, 0, 1280, 22), fill=shade(dark, -0.18))
    d.rectangle((0, 698, 1280, 720), fill=shade(dark, -0.18))
    d.rectangle((0, 0, 22, 720), fill=shade(dark, -0.12))
    d.rectangle((1258, 0, 1280, 720), fill=shade(dark, -0.12))
    return img

def draw_city_map(palette, formal=False) -> Image.Image:
    base, dark, mid, accent = palette
    img = Image.new("RGB", (2560, 1440), base)
    d = ImageDraw.Draw(img)
    rng = random.Random(20260929)
    d.rectangle((0, 0, 2560, 1440), fill=blend(base, mid, 0.24))
    # Arterial roads create a readable cross-city map instead of one linear street.
    d.rectangle((1120, 0, 1440, 1440), fill=shade(dark, 0.14))
    d.rectangle((0, 620, 2560, 850), fill=shade(dark, 0.12))
    for x in range(1180, 1380, 46):
        d.rectangle((x, 0, x + 24, 1440), fill=shade(dark, -0.05))
    for y in range(660, 830, 42):
        d.rectangle((0, y, 2560, y + 20), fill=shade(dark, -0.04))
    # District blocks.
    blocks = [
        (80, 70, 660, 480, (177, 145, 108)),
        (1460, 70, 640, 430, (96, 119, 132)),
        (80, 920, 520, 420, (194, 157, 117)),
        (650, 920, 420, 420, (105, 145, 104)),
        (1500, 930, 500, 390, (156, 143, 128)),
        (2070, 930, 380, 390, (139, 164, 151)),
    ]
    for x, y, w, h, color in blocks:
        block = blend(color, base, 0.08)
        d.rounded_rectangle((x, y, x + w, y + h), radius=22, fill=block, outline=shade(dark, -0.10), width=5)
        for bx in range(x + 28, x + w - 40, 120):
            for by in range(y + 30, y + h - 34, 100):
                bw = 78 + (bx * 7) % 34
                bh = 58 + (by * 5) % 30
                building = shade(block, -0.12 if (bx + by) % 2 else 0.10)
                d.rectangle((bx, by, bx + bw, by + bh), fill=building, outline=shade(dark, -0.08), width=3)
                for wx in range(bx + 12, bx + bw - 10, 24):
                    d.rectangle((wx, by + 14, wx + 10, by + 25), fill=shade(accent, 0.28 if rng.random() > 0.4 else -0.05))
    # Natural districts.
    d.rounded_rectangle((1100, 930, 1460, 1360), radius=30, fill=blend((94, 135, 101), base, 0.08), outline=shade(dark, -0.10), width=5)
    for x in range(1140, 1430, 70):
        draw_tree(d, x, 1120 + (x % 80), 0.72, dark, shade((94, 135, 101), 0.14), shade(dark, 0.12))
    d.rectangle((0, 1360, 2560, 1440), fill=shade(dark, 0.02))
    d.rectangle((0, 0, 2560, 36), fill=shade(dark, -0.10))
    d.rectangle((0, 1404, 2560, 1440), fill=shade(dark, -0.10))
    d.rectangle((0, 0, 28, 1440), fill=shade(dark, -0.08))
    d.rectangle((2532, 0, 2560, 1440), fill=shade(dark, -0.08))
    if formal:
        for x in range(160, 2460, 260):
            d.line((x, 860, x + 110, 610), fill=shade(accent, 0.08), width=4)
            d.ellipse((x - 12, 846, x + 12, 870), fill=shade(accent, 0.16))
        for x in range(170, 2480, 300):
            d.rectangle((x, 40, x + 160, 88), fill=shade(accent, -0.18), outline=shade(accent, 0.22), width=3)
    noise_rect(d, (0, 0, 2560, 1440), shade(mid, 0.05), 0.035, 77, 12)
    return img

def draw_character(npc_id: str, palette, portrait=False, frame: int = 0, action: str = "walk", expression: str = "neutral") -> Image.Image:
    accent, dark, skin, cloth = palette
    outline = shade(dark, -0.28)
    cloth_light = shade(cloth, 0.20)
    skin_shadow = shade(skin, -0.16)
    if portrait:
        img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse((7, 7, 121, 123), fill=shade(dark, -0.06))
        d.ellipse((12, 12, 116, 118), fill=shade(accent, -0.05))
        d.ellipse((20, 20, 108, 118), fill=skin, outline=outline, width=3)
        d.rectangle((15, 91, 113, 128), fill=cloth, outline=outline, width=3)
        d.polygon([(24, 54), (36, 16), (92, 14), (108, 50), (94, 48), (82, 30), (54, 25), (43, 48)], fill=dark)
        eye_color = (25, 36, 43)
        if expression == "happy":
            d.arc((38, 50, 60, 66), 200, 340, fill=eye_color, width=3)
            d.arc((68, 50, 90, 66), 200, 340, fill=eye_color, width=3)
            d.arc((48, 76, 80, 96), 15, 165, fill=shade(skin, -0.38), width=3)
        elif expression == "tired":
            d.line((40, 58, 58, 61), fill=eye_color, width=3)
            d.line((70, 61, 88, 58), fill=eye_color, width=3)
            d.line((51, 84, 77, 84), fill=shade(skin, -0.32), width=3)
            d.line((34, 78, 44, 75), fill=shade(skin, -0.22), width=2)
            d.line((84, 75, 94, 78), fill=shade(skin, -0.22), width=2)
        elif expression == "worried":
            d.rectangle((43, 55, 57, 61), fill=eye_color)
            d.rectangle((71, 55, 85, 61), fill=eye_color)
            d.line((39, 48, 58, 53), fill=shade(skin, -0.34), width=2)
            d.line((70, 53, 89, 48), fill=shade(skin, -0.34), width=2)
            d.arc((49, 79, 79, 94), 190, 350, fill=shade(skin, -0.32), width=3)
        else:
            d.rectangle((43, 55, 57, 63), fill=eye_color)
            d.rectangle((71, 55, 85, 63), fill=eye_color)
            d.rectangle((53, 82, 75, 86), fill=shade(skin, -0.30))
        d.line((28, 104, 100, 104), fill=cloth_light, width=4)
        return img

    frame = frame % 4
    bob = (0, -1, 0, 1)[frame]
    img = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((4, 43, 28, 47), fill=(0, 0, 0, 55))
    if action == "sleep":
        d.rectangle((1, 25, 31, 44), fill=dark, outline=outline)
        d.rectangle((4, 28, 28, 41), fill=accent)
        d.ellipse((2, 20, 15, 38), fill=skin, outline=outline)
        d.rectangle((13, 29, 29, 39), fill=cloth)
        d.rectangle((5, 22, 13, 28), fill=dark)
        d.rectangle((8, 27, 10, 29), fill=(25, 36, 43))
        return img

    body_x = 6 if action == "pickup" else 5
    body_y = 9 + bob + (1 if action in {"work", "pickup"} else 0)
    d.rectangle((body_x, body_y, body_x + 22, body_y + 31), fill=dark, outline=outline)
    d.rectangle((body_x + 3, body_y + 2, body_x + 19, body_y + 28), fill=accent)
    d.rectangle((body_x + 3, body_y + 23, body_x + 19, body_y + 28), fill=cloth)
    d.line((body_x + 3, body_y + 22, body_x + 19, body_y + 22), fill=cloth_light, width=2)

    if action == "work":
        left_leg = (8, 10, 9, 11)[frame]
        right_leg = (20, 19, 21, 20)[frame]
    elif action == "pickup":
        left_leg = (5, 6, 5, 6)[frame]
        right_leg = (24, 23, 24, 23)[frame]
    else:
        left_leg = (9, 7, 9, 11)[frame]
        right_leg = (19, 21, 19, 17)[frame]
    d.rectangle((left_leg, body_y + 29, left_leg + 7, 47), fill=cloth, outline=outline)
    d.rectangle((right_leg, body_y + 29, right_leg + 7, 47), fill=cloth, outline=outline)

    head_y = 0 + bob
    d.ellipse((7, head_y, 25, head_y + 19), fill=skin, outline=outline, width=2)
    d.rectangle((7, head_y, 25, head_y + 6), fill=dark)
    if npc_id in {"mei", "azhen", "xiaoyu"}:
        d.ellipse((4, head_y, 14, head_y + 14), fill=dark)
        d.ellipse((18, head_y, 28, head_y + 14), fill=dark)
    d.rectangle((12, head_y + 8, 14, head_y + 10), fill=(25, 36, 43))
    d.rectangle((18, head_y + 8, 20, head_y + 10), fill=(25, 36, 43))
    d.rectangle((14, head_y + 14, 19, head_y + 15), fill=shade(skin, -0.34))

    arm_swing = (-2, 0, 2, 0)[frame]
    if action == "work":
        d.rectangle((25, body_y + 8, 31, body_y + 13), fill=skin)
        d.rectangle((27, body_y + 5, 30, body_y + 15), fill=(126, 100, 65))
        d.rectangle((26, body_y + 4, 32, body_y + 7), fill=(180, 148, 82))
    elif action == "eat":
        d.rectangle((23, body_y + 12, 29, body_y + 17), fill=skin)
        d.ellipse((20, body_y + 17, 31, body_y + 24), fill=(210, 190, 135))
        d.ellipse((21, body_y + 18, 30, body_y + 23), fill=(143, 94, 69))
    elif action == "interact":
        d.rectangle((25, body_y + 2 + arm_swing, 29, body_y + 12 + arm_swing), fill=skin)
        d.rectangle((28, body_y, 30, body_y + 2), fill=(247, 220, 135))
    elif action == "pickup":
        d.rectangle((25, body_y + 20, 30, body_y + 29), fill=skin)
        d.rectangle((27, body_y + 28, 32, body_y + 31), fill=(184, 145, 92))
    else:
        d.rectangle((1, body_y + 9 + arm_swing, 5, body_y + 19 + arm_swing), fill=skin)
        d.rectangle((27, body_y + 9 - arm_swing, 31, body_y + 19 - arm_swing), fill=skin)
    d.rectangle((body_x + 8, body_y + 10, body_x + 15, body_y + 12), fill=cloth_light)
    return img

def draw_formal_world(npc_id: str, palette, frame: int = 0, action: str = "walk") -> Image.Image:
    base = draw_character(npc_id, palette, False, frame, action).resize((64, 96), Image.Resampling.NEAREST)
    img = Image.new("RGBA", (64, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    accent, dark, skin, cloth = palette
    d.ellipse((8, 83, 56, 94), fill=(0, 0, 0, 55))
    img.alpha_composite(base, (0, 0))
    # Formal layer adds a readable silhouette edge and a small role accessory.
    d.line((18, 20, 45, 20), fill=shade(accent, 0.28), width=2)
    if npc_id in {"mei", "azhen", "xiaoyu", "zhoujie"}:
        d.ellipse((47, 18, 57, 28), fill=shade(accent, 0.20))
    elif npc_id in {"wang", "asen", "laoxu"}:
        d.rectangle((48, 28, 58, 42), fill=shade(cloth, 0.18), outline=shade(dark, -0.10), width=2)
    elif npc_id in {"lin_doctor", "chen"}:
        d.rectangle((48, 30, 57, 43), fill=shade(accent, 0.16), outline=shade(dark, -0.12), width=2)
    return img

def draw_formal_portrait(npc_id: str, palette, expression: str = "neutral") -> Image.Image:
    accent, dark, skin, cloth = palette
    base = draw_character(npc_id, palette, True, 0, "walk", expression).resize((160, 160), Image.Resampling.NEAREST)
    img = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(0, 192, 8):
        amount = y / 192.0
        d.rectangle((0, y, 192, y + 7), fill=blend(shade(dark, 0.06), shade(accent, 0.08), amount))
    d.rounded_rectangle((2, 2, 189, 189), radius=22, outline=shade(accent, 0.25), width=4)
    img.alpha_composite(base, (16, 16))
    d.rounded_rectangle((24, 154, 168, 178), radius=10, fill=shade(dark, -0.08), outline=shade(accent, 0.20), width=2)
    return img

def draw_item(item_id: str, kind: str) -> Image.Image:
    palette = [
        (230, 174, 91), (158, 202, 177), (199, 120, 102), (139, 155, 204),
        (203, 190, 136), (126, 165, 184), (188, 142, 190)
    ]
    seed = sum(ord(c) for c in item_id)
    color = palette[seed % len(palette)]
    dark = shade(color, -0.52)
    light = shade(color, 0.34)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((4, 26, 28, 30), fill=(0, 0, 0, 45))
    if kind in {"food", "drink"} or any(word in item_id for word in ("tea", "coffee", "water", "milk", "noodle", "rice", "bun", "bread")):
        d.rounded_rectangle((5, 6, 27, 27), radius=4, fill=dark, outline=dark, width=2)
        d.rounded_rectangle((7, 8, 25, 25), radius=3, fill=color)
        d.arc((9, 1, 23, 14), 180, 360, fill=light, width=3)
        d.ellipse((12, 15, 20, 22), fill=shade(light, 0.10))
        d.rectangle((8, 25, 24, 27), fill=blend(color, dark, 0.40))
    elif kind == "seed" or "seed" in item_id:
        d.rectangle((6, 4, 26, 28), fill=dark, outline=dark, width=2)
        d.rectangle((8, 6, 24, 25), fill=(213, 190, 119))
        d.ellipse((11, 10, 17, 16), fill=shade(color, -0.15))
        d.ellipse((17, 14, 23, 20), fill=shade(color, 0.12))
        d.line((10, 22, 22, 22), fill=(103, 91, 60), width=2)
    elif kind in {"pet_supply", "decor"}:
        d.rounded_rectangle((4, 6, 28, 28), radius=4, fill=dark, outline=dark, width=2)
        d.rounded_rectangle((7, 9, 25, 25), radius=3, fill=color)
        if kind == "pet_supply":
            d.ellipse((10, 12, 15, 17), fill=light)
            d.ellipse((18, 12, 23, 17), fill=light)
            d.arc((10, 16, 23, 24), 20, 160, fill=dark, width=2)
        else:
            d.rectangle((9, 12, 23, 23), outline=light, width=2)
            d.line((11, 25, 21, 25), fill=light, width=2)
    else:
        # Collectibles and tools use a faceted silhouette so rarity reads at a glance.
        if seed % 3 == 0:
            d.polygon([(16, 2), (29, 11), (25, 29), (7, 29), (3, 11)], fill=dark)
            d.polygon([(16, 6), (25, 13), (22, 25), (10, 25), (7, 13)], fill=color)
            d.line((10, 10, 22, 22), fill=light, width=2)
        elif seed % 3 == 1:
            d.ellipse((4, 8, 28, 28), fill=dark)
            d.ellipse((7, 11, 25, 25), fill=color)
            d.arc((9, 13, 23, 27), 190, 350, fill=light, width=2)
        else:
            d.rounded_rectangle((5, 5, 27, 28), radius=3, fill=dark)
            d.rounded_rectangle((8, 8, 24, 25), radius=2, fill=color)
            d.line((11, 11, 21, 21), fill=light, width=2)
    d.point((10, 9), fill=(255, 244, 205))
    return img

def draw_formal_item(item_id: str, kind: str) -> Image.Image:
    palette = [
        (234, 181, 94), (143, 203, 177), (209, 119, 102), (132, 158, 215),
        (205, 189, 128), (116, 172, 191), (189, 139, 196)
    ]
    seed = sum(ord(c) for c in item_id)
    color = palette[seed % len(palette)]
    dark = shade(color, -0.58)
    light = shade(color, 0.42)
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((7, 39, 41, 46), fill=(0, 0, 0, 65))
    is_drink = kind == "drink" or any(word in item_id for word in ("tea", "coffee", "water", "milk", "soy"))
    is_food = kind == "food" or any(word in item_id for word in ("rice", "bread", "bun", "noodle", "dumpling", "sandwich", "fruit"))
    if is_drink or kind == "drink":
        d.rounded_rectangle((9, 12, 39, 40), radius=6, fill=dark, outline=dark, width=3)
        d.rounded_rectangle((12, 15, 36, 37), radius=5, fill=color)
        d.rectangle((21, 3, 27, 17), fill=light)
        d.rectangle((15, 10, 34, 13), fill=shade(light, 0.15))
        for x, y in [(17, 24), (23, 28), (29, 22), (20, 33), (31, 32)]:
            d.ellipse((x, y, x + 5, y + 5), fill=shade(dark, 0.18))
    elif is_food:
        d.ellipse((7, 12, 41, 41), fill=dark)
        d.ellipse((10, 15, 38, 38), fill=shade(color, -0.12))
        d.ellipse((14, 18, 34, 35), fill=shade(light, -0.10))
        d.arc((17, 9, 31, 23), 190, 350, fill=(245, 235, 205, 180), width=2)
        d.arc((14, 5, 34, 20), 190, 350, fill=(245, 235, 205, 120), width=2)
    elif kind == "seed" or "seed" in item_id:
        d.rectangle((8, 7, 40, 41), fill=dark, outline=dark, width=3)
        d.rectangle((11, 10, 37, 38), fill=(217, 197, 131))
        d.ellipse((16, 18, 24, 26), fill=shade(color, -0.18))
        d.ellipse((25, 22, 33, 30), fill=shade(color, 0.15))
        d.line((17, 14, 31, 14), fill=shade(dark, 0.18), width=2)
    elif kind in {"pet_supply", "decor"}:
        d.rounded_rectangle((7, 10, 41, 42), radius=6, fill=dark, outline=dark, width=3)
        d.rounded_rectangle((11, 14, 37, 38), radius=4, fill=color)
        if kind == "pet_supply":
            d.ellipse((16, 19, 21, 24), fill=light)
            d.ellipse((27, 19, 32, 24), fill=light)
            d.arc((16, 24, 32, 34), 20, 160, fill=dark, width=2)
        else:
            d.rectangle((15, 18, 33, 34), outline=light, width=3)
            d.line((18, 39, 30, 39), fill=light, width=2)
    else:
        if seed % 3 == 0:
            d.polygon([(24, 3), (43, 16), (37, 43), (11, 43), (5, 16)], fill=dark)
            d.polygon([(24, 8), (37, 19), (33, 38), (15, 38), (11, 19)], fill=color)
            d.line((15, 15, 34, 34), fill=light, width=3)
            d.line((33, 15, 16, 35), fill=shade(color, -0.20), width=2)
        elif seed % 3 == 1:
            d.ellipse((5, 10, 43, 42), fill=dark)
            d.ellipse((10, 15, 38, 38), fill=color)
            d.arc((14, 18, 34, 38), 190, 350, fill=light, width=3)
        else:
            d.rounded_rectangle((7, 6, 41, 42), radius=5, fill=dark)
            d.rounded_rectangle((11, 10, 37, 38), radius=3, fill=color)
            d.line((15, 15, 33, 31), fill=light, width=3)
    d.point((15, 15), fill=(255, 249, 220))
    return img

def draw_ui_panel() -> Image.Image:
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((1, 1, 62, 62), radius=12, fill=(5, 16, 21, 245), outline=(233, 185, 91, 235), width=3)
    d.rounded_rectangle((6, 6, 57, 57), radius=9, outline=(74, 119, 116, 180), width=2)
    d.line((12, 10, 52, 10), fill=(255, 226, 145, 100), width=2)
    return img

def draw_ui_button() -> Image.Image:
    img = Image.new("RGBA", (96, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((1, 1, 94, 38), radius=9, fill=(14, 35, 41, 246), outline=(239, 190, 90, 225), width=2)
    d.rounded_rectangle((5, 5, 90, 34), radius=7, outline=(81, 132, 126, 155), width=1)
    d.line((13, 8, 82, 8), fill=(255, 225, 145, 75), width=2)
    return img

def draw_ui_slot() -> Image.Image:
    img = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((1, 1, 70, 70), radius=10, fill=(8, 24, 29, 242), outline=(218, 174, 86, 210), width=2)
    d.rounded_rectangle((6, 6, 65, 65), radius=8, outline=(72, 121, 118, 155), width=1)
    d.line((12, 10, 60, 10), fill=(255, 225, 145, 65), width=2)
    return img

def draw_formal_ui_panel() -> Image.Image:
    img = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2, 2, 93, 93), radius=15, fill=(5, 15, 22, 248), outline=(238, 190, 91, 240), width=3)
    d.rounded_rectangle((8, 8, 87, 87), radius=11, outline=(76, 128, 124, 190), width=2)
    d.line((18, 13, 78, 13), fill=(255, 229, 153, 115), width=2)
    d.line((18, 82, 78, 82), fill=(71, 109, 107, 120), width=2)
    return img

def draw_formal_ui_button() -> Image.Image:
    img = Image.new("RGBA", (128, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2, 2, 125, 45), radius=11, fill=(10, 28, 35, 248), outline=(234, 184, 83, 230), width=3)
    d.rounded_rectangle((8, 7, 119, 39), radius=8, outline=(92, 147, 140, 150), width=2)
    d.line((22, 11, 106, 11), fill=(255, 229, 153, 95), width=2)
    d.line((22, 35, 106, 35), fill=(47, 80, 82, 120), width=2)
    return img

def draw_formal_ui_slot() -> Image.Image:
    img = Image.new("RGBA", (80, 80), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2, 2, 77, 77), radius=11, fill=(7, 22, 28, 245), outline=(216, 170, 82, 220), width=3)
    d.rounded_rectangle((8, 8, 71, 71), radius=8, outline=(72, 122, 119, 170), width=2)
    d.line((16, 13, 64, 13), fill=(255, 226, 145, 80), width=2)
    return img

def draw_formal_ui_title() -> Image.Image:
    img = Image.new("RGBA", (320, 100), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2, 2, 317, 97), radius=18, fill=(4, 13, 20, 230), outline=(239, 190, 86, 220), width=3)
    d.line((28, 18, 292, 18), fill=(255, 225, 143, 100), width=2)
    d.line((28, 82, 292, 82), fill=(70, 112, 112, 100), width=2)
    return img

def main():
    # backgrounds
    scene_ids = set(SCENE_PALETTES)
    for row in csv.DictReader((DATA/"scene_metadata.csv").open(encoding="utf-8-sig")):
        scene_ids.add(row["area_id"])
    for area_id in sorted(scene_ids):
        pal = SCENE_PALETTES.get(area_id, ((116,132,127),(49,62,65),(154,143,118),(116,166,157)))
        if area_id == "street":
            save(draw_city_map(pal), ART/"scenes"/area_id/"background.png")
            save(draw_city_map(pal, True), ART/"formal"/"scenes"/area_id/"background.png")
            continue
        save(draw_scene(area_id, pal), ART/"scenes"/area_id/"background.png")
        if area_id in {"home", "street", "restaurant", "farm", "night_market"}:
            save(draw_scene(area_id, pal, True), ART/"formal"/"scenes"/area_id/"background.png")
    # characters are data-driven; hand-tuned palettes remain optional overrides.
    npc_rows = list(csv.DictReader((DATA/"npcs.csv").open(encoding="utf-8-sig")))
    for row in npc_rows:
        npc_id = row["npc_id"]
        pal = NPC_PALETTES.get(npc_id, palette_from_color(row.get("color", "#ffffff"), npc_id))
        save(draw_character(npc_id,pal,False,0,"walk"), ART/"characters"/npc_id/"world.png")
        for frame in range(4):
            save(draw_character(npc_id,pal,False,frame,"walk"), ART/"characters"/npc_id/f"world_{frame+1}.png")
        for action in ("work","eat","sleep","interact","pickup"):
            for frame in range(4):
                save(draw_character(npc_id,pal,False,frame,action), ART/"characters"/npc_id/"actions"/f"{action}_{frame+1}.png")
        save(draw_character(npc_id,pal,True), ART/"characters"/npc_id/"portrait.png")
        save(draw_formal_world(npc_id,pal,0,"walk"), ART/"formal"/"characters"/npc_id/"world.png")
        for frame in range(4):
            save(draw_formal_world(npc_id,pal,frame,"walk"), ART/"formal"/"characters"/npc_id/f"world_{frame+1}.png")
        for action in ("work","eat","sleep","interact","pickup"):
            for frame in range(4):
                save(draw_formal_world(npc_id,pal,frame,action), ART/"formal"/"characters"/npc_id/"actions"/f"{action}_{frame+1}.png")
        save(draw_formal_portrait(npc_id,pal), ART/"formal"/"characters"/npc_id/"portrait.png")
        for expression in ("happy","tired","worried"):
            save(draw_formal_portrait(npc_id,pal,expression), ART/"formal"/"characters"/npc_id/f"portrait_{expression}.png")
        for expression in ("happy","tired","worried"):
            save(draw_character(npc_id,pal,True,expression=expression), ART/"characters"/npc_id/f"portrait_{expression}.png")
    candidate_path = DATA/"staff_candidates.csv"
    if candidate_path.exists():
        for row in csv.DictReader(candidate_path.open(encoding="utf-8-sig")):
            candidate_id = row["candidate_id"]
            pal = palette_from_color(row.get("color", "#ffffff"), candidate_id)
            save(draw_character(candidate_id,pal,False,0,"walk"), ART/"characters"/candidate_id/"world.png")
            for frame in range(4):
                save(draw_character(candidate_id,pal,False,frame,"walk"), ART/"characters"/candidate_id/f"world_{frame+1}.png")
            save(draw_character(candidate_id,pal,True), ART/"characters"/candidate_id/"portrait.png")
            for expression in ("happy","tired","worried"):
                save(draw_character(candidate_id,pal,True,expression=expression), ART/"characters"/candidate_id/f"portrait_{expression}.png")
            save(draw_formal_world(candidate_id,pal,0,"walk"), ART/"formal"/"characters"/candidate_id/"world.png")
            for frame in range(4):
                save(draw_formal_world(candidate_id,pal,frame,"walk"), ART/"formal"/"characters"/candidate_id/f"world_{frame+1}.png")
            save(draw_formal_portrait(candidate_id,pal), ART/"formal"/"characters"/candidate_id/"portrait.png")
            for expression in ("happy","tired","worried"):
                save(draw_formal_portrait(candidate_id,pal,expression), ART/"formal"/"characters"/candidate_id/f"portrait_{expression}.png")
    player_pal = NPC_PALETTES["player"]
    save(draw_character("player",player_pal,False,0,"walk"), ART/"characters"/"player"/"world.png")
    for frame in range(4):
        save(draw_character("player",player_pal,False,frame,"walk"), ART/"characters"/"player"/f"world_{frame+1}.png")
    for action in ("work","eat","sleep","interact","pickup"):
        for frame in range(4):
            save(draw_character("player",player_pal,False,frame,action), ART/"characters"/"player"/"actions"/f"{action}_{frame+1}.png")
    save(draw_character("player",player_pal,True), ART/"characters"/"player"/"portrait.png")
    save(draw_formal_world("player",player_pal,0,"walk"), ART/"formal"/"characters"/"player"/"world.png")
    for frame in range(4):
        save(draw_formal_world("player",player_pal,frame,"walk"), ART/"formal"/"characters"/"player"/f"world_{frame+1}.png")
    for action in ("work","eat","sleep","interact","pickup"):
        for frame in range(4):
            save(draw_formal_world("player",player_pal,frame,action), ART/"formal"/"characters"/"player"/"actions"/f"{action}_{frame+1}.png")
    save(draw_formal_portrait("player",player_pal), ART/"formal"/"characters"/"player"/"portrait.png")
    for expression in ("happy","tired","worried"):
        save(draw_formal_portrait("player",player_pal,expression), ART/"formal"/"characters"/"player"/f"portrait_{expression}.png")
    for expression in ("happy","tired","worried"):
        save(draw_character("player",player_pal,True,expression=expression), ART/"characters"/"player"/f"portrait_{expression}.png")
    # items and collectibles
    for row in csv.DictReader((DATA/"items.csv").open(encoding="utf-8-sig")):
        item_id = row["item_id"]
        kind = row.get("kind","misc")
        save(draw_item(item_id, kind), ART/"items"/item_id/"icon.png")
        save(draw_formal_item(item_id, kind), ART/"formal"/"items"/item_id/"icon.png")
    for row in csv.DictReader((DATA/"collectibles.csv").open(encoding="utf-8-sig")):
        item_id = row["item_id"]
        save(draw_item(item_id, "collectible"), ART/"items"/item_id/"icon.png")
        save(draw_formal_item(item_id, "collectible"), ART/"formal"/"items"/item_id/"icon.png")
    # ui
    save(draw_ui_panel(), ART/"ui"/"panel.png")
    save(draw_ui_button(), ART/"ui"/"button.png")
    save(draw_ui_slot(), ART/"ui"/"slot.png")
    save(draw_ui_panel(), ART/"ui"/"title.png")
    save(draw_formal_ui_panel(), ART/"formal"/"ui"/"panel.png")
    save(draw_formal_ui_button(), ART/"formal"/"ui"/"button.png")
    save(draw_formal_ui_slot(), ART/"formal"/"ui"/"slot.png")
    save(draw_formal_ui_title(), ART/"formal"/"ui"/"title.png")
    print(f"pixel art generated under {ART}")

if __name__ == "__main__":
    main()
