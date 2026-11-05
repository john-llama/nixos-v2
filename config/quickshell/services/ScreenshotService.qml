pragma Singleton

// The screenshot just taken by the `screenshot` script, offered for editing
// from the bar for a few seconds instead of through a notification.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string file: ""
    readonly property bool recent: file !== ""
    readonly property int shownMs: 5000

    function edit(): void {
        if (!recent)
            return;
        Quickshell.execDetached(["satty-edit", file]);
        dismiss();
    }

    function dismiss(): void {
        hideTimer.stop();
        file = "";
    }

    Timer {
        id: hideTimer
        interval: root.shownMs
        onTriggered: root.file = ""
    }

    IpcHandler {
        target: "screenshot"

        function taken(path: string): void {
            root.file = path;
            hideTimer.restart();
        }
    }
}
