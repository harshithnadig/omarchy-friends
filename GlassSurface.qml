import QtQuick
import qs.Commons

Item {
    id: root

    property real radius: Style.space(18)
    property real fillOpacity: 0.70
    property real borderOpacity: 0.13
    property real glowOpacity: 0.18
    property bool elevated: false
    property bool selected: false
    property color accentColor: "#8b7cff"
    property color baseColor: "#07101f"
    property color secondaryColor: "#131c36"
    property color coolTint: "#55d9ff"
    property color warmTint: "#ff6bcf"

    // Soft outer bloom. Kept in plain QtQuick so the glass treatment works on
    // the same runtime that already passed Omarchy qmllint/validation.
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.elevated ? -Style.space(6) : -Style.space(2)
        radius: root.radius + Style.space(6)
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b,
                              root.selected ? 0.50 : (root.elevated ? root.glowOpacity : root.glowOpacity * 0.52))
        opacity: root.elevated || root.selected ? 1 : 0.76
    }

    Rectangle {
        id: glassBody
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(root.secondaryColor.r, root.secondaryColor.g, root.secondaryColor.b,
                               Math.min(1, root.fillOpacity + 0.10))
            }
            GradientStop {
                position: 0.50
                color: Qt.rgba(root.baseColor.r, root.baseColor.g, root.baseColor.b,
                               Math.max(0.28, root.fillOpacity - 0.06))
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0.018, 0.035, 0.080, Math.min(1, root.fillOpacity + 0.01))
            }
        }
        border.width: 1
        border.color: root.selected
            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.58)
            : Qt.rgba(0.84, 0.90, 1.0, root.borderOpacity)
    }

    // Liquid colour pools. They are intentionally subtle: enough colour to
    // separate surfaces without turning the panel into a neon dashboard.
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            width: Math.min(parent.width * 0.72, Style.space(190))
            height: width
            radius: width / 2
            x: -width * 0.34
            y: -height * 0.48
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b,
                           root.selected ? 0.17 : 0.085)
        }

        Rectangle {
            width: Math.min(parent.width * 0.58, Style.space(160))
            height: width
            radius: width / 2
            x: parent.width - width * 0.62
            y: parent.height - height * 0.44
            color: Qt.rgba(root.coolTint.r, root.coolTint.g, root.coolTint.b,
                           root.selected ? 0.10 : 0.048)
        }

        Rectangle {
            visible: root.elevated
            width: Math.min(parent.width * 0.42, Style.space(120))
            height: width
            radius: width / 2
            x: parent.width * 0.58
            y: -height * 0.42
            color: Qt.rgba(root.warmTint.r, root.warmTint.g, root.warmTint.b, 0.050)
        }
    }

    // Specular rim: this is what gives the surfaces the wet/liquid edge in
    // motion while avoiding extra Qt effect-module dependencies.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        anchors.topMargin: 1
        height: Math.max(2, root.radius * 0.84)
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, root.selected ? 0.13 : 0.075) }
            GradientStop { position: 0.58; color: Qt.rgba(0.72, 0.82, 1.0, 0.025) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Style.space(4)
        anchors.rightMargin: Style.space(4)
        height: Math.max(1, root.radius * 0.58)
        radius: root.radius
        color: Qt.rgba(0, 0, 0, root.elevated ? 0.20 : 0.10)
    }
}
