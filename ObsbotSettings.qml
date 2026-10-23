import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    pluginId: "obsbotControl"

    SelectionSetting {
        settingKey: "wakeTrackingMode"
        label: "Tracking mode on wake"
        description: "Applied whenever the camera wakes up"
        options: [
            { label: "Keep current", value: "" },
            { label: "Static", value: "static" },
            { label: "Normal Tracking", value: "normal" },
            { label: "Upper Body", value: "upper-body" },
            { label: "Close-up", value: "close-up" },
            { label: "Headless", value: "headless" },
            { label: "Lower Body", value: "lower-body" },
            { label: "Desk Mode", value: "desk" },
            { label: "Whiteboard", value: "whiteboard" },
            { label: "Hand", value: "hand" },
            { label: "Group", value: "group" }
        ]
        defaultValue: ""
    }
}
