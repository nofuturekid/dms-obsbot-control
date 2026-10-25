import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Zone tracking: stay within an area, return to a chosen position. The camera reports only
// whether zone tracking is on; follow is remembered by obsbot4linux (state.zone_follow) and
// the area has no readback, so the widget keeps the last area it set in its plugin settings.
SectionCard {
    id: section

    property var ctl

    readonly property var fullArea: [-100, 100, -30, 30]
    // [pan from, pan to, tilt from, tilt to]
    readonly property var savedArea: {
        const saved = ctl.pluginData?.zoneArea;
        return Array.isArray(saved) && saved.length === 4 && saved.every(v => Number.isFinite(v)) ? saved : fullArea;
    }
    property int panMin: savedArea[0]
    property int panMax: savedArea[1]
    property int tiltMin: savedArea[2]
    property int tiltMax: savedArea[3]
    readonly property bool zoneOn: ctl.tracking.zone_tracking === true
    readonly property bool fullAreaSet: panMin === fullArea[0] && panMax === fullArea[1] && tiltMin === fullArea[2] && tiltMax === fullArea[3]

    function num(v) {
        return String(v).replace("-", "−");
    }
    function deg(v) {
        return num(v) + "°";
    }

    // Keeps from < to; the slider that was dragged past the other one stops at it
    function setArea(which, value) {
        if (which === "panMin")
            panMin = Math.min(value, panMax - 1);
        else if (which === "panMax")
            panMax = Math.max(value, panMin + 1);
        else if (which === "tiltMin")
            tiltMin = Math.min(value, tiltMax - 1);
        else
            tiltMax = Math.max(value, tiltMin + 1);
        panMinSlider.sync();
        panMaxSlider.sync();
        tiltMinSlider.sync();
        tiltMaxSlider.sync();
    }

    function sendArea() {
        ctl.send(["zone", "area", "--pan", panMin, panMax, "--tilt", tiltMin, tiltMax], "Setting zone area", undefined);
        ctl.pluginService?.savePluginData(ctl.pluginId, "zoneArea", [panMin, panMax, tiltMin, tiltMax]);
    }

    title: "Zone"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Zone") && ctl.has("zone")
    summary: (ctl.tracking.zone_tracking === undefined ? "" : "Zone " + (zoneOn ? "on" : "off") + " · ") + "pan " + num(panMin) + "…" + deg(panMax) + " · tilt " + num(tiltMin) + "…" + deg(tiltMax)
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    ToggleRow {
        width: parent.width
        label: "Zone tracking"
        checked: section.zoneOn
        onToggled: checked => section.ctl.send(["zone", checked ? "on" : "off"], checked ? "Turning on zone tracking" : "Turning off zone tracking", { tracking: { zone_tracking: checked } })
    }

    ToggleRow {
        width: parent.width
        visible: section.ctl.has("zone_follow")
        label: "Follow new targets"
        checked: section.ctl.cam.state?.zone_follow === true
        onToggled: checked => section.ctl.send(["zone", "follow", checked ? "on" : "off"], checked ? "Following new targets" : "Not following new targets", { state: { zone_follow: checked } })
    }

    // Sent once the slider is let go, not on every step
    LabeledSlider {
        id: panMinSlider
        width: parent.width
        label: "Pan from"
        minimum: -100
        maximum: 100
        value: section.panMin
        formatValue: section.deg
        onMoved: value => section.setArea("panMin", value)
        onReleased: section.sendArea()
    }

    LabeledSlider {
        id: panMaxSlider
        width: parent.width
        label: "Pan to"
        minimum: -100
        maximum: 100
        value: section.panMax
        formatValue: section.deg
        onMoved: value => section.setArea("panMax", value)
        onReleased: section.sendArea()
    }

    LabeledSlider {
        id: tiltMinSlider
        width: parent.width
        label: "Tilt from"
        minimum: -30
        maximum: 30
        value: section.tiltMin
        formatValue: section.deg
        onMoved: value => section.setArea("tiltMin", value)
        onReleased: section.sendArea()
    }

    LabeledSlider {
        id: tiltMaxSlider
        width: parent.width
        label: "Tilt to"
        minimum: -30
        maximum: 30
        value: section.tiltMax
        formatValue: section.deg
        onMoved: value => section.setArea("tiltMax", value)
        onReleased: section.sendArea()
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        DButton {
            text: "Full area"
            iconName: "fit_screen"
            enabled: !section.fullAreaSet
            onClicked: {
                section.panMin = section.fullArea[0];
                section.panMax = section.fullArea[1];
                section.tiltMin = section.fullArea[2];
                section.tiltMax = section.fullArea[3];
                section.sendArea();
            }
        }

        DButton {
            text: "Return here"
            iconName: "my_location"
            onClicked: section.ctl.send(["zone", "return-here"], "Setting the zone return position")
        }
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: section.ctl.cam.state?.zone_follow === true
            ? "When the target leaves the area, the camera keeps tracking and takes the next person who enters it."
            : "When the target leaves the area, tracking stops (Static) and the camera returns to its return position."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }
}
