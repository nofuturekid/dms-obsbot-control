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
            spacing: Theme.spacingXS

            Item { width: upButton.width; height: upButton.height }
            DIconButton {
                id: upButton
                variant: "tonal"
                iconName: "keyboard_arrow_up"
                tooltipText: "Tilt up " + section.ctl.gimbalStep + "°"
                onClicked: section.ctl.moveGimbal(section.ctl.pan, section.ctl.tilt + section.ctl.gimbalStep)
            }
            Item { width: upButton.width; height: upButton.height }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_left"
                tooltipText: "Pan left " + section.ctl.gimbalStep + "°"
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
                tooltipText: "Pan right " + section.ctl.gimbalStep + "°"
                onClicked: section.ctl.moveGimbal(section.ctl.pan - section.ctl.gimbalStep, section.ctl.tilt)
            }
            Item { width: upButton.width; height: upButton.height }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_down"
                tooltipText: "Tilt down " + section.ctl.gimbalStep + "°"
                onClicked: section.ctl.moveGimbal(section.ctl.pan, section.ctl.tilt - section.ctl.gimbalStep)
            }
            Item { width: upButton.width; height: upButton.height }
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
                text: section.ctl.gimbalStep + "° per step. Moving switches tracking to Static."
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    ToggleRow {
        width: parent.width
        label: "Fine steps"
        description: "1° per click instead of 5°"
        checked: section.ctl.fineGimbal
        onToggled: checked => section.ctl.fineGimbal = checked
    }

    LabeledSlider {
        width: parent.width
        label: "Zoom"
        minimum: 10
        maximum: 40
        value: Math.round(section.ctl.zoomFactor * 10)
        formatValue: v => (v / 10).toFixed(1) + "×"
        onMoved: value => section.ctl.setZoom(value / 10)
    }
}
