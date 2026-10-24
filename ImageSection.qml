import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Image adjustments (UVC controls), always open, with the reset button at the bottom
Rectangle {
    id: section

    property var ctl

    readonly property real padding: Theme.spacingL

    color: Theme.surfaceContainerHigh
    radius: Theme.cornerRadius
    enabled: ctl.live
    opacity: ctl.live ? 1 : 0.38
    implicitHeight: content.implicitHeight + Theme.spacingM + resetButton.height + padding * 2

    Column {
        id: content
        x: section.padding
        y: section.padding
        width: section.width - section.padding * 2
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: titleText.implicitHeight

            StyledText {
                id: titleText
                text: "Image adjustments"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
            }

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: section.ctl.imageAtDefaults ? "Defaults" : "Custom"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Repeater {
            model: section.ctl.imageControls

            LabeledSlider {
                required property var modelData
                width: parent.width
                label: modelData.label
                minimum: section.ctl.image[modelData.name]?.min ?? 0
                maximum: section.ctl.image[modelData.name]?.max ?? 100
                value: section.ctl.image[modelData.name]?.value ?? 0
                onMoved: value => section.ctl.setControl(modelData.name, value)
            }
        }
    }

    DButton {
        id: resetButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: section.padding
        text: "Reset to defaults"
        iconName: "restart_alt"
        onClicked: section.ctl.imageControls.forEach(c => section.ctl.setControl(c.name, section.ctl.image[c.name]?.default ?? 0))
    }
}
