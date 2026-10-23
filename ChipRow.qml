import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Label on the left, single-select chips right-aligned (Speed, Exposure).
// DFilterChips is a Flow; right-to-left flow plus a reversed model keeps the chip order.
Item {
    id: row

    property string label: ""
    property var options: []
    property int currentIndex: -1
    signal selected(int index)

    implicitHeight: Math.max(labelText.implicitHeight, chips.implicitHeight)

    StyledText {
        id: labelText
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeSmall
    }

    DFilterChips {
        id: chips
        anchors.left: labelText.right
        anchors.leftMargin: Theme.spacingS
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        layoutDirection: Qt.RightToLeft
        model: row.options.slice().reverse()
        currentIndex: row.currentIndex < 0 ? -1 : row.options.length - 1 - row.currentIndex
        onSelectionChanged: index => row.selected(row.options.length - 1 - index)
    }

    // A click assigns currentIndex and breaks the binding; call after the state was re-read
    function sync() {
        chips.currentIndex = row.currentIndex < 0 ? -1 : row.options.length - 1 - row.currentIndex;
    }
}
