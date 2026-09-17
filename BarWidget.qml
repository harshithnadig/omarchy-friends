import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "community.omarchy-friends"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = pill
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  implicitWidth: pill.implicitWidth
  implicitHeight: pill.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarPill {
    id: pill
    bar: root.bar
    active: root.opened
    useActiveColor: true
    activeColor: Color.accent

    leftIcon: "🔥"
    text: panelLoader.item ? (panelLoader.item.vibeIcon + " " + panelLoader.item.campfirePeers) : "🔥"
    tooltipText: panelLoader.item ? 
      ("Omarchy Friends: " + panelLoader.item.campfirePeers + " around the campfire\nVibe: " + panelLoader.item.vibeIcon + " " + panelLoader.item.vibeLabel + "\nClick to open campfire card • Middle-click to toss spark") : 
      "Omarchy Friends Campfire"

    onClicked: root.togglePanel()
    onMiddleClicked: {
      if (panelLoader.item) {
        panelLoader.item.sendSpark()
      }
    }
  }
}
