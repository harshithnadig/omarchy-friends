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
    if ("overlay" in target) target.overlay = overlayLoader.item
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  implicitWidth: pill.implicitWidth
  implicitHeight: pill.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: overlayLoader
    active: true
    source: Qt.resolvedUrl("FlybyOverlay.qml")
  }

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

    leftIcon: "✈️"
    text: panelLoader.item ? (panelLoader.item.sealIcon + " " + panelLoader.item.planesAloft) : "✈️"
    tooltipText: panelLoader.item ? 
      ("Paper Plane Skyway: " + panelLoader.item.planesAloft + " planes aloft\nActive fold: " + panelLoader.item.foldName + " • Seal: " + panelLoader.item.sealIcon + " " + panelLoader.item.sealLabel + "\nClick for Flight Deck • Middle-click to launch") : 
      "Omarchy Paper Plane Skyway"

    onClicked: root.togglePanel()
    onMiddleClicked: {
      if (panelLoader.item) {
        panelLoader.item.launchPlane()
      }
    }
  }
}
