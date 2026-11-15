#!/usr/bin/env python3
"""Render the README screenshots into docs/img/.

Each widget is installed as a temporary copy (id <plugin>.shot), opened with plasmawindowed and
grabbed by the widget itself (Item.grabToImage), so the images are exactly what Plasma draws with
the installed theme and fonts. Widgets that show a home lab, a media server or your containers
read the sample data from docs/sample.py instead of the real commands; the weather card shows
Lisbon. Static pieces (wallpapers, splash, icons, palette) are composed with ImageMagick / Pillow.

Each render opens a window for a few seconds. Needs: plasmawindowed, kpackagetool6, magick, Pillow.
Usage: docs/shoot.py [name...]   names: topbar system containers proxmox jellyfin lab desktop
                                        wallpapers splash icons palette (default: all)
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMG = ROOT / "docs/img"
TMP = Path(tempfile.mkdtemp(prefix="exsbe-shoot-"))
SAMPLE = TMP / "sample"
WALL = ROOT / "wallpapers/lockup-centre/3-evening.webp"   # backdrop for the desktop cards
CARD, BORDER = "#232326", "rgba(230,230,232,0.10)"


def sh(*cmd, **kw):
    return subprocess.run([str(c) for c in cmd], check=True, **kw)


def magick(*args):
    sh("magick", *args)


# --- rendering a widget -------------------------------------------------------------------------
def render(plugin, out, wait=5000, size=None, compact=False, patches=()):
    """Grab PLUGIN's full (or compact) view into OUT after WAIT ms, with text PATCHES applied."""
    pkg = TMP / plugin
    shutil.rmtree(pkg, ignore_errors=True)
    shutil.copytree(ROOT / "plasmoid" / plugin, pkg)
    meta = pkg / "metadata.json"
    meta.write_text(meta.read_text().replace(f'"Id": "{plugin}"', f'"Id": "{plugin}.shot"'))
    qml = pkg / "contents/ui/main.qml"
    s = qml.read_text()
    for old, new in patches:
        assert old in s, f"{plugin}: patch target not found: {old[:60]}"
        s = s.replace(old, new)
    box = False
    if not compact:
        # the popup as the view, with its open-popup refresh behaviour
        s = s.replace("preferredRepresentation: compactRepresentation", "preferredRepresentation: fullRepresentation")
        s = s.replace("running: root.expanded\n", "running: true\n")
        s = re.sub(r"interval: root\.expanded \? (\d+) : \d+", r"interval: \1", s)
        s = re.sub(r"readonly property bool onLab: .*", "readonly property bool onLab: true", s)
        if size and "    fullRepresentation: Item {" in s:
            # a plain card: put its content in a box of exactly that size and grab the box (the
            # preview window has a minimum size and would stretch a short card)
            w, h = size
            start = s.index("    fullRepresentation: Item {") + len("    fullRepresentation: Item {")
            depth, i = 1, start
            while depth:
                depth += {"{": 1, "}": -1}.get(s[i], 0)
                i += 1
            s = s[:start] + f"\n        Item {{ width: {w}; height: {h}" + s[start:i - 1] + "}\n    " + s[i - 1:]
            box = True
        elif size:
            w, h = size
            lines = s.split("\n")
            i = next(k for k, l in enumerate(lines) if l.startswith("    fullRepresentation:"))
            body = [l for l in lines[i + 1:i + 12] if not re.match(r"^        Layout\.(minimum|preferred|maximum)(Width|Height):", l)]
            lines[i + 1:i + 12] = [f"        width: {w}; height: {h}; Layout.minimumWidth: {w}; Layout.minimumHeight: {h}; "
                                   f"Layout.maximumWidth: {w}; Layout.maximumHeight: {h}"] + body
            s = "\n".join(lines)
    item = "compactRepresentationItem" if compact else "fullRepresentationItem.children[0]" if box else "fullRepresentationItem"
    i = s.index("{", s.index("PlasmoidItem {")) + 1
    s = s[:i] + (f'\n    Timer {{ interval: {wait}; running: true\n'
                 f'        onTriggered: root.{item}.grabToImage(r => {{ r.saveToFile("{out}"); Qt.quit() }}) }}\n') + s[i:]
    qml.write_text(s)

    subprocess.run(["kpackagetool6", "-t", "Plasma/Applet", "-r", f"{plugin}.shot"], capture_output=True)
    sh("kpackagetool6", "-t", "Plasma/Applet", "-i", pkg, stdout=subprocess.DEVNULL)
    Path(out).unlink(missing_ok=True)
    env = dict(os.environ, QT_FORCE_STDERR_LOGGING="1")
    log = ""
    try:
        # a second try: a window opened right after the previous one closed can hand off and exit
        for _ in range(2):
            try:
                r = subprocess.run(["plasmawindowed", f"{plugin}.shot"], env=env, capture_output=True, text=True, timeout=wait / 1000 + 10)
                log = r.stderr
            except subprocess.TimeoutExpired as e:
                log = (e.stderr or b"").decode()
            if Path(out).exists():
                break
            time.sleep(2)
    finally:
        subprocess.run(["kpackagetool6", "-t", "Plasma/Applet", "-r", f"{plugin}.shot"], capture_output=True)
        for f in ("plasmawindowed-appletsrc", "plasmawindowedrc"):   # plasmawindowed's own state
            (Path.home() / ".config" / f).unlink(missing_ok=True)
    errors = [l for l in log.splitlines() if re.search(r"\.qml:\d+|TypeError|ReferenceError|error when loading", l)
              and "Binding loop" not in l]
    if errors:
        print("\n".join(errors[:10]), file=sys.stderr)
    if not Path(out).exists():
        sys.exit(f"{plugin}: no image")
    return Path(out)


