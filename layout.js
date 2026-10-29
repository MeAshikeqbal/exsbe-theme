// Exsbe "Focus" layout. Run with:
//   qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat layout.js)"
// Replaces all panels with a slim top bar and an auto-hiding dock.

panels().forEach(function (p) { p.remove(); });

function add(panel, plugin, config) {
    var w = panel.addWidget(plugin);
    for (var group in config || {}) {
        w.currentConfigGroup = [group];
        for (var key in config[group]) w.writeConfig(key, config[group][key]);
    }
    return w;
}

// top bar: launcher, desktops, app menu | clock | load, containers, tray
var top = new Panel;
top.location = "top";
top.height = 34;
top.floating = true;
top.hiding = "none";
top.lengthMode = "fill";

add(top, "org.kde.plasma.kickoff", { General: { icon: "@ICON@" } });
add(top, "org.kde.plasma.panelspacer", { General: { expanding: false, length: 10 } });
add(top, "com.exsbe.workspaces");
add(top, "org.kde.plasma.appmenu");
add(top, "org.kde.plasma.panelspacer");
add(top, "org.kde.plasma.digitalclock", {
    Appearance: { autoFontAndSize: false, fontFamily: "Inter Variable", fontSize: 10, fontWeight: 500, showDate: true, dateDisplayFormat: "BesideTime", dateFormat: "custom", customDateFormat: "ddd d MMM", use24hFormat: 0 }
});
add(top, "org.kde.plasma.panelspacer");
add(top, "org.kde.plasma.systemmonitor.cpu");
add(top, "org.kde.plasma.systemmonitor.memory");
add(top, "com.exsbe.containers");
add(top, "com.exsbe.proxmox");
add(top, "com.exsbe.jellyfin");
add(top, "org.kde.plasma.systemtray");

// dock: browser, terminal, editor, files; hides when a window covers it
var dock = new Panel;
dock.location = "bottom";
dock.height = 48;
dock.floating = true;
dock.hiding = "dodgewindows";
dock.lengthMode = "fit";
dock.alignment = "center";

add(dock, "org.kde.plasma.icontasks", {
    General: {
        launchers: [
            "applications:com.brave.Browser.desktop",
            "applications:kitty.desktop",
            "applications:code.desktop",
            "applications:org.kde.dolphin.desktop"
        ].join(","),
        showOnlyCurrentDesktop: true,
        groupingStrategy: 1,
        iconSpacing: 1
    }
});
