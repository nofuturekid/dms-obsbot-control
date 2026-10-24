import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Label and value on one line, slider below (zoom, image adjustments)
Column {
    id: item

    property string label: ""
    property string unit: ""
    property int minimum: 0
    property int maximum: 100
    property int value: 0
    // How the value is shown next to the label, e.g. tenths as "2.0×"
    property var formatValue: v => v + item.unit
    signal moved(int value)

    spacing: 2

    // Dragging assigns slider.value and breaks its binding, so push later changes
    // (reset to defaults, values read from the camera) explicitly
    onValueChanged: slider.value = value

    Item {
        width: parent.width
        height: labelText.implicitHeight

        StyledText {
            id: labelText
            text: item.label
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
        }

        StyledText {
            anchors.right: parent.right
            text: item.formatValue(slider.value)
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    DSlider {
        id: slider
        width: parent.width
        showValue: false
        minimum: item.minimum
        maximum: item.maximum
        value: item.value
        onSliderValueChanged: newValue => item.moved(newValue)
    }
}
