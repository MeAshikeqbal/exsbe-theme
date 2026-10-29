#!/usr/bin/env python3
"""Generate the Exsbe Plasma style: rounded task-manager and pager SVGs.

Only the dock items (widgets/tasks.svg), the pager (widgets/pager.svg) and the desktop
widget card (widgets/background.svg, translucentbackground.svg) are provided; every other
element falls back to the Breeze ("default") Plasma style.
Colors come from the active color scheme through the ColorScheme-* classes.
"""
import json
import pathlib

OUT = pathlib.Path(__file__).resolve().parent / "exsbe"

STYLE = """<style id="current-color-scheme" type="text/css">
.ColorScheme-Background { color:#232326; }
.ColorScheme-Text { color:#e6e6e8; }
.ColorScheme-Highlight { color:#8fa4c0; }
.ColorScheme-NegativeText { color:#e07a7a; }
.ColorScheme-PositiveText { color:#8fc79a; }
</style>"""


def frame(prefix, x0, r, fill=None, border=None):
    """9-slice rounded frame with corner radius r, laid out at x offset x0.

    fill / border are (css class, opacity) or None. The border is 1px wide.
    """
    def paint(spec, d, rule=""):
        if not spec:
            return ""
        cls, op = spec
        return f'<path class="{cls}" fill="currentColor" fill-opacity="{op}" {rule} d="{d}"/>'

    def bounds(x, y, w, h):
        return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="none"/>'

    def corner(cx, cy, sx, sy):
        # quarter disc around (cx, cy) reaching towards (cx+sx*r, cy+sy*r)
        def pie(rad):
            ax, ay = cx + sx * rad, cy
            bx, by = cx, cy + sy * rad
            sweep = 1 if sx * sy > 0 else 0
            return f"M{cx},{cy} L{ax},{ay} A{rad},{rad} 0 0 {sweep} {bx},{by} Z"
        ring = pie(r) + " " + pie(r - 1)
        return paint(border, ring, 'fill-rule="evenodd"') + paint(fill, pie(r - 1))

    a, b, c = x0, x0 + r, x0 + 2 * r          # column edges
    t, m, n = 0, r, 2 * r                      # row edges
    pieces = {
        "topleft": (bounds(a, t, r, r), corner(b, m, -1, -1)),
        "topright": (bounds(c, t, r, r), corner(c, m, 1, -1)),
        "bottomleft": (bounds(a, n, r, r), corner(b, n, -1, 1)),
        "bottomright": (bounds(c, n, r, r), corner(c, n, 1, 1)),
        "top": (bounds(b, t, r, r), paint(border, f"M{b},{t}h{r}v1h-{r}z") + paint(fill, f"M{b},{t+1}h{r}v{r-1}h-{r}z")),
        "bottom": (bounds(b, n, r, r), paint(border, f"M{b},{n+r-1}h{r}v1h-{r}z") + paint(fill, f"M{b},{n}h{r}v{r-1}h-{r}z")),
        "left": (bounds(a, m, r, r), paint(border, f"M{a},{m}h1v{r}h-1z") + paint(fill, f"M{a+1},{m}h{r-1}v{r}h-{r-1}z")),
        "right": (bounds(c, m, r, r), paint(border, f"M{c+r-1},{m}h1v{r}h-1z") + paint(fill, f"M{c},{m}h{r-1}v{r}h-{r-1}z")),
        "center": (bounds(b, m, r, r), paint(fill, f"M{b},{m}h{r}v{r}h-{r}z")),
    }
    return "\n".join(f'<g id="{prefix + "-" if prefix else ""}{k}">{bx}{body}</g>' for k, (bx, body) in pieces.items())


def svg(groups, width, height):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">\n'
            f"<defs>{STYLE}</defs>\n" + "\n".join(groups) + "\n</svg>\n")


def tasks():
    r = 8
    states = {
        "normal": (None, None),
        "minimized": (("ColorScheme-Text", 0.05), None),
        "hover": (("ColorScheme-Text", 0.12), ("ColorScheme-Text", 0.10)),
        "focus": (("ColorScheme-Highlight", 0.28), ("ColorScheme-Highlight", 0.45)),
        "attention": (("ColorScheme-NegativeText", 0.30), ("ColorScheme-NegativeText", 0.55)),
        "progress": (("ColorScheme-PositiveText", 0.25), None),
    }
    groups, x = [], 0
    for loc in ("", "north-", "east-", "west-"):
        for name, (fill, border) in states.items():
            groups.append(frame(loc + name, x, r, fill, border))
            x += 3 * r + 2
    # padding around each task icon
    for side in ("top", "bottom", "left", "right"):
        groups.append(f'<rect id="normal-hint-{side}-margin" x="{x}" y="0" width="3" height="3" fill="none"/>')
        x += 4
    return svg(groups, x, 3 * r)


def pager():
    r = 5
    states = {
        "normal": (("ColorScheme-Text", 0.06), ("ColorScheme-Text", 0.18)),
        "hover": (("ColorScheme-Text", 0.14), ("ColorScheme-Text", 0.28)),
        "active": (("ColorScheme-Highlight", 0.35), ("ColorScheme-Highlight", 0.70)),
    }
    groups, x = [], 0
    for name, (fill, border) in states.items():
        groups.append(frame(name, x, r, fill, border))
        x += 3 * r + 2
    return svg(groups, x, 3 * r)


def card(opacity):
    """Desktop widget background: the same card as the Lab dashboard (18px radius, hairline border)."""
    r, pad = 18, 12
    groups = [frame("", 0, r, ("ColorScheme-Background", opacity), ("ColorScheme-Text", 0.08))]
    for i, side in enumerate(("top", "bottom", "left", "right")):
        groups.append(f'<rect id="hint-{side}-margin" x="{3 * r + 2 + i * (pad + 2)}" y="0" width="{pad}" height="{pad}" fill="none"/>')
    return svg(groups, 3 * r + 2 + 4 * (pad + 2), 3 * r)


def main():
    (OUT / "widgets").mkdir(parents=True, exist_ok=True)
    (OUT / "widgets/tasks.svg").write_text(tasks())
    (OUT / "widgets/pager.svg").write_text(pager())
    (OUT / "widgets/background.svg").write_text(card(0.92))
    (OUT / "widgets/translucentbackground.svg").write_text(card(0.75))
    (OUT / "metadata.json").write_text(json.dumps({
        "KPlugin": {
            "Authors": [{"Name": "Exsbe"}],
            "Description": "Breeze with rounded dock items, desktop pager and widget cards",
            "Id": "exsbe",
            "License": "MIT",
            "Name": "Exsbe",
            "Version": "1.0",
        },
        "X-Plasma-API": "5.0",
    }, indent=4) + "\n")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
