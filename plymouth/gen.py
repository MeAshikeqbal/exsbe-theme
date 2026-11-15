#!/usr/bin/env python3
"""Build the Exsbe boot and login splash images from plymouth/logo.svg.

The lockup is cut into its parts, so the splash can animate them: five bars (bar-1 at the top
... bar-5 at the bottom) and the wordmark shapes (word-1 ... word-4, left to right). Every part
is drawn on the same transparent canvas, so they line up exactly when stacked. Also draws the
background: graphite, lit softly from behind the logo, dithered against banding (small enough
for the initramfs).

Writes plymouth/exsbe/ (boot splash) and look-and-feel/com.exsbe.desktop/contents/splash/images/
(the splash after login). Needs ImageMagick with SVG support.
Usage: plymouth/gen.py
"""
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / "plymouth/logo.svg"
OUTS = [ROOT / "plymouth/exsbe", ROOT / "look-and-feel/com.exsbe.desktop/contents/splash/images"]
WIDTH = 1600          # sprite width in px; the splash scales it to about a third of the screen
BG = (1920, 1080)    # scaled to the screen; a smooth gradient stays smooth


def magick(*args):
    r = subprocess.run(["magick", *map(str, args)], check=True, capture_output=True, text=True)
    return r.stdout


def bbox(png):
    """(x, y, w, h) of the visible part of a sprite."""
    w, h, x, y = map(int, re.match(r"(\d+)x(\d+)\+(\d+)\+(\d+)", magick(png, "-format", "%@", "info:")).groups())
    return x, y, w, h


def main():
    src = SVG.read_text()
    head = re.search(r"<svg[^>]*>", src).group(0)
    rects = re.findall(r"<rect [^>]+/>", src)
    paths = re.findall(r"<path [^>]+/>", src)
    tmp = Path(tempfile.mkdtemp())
    try:
        def part(name, element):
            svg = tmp / f"{name}.svg"
            svg.write_text(f'{head}<g fill="#fff">{element}</g></svg>')
            png = tmp / f"{name}.png"
            magick("-background", "none", "-density", 300, svg, "-resize", f"{WIDTH}x", png)
            return png

        bars = sorted((part(f"r{i}", r) for i, r in enumerate(rects)), key=lambda p: bbox(p)[1])
        words = sorted((part(f"p{i}", p) for i, p in enumerate(paths)), key=lambda p: bbox(p)[0])
        sprites = {f"bar-{i + 1}.png": p for i, p in enumerate(bars)}
        sprites |= {f"word-{i + 1}.png": p for i, p in enumerate(words)}

        # graphite, lit softly from behind the logo; an ordered dither from 16 to 8 bits keeps the
        # gradient free of bands and compresses far better than grain
        bg = tmp / "background.png"
        w, h = BG
        magick("-size", f"{w}x{h}", "radial-gradient:#34343a-#141416", "-ordered-dither", "o8x8,256", "-depth", "8", bg)
        sprites["background.png"] = bg

        for out in OUTS:
            out.mkdir(parents=True, exist_ok=True)
            for old in list(out.glob("bar-*.png")) + list(out.glob("word-*.png")) + [out / "logo.png"]:
                old.unlink(missing_ok=True)
            for name, png in sprites.items():
                shutil.copyfile(png, out / name)
        print(f"{len(bars)} bars, {len(words)} wordmark shapes, background -> " + ", ".join(str(o.relative_to(ROOT)) for o in OUTS))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
