import QtQuick

// Keep the manifest entry point stable while delegating all behavior to the
// normal Friends service. v4.15 deliberately performs updates only after an
// explicit user action from the UI; no startup/background updater runs here.
Service {
    id: root
}
