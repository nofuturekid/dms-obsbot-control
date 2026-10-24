import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Auto-sleep and what the camera shows while asleep
SectionCard {
    id: section

    property var ctl

    readonly property var backgrounds: ["Black", "Image"]

    title: "Sleep"
    collapsible: true
    expanded: false
    visible: ctl.has("auto-sleep") || ctl.has("sleep-background")
    summary: ctl.liteValue("Auto-Sleep")
    // Unlike the other settings these matter (and work) while the camera is asleep
    enabled: ctl.available
    opacity: ctl.available ? 1 : 0.38

    ChipRow {
        id: autoSleepRow
        width: parent.width
        visible: section.ctl.has("auto-sleep")
        label: "Auto-sleep"
        options: section.ctl.autoSleepTimes.map(t => t.label)
        currentIndex: section.ctl.autoSleepIndex()
        onSelected: index => {
            const time = section.ctl.autoSleepTimes[index];
            // "off" keeps the configured time, as `info` then shows "Off (… s)"
            const shown = index === 0 ? "Off" : time.arg + " s";
            section.ctl.setLite(["auto-sleep", time.arg], "Setting auto-sleep to " + time.label, "Auto-Sleep", shown);
        }
    }

    ChipRow {
        id: backgroundRow
        width: parent.width
        visible: section.ctl.has("sleep-background")
        label: "While asleep"
        options: section.backgrounds
        currentIndex: section.backgrounds.indexOf(section.ctl.liteValue("Sleep Background"))
        onSelected: index => section.ctl.setLite(["sleep-background", section.backgrounds[index].toLowerCase()], "Setting sleep background to " + section.backgrounds[index], "Sleep Background", section.backgrounds[index])
    }

    Connections {
        target: section.ctl
        function onStateRefreshed() {
            autoSleepRow.sync();
            backgroundRow.sync();
        }
    }
}
