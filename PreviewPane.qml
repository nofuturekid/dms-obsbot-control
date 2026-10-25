import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets

// Fixed 16:9 frame: live video while the preview runs, otherwise a
// hint with one action (start preview, wake camera, retry when not reachable). Hovering the
// running video shows the same kind of hint over it, with a button to stop the preview.
SectionCard {
    id: pane

    property var ctl

    title: "Preview"

    // Without qt6-multimedia PreviewVideo.qml fails to load; the frame then says so
    readonly property bool videoMissing: videoLoader.status === Loader.Error
    readonly property bool previewShown: ctl.previewOn && ctl.live && !videoMissing
    readonly property bool overlayShown: !previewShown || frameHover.hovered
    readonly property var hint: previewShown
        ? { icon: "visibility", title: "Preview is on", body: "No other app can use the camera while it's on. Stop it before a call.", button: "Stop preview", buttonIcon: "stop" }
        : !ctl.available
        ? (ctl.toolMissing
            ? { icon: "terminal", title: "Control tool not found", body: "obsbot4linux could not be run. Check that it is installed and on PATH.", button: "Retry", buttonIcon: "refresh" }
            : { icon: "usb_off", title: "Camera not connected", body: "The camera doesn't respond on USB. Plug it back in.", button: "Retry", buttonIcon: "refresh" })
        : videoMissing
            ? { icon: "extension_off", title: "Preview unavailable", body: "The live preview needs qt6-multimedia. All other controls work without it.", button: "Stop preview", buttonIcon: "stop" }
        : !ctl.awake
            ? { icon: "videocam_off", title: "Camera is asleep", body: "Lens is stowed face-down. Wake it to preview, track or adjust the picture.", button: "Wake camera", buttonIcon: "videocam" }
        : !ctl.previewReady
            ? { icon: "hourglass_empty", title: "Waiting for the camera", body: "The preview starts once the camera's video device is known.", button: "", buttonIcon: "" }
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
        else if (ctl.previewReady)
            ctl.previewOn = true;
    }

    // ClippingRectangle: plain clip cuts square corners into the video
    ClippingRectangle {
        width: parent.width
        height: width * 9 / 16
        color: Theme.surfaceContainerLowest
        radius: Theme.cornerRadius

        // Loaded in the background as soon as the popout opens (Qt Multimedia takes ~2 s to
        // load), so starting the preview only switches the camera on
        Loader {
            id: videoLoader
            anchors.fill: parent
            active: pane.ctl.interactionActive
            asynchronous: true
            source: Qt.resolvedUrl("PreviewVideo.qml")
        }

        Binding {
            target: videoLoader.item
            property: "node"
            value: pane.ctl.videoNode
            when: videoLoader.status === Loader.Ready
        }

        Binding {
            target: videoLoader.item
            property: "running"
            value: pane.ctl.previewOn && pane.ctl.live
            when: videoLoader.status === Loader.Ready
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
                visible: pane.hint.button !== ""
                text: pane.hint.button
                iconName: pane.hint.buttonIcon
                onClicked: pane.hintAction()
            }
        }
    }
}
