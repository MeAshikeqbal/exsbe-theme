#!/usr/bin/env bash
# System-level Exsbe pieces on Bazzite (immutable /usr, so files go to /usr/local, /var and /etc).
# Run: sudo ./install-boot.sh [plymouth] [login]     (no argument = both), then reboot.
#   plymouth: boot splash (needs rpm/build.sh first)
#   login:    Plasma Login Manager greeter in the Exsbe look
# Run ./install.sh first: the login part copies your applied colors, fonts and cursor.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
USER_HOME="$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)"

plymouth() {
  local rpm
  rpm=$(ls "$HERE"/rpm/exsbe-plymouth-*.noarch.rpm | tail -1)

  # 1. layer the theme package (pulls the script and label plugins with it); a newer build
  #    replaces the layered one in the same transaction
  local want have=""
  want=$(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$rpm")
  rpm -q exsbe-plymouth >/dev/null 2>&1 && have=$(rpm -q --qf '%{VERSION}-%{RELEASE}' exsbe-plymouth)
  if [ -z "$have" ]; then
    rpm-ostree install "$rpm"
  elif [ "$have" != "$want" ]; then
    echo "exsbe-plymouth $have -> $want"
    rpm-ostree uninstall exsbe-plymouth --install "$rpm"
  else
    echo "exsbe-plymouth $have is already layered"
  fi

  # 2. select it (admin override file; distro defaults stay untouched)
  local conf=/etc/plymouth/plymouthd.conf
  if grep -q '^\[Daemon\]' "$conf"; then
    sed -i '/^Theme=/d' "$conf"
    sed -i '/^\[Daemon\]/a Theme=exsbe' "$conf"
  else
    printf '\n[Daemon]\nTheme=exsbe\n' >> "$conf"
  fi

  # 3. the theme must be inside the initramfs, so build it locally from now on
  rpm-ostree initramfs | grep -q 'regeneration: enabled' || rpm-ostree initramfs --enable
}

login() {
  # the greeter runs as the 'plasmalogin' user and can't read your home, so
  # shared assets go to /usr/local (writable on Bazzite) and /var/lib/exsbe
  # the boot splash's graphite background, so boot -> login -> desktop is one continuous look
  install -Dm644 "$HERE/plymouth/exsbe/background.png" /var/lib/exsbe/login.png
  chmod 755 /var/lib/exsbe
  install -d /usr/local/share/fonts/Inter
  install -m644 "$USER_HOME"/.local/share/fonts/Inter/*.ttf /usr/local/share/fonts/Inter/
  fc-cache -f /usr/local/share/fonts
  rm -rf /usr/local/share/icons/WhiteSur-cursors /usr/local/share/plasma/desktoptheme/exsbe
  mkdir -p /usr/local/share/icons /usr/local/share/plasma/desktoptheme /usr/local/share/color-schemes
  cp -r "$USER_HOME/.icons/WhiteSur-cursors" /usr/local/share/icons/
  cp -r "$HERE/plasma-style/exsbe" /usr/local/share/plasma/desktoptheme/exsbe
  install -m644 "$HERE/colors/Exsbe.colors" /usr/local/share/color-schemes/Exsbe.colors
  chmod -R a+rX /usr/local/share/icons/WhiteSur-cursors /usr/local/share/plasma/desktoptheme/exsbe

  # greeter background
  install -d /etc/plasmalogin.conf.d
  cat > /etc/plasmalogin.conf.d/10-exsbe.conf <<'EOF'
[Greeter]
WallpaperPlugin=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
Image=file:///var/lib/exsbe/login.png
PreviewImage=file:///var/lib/exsbe/login.png
EOF

  # greeter look: your applied colors/fonts (kdeglobals), cursor and Plasma style
  local gh; gh="$(getent passwd plasmalogin | cut -d: -f6)"
  install -d -o plasmalogin -g plasmalogin "$gh/.config"
  grep -v '^LookAndFeelPackage=' "$USER_HOME/.config/kdeglobals" > "$gh/.config/kdeglobals"
  printf '[Mouse]\ncursorTheme=WhiteSur-cursors\ncursorSize=24\n' > "$gh/.config/kcminputrc"
  printf '[Theme]\nname=exsbe\n' > "$gh/.config/plasmarc"
  chown plasmalogin:plasmalogin "$gh/.config"/{kdeglobals,kcminputrc,plasmarc}
}

parts=("$@")
[ ${#parts[@]} -eq 0 ] && parts=(plymouth login)
for p in "${parts[@]}"; do
  echo "==> $p"
  "$p"
done
echo "Done. Reboot (plymouth) or log out (login screen) to see the changes."
