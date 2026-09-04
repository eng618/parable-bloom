#!/usr/bin/env python3
"""Generate the Google Play feature graphic (1024x500) for Parable Bloom.

Composition ("Icon + gameplay"): watercolor-wash background sampled from the
brand palette, circular branded-icon hero on the left, stacked serif title +
tagline center, full-height gameplay screenshot bleeding off the right edge.

Usage:
    python3 scripts/make_feature_graphic.py [--out PATH] [--preview-only]

Outputs:
    apps/parable-bloom/assets/images/feature-graphic-1024x500.png
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO_ROOT = Path(__file__).resolve().parent.parent
ART = REPO_ROOT / "apps/parable-bloom/assets/art/app_icon_branded.png"
SCREENSHOT = (
    REPO_ROOT
    / "apps/parable-bloom/android/fastlane/screenshots/en-US"
    / "emulator_5554_02_gameplay_light.png"
)
DEFAULT_OUT = (
    REPO_ROOT
    / "apps/parable-bloom/assets/images/feature-graphic-1024x500.png"
)

W, H = 1024, 500

# Brand palette (cream/sage wash + deep garden green from site theme #177245)
BG_TOP = (251, 248, 241)
BG_BOTTOM = (214, 228, 203)
BLOB = (183, 205, 168)
TITLE_GREEN = (16, 96, 58)
TAGLINE_SLATE = (46, 59, 51)
SUBLINE_SAGE = (91, 122, 99)
WHITE = (255, 255, 255)

GEORGIA_BOLD = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
ARIAL = "/System/Library/Fonts/Supplemental/Arial.ttf"
ARIAL_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def luminance(rgb: tuple[int, int, int]) -> float:
    def ch(c: int) -> float:
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (ch(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def vertical_gradient(size: tuple[int, int], top: tuple, bottom: tuple) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        px_line = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = px_line
    return img


def soft_blob(base: Image.Image, center: tuple[int, int], radius: int,
              color: tuple[int, int, int], opacity: int = 60) -> Image.Image:
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = center
    d.ellipse([x - radius, y - radius, x + radius, y + radius],
              fill=color + (opacity,))
    layer = layer.filter(ImageFilter.GaussianBlur(radius // 3))
    return Image.alpha_composite(base.convert("RGBA"), layer)


def circle_crop(img: Image.Image, size: int) -> Image.Image:
    img = img.convert("RGBA").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size, size], fill=255)
    img.putalpha(mask)
    return img


def round_left_corners(img: Image.Image, radius: int) -> Image.Image:
    """Round top-left + bottom-left corners, keep right edge square (bleed)."""
    img = img.convert("RGBA")
    w, h = img.size
    mask = Image.new("L", (w, h), 255)
    corner = Image.new("L", (radius * 2, radius * 2), 0)
    ImageDraw.Draw(corner).ellipse([0, 0, radius * 2, radius * 2], fill=255)
    mask.paste(corner.crop((0, 0, radius, radius)), (0, 0))  # TL
    mask.paste(corner.crop((0, radius, radius, radius * 2)), (0, h - radius))  # BL
    img.putalpha(mask)
    return img


def draw_text_with_halo(base: Image.Image, pos: tuple[int, int], text: str,
                        font: ImageFont.FreeTypeFont,
                        fill: tuple[int, int, int]) -> None:
    d = ImageDraw.Draw(base)
    x, y = pos
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx or dy:
                d.text((x + dx, y + dy), text, font=font, fill=WHITE + (220,))
    d.text((x, y), text, font=font, fill=fill + (255,))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    args = ap.parse_args()

    for path in (ART, SCREENSHOT):
        if not path.exists():
            print(f"missing input: {path}", file=sys.stderr)
            return 1

    canvas = vertical_gradient((W, H), BG_TOP, BG_BOTTOM).convert("RGBA")
    # Watercolor blobs: sage wash top-right, soft green bottom-left
    canvas = soft_blob(canvas, (880, 90), 220, BLOB, 70)
    canvas = soft_blob(canvas, (140, 470), 200, BLOB, 55)
    canvas = soft_blob(canvas, (520, 250), 260, WHITE, 40)

    # --- Icon hero: 280px circle, left, vertically centered ---
    icon = circle_crop(Image.open(ART), 280)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([60 + 6, 110 + 10, 60 + 280 + 6, 110 + 280 + 10], fill=(60, 80, 60, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(icon, (60, 110))
    # Thin white ring to delineate the wash-on-wash edge
    ring = ImageDraw.Draw(canvas)
    ring.ellipse([60, 110, 60 + 280, 110 + 280], outline=WHITE + (200,), width=5)

    # --- Screenshot card: full-height, bleeds off right edge ---
    shot = Image.open(SCREENSHOT).convert("RGB")
    sw, sh = shot.size
    target_ratio = 300 / 500
    crop_h = int(sw / target_ratio)
    crop_y = min(120, max(0, sh - crop_h))  # bias toward top (header + grid)
    shot = shot.crop((0, crop_y, sw, crop_y + crop_h)).resize((300, 500), Image.LANCZOS)
    shot = round_left_corners(shot, 30)
    card_shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(card_shadow)
    cd.rounded_rectangle([724 + 8, 0, 724 + 300 + 8, 500], radius=30, fill=(60, 80, 60, 100))
    card_shadow = card_shadow.filter(ImageFilter.GaussianBlur(12))
    canvas = Image.alpha_composite(canvas, card_shadow)
    canvas.alpha_composite(shot, (724, 0))
    edge = ImageDraw.Draw(canvas)
    edge.line([(724, 30), (724, 470)], fill=WHITE + (230,), width=5)

    # --- Title block (stacked serif, center-left) ---
    title_font = ImageFont.truetype(GEORGIA_BOLD, 76)
    draw_text_with_halo(canvas, (378, 84), "Parable", title_font, TITLE_GREEN)
    draw_text_with_halo(canvas, (378, 168), "Bloom", title_font, TITLE_GREEN)
    tag_font = ImageFont.truetype(ARIAL, 30)
    draw_text_with_halo(canvas, (382, 272), "Find peace in puzzles.", tag_font, TAGLINE_SLATE)
    sub_font = ImageFont.truetype(ARIAL_BOLD, 22)
    draw_text_with_halo(canvas, (382, 322), "105 levels  •  Offline  •  No ads", sub_font, SUBLINE_SAGE)

    # --- Contrast self-check (title green vs nearby background, off-glyph) ---
    flat = canvas.convert("RGB")
    # Draw text onto a copy first? No — sample points known to be background:
    # right of "Parable"/"Bloom" (text ends ~x680), and the gap above tagline.
    bg_points = [(700, 110), (700, 210), (390, 262), (660, 300)]
    ratios = []
    for pt in bg_points:
        bg_sample = flat.getpixel(pt)
        # Skip pixels that are themselves text/edge (near title green or white edge)
        if bg_sample[:3] == TITLE_GREEN or bg_sample[:3] == (254, 254, 254):
            continue
        ratios.append(contrast(TITLE_GREEN, bg_sample))
    ratio = min(ratios) if ratios else 0
    print(f"title contrast vs local bg: {ratio:.2f} (need >= 4.5)")
    if ratio < 4.5:
        print("contrast check FAILED", file=sys.stderr)
        return 1

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    flat.save(out, "PNG", optimize=True)
    print(f"wrote {out} ({out.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
