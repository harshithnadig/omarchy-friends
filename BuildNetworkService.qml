import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string runtimePath: Qt.resolvedUrl("bin/build_network_runtime.py").toString().replace(/^file:\/\//, "")

    property var profile: ({ handle: "OmarchyBuilder", public_key: "" })
    property var ideas: []
    property var interests: []
    property var buildRooms: []
    property var joins: []
    property var setups: []
    property var tests: []
    property var results: []
    property var stats: ({ ideas: 0, build_rooms: 0, setups: 0, tests: 0, builders: 0 })
    property int relayOk: 0
    property int relayTotal: 0
    property int lastRefresh: 0
    property var lastErrors: []
    property var detectedSetup: ({ theme: "", plugins: [], components: [], shell: "", terminal: "", editor: "" })
    property bool busy: false
    property string lastNotice: ""

    signal actionResult(bool ok, string message)

    function applyStatus(data) {
        if (!data || typeof data !== "object") return
        if (data.profile) root.profile = data.profile
        if (data.ideas) root.ideas = data.ideas
        if (data.interests) root.interests = data.interests
        if (data.build_rooms) root.buildRooms = data.build_rooms
        if (data.joins) root.joins = data.joins
        if (data.setups) root.setups = data.setups
        if (data.tests) root.tests = data.tests
        if (data.results) root.results = data.results
        if (data.stats) root.stats = data.stats
        if (data.relay_ok !== undefined) root.relayOk = data.relay_ok
        if (data.relay_total !== undefined) root.relayTotal = data.relay_total
        if (data.last_refresh !== undefined) root.lastRefresh = data.last_refresh
        if (data.last_errors) root.lastErrors = data.last_errors
    }

    function parseOutput(output) {
        try { return JSON.parse(output || "{}") } catch (e) { return ({ ok: false, message: "Build Network returned invalid data" }) }
    }

    function run(command, payload, fallback) {
        var args = ["python3", root.runtimePath, command]
        if (payload !== undefined && payload !== null) args.push(JSON.stringify(payload))
        root.busy = true
        var proc = actionComponent.createObject(root, { command: args })
        if (!proc) {
            root.busy = false
            root.actionResult(false, "Build Network could not start")
            return
        }
        proc.completed.connect(function(output, exitCode) {
            root.busy = false
            var data = root.parseOutput(output)
            root.applyStatus(data)
            if (data.setup) root.detectedSetup = data.setup
            var ok = data.ok === true && exitCode === 0
            var message = data.message || fallback || (ok ? "Done" : "Build Network action failed")
            root.lastNotice = message
            root.actionResult(ok, message)
        })
        proc.running = true
    }

    function refreshLocal() {
        if (!statusProc.running) statusProc.running = true
    }

    function refreshNetwork() {
        if (!refreshProc.running) {
            root.busy = true
            refreshProc.running = true
        }
    }

    function inspectSetup() { run("inspect-setup", null, "Setup inspected") }
    function createIdea(title, summary, tags) { run("create-idea", { title: title, summary: summary, tags: tags || [] }, "Idea shared") }
    function markInterested(ideaId, note) { run("interest", { idea_id: ideaId, note: note || "" }, "Marked interested") }
    function createRoom(title, goal, repoUrl, roles, tasks, sourceIdeaId) { run("create-room", { title: title, goal: goal, repo_url: repoUrl || "", roles_needed: roles || [], tasks: tasks || [], source_idea_id: sourceIdeaId || "" }, "Build Room opened") }
    function buildIdea(ideaId, repoUrl, roles) { run("room-from-idea", { idea_id: ideaId, repo_url: repoUrl || "", roles_needed: roles || [] }, "Idea promoted to Build Room") }
    function joinRoom(roomId, role, note) { run("join-room", { room_id: roomId, role: role || "Builder", note: note || "" }, "Joined Build Room") }
    function createSetup(title, repoUrl, wallpaperUrl, notes, useDetected) { run("create-setup", { title: title, repo_url: repoUrl || "", wallpaper_url: wallpaperUrl || "", notes: notes || "", use_detected: useDetected !== false }, "Setup shared") }
    function createTest(title, artifactUrl, version, requestedTags, notes, roomId) { run("create-test", { title: title, artifact_url: artifactUrl || "", version: version || "", requested_tags: requestedTags || [], notes: notes || "", build_room_id: roomId || "" }, "Test request shared") }
    function submitTestResult(requestId, result, tags, note) { run("test-result", { request_id: requestId, result: result, environment_tags: tags || [], note: note || "" }, "Test result shared") }
    function hideObject(publicKey, objectId) { run("hide", { public_key: publicKey || "", id: objectId || "" }, "Hidden") }

    Component {
        id: actionComponent
        Process {
            id: actionProc
            property string resultText: ""
            signal completed(string output, int exitCode)
            stdout: StdioCollector { onStreamFinished: actionProc.resultText = this.text }
            onExited: function(exitCode) {
                completed(resultText, exitCode)
                destroy()
            }
        }
    }

    Process {
        id: statusProc
        command: ["python3", root.runtimePath, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return
                root.applyStatus(root.parseOutput(this.text))
            }
        }
    }

    Process {
        id: refreshProc
        command: ["python3", root.runtimePath, "refresh"]
        property string resultText: ""
        stdout: StdioCollector { onStreamFinished: refreshProc.resultText = this.text }
        onExited: function(exitCode) {
            root.busy = false
            var data = root.parseOutput(resultText)
            root.applyStatus(data)
            var ok = data.ok === true && exitCode === 0
            root.lastNotice = data.message || (ok ? "Build Network refreshed" : "Build Network refresh failed")
            root.actionResult(ok, root.lastNotice)
        }
    }

    Timer {
        interval: 7000
        repeat: true
        running: true
        onTriggered: root.refreshLocal()
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshNetwork()
    }

    Component.onCompleted: {
        root.refreshLocal()
        root.inspectSetup()
    }
}
