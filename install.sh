#!/usr/bin/env bash
# Exsbe desktop theme installer (user level, no sudo).
# Usage: ./install.sh [section...]   sections: colors desktop apps containers splash layout
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
  kw --file kdeglobals --group Icons --key Theme WhiteSur-dark
  plasma-apply-cursortheme WhiteSur-cursors || true

  # window decoration: Exsbe Aurorae (rounded graphite frame), buttons on the right
  rm -rf ~/.local/share/aurorae/themes/Exsbe
  cp -r "$HERE/aurorae/Exsbe" ~/.local/share/aurorae/themes/Exsbe
  kw --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae.v2
  kw --file kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__Exsbe
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
  local pkg="$HERE/plasmoid/com.exsbe.workspaces"
  kpackagetool6 -t Plasma/Applet -u "$pkg" >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -i "$pkg"
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

sections=("$@")
[ ${#sections[@]} -eq 0 ] && sections=(colors desktop apps containers splash workflow layout)
for s in "${sections[@]}"; do
  echo "==> $s"
  "$s"
done
