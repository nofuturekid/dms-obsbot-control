import QtQuick
import QtQuick.Window
import QtQml.Models
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
    // Settings page: short status text next to the bar icon (horizontal bars only), off by default
    readonly property bool statusTextInBar: pluginData?.statusTextInBar ?? false
    // Settings page: one switch per popout card, all on by default. Popout only; the bar icon
    // and the Control Center tile do not look at them.
    function cardEnabled(card) {
        return pluginData?.["card" + card] ?? true;
    }
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

    // Bar pill text: tracking state while awake, "Asleep", "Offline" without a camera
    readonly property string pillText: !available ? "Offline" : !awake ? "Asleep" : status.ai_mode === "static" ? "Static" : "Tracking"

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
        if (!interactionActive) {
            previewOn = false;
            arranging = false;
        }
    }

    signal stateRefreshed

    // The open card of each column of Lite settings ("" = all closed); opening one closes
    // the other in the same column, so the popout stays short
    property string openLeft: ""
    property string openRight: ""
    function columnOf(id) {
        return cardOrder.Left.includes(id) ? "Left" : "Right";
    }
    function isOpen(id) {
        return (columnOf(id) === "Left" ? openLeft : openRight) === id;
    }
    function toggleOpen(id) {
        const next = isOpen(id) ? "" : id;
        if (columnOf(id) === "Left")
            openLeft = next;
        else
            openRight = next;
    }

    // Arrange mode of the popout (header button): cards fold up and can be dragged by their grip.
    // The order is saved per column as card ids in cardOrderLeft / cardOrderRight. Ids missing
    // there (new cards) join their default column at the end, unknown ids are dropped. Hidden and
    // unsupported cards keep their slot in the order, they are only not shown.
    property bool arranging: false
    onArrangingChanged: {
        openLeft = "";
        openRight = "";
    }
    readonly property var defaultOrder: ({
            Left: ["preview", "framing", "camera", "sleep"],
            Right: ["tracking", "picture", "image", "audio", "gestures", "reset"]
        })
    property var cardOrder: defaultOrder
    // Replaced only when the order really differs, so other plugin settings changing
    // do not rebuild the cards
    function refreshOrder() {
        const known = defaultOrder.Left.concat(defaultOrder.Right);
        const seen = {};
        const next = { Left: [], Right: [] };
        for (const col of ["Left", "Right"]) {
            const saved = pluginData?.["cardOrder" + col];
            for (const id of Array.isArray(saved) ? saved : []) {
                if (known.includes(id) && !seen[id]) {
                    seen[id] = true;
                    next[col].push(id);
                }
            }
        }
        for (const col of ["Left", "Right"])
            next[col].push(...defaultOrder[col].filter(id => !seen[id]));
        if (JSON.stringify(next) !== JSON.stringify(cardOrder))
            cardOrder = next;
    }
    onPluginDataChanged: refreshOrder()

    // anchorId: the visible card next to the drop position (after it or before it); "" = empty column
    function moveCard(id, col, anchorId, after) {
        const next = { Left: cardOrder.Left.filter(c => c !== id), Right: cardOrder.Right.filter(c => c !== id) };
        next[col].splice(anchorId === "" ? next[col].length : next[col].indexOf(anchorId) + (after ? 1 : 0), 0, id);
        if (JSON.stringify(next) === JSON.stringify(cardOrder))
            return;
        pluginService?.savePluginData(pluginId, "cardOrderLeft", next.Left);
        pluginService?.savePluginData(pluginId, "cardOrderRight", next.Right);
    }

    // undefined drops the keys from the saved settings
    function resetLayout() {
        pluginService?.savePluginData(pluginId, "cardOrderLeft", undefined);
        pluginService?.savePluginData(pluginId, "cardOrderRight", undefined);
    }

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

    // Layout 1b: two columns (picture | behaviour); the preview area stays in place and is
    // black while the preview is off. Cards switched off on the settings page (or not
    // supported by the camera) close up; a column left without cards drops out and the
    // popout narrows to the one column that is left. The popout reports the count.
    property int shownColumns: 2
    popoutWidth: shownColumns >= 2 ? 760 : 380

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

            // In arrange mode both columns stay, an empty one is a drop target
            Binding {
                target: root
                property: "shownColumns"
                value: root.arranging ? 2 : (leftColumn.hasCards ? 1 : 0) + (rightColumn.hasCards ? 1 : 0)
            }

            // Arrange mode: cards report the pointer while their grip is dragged; `drop` is the
            // insert position (column, neighbour card, side), shown as a line, applied on release
            readonly property bool arranging: root.arranging
            property var drop: null

            function dragMove(id, scenePos) {
                const p = cols.mapFromItem(null, scenePos.x, scenePos.y);
                const column = p.x < rightColumn.x - columnRow.spacing / 2 ? leftColumn : rightColumn;
                const others = [];
                for (const c of column.children) {
                    if (c.cardId && c.cardId !== id && c.visible)
                        others.push(c);
                }
                const k = others.findIndex(c => p.y < c.y + c.height / 2);
                const before = k >= 0 ? others[k] : null;
                const last = others[others.length - 1];
                drop = {
                    col: column === leftColumn ? "Left" : "Right",
                    anchorId: before ? before.cardId : last ? last.cardId : "",
                    after: !before,
                    x: column.x,
                    width: column.width,
                    y: before ? before.y - column.spacing / 2 : last ? last.y + last.height + column.spacing / 2 : 0
                };
            }

            function dragEnd(id) {
                const d = drop;
                drop = null;
                if (d)
                    Qt.callLater(() => root.moveCard(id, d.col, d.anchorId, d.after));
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

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: root.arranging

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - resetButton.width - parent.spacing
                            text: "Drag a card by its handle to move it."
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }

                        DButton {
                            id: resetButton
                            text: "Reset layout"
                            iconName: "restart_alt"
                            onClicked: root.resetLayout()
                        }
                    }

                    // Two independent columns; every card is as high as its content and
                    // follows the one above it directly
                    Item {
                        id: cols
                        width: parent.width
                        height: columnRow.height

                        Row {
                            id: columnRow
                            width: parent.width
                            spacing: (leftColumn.hasCards || root.arranging) && (rightColumn.hasCards || root.arranging) ? Theme.spacingM : 0

                            Column {
                                id: leftColumn
                                // Column skips hidden cards; without any it drops out
                                readonly property bool hasCards: visibleChildren.length > 0
                                readonly property bool shown: hasCards || root.arranging
                                width: !shown ? 0 : rightColumn.shown ? (parent.width - parent.spacing) / 2 : parent.width
                                spacing: Theme.spacingM

                                Repeater {
                                    visible: false
                                    model: root.cardOrder.Left
                                    delegate: cardChooser
                                }
                            }

                            Column {
                                id: rightColumn
                                readonly property bool hasCards: visibleChildren.length > 0
                                readonly property bool shown: hasCards || root.arranging
                                width: !shown ? 0 : leftColumn.shown ? parent.width - leftColumn.width - parent.spacing : parent.width
                                spacing: Theme.spacingM

                                Repeater {
                                    visible: false
                                    model: root.cardOrder.Right
                                    delegate: cardChooser
                                }
                            }
                        }

                        // Insert position of the card being dragged
                        Rectangle {
                            visible: popout.drop !== null
                            x: popout.drop?.x ?? 0
                            y: Math.max(0, (popout.drop?.y ?? 0) - height / 2)
                            width: popout.drop?.width ?? 0
                            height: Theme.spacingXS
                            radius: height / 2
                            color: Theme.primary
                        }
                    }
                }
            }

            // One delegate per card id; the repeaters above create them in the saved order
            DelegateChooser {
                id: cardChooser
                role: "modelData"

                DelegateChoice {
                    roleValue: "preview"
                    PreviewPane {
                        width: parent.width
                        cardId: "preview"
                        arranger: popout
                        visible: root.cardEnabled("Preview")
                        ctl: root
                    }
                }

                DelegateChoice {
                    roleValue: "framing"
                    FramingSection {
                        width: parent.width
                        cardId: "framing"
                        arranger: popout
                        visible: root.cardEnabled("Framing")
                        ctl: root
                    }
                }

                DelegateChoice {
                    roleValue: "camera"
                    CameraSection {
                        width: parent.width
                        cardId: "camera"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("camera")
                        onToggleRequested: root.toggleOpen("camera")
                    }
                }

                DelegateChoice {
                    roleValue: "sleep"
                    SleepSection {
                        width: parent.width
                        cardId: "sleep"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("sleep")
                        onToggleRequested: root.toggleOpen("sleep")
                    }
                }

                DelegateChoice {
                    roleValue: "tracking"
                    TrackingSection {
                        width: parent.width
                        cardId: "tracking"
                        arranger: popout
                        visible: root.cardEnabled("Tracking")
                        ctl: root
                    }
                }

                DelegateChoice {
                    roleValue: "picture"
                    PictureSection {
                        width: parent.width
                        cardId: "picture"
                        arranger: popout
                        visible: root.cardEnabled("Picture")
                        ctl: root
                    }
                }

                DelegateChoice {
                    roleValue: "image"
                    ImageSection {
                        width: parent.width
                        cardId: "image"
                        arranger: popout
                        visible: root.cardEnabled("Image")
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("image")
                        onToggleRequested: root.toggleOpen("image")
                    }
                }

                DelegateChoice {
                    roleValue: "audio"
                    AudioSection {
                        width: parent.width
                        cardId: "audio"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("audio")
                        onToggleRequested: root.toggleOpen("audio")
                    }
                }

                DelegateChoice {
                    roleValue: "gestures"
                    GestureSection {
                        width: parent.width
                        cardId: "gestures"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("gestures")
                        onToggleRequested: root.toggleOpen("gestures")
                    }
                }

                DelegateChoice {
                    roleValue: "reset"
                    ResetSection {
                        width: parent.width
                        cardId: "reset"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("reset")
                        onToggleRequested: root.toggleOpen("reset")
                    }
                }
            }
        }
    }
}
