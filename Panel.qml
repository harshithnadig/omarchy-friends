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
  readonly property var barIdentity: hostWidget || root

  readonly property string scriptPath:
    Qt.resolvedUrl("bin/omarchy-friends").toString().replace(/^file:\/\//, "")

  property string activeVibe: "focus"
  property string vibeLabel: "Deep Focus"
  property string vibeIcon: "🌿"
  property string vibeDesc: "Quiet deep work"
  property int campfirePeers: 42
  property bool canSpark: true
  property int cooldownSeconds: 0
  property real cooldownProgress: 1.0
  property int totalSent: 0
  property int totalReceived: 0
  property int starsCount: 3
  property int countriesCount: 3
  property var encounters: []
  property var availableVibes: []

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

  function setVibe(vibeId) {
    activeVibe = vibeId
    setVibeProcess.targetVibe = vibeId
    setVibeProcess.running = true
  }

  function sendSpark() {
    if (!canSpark) return
    sparkProcess.running = true
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
          root.activeVibe = data.active_vibe || "focus"
          root.vibeLabel = data.vibe_label || "Deep Focus"
          root.vibeIcon = data.vibe_icon || "🌿"
          root.vibeDesc = data.vibe_desc || ""
          root.campfirePeers = data.campfire_peers || 35
          root.canSpark = data.can_spark !== false
          root.cooldownSeconds = data.cooldown_seconds || 0
          root.cooldownProgress = data.cooldown_progress !== undefined ? data.cooldown_progress : 1.0
          root.totalSent = data.total_sent || 0
          root.totalReceived = data.total_received || 0
          root.starsCount = data.stars_count || 0
          root.countriesCount = data.countries_count || 0
          root.encounters = data.encounters || []
          root.availableVibes = data.available_vibes || []
        } catch (e) {}
      }
    }
  }

  Process {
    id: setVibeProcess
    property string targetVibe: "focus"
    command: ["python3", root.scriptPath, "vibe", targetVibe]
    onExited: root.refresh()
  }

  Process {
    id: sparkProcess
    command: ["python3", root.scriptPath, "spark", root.activeVibe]
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

  implicitWidth: 380
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

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Text {
          text: "🔥"
          font.pixelSize: 26
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Text {
            text: "Omarchy Campfire"
            font.family: root.fontFam
            font.pixelSize: Style.fontSizeL
            font.bold: true
            color: root.fg
          }

          Text {
            text: root.campfirePeers + " friends around the fire right now"
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

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
      }

      // Vibe Selector Section
      Text {
        text: "CHOOSE YOUR AMBIENT VIBE"
        font.family: root.fontFam
        font.pixelSize: Style.fontSizeXS
        font.bold: true
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
      }

      Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: root.availableVibes
          delegate: Rectangle {
            width: vibeRow.implicitWidth + 16
            height: 32
            radius: 16
            color: root.activeVibe === modelData.id ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
            border.color: root.activeVibe === modelData.id ? root.accent : Qt.transparent
            border.width: 1

            RowLayout {
              id: vibeRow
              anchors.centerIn: parent
              spacing: 6

              Text {
                text: modelData.icon
                font.pixelSize: 14
              }

              Text {
                text: modelData.label
                font.family: root.fontFam
                font.pixelSize: Style.fontSizeS
                font.bold: root.activeVibe === modelData.id
                color: root.activeVibe === modelData.id ? root.accent : root.fg
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setVibe(modelData.id)
            }
          }
        }
      }

      // Spark Action Button
      Rectangle {
        Layout.fillWidth: true
        height: 48
        radius: Style.radiusM
        color: root.canSpark ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.marginM

          Text {
            text: root.canSpark ? "🔥" : "⏳"
            font.pixelSize: 18
          }

          Text {
            text: root.canSpark ? 
              ("Toss a Spark to the Campfire (" + root.vibeIcon + " " + root.vibeLabel + ")") : 
              ("Next spark ready in " + Math.ceil(root.cooldownSeconds / 60) + "m")
            font.family: root.fontFam
            font.pixelSize: Style.fontSizeM
            font.bold: true
            color: root.canSpark ? Color.accentText : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.6)
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: root.canSpark
          cursorShape: root.canSpark ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.sendSpark()
        }
      }

      // Constellation Stats Row
      Rectangle {
        Layout.fillWidth: true
        height: 42
        radius: Style.radiusM
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginL

          Text {
            text: "✨ Constellation: " + root.starsCount + " stars"
            font.family: root.fontFam
            font.pixelSize: Style.fontSizeS
            font.bold: true
            color: root.fg
          }

          Item { Layout.fillWidth: true }

          Text {
            text: "🌍 " + root.countriesCount + " countries"
            font.family: root.fontFam
            font.pixelSize: Style.fontSizeS
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.7)
          }

          Text {
            text: "🔥 " + root.totalSent + " sparks sent"
            font.family: root.fontFam
            font.pixelSize: Style.fontSizeS
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.7)
          }
        }
      }

      // Recent Encounters Title
      Text {
        text: "RECENT CAMPFIRE ENCOUNTERS"
        font.family: root.fontFam
        font.pixelSize: Style.fontSizeXS
        font.bold: true
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
      }

      // Encounters List
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: root.encounters.slice(0, 4)
          delegate: Rectangle {
            Layout.fillWidth: true
            height: 38
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

              Text {
                text: modelData.country
                font.family: root.fontFam
                font.pixelSize: Style.fontSizeS
                font.bold: true
                color: root.fg
              }

              Text {
                text: "· " + modelData.note
                font.family: root.fontFam
                font.pixelSize: Style.fontSizeS
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.7)
                elide: Text.ElideRight
                Layout.fillWidth: true
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
          text: "📋 Copy Friend Invite"
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
