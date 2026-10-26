import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Desktop surface of the plugin: the camera preview as a free-standing widget, with the same
// start/stop overlay as the popout (PreviewFrame). Nothing here starts the preview by itself.
//
// This surface runs its own `obsbot4linux watch` (the bar widget, the Control Center tile and
// the popout are separate objects; the state is not shared between surfaces, only the
// "who runs a preview" flag, see PreviewClaim).
DesktopPluginComponent {
    id: root

    // Geometry defaults and limits: 16:9, the smallest size still shows icon, title and button
    readonly property real defaultWidth: 480
    readonly property real defaultHeight: 270
    minWidth: 240
    minHeight: 135

    // DMS unloads desktop widgets while the desktop is being edited, but the editor shows its own
    // copy of them: that one is inert
    readonly property bool editing: DesktopWidgetRegistry.editing

    // Camera state from obsbot4linux watch, same fields as the popout reads
    property var cam: ({})
    property bool toolMissing: false
    property string videoNode: ""
    property bool previewOn: false
    property int requestId: 0

    readonly property bool available: cam.available === true
    readonly property bool awake: available && cam.status?.asleep === false
    readonly property bool live: available && awake
    readonly property string device: cam.device ?? ""
    readonly property bool previewReady: device !== "" && videoNode !== ""
    // Loads Qt Multimedia; not while editing
    readonly property bool interactionActive: !editing

    // Stop rules: whenever the picture cannot be live any more (camera asleep, unplugged, lost),
    // and while editing. DMS also unloads the widget when it is disabled or removed, which
    // closes the camera. Otherwise the preview keeps running until the user stops it.
    onLiveChanged: {
        if (!live)
            previewOn = false;
    }
    onEditingChanged: {
        if (editing)
            previewOn = false;
    }

    onDeviceChanged: {
        videoNode = "";
        if (device === "")
            return;
        const wanted = device;
        // No id: Proc debounces per id and keeps only the last callback, so a shared id would
        // leave every instance but the last (one per screen) without its video node
        Proc.runCommand(null, ["readlink", "-f", wanted], (stdout, exitCode) => {
            if (exitCode === 0 && root.device === wanted)
                root.videoNode = stdout.trim();
        });
    }

    function setAwake(on) {
        if (!watch.running)
            return;
        if (!on)
            previewOn = false;
        watch.write(JSON.stringify({ id: ++root.requestId, args: [on ? "wake" : "sleep"] }) + "\n");
    }

    // Retry button: start the watcher again now
    function refresh() {
        if (!watch.running)
            watch.running = true;
    }

    function handleLine(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (msg.event === "state")
            root.cam = msg.state;
        else if (msg.id !== undefined && msg.ok === false)
            console.warn("obsbotControl: obsbot4linux:", msg.error);
    }

    // One preview at a time: starting one in the popout switches this one off and vice versa
    PreviewClaim {
        pluginId: root.pluginId
        holding: root.previewOn
        onDisplaced: root.previewOn = false
    }

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
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: root.toolMissing ? 10000 : 2000
        onTriggered: watch.running = true
    }

    PreviewFrame {
        // stays loaded on the desktop: free the device whenever the preview stops
        releaseOnStop: true
        id: frame
        anchors.fill: parent
        ctl: root
        interactive: !root.editing
        dropBodyWhenTight: true

        // On air while the picture is live (the hover overlay keeps it visible)
        Rectangle {
            visible: frame.previewShown
            width: Theme.spacingM
            height: width
            radius: width / 2
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingS
            color: Theme.error
        }
    }
}
