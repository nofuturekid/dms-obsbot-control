import QtQuick
import qs.Services

// Only one preview can hold the camera at a time, and the bar widget has to know when one runs
// anywhere (on air). Every surface that can run a preview (popout, desktop widget instances) has
// one of these: `holding` is that surface's preview switch, the last one switched on wins and the
// others get `displaced`. The owner is a plugin global variable shared by all surfaces.
QtObject {
    id: claim

    property string pluginId: ""
    property bool holding: false

    signal displaced

    // Unique per surface; no bindings, so it is evaluated once
    readonly property string token: Math.random().toString(36).slice(2)
    readonly property string owner: PluginService.globalVars[pluginId]?.previewOwner ?? ""
    // Some surface (this one or another) runs a preview
    readonly property bool anyRunning: owner !== ""

    function setOwner(value) {
        PluginService.setGlobalVar(pluginId, "previewOwner", value);
    }

    onHoldingChanged: {
        if (holding)
            setOwner(token);
        else if (owner === token)
            setOwner("");
    }

    onOwnerChanged: {
        if (holding && owner !== token)
            displaced();
    }

    Component.onDestruction: {
        if (owner === token)
            setOwner("");
    }
}
