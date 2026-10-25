import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // One long-running `obsbot4linux watch` is the only link to the camera: its state events are the
    // only source of truth, commands are requests on its stdin. The UI patches `cam`
    // optimistically when a command goes out; the next event overwrites the patch.

    // key = ai_mode in obsbot4linux's state, arg = `obsbot4linux tracking <arg>`
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

    readonly property var exposureModes: [
        { label: "Global", arg: "global" },
        { label: "Face", arg: "face" },
        { label: "Custom", arg: "manual" }
    ]
    // Manual exposure (UVC auto_exposure 1): exposure_time and gain then set the brightness
    readonly property bool manualExposure: (image.auto_exposure?.value ?? 0) === 1
    // Settings page: tracking mode applied whenever the camera wakes up ("" = keep)
    readonly property string wakeTrackingMode: pluginData?.wakeTrackingMode ?? ""
    // Settings page: the pill's mouse wheel zooms, its middle click toggles tracking
    readonly property bool wheelZoom: pluginData?.wheelZoom ?? true
    readonly property bool middleClickTracking: pluginData?.middleClickTracking ?? true
    // Settings page: hide the bar icon while no supported camera is plugged in (default: show it dimmed)
    readonly property bool hideWithoutCamera: pluginData?.hideWithoutCamera ?? false
    // Last tracking mode other than Static (ai_mode key), what the middle click goes back to
    readonly property string lastTrackingMode: pluginData?.lastTrackingMode ?? "normal"

    // UVC controls shown as sliders; range and default come from obsbot4linux's image.<name>
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
    // live pose (follows AI tracking), else the last pose obsbot4linux set
    readonly property real pan: cam.pose?.pan ?? cam.state?.gimbal?.pan ?? 0
    readonly property real tilt: cam.pose?.tilt ?? cam.state?.gimbal?.tilt ?? 0
    readonly property bool imageAtDefaults: imageControls.every(c => (image[c.name]?.value ?? 0) === (image[c.name]?.default ?? 0))

    // Camera model and V4L2 by-id path, both null in the state while no supported camera is there
    readonly property string model: cam.model ?? ""
    readonly property string device: cam.device ?? ""
    // /dev/videoN behind `device`, what Qt Multimedia calls the camera's id
    property string videoNode: ""
    readonly property bool previewReady: device !== "" && videoNode !== ""
    onDeviceChanged: {
        videoNode = "";
        if (device === "")
            return;
        const wanted = device;
        Proc.runCommand("obsbotControl.videoNode", ["readlink", "-f", wanted], (stdout, exitCode) => {
            if (exitCode === 0 && root.device === wanted)
                root.videoNode = stdout.trim();
        });
    }

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

    // Label of the command in flight, shown in the header until obsbot4linux answers
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
    // Any application reading the camera, the widget's own preview included (obsbot4linux 0.3.0)
    // On air: any app streams (obsbot4linux's kernel probe) or our own preview runs. The preview is
    // counted here too: Qt reads the frames without mmap, so obsbot4linux can't name it.
    readonly property bool streaming: cam.streaming === true || previewOn
    // Names obsbot4linux could see (may be empty, e.g. Chrome's sandbox), plus our preview
    readonly property var streamingApps: (cam.streaming_apps ?? []).filter(a => a !== "qs").concat(previewOn ? ["qs"] : [])
    readonly property var appNames: ({
            "qs": "preview",
            "chrome": "Chrome",
            "chromium": "Chrome",
            "firefox": "Firefox",
            "obs": "OBS"
        })

    readonly property string baseSummary: (model !== "" ? model : "OBSBOT camera") + " · " + statusText
    // Header and pill tooltip show this line
    readonly property string summary: baseSummary + (streaming ? " · On air" + (streamingApps.length > 0 ? ": " + streamingApps.map(a => appNames[a] ?? a).join(", ") : "") : "")

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

    // Sends `obsbot4linux <args>` and flips the UI to `changes` at once
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
                console.warn("obsbotControl: obsbot4linux:", msg.error);
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
        const mode = next.status?.ai_mode;
        if (mode && mode !== "static" && mode !== root.lastTrackingMode)
            root.pluginService?.savePluginData(root.pluginId, "lastTrackingMode", mode);
        root.stateRefreshed();
    }

    function setAwake(on) {
        if (!on)
            root.previewOn = false;
        root.send([on ? "wake" : "sleep"], on ? "Waking camera" : "Stowing lens", { status: { asleep: !on } });
    }

    function toggleAwake() {
        if (root.available)
            root.setAwake(!root.awake);
    }

    // Middle click: Static <-> the last other mode
    function toggleTracking() {
        if (!root.available)
            return;
        const target = status.ai_mode === "static" ? root.lastTrackingMode : "static";
        const index = root.trackingModes.findIndex(m => m.key === target);
        root.setMode(index < 0 ? 1 : index);
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

    // The camera restarts and drops off USB for ~20 s; obsbot4linux reports it unavailable meanwhile
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
        root.send(["zoom", factor.toFixed(2)], "", { zoom: { factor: factor } }, true);
    }

    // Mouse wheel: 0.1 per notch within 1.0-4.0, the range `obsbot4linux zoom` accepts
    function stepZoom(notches) {
        const next = Math.max(1, Math.min(4, Math.round((root.zoomFactor + notches * 0.1) * 100) / 100));
        if (next !== root.zoomFactor)
            root.setZoom(next);
    }

    // `obsbot4linux gimbal` takes an absolute pose in degrees and switches to Static itself
    function moveGimbal(newPan, newTilt) {
        const p = Math.max(-130, Math.min(130, newPan));
        const t = Math.max(-90, Math.min(90, newTilt));
        root.send(["gimbal", "--pan", p, "--tilt", t], "", { state: { gimbal: { pan: p, tilt: t } }, pose: { pan: p, tilt: t }, status: { ai_mode: "static" } });
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

    // Exit 0 while a camera obsbot4linux supports is plugged in; enumerates only, no daemon.
    // Only used when the icon should hide without a camera; an empty command keeps it visible.
    visibilityCommand: hideWithoutCamera ? "obsbot4linux detect >/dev/null" : ""
    visibilityInterval: 5

    Process {
        id: watch
        // Exit code 127 tells "tool not installed" apart from a daemon or camera problem
        command: ["sh", "-c", "command -v obsbot4linux >/dev/null || exit 127; exec obsbot4linux watch"]
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

    // The bar draws the pill; plugins only provide the content (same as the built-in widgets).
    // Right click is sleep/wake; left click opens the popout.
    horizontalBarPill: Component {
        PillContent {
            ctl: root
        }
    }

    verticalBarPill: Component {
        PillContent {
            ctl: root
        }
    }
    pillRightClickAction: () => root.toggleAwake()

    // Control Center tile: the icon toggles sleep/wake. Larger tiles and the detail page show
    // the tracking card. Control Center runs its own instance of this component.
    ccWidgetIcon: !root.available ? "usb_off" : root.live ? "videocam" : "videocam_off"
    ccWidgetPrimaryText: "OBSBOT Control"
    ccWidgetSecondaryText: root.baseSummary + (root.streaming ? " · On air" : "")
    ccWidgetIsActive: root.awake
    onCcWidgetToggled: root.toggleAwake()
    ccExpandedMinimumHeight: Theme.listItemHeight * 3.5
    ccExpandedContent: Component {
        CcTileContent {
            clip: true

            TrackingSection {
                width: parent.width
                ctl: root
                flat: true
                compact: true
                title: ""
            }
        }
    }
    ccDetailHeight: Theme.listItemHeight * 6
    ccDetailContent: Component {
        Item {
            TrackingSection {
                width: parent.width
                ctl: root
            }
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

                    // Two independent columns; every card is as high as its content and
                    // follows the one above it directly
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            id: leftColumn
                            width: (parent.width - parent.spacing) / 2
                            spacing: Theme.spacingM

                            PreviewPane {
                                width: parent.width
                                ctl: root
                            }

                            FramingSection {
                                width: parent.width
                                ctl: root
                            }

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
                        }

                        Column {
                            width: parent.width - leftColumn.width - parent.spacing
                            spacing: Theme.spacingM

                            TrackingSection {
                                width: parent.width
                                ctl: root
                            }

                            PictureSection {
                                width: parent.width
                                ctl: root
                            }

                            ImageSection {
                                width: parent.width
                                ctl: root
                                controlled: true
                                expanded: root.openRight === "image"
                                onToggleRequested: root.openRight = expanded ? "" : "image"
                            }

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
