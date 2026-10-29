# Exsbe desktop theme

Graphite KDE Plasma 6 setup for Bazzite built around the Exsbe wallpapers and logo.

## Install

```sh
./install.sh                 # everything (user level, no sudo)
./install.sh desktop layout  # or single sections
bin/exsbe-pve-setup root@192.0.2.10 --pbs root@203.0.113.10   # once, before the lab section
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
| `icons/gen-folders.sh` | `Exsbe` icon theme: WhiteSur-dark with graphite folders |
| `layout.js` | top bar + auto-hiding dock |
| `plasmoid/com.exsbe.workspaces` | icon workspace switcher (Code / Web / Lab / Play) |
| `plasmoid/com.exsbe.containers` | Podman / distrobox panel widget |
| `plasmoid/com.exsbe.proxmox` | Proxmox panel widget: nodes, storage, backups, guests (start / shut down / console / ssh) |
| `bin/exsbe-pve`, `bin/pvepick` | Proxmox CLI (status, actions, consoles, ssh-config, alerts) and the fzf guest picker |
| `bin/exsbe-pve-setup` | one-time: least-privilege Proxmox users + API tokens, secrets straight into KWallet |
| `lab/pve.conf` | cluster endpoints (LAN name, then node IPs), PBS URL, home router MAC |
| `bin/exsbe-jellyfin-mpris` | Jellyfin "now playing" (any device) in Plasma's media controls and lock screen |
| `bin/exsbe-tailnet-routes` | uses the `tailscale-router` Tailscale subnet route (CT 112) only when away from home |
| `bin/exsbe-secret` | store an API key in KWallet without echo (`exsbe-secret jellyfin`) |
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
