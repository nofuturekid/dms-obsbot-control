import QtQuick
import QtMultimedia

// Live camera picture. Loaded by URL from PreviewPane, so a missing qt6-multimedia only
// disables the preview instead of breaking the whole popout.
Item {
    id: root

    // camera on; off keeps the device free for other apps
    property bool running: false

    // /dev/videoN of the camera to show (the by-id path from obsbot4linux, resolved)
    property string node: ""

    MediaDevices {
        id: mediaDevices
    }

    CaptureSession {
        camera: Camera {
            cameraDevice: mediaDevices.videoInputs.find(d => String(d.id) === root.node) ?? mediaDevices.defaultVideoInput
            // 720p is plenty for a ~350 px preview and keeps MJPEG decoding cheap
            cameraFormat: cameraDevice.videoFormats.find(f => f.resolution.width === 1280 && f.resolution.height === 720) ?? cameraDevice.videoFormats[0]
            active: root.running
        }
        videoOutput: videoOutput
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        visible: root.running
        fillMode: VideoOutput.PreserveAspectFit
    }
}
