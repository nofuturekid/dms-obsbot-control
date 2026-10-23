import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Camera name, status line (with a spinner while a command is in flight) and the Awake switch
Item {
    id: bar

    property var ctl

    implicitHeight: 40

    Rectangle {
        id: badge
        width: 40
        height: 40
        radius: 20
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.surfaceContainerHighest

        DIcon {
            anchors.centerIn: parent
            name: !bar.ctl.available ? "error" : (bar.ctl.awake ? "videocam" : "videocam_off")
            color: bar.ctl.live ? Theme.primary : Theme.surfaceVariantText
            size: Theme.iconSize
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: Theme.spacingM
        anchors.right: awakeRow.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StyledText {
            text: "Tiny 2 Lite"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.DemiBold
        }

        Row {
            spacing: Theme.spacingXS

            DIcon {
                id: spinner
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.ctl.pendingLabel !== ""
                name: "progress_activity"
                color: Theme.surfaceVariantText
                size: Theme.iconSizeSmall

                RotationAnimator on rotation {
                    running: spinner.visible
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.ctl.statusText
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    Row {
        id: awakeRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS
        visible: bar.ctl.available

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Awake"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }

        DToggle {
            anchors.verticalCenter: parent.verticalCenter
            // A DToggle label would span the whole row, so the label is the text beside it
            hideText: true
            checked: bar.ctl.awake
            onToggled: checked => bar.ctl.setAwake(checked)
        }
    }
}
