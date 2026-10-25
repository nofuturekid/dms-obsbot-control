import QtQuick
import qs.Common

// Dependency gate: the plugin only activates when obsbot4linux is installed and new enough
// (0.2.0 adds the camera model and device to its state and the `detect` command).
// The camera itself is not required, the widget copes with it being unplugged.
QtObject {
    readonly property var minVersion: [0, 2, 0]
    readonly property string releases: "https://github.com/nofuturekid/obsbot4linux/releases"

    // "obsbot4linux 0.2.0" -> [0, 2, 0]; null when there is no version in the text
    function parseVersion(text) {
        const m = /(\d+)\.(\d+)\.(\d+)/.exec(text);
        return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
    }

    function isOlder(version, minimum) {
        for (let i = 0; i < 3; i++) {
            if (version[i] !== minimum[i])
                return version[i] < minimum[i];
        }
        return false;
    }

    function check(done) {
        Proc.runCommand("obsbotControl.depCheck", ["sh", "-c", "command -v obsbot4linux >/dev/null && obsbot4linux --version"], (stdout, exitCode) => {
            const minimum = minVersion.join(".");
            if (exitCode !== 0) {
                done({
                    "title": "obsbot4linux is required",
                    "details": "The 'obsbot4linux' tool is not installed or not on your PATH. This plugin needs obsbot4linux " + minimum + " or newer.\n\nInstall it from " + releases + " (packages for Arch, Debian/Ubuntu, Fedora/openSUSE and a tarball), then enable this plugin again."
                });
                return;
            }
            const version = parseVersion(stdout);
            if (version && !isOlder(version, minVersion)) {
                done(null);
                return;
            }
            done({
                "title": "obsbot4linux " + minimum + " or newer is required",
                "details": "Installed: " + stdout.trim() + ". This plugin needs obsbot4linux " + minimum + " or newer, which reports the camera model and device.\n\nUpdate it from " + releases + ", then enable this plugin again."
            });
        });
    }
}
