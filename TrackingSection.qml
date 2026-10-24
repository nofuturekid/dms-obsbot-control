import QtQuick
import qs.Common
import qs.DCommon.Widgets

// AI tracking mode, speed and the hand that hand tracking follows
SectionCard {
    id: section

    property var ctl

    readonly property var sides: ["Left", "Right"]

    function modeIndex() {
        return ctl.trackingModes.findIndex(m => m.label === ctl.aiMode);
    }

    title: "Tracking"
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available
    opacity: ctl.available ? 1 : 0.38

    DFilterChips {
        id: modeChips
        // the selected chip is marked by its colour only; a check mark would widen it
        showCheck: false
        width: parent.width
        model: section.ctl.trackingModes.map(m => m.label)
        currentIndex: section.modeIndex()
        onSelectionChanged: index => section.ctl.setMode(index)
    }

    ChipRow {
        id: speedRow
        width: parent.width
        label: "Speed"
        options: section.ctl.speeds.map(m => m.label)
        currentIndex: section.ctl.speeds.findIndex(s => s.label === section.ctl.speed)
        onSelected: index => section.ctl.setSpeed(index)
    }

    // Greyed out but readable outside hand tracking, so the side that would be tracked shows
    ChipRow {
        id: sideRow
        width: parent.width
        visible: section.ctl.has("hand")
        enabled: section.ctl.status.ai_mode === "hand"
        opacity: enabled ? 1 : 0.38
        label: "Tracked hand"
        options: section.sides
        currentIndex: section.sides.findIndex(s => s.toLowerCase() === section.ctl.tracking.hand_side)
        onSelected: index => section.ctl.send(["hand", section.sides[index].toLowerCase()], "Tracking the " + section.sides[index].toLowerCase() + " hand", { tracking: { hand_side: section.sides[index].toLowerCase() } })
    }

    // A click assigns currentIndex and breaks the binding; re-sync to the camera state
    Connections {
        target: section.ctl
        function onStateRefreshed() {
            modeChips.currentIndex = section.modeIndex();
            speedRow.sync();
            sideRow.sync();
        }
    }
}
