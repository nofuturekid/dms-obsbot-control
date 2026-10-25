import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Widgets

// Bar pill: the camera icon plus the interactions PluginComponent does not forward. Left and
// right click stay with the pill itself (popout, sleep/wake): the MouseArea takes only the
// wheel and the middle button, the HoverHandler is passive, so the pill keeps its own hover.
Item {
    id: pill

    property var ctl

    implicitWidth: ctl.iconSize
    implicitHeight: ctl.iconSize

    DIcon {
        anchors.centerIn: parent
        // unplugged/unreachable gets its own icon, so it is not mistaken for asleep (videocam_off)
        name: !pill.ctl.available ? "usb_off" : pill.ctl.live ? "videocam" : "videocam_off"
        color: pill.ctl.live ? Theme.primary : Theme.surfaceVariantText
        // dimmed while the camera is unplugged or unreachable
        opacity: pill.ctl.available ? 1 : 0.38
        size: pill.ctl.iconSize

        // On-air dot: some application (the preview included) is reading the camera
        Rectangle {
            visible: pill.ctl.streaming
            width: Math.round(pill.ctl.iconSize / 4)
            height: width
            radius: width / 2
            anchors.top: parent.top
            anchors.right: parent.right
            color: Theme.error
        }
    }

    Loader {
        id: tooltip
        active: false
        sourceComponent: DTooltip {}
    }

    function showTooltip() {
        if (!ctl.parentScreen || ctl.interactionActive)
            return;
        tooltip.active = true;
        if (!tooltip.item)
            return;
        const screen = ctl.parentScreen;
        const text = ctl.summary;
        if (ctl.isVertical) {
            // a bar on a second screen sits below that screen's origin
            const pos = pill.mapToItem(null, width / 2, height / 2);
            const left = ctl.axis?.edge === "left";
            const x = left ? (ctl.barThickness + ctl.barSpacing + Theme.spacingXS) : (screen.width - ctl.barThickness - ctl.barSpacing - Theme.spacingXS);
            tooltip.item.show(text, x, pos.y + (screen.y > 0 ? ctl.barThickness + ctl.barSpacing : 0), screen, left, !left);
        } else {
            const pos = pill.mapToItem(null, width / 2, 0);
            const tooltipHeight = Theme.fontSizeSmall * 1.5 + Theme.spacingS * 2;
            const y = ctl.axis?.edge === "bottom" ? screen.height - ctl.barThickness - ctl.barSpacing - Theme.spacingXS - tooltipHeight : ctl.barThickness + ctl.barSpacing + Theme.spacingXS;
            tooltip.item.show(text, pos.x, y, screen, false, false);
        }
    }

    function hideTooltip() {
        tooltip.item?.hide();
        tooltip.active = false;
    }

    // Opening the popout (left click) ends the hover
    Connections {
        target: pill.ctl
        function onInteractionActiveChanged() {
            if (pill.ctl.interactionActive)
                pill.hideTooltip();
        }
    }

    // The whole pill, padding included
    Item {
        anchors.fill: parent
        anchors.margins: -Theme.spacingS

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: hovered ? pill.showTooltip() : pill.hideTooltip()
        }

        MouseArea {
            anchors.fill: parent
            // Switched off, the middle button and the wheel pass on as before
            acceptedButtons: pill.ctl.middleClickTracking ? Qt.MiddleButton : Qt.NoButton
            onClicked: pill.ctl.toggleTracking()
            onWheel: wheel => {
                wheel.accepted = pill.ctl.wheelZoom && pill.ctl.live;
                if (wheel.accepted)
                    pill.ctl.stepZoom(wheel.angleDelta.y / 120);
            }
        }
    }
}
