import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Label on the left, single-select chips right-aligned (Speed, Exposure).
// DFilterChips is a Flow; right-to-left flow plus a reversed model keeps the chip order.
// stacked: label above, chips left to right below; for rows too long for one line, where
// the reversed right-to-left flow would wrap the first chips into the second line.
Item {
    id: row

    property string label: ""
    property var options: []
    property int currentIndex: -1
    property bool stacked: false
    signal selected(int index)

    // Chip index <-> option index; reversed only in the right-aligned layout
    function chipIndex(index) {
        return index < 0 ? -1 : (row.stacked ? index : row.options.length - 1 - index);
    }

    implicitHeight: stacked ? labelText.implicitHeight + Theme.spacingS + chips.implicitHeight : Math.max(labelText.implicitHeight, chips.implicitHeight)

    StyledText {
        id: labelText
        anchors.top: row.stacked ? parent.top : undefined
        anchors.verticalCenter: row.stacked ? undefined : parent.verticalCenter
        text: row.label
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeSmall
    }

    DFilterChips {
        id: chips
        // the selected chip is marked by its colour only; a check mark would widen it
        showCheck: false
        anchors.left: row.stacked ? parent.left : labelText.right
        anchors.leftMargin: row.stacked ? 0 : Theme.spacingS
        anchors.right: parent.right
        anchors.top: row.stacked ? labelText.bottom : undefined
        anchors.topMargin: row.stacked ? Theme.spacingS : 0
        anchors.verticalCenter: row.stacked ? undefined : parent.verticalCenter
        layoutDirection: row.stacked ? Qt.LeftToRight : Qt.RightToLeft
        model: row.stacked ? row.options : row.options.slice().reverse()
        currentIndex: row.chipIndex(row.currentIndex)
        onSelectionChanged: index => row.selected(row.chipIndex(index))
    }

    // A click assigns currentIndex and breaks the binding; call after the state was re-read
    function sync() {
        chips.currentIndex = row.chipIndex(row.currentIndex);
    }
}
