# Exsbe desktop theme

Graphite KDE Plasma 6 setup for Bazzite built around the Exsbe wallpapers and logo.

## Install

```sh
./install.sh                 # everything (user level, no sudo)
./install.sh desktop layout  # or single sections
sudo ./install-boot.sh       # boot splash + login screen (build first: rpm/build.sh), then reboot
./restore.sh                 # undo, from the backup taken before the first install
```

Sections: `colors` `desktop` `apps` `containers` `splash` `workflow` `layout`.

Everything is self-contained: the `splash` section copies the wallpapers to
`~/Pictures/Wallpapers/exsbe/` (existing files are kept) and enables the time-of-day timer,
and `rpm/build.sh` builds the boot splash from `plymouth/exsbe/`.

## What's inside

| Path | What |
| --- | --- |
| `colors/` | `Exsbe.colors` generator; accent follows the wallpaper |
| `plasma-style/` | Breeze + rounded dock items and pager (`gen.py`) |
| `aurorae/Exsbe` | rounded graphite window decoration |
| `layout.js` | top bar + auto-hiding dock |
| `plasmoid/com.exsbe.workspaces` | icon workspace switcher (Code / Web / Lab / Play) |
| `plasmoid/com.exsbe.containers` | Podman / distrobox panel widget |
| `kwin/exsbe-gamemode` | Play workspace: blur off, dock hidden, Do Not Disturb |
| `look-and-feel/com.exsbe.desktop` | login splash + one-click global theme |
| `konsole/`, `lazydocker/`, `bin/` | app themes and helper scripts |
| `wallpapers/` | five time-of-day wallpapers (morning → midnight) |
| `plymouth/exsbe` | Plymouth boot theme sources |
| `systemd/` | wallpaper timer and the game-mode Do Not Disturb helper |
| `rpm/` | Plymouth theme RPM spec and container build |

## Shortcuts

- **Meta+Shift+C**: lazydocker on Podman
- **Meta+Shift+H**: SSH host picker
- **Meta+V**: clipboard history
- **Meta+T**: tiling layout editor (60/40 + stacked right column)
