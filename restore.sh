#!/usr/bin/env bash
# Undo the Exsbe desktop theme: restore the config backup taken before install.
# Usage: ./restore.sh [backup.tar.gz]     (boot splash: sudo rpm-ostree uninstall exsbe-plymouth)
set -euo pipefail
backup="${1:-$(ls ~/exsbe-theme-backup-*.tar.gz | head -1)}"
echo "restoring $backup"

# plasmashell rewrites its layout file on exit, so stop it before restoring
systemctl --user stop plasma-plasmashell.service
tar xzf "$backup" -C ~/.config
systemctl --user start plasma-plasmashell.service

plasma-apply-colorscheme "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)"
plasma-apply-desktoptheme "$(kreadconfig6 --file plasmarc --group Theme --key name)"
busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure
kpackagetool6 -t Plasma/Applet -r com.exsbe.containers >/dev/null 2>&1 || true
kpackagetool6 -t Plasma/LookAndFeel -r com.exsbe.desktop >/dev/null 2>&1 || true
echo "Restored. Log out and back in to finish."
