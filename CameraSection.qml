import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Field of view, status LED, mirror and invert (tiny4linux with the Lite settings)
SectionCard {
    id: section

    property var ctl

    readonly property var fovs: ["Wide", "Medium", "Narrow"]
    readonly property var leds: ["Off", "1", "2", "3"]

    title: "Camera"
    collapsible: true
    expanded: false
    visible: ["fov", "led", "mirror", "invert"].some(c => ctl.has(c))
    summary: [ctl.liteValue("Field of View"), ctl.liteValue("Status LED") !== "" ? "LED " + ctl.liteValue("Status LED") : ""].filter(s => s !== "").join(" · ")
    enabled: ctl.live
    opacity: ctl.live ? 1 : 0.38

    ChipRow {
        id: fovRow
        width: parent.width
        visible: section.ctl.has("fov")
        label: "Field of view"
        options: section.fovs
        currentIndex: section.fovs.indexOf(section.ctl.liteValue("Field of View"))
        onSelected: index => section.ctl.setLite(["fov", section.fovs[index].toLowerCase()], "Setting field of view to " + section.fovs[index], "Field of View", section.fovs[index])
    }

    ChipRow {
        id: ledRow
        width: parent.width
        visible: section.ctl.has("led")
        label: "Status LED"
        options: section.leds
        currentIndex: section.leds.indexOf(section.ctl.liteValue("Status LED"))
        onSelected: index => section.ctl.setLite(["led", section.leds[index].toLowerCase()], "Setting status LED to " + section.leds[index], "Status LED", section.leds[index])
    }

    ToggleRow {
        width: parent.width
        visible: section.ctl.has("mirror")
        label: "Mirror image"
        checked: section.ctl.liteValue("Mirror Image") === "On"
        onToggled: checked => section.ctl.setLite(["mirror", checked ? "on" : "off"], checked ? "Mirroring image" : "Unmirroring image", "Mirror Image", checked ? "On" : "Off")
    }

    ToggleRow {
        width: parent.width
        visible: section.ctl.has("invert")
        label: "Invert gimbal"
        description: "Reverses left/right panning"
        checked: section.ctl.liteValue("Invert View and Gimbal") === "On"
        onToggled: checked => section.ctl.setLite(["invert", checked ? "on" : "off"], checked ? "Inverting gimbal" : "Restoring gimbal direction", "Invert View and Gimbal", checked ? "On" : "Off")
    }

    // A click assigns currentIndex and breaks the binding; re-sync to the camera state
    Connections {
        target: section.ctl
        function onStateRefreshed() {
            fovRow.sync();
            ledRow.sync();
        }
    }
}
