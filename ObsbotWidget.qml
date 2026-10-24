import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // The status is decoded from the raw state block (`tiny4linux-cli -v info`) because
    // tiny4linux 2.2.1 decodes it with Tiny 2 offsets: on the Lite the tracking speed sits
    // at 0x24 (not 0x21) and hand tracking reads (3, 0) (not (6, 0)).
    // code = [block[0x18], block[0x1c]]
    readonly property var trackingModes: [
        { label: "Static", arg: "static", code: [0, 0] },
        { label: "Normal Tracking", arg: "normal", code: [2, 0] },
        { label: "Upper Body", arg: "upper-body", code: [2, 1] },
        { label: "Close-up", arg: "close-up", code: [2, 2] },
        { label: "Headless", arg: "headless", code: [2, 3] },
        { label: "Lower Body", arg: "lower-body", code: [2, 4] },
        { label: "Desk Mode", arg: "desk", code: [5, 0] },
        { label: "Whiteboard", arg: "whiteboard", code: [4, 0] },
        { label: "Hand", arg: "hand", code: [3, 0] },
        { label: "Group", arg: "group", code: [1, 0] }
    ]
    // code = block[0x24]
    readonly property var speeds: [
        { label: "Standard", arg: "standard", code: 0 },
        { label: "Sport", arg: "fast", code: 2 }
    ]

    readonly property string device: "/dev/v4l/by-id/usb-Remo_Tech_Co.__Ltd._OBSBOT_Tiny_2_Lite-video-index0"

    // Exposure mode is not part of the status block, so the last choice is remembered
    readonly property var exposureModes: [
        { label: "Global", arg: "global" },
        { label: "Face", arg: "face" },
        { label: "Manual", arg: "manual" }
    ]
    readonly property string exposure: pluginData?.exposure ?? ""
    // Settings page: tracking mode applied whenever the camera wakes up ("" = keep)
    readonly property string wakeTrackingMode: pluginData?.wakeTrackingMode ?? ""

    // UVC controls: name, label, range and camera default (`v4l2-ctl -L`)
    readonly property var imageControls: [
        { name: "brightness", label: "Brightness", min: 0, max: 100, def: 50 },
        { name: "contrast", label: "Contrast", min: 0, max: 100, def: 50 },
        { name: "saturation", label: "Saturation", min: 0, max: 100, def: 50 },
        { name: "sharpness", label: "Sharpness", min: 0, max: 100, def: 50 },
        { name: "backlight_compensation", label: "Backlight compensation", min: 0, max: 18, def: 9 }
    ]
    property var controlValues: ({})
    readonly property bool imageAtDefaults: imageControls.every(c => (controlValues[c.name] ?? c.def) === c.def)
    // Gimbal units are 1/3600 degree; pan +/-130 deg (positive = camera left), tilt +/-90 deg
    readonly property int gimbalStep: 5 * 3600
    property int pan: 0
    property int tilt: 0

    property bool available: false
    property bool toolMissing: false
    property bool awake: false
    // Last awake state read from the camera (root.awake is also set optimistically)
    property bool readAwake: false
    property bool statusKnown: false
    property string aiMode: ""
    property string speed: ""
    property bool hdr: false
    // Label of the command in flight, shown in the header until the camera confirms
    property string pendingLabel: ""

    // Subcommands of the installed tiny4linux-cli (`--help`). The Lite settings below are
    // only offered where the CLI has the command, so an older tiny4linux keeps the popout
    // as it was.
    property var commands: []
    function has(name) {
        return root.commands.indexOf(name) >= 0;
    }
    readonly property bool liteAvailable: ["fov", "led", "auto-sleep", "audio", "gesture", "hand", "zone", "factory-reset"].some(c => has(c))

    // Settings as `info` reports them, keyed by their English label ("Field of View": "Wide").
    // Older CLIs print fewer lines; a missing value just leaves its chips unselected.
    property var lite: ({})
    function liteValue(key) {
        return root.lite[key] ?? "";
    }
    function setLite(args, label, key, value) {
        const values = Object.assign({}, root.lite);
        values[key] = value;
        root.lite = values;
        root.run(args, label);
    }

    // Auto-sleep times offered, the choices of OBSBOT Center; `info` prints "120 s" or
    // "Off (120 s)" when auto-sleep is off but keeps the time
    readonly property var autoSleepTimes: [
        { label: "Off", arg: "off" },
        { label: "30 s", arg: "30" },
        { label: "2 min", arg: "120" },
        { label: "10 min", arg: "600" }
    ]
    function autoSleepIndex() {
        const value = liteValue("Auto-Sleep");
        if (value === "")
            return -1;
        if (value.startsWith("Off"))
            return 0;
        return autoSleepTimes.findIndex(t => t.arg + " s" === value);
    }

    // Live preview; holds the camera, so no other app can open it meanwhile
    property bool previewOn: false
    readonly property bool live: available && awake

    readonly property string statusText: {
        if (!available)
            return toolMissing ? "Control tool not found" : "Not reachable";
        if (pendingLabel !== "")
            return pendingLabel + "…";
        return awake ? "Awake · " + aiMode : "Asleep · lens stowed";
    }

    // DMS only hides the popout, its content stays alive; switch the preview off on close
    onInteractionActiveChanged: {
        if (!interactionActive)
            previewOn = false;
        else if (!controlsProc.running)
            controlsProc.running = true;
    }

    signal stateRefreshed

    function indexOf(list, label) {
        return list.findIndex(m => m.label === label);
    }

    // The open card of each column of Lite settings ("" = all closed); opening one closes
    // the other in the same column, so the popout stays short
    property string openLeft: ""
    property string openRight: ""

    property bool refreshPending: false

    function refresh() {
        if (infoProc.running)
            refreshPending = true;
        else
            infoProc.running = true;
    }

    // Callers set the expected state first so the UI reacts at once; the camera needs
    // ~0.5 s before its status block shows a change, hence the second read via settleTimer.
    function run(args, label) {
        root.pendingLabel = label ?? "";
        actionProc.command = ["tiny4linux-cli", "--lang", "en"].concat(args);
        actionProc.running = true;
        root.stateRefreshed();
    }

    function setAwake(on) {
        root.awake = on;
        if (!on)
            root.previewOn = false;
        root.run([on ? "wake" : "sleep"], on ? "Waking camera" : "Stowing lens");
    }

    function setMode(index) {
        const mode = root.trackingModes[index];
        root.aiMode = mode.label;
        root.run(["tracking", mode.arg], "Switching to " + mode.label);
    }

    function setSpeed(index) {
        root.speed = root.speeds[index].label;
        root.run(["speed", root.speeds[index].arg], "Setting speed to " + root.speed);
    }

    function setHdr(on) {
        root.hdr = on;
        root.run(["hdr", on ? "on" : "off"], on ? "Turning HDR on" : "Turning HDR off");
    }

    // The camera restarts and drops off USB for ~20 s; the regular refresh picks it up again
    function factoryReset() {
        root.previewOn = false;
        root.run(["factory-reset", "--yes"], "Resetting to factory settings");
    }

    function setExposure(index) {
        const mode = root.exposureModes[index];
        pluginService?.savePluginData(pluginId, "exposure", mode.arg);
        root.run(["exposure", mode.arg], "Setting exposure to " + mode.label);
    }

    function setControl(name, value) {
        Quickshell.execDetached(["v4l2-ctl", "-d", root.device, "-c", name + "=" + value]);
        const values = Object.assign({}, root.controlValues);
        values[name] = value;
        root.controlValues = values;
    }

    // Manual moves only stick without AI tracking, so they switch to Static first
    function moveGimbal(newPan, newTilt) {
        if (root.aiMode !== "Static") {
            root.aiMode = "Static";
            root.run(["tracking", "static"], "Switching to Static");
        }
        root.pan = Math.max(-468000, Math.min(468000, newPan));
        root.tilt = Math.max(-324000, Math.min(324000, newTilt));
        Quickshell.execDetached(["v4l2-ctl", "-d", root.device, "-c", "pan_absolute=" + root.pan + ",tilt_absolute=" + root.tilt]);
    }

    function degrees(units) {
        const d = Math.round(units / 3600);
        return (d > 0 ? "+" : d < 0 ? "−" : "") + Math.abs(d) + "°";
    }

    visibilityCommand: "test -e " + device
    visibilityInterval: 5

    Process {
        id: infoProc
        // Exit code 127 tells "tool not installed" apart from "camera not reachable"
        command: ["sh", "-c", "command -v tiny4linux-cli >/dev/null || exit 127; exec tiny4linux-cli --lang en -v info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Current state: \[([0-9, ]+)\]/);
                const b = m ? m[1].split(",").map(Number) : [];
                root.available = b.length > 0x24;
                if (root.available) {
                    const nowAwake = b[0x02] === 0;
                    // Only on a real sleep -> awake change, not on the first read after a DMS start
                    if (nowAwake && root.statusKnown && !root.readAwake && root.wakeTrackingMode !== "")
                        root.run(["tracking", root.wakeTrackingMode]);
                    root.readAwake = nowAwake;
                    root.statusKnown = true;
                    root.awake = nowAwake;
                    root.hdr = b[0x06] !== 0;
                    const mode = root.trackingModes.find(t => t.code[0] === b[0x18] && t.code[1] === b[0x1c]);
                    root.aiMode = mode ? mode.label : "";
                    const speed = root.speeds.find(t => t.code === b[0x24]);
                    root.speed = speed ? speed.label : "";

                    // "  🔭  Field of View: Wide": drop the icon, split at the last ": "
                    // (labels like "Gesture: Zoom" contain one themselves)
                    const values = {};
                    for (const line of text.split("\n")) {
                        const entry = line.replace(/^\s*\S+\s+/, "");
                        const split = entry.lastIndexOf(": ");
                        if (line.startsWith("  ") && split > 0)
                            values[entry.slice(0, split)] = entry.slice(split + 2).trim();
                    }
                    root.lite = values;
                }
                root.stateRefreshed();
            }
        }
        onExited: exitCode => {
            root.toolMissing = exitCode === 127;
            if (!root.toolMissing && root.commands.length === 0 && !helpProc.running)
                helpProc.running = true;
            if (root.refreshPending) {
                root.refreshPending = false;
                infoProc.running = true;
            }
        }
    }

    Process {
        id: helpProc
        command: ["tiny4linux-cli", "--lang", "en", "--help"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                for (const line of text.split("\n")) {
                    const m = line.match(/^  ([a-z][a-z-]*)\s{2,}/);
                    if (m)
                        names.push(m[1]);
                }
                root.commands = names;
            }
        }
    }

    Process {
        id: controlsProc
        command: ["v4l2-ctl", "-d", root.device, "-C", root.imageControls.map(c => c.name).concat(["zoom_absolute", "pan_absolute", "tilt_absolute"]).join(",")]
        stdout: StdioCollector {
            onStreamFinished: {
                const values = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\w+):\s*(-?\d+)/);
                    if (m)
                        values[m[1]] = Number(m[2]);
                }
                root.pan = values.pan_absolute ?? 0;
                root.tilt = values.tilt_absolute ?? 0;
                root.controlValues = values;
            }
        }
    }

    Process {
        id: actionProc
        onExited: {
            root.refresh();
            settleTimer.restart();
        }
    }

    Timer {
        id: settleTimer
        interval: 1500
        onTriggered: {
            root.pendingLabel = "";
            root.refresh();
        }
    }

    Timer {
        interval: 10000
        running: root.surfaceLive
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Layout 1b, static: always two columns (picture | behaviour); the preview area stays
    // in place and is black while the preview is off
    popoutWidth: 760

    // The bar draws the pill; plugins only provide the icon (same as the built-in widgets)
    horizontalBarPill: Component {
        DIcon {
            name: root.live ? "videocam" : "videocam_off"
            color: root.live ? Theme.primary : Theme.surfaceVariantText
            size: root.iconSize
            anchors.verticalCenter: parent.verticalCenter

            // Dot: the preview is holding the camera
            Rectangle {
                visible: root.previewOn && root.live
                width: Math.round(root.iconSize / 4)
                height: width
                radius: width / 2
                anchors.top: parent.top
                anchors.right: parent.right
                color: Theme.surfaceText
            }
        }
    }

    verticalBarPill: Component {
        DIcon {
            name: root.live ? "videocam" : "videocam_off"
            color: root.live ? Theme.primary : Theme.surfaceVariantText
            size: root.iconSize
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            Component.onCompleted: {
                root.refresh();
                controlsProc.running = true;
            }

            // DMS sizes the popout to its content; past 85 % of the screen the body scrolls
            // and the header stays in place
            readonly property real maxBodyHeight: Math.round(Screen.height * 0.85) - header.height - Theme.spacingM

            HeaderBar {
                id: header
                width: parent.width
                ctl: root
            }

            Item {
                width: parent.width
                height: Theme.spacingM
            }

            DFlickable {
                id: body
                width: parent.width
                height: Math.min(bodyColumn.implicitHeight, popout.maxBodyHeight)
                contentWidth: width
                contentHeight: bodyColumn.implicitHeight
                clip: true

                Column {
                    id: bodyColumn
                    width: body.width
                    spacing: Theme.spacingM

                    // Layout 2a: same two columns in every state, so the panel never jumps.
                    // Rows: Preview | Tracking (same height), then Framing + Picture | Image.
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        readonly property real topRowHeight: Math.max(preview.implicitHeight, tracking.implicitHeight)

                        Column {
                            id: leftColumn
                            width: (parent.width - parent.spacing) / 2
                            spacing: Theme.spacingM

                            PreviewPane {
                                id: preview
                                width: parent.width
                                height: parent.parent.topRowHeight
                                ctl: root
                            }

                            FramingSection {
                                id: framing
                                width: parent.width
                                ctl: root
                            }

                            PictureSection {
                                id: picture
                                width: parent.width
                                ctl: root
                            }
                        }

                        Column {
                            width: parent.width - leftColumn.width - parent.spacing
                            spacing: Theme.spacingM

                            TrackingSection {
                                id: tracking
                                width: parent.width
                                height: parent.parent.topRowHeight
                                ctl: root
                            }

                            ImageSection {
                                width: parent.width
                                height: Math.max(implicitHeight, framing.height + picture.height + parent.spacing)
                                ctl: root
                            }
                        }
                    }

                    // Settings of tiny4linux builds that have the Tiny 2 Lite commands; collapsed
                    // by default so the popout keeps its height
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: root.liteAvailable

                        Column {
                            id: liteLeft
                            width: (parent.width - parent.spacing) / 2
                            spacing: Theme.spacingM

                            CameraSection {
                                width: parent.width
                                ctl: root
                                controlled: true
                                expanded: root.openLeft === "camera"
                                onToggleRequested: root.openLeft = expanded ? "" : "camera"
                            }

                            SleepSection {
                                width: parent.width
                                ctl: root
                                controlled: true
                                expanded: root.openLeft === "sleep"
                                onToggleRequested: root.openLeft = expanded ? "" : "sleep"
                            }

                            HandZoneSection {
                                width: parent.width
                                ctl: root
                                controlled: true
                                expanded: root.openLeft === "handZone"
                                onToggleRequested: root.openLeft = expanded ? "" : "handZone"
                            }
                        }

                        Column {
                            width: parent.width - liteLeft.width - parent.spacing
                            spacing: Theme.spacingM

                            AudioSection {
                                width: parent.width
                                ctl: root
                                controlled: true
                                expanded: root.openRight === "audio"
                                onToggleRequested: root.openRight = expanded ? "" : "audio"
                            }

                            GestureSection {
                                width: parent.width
                                ctl: root
                                controlled: true
                                expanded: root.openRight === "gestures"
                                onToggleRequested: root.openRight = expanded ? "" : "gestures"
                            }

                            ResetSection {
                                width: parent.width
                                ctl: root
                                controlled: true
                                expanded: root.openRight === "reset"
                                onToggleRequested: root.openRight = expanded ? "" : "reset"
                            }
                        }
                    }
                }
            }
        }
    }
}
