import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // One long-running `t2l watch` is the only link to the camera: its state events are the
    // only source of truth, commands are requests on its stdin. The UI patches `cam`
    // optimistically when a command goes out; the next event overwrites the patch.

    // key = ai_mode in t2l's state, arg = `t2l tracking <arg>`
    readonly property var trackingModes: [
        { label: "Static", arg: "static", key: "static" },
        { label: "Normal Tracking", arg: "normal", key: "normal" },
        { label: "Upper Body", arg: "upper-body", key: "upper_body" },
        { label: "Close-up", arg: "close-up", key: "close_up" },
        { label: "Headless", arg: "headless", key: "headless" },
        { label: "Lower Body", arg: "lower-body", key: "lower_body" },
        { label: "Hand", arg: "hand", key: "hand" },
        { label: "Group", arg: "group", key: "group" }
    ]
    readonly property var speeds: [
        { label: "Standard", arg: "standard" },
        { label: "Sport", arg: "sport" }
    ]

    // Only used to hide the bar pill while the camera is unplugged
    readonly property string device: "/dev/v4l/by-id/usb-Remo_Tech_Co.__Ltd._OBSBOT_Tiny_2_Lite-video-index0"

    readonly property var exposureModes: [
        { label: "Global", arg: "global" },
        { label: "Face", arg: "face" },
        { label: "Custom", arg: "manual" }
    ]
    // Manual exposure (UVC auto_exposure 1): exposure_time and gain then set the brightness
    readonly property bool manualExposure: (image.auto_exposure?.value ?? 0) === 1
    // Settings page: tracking mode applied whenever the camera wakes up ("" = keep)
    readonly property string wakeTrackingMode: pluginData?.wakeTrackingMode ?? ""

    // UVC controls shown as sliders; range and default come from t2l's image.<name>
    readonly property var imageControls: [
        { name: "brightness", label: "Brightness" },
        { name: "contrast", label: "Contrast" },
        { name: "saturation", label: "Saturation" },
        { name: "sharpness", label: "Sharpness" },
        { name: "backlight_compensation", label: "Backlight compensation" }
    ]

    // The state object of the last event, with optimistic patches on top
    property var cam: ({})
    property var truth: ({})
    readonly property var status: cam.status ?? ({})
    readonly property var tracking: cam.tracking ?? ({})
    readonly property var image: cam.image ?? ({})
    readonly property real zoomFactor: cam.zoom?.factor ?? 1
    // Gimbal pose in degrees; positive pan = camera left, positive tilt = up
    readonly property real pan: cam.state?.gimbal?.pan ?? 0
    readonly property real tilt: cam.state?.gimbal?.tilt ?? 0
    readonly property bool imageAtDefaults: imageControls.every(c => (image[c.name]?.value ?? 0) === (image[c.name]?.default ?? 0))

    property bool toolMissing: false
    readonly property bool available: cam.available === true
    readonly property bool awake: available && status.asleep === false
    readonly property string aiMode: trackingModes.find(m => m.key === status.ai_mode)?.label ?? ""
    readonly property string speed: speeds.find(s => s.arg === status.tracking_speed)?.label ?? ""

    function has(name) {
        return (cam.capabilities ?? []).indexOf(name) >= 0;
    }

    // Fine steps: 1° per arrow click instead of 5°
    property bool fineGimbal: false
    readonly property int gimbalStep: fineGimbal ? 1 : 5

    // Label of the command in flight, shown in the header until t2l answers
    property string pendingLabel: ""
    property int pendingId: 0
    property int requestId: 0

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
    }

    signal stateRefreshed

    // The open card of each column of Lite settings ("" = all closed); opening one closes
    // the other in the same column, so the popout stays short
    property string openLeft: ""
    property string openRight: ""

    // changes: { group: { key: value } }; in "image" the value goes into <control>.value
    function patch(changes) {
        const s = Object.assign({}, root.cam);
        for (const group in changes) {
            s[group] = Object.assign({}, s[group]);
            for (const key in changes[group])
                s[group][key] = group === "image" ? Object.assign({}, s.image[key], { value: changes[group][key] }) : changes[group][key];
        }
        root.cam = s;
    }

    // Sliders: events that arrive while the user is still dragging would pull the handle
    // back, so image and zoom of the state stay as dragged until the drag has rested.
    Timer {
        id: dragHold
        interval: 500
        onTriggered: {
            root.cam = root.truth;
            root.stateRefreshed();
        }
    }

    // Sends `t2l <args>` and flips the UI to `changes` at once
    function send(args, label, changes, slider) {
        if (!watch.running)
            return;
        if (changes)
            root.patch(changes);
        if (slider)
            dragHold.restart();
        const id = ++root.requestId;
        if (label) {
            root.pendingId = id;
            root.pendingLabel = label;
        }
        watch.write(JSON.stringify({ id: id, args: args.map(String) }) + "\n");
        root.stateRefreshed();
    }

    function handleLine(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (msg.event === "state") {
            root.onState(msg.state);
        } else if (msg.id !== undefined) {
            if (msg.id === root.pendingId)
                root.pendingLabel = "";
            if (msg.ok === false) {
                console.warn("obsbotControl: t2l:", msg.error);
                // the optimistic change did not happen
                root.cam = root.truth;
                root.stateRefreshed();
            }
        }
    }

    function onState(next) {
        const was = root.truth.status?.asleep;
        root.truth = next;
        if (dragHold.running) {
            const s = Object.assign({}, next);
            s.image = root.cam.image;
            s.zoom = root.cam.zoom;
            root.cam = s;
        } else {
            root.cam = next;
        }
        // Only on a real asleep -> awake change seen in events, not on the first state after a DMS start
        if (was === true && next.status?.asleep === false && root.wakeTrackingMode !== "")
            root.send(["tracking", root.wakeTrackingMode]);
        root.stateRefreshed();
    }

    function setAwake(on) {
        if (!on)
            root.previewOn = false;
        root.send([on ? "wake" : "sleep"], on ? "Waking camera" : "Stowing lens", { status: { asleep: !on } });
    }

    function setMode(index) {
        const mode = root.trackingModes[index];
        root.send(["tracking", mode.arg], "Switching to " + mode.label, { status: { ai_mode: mode.key } });
    }

    function setSpeed(index) {
        const speed = root.speeds[index];
        root.send(["speed", speed.arg], "Setting speed to " + speed.label, { status: { tracking_speed: speed.arg } });
    }

    function setHdr(on) {
        root.send(["hdr", on ? "on" : "off"], on ? "Turning HDR on" : "Turning HDR off", { status: { hdr: on } });
    }

    // The camera restarts and drops off USB for ~20 s; t2l reports it unavailable meanwhile
    function factoryReset() {
        root.previewOn = false;
        root.send(["factory-reset", "--yes"], "Resetting to factory settings");
    }

    function setExposure(index) {
        const mode = root.exposureModes[index];
        const changes = mode.arg === "manual" ? { image: { auto_exposure: 1 } } : { status: { face_auto_exposure: mode.arg === "face" }, image: { auto_exposure: 0 } };
        root.send(["exposure", mode.arg], "Setting exposure to " + mode.label, changes);
    }

    function setControl(name, value) {
        root.send(["image", name, value], "", { image: { [name]: value } }, true);
    }

    function setZoom(factor) {
        root.send(["zoom", factor.toFixed(1)], "", { zoom: { factor: factor } }, true);
    }

    // `t2l gimbal` takes an absolute pose in degrees and switches to Static itself
    function moveGimbal(newPan, newTilt) {
        const p = Math.max(-130, Math.min(130, newPan));
        const t = Math.max(-90, Math.min(90, newTilt));
        root.send(["gimbal", "--pan", p, "--tilt", t], "", { state: { gimbal: { pan: p, tilt: t } }, status: { ai_mode: "static" } });
    }

    function degrees(d) {
        const r = Math.round(d);
        return (r > 0 ? "+" : r < 0 ? "−" : "") + Math.abs(r) + "°";
    }

    // Auto-sleep times offered, the choices of OBSBOT Center
    readonly property var autoSleepTimes: [
        { label: "Off", arg: "off" },
        { label: "30 s", arg: "30" },
        { label: "2 min", arg: "120" },
        { label: "10 min", arg: "600" }
    ]
    function autoSleepIndex() {
        if (status.auto_sleep_enabled === undefined)
            return -1;
        if (!status.auto_sleep_enabled)
            return 0;
        return autoSleepTimes.findIndex(t => t.arg === String(status.auto_sleep_seconds));
    }

    visibilityCommand: "test -e " + device
    visibilityInterval: 5

    Process {
        id: watch
        // Exit code 127 tells "tool not installed" apart from a daemon or camera problem
        command: ["sh", "-c", "command -v t2l >/dev/null || exit 127; exec t2l watch"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }
        onExited: exitCode => {
            root.toolMissing = exitCode === 127;
            root.cam = ({});
            root.truth = ({});
            root.pendingLabel = "";
            root.stateRefreshed();
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: root.toolMissing ? 10000 : 2000
        onTriggered: watch.running = true
    }

    // Retry button: start the watcher again now
    function refresh() {
        if (!watch.running)
            watch.running = true;
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

            Component.onCompleted: root.refresh()

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

                    // Lite settings, collapsed by default so the popout keeps its height
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: root.has("fov")

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
