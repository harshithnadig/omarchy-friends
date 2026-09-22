import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string runtimePath: Qt.resolvedUrl("bin/build_network_app_v4.py").toString().replace(/^file:\/\//, "")

    property var profile: ({ handle: "OmarchyBuilder", public_key: "" })
    property var ideas: []
    property var interests: []
    property var buildRooms: []
    property var joins: []
    property var setups: []
    property var tests: []
    property var results: []
    property var helpRequests: []
    property var helpOffers: []
    property var solutions: []
    property var solutionVerifications: []
    property var shipPosts: []
    property var updateReports: []
    property var updatePulse: []
    property var events: []
    property var eventRsvps: []
    property var challenges: []
    property var challengeJoins: []
    property var taskUpdates: []
    property var contributors: []
    property var discoverFeed: []
    property var saved: []
    property var helpers: []
    property var pairing: []
    property var setupComponents: []
    property var projectActivity: []
    property var githubSnapshot: ({ repo_url: "", items: [] })
    property string shareText: ""
    property var uriRegistration: ({})
    property var releaseInfo: ({ app_version: "", state_schema: 1, pending_publish: 0, blocked_filtered: 0 })
    property var stats: ({ ideas: 0, build_rooms: 0, setups: 0, tests: 0, builders: 0, ships: 0, solutions: 0, help_requests: 0, events: 0, challenges: 0, helps: 0, verifications: 0, task_updates: 0, helpers: 0, setup_components: 0, project_activity: 0, pending_publish: 0, blocked_filtered: 0 })
    property int relayOk: 0
    property int relayTotal: 0
    property int lastRefresh: 0
    property var lastErrors: []
    property var detectedSetup: ({ theme: "", plugins: [], components: [], shell: "", terminal: "", editor: "" })
    property var detectedEnvironment: ({ tags: [], omarchy_version: "", architecture: "", gpu_vendor: "", kernel: "" })
    property var setupComparison: ({})
    property bool busy: false
    property var actionQueue: []
    property string lastNotice: ""

    signal actionResult(bool ok, string message)
    signal shareTextReady(string text)
    signal githubSnapshotReady(var snapshot)

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
        if (data.help_requests) root.helpRequests = data.help_requests
        if (data.help_offers) root.helpOffers = data.help_offers
        if (data.solutions) root.solutions = data.solutions
        if (data.solution_verifications) root.solutionVerifications = data.solution_verifications
        if (data.ship_posts) root.shipPosts = data.ship_posts
        if (data.update_reports) root.updateReports = data.update_reports
        if (data.update_pulse) root.updatePulse = data.update_pulse
        if (data.events) root.events = data.events
        if (data.event_rsvps) root.eventRsvps = data.event_rsvps
        if (data.challenges) root.challenges = data.challenges
        if (data.challenge_joins) root.challengeJoins = data.challenge_joins
        if (data.task_updates) root.taskUpdates = data.task_updates
        if (data.contributors) root.contributors = data.contributors
        if (data.discover_feed) root.discoverFeed = data.discover_feed
        if (data.saved) root.saved = data.saved
        if (data.helpers) root.helpers = data.helpers
        if (data.pairing) root.pairing = data.pairing
        if (data.setup_components) root.setupComponents = data.setup_components
        if (data.project_activity) root.projectActivity = data.project_activity
        if (data.environment) root.detectedEnvironment = data.environment
        if (data.release) root.releaseInfo = data.release
        if (data.github_snapshot) { root.githubSnapshot = data.github_snapshot; root.githubSnapshotReady(data.github_snapshot) }
        if (data.share_text !== undefined) { root.shareText = data.share_text; root.shareTextReady(data.share_text) }
        if (data.registration) root.uriRegistration = data.registration
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
        var queue = root.actionQueue.slice()
        queue.push({ command: command, payload: payload, fallback: fallback || "" })
        root.actionQueue = queue
        root.processActionQueue()
    }

    function processActionQueue() {
        if (root.busy || statusProc.running || refreshProc.running || root.actionQueue.length === 0) return

        var queue = root.actionQueue.slice()
        var next = queue.shift()
        root.actionQueue = queue

        var args = ["python3", root.runtimePath, next.command]
        if (next.payload !== undefined && next.payload !== null) args.push(JSON.stringify(next.payload))

        root.busy = true
        var proc = actionComponent.createObject(root, { command: args })
        if (!proc) {
            root.busy = false
            root.actionResult(false, "Build Network could not start")
            Qt.callLater(root.processActionQueue)
            return
        }
        proc.completed.connect(function(output, exitCode) {
            root.busy = false
            var data = root.parseOutput(output)
            root.applyStatus(data)
            if (data.setup) root.detectedSetup = data.setup
            if (data.environment) root.detectedEnvironment = data.environment
            if (data.comparison) root.setupComparison = data.comparison
            var ok = data.ok === true && exitCode === 0
            var message = data.message || next.fallback || (ok ? "Done" : "Build Network action failed")
            root.lastNotice = message
            root.actionResult(ok, message)
            Qt.callLater(root.processActionQueue)
        })
        proc.running = true
    }

    function refreshLocal() {
        if (!root.busy && root.actionQueue.length === 0 && !refreshProc.running && !statusProc.running)
            statusProc.running = true
    }

    function refreshNetwork() {
        if (!root.busy && root.actionQueue.length === 0 && !statusProc.running && !refreshProc.running) {
            root.busy = true
            refreshProc.running = true
        }
    }

    function inspectSetup() { run("inspect-setup", null, "Setup inspected") }
    function inspectEnvironment() { run("inspect-environment", null, "Environment inspected") }
    function compareSetup(setupId) { run("compare-setup", { setup_id: setupId }, "Setup comparison ready") }
    function createIdea(title, summary, tags) { run("create-idea", { title: title, summary: summary, tags: tags || [] }, "Idea shared") }
    function markInterested(ideaId, note) { run("interest", { idea_id: ideaId, note: note || "" }, "Marked interested") }
    function createRoom(title, goal, repoUrl, roles, tasks, sourceIdeaId) { run("create-room", { title: title, goal: goal, repo_url: repoUrl || "", roles_needed: roles || [], tasks: tasks || [], source_idea_id: sourceIdeaId || "" }, "Build Room opened") }
    function buildIdea(ideaId, repoUrl, roles) { run("room-from-idea", { idea_id: ideaId, repo_url: repoUrl || "", roles_needed: roles || [] }, "Idea promoted to Build Room") }
    function joinRoom(roomId, role, note) { run("join-room", { room_id: roomId, role: role || "Builder", note: note || "" }, "Joined Build Room") }
    function taskUpdate(roomId, task, status, note) { run("task-update", { room_id: roomId, task: task, status: status || "doing", note: note || "" }, "Task updated") }
    function updateRoom(roomId, status, repoUrl) { run("update-room", { room_id: roomId, status: status || "building", repo_url: repoUrl || "" }, "Build Room updated") }
    function createSetup(title, repoUrl, wallpaperUrl, notes, useDetected) { run("create-setup", { title: title, repo_url: repoUrl || "", wallpaper_url: wallpaperUrl || "", notes: notes || "", use_detected: useDetected !== false }, "Setup shared") }
    function shareComponent(type, name, sourceUrl, setupId, tags, notes) { run("share-component", { component_type: type || "other", name: name, source_url: sourceUrl || "", setup_id: setupId || "", tags: tags || [], notes: notes || "" }, "Component shared") }
    function createTest(title, artifactUrl, version, requestedTags, notes, roomId) { run("create-test", { title: title, artifact_url: artifactUrl || "", version: version || "", requested_tags: requestedTags || [], notes: notes || "", build_room_id: roomId || "" }, "Test request shared") }
    function submitTestResult(requestId, result, tags, note) { run("test-result", { request_id: requestId, result: result, environment_tags: tags || [], note: note || "" }, "Test result shared") }
    function createHelp(title, problem, tried, environmentTags, useDetected) { run("create-help", { title: title, problem: problem, tried: tried || "", environment_tags: environmentTags || [], use_detected: useDetected === true }, "Help request shared") }
    function offerHelp(helpId, note, useDetected) { run("offer-help", { help_id: helpId, note: note || "", use_detected: useDetected !== false }, "Offered to help") }
    function resolveHelp(helpId, status) { run("resolve-help", { help_id: helpId, status: status || "solved" }, "Help request updated") }
    function setAvailability(mode, skills, note, minutes, status) { run("set-availability", { mode: mode || "can_help", skills: skills || [], note: note || "", available_minutes: minutes || 30, status: status || "active", use_detected: true }, "Availability shared") }
    function createSolution(title, problem, solution, environmentTags, sourceUrl) { run("create-solution", { title: title, problem: problem || "", solution: solution, environment_tags: environmentTags || [], source_url: sourceUrl || "" }, "Solution saved") }
    function solutionFromHelp(helpId, solution, title, sourceUrl) { run("solution-from-help", { help_id: helpId, solution: solution, title: title || "", source_url: sourceUrl || "" }, "Help converted to solution") }
    function verifySolution(solutionId, result, note, useDetected) { run("verify-solution", { solution_id: solutionId, result: result || "worked", note: note || "", use_detected: useDetected !== false }, "Verification shared") }
    function ship(title, summary, artifactUrl, tags, roomId) { run("ship", { title: title, summary: summary || "", artifact_url: artifactUrl || "", tags: tags || [], build_room_id: roomId || "" }, "Ship post shared") }
    function reportUpdate(version, result, environmentTags, note, useDetected) { run("report-update", { version: version, result: result, environment_tags: environmentTags || [], note: note || "", use_detected: useDetected !== false }, "Update report shared") }
    function createEvent(title, whenText, location, eventUrl, notes) { run("create-event", { title: title, when_text: whenText || "", location: location || "", event_url: eventUrl || "", notes: notes || "" }, "Event shared") }
    function rsvpEvent(eventId, response, note) { run("rsvp-event", { event_id: eventId, response: response || "interested", note: note || "" }, "RSVP shared") }
    function createChallenge(title, prompt, deadlineText, rulesUrl, tags) { run("create-challenge", { title: title, prompt: prompt || "", deadline_text: deadlineText || "", rules_url: rulesUrl || "", tags: tags || [] }, "Challenge shared") }
    function joinChallenge(challengeId, teamName, repoUrl, note) { run("join-challenge", { challenge_id: challengeId, team_name: teamName || "", repo_url: repoUrl || "", note: note || "" }, "Joined challenge") }
    function publishProjectActivity(type, title, url, roomId, repoUrl, state, reference) { run("project-activity", { activity_type: type || "discussion", title: title, url: url || "", room_id: roomId || "", repo_url: repoUrl || "", state: state || "info", reference: reference || "" }, "Project activity shared") }
    function loadGithubSnapshot(repoUrl) { run("github-snapshot", { repo_url: repoUrl }, "GitHub activity loaded") }
    function generateShareText(objectId) { run("share-text", { id: objectId }, "Share text ready") }
    function registerInviteLinks() { run("register-uri", null, "Invite link handler registered") }
    function health() { run("health", null, "Release health ready") }
    function saveObject(objectId) { run("save", { id: objectId }, "Saved") }
    function hideObject(publicKey, objectId) { run("hide", { public_key: publicKey || "", id: objectId || "" }, "Hidden") }

    Component {
        id: actionComponent
        Process {
            id: actionProc
            property string resultText: ""
            signal completed(string output, int exitCode)
            stdout: StdioCollector { onStreamFinished: actionProc.resultText = this.text }
            onExited: function(exitCode) { completed(resultText, exitCode); destroy() }
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
        onExited: Qt.callLater(root.processActionQueue)
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
            Qt.callLater(root.processActionQueue)
        }
    }

    Timer { interval: 7000; repeat: true; running: true; onTriggered: root.refreshLocal() }
    Timer { interval: 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refreshNetwork() }

    Component.onCompleted: {
        root.refreshLocal()
        root.inspectSetup()
        root.inspectEnvironment()
    }
}
