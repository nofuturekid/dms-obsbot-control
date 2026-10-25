import QtQuick
import QtMultimedia

// Live camera picture. Loaded by URL from PreviewPane, so a missing qt6-multimedia only
// disables the preview instead of breaking the whole popout.
Item {
    id: root

    // camera on; off keeps the device free for other apps
    property bool running: false

    // true: the Camera object exists only while running (desktop widget, which stays loaded:
    // Qt keeps the device busy after `active: false` until the Camera is destroyed). false: it is
    // created up front for an instant start; the popout destroys it anyway when it closes.
    property bool releaseOnStop: false

    // /dev/videoN of the camera to show (the by-id path from obsbot4linux, resolved)
    property string node: ""

    // When another preview (popout / desktop widget) hands the camera over, it may still hold the
    // device for a moment and the first start fails: retry a few times instead of staying black.
    property bool restarting: false
    property int retries: 0
    onRunningChanged: retries = 0

    Timer {
        id: retryTimer
        interval: 300
        onTriggered: root.restarting = false
    }

    MediaDevices {
        id: mediaDevices
    }

    Loader {
        id: session
        anchors.fill: parent
        active: root.releaseOnStop ? root.running && !root.restarting : true
        sourceComponent: Item {
            CaptureSession {
                camera: Camera {
                    cameraDevice: mediaDevices.videoInputs.find(d => String(d.id) === root.node) ?? mediaDevices.defaultVideoInput
                    // 720p is plenty for a ~350 px preview and keeps MJPEG decoding cheap
                    cameraFormat: cameraDevice.videoFormats.find(f => f.resolution.width === 1280 && f.resolution.height === 720) ?? cameraDevice.videoFormats[0]
                    active: root.running && !root.restarting
                    // Not from inside the signal (binding loop): retry a moment later, the other
                    // preview may still be releasing the device
                    onErrorOccurred: (error, errorString) => {
                        console.warn("obsbotControl: preview camera:", errorString, "- retry", root.retries + 1);
                        if (!root.running || root.retries >= 10)
                            return;
                        root.retries++;
                        Qt.callLater(() => {
                            root.restarting = true;
                            retryTimer.restart();
                        });
                    }
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
}
