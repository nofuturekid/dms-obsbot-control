import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services

// The `obsbot4linux watch` of one instance (bar widget, Control Center tile or detail page,
// desktop widget) and the video node behind the camera's by-id path. Lines from obsbot4linux
// come out as `stateEvent` and `reply`; errors are logged and shown as a toast. When the process
// ends, `stopped` and a restart after 2 s, doubling up to 30 s until a state event arrives again.
Item {
    id: watcher

    // false keeps the process off (the throw-away instance DMS creates to read ccWidgetIcon)
    property bool active: false
    // For the log, e.g. "bar widget on screen DP-1"
    property string instanceName: ""
    // V4L2 by-id path from the state ("" without a camera) and the /dev/videoN behind it, what
    // Qt Multimedia calls the camera's id
    property string device: ""
    property string videoNode: ""
    property bool toolMissing: false
    readonly property bool running: process.running
    property int backoff: 2000

    signal stateEvent(var state)
    signal reply(var msg)
    signal stopped

    function write(id, args) {
        process.write(JSON.stringify({ id: id, args: args.map(String) }) + "\n");
    }

    // Retry button: start the watcher again now
    function refresh() {
        if (active && !process.running)
            process.running = true;
    }

    function log(text) {
        console.info("obsbot4linuxDux (" + instanceName + "): " + text);
    }

    // One line when a real instance starts; later, so the host has set the screen
    property bool started: false
    function logStart() {
        if (!active || started)
            return;
        started = true;
        Qt.callLater(() => console.info("obsbot4linuxDux: started as " + watcher.instanceName));
    }
    onActiveChanged: logStart()
    Component.onCompleted: logStart()

    onVideoNodeChanged: {
        if (active)
            log(videoNode !== "" ? "video node " + videoNode : "waiting for the camera");
    }

    onDeviceChanged: {
        videoNode = "";
        if (device === "")
            return;
        const wanted = device;
        // No id: Proc debounces per id and keeps only the last callback, so a shared id would
        // leave every instance but the last (one per screen) without its video node. The owner
        // drops the callback once this instance is gone.
        Proc.runCommand(null, ["readlink", "-f", wanted], (stdout, exitCode) => {
            if (exitCode === 0 && watcher.device === wanted)
                watcher.videoNode = stdout.trim();
        }, undefined, undefined, watcher);
    }

    function handleLine(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (msg.event === "state") {
            backoff = 2000;
            stateEvent(msg.state);
        } else if (msg.id !== undefined) {
            if (msg.ok === false) {
                console.warn("obsbot4linuxDux: obsbot4linux:", msg.error);
                // A toast for a few seconds: the first line of the error, the rest (e.g. the
                // usage) as its details
                const lines = String(msg.error ?? "").trim().split("\n");
                ToastService.showError("OBSBOT Control: " + lines[0], lines.slice(1).join("\n").trim());
            }
            reply(msg);
        }
    }

    Process {
        id: process
        // Exit code 127 tells "tool not installed" apart from a daemon or camera problem
        command: ["sh", "-c", "command -v obsbot4linux >/dev/null || exit 127; exec obsbot4linux watch"]
        running: watcher.active
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => watcher.handleLine(line)
        }
        stderr: SplitParser {
            onRead: line => console.warn("obsbot4linuxDux (" + watcher.instanceName + "): watch:", line)
        }
        onExited: exitCode => {
            watcher.toolMissing = exitCode === 127;
            restartTimer.interval = watcher.toolMissing ? 10000 : watcher.backoff;
            console.warn("obsbot4linuxDux (" + watcher.instanceName + "): watch exited with code " + exitCode + ", restart in " + restartTimer.interval / 1000 + " s");
            watcher.backoff = Math.min(watcher.backoff * 2, 30000);
            watcher.stopped();
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        onTriggered: process.running = true
    }
}
