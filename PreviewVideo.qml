import QtQuick
import QtMultimedia

// Live camera picture. Loaded by URL from PreviewPane, so a missing qt6-multimedia only
// disables the preview instead of breaking the whole popout.
Item {
    id: root

    // camera on; off keeps the device free for other apps
    property bool running: false

    MediaDevices {
        id: mediaDevices
    }

    CaptureSession {
        camera: Camera {
            cameraDevice: mediaDevices.videoInputs.find(d => d.description.includes("OBSBOT")) ?? mediaDevices.defaultVideoInput
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
