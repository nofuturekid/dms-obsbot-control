import QtQuick
import qs.Common
import qs.DCommon.Widgets

// The popout's Preview card: the shared 16:9 PreviewFrame in a titled card
SectionCard {
    id: pane

    property var ctl
    // Height the card may take; the picture gets shorter than 16:9 when it does not fit
    property real maxHeight: -1

    title: "Preview"

    PreviewFrame {
        width: parent.width
        height: pane.maxHeight > 0 ? Math.max(Theme.spacingXL * 3, Math.min(width * 9 / 16, pane.maxHeight - pane.padding * 2 - Theme.fontSizeMedium * 2 - Theme.spacingM)) : width * 9 / 16
        ctl: pane.ctl
    }
}
