import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Gesture switches and how far the zoom gesture zooms in
SectionCard {
    id: section

    property var ctl

    // label shown, CLI argument, label printed by `info`
    readonly property var gestures: [
        { label: "Target lock", arg: "target-lock", key: "Gesture: Target Lock" },
        { label: "Zoom", arg: "zoom", key: "Gesture: Zoom" },
        { label: "Dynamic zoom", arg: "dynamic-zoom", key: "Gesture: Dynamic Zoom" },
        { label: "Direction change", arg: "direction", key: "Gesture: Direction Change" }
    ]
    readonly property int onCount: gestures.filter(g => ctl.liteValue(g.key) === "On").length

    title: "Gestures"
    collapsible: true
    expanded: false
    visible: ctl.has("gesture")
    summary: onCount + " of " + gestures.length + " on"
    enabled: ctl.live
    opacity: ctl.live ? 1 : 0.38

    Repeater {
        model: section.gestures

        ToggleRow {
            required property var modelData
            width: parent.width
            label: modelData.label
            checked: section.ctl.liteValue(modelData.key) === "On"
            onToggled: checked => section.ctl.setLite(["gesture", modelData.arg, checked ? "on" : "off"], (checked ? "Turning on " : "Turning off ") + modelData.label.toLowerCase() + " gesture", modelData.key, checked ? "On" : "Off")
        }
    }

    // Tenths of the ratio, 1.0 to 4.0; sent once the slider rests, not on every step
    LabeledSlider {
        width: parent.width
        label: "Zoom gesture ratio"
        minimum: 10
        maximum: 40
        value: Math.round(Number(section.ctl.liteValue("Gesture Zoom Ratio") || 2) * 10)
        formatValue: v => (v / 10).toFixed(1) + "×"
        onMoved: value => {
            ratioTimer.ratio = value / 10;
            ratioTimer.restart();
        }
    }

    Timer {
        id: ratioTimer
        property real ratio: 2
        interval: 400
        onTriggered: section.ctl.setLite(["gesture", "zoom-ratio", ratio.toFixed(1)], "Setting zoom gesture ratio to " + ratio.toFixed(1) + "×", "Gesture Zoom Ratio", ratio.toFixed(1))
    }
}
