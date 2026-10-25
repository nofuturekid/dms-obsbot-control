import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Titled card around one popout section (Preview, Framing, Tracking, Picture).
// collapsible: the title row toggles the body; `summary` shows under the title while closed.
// flat: no background or padding, for a collapsible group inside another card.
// controlled: a click on the title only emits toggleRequested and the owner sets `expanded`,
// so cards can close each other (one open card per column).
// arranger: the popout's arrange mode (null elsewhere). While `arranging` the card shows a grip,
// folds up, ignores clicks and can be dragged by the grip; it reports the pointer to the arranger.
Rectangle {
    id: card

    property string title: ""
    property string summary: ""
    property bool collapsible: false
    property bool expanded: true
    property bool flat: false
    property bool controlled: false
    property string cardId: ""
    property var arranger: null
    readonly property bool arranging: arranger?.arranging ?? false
    signal toggleRequested
    default property alias content: body.data

    readonly property real padding: flat ? 0 : Theme.spacingL

    color: flat ? "transparent" : Theme.surfaceContainerHigh
    radius: Theme.cornerRadius
    implicitHeight: column.implicitHeight + padding * 2
    z: dragHandler.active ? 10 : 0
    transform: Translate {
        x: dragHandler.active ? dragHandler.activeTranslation.x : 0
        y: dragHandler.active ? dragHandler.activeTranslation.y : 0
    }

    Column {
        id: column
        x: card.padding
        y: card.padding
        width: card.width - card.padding * 2
        spacing: Theme.spacingM

        Item {
            width: parent.width
            height: titleText.implicitHeight + (summaryText.visible ? Theme.spacingXS + summaryText.implicitHeight : 0)
            visible: card.title !== ""

            StyledText {
                id: titleText
                text: card.title
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
            }

            // Closed cards list their settings under the title, wrapping over the full width
            StyledText {
                id: summaryText
                y: titleText.implicitHeight + Theme.spacingXS
                width: parent.width
                visible: card.summary !== "" && card.collapsible && !card.expanded
                wrapMode: Text.WordWrap
                text: card.summary
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }

            DIcon {
                id: chevron
                anchors.right: parent.right
                anchors.verticalCenter: titleText.verticalCenter
                visible: card.collapsible && !card.arranging
                name: card.expanded ? "expand_less" : "expand_more"
                color: Theme.surfaceVariantText
                size: Theme.iconSize
            }

            MouseArea {
                anchors.fill: parent
                enabled: card.collapsible && !card.arranging
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
            visible: card.expanded && !card.arranging
        }
    }

    // Arrange mode: clicks must not reach the controls, the grip sits above this
    MouseArea {
        anchors.fill: parent
        z: 1
        visible: card.arranging
    }

    Item {
        id: grip
        z: 2
        visible: card.arranging
        width: Theme.buttonHeightS
        height: Theme.buttonHeightS
        x: card.width - card.padding - width
        y: card.padding + titleText.implicitHeight / 2 - height / 2

        DIcon {
            anchors.centerIn: parent
            name: "drag_indicator"
            color: Theme.surfaceVariantText
            size: Theme.iconSize
        }

        HoverHandler {
            cursorShape: Qt.OpenHandCursor
        }

        DragHandler {
            id: dragHandler
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: Qt.ClosedHandCursor
            onCentroidChanged: {
                if (active)
                    card.arranger?.dragMove(card.cardId, centroid.scenePosition);
            }
            onActiveChanged: {
                if (!active)
                    card.arranger?.dragEnd(card.cardId);
            }
        }
    }
}
