import QtQuick
import qs.Common

// Dependency gate: the plugin only activates when obsbot4linux is installed.
// The camera itself is not required, the widget copes with it being unplugged.
QtObject {
    function check(done) {
        Proc.runCommand("obsbotControl.depCheck", ["sh", "-c", "command -v obsbot4linux"], (stdout, exitCode) => {
            if (exitCode === 0) {
                done(null);
                return;
            }
            done({
                "title": "obsbot4linux is required",
                "details": "The 'obsbot4linux' tool is not installed or not on your PATH.\n\nInstall it from https://github.com/nofuturekid/obsbot4linux/releases (packages for Arch, Debian/Ubuntu, Fedora/openSUSE and a tarball), then enable this plugin again."
            });
        });
    }
}