# --- framing ------------------------------------------------------------------------------------
def framed(src, out, pad=14, radius=18):
    """A popup as Plasma shows it: the theme's dark card with a hairline border."""
    magick(src, "-trim", "+repage", src)   # popups draw on nothing: trim to what they show
    w, h = map(int, subprocess.run(["magick", "identify", "-format", "%w %h", src], capture_output=True, text=True).stdout.split())
    W, H = w + 2 * pad, h + 2 * pad
    magick("-size", f"{W}x{H}", "xc:none", "-fill", CARD, "-stroke", BORDER, "-strokewidth", "1.5",
           "-draw", f"roundrectangle 1,1 {W - 2},{H - 2} {radius},{radius}",
           src, "-geometry", f"+{pad}+{pad}", "-composite", out)


def carded(src, out, radius=22):
    """A desktop card for widgets that draw on the theme's widget background."""
    w, h = map(int, subprocess.run(["magick", "identify", "-format", "%w %h", src], capture_output=True, text=True).stdout.split())
    magick("-size", f"{w}x{h}", "xc:none", "-fill", "rgba(35,35,38,0.92)", "-stroke", BORDER, "-strokewidth", "1.5",
           "-draw", f"roundrectangle 1,1 {w - 2},{h - 2} {radius},{radius}", src, "-composite", out)


def shadow(src):
    magick(src, "(", "+clone", "-background", "black", "-shadow", "45x14+0+6", ")", "+swap", "-background", "none",
           "-layers", "merge", "+repage", src)


# --- the shots ----------------------------------------------------------------------------------
def pve_patch():
    return [('readonly property string pollCmd: "exsbe-pve status; echo; echo \'@@TS@@\'; tailscale status --json 2>/dev/null | jq -r .BackendState"',
             f'readonly property string pollCmd: "cat {SAMPLE}/pve.out"')]


def sysmon_patch():
    # leave the screenshot tool itself out of the process lists
    return [("if (!(rss > 0) && !(t > 0)) continue", 'if ((!(rss > 0) && !(t > 0)) || name === "plasmawindowed") continue')]


def jellyfin_patch():
    return [('poller.connectSource(env + "exsbe-jellyfin status")', f'poller.connectSource("cat {SAMPLE}/jellyfin.json")')]


def containers_patch():
    return [('readonly property string pollCmd: "podman ps -a --format json; echo \'@@PODS@@\'; podman pod ps --format json"',
             f'readonly property string pollCmd: "cat {SAMPLE}/podman.out"')]


def shot_system():
    framed(render("com.exsbe.sysmon", TMP / "system.png", 30000, (420, 640), patches=sysmon_patch()), IMG / "system.png")


def shot_containers():
    framed(render("com.exsbe.containers", TMP / "containers.png", 3000, (440, 440), patches=containers_patch()), IMG / "containers.png")


