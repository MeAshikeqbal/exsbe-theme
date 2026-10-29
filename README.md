# Exsbe desktop theme

Graphite KDE Plasma 6 setup for Bazzite built around the Exsbe wallpapers and logo.

## Install

```sh
./install.sh                 # everything (user level, no sudo)
./install.sh desktop layout  # or single sections
cp lab/pve.conf.example ~/.config/exsbe/pve.conf   # once: your cluster's addresses (stays local)
bin/exsbe-pve-setup root@<node> --pbs root@<pbs>   # once, before the lab section
bin/exsbe-secret jellyfin    # once: Jellyfin API key (Dashboard → API Keys)
sudo ./install-boot.sh       # boot splash + login screen (build first: rpm/build.sh), then reboot
./restore.sh                 # undo, from the backup taken before the first install
```

Sections: `colors` `desktop` `apps` `containers` `splash` `workflow` `polish` `lab` `layout`.

Everything is self-contained: the `splash` section copies the wallpapers to
`~/Pictures/Wallpapers/exsbe/` (existing files are kept) and enables the time-of-day timer,
and `rpm/build.sh` builds the boot splash from `plymouth/exsbe/`.

## What's inside

| Path | What |
| --- | --- |
| `colors/` | `Exsbe.colors` generator; accent follows the wallpaper |
| `plasma-style/` | Breeze + rounded dock items and pager (`gen.py`) |
| `aurorae/Exsbe` | graphite Aurorae decoration (kept as an option; Breeze is used for rounded window corners) |
| `icons/gen-folders.sh`, `icons/gen-apps.py` | `Exsbe` icon theme: WhiteSur-dark with graphite folders, graphite dock tiles (Brave, kitty, VS Code, Dolphin) and CPU / memory symbolic glyphs |
| `layout.js` | top bar + auto-hiding dock |
| `plasmoid/com.exsbe.workspaces` | icon workspace switcher (Code / Web / Lab / Play) |
| `plasmoid/com.exsbe.sysmon` | top-bar CPU / RAM / GPU chips (fixed width; GPU dims when idle); popup with 1-minute graphs, temps, clocks, fans, VRAM and top processes |
| `plasmoid/com.exsbe.weather`, `plasmoid/com.exsbe.network` | desktop cards: weather + 7-day forecast (Open-Meteo, no key), network rates with a one-minute graph |
| `plasmoid/com.exsbe.containers` | Podman / distrobox panel widget |
| `plasmoid/com.exsbe.proxmox` | Proxmox panel widget: nodes, storage, backups, guests (start / shut down / console / ssh) |
| `bin/exsbe-pve`, `bin/pvepick` | Proxmox CLI (status, actions, consoles, ssh-config, alerts) and the fzf guest picker |
| `bin/exsbe-pve-setup` | one-time: least-privilege Proxmox users + API tokens, secrets straight into KWallet |
| `lab/pve.conf.example` | template for `~/.config/exsbe/pve.conf` (local, never committed): endpoints, PBS, LAN, home router MAC, Jellyfin, proxies |
| `plasmoid/com.exsbe.jellyfin`, `bin/exsbe-jellyfin` | Jellyfin widget: every user's streams, direct play vs transcode (codecs, reasons, GPU), and where they play from (LAN device, Tailscale, city/ISP) |
| `bin/exsbe-tailnet-routes` | accepts the lab's Tailscale route (advertise only the reverse proxy, a /32) only when away from home |
| `bin/exsbe-secret` | store an API key in KWallet without echo (`exsbe-secret jellyfin`) |
| `bin/exsbe-krunner`, `krunner/` | KRunner plugin: Proxmox guests (`jelly`, `pve …`), `ssh …` hosts, `jf …` Jellyfin library |
| `bin/exsbe-pve-keys` | put this PC's SSH key into every container with sshd; host keys read through Proxmox |
| `bin/exsbe-config-backup` | nightly snapshot of the desktop config into a local git repo; `log`, `diff`, `restore REV` |
| `bin/exsbe-term`, `kitty/sessions/` | the dock's terminal: tabs per workspace (Code: ~/projects; Lab: shell, btop, pve) |
| `mangohud/` | Exsbe MangoHud overlay for every Vulkan game, hidden until Right Shift+F12 |
| `kwin/exsbe-gamemode` | Play workspace: blur off, dock hidden, Do Not Disturb |
| `look-and-feel/com.exsbe.desktop` | login splash + one-click global theme |
| `konsole/`, `kitty/`, `btop/`, `lazygit/`, `lazydocker/`, `bin/` | app themes and helper scripts |
| `shell/exsbe.zsh` | fzf, bat, eza and zsh highlighting colours; fastfetch greeting in kitty |
| `fastfetch/` | system info with the Exsbe logo |
| `sounds/` | `gen.sh` synthesises the Exsbe chime sound theme |
| `wallpapers/` | five time-of-day wallpapers (morning → midnight) |
| `plymouth/exsbe` | Plymouth boot theme sources |
| `systemd/` | wallpaper timer, Proxmox alerts / SSH config timer, game-mode Do Not Disturb helper |
| `rpm/` | Plymouth theme RPM spec and container build |

## Shortcuts

- **Meta+Shift+C**: lazydocker on Podman
- **Meta+Shift+H**: SSH host picker
- **Meta+Shift+P**: Proxmox guest picker
- **Meta** (tap): Overview; **Alt+Space**: KRunner
- **Meta+V**: clipboard history
- **Meta+T**: tiling layout editor (60/40 + stacked right column)
