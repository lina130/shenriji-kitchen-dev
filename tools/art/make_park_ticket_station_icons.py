"""Draw the ten compact, hand-composed appliance thumbnails for kitchen tickets.

These are UI depictions of the existing workstations, not replacements for the
modeled kitchen props. Work at 4x resolution so the 46 x 37 ticket slot keeps
its small food and tool details after Godot scales it down.
"""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/ui/stations"
S = 4
W, H = 46, 37


def box(d, xy, fill, radius=0, outline=None, width=1):
    rect = tuple(round(v * S) for v in xy)
    if radius:
        d.rounded_rectangle(rect, radius=round(radius * S), fill=fill,
                            outline=outline, width=round(width * S))
    else:
        d.rectangle(rect, fill=fill, outline=outline, width=round(width * S))


def oval(d, xy, fill, outline=None, width=1):
    d.ellipse(tuple(round(v * S) for v in xy), fill=fill, outline=outline,
              width=round(width * S))


def line(d, pts, fill, width=1, joint="curve"):
    d.line([(round(x * S), round(y * S)) for x, y in pts], fill=fill,
           width=round(width * S), joint=joint)


def poly(d, pts, fill):
    d.polygon([(round(x * S), round(y * S)) for x, y in pts], fill=fill)


def arc(d, xy, start, end, fill, width=1):
    d.arc(tuple(round(v * S) for v in xy), start, end, fill=fill,
          width=round(width * S))


INK = "#557166"
DEEP = "#3f5e56"
EDGE = "#a98f70"
CREAM = "#f6edda"
LIGHT = "#fff8e9"
TEAL = "#91b4a4"
WATER = "#b6d7c9"
WOOD = "#c99767"
WOOD_DARK = "#966d4c"
GREENS = "#719d64"
GOLD = "#edbe6f"
TOMATO = "#cc6d54"


def shadow(d, xy):
    oval(d, xy, "#6c574744")


def plate(d, xy):
    shadow(d, (xy[0] + 1, xy[1] + 2, xy[2] + 1, xy[3] + 2))
    oval(d, xy, "#d7c5a4", EDGE, 0.6)
    oval(d, (xy[0] + 2, xy[1] + 2, xy[2] - 2, xy[3] - 2), LIGHT, "#b8c5ad", 0.7)


def leaf(d, x, y, rot=False):
    if rot:
        oval(d, (x - 1.8, y - 3.0, x + 1.8, y + 3.0), GREENS)
        line(d, [(x, y - 2), (x, y + 2)], "#dfdf9d", 0.5)
    else:
        oval(d, (x - 3.0, y - 1.8, x + 3.0, y + 1.8), GREENS)
        line(d, [(x - 2, y), (x + 2, y)], "#dfdf9d", 0.5)


def draw_wash(d):
    shadow(d, (3, 29, 42, 35))
    oval(d, (3, 11, 42, 33), "#e2e7d9", DEEP, 1)
    oval(d, (7, 14, 38, 30), WATER, "#78a8a0", 1)
    arc(d, (10, 15, 36, 28), 10, 170, "#eaf8e7", 1)
    line(d, [(19, 12), (19, 4), (25, 3), (29, 5), (29, 10)], DEEP, 2.6)
    line(d, [(19, 5), (25, 4), (29, 7)], "#b6d2b9", 1)
    oval(d, (26.5, 9, 31, 11), "#698d81")
    line(d, [(29, 12), (28, 17)], "#7ebdc5", 1.5)
    oval(d, (13, 20, 19, 25), "#d6c995")
    leaf(d, 24, 22)
    oval(d, (30, 20, 35, 25), TOMATO)
    oval(d, (32, 21, 33, 22), LIGHT)


def draw_slice(d):
    shadow(d, (4, 29, 42, 34))
    box(d, (4, 5, 42, 31), WOOD_DARK, 3)
    box(d, (6, 6, 40, 29), "#d8ad7c", 2)
    line(d, [(9, 8), (36, 8)], "#efcca0", 0.8)
    oval(d, (34, 24, 38, 27), "#896647")
    for x in (12, 17, 22):
        oval(d, (x - 2, 20, x + 2.5, 25), "#a8bc78", INK, 0.4)
        line(d, [(x - 1, 21), (x + 1.5, 23)], "#decb95", 0.5)
    oval(d, (24, 11, 30, 16), TOMATO)
    leaf(d, 32, 13)
    poly(d, [(8, 17), (28, 12), (31, 15), (11, 21)], "#e6e9db")
    line(d, [(9, 19), (30, 14)], "#9aa79a", 0.8)
    box(d, (29, 10, 38, 15), "#6d503d", 1.4)
    oval(d, (34, 11, 35.5, 12.5), "#d9b481")