def shot_proxmox():
    framed(render("com.exsbe.proxmox", TMP / "proxmox.png", 3000, (460, 660), patches=pve_patch()), IMG / "proxmox.png")


def shot_jellyfin():
    framed(render("com.exsbe.jellyfin", TMP / "jellyfin.png", 3500, (500, 400), patches=jellyfin_patch()), IMG / "jellyfin.png")


def shot_lab():
    lab = render("com.exsbe.lab", TMP / "lab.png", 3000, (544, 900),
                 patches=[('poller.connectSource(env + "exsbe-pve status")', f'poller.connectSource("cat {SAMPLE}/pve.json")')])
    magick(lab, "-trim", "+repage", lab)
    shadow(lab)
    w, h = map(int, subprocess.run(["magick", "identify", "-format", "%w %h", lab], capture_output=True, text=True).stdout.split())
    magick(WALL, "-resize", f"{w + 160}x{h + 120}^", "-gravity", "center", "-extent", f"{w + 160}x{h + 120}",
           lab, "-gravity", "center", "-composite", "-quality", "88", IMG / "lab.jpg")


def shot_desktop():
    weather = render("com.exsbe.weather", TMP / "weather.png", 6000, (528, 304), patches=[
        ('readonly property string place: Plasmoid.configuration.place || "Set a location"', 'readonly property string place: "Lisbon"'),
        ("readonly property real latitude: Plasmoid.configuration.latitude", "readonly property real latitude: 38.72"),
        ("readonly property real longitude: Plasmoid.configuration.longitude", "readonly property real longitude: -9.14"),
        ("readonly property bool located: Plasmoid.configuration.latitude !== 0 || Plasmoid.configuration.longitude !== 0",
         "readonly property bool located: true")])
    network = render("com.exsbe.network", TMP / "network.png", 30000, (528, 272))
    for p in (weather, network):
        carded(p, p)
        shadow(p)
    magick(weather, network, "-background", "none", "-gravity", "center", "-splice", "0x0", "-append", TMP / "cards.png")
    magick(TMP / "cards.png", "-background", "none", "-gravity", "center", "-splice", "0x8", TMP / "cards.png")
    w, h = map(int, subprocess.run(["magick", "identify", "-format", "%w %h", TMP / "cards.png"], capture_output=True, text=True).stdout.split())
    magick(WALL, "-resize", f"{w + 160}x{h + 120}^", "-gravity", "center", "-extent", f"{w + 160}x{h + 120}",
           TMP / "cards.png", "-gravity", "center", "-composite", "-quality", "88", IMG / "desktop.jpg")


def shot_topbar():
    """The Exsbe pieces of the top bar, as they sit in it: workspaces left, status chips right."""
    ws = render("com.exsbe.workspaces", TMP / "ws.png", 2500, (300, 34))
    chips = [render("com.exsbe.sysmon", TMP / "c1.png", 3000, compact=True),
             render("com.exsbe.containers", TMP / "c2.png", 3000, compact=True, patches=containers_patch()),
             render("com.exsbe.proxmox", TMP / "c3.png", 3000, compact=True, patches=pve_patch()),
             render("com.exsbe.jellyfin", TMP / "c4.png", 3000, compact=True, patches=jellyfin_patch())]
    for p in [ws] + chips:
        magick(p, "-trim", "+repage", p)
    spaced = []
    for c in chips:   # chips with a gap between them
        spaced += [c, "(", "-size", "22x1", "xc:none", ")"]
    magick("-background", "none", *spaced[:-5], "-gravity", "center", "+append", TMP / "right.png")
    hgt = 48
    rw = int(subprocess.run(["magick", "identify", "-format", "%w", TMP / "right.png"], capture_output=True, text=True).stdout)
    ww = int(subprocess.run(["magick", "identify", "-format", "%w", ws], capture_output=True, text=True).stdout)
    W = ww + rw + 360
    magick("-size", f"{W}x{hgt}", "xc:none", "-fill", "rgba(29,29,32,0.96)", "-stroke", BORDER,
           "-draw", f"roundrectangle 1,1 {W - 2},{hgt - 2} 14,14",
           ws, "-gravity", "west", "-geometry", "+14+0", "-composite",
           TMP / "right.png", "-gravity", "east", "-geometry", "+16+0", "-composite", IMG / "topbar.png")


