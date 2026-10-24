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
    summary: [ctl.liteValue("Hand Tracking Side") !== "" ? ctl.liteValue("Hand Tracking Side") + " hand" : "", ctl.liteValue("Zone Tracking") !== "" ? "zone " + ctl.liteValue("Zone Tracking").toLowerCase() : ""].filter(s => s !== "").join(" · ")
    enabled: ctl.live
    opacity: ctl.live ? 1 : 0.38

    ChipRow {
        id: sideRow
        width: parent.width
        visible: section.ctl.has("hand")
        label: "Tracked hand"
        options: section.sides
        currentIndex: section.sides.indexOf(section.ctl.liteValue("Hand Tracking Side"))
        onSelected: index => section.ctl.setLite(["hand", section.sides[index].toLowerCase()], "Tracking the " + section.sides[index].toLowerCase() + " hand", "Hand Tracking Side", section.sides[index])
    }

    ToggleRow {
        width: parent.width
        visible: section.ctl.has("zone")
        label: "Zone tracking"
        checked: section.ctl.liteValue("Zone Tracking") === "On"
        onToggled: checked => section.ctl.setLite(["zone", checked ? "on" : "off"], checked ? "Turning zone tracking on" : "Turning zone tracking off", "Zone Tracking", checked ? "On" : "Off")
    }

    Connections {
        target: section.ctl
        function onStateRefreshed() {
            sideRow.sync();
        }
    }
}
