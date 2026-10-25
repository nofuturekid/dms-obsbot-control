import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Camera name, status line (with a spinner while a command is in flight) and the Awake switch.
// In arrange mode the status line becomes the hint and Reset layout takes the Awake switch's place,
// so the header keeps its height and the cards below don't move.
Item {
    id: bar

    property var ctl

    implicitHeight: badge.height

    Rectangle {
        id: badge
        width: Theme.buttonHeightS
        height: Theme.buttonHeightS
        radius: width / 2
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
        anchors.right: editButton.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StyledText {
            text: "OBSBOT Control"
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
                // the camera model, then its state: the title is the plugin's name
                text: bar.ctl.arranging ? "Drag a card by its handle to move it." : bar.ctl.summary
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    // Arrange mode of the popout cards (drag handles, Reset layout)
    DIconButton {
        id: editButton
        anchors.right: resetButton.visible ? resetButton.left : (awakeRow.visible ? awakeRow.left : parent.right)
        anchors.rightMargin: resetButton.visible || awakeRow.visible ? Theme.spacingM : 0
        anchors.verticalCenter: parent.verticalCenter
        iconName: bar.ctl.arranging ? "check" : "edit"
        variant: bar.ctl.arranging ? "tonal" : "standard"
        tooltipText: bar.ctl.arranging ? "Done" : "Arrange cards"
        onClicked: bar.ctl.arranging = !bar.ctl.arranging
    }

    DButton {
        id: resetButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: bar.ctl.arranging
        text: "Reset layout"
        iconName: "restart_alt"
        backgroundColor: Theme.surfaceContainerHighest
        textColor: Theme.surfaceText
        onClicked: bar.ctl.resetLayout()
    }

    Row {
        id: awakeRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS
        visible: bar.ctl.available && !bar.ctl.arranging

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