def shot_wallpapers():
    designs = sorted(p for p in (ROOT / "wallpapers").iterdir() if p.is_dir())
    tiles = []
    for d in designs:
        t = TMP / f"wp-{d.name}.png"
        magick(d / "2-afternoon.webp", "-resize", "480x270^", "-gravity", "center", "-extent", "480x270", t)
        tiles.append(t)
    if len(tiles) % 4:   # fill the last row with the logo
        logo = TMP / "wp-logo.png"
        magick("-size", "480x270", "xc:#26262a", "(", ROOT / "icons/exsbe.png", "-resize", "120x120", ")",
               "-gravity", "center", "-composite", logo)
        tiles += [logo] * (4 - len(tiles) % 4)
    sh("magick", "montage", *tiles, "-tile", "4x", "-geometry", "+6+6", "-background", "#1d1d20", "-quality", "86", IMG / "wallpapers.jpg")
    cycle = [TMP / f"cycle-{i}.png" for i in range(5)]
    for i, f in enumerate(sorted((ROOT / "wallpapers/lockup-centre").glob("*.webp"))):
        magick(f, "-resize", "384x216^", "-gravity", "center", "-extent", "384x216", "-gravity", "southwest", "-fill", "#f2f2f4",
               "-font", "Inter-Variable-Medium", "-pointsize", "17", "-annotate", "+14+12", f.stem.split("-", 1)[1], cycle[i])
    sh("magick", "montage", *cycle, "-tile", "5x", "-geometry", "+5+5", "-background", "#1d1d20", "-quality", "86", IMG / "day-cycle.jpg")


def shot_splash():
    """The splash animation, frame by frame: Splash.qml with its clock stepped by hand (no real-time
    jitter), grabbed at 20 fps into an animated WebP."""
    W, H, fps, seconds = 960, 540, 20, 4.4
    src = ROOT / "look-and-feel/com.exsbe.desktop/contents/splash"
    splash = TMP / "splash"
    shutil.copytree(src, splash)
    qml = splash / "Splash.qml"
    qml.write_text(re.sub(r"\n\s*NumberAnimation on t \{[^}]*\}", "", qml.read_text()))   # the clock is ours
    frames = TMP / "frames"
    frames.mkdir()
    n = int(seconds * fps)
    pkg = TMP / "com.exsbe.splashshot"
    (pkg / "contents/ui").mkdir(parents=True)
    (pkg / "metadata.json").write_text('{"KPlugin": {"Id": "com.exsbe.splashshot", "Name": "splash shot"}, '
                                       '"KPackageStructure": "Plasma/Applet", "X-Plasma-API-Minimum-Version": "6.0"}')
    (pkg / "contents/ui/main.qml").write_text(f"""
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
PlasmoidItem {{
    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {{
        Layout.minimumWidth: {W}; Layout.minimumHeight: {H}
        property int frame: 0
        Item {{ id: box; width: {W}; height: {H}
            Loader {{ id: ld; anchors.fill: parent; source: "file://{qml}" }} }}
        function step() {{ ld.item.t = frame / {fps}; settle.start() }}
        Timer {{ id: settle; interval: 40
            onTriggered: box.grabToImage(r => {{
                r.saveToFile("{frames}/f" + String(frame).padStart(4, "0") + ".png")
                frame++
                if (frame < {n}) step(); else Qt.quit() }}) }}
        Timer {{ interval: 1500; running: true; onTriggered: step() }}
    }}
}}
""")
    subprocess.run(["kpackagetool6", "-t", "Plasma/Applet", "-r", "com.exsbe.splashshot"], capture_output=True)
    sh("kpackagetool6", "-t", "Plasma/Applet", "-i", pkg, stdout=subprocess.DEVNULL)
    try:
        subprocess.run(["plasmawindowed", "com.exsbe.splashshot"], capture_output=True, timeout=seconds * 4 + 30)
    except subprocess.TimeoutExpired:
        pass
    finally:
        subprocess.run(["kpackagetool6", "-t", "Plasma/Applet", "-r", "com.exsbe.splashshot"], capture_output=True)
        for f in ("plasmawindowed-appletsrc", "plasmawindowedrc"):
            (Path.home() / ".config" / f).unlink(missing_ok=True)
    shots = sorted(frames.glob("f*.png"))
    if len(shots) < n:
        sys.exit(f"splash: only {len(shots)} of {n} frames")
    magick("-delay", 100 // fps, "-loop", "0", *shots, "-resize", "800x", "-define", "webp:lossless=false",
           "-quality", "82", IMG / "splash.webp")


