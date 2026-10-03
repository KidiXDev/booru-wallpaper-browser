#!/usr/bin/env python3
"""Shrinks the bundled fonts in assets/fonts from the full ones in assets/fonts/src.

Run it again after using a new icon: python3 scripts/subset_fonts.py
Needs: pip install fonttools uharfbuzz
"""

import re
import sys
from pathlib import Path

import uharfbuzz as hb
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/fonts/src"
OUT = ROOT / "assets/fonts"
# Every axis Tokens.qml or MaterialIcon.qml sets stays variable
SANS_PINNED = ("wdth", "GRAD", "slnt")
LIGATURE_CHARS = "abcdefghijklmnopqrstuvwxyz0123456789_"


def icon_candidates() -> set[str]:
    # Any lowercase string literal could be an icon name ("download", toast icons, menu items):
    # the ones that aren't don't shape to a ligature and are dropped below
    names = set()
    for qml in (ROOT / "qml").glob("*.qml"):
        names.update(re.findall(r"""["']([a-z][a-z0-9_]*)["']""", qml.read_text()))
    return names


def shape(blob: bytes, text: str) -> list[int]:
    font = hb.Font(hb.Face(blob))
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf, {"liga": True})
    return [info.codepoint for info in buf.glyph_infos]


def subset_icons() -> None:
    src = SRC / "MaterialSymbolsRounded.ttf"
    blob = src.read_bytes()
    icons = {}
    for name in sorted(icon_candidates()):
        gids = shape(blob, name)
        if len(name) > 1 and len(gids) == 1:
            icons[name] = gids[0]
    font = TTFont(src)
    order = font.getGlyphOrder()
    options = subset.Options()
    options.layout_features = ["*"]
    options.layout_closure = False  # Keep only the ligatures asked for, not every icon the letters spell
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.glyph_names = True  # For the check below
    sub = subset.Subsetter(options)
    sub.populate(text=LIGATURE_CHARS, gids=list(icons.values()))
    sub.subset(font)
    out = OUT / src.name
    font.save(out)

    # Every icon must still shape to the same glyph, or it would show up as its name in text
    new_blob = out.read_bytes()
    new_order = TTFont(out).getGlyphOrder()
    missing = [n for n, g in icons.items() if [new_order[i] for i in shape(new_blob, n)] != [order[g]]]
    if missing:
        sys.exit(f"icons lost in the subset: {missing}")
    print(f"{out.name}: {len(icons)} icons, {src.stat().st_size // 1024} KB -> {out.stat().st_size // 1024} KB")
    print("  " + " ".join(icons))


def pin_sans_axes() -> None:
    src = SRC / "GoogleSansFlex.ttf"
    font = TTFont(src)
    defaults = {a.axisTag: a.defaultValue for a in font["fvar"].axes}
    font = instancer.instantiateVariableFont(font, {tag: defaults[tag] for tag in SANS_PINNED})
    out = OUT / src.name
    font.save(out)
    print(f"{out.name}: pinned {', '.join(SANS_PINNED)}, {src.stat().st_size // 1024} KB -> {out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    subset_icons()
    pin_sans_axes()
