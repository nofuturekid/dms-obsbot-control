import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Factory reset, confirmed in place: the first click only asks, the second resets.
// An inline confirmation instead of a dialog, which could close the popout.
SectionCard {
    id: section

    property var ctl
    property bool confirming: false

    title: "Factory reset"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Reset") && ctl.has("factory_reset")
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38
    onExpandedChanged: confirming = false

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: section.confirming ? "This resets every camera setting to its factory default and deletes the presets stored in the camera. The camera restarts and is unavailable for about 20 seconds." : "Restores the camera's factory settings and deletes its stored presets, for example after trying out saved settings."
        color: section.confirming ? Theme.error : Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    Row {
        anchors.right: parent.right
        spacing: Theme.spacingS

        DButton {
            visible: !section.confirming
            text: "Reset to factory settings"
            iconName: "restart_alt"
            backgroundColor: Theme.errorContainer
            textColor: Theme.onErrorContainer
            onClicked: {
                section.confirming = true;
                cancelTimer.restart();
            }
        }

        DButton {
            visible: section.confirming
            text: "Cancel"
            onClicked: section.confirming = false
        }

        DButton {
            visible: section.confirming
            text: "Reset now"
            iconName: "restart_alt"
            backgroundColor: Theme.error
            textColor: Theme.onError
            onClicked: {
                section.confirming = false;
                section.ctl.factoryReset();
            }
        }
    }

    // A forgotten first click must not stay armed
    Timer {
        id: cancelTimer
        interval: 10000
        onTriggered: section.confirming = false
    }
}
