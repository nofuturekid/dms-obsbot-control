import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Pan/tilt and zoom
SectionCard {
    id: section

    property var ctl

    title: "Framing"
    enabled: ctl.live
    opacity: ctl.live ? 1 : 0.38

    Row {
        width: parent.width
        spacing: Theme.spacingL

        // D-pad: up / left center right / down
        Grid {
            id: dpad
            columns: 3
            spacing: 4

            Item { width: 40; height: 40 }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_up"
                tooltipText: "Tilt up 5°"
                onClicked: section.ctl.moveGimbal(section.ctl.pan, section.ctl.tilt + section.ctl.gimbalStep)
            }
            Item { width: 40; height: 40 }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_left"
                tooltipText: "Pan left 5°"
                onClicked: section.ctl.moveGimbal(section.ctl.pan + section.ctl.gimbalStep, section.ctl.tilt)
            }
            DIconButton {
                variant: "outlined"
                iconName: "filter_center_focus"
                tooltipText: "Center"
                onClicked: section.ctl.moveGimbal(0, 0)
            }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_right"
                tooltipText: "Pan right 5°"
                onClicked: section.ctl.moveGimbal(section.ctl.pan - section.ctl.gimbalStep, section.ctl.tilt)
            }
            Item { width: 40; height: 40 }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_down"
                tooltipText: "Tilt down 5°"
                onClicked: section.ctl.moveGimbal(section.ctl.pan, section.ctl.tilt - section.ctl.gimbalStep)
            }
            Item { width: 40; height: 40 }
        }

        Column {
            width: parent.width - dpad.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            StyledText {
                text: "Pan " + section.ctl.degrees(section.ctl.pan) + " · Tilt " + section.ctl.degrees(section.ctl.tilt)
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.features: { "tnum": 1 }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "5° per step. Moving switches tracking to Static."
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    LabeledSlider {
        width: parent.width
        label: "Zoom"
        unit: "%"
        value: section.ctl.controlValues.zoom_absolute ?? 0
        onMoved: value => section.ctl.setControl("zoom_absolute", value)
    }
}
