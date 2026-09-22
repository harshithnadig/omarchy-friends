import QtQuick
import Quickshell
import Quickshell.Io

Service {
    id: root

    property bool autoUpdateEnabled: true
    property string autoUpdateMessage: ""
    property bool autoUpdateRunning: false

    readonly property string autoUpdatePath: Qt.resolvedUrl("bin/omarchy-friends-auto-update")
        .toString().replace(/^file:\/\//, "")

    function checkStableUpdate() {
        if (!root.autoUpdateEnabled || autoUpdateProc.running) return
        root.autoUpdateRunning = true
        autoUpdateProc.running = true
    }

    Process {
        id: autoUpdateProc
        command: ["bash", root.autoUpdatePath]
        property string outputText: ""

        stdout: StdioCollector {
            onStreamFinished: autoUpdateProc.outputText = this.text
        }

        onExited: function(exitCode) {
            root.autoUpdateRunning = false
            var result = {}
            try { result = JSON.parse(autoUpdateProc.outputText || "{}") } catch (e) { result = {} }
            root.autoUpdateMessage = result.message || ""
            if (result.updated === true) {
                Util.execArgv([
                    "omarchy-notification-send",
                    "--app-name", "Omarchy Friends",
                    "-u", "low",
                    "Friends updated ✨",
                    "Latest stable version installed. Reopen Friends to use it."
                ])
            }
        }
    }

    // Check shortly after startup, then every 30 minutes. The updater itself
    // refuses dev branches, dirty checkouts, divergent history and unknown origins.
    Timer {
        interval: 12000
        running: root.autoUpdateEnabled
        repeat: false
        onTriggered: root.checkStableUpdate()
    }

    Timer {
        interval: 30 * 60 * 1000
        running: root.autoUpdateEnabled
        repeat: true
        onTriggered: root.checkStableUpdate()
    }
}