def shot_icons():
    from PIL import Image, ImageDraw
    theme = Path.home() / ".local/share/icons/Exsbe"
    names = [("apps", n) for n in ("com.brave.Browser", "kitty", "code", "org.kde.dolphin")] + \
            [("places", n) for n in ("default-folder", "default-user-home", "default-folder-documents", "default-folder-download",
                                     "default-folder-pictures", "default-folder-music", "default-folder-code", "default-folder-games")]
    row1 = TMP / "icons1.png"
    files = [theme / f"{kind}/scalable/{n}.svg" for kind, n in names]
    sh("magick", "-background", "none", "-density", "200", *files, "-resize", "84x84", "-gravity", "center",
       "-extent", "104x104", "+append", row1)
    glyphs = ["code-context-symbolic", "globe-symbolic", "exsbe-cpu-symbolic", "exsbe-memory-symbolic", "exsbe-jellyfin-symbolic"]
    row2 = TMP / "icons2.png"
    sh("magick", "-background", "none", "-density", "400", *[theme / f"status/symbolic/{g}.svg" for g in glyphs],
       "-resize", "36x36", "-gravity", "center", "-extent", "72x72", "+append", row2)
    magick(row1, row2, "-background", "none", "-gravity", "center", "-append", "-bordercolor", "none", "-border", "12", IMG / "icons.png")
    framed(IMG / "icons.png", IMG / "icons.png")


def shot_palette():
    from PIL import Image, ImageDraw, ImageFont
    conf = (ROOT / "kitty/exsbe.conf").read_text()
    col = dict(re.findall(r"^(color\d+|foreground|background)\s+(#[0-9a-fA-F]{6})", conf, re.M))
    font = ImageFont.truetype(subprocess.run(["fc-match", "-f", "%{file}", "JetBrainsMono Nerd Font"], capture_output=True, text=True).stdout, 15)
    names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
    sw, gap, pad = 104, 10, 22
    W = pad * 2 + 8 * sw + 7 * gap
    img = Image.new("RGBA", (W, pad * 2 + 2 * 72 + gap + 36), col["background"])
    d = ImageDraw.Draw(img)
    for row, offset in ((0, 0), (1, 8)):
        for i in range(8):
            x, y = pad + i * (sw + gap), pad + row * (72 + gap)
            c = col[f"color{i + offset}"]
            d.rounded_rectangle([x, y, x + sw, y + 72], 12, fill=c)
            light = sum(int(c[k:k + 2], 16) for k in (1, 3, 5)) > 420
            d.text((x + 10, y + 10), names[i] if not row else "bright", fill="#232326" if light else "#e6e6e8", font=font)
            d.text((x + 10, y + 48), c.lower(), fill="#232326" if light else "#e6e6e8", font=font)
    d.text((pad, pad + 2 * 72 + gap + 14), f"foreground {col['foreground']}   background {col['background']}   accent #8fa4c0 (follows the wallpaper)",
           fill=col["foreground"], font=font)
    img.save(IMG / "palette.png")


SHOTS = {"topbar": shot_topbar, "system": shot_system, "containers": shot_containers, "proxmox": shot_proxmox,
         "jellyfin": shot_jellyfin, "lab": shot_lab, "desktop": shot_desktop, "wallpapers": shot_wallpapers,
         "splash": shot_splash, "icons": shot_icons, "palette": shot_palette}


def main():
    want = sys.argv[1:] or list(SHOTS)
    unknown = [w for w in want if w not in SHOTS]
    if unknown:
        sys.exit(f"unknown: {' '.join(unknown)}\n{__doc__}")
    IMG.mkdir(parents=True, exist_ok=True)
    sh(sys.executable, "-I", ROOT / "docs/sample.py", SAMPLE, stdout=subprocess.DEVNULL)
    try:
        for name in want:
            print(f"==> {name}")
            SHOTS[name]()
    finally:
        shutil.rmtree(TMP, ignore_errors=True)


if __name__ == "__main__":
    main()
