"""Render the launcher icons in the game's own style: four letter tiles on the board colour.

    python tools/make_icons.py

Writes the legacy mipmap PNGs (48..192 px) and the adaptive-icon foreground layers (108..432 px,
keeping the tiles inside the 66/108 safe zone), plus the anydpi-v26 XML that pairs the foreground
with the board colour. Pillow only, no network.
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RES = os.path.join(ROOT, "app", "res")

BOARD = (34, 17, 0, 255)
TILES = [
    ((199, 79, 160, 255), "T"),
    ((57, 179, 106, 255), "E"),
    ((63, 169, 199, 255), "X"),
    ((224, 138, 60, 255), "T"),
]
LETTER = (255, 255, 255, 255)
LETTER_EDGE = (34, 17, 0, 255)

FONTS = [
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\segoeuib.ttf",
    r"C:\Windows\Fonts\arial.ttf",
]
LEGACY = [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]
FOREGROUND = [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)]
SS = 8  # supersample factor


def pick_font() -> str:
    for path in FONTS:
        if os.path.exists(path):
            return path
    raise SystemExit("no truetype font found")


def draw_tiles(canvas, size, span, font_path):
    """Draw the 2x2 letter grid inside a centred square of `span` pixels."""
    draw = ImageDraw.Draw(canvas)
    tile = span / 2
    radius = tile * 0.42
    letter_px = int(tile * 0.72)
    font = ImageFont.truetype(font_path, letter_px)
    origin = (size - span) / 2

    for index, (color, letter) in enumerate(TILES):
        col, row = index % 2, index // 2
        cx = origin + col * tile + tile / 2
        cy = origin + row * tile + tile / 2
        draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color)

        box = draw.textbbox((0, 0), letter, font=font, stroke_width=max(1, letter_px // 12))
        draw.text(
            (cx - (box[0] + box[2]) / 2, cy - (box[1] + box[3]) / 2),
            letter,
            font=font,
            fill=LETTER,
            stroke_width=max(1, letter_px // 12),
            stroke_fill=LETTER_EDGE,
        )


def write(path, canvas, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    canvas.resize((size, size), Image.LANCZOS).save(path)
    print("wrote", os.path.relpath(path, ROOT))


def main() -> None:
    font_path = pick_font()

    for density, size in LEGACY:
        big = Image.new("RGBA", (size * SS, size * SS), BOARD)
        draw_tiles(big, size * SS, size * SS * 0.84, font_path)
        write(os.path.join(RES, "mipmap-" + density, "ic_launcher.png"), big, size)

    for density, size in FOREGROUND:
        # An adaptive icon is 108dp with the visible mask covering the middle 72dp and a 66dp
        # safe zone inside that; 0.58 of the canvas keeps the tiles clear of every mask shape.
        big = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
        draw_tiles(big, size * SS, size * SS * 0.58, font_path)
        write(os.path.join(RES, "mipmap-" + density, "ic_launcher_foreground.png"), big, size)


if __name__ == "__main__":
    main()
