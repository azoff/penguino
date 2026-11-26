// Window Memory: per-monitor-setup window positions (docs/pop26-plasma.md).
//
// A "setup" is the exact set of connected monitors (identified from EDID by
// conf/bin/window-memory-store, which also stores the layouts). For each
// setup, each app (Wayland app id; every Vivaldi web app is its own app) has
// at most one saved spot: monitor, position/size on that monitor, maximized,
// fullscreen. All of an app's windows go to that spot.
//
// - window opens: moved to its app's spot for the current setup, if any
// - monitors change: once they settle, every open window with a spot moves
// - Meta+Ctrl+S: save every open window's spot for the current setup (apps
//   not open keep theirs); Meta+Ctrl+L: re-apply the current setup's spots
// - no saved spot (or unsaved setup): the window is left alone
import QtQuick
import org.kde.kwin

Item {
    id: root

    readonly property string service: "local.penguino.WindowMemory"
    readonly property string objectPath: "/local/penguino/WindowMemory"

    property string setupId: ""
    property string lastSetupId: ""   // setup before the latest monitor event: only a different set moves windows
    property string setupName: ""
    property var outputIds: ({})      // connector name -> monitor id
    property var apps: null           // app key -> spot, for the current setup (null: never saved)
    property bool resolving: false
    property bool monitorsChanged: false
    property bool applyAfterResolve: false
    property bool saveAfterResolve: false
    property var waiting: []          // windows opened while the setup was being resolved
    property var replace: []          // [{window, due}] second placement pass for new windows

    function log(msg) { console.log("window-memory: " + msg); }

    function eligible(w) {
        return w && !w.deleted && w.managed && w.normalWindow && !w.transient && !w.specialWindow
            && !w.skipTaskbar && w.moveable && w.moveableAcrossScreens;
    }

    function appKey(w) { return w.desktopFileName || w.resourceClass || w.resourceName; }

    function outputsJson() {
        var list = [];
        for (const s of Workspace.screens)
            list.push({name: s.name, manufacturer: s.manufacturer, model: s.model, serial: s.serialNumber,
                       x: s.geometry.x, y: s.geometry.y, width: s.geometry.width, height: s.geometry.height});
        return JSON.stringify(list);
    }

    function outputById(id) {
        for (const s of Workspace.screens)
            if (outputIds[s.name] === id) return s;
        return null;
    }

    function notify(summary, body) {
        notifyCall.arguments = [summary, body];
        notifyCall.call();
    }

    // ---- placing -------------------------------------------------------

    function place(w, spot) {
        var out = outputById(spot.output);
        if (!out) return false;               // that monitor is not part of this setup
        if (w.fullScreen && !spot.fullScreen) w.fullScreen = false;
        if (w.maximizeMode !== 0) w.setMaximize(false, false);
        var g = out.geometry;
        var width = Math.min(spot.width, g.width), height = Math.min(spot.height, g.height);
        var x = g.x + Math.max(0, Math.min(spot.x, g.width - width));
        var y = g.y + Math.max(0, Math.min(spot.y, g.height - height));
        w.frameGeometry = Qt.rect(x, y, width, height);
        if (spot.maximized) w.setMaximize(true, true);
        if (spot.fullScreen) w.fullScreen = true;
        return true;
    }

    function placeWindow(w) {
        if (!apps || !eligible(w)) return false;
        var spot = apps[appKey(w)];
        return spot ? place(w, spot) : false;
    }

    function applyAll(reason) {
        if (!apps) {
            if (reason === "monitors" || reason === "shortcut")
                notify("Window layout: " + setupName, "Not saved yet. Arrange your windows, then press Meta+Ctrl+S.");
            log("no saved layout for " + setupId + " (" + reason + ")");
            return;
        }
        var n = 0;
        for (const w of Workspace.windows)
            if (placeWindow(w)) n++;
        log("applied " + n + " windows for " + setupId + " (" + reason + ")");
        if (reason === "monitors" || reason === "shortcut")
            notify("Window layout: " + setupName, n + " window" + (n === 1 ? "" : "s") + " placed");
    }

    // ---- saving --------------------------------------------------------

    function save() {
        if (!setupId) { saveAfterResolve = true; resolve(); return; }
        var spots = {};
        // stackingOrder runs bottom to top: for apps with several windows the topmost one wins
        for (const w of Workspace.stackingOrder) {
            if (!eligible(w) || !w.output || !outputIds[w.output.name]) continue;
            var g = w.output.geometry, f = w.frameGeometry;
            spots[appKey(w)] = {
                output: outputIds[w.output.name],
                x: Math.round(f.x - g.x), y: Math.round(f.y - g.y),
                width: Math.round(f.width), height: Math.round(f.height),
                maximized: w.maximizeMode === 3, fullScreen: w.fullScreen
            };
        }
        var merged = Object.assign({}, apps || {});
        for (const k in spots) merged[k] = spots[k];
        apps = merged;
        saveCall.arguments = [setupId, setupName, outputsJson(), JSON.stringify(spots)];
        saveCall.call();
        log("saving " + Object.keys(spots).length + " apps for " + setupId);
    }

    // ---- monitor setup -------------------------------------------------

    function resolve() {
        resolving = true;
        resolveCall.arguments = [outputsJson()];
        resolveCall.call();
    }

    DBusCall {
        id: resolveCall
        service: root.service; path: root.objectPath; dbusInterface: root.service
        method: "Resolve"
        onFinished: (returnValue) => {
            var r = JSON.parse(returnValue[0]);
            root.setupId = r.setup;
            root.setupName = r.name;
            root.outputIds = r.outputs;
            root.apps = r.apps;
            root.resolving = false;
            root.log("setup " + r.setup + (r.apps ? " (" + Object.keys(r.apps).length + " apps saved)" : " (not saved)"));
            if (root.applyAfterResolve) {
                root.applyAfterResolve = false;
                // the DisplayLink dock re-announces its screen now and then; with the
                // same set of monitors nothing changed, so leave the windows alone
                if (r.setup !== root.lastSetupId) root.applyAll("monitors");
                else root.log("monitor event, same setup: nothing to do");
            }
            root.lastSetupId = r.setup;
            for (const w of root.waiting) root.placeNew(w);
            root.waiting = [];
            if (root.saveAfterResolve) { root.saveAfterResolve = false; root.save(); }
        }
        onFailed: { root.resolving = false; root.log("store unavailable: Resolve failed"); }
    }

    DBusCall {
        id: saveCall
        service: root.service; path: root.objectPath; dbusInterface: root.service
        method: "Save"
        onFailed: root.log("store unavailable: Save failed")
    }

    DBusCall {
        id: notifyCall
        service: root.service; path: root.objectPath; dbusInterface: root.service
        method: "Notify"
    }

    // monitors come and go in several steps (connect, then KScreen applies
    // the arrangement), so wait until things are quiet before acting
    Timer {
        id: settle
        interval: 1500
        onTriggered: {
            root.applyAfterResolve = root.monitorsChanged;
            root.monitorsChanged = false;
            root.resolve();
        }
    }

    // ---- new windows ---------------------------------------------------

    function placeNew(w) {
        if (!eligible(w)) return;
        if (resolving || settle.running) { waiting.push(w); return; }
        if (placeWindow(w)) {
            log("placed new window: " + appKey(w));
            // apps like Vivaldi and Slack resize themselves right after
            // opening; place them again once that has happened
            replace.push({window: w, due: Date.now() + 700});
            replaceTimer.start();
        }
    }

    Timer {
        id: replaceTimer
        interval: 200; repeat: true
        onTriggered: {
            var now = Date.now(), rest = [];
            for (const item of root.replace) {
                if (item.due > now) { rest.push(item); continue; }
                if (!item.window.deleted) root.placeWindow(item.window);
            }
            root.replace = rest;
            if (!rest.length) stop();
        }
    }

    Connections {
        target: Workspace
        function onWindowAdded(w) { root.placeNew(w); }
        function onScreensChanged() { root.monitorsChanged = true; settle.restart(); }
        // arrangement changes after a hotplug: keep waiting, don't treat as a new setup
        function onVirtualScreenGeometryChanged() { if (settle.running) settle.restart(); }
    }

    ShortcutHandler {
        name: "Window Memory: Save layout"
        text: "Window Memory: Save window layout for these monitors"
        sequence: "Meta+Ctrl+S"
        onActivated: root.save()
    }

    ShortcutHandler {
        name: "Window Memory: Apply layout"
        text: "Window Memory: Put windows back where they were saved"
        sequence: "Meta+Ctrl+L"
        onActivated: root.applyAll("shortcut")
    }

    // existing windows are left where they are at startup (login, reload);
    // only the setup is looked up
    Component.onCompleted: resolve()
}
