import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Image adjustments (UVC controls), open by default, with the reset button at the bottom
SectionCard {
    id: section

    property var ctl

    title: "Image adjustments"
    collapsible: true
    summary: ctl.imageAtDefaults ? "Defaults" : "Custom"
    enabled: ctl.live
    opacity: ctl.live ? 1 : 0.38

    Column {
        width: parent.width
        spacing: Theme.spacingS

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

    Item {
        width: parent.width
        height: resetButton.height

        DButton {
            id: resetButton
            anchors.right: parent.right
            text: "Reset to defaults"
            iconName: "restart_alt"
            onClicked: section.ctl.imageControls.forEach(c => section.ctl.setControl(c.name, section.ctl.image[c.name]?.default ?? 0))
        }
    }
}
