import QtQuick
import qs.Common
import qs.DCommon.Widgets

// The popout's Preview card: the shared 16:9 PreviewFrame in a titled card
SectionCard {
    id: pane

    property var ctl

    title: "Preview"

    PreviewFrame {
        width: parent.width
        height: width * 9 / 16
        ctl: pane.ctl
    }
}
