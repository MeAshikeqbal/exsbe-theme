#!/usr/bin/env python3
"""Exsbe app and status icons.

Dock icons: graphite rounded tiles with a light symbolic glyph.

Same visual language as the workspace switcher (Code / Web / Lab / Play): the glyphs are the
symbolic icons the switcher itself uses, looked up through the same themes. Writes
OUT/apps/scalable/<name>.svg for every icon name an app may ask for, plus the symbolic
CPU and memory glyphs the top-bar system widget uses (OUT/status/symbolic).
Usage: gen-apps.py OUT_THEME_DIR
"""
import re
import sys
from pathlib import Path

ICONS = Path.home() / ".local/share/icons"
SEARCH = [ICONS / "WhiteSur-dark", Path("/usr/share/icons/breeze-dark"), Path("/usr/share/icons/breeze")]
GLYPH_COLOR = "#e6e6e8"

# glyph -> (scale, icon names the apps use: desktop-file Icon= values, flatpak ids, aliases)
APPS = {
    "globe-symbolic": (1.0, ["com.brave.Browser", "brave-browser", "brave"]),
    "utilities-terminal-symbolic": (1.0, ["kitty"]),
    "code-context-symbolic": (1.3, ["code", "com.visualstudio.code", "visual-studio-code", "vscode"]),  # thin glyph
    "folder-symbolic": (1.0, ["org.kde.dolphin", "system-file-manager", "dolphin"]),
}

# 16px symbolic glyphs drawn here (none of the installed themes has monochrome ones)
SYMBOLIC = {
    "exsbe-cpu-symbolic": """<rect x="4" y="4" width="8" height="8" rx="1.5" fill="none" stroke="#e6e6e8" stroke-width="1.5"/>
<rect x="6.5" y="6.5" width="3" height="3" rx="0.5" fill="#e6e6e8"/>
<path d="M6 1v2.2M10 1v2.2M6 12.8V15M10 12.8V15M1 6h2.2M1 10h2.2M12.8 6H15M12.8 10H15" stroke="#e6e6e8" stroke-width="1.4" stroke-linecap="round"/>""",
    "exsbe-memory-symbolic": """<rect x="1" y="4" width="14" height="6.5" rx="1.2" fill="none" stroke="#e6e6e8" stroke-width="1.5"/>
<path d="M4.5 6.3v2M8 6.3v2M11.5 6.3v2" stroke="#e6e6e8" stroke-width="1.6" stroke-linecap="round"/>
<path d="M3 13v-1.6M5.5 13v-1.6M8 13v-1.6M10.5 13v-1.6M13 13v-1.6" stroke="#e6e6e8" stroke-width="1.2" stroke-linecap="round"/>""",
}

TILE = """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<defs>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#3c3c42"/><stop offset="1" stop-color="#26262a"/>
</linearGradient>
<linearGradient id="rim" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#ffffff" stop-opacity="0.16"/><stop offset="1" stop-color="#ffffff" stop-opacity="0.04"/>
</linearGradient>
</defs>
<rect x="4" y="4" width="56" height="56" rx="14" fill="url(#bg)"/>
<rect x="4.5" y="4.5" width="55" height="55" rx="13.5" fill="none" stroke="url(#rim)"/>
<g fill="{color}" transform="translate({tx:.3f},{ty:.3f}) scale({s:.4f})">
{glyph}
</g>
</svg>
"""


def find(name):
    for base in SEARCH:
        hits = sorted(p for p in base.rglob(f"{name}.svg") if "@" not in str(p))
        if hits:
            # prefer the largest fixed size / scalable for the most detail
            return max(hits, key=lambda p: (("scalable" in p.parts) * 100) + int(next((x for x in p.parts if x.isdigit()), 0)))
    sys.exit(f"glyph {name} not found")


def glyph(path):
    """Inner shapes of a symbolic icon, recoloured, plus its viewBox size."""
    svg = path.read_text()
    vb = re.search(r'viewBox="([\d.\s-]+)"', svg)
    if vb:
        size = float(vb.group(1).split()[2])
    else:
        size = float(re.search(r'<svg[^>]*\swidth="([\d.]+)', svg).group(1))
    inner = re.sub(r"^.*?<svg[^>]*>", "", svg, count=1, flags=re.S)
    inner = inner.rsplit("</svg>", 1)[0]
    inner = re.sub(r"<(defs|metadata|title|sodipodi:namedview)\b.*?</\1>", "", inner, flags=re.S)
    inner = re.sub(r"<(sodipodi:namedview)\b[^>]*/>", "", inner)
    inner = inner.replace("currentColor", GLYPH_COLOR)
    inner = re.sub(r'(fill[:=]\s*"?)#[0-9a-fA-F]{3,6}', rf"\g<1>{GLYPH_COLOR}", inner)
    return inner.strip(), size


def main():
    out = Path(sys.argv[1]) / "apps/scalable"
    out.mkdir(parents=True, exist_ok=True)
    box = 30  # glyph size on the 64px tile
    for name, (scale, targets) in APPS.items():
        inner, size = glyph(find(name))
        b = box * scale
        svg = TILE.format(color=GLYPH_COLOR, tx=32 - b / 2, ty=32 - b / 2, s=b / size, glyph=inner)
        for t in targets:
            (out / f"{t}.svg").write_text(svg)
    sym = Path(sys.argv[1]) / "status/symbolic"
    sym.mkdir(parents=True, exist_ok=True)
    for name, body in SYMBOLIC.items():
        (sym / f"{name}.svg").write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">\n{body}\n</svg>\n')
    print(f"wrote {sum(len(t) for _, t in APPS.values())} app icons and {len(SYMBOLIC)} symbolic icons")


if __name__ == "__main__":
    main()
