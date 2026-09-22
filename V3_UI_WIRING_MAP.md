# V3 UI wiring map — zero invention required

The backend and `BuildNetworkService.qml` already expose every action below. If the real-system pass chooses to surface these inside `BuildNetworkPanelV3.qml`, do **not** design new backend behavior. Add controls in the listed existing tabs and call exactly these methods.

## Help tab — Can Help / Pair

Place near the Help heading or before help requests.

```qml
build.setAvailability("can_help", root.csv(skillsDraft), noteDraft, 30, "active")
build.setAvailability("pair", root.csv(skillsDraft), noteDraft, 60, "active")
build.setAvailability("can_help", [], "", 30, "closed")
```

Data already exposed:

```qml
build.helpers
build.pairing
modelData.helper_matches   // on each help request after status/refresh
```

For a helper match, route private follow-up through the existing Friends chat using the same `root.connectBuilder(modelData.public_key)` helper already used elsewhere.

## Share/Test tab — share one setup component

Place immediately below Setup Cards.

```qml
build.shareComponent(
    "plugin",            // theme/plugin/bar/wallpaper/font/terminal/editor/shell/keybindings/other
    componentName,
    sourceUrl,
    setupId,
    root.csv(tagsDraft),
    notesDraft
)
```

Data:

```qml
build.setupComponents
modelData.shared_components  // attached to Setup Cards after refresh
```

Do not add an Install button. Allowed actions are Save / Copy / Open HTTP(S) source / Chat.

## Build tab — public GitHub pulse

A Build Room already has `repo_url`. Add a user-triggered refresh action, never background credential scraping:

```qml
build.loadGithubSnapshot(modelData.repo_url)
```

Returned local-only data:

```qml
build.githubSnapshot.repo_url
build.githubSnapshot.items
```

Each item contains:

```text
activity_type: commit | pull_request | issue
state
reference
url
title
```

Allow the room owner/user to explicitly publish a selected item:

```qml
build.publishProjectActivity(
    item.activity_type,
    item.title,
    item.url,
    room.id,
    room.repo_url,
    item.state,
    item.reference
)
```

Published data:

```qml
build.projectActivity
room.project_activity
```

Do not request GitHub tokens. V3 snapshot is public-repository metadata only.

## Help tab — turn solved help into community memory

On a help request owned by the current user after a solution is known:

```qml
build.solutionFromHelp(
    modelData.id,
    solutionDraft,
    modelData.title,
    ""
)
```

This reuses the original problem/environment instead of making the user retype it.

Never auto-publish a private DM transcript.

## Discover / card overflow — external share text

For any public Build Network object:

```qml
build.generateShareText(modelData.id)
```

Listen for:

```qml
Connections {
    target: build
    function onShareTextReady(text) {
        root.copyText(text, "Share text copied")
    }
}
```

This produces a compact Idea/Build/Setup/Help/Solution/Ship/Event/Challenge/Project Activity share block with an external URL when one exists.

## Me / startup diagnostics — invite URI handler

Normally V3 status performs idempotent local registration automatically. Optional explicit repair button:

```qml
build.registerInviteLinks()
```

Validate on the machine:

```bash
xdg-mime query default x-scheme-handler/omarchy-friends
```

Do not hard-code the checkout path; the V3 runtime builds the `.desktop` entry from the actual installed `bin/omarchy-friends-open` path.

## Existing functions that must NOT be duplicated

Use the existing methods rather than creating competing UI/backend paths:

```text
createIdea / markInterested / buildIdea
createRoom / joinRoom / taskUpdate / updateRoom
createSetup / compareSetup
createTest / submitTestResult
createHelp / offerHelp / resolveHelp
createSolution / verifySolution
ship
reportUpdate
createEvent / rsvpEvent
createChallenge / joinChallenge
saveObject / hideObject
```

## Visual rule

Use the existing `GlassSurface.qml` and `GlassPill.qml` families. Do not introduce a new visual system or another panel generation. The only acceptable real-system work is placing these already-implemented actions into the most natural V3 section and fixing QML/runtime issues.
