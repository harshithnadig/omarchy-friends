import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "community.omarchy-friends"
  ipcTarget: "community.omarchy-friends.panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var overlay: null
  readonly property var barIdentity: hostWidget || root

  readonly property string scriptPath:
    Qt.resolvedUrl("bin/omarchy-friends").toString().replace(/^file:\/\//, "")

  property string hangarId: "AERO-0000"
  property string activeFold: "dart"
  property string foldName: "Classic Dart"
  property string foldIcon: "✈️"
  property string activeSeal: "focus"
  property string sealLabel: "Deep Focus"
  property string sealIcon: "🌿"
  property string sealDesc: ""
  property int planesAloft: 38
  property bool canLaunch: true
  property int cooldownSeconds: 0
  property real cooldownProgress: 1.0
  property int totalLaunched: 0
  property int totalCaught: 0
  property int totalKm: 28450
  property var jetstream: ({ speed_kmh: 190, altitude_ft: 31000, direction: "Westerly" })
  property var passportStamps: []
  property var flightLog: []
  property var availableFolds: []
  property var availableSeals: []

  readonly property color fg: bar ? bar.foreground : Color.popups.text
  readonly property color bg: Color.popups.background
  readonly property color accent: Color.accent
  readonly property string fontFam: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
    root.refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function refresh() {
    statusProcess.running = true
  }

  function setFold(foldId) {
    activeFold = foldId
    setFoldProcess.targetFold = foldId
    setFoldProcess.running = true
  }

  function setSeal(sealId) {
    activeSeal = sealId
    setSealProcess.targetSeal = sealId
    setSealProcess.running = true
  }

  function launchPlane() {
    if (!canLaunch) return
    launchProcess.running = true
    if (root.overlay) {
      root.overlay.trigger("🍃", "Your Sky", root.sealIcon)
    }
  }

  function testFlyby() {
    if (root.overlay) {
      var sampleFlags = ["🇯🇵", "🇩🇪", "🇸🇪", "🇨🇭", "🇮🇸", "🇫🇮"]
      var sampleCities = ["Tokyo", "Munich", "Stockholm", "Zurich", "Reykjavik", "Helsinki"]
      var idx = Math.floor(Math.random() * sampleFlags.length)
      root.overlay.trigger(sampleFlags[idx], sampleCities[idx], root.sealIcon)
    }
  }

  function copyInvite() {
    inviteProcess.running = true
  }

  Process {
    id: statusProcess
    command: ["python3", root.scriptPath, "status"]
    stdout: StdioCollector {
      onDataChanged: {
        try {
          var data = JSON.parse(value.trim())
          root.hangarId = data.hangar_id || "AERO-0000"
          root.activeFold = data.active_fold || "dart"
          root.foldName = data.fold_name || "Classic Dart"
          root.foldIcon = data.fold_icon || "✈️"
          root.activeSeal = data.active_seal || "focus"
          root.sealLabel = data.seal_label || "Deep Focus"
          root.sealIcon = data.seal_icon || "🌿"
          root.sealDesc = data.seal_desc || ""
          root.planesAloft = data.planes_aloft || 38
          root.canLaunch = data.can_launch !== false
          root.cooldownSeconds = data.cooldown_seconds || 0
          root.cooldownProgress = data.cooldown_progress !== undefined ? data.cooldown_progress : 1.0
          root.totalLaunched = data.total_launched || 0
          root.totalCaught = data.total_caught || 0
          root.totalKm = data.total_km || 0
          root.jetstream = data.jetstream || { speed_kmh: 190, altitude_ft: 31000, direction: "Westerly" }
          root.passportStamps = data.passport_stamps || []
          root.flightLog = data.flight_log || []
          root.availableFolds = data.available_folds || []
          root.availableSeals = data.available_seals || []
        } catch (e) {}
      }
    }
  }

  Process {
    id: setFoldProcess
    property string targetFold: "dart"
    command: ["python3", root.scriptPath, "fold", targetFold]
    onExited: root.refresh()
  }

  Process {
    id: setSealProcess
    property string targetSeal: "focus"
    command: ["python3", root.scriptPath, "seal", targetSeal]
    onExited: root.refresh()
  }

  Process {
    id: launchProcess
    command: ["python3", root.scriptPath, "launch", root.activeFold, root.activeSeal]
    onExited: root.refresh()
  }

  Process {
    id: inviteProcess
    command: ["python3", root.scriptPath, "invite"]
  }

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  PanelController {
    id: controller
    panel: root
    anchorItem: root.anchorItem
    bar: root.bar
    exclusiveGroup: root.bar ? root.bar.panelGroup : null
  }

  implicitWidth: 420
  implicitHeight: contentColumn.implicitHeight + Style.marginL * 2

  Rectangle {
    anchors.fill: parent
    color: root.bg
    radius: Style.radiusL
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
    border.width: 1

    ColumnLayout {
      id: contentColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // Header: Cockpit Bar
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Text {
          text: "✈️"
          font.pixelSize: 28
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          RowLayout {
            spacing: 8
            Text {
              text: "Paper Plane Skyway"
              font.family: root.fontFam
              font.pixelSize: Style.fontSizeL
              font.bold: true
              color: root.fg
            }

            Rectangle {
              height: 18
              width: hangarText.implicitWidth + 8
              radius: 4
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)

              Text {
                id: hangarText
                anchors.centerIn: parent
                text: root.hangarId
                font.family: root.fontFam
                font.pixelSize: 10
                font.bold: true
                color: root.accent
              }
            }
          }

          Text {
            text: root.planesAloft + " planes aloft in the global jetstream right now"
            font.family: root.fontFam
            font.pixelSize: Style.fontSizeS
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.65)
          }
        }

        Rectangle {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          radius: 14
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)

          Text {
            anchors.centerIn: parent
            text: "󰑐"
            font.family: root.fontFam
            font.pixelSize: 14
            color: root.fg
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.refresh()
          }
        }
      }

      // Atmospheric Jetstream Gauge
      Rectangle {
        Layout.fillWidth: true
        height: 38
        radius: Style.radiusM
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)

        RowLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 12

          Text {
            text: "🍃 " + root.jetstream.direction + " " + root.jetstream.speed_kmh + " km/h"
            font.family: root.fontFam
            font.pixelSize: Style.fontSizeS
            font.bold: true
            color: root.accent
          }

          Item { Layout.fillWidth: true }

          Text {
            text: "⛅ Altitude " + (root.jetstream.altitude_ft).toLocaleString() + " ft"
            font.family: root.fontFam
            font.pixelSize: Style.fontSizeS
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.7)
          }

          Text {
            text: "🌍 " + (root.totalKm).toLocaleString() + " km drifted"
            font.family: root.fontFam
            font.pixelSize: Style.fontSizeS
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.7)
          }
        }
      }

      // Fold Selection
      Text {
        text: "1. CHOOSE ORIGAMI FOLD"
        font.family: root.fontFam
        font.pixelSize: Style.fontSizeXS
        font.bold: true
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: root.availableFolds
          delegate: Rectangle {
            Layout.fillWidth: true
            height: 34
            radius: 8
            color: root.activeFold === modelData.id ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
            border.color: root.activeFold === modelData.id ? root.accent : Qt.transparent
            border.width: 1

            RowLayout {
              anchors.centerIn: parent
              spacing: 4

              Text {
                text: modelData.icon
                font.pixelSize: 14
              }

              Text {
                text: modelData.name
                font.family: root.fontFam
                font.pixelSize: Style.fontSizeS
                font.bold: root.activeFold === modelData.id
                color: root.activeFold === modelData.id ? root.accent : root.fg
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setFold(modelData.id)
            }
          }
        }
      }

      // Seal Selection
      Text {
        text: "2. CHOOSE TRAVEL SEAL"
        font.family: root.fontFam
        font.pixelSize: Style.fontSizeXS
        font.bold: true
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
      }

      Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: root.availableSeals
          delegate: Rectangle {
            width: sealRow.implicitWidth + 14
            height: 30
            radius: 15
            color: root.activeSeal === modelData.id ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
            border.color: root.activeSeal === modelData.id ? root.accent : Qt.transparent
            border.width: 1

            RowLayout {
              id: sealRow
              anchors.centerIn: parent
              spacing: 6

              Text {
                text: modelData.icon
                font.pixelSize: 13
              }

              Text {
                text: modelData.label
                font.family: root.fontFam
                font.pixelSize: Style.fontSizeS
                font.bold: root.activeSeal === modelData.id
                color: root.activeSeal === modelData.id ? root.accent : root.fg
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setSeal(modelData.id)
            }
          }
        }
      }

      // Launch Action Button
      Rectangle {
        Layout.fillWidth: true
        height: 48
        radius: Style.radiusM
        color: root.canLaunch ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.marginM

          Text {
            text: root.canLaunch ? root.foldIcon : "⏳"
            font.pixelSize: 20
          }

          Text {
            text: root.canLaunch ? 
              ("Launch into Jetstream (" + root.foldName + " · " + root.sealIcon + " " + root.sealLabel + ")") : 
              ("Next plane ready in " + Math.ceil(root.cooldownSeconds / 60) + "m")
            font.family: root.fontFam
            font.pixelSize: Style.fontSizeM
            font.bold: true
            color: root.canLaunch ? Color.accentText : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.6)
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: root.canLaunch
          cursorShape: root.canLaunch ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.launchPlane()
        }
      }

      // Passport Stamp Collection
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "PASSPORT STAMPS:"
          font.family: root.fontFam
          font.pixelSize: Style.fontSizeXS
          font.bold: true
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
        }

        Row {
          spacing: 4
          Repeater {
            model: root.passportStamps
            delegate: Text {
              text: modelData
              font.pixelSize: 18
            }
          }
        }
      }

      // Recent Airspace Landings
      Text {
        text: "RECENT AIRSPACE ARRIVALS"
        font.family: root.fontFam
        font.pixelSize: Style.fontSizeXS
        font.bold: true
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: root.flightLog.slice(0, 3)
          delegate: Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: Style.radiusS
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)

            RowLayout {
              anchors.fill: parent
              anchors.margins: 8
              spacing: 8

              Text {
                text: modelData.flag
                font.pixelSize: 16
              }

              ColumnLayout {
                spacing: 1
                Layout.fillWidth: true

                RowLayout {
                  spacing: 6
                  Text {
                    text: modelData.origin + " ➔ " + modelData.destination
                    font.family: root.fontFam
                    font.pixelSize: Style.fontSizeS
                    font.bold: true
                    color: root.fg
                  }

                  Text {
                    text: "· " + modelData.distance_km.toLocaleString() + " km"
                    font.family: root.fontFam
                    font.pixelSize: Style.fontSizeXS
                    color: root.accent
                  }
                }

                Text {
                  text: modelData.status
                  font.family: root.fontFam
                  font.pixelSize: 10
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.6)
                  elide: Text.ElideRight
                }
              }

              Text {
                text: modelData.seal_icon
                font.pixelSize: 15
              }

              Text {
                text: modelData.time_ago
                font.family: root.fontFam
                font.pixelSize: Style.fontSizeXS
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.45)
              }
            }
          }
        }
      }

      // Footer
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Button {
          Layout.fillWidth: true
          text: "✈️ Test Screen Flyby"
          onClicked: root.testFlyby()
        }

        Button {
          text: "📋 Invite"
          onClicked: root.copyInvite()
        }

        Button {
          text: "Close"
          onClicked: root.close()
        }
      }
    }
  }
}
