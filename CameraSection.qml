import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Field of view, status LED, mirror and invert (obsbot4linux)
SectionCard {
    id: section

    property var ctl

    readonly property var fovs: ["Wide", "Medium", "Narrow"]
    readonly property var leds: ["Off", "1", "2", "3"]

    // "custom" after the zoom was set freely
    function fovName() {
        const f = ctl.status.field_of_view ?? "";
        return f.charAt(0).toUpperCase() + f.slice(1);
    }

    title: "Camera"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Camera") && (["fov", "led", "mirror", "invert"].some(c => ctl.has(c)))
    summary: [fovName(), ctl.status.led !== undefined ? "LED " + leds[ctl.status.led] : "", ctl.status.mirror !== undefined ? "mirror " + (ctl.status.mirror ? "on" : "off") : "", ctl.tracking.invert !== undefined ? "invert " + (ctl.tracking.invert ? "on" : "off") : ""].filter(s => s !== "").join(" · ")
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available
    opacity: ctl.available ? 1 : 0.38

    ChipRow {
        id: fovRow
        width: parent.width
        visible: section.ctl.has("fov")
        // ignored by the camera while it sleeps
        enabled: section.ctl.live
        opacity: enabled ? 1 : 0.38
        label: "Field of view"
        options: section.fovs
        currentIndex: section.fovs.findIndex(f => f.toLowerCase() === section.ctl.status.field_of_view)
        onSelected: index => section.ctl.send(["fov", section.fovs[index].toLowerCase()], "Setting field of view to " + section.fovs[index], { status: { field_of_view: section.fovs[index].toLowerCase() } })
    }

    ChipRow {
        id: ledRow
        width: parent.width
        visible: section.ctl.has("led")
        label: "Status LED"
        options: section.leds
        currentIndex: section.ctl.status.led ?? -1
        onSelected: index => section.ctl.send(["led", index], "Setting status LED to " + section.leds[index], { status: { led: index } })
    }

    ToggleRow {
        width: parent.width
        visible: section.ctl.has("mirror")
        label: "Mirror image"
        checked: section.ctl.status.mirror === true
        onToggled: checked => section.ctl.send(["mirror", checked ? "on" : "off"], checked ? "Mirroring image" : "Unmirroring image", { status: { mirror: checked } })
    }

    ToggleRow {
        width: parent.width
        visible: section.ctl.has("invert")
        label: "Invert gimbal"
        description: "Reverses left/right panning"
        checked: section.ctl.tracking.invert === true
        onToggled: checked => section.ctl.send(["invert", checked ? "on" : "off"], checked ? "Inverting gimbal" : "Restoring gimbal direction", { tracking: { invert: checked } })
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
