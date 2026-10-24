import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Microphone processing. Turning the microphone off is left to the CLI: it restarts the camera.
SectionCard {
    id: section

    property var ctl

    readonly property var levels: ["Off", "Weak", "Medium", "Strong"]
    readonly property var distances: ["Near", "Standard", "Far"]

    title: "Audio"
    collapsible: true
    expanded: false
    visible: ctl.has("audio")
    summary: ctl.liteValue("Noise Reduction") !== "" ? "Noise reduction " + ctl.liteValue("Noise Reduction").toLowerCase() : ""
    enabled: ctl.live
    opacity: ctl.live ? 1 : 0.38

    ChipRow {
        id: levelRow
        width: parent.width
        label: "Noise reduction"
        stacked: true
        options: section.levels
        currentIndex: section.levels.indexOf(section.ctl.liteValue("Noise Reduction"))
        onSelected: index => section.ctl.setLite(["audio", "noise-reduction", section.levels[index].toLowerCase()], "Setting noise reduction to " + section.levels[index], "Noise Reduction", section.levels[index])
    }

    ChipRow {
        id: distanceRow
        width: parent.width
        label: "Pickup distance"
        options: section.distances
        currentIndex: section.distances.indexOf(section.ctl.liteValue("Pickup Distance"))
        onSelected: index => section.ctl.setLite(["audio", "pickup-distance", section.distances[index].toLowerCase()], "Setting pickup distance to " + section.distances[index], "Pickup Distance", section.distances[index])
    }

    ToggleRow {
        width: parent.width
        label: "Automatic gain"
        checked: section.ctl.liteValue("Automatic Gain") === "On"
        onToggled: checked => section.ctl.setLite(["audio", "auto-gain", checked ? "on" : "off"], checked ? "Turning automatic gain on" : "Turning automatic gain off", "Automatic Gain", checked ? "On" : "Off")
    }

    ToggleRow {
        width: parent.width
        label: "Microphone while asleep"
        checked: section.ctl.liteValue("Microphone while asleep") === "On"
        onToggled: checked => section.ctl.setLite(["audio", "mic-in-sleep", checked ? "on" : "off"], checked ? "Keeping the microphone on while asleep" : "Muting the microphone while asleep", "Microphone while asleep", checked ? "On" : "Off")
    }

    Connections {
        target: section.ctl
        function onStateRefreshed() {
            levelRow.sync();
            distanceRow.sync();
        }
    }
}
