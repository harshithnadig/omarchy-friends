import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Variants {
  id: root
  model: Quickshell.screens

  property string planeFlag: "🇯🇵"
  property string planeOrigin: "Tokyo"
  property string planeSeal: "🌙"
  property bool active: false

  function trigger(flag, origin, seal) {
    planeFlag = flag || "✨"
    planeOrigin = origin || "The Jetstream"
    planeSeal = seal || "✈️"
    active = true
    flyAnimation.restart()
  }

  PanelWindow {
    id: window
    required property var modelData
    screen: modelData

    visible: root.active
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // 100% Click-through: never intercepts user mouse clicks
    mask: Region {}

    WlrLayershell.namespace: "omarchy-paper-plane-flyby"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Item {
      id: planeContainer
      width: 140
      height: 44
      y: 70 + Math.sin(x / 80.0) * 18
      x: -180

      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Jetstream Dashed Trail
        Text {
          text: "- - - 🍃"
          font.pixelSize: 13
          color: Qt.rgba(1.0, 1.0, 1.0, 0.45)
          anchors.verticalCenter: parent.verticalCenter
        }

        // Origami Plane
        Text {
          text: "✈️"
          font.pixelSize: 22
          anchors.verticalCenter: parent.verticalCenter
          rotation: -5 + Math.sin(planeContainer.x / 60.0) * 8
        }

        // Flight Pill
        Rectangle {
          height: 26
          width: flightText.implicitWidth + 14
          radius: 13
          color: Qt.rgba(0.08, 0.10, 0.14, 0.85)
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
          border.width: 1
          anchors.verticalCenter: parent.verticalCenter

          Row {
            id: flightText
            anchors.centerIn: parent
            spacing: 5

            Text {
              text: root.planeFlag
              font.pixelSize: 13
            }

            Text {
              text: root.planeOrigin + " " + root.planeSeal
              font.family: Style.font.family
              font.pixelSize: 11
              font.bold: true
              color: "#FFFFFF"
            }
          }
        }
      }

      NumberAnimation on x {
        id: flyAnimation
        running: false
        from: -200
        to: window.screen ? (window.screen.width + 200) : 2500
        duration: 4800
        easing.type: Easing.InOutQuad
        onFinished: {
          root.active = false
        }
      }
    }
  }
}
