#!/usr/bin/env python3
"""Merge Exsbe colors and fonts into VS Code user settings without dropping existing keys."""
import json, pathlib, sys

path = pathlib.Path.home() / ".config/Code/User/settings.json"
settings = json.loads(path.read_text()) if path.exists() and path.read_text().strip() else {}

bg, bg2, view, header, fg, fg2, acc = "#232326", "#2a2a2e", "#1c1c1f", "#2b2b2f", "#e6e6e8", "#a8a8b0", "#8fa4c0"
settings.update({
    "workbench.colorTheme": "Default Dark Modern",
    "editor.fontFamily": "'JetBrainsMono Nerd Font', monospace",
    "editor.fontLigatures": True,
    "editor.fontSize": 14,
    "terminal.integrated.fontFamily": "'JetBrainsMono Nerd Font'",
    "window.titleBarStyle": "custom",
})
colors = settings.setdefault("workbench.colorCustomizations", {})
colors.update({
    "editor.background": bg,
    "editorGutter.background": bg,
    "editorGroupHeader.tabsBackground": view,
    "tab.inactiveBackground": view,
    "tab.activeBackground": bg,
    "tab.activeBorderTop": acc,
    "sideBar.background": view,
    "sideBarSectionHeader.background": view,
    "activityBar.background": view,
    "activityBar.activeBorder": acc,
    "activityBarBadge.background": acc,
    "titleBar.activeBackground": view,
    "titleBar.inactiveBackground": view,
    "statusBar.background": view,
    "statusBar.border": header,
    "panel.background": view,
    "terminal.background": bg,
    "terminal.foreground": fg,
    "input.background": bg2,
    "dropdown.background": bg2,
    "editorWidget.background": header,
    "focusBorder": acc,
    "button.background": acc,
    "button.foreground": view,
    "badge.background": acc,
    "badge.foreground": view,
    "progressBar.background": acc,
    "foreground": fg,
    "descriptionForeground": fg2,
    "terminal.ansiBlack": "#2e2e32", "terminal.ansiBrightBlack": "#5a5a62",
    "terminal.ansiRed": "#e07a7a", "terminal.ansiBrightRed": "#ee9a9a",
    "terminal.ansiGreen": "#8fc79a", "terminal.ansiBrightGreen": "#a8d8b2",
    "terminal.ansiYellow": "#e0c47a", "terminal.ansiBrightYellow": "#ecd69a",
    "terminal.ansiBlue": "#7fa8d6", "terminal.ansiBrightBlue": "#9fc0e6",
    "terminal.ansiMagenta": "#b494d6", "terminal.ansiBrightMagenta": "#c8aee6",
    "terminal.ansiCyan": "#7fc8c8", "terminal.ansiBrightCyan": "#9ee0e0",
    "terminal.ansiWhite": "#c8c8cc", "terminal.ansiBrightWhite": "#f2f2f4",
})
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(settings, indent=4) + "\n")
print(f"merged {len(colors)} colors into {path}")
