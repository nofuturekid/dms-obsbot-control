import QtQuick
import QtMultimedia
import qs.Common
import qs.DCommon.Widgets

// Preview switch and a fixed 16:9 frame: live video while the preview runs, otherwise a
// hint with one action (start preview, wake camera, retry when not reachable)
SectionCard {
    id: pane

    property var ctl

    readonly property bool previewShown: ctl.previewOn && ctl.live
    readonly property var hint: !ctl.available
        ? (ctl.toolMissing
            ? { icon: "terminal", title: "Control tool not found", body: "tiny4linux-cli could not be run. Check that it is installed and on PATH.", button: "Retry", buttonIcon: "refresh" }
            : { icon: "usb_off", title: "Camera not connected", body: "The Tiny 2 Lite doesn't respond on USB. Plug it back in. The bar icon hides while it is gone.", button: "Retry", buttonIcon: "refresh" })
        : !ctl.awake
            ? { icon: "videocam_off", title: "Camera is asleep", body: "Lens is stowed face-down. Wake it to preview, track or adjust the picture.", button: "Wake camera", buttonIcon: "videocam" }
            : { icon: "visibility_off", title: "Preview is off", body: "Turn it on to see the picture while you adjust it. While it's on, no other app can use the camera.", button: "Start preview", buttonIcon: "play_arrow" }

    function hintAction() {
        if (!ctl.available)
            ctl.refresh();
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
        color: "black"
        radius: Theme.cornerRadius
        clip: true

        Loader {
            anchors.fill: parent
            active: pane.previewShown && pane.ctl.interactionActive
            sourceComponent: Item {
                MediaDevices {
                    id: mediaDevices
                }

                CaptureSession {
                    camera: Camera {
                        cameraDevice: mediaDevices.videoInputs.find(d => d.description.includes("OBSBOT")) ?? mediaDevices.defaultVideoInput
                        // 720p is plenty for a ~350 px preview and keeps MJPEG decoding cheap
                        cameraFormat: cameraDevice.videoFormats.find(f => f.resolution.width === 1280 && f.resolution.height === 720) ?? cameraDevice.videoFormats[0]
                        active: true
                    }
                    videoOutput: videoOutput
                }

                VideoOutput {
                    id: videoOutput
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
                }
            }
        }

        Column {
            anchors.centerIn: parent
            width: Math.min(280, parent.width - Theme.spacingL * 2)
            spacing: Theme.spacingS
            visible: !pane.previewShown

            DIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: pane.hint.icon
                color: "#9a9a9a"
                size: Theme.iconSizeLarge
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: pane.hint.title
                color: "#e4e4e4"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: pane.hint.body
                color: "#c4c4c4"
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
