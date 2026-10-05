"""Rebuild the editable-model catalog from all rendered food-stage previews."""

from math import ceil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


MODEL_DIR = Path(__file__).resolve().parents[2] / "assets" / "art" / "models" / "food_stage"
OUTPUT = MODEL_DIR / "food_stage_contact_sheet.png"
CELL = (250, 222)
COLUMNS = 5


def main() -> None:
    previews = sorted(MODEL_DIR.glob("*_preview.png"))
    if not previews:
        raise SystemExit("No food-stage previews found")
    rows = ceil(len(previews) / COLUMNS)
    sheet = Image.new("RGB", (COLUMNS * CELL[0], rows * CELL[1]), "#f4f0e7")
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/arial.ttf")
    font = ImageFont.truetype(str(font_path), 13) if font_path.exists() else ImageFont.load_default()
    for index, preview in enumerate(previews):
        x = index % COLUMNS * CELL[0]
        y = index // COLUMNS * CELL[1]
        with Image.open(preview) as original:
            tile = ImageOps.fit(original.convert("RGB"), (CELL[0], CELL[1] - 26))
        sheet.paste(tile, (x, y))
        draw.rectangle((x, y + CELL[1] - 26, x + CELL[0], y + CELL[1]), fill="#ebe7dd")
        draw.text((x + 8, y + CELL[1] - 20), preview.stem.removesuffix("_preview"),
                  fill="#3a5550", font=font)
    sheet.save(OUTPUT)
    print(f"FOOD_STAGE_CONTACT_SHEET:{OUTPUT}:{len(previews)}")


if __name__ == "__main__":
    main()
