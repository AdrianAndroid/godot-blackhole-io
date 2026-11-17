#!/usr/bin/env python3
"""Build deterministic, saturated building palettes from the local Kenney CC0 palette."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TEXTURES = ROOT / "assets" / "game" / "models" / "commercial" / "Textures"
PALETTES = {
    "reference-blue.png": (24, 72, 176),
    "reference-orange.png": (232, 91, 38),
    "reference-pink.png": (208, 48, 126),
}


def clamp(value: float) -> int:
    return max(0, min(255, round(value)))


def recolor(pixel: tuple[int, int, int, int], target: tuple[int, int, int]) -> tuple[int, int, int, int]:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return pixel
    high = max(red, green, blue)
    low = min(red, green, blue)
    mean = (red + green + blue) / 3.0
    if high - low < 24 and 35.0 < mean < 228.0:
        shade = 0.55 + mean / 255.0 * 0.85
        return tuple(clamp(channel * shade) for channel in target) + (alpha,)
    if red > green * 1.20 and green > blue * 1.04:
        # Preserve the palette's warm roofs and trim while approaching the reference's orange.
        return clamp(red * 1.28 + 20.0), clamp(green * 1.12 + 5.0), clamp(blue * 0.88), alpha
    if blue > red * 1.12:
        return clamp(red * 0.78), clamp(green * 1.04), clamp(blue * 1.18 + 14.0), alpha
    saturation = 1.18
    return (
        clamp(mean + (red - mean) * saturation),
        clamp(mean + (green - mean) * saturation),
        clamp(mean + (blue - mean) * saturation),
        alpha,
    )


def build(source: Image.Image, target: tuple[int, int, int]) -> Image.Image:
    rgba = source.convert("RGBA")
    output = Image.new("RGBA", rgba.size)
    output.putdata([recolor(pixel, target) for pixel in rgba.get_flattened_data()])
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Verify deterministic output without rewriting it")
    args = parser.parse_args()
    with Image.open(TEXTURES / "colormap.png") as source:
        for filename, color in PALETTES.items():
            expected = build(source, color)
            path = TEXTURES / filename
            if args.check:
                if not path.is_file():
                    raise SystemExit(f"Missing generated palette: {path}")
                with Image.open(path) as actual:
                    if actual.size != expected.size or actual.convert("RGBA").tobytes() != expected.tobytes():
                        raise SystemExit(f"Stale generated palette: {path}")
            else:
                expected.save(path, optimize=False)
                print(path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
