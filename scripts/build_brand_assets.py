"""Generate the SALUS favicon PNGs from the brand mark.

Run with Pillow installed:
    python scripts/build_brand_assets.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "frontend" / "landing"
ACCENT = (53, 214, 164, 255)
SURFACE = (24, 24, 24, 255)


def draw_icon(size: int) -> Image.Image:
    scale = 8
    edge = size * scale
    image = Image.new("RGBA", (edge, edge), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        (0, 0, edge - 1, edge - 1),
        radius=int(edge * 0.22),
        fill=SURFACE,
    )

    width = int(edge * 0.5)
    height = int(edge * 0.56)
    left = (edge - width) // 2
    top = int(edge * 0.18)
    stroke = max(2, int(edge * 0.045))
    shield = [
        (left + width // 2, top),
        (left + width, top + int(height * 0.14)),
        (left + width, top + int(height * 0.5)),
        (left + width // 2, top + height),
        (left, top + int(height * 0.5)),
        (left, top + int(height * 0.14)),
        (left + width // 2, top),
    ]
    draw.line(shield, fill=ACCENT, width=stroke, joint="curve")
    check = [
        (left + int(width * 0.28), top + int(height * 0.5)),
        (left + int(width * 0.45), top + int(height * 0.66)),
        (left + int(width * 0.74), top + int(height * 0.3)),
    ]
    draw.line(check, fill=ACCENT, width=stroke, joint="curve")
    return image.resize((size, size), Image.LANCZOS)


def main():
    for size, name in [
        (32, "favicon-32.png"),
        (180, "apple-touch-icon.png"),
        (192, "favicon-192.png"),
        (512, "favicon-512.png"),
    ]:
        draw_icon(size).save(OUT / name)
        print("wrote", OUT / name)


if __name__ == "__main__":
    main()
