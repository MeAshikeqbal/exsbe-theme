#!/usr/bin/env bash
# Exsbe desktop theme installer (user level, no sudo).
# Usage: ./install.sh [section...]   sections: colors desktop apps containers splash workflow polish lab layout
# With no arguments every section runs in order.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
kw() { kwriteconfig6 "$@"; }

colors() {
  install -Dm644 "$HERE/colors/Exsbe.colors" ~/.local/share/color-schemes/Exsbe.colors
  plasma-apply-colorscheme Exsbe
  # accent follows the active (time-of-day) wallpaper
  kw --file kdeglobals --group General --key accentColorFromWallpaper true
}

desktop() {
  # fonts
  local ui="Inter Variable,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
  local small="Inter Variable,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
  local mono="JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
  kw --file kdeglobals --group General --key font "$ui"
  kw --file kdeglobals --group General --key menuFont "$ui"
  kw --file kdeglobals --group General --key toolBarFont "$ui"
  kw --file kdeglobals --group General --key smallestReadableFont "$small"
  kw --file kdeglobals --group General --key fixed "$mono"
  kw --file kdeglobals --group WM --key activeFont "Inter Variable,10,-1,5,600,0,0,0,0,0,0,0,0,0,0,1"

  # widget style, plasma style (Breeze follows the color scheme), icons, cursor
  kw --file kdeglobals --group KDE --key widgetStyle Breeze
  rm -rf ~/.local/share/plasma/desktoptheme/exsbe
  cp -r "$HERE/plasma-style/exsbe" ~/.local/share/plasma/desktoptheme/exsbe
  plasma-apply-desktoptheme exsbe
  # icons: WhiteSur-dark with graphite folders
  if [ -d ~/.local/share/icons/WhiteSur-dark ]; then
    "$HERE/icons/gen-folders.sh"   # graphite folders, dock tiles, symbolic glyphs
    kw --file kdeglobals --group Icons --key Theme Exsbe
    # VS Code's Homebrew launcher points at a PNG, which skips the icon theme (and the Exsbe tile)
    [ -f ~/.local/share/applications/code.desktop ] &&
      sed -i 's|^Icon=/.*code\.png$|Icon=code|' ~/.local/share/applications/code.desktop
    rm -f ~/.cache/icon-cache.kcache
  else
    kw --file kdeglobals --group Icons --key Theme WhiteSur-dark
  fi
  plasma-apply-cursortheme WhiteSur-cursors || true

  # window decoration: Breeze, which (unlike Aurorae) tells KWin its corner radius,
  # so window contents get rounded corners too; colours come from the Exsbe scheme.
  # The Exsbe Aurorae theme stays installed: pick it in System Settings to go back.
  rm -rf ~/.local/share/aurorae/themes/Exsbe
  cp -r "$HERE/aurorae/Exsbe" ~/.local/share/aurorae/themes/Exsbe
  kw --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
  kw --file kwinrc --group org.kde.kdecoration2 --key theme Breeze
  kw --file breezerc --group Common --key RoundedCorners true
  kw --file breezerc --group Common --key OutlineIntensity OutlineLow
  kw --file breezerc --group Common --key ShadowSize ShadowLarge
  kw --file breezerc --group Common --key ShadowStrength 160
  kw --file breezerc --group Windeco --key TitleAlignment AlignCenterFullWidth
  kw --file breezerc --group Windeco --key ButtonSize ButtonDefault
  kw --file breezerc --group Windeco --key DrawBackgroundGradient false
  kw --file breezerc --group Windeco --key OutlineCloseButton false
  kw --file kwinrc --group org.kde.kdecoration2 --key BorderSize Normal
  kw --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto false
  kw --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft ""
  kw --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight "IAX"

  # effects: blur behind panels/menus
  kw --file kwinrc --group Plugins --key blurEnabled true
  kw --file kwinrc --group Plugins --key contrastEnabled true
  kw --file kwinrc --group Effect-blur --key BlurStrength 7
  kw --file kwinrc --group Effect-blur --key NoiseStrength 3

  # virtual desktops: Code / Web / Lab / Play
  # (through KWin's DBus API; KWin overwrites kwinrc edits made while it runs)
  local vdm=(org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager)
  local names=(Code Web Lab Play) i ids
  for ((i = $(busctl --user get-property "${vdm[@]}" count | cut -d' ' -f2); i < ${#names[@]}; i++)); do
    busctl --user call "${vdm[@]}" createDesktop us "$i" "${names[$i]}"
  done
  mapfile -t ids < <(busctl --user --json=short get-property "${vdm[@]}" desktops |
    python3 -c 'import json,sys; [print(d[1]) for d in json.load(sys.stdin)["data"]]')
  for i in "${!names[@]}"; do
    busctl --user call "${vdm[@]}" setDesktopName ss "${ids[$i]}" "${names[$i]}"
  done

  # GTK / libadwaita
  busctl --user call org.kde.GtkConfig /GtkConfig org.kde.GtkConfig setGtkTheme s Breeze || true
  gsettings set org.gnome.desktop.interface gtk-theme Breeze
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark
  gsettings set org.gnome.desktop.interface font-name "Inter Variable 10"
  gsettings set org.gnome.desktop.interface monospace-font-name "JetBrainsMono Nerd Font 10"

  # Flatpak apps: read GTK config, fonts and icons/cursors from home
  flatpak override --user \
    --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro \
    --filesystem=~/.local/share/fonts:ro --filesystem=~/.icons:ro \
    --filesystem=xdg-data/icons:ro

  qdbus_reconfigure
}

apps() {
  # Konsole
  install -Dm644 "$HERE/konsole/Exsbe.colorscheme" ~/.local/share/konsole/Exsbe.colorscheme
  install -Dm644 "$HERE/konsole/Exsbe.profile" ~/.local/share/konsole/Exsbe.profile
  kw --file konsolerc --group "Desktop Entry" --key DefaultProfile Exsbe.profile

  # VS Code (merges, keeps existing settings)
  python3 "$HERE/bin/merge-vscode.py"

  # Starship: swap the bright defaults for the Exsbe palette
  local st=~/.config/starship.toml
  if [ -f "$st" ]; then
    sed -i -e 's/"bold cyan"/"bold #7fa8d6"/' -e 's/"bold purple"/"#b494d6"/' \
      -e 's/"bold yellow"/"#e0c47a"/g' -e 's/(bold yellow)/(#e0c47a)/g' \
      -e 's/(bold green)/(bold #8fc79a)/g' -e 's/(bold red)/(bold #e07a7a)/g' \
      -e 's/"bold blue"/"#7fa8d6"/' "$st"
  fi

  # kitty: palette + rounded tabs, included from the user's kitty.conf
  install -Dm644 "$HERE/kitty/exsbe.conf" ~/.config/kitty/exsbe.conf
  touch ~/.config/kitty/kitty.conf
  grep -qx 'include exsbe.conf' ~/.config/kitty/kitty.conf || echo 'include exsbe.conf' >> ~/.config/kitty/kitty.conf
  pkill -USR1 -x kitty || true   # live reload
  # per-workspace sessions (Code, Lab); the dock's kitty opens the one for the current workspace
  install -Dm644 -t ~/.config/kitty/sessions "$HERE"/kitty/sessions/*.kitty
  install -Dm755 "$HERE/bin/exsbe-term" ~/.local/bin/exsbe-term
  [ -f ~/.local/share/applications/kitty.desktop ] &&
    sed -i "s|^Exec=.*kitty %U$|Exec=$HOME/.local/bin/exsbe-term|" ~/.local/share/applications/kitty.desktop

  # MangoHud: Exsbe overlay, loaded in every Vulkan game but hidden until Right Shift+F12
  install -Dm644 "$HERE/mangohud/MangoHud.conf" ~/.config/MangoHud/MangoHud.conf
  install -Dm644 "$HERE/mangohud/environment.conf" ~/.config/environment.d/exsbe-mangohud.conf

  # CLI colours (fzf, bat, eza, zsh highlighting) + fastfetch greeting, sourced from .zshrc
  install -Dm644 "$HERE/shell/exsbe.zsh" ~/.config/exsbe/exsbe.zsh
  grep -q 'exsbe/exsbe.zsh' ~/.zshrc 2>/dev/null ||
    printf '\n# Exsbe palette for CLI tools\nsource ~/.config/exsbe/exsbe.zsh\n' >> ~/.zshrc
  install -Dm644 "$HERE/icons/exsbe.png" ~/.local/share/exsbe/exsbe.png
  install -Dm644 "$HERE/fastfetch/config.jsonc" ~/.config/fastfetch/config.jsonc
  install -Dm644 "$HERE/lazygit/config.yml" ~/.config/lazygit/config.yml

  # btop
  install -Dm644 "$HERE/btop/exsbe.theme" ~/.config/btop/themes/exsbe.theme
  if [ -f ~/.config/btop/btop.conf ]; then
    sed -i -e 's|^color_theme = .*|color_theme = "exsbe"|' -e 's|^theme_background = .*|theme_background = false|' \
      ~/.config/btop/btop.conf
  else
    printf 'color_theme = "exsbe"\ntheme_background = false\n' > ~/.config/btop/btop.conf
  fi
}

containers() {
  # panel widget
  local pkg="$HERE/plasmoid/com.exsbe.containers"
  kpackagetool6 -t Plasma/Applet -u "$pkg" >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -i "$pkg"

  # lazydocker on the Podman socket, Meta+Shift+C
  systemctl --user enable --now podman.socket
  install -Dm755 "$HERE/bin/lazypod" ~/.local/bin/lazypod
  install -Dm644 "$HERE/lazydocker/config.yml" ~/.config/lazydocker/config.yml
  local kitty; kitty="$(command -v kitty || echo /home/linuxbrew/.linuxbrew/bin/kitty)"
  sed -e "s|@KITTY@|$kitty|" -e "s|@HOME@|$HOME|" "$HERE/bin/lazypod.desktop" \
    > ~/.local/share/applications/lazypod.desktop
  kw --file kglobalshortcutsrc --group services --group lazypod.desktop --key _launch "Meta+Shift+C"
  update-desktop-database ~/.local/share/applications 2>/dev/null || true
}

splash() {
  # login splash + one-click "Exsbe" global theme (does not touch the panel layout)
  local pkg="$HERE/look-and-feel/com.exsbe.desktop"
  kpackagetool6 -t Plasma/LookAndFeel -u "$pkg" >/dev/null 2>&1 || kpackagetool6 -t Plasma/LookAndFeel -i "$pkg"
  kw --file ksplashrc --group KSplash --key Engine KSplashQML
  kw --file ksplashrc --group KSplash --key Theme com.exsbe.desktop
  kw --file kdeglobals --group KDE --key LookAndFeelPackage com.exsbe.desktop

  # time-of-day wallpapers (desktop + lock screen), switched by a user timer
  mkdir -p ~/Pictures/Wallpapers/exsbe
  cp -n "$HERE"/wallpapers/*.png ~/Pictures/Wallpapers/exsbe/
  install -Dm755 "$HERE/bin/exsbe-wallpaper" ~/.local/bin/exsbe-wallpaper
  install -Dm644 "$HERE/systemd/exsbe-wallpaper.service" ~/.config/systemd/user/exsbe-wallpaper.service
  install -Dm644 "$HERE/systemd/exsbe-wallpaper.timer" ~/.config/systemd/user/exsbe-wallpaper.timer
  systemctl --user daemon-reload
  systemctl --user enable --now exsbe-wallpaper.timer
  ~/.local/bin/exsbe-wallpaper
}

layout() {
  local pkg
  for pkg in com.exsbe.workspaces com.exsbe.sysmon; do
    kpackagetool6 -t Plasma/Applet -u "$HERE/plasmoid/$pkg" >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -i "$HERE/plasmoid/$pkg"
  done
  install -Dm644 "$HERE/icons/exsbe.png" ~/.local/share/exsbe/exsbe.png
  busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell \
    evaluateScript s "$(sed "s|@ICON@|$HOME/.local/share/exsbe/exsbe.png|" "$HERE/layout.js")"
  # kickoff only picks up a custom icon file after a shell restart
  systemctl --user restart plasma-plasmashell.service
}

qdbus_reconfigure() {
  busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure || true
}

desktop_id() { # workspace name -> KWin desktop UUID
  busctl --user --json=short get-property org.kde.KWin /VirtualDesktopManager \
    org.kde.KWin.VirtualDesktopManager desktops |
    python3 -c 'import json,sys; print(next(d[1] for d in json.load(sys.stdin)["data"] if d[2] == sys.argv[1]))' "$1"
}

workflow() {
  # apps open on their own workspace (initially; they can still be moved)
  local rules=() r
  rule() { # id description class-regex workspace
    r="exsbe-$1"; rules+=("$r")
    kw --file kwinrulesrc --group "$r" --key Description "$2"
    kw --file kwinrulesrc --group "$r" --key wmclass "$3"
    kw --file kwinrulesrc --group "$r" --key wmclassmatch 3
    kw --file kwinrulesrc --group "$r" --key wmclasscomplete false
    kw --file kwinrulesrc --group "$r" --key desktops "$(desktop_id "$4")"
    kw --file kwinrulesrc --group "$r" --key desktopsrule 3
  }
  rule code "VS Code on Code" '(?i)^code$' Code
  rule web "Brave on Web" '(?i)^(brave-browser|com\.brave\.browser)$' Web
  rule lab "Proxmox, Termius, Moonlight on Lab" '(?i)^(brave-pve\.local\.lab\.site__-default|com\.termius\.termius|termius.*|com\.moonlight_stream\.moonlight|moonlight)$' Lab
  rule play "Games on Play" '(?i)^(steam|steam_app_.*|steamwebhelper|lutris|net\.lutris\.lutris|heroic|com\.heroicgameslauncher\.hgl|gamescope)$' Play
  local existing; existing="$(kreadconfig6 --file kwinrulesrc --group General --key rules | tr ',' '\n' | grep -v '^exsbe-' | grep -v '^$' || true)"
  local all; all="$(printf '%s\n' $existing "${rules[@]}" | paste -sd,)"
  kw --file kwinrulesrc --group General --key rules "$all"
  kw --file kwinrulesrc --group General --key count "$(tr ',' '\n' <<<"$all" | grep -c .)"

  # Meta+T tiling: editor 60% | two stacked 40% tiles, on every workspace and screen
  local tiles='{"layoutDirection":"horizontal","tiles":[{"width":0.6},{"layoutDirection":"vertical","width":0.4,"tiles":[{"height":0.5},{"height":0.5}]}]}'
  local outputs d o
  outputs="$(grep -o '^\[Tiling\]\[[^]]*\]\[[^]]*\]' ~/.config/kwinrc | sed 's/.*\]\[\(.*\)\]$/\1/' | sort -u)"
  for d in Code Web Lab Play; do
    for o in $outputs; do
      kw --file kwinrc --group Tiling --group "$(desktop_id "$d")" --group "$o" --key padding 6
      kw --file kwinrc --group Tiling --group "$(desktop_id "$d")" --group "$o" --key tiles "$tiles"
    done
  done

  # game mode on the Play workspace
  local gm="$HERE/kwin/exsbe-gamemode"
  kpackagetool6 -t KWin/Script -u "$gm" >/dev/null 2>&1 || kpackagetool6 -t KWin/Script -i "$gm"
  kw --file kwinrc --group Plugins --key exsbe-gamemodeEnabled true
  install -Dm755 "$HERE/bin/exsbe-dnd" ~/.local/bin/exsbe-dnd
  install -Dm644 "$HERE/systemd/exsbe-dnd.service" ~/.config/systemd/user/exsbe-dnd.service
  systemctl --user daemon-reload
  # reload the script so KWin picks up changes
  busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting unloadScript s exsbe-gamemode >/dev/null
  busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting start >/dev/null

  # nightly config snapshot into a local git repo (exsbe-config-backup log / restore REV)
  install -Dm755 "$HERE/bin/exsbe-config-backup" ~/.local/bin/exsbe-config-backup
  install -Dm644 -t ~/.config/systemd/user "$HERE/systemd/exsbe-config-backup.service" "$HERE/systemd/exsbe-config-backup.timer"
  systemctl --user daemon-reload
  systemctl --user enable --now exsbe-config-backup.timer

  # SSH host picker, Meta+Shift+H
  install -Dm755 "$HERE/bin/sshpick" ~/.local/bin/sshpick
  local kitty; kitty="$(command -v kitty || echo /home/linuxbrew/.linuxbrew/bin/kitty)"
  sed -e "s|@KITTY@|$kitty|" -e "s|@HOME@|$HOME|" "$HERE/bin/sshpick.desktop" \
    > ~/.local/share/applications/sshpick.desktop
  kw --file kglobalshortcutsrc --group services --group sshpick.desktop --key _launch "Meta+Shift+H"

  # clipboard history (Meta+V): longer, text selections ignored
  kw --file klipperrc --group General --key MaxClipItems 100
  kw --file klipperrc --group General --key KeepClipboardContents true
  kw --file klipperrc --group General --key IgnoreSelection true

  # night light, warming with the evening wallpaper at 17:00
  kw --file kwinrc --group NightColor --key Active true
  kw --file kwinrc --group NightColor --key Mode Times
  kw --file kwinrc --group NightColor --key EveningBeginFixed 1700
  kw --file kwinrc --group NightColor --key MorningBeginFixed 0600
  kw --file kwinrc --group NightColor --key TransitionTime 90
  kw --file kwinrc --group NightColor --key NightTemperature 4200

  qdbus_reconfigure
}

polish() {
  # animations: a bit quicker; windows scale in/out, minimize into the dock like a genie
  kw --file kdeglobals --group KDE --key AnimationDurationFactor 0.7
  kw --file kwinrc --group Plugins --key scaleEnabled true
  kw --file kwinrc --group Plugins --key glideEnabled false
  kw --file kwinrc --group Plugins --key fadeEnabled false
  kw --file kwinrc --group Plugins --key magiclampEnabled true
  kw --file kwinrc --group Plugins --key squashEnabled false
  # tapping Meta opens Overview (the app launcher stays on Alt+F1)
  kw --file kwinrc --group ModifierOnlyShortcuts --key Meta \
    "org.kde.kglobalaccel,/component/kwin,org.kde.kglobalaccel.Component,invokeShortcut,Overview"
  # KRunner (Alt+Space) floats in the middle of the screen instead of dropping from the top
  kw --file krunnerrc --group General --key FreeFloating true

  # notifications: top right under the bar, 5 s, quiet while gaming / sharing the screen
  kw --file plasmanotifyrc --group Notifications --key PopupPosition TopRight
  kw --file plasmanotifyrc --group Notifications --key PopupTimeout 5000
  kw --file plasmanotifyrc --group Notifications --key LowPriorityHistory false
  kw --file plasmanotifyrc --group Notifications --key CriticalInDndMode true
  kw --file plasmanotifyrc --group DoNotDisturb --key WhenFullscreen true
  kw --file plasmanotifyrc --group DoNotDisturb --key WhenScreenSharing true
  kw --file plasmanotifyrc --group DoNotDisturb --key WhenScreensMirrored true

  # sound theme: soft Exsbe chimes (falls back to Ocean for anything not covered)
  rm -rf ~/.local/share/sounds/exsbe
  mkdir -p ~/.local/share/sounds
  cp -r "$HERE/sounds/exsbe" ~/.local/share/sounds/exsbe
  kw --file kdeglobals --group Sounds --key Theme exsbe
  kw --file kdeglobals --group Sounds --key Enable true
  gsettings set org.gnome.desktop.sound theme-name exsbe || true

  qdbus_reconfigure
}

# panel_widget PLUGIN AFTER: install PLUGIN from plasmoid/ and add it to the top bar right after
# AFTER (Plasma rewrites the order when a widget is added, so it is placed in a second pass).
# Returns 0 when it was added (the shell then needs a restart to show the order).
panel_widget() {
  local shell=(org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s)
  kpackagetool6 -t Plasma/Applet -u "$HERE/plasmoid/$1" >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -i "$HERE/plasmoid/$1"
  busctl --user call "${shell[@]}" "
    panels().filter(p => p.location === 'top' && !p.widgets().some(w => w.type === '$1'))
      .forEach(p => { p.addWidget('$1'); print('added') });" | grep -q added || return 1
  busctl --user call "${shell[@]}" "
    panels().filter(p => p.location === 'top').forEach(p => {
      const ws = p.widgets(), me = ws.find(w => w.type === '$1').id, after = ws.find(w => w.type === '$2');
      p.currentConfigGroup = ['General'];
      let ids = String(p.readConfig('AppletOrder') || '').split(';').map(Number).filter(i => ws.some(w => w.id === i));
      ids = ids.concat(ws.map(w => w.id).filter(i => !ids.includes(i))).filter(i => i !== me);
      ids.splice(after ? ids.indexOf(after.id) + 1 : ids.length, 0, me);
      p.writeConfig('AppletOrder', ids.join(';'));
    });" >/dev/null
}

lab() {
  # Lab Proxmox: CLI, guest picker (Meta+Shift+P), panel widget, alerts + SSH config timer.
  # One-time token setup (root SSH): bin/exsbe-pve-setup root@192.0.2.10 --pbs root@203.0.113.10
  install -Dm755 "$HERE/bin/exsbe-pve" ~/.local/bin/exsbe-pve
  install -Dm755 "$HERE/bin/exsbe-pve-setup" ~/.local/bin/exsbe-pve-setup
  install -Dm755 "$HERE/bin/pvepick" ~/.local/bin/pvepick
  install -Dm755 "$HERE/bin/exsbe-secret" ~/.local/bin/exsbe-secret
  install -Dm755 "$HERE/bin/exsbe-jellyfin" ~/.local/bin/exsbe-jellyfin
  install -Dm755 "$HERE/bin/exsbe-tailnet-routes" ~/.local/bin/exsbe-tailnet-routes
  install -Dm755 "$HERE/bin/exsbe-pve-keys" ~/.local/bin/exsbe-pve-keys   # run once: keys into containers
  # KRunner (Alt+Space): Proxmox guests, ssh hosts, Jellyfin library; started on demand over D-Bus
  install -Dm755 "$HERE/bin/exsbe-krunner" ~/.local/bin/exsbe-krunner
  install -Dm644 "$HERE/krunner/exsbe.desktop" ~/.local/share/krunner/dbusplugins/exsbe.desktop
  mkdir -p ~/.local/share/dbus-1/services
  sed "s|@HOME@|$HOME|" "$HERE/krunner/org.exsbe.krunner.service" > ~/.local/share/dbus-1/services/org.exsbe.krunner.service
  [ -f ~/.config/exsbe/pve.conf ] || install -Dm644 "$HERE/lab/pve.conf" ~/.config/exsbe/pve.conf
  local kitty d; kitty="$(command -v kitty || echo /home/linuxbrew/.linuxbrew/bin/kitty)"
  for d in pvepick proxmox; do
    sed -e "s|@KITTY@|$kitty|" -e "s|@HOME@|$HOME|" "$HERE/bin/$d.desktop" > ~/.local/share/applications/$d.desktop
  done
  kw --file kglobalshortcutsrc --group services --group pvepick.desktop --key _launch "Meta+Shift+P"
  update-desktop-database ~/.local/share/applications 2>/dev/null || true

  # generated Host entries for every node and guest
  mkdir -p -m700 ~/.ssh/config.d
  touch ~/.ssh/config
  grep -qx 'Include config.d/\*' ~/.ssh/config || sed -i '1i Include config.d/*\n' ~/.ssh/config

  install -Dm644 "$HERE/systemd/exsbe-pve.service" ~/.config/systemd/user/exsbe-pve.service
  install -Dm644 "$HERE/systemd/exsbe-pve.timer" ~/.config/systemd/user/exsbe-pve.timer
  systemctl --user daemon-reload
  systemctl --user enable --now exsbe-pve.timer

  # Tailscale: accept the tailscale-router subnet route only when away from home
  install -Dm644 "$HERE/systemd/exsbe-tailnet-routes.service" ~/.config/systemd/user/exsbe-tailnet-routes.service
  systemctl --user daemon-reload
  systemctl --user enable --now exsbe-tailnet-routes.service

  # top bar: Proxmox after the containers widget, Jellyfin (API key: exsbe-secret jellyfin) after it
  local shell=(org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s) added=0 pkg
  for pkg in com.exsbe.proxmox:com.exsbe.containers com.exsbe.jellyfin:com.exsbe.proxmox; do
    panel_widget "${pkg%%:*}" "${pkg#*:}" && added=1
  done
  [ $added = 1 ] && systemctl --user restart plasma-plasmashell.service

  # Lab dashboard on the main screen's desktop (shown only on the Lab workspace).
  # New desktop widgets get a default size, so set position/size in the config with the shell stopped.
  pkg="$HERE/plasmoid/com.exsbe.lab"
  kpackagetool6 -t Plasma/Applet -u "$pkg" >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -i "$pkg"
  local id rc=~/.config/plasma-org.kde.plasma.desktop-appletsrc
  id=$(busctl --user call "${shell[@]}" '
    desktopsForActivity(currentActivity()).filter(d => d.screen === 0 && !d.widgets().some(w => w.type === "com.exsbe.lab"))
      .forEach(d => print(d.addWidget("com.exsbe.lab").id));' | grep -o '[0-9]\+' || true)
  if [ -n "$id" ]; then
    sleep 1
    systemctl --user stop plasma-plasmashell.service
    sed -i -E "s/(Applet-$id:)[0-9.-]+,[0-9.-]+,[0-9.-]+,[0-9.-]+/\1408,0,540,900/g" "$rc"
    systemctl --user start plasma-plasmashell.service
  fi
}

sections=("$@")
[ ${#sections[@]} -eq 0 ] && sections=(colors desktop apps containers splash workflow polish lab layout)
for s in "${sections[@]}"; do
  echo "==> $s"
  "$s"
done