def draw_mix(d):
    shadow(d, (6, 29, 40, 35))
    oval(d, (5, 11, 40, 32), "#8da99a", DEEP, 1)
    oval(d, (8, 12, 37, 27), "#e8d0a3", "#f7ecd3", 1.6)
    arc(d, (13, 15, 31, 24), 10, 210, "#bd8859", 1)
    arc(d, (17, 16, 34, 23), 180, 345, CREAM, 1)
    oval(d, (13, 17, 17, 20), TOMATO)
    leaf(d, 26, 21)
    line(d, [(34, 3), (26, 19)], WOOD_DARK, 2.1)
    oval(d, (22, 17, 29, 23), None, "#9ca797", 1)
    for x in (24, 26, 28):
        line(d, [(x, 17), (x - 2, 22)], "#9ca797", 0.7)


def draw_marinate(d):
    shadow(d, (3, 29, 43, 35))
    box(d, (3, 26, 43, 31), WOOD_DARK, 1)
    box(d, (5, 25, 41, 29), "#d7aa76", 1)
    for x, fill, lid in ((7, "#b97658", "#dfb475"),
                         (18, "#8aab85", "#c99e6a"),
                         (29, "#c7976b", "#e1bf8c")):
        box(d, (x, 9, x + 9, 26), fill, 2, DEEP, 0.8)
        box(d, (x - 0.6, 7, x + 9.6, 10), lid, 1.2, WOOD_DARK, 0.6)
        box(d, (x + 1, 16, x + 8, 21), CREAM, 0.7)
        oval(d, (x + 2, 17, x + 4.3, 19.3), TOMATO)
        line(d, [(x + 2, 12), (x + 2, 15)], LIGHT, 0.7)
    leaf(d, 39, 23, True)


def draw_portion(d):
    shadow(d, (3, 30, 43, 35))
    box(d, (3, 7, 43, 31), WOOD_DARK, 3)
    box(d, (5, 8, 41, 29), "#d7aa75", 2)
    for x, fill in ((8, "#ede2bd"), (19, "#c68255"), (30, "#8eab77")):
        oval(d, (x - 1, 12, x + 9, 26), "#f7eedc", EDGE, 0.6)
        oval(d, (x, 14, x + 8, 24), fill)
        oval(d, (x + 1, 15, x + 3, 17), "#fff3d2")
    leaf(d, 34, 19, True)
    line(d, [(9, 10), (39, 10)], LIGHT, 0.7)


def draw_steam(d):
    shadow(d, (4, 30, 43, 35))
    for x in (13, 23, 33):
        arc(d, (x - 3, 1, x + 3, 15), 240, 80, "#d7d9c7", 1)
    oval(d, (5, 17, 41, 33), "#a7764b", WOOD_DARK, 0.8)
    box(d, (5, 16, 41, 27), "#c8995e", 1, WOOD_DARK, 0.7)
    for y in (21, 26):
        line(d, [(7, y), (39, y)], "#9e6e43", 0.8)
    oval(d, (5, 10, 41, 22), "#efd09b", WOOD_DARK, 1)
    oval(d, (8, 12, 38, 20), "#ba8e58")
    for x in (14, 23, 32):
        oval(d, (x - 4, 11, x + 4, 19), CREAM, EDGE, 0.4)
        line(d, [(x - 2, 14), (x, 12), (x + 2, 14)], "#d5bf99", 0.5)


