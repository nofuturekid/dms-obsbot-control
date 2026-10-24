import QtQuick
import qs.Common
import qs.DCommon.Widgets

// AI tracking mode and speed
SectionCard {
    id: section

    property var ctl

    function modeIndex() {
        return ctl.trackingModes.findIndex(m => m.label === ctl.aiMode);
    }

    title: "Tracking"
    enabled: ctl.live
    opacity: ctl.live ? 1 : 0.38

    DFilterChips {
        id: modeChips
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

    // A click assigns currentIndex and breaks the binding; re-sync to the camera state
    Connections {
        target: section.ctl
        function onStateRefreshed() {
            modeChips.currentIndex = section.modeIndex();
            speedRow.sync();
        }
    }
}
