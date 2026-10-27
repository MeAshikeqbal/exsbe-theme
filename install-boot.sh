#!/usr/bin/env bash
# Install the Exsbe Plymouth boot splash on Bazzite (immutable /usr).
# Run: sudo ./install-boot.sh   then reboot.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
rpm=$(ls "$HERE"/rpm/exsbe-plymouth-*.noarch.rpm | tail -1)

# 1. layer the theme package (pulls plymouth-plugin-script with it)
rpm -q exsbe-plymouth >/dev/null 2>&1 || rpm-ostree install "$rpm"

# 2. select it (admin override file; distro defaults stay untouched)
conf=/etc/plymouth/plymouthd.conf
if grep -q '^\[Daemon\]' "$conf"; then
  sed -i '/^Theme=/d' "$conf"
  sed -i '/^\[Daemon\]/a Theme=exsbe' "$conf"
else
  printf '\n[Daemon]\nTheme=exsbe\n' >> "$conf"
fi

# 3. the theme must be inside the initramfs, so build it locally from now on
rpm-ostree initramfs --enable

echo "Done. Reboot to see the Exsbe boot splash."
