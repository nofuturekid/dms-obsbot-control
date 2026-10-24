import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Preview switch and a fixed 16:9 frame: live video while the preview runs, otherwise a
// hint with one action (start preview, wake camera, retry when not reachable). Hovering the
// running video shows the same kind of hint over it, with a button to stop the preview.
SectionCard {
    id: pane

    property var ctl

    // Without qt6-multimedia PreviewVideo.qml fails to load; the frame then says so
    readonly property bool videoMissing: videoLoader.status === Loader.Error
    readonly property bool previewShown: ctl.previewOn && ctl.live && !videoMissing
    readonly property bool overlayShown: !previewShown || frameHover.hovered
    readonly property var hint: previewShown
        ? { icon: "visibility", title: "Preview is on", body: "No other app can use the camera while it's on. Stop it before a call.", button: "Stop preview", buttonIcon: "stop" }
        : !ctl.available
        ? (ctl.toolMissing
            ? { icon: "terminal", title: "Control tool not found", body: "t2l could not be run. Check that it is installed and on PATH.", button: "Retry", buttonIcon: "refresh" }
            : { icon: "usb_off", title: "Camera not connected", body: "The Tiny 2 Lite doesn't respond on USB. Plug it back in. The bar icon hides while it is gone.", button: "Retry", buttonIcon: "refresh" })
        : videoMissing
            ? { icon: "extension_off", title: "Preview unavailable", body: "The live preview needs qt6-multimedia. All other controls work without it.", button: "Stop preview", buttonIcon: "stop" }
        : !ctl.awake
            ? { icon: "videocam_off", title: "Camera is asleep", body: "Lens is stowed face-down. Wake it to preview, track or adjust the picture.", button: "Wake camera", buttonIcon: "videocam" }
            : { icon: "visibility_off", title: "Preview is off", body: "Turn it on to see the picture while you adjust it. While it's on, no other app can use the camera.", button: "Start preview", buttonIcon: "play_arrow" }

    function hintAction() {
        if (previewShown)
            ctl.previewOn = false;
        else if (!ctl.available)
            ctl.refresh();
        else if (videoMissing)
            ctl.previewOn = false;
        else if (!ctl.awake)
            ctl.setAwake(true);
        else
            ctl.previewOn = true;
    }

    ToggleRow {
        width: parent.width
        enabled: pane.ctl.live
        opacity: pane.ctl.live ? 1 : 0.38
        label: "Preview"
        // Same length either way, so switching doesn't reflow the card and move the picture
        description: pane.ctl.previewOn ? "Camera blocked for other apps" : "Camera free for other apps"
        checked: pane.ctl.previewOn
        onToggled: checked => pane.ctl.previewOn = checked
    }

    Rectangle {
        width: parent.width
        height: width * 9 / 16
        color: Theme.surfaceContainerLowest
        radius: Theme.cornerRadius
        clip: true

        Loader {
            id: videoLoader
            anchors.fill: parent
            active: pane.ctl.previewOn && pane.ctl.live && pane.ctl.interactionActive
            source: Qt.resolvedUrl("PreviewVideo.qml")
        }

        HoverHandler {
            id: frameHover
        }

        // Dims the video under the hint while hovering
        Rectangle {
            anchors.fill: parent
            visible: pane.previewShown && pane.overlayShown
            color: Theme.withAlpha(Theme.surfaceContainerLowest, 0.75)
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - Theme.spacingXL * 2
            spacing: Theme.spacingS
            visible: pane.overlayShown

            DIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: pane.hint.icon
                color: Theme.surfaceVariantText
                size: Theme.iconSizeLarge
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: pane.hint.title
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: pane.hint.body
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }

            DButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pane.hint.button
                iconName: pane.hint.buttonIcon
                onClicked: pane.hintAction()
            }
        }
    }
}
