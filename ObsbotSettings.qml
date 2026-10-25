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
            { label: "Hand", value: "hand" },
            { label: "Group", value: "group" }
        ]
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "wheelZoom"
        label: "Mouse wheel zooms"
        description: "Scrolling over the bar icon changes the zoom by 0.1 per notch"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "middleClickTracking"
        label: "Middle click toggles tracking"
        description: "Switches between Static and the last tracking mode; right click always wakes or sleeps the camera"
        defaultValue: true
    }
}
