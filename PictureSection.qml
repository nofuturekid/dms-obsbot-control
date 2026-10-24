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
        checked: section.ctl.status.hdr === true
        onToggled: checked => section.ctl.setHdr(checked)
    }

    // Global / face as status byte 0x07 reports it
    ChipRow {
        width: parent.width
        label: "Exposure"
        options: section.ctl.exposureModes.map(m => m.label)
        currentIndex: section.ctl.status.face_auto_exposure === undefined ? -1 : (section.ctl.status.face_auto_exposure ? 1 : 0)
        onSelected: index => section.ctl.setExposure(index)
    }
}
