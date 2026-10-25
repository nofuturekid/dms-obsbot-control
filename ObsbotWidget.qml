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
    // Starting the preview on a desktop widget switches this one off, and the other way round
    PreviewClaim {
        id: previewClaim
        pluginId: root.pluginId
        holding: root.previewOn
        onDisplaced: root.previewOn = false
    }
    readonly property bool live: available && awake

    readonly property string statusText: {
        if (!available)
            return toolMissing ? "Control tool not found" : "Not reachable";
        if (pendingLabel !== "")
            return pendingLabel + "…";
        // obsbot4linux 0.4.0: target null while static, detected false while the camera searches
        const searching = cam.target?.detected === false;
        return awake ? "Awake · " + aiMode + (searching ? " · searching" : "") : "Asleep · lens stowed";
    }
    // Any application reading the camera, the widget's own preview included (obsbot4linux 0.3.0)
    // On air: any app streams (obsbot4linux's kernel probe) or our own preview runs. The preview is
    // counted here too: Qt reads the frames without mmap, so obsbot4linux can't name it.
    // A preview of ours also runs on a desktop widget (PreviewClaim shares that between surfaces)
    readonly property bool previewRunning: previewOn || previewClaim.anyRunning
    readonly property bool streaming: cam.streaming === true || previewRunning
    // Names obsbot4linux could see (may be empty, e.g. Chrome's sandbox), plus our preview
    readonly property var streamingApps: (cam.streaming_apps ?? []).filter(a => a !== "qs").concat(previewRunning ? ["qs"] : [])
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

    // The open card of each tab ("" = all closed); opening one closes the other in the same
    // tab, so the popout stays short
    property var openCards: ({})
    function isOpen(id) {
        return openCards[tabOf(id)] === id;
    }
    function toggleOpen(id) {
        const next = Object.assign({}, openCards);
        next[tabOf(id)] = isOpen(id) ? "" : id;
        openCards = next;
    }

    // The right column of the popout is a tab bar; Preview and Framing stay in the left column.
    // Arrange mode of the popout (header button): cards fold up and can be dragged by their grip,
    // within their tab or onto another tab's button. The assignment is saved as card ids per tab
    // in cardTabs. Ids missing there (new cards) join their default tab at the end, unknown ids
    // are dropped. Hidden and unsupported cards keep their slot, they are only not shown.
    property bool arranging: false
    onArrangingChanged: openCards = ({})
    readonly property var tabs: [
        { id: "tracking", text: "Tracking", icon: "track_changes" },
        { id: "picture", text: "Picture", icon: "tune" },
        { id: "device", text: "Device", icon: "settings" }
    ]
    readonly property var defaultTabs: ({
            tracking: ["tracking", "zone"],
            picture: ["picture", "image"],
            device: ["camera", "sleep", "audio", "gestures", "reset"]
        })
    property var cardTabs: defaultTabs
    function tabOf(id) {
        return tabs.find(t => cardTabs[t.id].includes(id))?.id ?? "device";
    }

    // The tab selected in the popout ("" = the saved one); the last click is saved as lastTab
    property string tab: ""
    readonly property string lastTab: pluginData?.lastTab ?? "tracking"
    function selectTab(id, save) {
        tab = id;
        if (save)
            pluginService?.savePluginData(pluginId, "lastTab", id);
    }

    // Replaced only when the assignment really differs, so other plugin settings changing
    // do not rebuild the cards
    function refreshTabs() {
        const known = tabs.reduce((all, t) => all.concat(defaultTabs[t.id]), []);
        const defaultTab = id => tabs.find(t => defaultTabs[t.id].includes(id)).id;
        const next = {};
        const seen = {};
        const take = (t, id) => {
            if (known.includes(id) && !seen[id]) {
                seen[id] = true;
                next[t].push(id);
            }
        };
        for (const t of tabs)
            next[t.id] = [];
        const saved = pluginData?.cardTabs;
        if (saved && typeof saved === "object") {
            for (const t of tabs) {
                for (const id of Array.isArray(saved[t.id]) ? saved[t.id] : [])
                    take(t.id, id);
            }
        } else {
            // Before 0.17.0 the order was saved per column (cardOrderLeft / cardOrderRight): every
            // card goes to its default tab, ordered by its place in its old column (left first on a tie)
            const old = [];
            for (const col of ["Left", "Right"]) {
                const list = pluginData?.["cardOrder" + col];
                (Array.isArray(list) ? list : []).filter(id => known.includes(id)).forEach((id, rank) => old.push({ id: id, rank: rank, col: col }));
            }
            old.sort((x, y) => x.rank - y.rank || (x.col === "Left" ? -1 : 1) - (y.col === "Left" ? -1 : 1));
            for (const e of old)
                take(defaultTab(e.id), e.id);
        }
        for (const t of tabs) {
            for (const id of defaultTabs[t.id])
                take(t.id, id);
        }
        if (JSON.stringify(next) !== JSON.stringify(cardTabs))
            cardTabs = next;
    }
    onPluginDataChanged: refreshTabs()

    // anchorId: the visible card next to the drop position (after it or before it); "" = end of the tab
    function moveCard(id, toTab, anchorId, after) {
        const next = {};
        for (const t of tabs)
            next[t.id] = cardTabs[t.id].filter(c => c !== id);
        next[toTab].splice(anchorId === "" ? next[toTab].length : next[toTab].indexOf(anchorId) + (after ? 1 : 0), 0, id);
        selectTab(toTab, false);
        if (JSON.stringify(next) === JSON.stringify(cardTabs))
            return;
        pluginService?.savePluginData(pluginId, "cardTabs", next);
    }

    // undefined drops the keys from the saved settings (the pre-0.17.0 column orders too)
    function resetLayout() {
        pluginService?.savePluginData(pluginId, "cardTabs", undefined);
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

    // The watcher's `available` drives the bar icon when it should hide without a camera. DMS only
    // fades the pill out, the component and the watch process stay alive, so the icon returns when
    // the camera is plugged in again.
    function applyVisibility() {
        if (hideWithoutCamera)
            setVisibilityOverride(available);
        else
            clearVisibilityOverride();
    }
    onHideWithoutCameraChanged: applyVisibility()
    onAvailableChanged: applyVisibility()
    Component.onCompleted: applyVisibility()

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

    // Layout: the left column (preview, framing) is always there, the right one has the tabs
    // (Tracking | Picture | Device). The preview area stays in place and is black while the
    // preview is off. Cards switched off on the settings page (or not supported by the camera)
    // close up; a tab without cards drops out of the tab bar, and when a column is left without
    // cards the popout narrows to the one column that is left. The popout reports the count.
    property int shownColumns: 2
    // 920 px, but at most 90 % of a small screen (1366 px laptop, scaled displays)
    popoutWidth: shownColumns >= 2 ? Math.min(920, Screen.width > 0 ? Math.round(Screen.width * 0.9) : 920) : 380

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

            // In arrange mode the tabs stay, an empty one is a drop target
            Binding {
                target: root
                property: "shownColumns"
                value: (leftColumn.hasCards ? 1 : 0) + (root.arranging || popout.shownTabs.length > 0 ? 1 : 0)
            }

            // The tabs with cards (all of them while arranging) and the selected one: the last
            // click, else the saved tab, else the first tab that is left
            readonly property var shownTabs: root.tabs.filter(t => root.arranging || tabColumn(t.id).hasCards)
            readonly property string activeTab: {
                const want = root.tab !== "" ? root.tab : root.lastTab;
                return shownTabs.some(t => t.id === want) ? want : (shownTabs[0]?.id ?? "");
            }

            function tabColumn(id) {
                return id === "tracking" ? trackingTab : id === "picture" ? pictureTab : deviceTab;
            }

            // Arrange mode: cards report the pointer while their grip is dragged; `drop` is the
            // insert position (tab, neighbour card, side), shown as a line, applied on release.
            // Over a tab button the card goes to the end of that tab (the button is highlighted).
            readonly property bool arranging: root.arranging
            property var drop: null

            function dragMove(id, scenePos) {
                const b = tabBar.mapFromItem(null, scenePos.x, scenePos.y);
                if (b.x >= 0 && b.x < tabBar.width && b.y >= 0 && b.y < tabBar.height) {
                    const i = Math.min(shownTabs.length - 1, Math.floor(b.x / tabBar.width * shownTabs.length));
                    drop = { tab: shownTabs[i].id, anchorId: "", after: true, bar: true, x: i * tabBar.width / shownTabs.length, width: tabBar.width / shownTabs.length };
                    return;
                }
                const column = tabColumn(activeTab);
                const p = column.mapFromItem(null, scenePos.x, scenePos.y);
                const others = [];
                for (const c of column.children) {
                    if (c.cardId && c.cardId !== id && c.visible)
                        others.push(c);
                }
                const k = others.findIndex(c => p.y < c.y + c.height / 2);
                const before = k >= 0 ? others[k] : null;
                const last = others[others.length - 1];
                const at = column.mapToItem(cols, 0, before ? before.y - column.spacing / 2 : last ? last.y + last.height + column.spacing / 2 : 0);
                drop = {
                    tab: activeTab,
                    anchorId: before ? before.cardId : last ? last.cardId : "",
                    after: !before,
                    bar: false,
                    x: at.x,
                    width: column.width,
                    y: at.y
                };
            }

            function dragEnd(id) {
                const d = drop;
                drop = null;
                if (d)
                    Qt.callLater(() => root.moveCard(id, d.tab, d.anchorId, d.after));
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

                    Item {
                        id: cols
                        width: parent.width
                        height: columnRow.height

                        Row {
                            id: columnRow
                            width: parent.width
                            spacing: leftColumn.hasCards && rightColumn.shown ? Theme.spacingM : 0

                            // Always there: the picture to watch while changing settings
                            Column {
                                id: leftColumn
                                // Column skips hidden cards; without any it drops out
                                readonly property bool hasCards: visibleChildren.length > 0
                                width: !hasCards ? 0 : rightColumn.shown ? (parent.width - parent.spacing) * 0.55 : parent.width
                                spacing: Theme.spacingM

                                PreviewPane {
                                    width: parent.width
                                    visible: root.cardEnabled("Preview")
                                    ctl: root
                                }

                                FramingSection {
                                    width: parent.width
                                    visible: root.cardEnabled("Framing")
                                    ctl: root
                                }
                            }

                            Column {
                                id: rightColumn
                                readonly property bool shown: popout.shownTabs.length > 0
                                width: !shown ? 0 : !leftColumn.hasCards ? parent.width : parent.width - leftColumn.width - parent.spacing
                                spacing: Theme.spacingM

                                DTabBar {
                                    id: tabBar
                                    width: parent.width
                                    model: popout.shownTabs
                                    currentIndex: popout.shownTabs.findIndex(t => t.id === popout.activeTab)
                                    onTabClicked: index => root.selectTab(popout.shownTabs[index].id, true)
                                }

                                // The tabs lie on top of each other and the area is as high as the
                                // tallest one, so the popout does not jump when switching. A tab that is
                                // not selected stays "visible" (the cards' visibility is what counts as
                                // having cards) but is see-through and inert.
                                Item {
                                    id: tabArea
                                    width: parent.width
                                    height: Math.max(trackingTab.height, pictureTab.height, deviceTab.height)

                                    Column {
                                        id: trackingTab
                                        readonly property bool hasCards: visibleChildren.length > 0
                                        width: parent.width
                                        spacing: Theme.spacingM
                                        opacity: popout.activeTab === "tracking" ? 1 : 0
                                        enabled: popout.activeTab === "tracking"

                                        Repeater {
                                            visible: false
                                            model: root.cardTabs.tracking
                                            delegate: cardChooser
                                        }
                                    }

                                    Column {
                                        id: pictureTab
                                        readonly property bool hasCards: visibleChildren.length > 0
                                        width: parent.width
                                        spacing: Theme.spacingM
                                        opacity: popout.activeTab === "picture" ? 1 : 0
                                        enabled: popout.activeTab === "picture"

                                        Repeater {
                                            visible: false
                                            model: root.cardTabs.picture
                                            delegate: cardChooser
                                        }
                                    }

                                    Column {
                                        id: deviceTab
                                        readonly property bool hasCards: visibleChildren.length > 0
                                        width: parent.width
                                        spacing: Theme.spacingM
                                        opacity: popout.activeTab === "device" ? 1 : 0
                                        enabled: popout.activeTab === "device"

                                        Repeater {
                                            visible: false
                                            model: root.cardTabs.device
                                            delegate: cardChooser
                                        }
                                    }
                                }
                            }
                        }

                        // Insert position of the card being dragged
                        Rectangle {
                            visible: popout.drop !== null && !popout.drop.bar
                            x: popout.drop?.x ?? 0
                            y: Math.max(0, (popout.drop?.y ?? 0) - height / 2)
                            width: popout.drop?.width ?? 0
                            height: Theme.spacingXS
                            radius: height / 2
                            color: Theme.primary
                        }

                        // Tab button the card would be dropped on
                        Rectangle {
                            visible: popout.drop?.bar ?? false
                            x: tabBar.mapToItem(cols, popout.drop?.x ?? 0, 0).x
                            y: tabBar.mapToItem(cols, 0, 0).y
                            width: popout.drop?.width ?? 0
                            height: tabBar.height
                            radius: Theme.cornerRadius
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.primary
                        }
                    }
                }
            }

            // One delegate per card id; the repeaters above create them in the saved order
            DelegateChooser {
                id: cardChooser
                role: "modelData"

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
                    roleValue: "zone"
                    ZoneSection {
                        width: parent.width
                        cardId: "zone"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("zone")
                        onToggleRequested: root.toggleOpen("zone")
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
