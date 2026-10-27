// Exsbe game mode: while the "Play" workspace is current, turn off GPU-heavy
// effects, let the dock fully auto-hide and hold notifications (Do Not Disturb).
const PLAY = "Play";
const EFFECTS = ["blur", "contrast"];

let active = false;

function setDock(mode) {
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript",
        "panels().forEach(function (p) { if (p.location == 'bottom') p.hiding = '" + mode + "'; });");
}

function setDnd(on) {
    // exsbe-dnd.service holds the inhibition; KWin scripts can't pass the uint
    // cookie that UnInhibit needs, so the helper's lifetime is the switch instead
    callDBus("org.freedesktop.systemd1", "/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager",
        on ? "StartUnit" : "StopUnit", "exsbe-dnd.service", "replace");
}

function update() {
    const play = workspace.currentDesktop && workspace.currentDesktop.name === PLAY;
    if (play === active) return;
    active = play;
    for (const effect of EFFECTS)
        callDBus("org.kde.KWin", "/Effects", "org.kde.kwin.Effects", play ? "unloadEffect" : "loadEffect", effect);
    setDock(play ? "autohide" : "dodgewindows");
    setDnd(play);
}

workspace.currentDesktopChanged.connect(update);
update();
