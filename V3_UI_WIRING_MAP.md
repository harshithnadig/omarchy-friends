# Build Network V3 wiring map — completed v4.15 reference

The v4.15 Build Network UI is already wired. This file is a maintenance reference for the existing backend/UI paths; it is **not** a backlog asking a future agent to add duplicate controls.

## Active path

```text
BuildNetworkPanelV3.qml
  -> BuildNetworkService.qml
  -> bin/build_network_app_v4.py
```

`BuildNetworkService.qml` exposes the supported user actions. Keep using these methods rather than creating competing backend paths.

## Help — Can Help / Pair / Building

Existing actions:

```qml
build.setAvailability("can_help", skills, note, 30, "active")
build.setAvailability("pair", skills, note, 60, "active")
build.setAvailability("building", skills, note, 60, "active")
build.setAvailability("can_help", [], "", 30, "closed")
```

Existing data:

```qml
build.helpers
build.pairing
modelData.helper_matches
```

Private follow-up must route through the existing Friends chat handoff; do not create a second private messaging system.

## Share — setup components

Existing action:

```qml
build.shareComponent(
    componentType,
    componentName,
    sourceUrl,
    setupId,
    tags,
    notes
)
```

Existing data:

```qml
build.setupComponents
modelData.shared_components
```

There is intentionally no automatic Install/Apply action. Allowed workflows are review, compare, save/copy and open a safe HTTP(S) source.

## Build — public GitHub activity

Existing explicit public-repository snapshot action:

```qml
build.loadGithubSnapshot(modelData.repo_url)
```

Local result:

```qml
build.githubSnapshot.repo_url
build.githubSnapshot.items
```

Existing explicit publish action:

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

GitHub remains the source of truth. Friends never requests a GitHub token for this public snapshot helper.

## Help -> Solution

Existing action:

```qml
build.solutionFromHelp(
    modelData.id,
    solutionDraft,
    modelData.title,
    ""
)
```

This reuses the original public problem/environment context. Never auto-publish or summarize a private DM transcript.

## External sharing

Existing public-card share action:

```qml
build.generateShareText(modelData.id)
```

The service emits `shareTextReady(text)` and the UI copies the generated text explicitly.

## Invite/health maintenance

Existing actions include:

```qml
build.registerInviteLinks()
build.health()
```

Desktop registration must use the actual installed `bin/omarchy-friends-open` path; never hard-code a developer checkout.

## Core methods that must not be duplicated

```text
createIdea / markInterested / buildIdea
createRoom / joinRoom / taskUpdate / updateRoom
createSetup / compareSetup / shareComponent
createTest / submitTestResult
createHelp / offerHelp / resolveHelp / solutionFromHelp
createSolution / verifySolution
ship
reportUpdate
createEvent / rsvpEvent
createChallenge / joinChallenge
saveObject / hideObject
loadGithubSnapshot / publishProjectActivity
generateShareText / registerInviteLinks / health
```

## Visual rule

Build Network uses the same product palette and shared Glass primitives as Friends V3. Real-system work may fix concrete QML/render/input bugs, but must not introduce another Build panel generation or duplicate the existing action paths.
