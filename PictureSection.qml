import QtQuick
import qs.Common
import qs.DCommon.Widgets

// HDR and exposure mode
SectionCard {
    id: section

    property var ctl

    title: "Picture"
    enabled: ctl.live
    opacity: ctl.live ? 1 : 0.38

    ToggleRow {
        width: parent.width
        label: "HDR"
        checked: section.ctl.hdr
        onToggled: checked => section.ctl.setHdr(checked)
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        ChipRow {
            width: parent.width
            label: "Exposure"
            options: section.ctl.exposureModes.map(m => m.label)
            currentIndex: section.ctl.exposureModes.findIndex(m => m.arg === section.ctl.exposure)
            onSelected: index => section.ctl.setExposure(index)
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignRight
            text: "Last choice. The camera doesn't report exposure."
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall - 1
        }
    }
}
