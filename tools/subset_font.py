#!/usr/bin/env python3
"""Generate or verify the runtime Noto Sans SC subset without changing the source font."""

from __future__ import annotations

import argparse
from io import BytesIO
from pathlib import Path
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/game/fonts/NotoSansSC-Variable.ttf"
OUTPUT = ROOT / "assets/game/fonts/NotoSansSC-Game.ttf"


def required_characters() -> str:
    paths = sorted((ROOT / "scripts").rglob("*.gd"))
    paths.append(ROOT / "tests/integration/audio_font_test.gd")
    characters = {chr(codepoint) for codepoint in range(32, 127)}
    characters.update("\n\r\t")
    for path in paths:
        characters.update(path.read_text(encoding="utf-8"))
    return "".join(sorted(characters))


def generate(characters: str) -> bytes:
    font = TTFont(SOURCE, recalcTimestamp=False)
    source_modified = font["head"].modified
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.notdef_glyph = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text=characters)
    subsetter.subset(font)
    font["head"].modified = source_modified
    buffer = BytesIO()
    font.save(buffer)
    return buffer.getvalue()


def verify(data: bytes, characters: str) -> None:
    font = TTFont(BytesIO(data))
    cmap = font.getBestCmap()
    missing = [character for character in characters if ord(character) >= 32 and ord(character) not in cmap]
    if missing:
        raise ValueError("Subset is missing characters: " + repr(missing))
    if "fvar" not in font or not any(axis.axisTag == "wght" for axis in font["fvar"].axes):
        raise ValueError("Subset lost the variable wght axis")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify without rewriting the subset")
    args = parser.parse_args()
    characters = required_characters()
    data = generate(characters)
    verify(data, characters)
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != data:
            print("Font subset is stale; run python3 -I tools/subset_font.py", file=sys.stderr)
            return 1
    else:
        OUTPUT.write_bytes(data)
    print(
        f"Font subset {'verified' if args.check else 'generated'}: "
        f"{SOURCE.stat().st_size} -> {len(data)} bytes, "
        f"{len(characters)} characters, variable wght preserved"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
