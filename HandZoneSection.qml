import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Which hand the hand tracking follows, and zone tracking
SectionCard {
    id: section

    property var ctl

    readonly property var sides: ["Left", "Right"]

    title: "Hand & zone tracking"
    collapsible: true
    expanded: false
    visible: ctl.has("hand") || ctl.has("zone")
    summary: [ctl.tracking.hand_side ? ctl.tracking.hand_side + " hand" : "", ctl.tracking.zone_tracking !== undefined ? "zone " + (ctl.tracking.zone_tracking ? "on" : "off") : ""].filter(s => s !== "").join(" · ")
    enabled: ctl.live
    opacity: ctl.live ? 1 : 0.38

    ChipRow {
        id: sideRow
        width: parent.width
        visible: section.ctl.has("hand")
        label: "Tracked hand"
        options: section.sides
        currentIndex: section.sides.findIndex(s => s.toLowerCase() === section.ctl.tracking.hand_side)
        onSelected: index => section.ctl.send(["hand", section.sides[index].toLowerCase()], "Tracking the " + section.sides[index].toLowerCase() + " hand", { tracking: { hand_side: section.sides[index].toLowerCase() } })
    }

    ToggleRow {
        width: parent.width
        visible: section.ctl.has("zone")
        label: "Zone tracking"
        checked: section.ctl.tracking.zone_tracking === true
        onToggled: checked => section.ctl.send(["zone", checked ? "on" : "off"], checked ? "Turning zone tracking on" : "Turning zone tracking off", { tracking: { zone_tracking: checked } })
    }

    Connections {
        target: section.ctl
        function onStateRefreshed() {
            sideRow.sync();
        }
    }
}
