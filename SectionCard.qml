import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Titled card around one popout section (Preview, Framing, Tracking, Picture).
// collapsible: the title row toggles the body and shows `summary` while it is closed.
// flat: no background or padding, for a collapsible group inside another card.
// controlled: a click on the title only emits toggleRequested and the owner sets `expanded`,
// so cards can close each other (one open card per column).
Rectangle {
    id: card

    property string title: ""
    property string summary: ""
    property bool collapsible: false
    property bool expanded: true
    property bool flat: false
    property bool controlled: false
    signal toggleRequested
    default property alias content: body.data

    readonly property real padding: flat ? 0 : Theme.spacingL

    color: flat ? "transparent" : Theme.surfaceContainerHigh
    radius: Theme.cornerRadius
    implicitHeight: column.implicitHeight + padding * 2

    Column {
        id: column
        x: card.padding
        y: card.padding
        width: card.width - card.padding * 2
        spacing: Theme.spacingM

        Item {
            width: parent.width
            height: titleText.implicitHeight
            visible: card.title !== ""

            StyledText {
                id: titleText
                text: card.title
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
            }

            StyledText {
                anchors.right: chevron.visible ? chevron.left : parent.right
                anchors.rightMargin: chevron.visible ? Theme.spacingS : 0
                anchors.verticalCenter: parent.verticalCenter
                visible: card.summary !== "" && card.collapsible && !card.expanded
                text: card.summary
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }

            DIcon {
                id: chevron
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: card.collapsible
                name: card.expanded ? "expand_less" : "expand_more"
                color: Theme.surfaceVariantText
                size: Theme.iconSize
            }

            MouseArea {
                anchors.fill: parent
                enabled: card.collapsible
                cursorShape: card.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (card.controlled)
                        card.toggleRequested();
                    else
                        card.expanded = !card.expanded;
                }
            }
        }

        Column {
            id: body
            width: parent.width
            spacing: Theme.spacingM
            visible: card.expanded
        }
    }
}