def draw_fry(d):
    shadow(d, (3, 29, 43, 35))
    line(d, [(31, 20), (44, 17)], "#493e32", 4)
    line(d, [(33, 19), (43, 17)], "#8c6749", 2)
    oval(d, (3, 7, 34, 32), "#4e756c", DEEP, 1.1)
    oval(d, (6, 9, 31, 29), "#d79d55", "#e6c288", 1)
    oval(d, (10, 13, 24, 24), "#b66343", "#e4ad6e", 0.7)
    for y in (15, 19, 23):
        line(d, [(13, y), (21, y + 1)], "#814b38", 0.8)
    for x, y in ((9, 12), (27, 14), (27, 24), (8, 26)):
        oval(d, (x, y, x + 2, y + 2), CREAM)
    leaf(d, 25, 22)


def draw_boil(d):
    shadow(d, (4, 30, 42, 35))
    box(d, (6, 12, 40, 31), "#759f91", 4, DEEP, 1)
    box(d, (3, 16, 8, 23), WOOD_DARK, 1)
    box(d, (38, 16, 43, 23), WOOD_DARK, 1)
    oval(d, (6, 8, 40, 19), "#a9c7b5", DEEP, 0.9)
    oval(d, (10, 10, 36, 17), "#bf9158")
    for x in (15, 20, 26):
        arc(d, (x - 4, 10, x + 5, 17), 20, 155, CREAM, 1)
    oval(d, (28, 11, 31, 14), CREAM)
    oval(d, (33, 8, 35, 10), "#d6e4d3")
    arc(d, (13, 1, 19, 12), 220, 90, "#c5d7c9", 1)
    arc(d, (27, 0, 33, 11), 220, 90, "#c5d7c9", 1)


def draw_garnish(d):
    plate(d, (4, 5, 42, 33))
    oval(d, (12, 13, 34, 27), "#e4c293")
    for x, y in ((15, 15), (22, 13), (29, 18), (19, 24)):
        leaf(d, x, y, y < 20)
    oval(d, (25, 22, 30, 26), TOMATO)
    for x, y in ((13, 23), (33, 14), (25, 17)):
        oval(d, (x, y, x + 2, y + 2), CREAM)
    line(d, [(36, 3), (29, 17)], "#887960", 1.6)
    oval(d, (27, 15, 31, 19), None, "#887960", 0.9)


def draw_serve(d):
    shadow(d, (2, 30, 44, 35))
    box(d, (3, 11, 43, 32), "#7f9f8e", 3, DEEP, 0.8)
    box(d, (6, 13, 40, 29), "#d7b889", 2)
    box(d, (1, 19, 5, 25), WOOD_DARK, 1)
    box(d, (41, 19, 45, 25), WOOD_DARK, 1)
    oval(d, (8, 16, 22, 27), CREAM, EDGE, 0.7)
    oval(d, (11, 18, 19, 25), "#bd7e58")
    leaf(d, 17, 19)
    box(d, (24, 16, 30, 27), "#b9d8bb", 1, DEEP, 0.5)
    oval(d, (24, 13, 30, 17), CREAM, EDGE, 0.5)
    oval(d, (33, 18, 38, 23), GOLD, WOOD_DARK, 0.5)
    box(d, (32, 23, 39, 25), "#9d7950", 1)
    oval(d, (34, 15, 36, 18), TOMATO)


DRAWERS = {
    "wash": draw_wash,
    "slice": draw_slice,
    "mix": draw_mix,
    "marinate": draw_marinate,
    "portion": draw_portion,
    "steam": draw_steam,
    "fry": draw_fry,
    "boil": draw_boil,
    "garnish": draw_garnish,
    "serve": draw_serve,
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    previews = []
    for name, drawer in DRAWERS.items():
        canvas = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
        drawer(ImageDraw.Draw(canvas))
        canvas.save(OUT / f"{name}.png")
        previews.append((name, canvas.resize((W * 3, H * 3), Image.Resampling.LANCZOS)))
    sheet = Image.new("RGB", (5 * 158, 2 * 145), "#f5eedc")
    labels = ImageDraw.Draw(sheet)
    for i, (name, icon) in enumerate(previews):
        x, y = (i % 5) * 158 + 10, (i // 5) * 145 + 10
        sheet.paste(icon, (x, y), icon)
        labels.text((x + 4, y + 115), name, fill=DEEP)
    sheet.save(ROOT / "output/station_icon_contact.png")
    print(f"STATION_ICONS:{len(DRAWERS)}:{OUT}")


if __name__ == "__main__":
    main()
