import QtQuick
import qs.Commons

QtObject {
    id: root

    readonly property color seed: Color.accent
    readonly property color background: Color.background
    readonly property color foreground: Color.foreground
    readonly property bool light: luminance(background) > 0.5

    function clamp(value, low, high) {
        return Math.max(low, Math.min(high, Number(value) || 0))
    }

    function linear(value) {
        var channel = clamp(value, 0, 1)
        return channel <= 0.04045
            ? channel / 12.92
            : Math.pow((channel + 0.055) / 1.055, 2.4)
    }

    function luminance(value) {
        return 0.2126 * linear(value.r) + 0.7152 * linear(value.g) + 0.0722 * linear(value.b)
    }

    function contrast(first, second) {
        var high = Math.max(luminance(first), luminance(second))
        var low = Math.min(luminance(first), luminance(second))
        return (high + 0.05) / (low + 0.05)
    }

    function onColor(fill) {
        var black = Qt.rgba(0, 0, 0, 1)
        var white = Qt.rgba(1, 1, 1, 1)
        return contrast(fill, black) >= contrast(fill, white) ? black : white
    }

    function mix(first, second, amount) {
        var t = clamp(amount, 0, 1)
        return Qt.rgba(
            first.r + (second.r - first.r) * t,
            first.g + (second.g - first.g) * t,
            first.b + (second.b - first.b) * t,
            first.a + (second.a - first.a) * t
        )
    }

    function hue(value) {
        var maximum = Math.max(value.r, value.g, value.b)
        var minimum = Math.min(value.r, value.g, value.b)
        var delta = maximum - minimum
        if (delta === 0) return 0
        var h = maximum === value.r
            ? ((value.g - value.b) / delta) % 6
            : maximum === value.g
                ? (value.b - value.r) / delta + 2
                : (value.r - value.g) / delta + 4
        return ((h / 6) + 1) % 1
    }

    function saturation(value) {
        var maximum = Math.max(value.r, value.g, value.b)
        var minimum = Math.min(value.r, value.g, value.b)
        var lightness = (maximum + minimum) / 2
        var delta = maximum - minimum
        return delta === 0 ? 0 : delta / (1 - Math.abs(2 * lightness - 1))
    }

    readonly property color primary: seed
    readonly property color onPrimary: onColor(primary)
    readonly property color secondary: Qt.hsla(
        hue(seed), clamp(saturation(seed) * 0.48, 0.16, 0.54), light ? 0.39 : 0.76, 1)
    readonly property color onSecondary: onColor(secondary)
    readonly property color tertiary: Qt.hsla(
        (hue(seed) + 0.14) % 1, clamp(Math.max(0.34, saturation(seed) * 0.72), 0.34, 0.64), light ? 0.41 : 0.72, 1)
    readonly property color onTertiary: onColor(tertiary)

    readonly property color surface: background
    readonly property color surfaceDim: mix(background, foreground, light ? 0.035 : 0.015)
    readonly property color surfaceBright: mix(background, foreground, light ? 0.11 : 0.22)
    readonly property color surfaceContainerLowest: mix(background, foreground, light ? 0.015 : 0.025)
    readonly property color surfaceContainerLow: mix(background, foreground, light ? 0.035 : 0.06)
    readonly property color surfaceContainer: mix(background, foreground, light ? 0.06 : 0.095)
    readonly property color surfaceContainerHigh: mix(background, foreground, light ? 0.09 : 0.14)
    readonly property color surfaceContainerHighest: mix(background, foreground, light ? 0.13 : 0.19)
    readonly property color surfaceVariant: surfaceContainerHighest
    readonly property color onSurface: foreground
    readonly property color onSurfaceVariant: mix(foreground, background, 0.3)
    readonly property color outline: mix(background, foreground, 0.43)
    readonly property color outlineVariant: mix(background, foreground, 0.21)

    readonly property color primaryContainer: mix(surfaceContainer, primary, light ? 0.17 : 0.30)
    readonly property color onPrimaryContainer: onColor(primaryContainer)
    readonly property color secondaryContainer: mix(surfaceContainer, secondary, light ? 0.12 : 0.22)
    readonly property color onSecondaryContainer: onColor(secondaryContainer)
    readonly property color tertiaryContainer: mix(surfaceContainer, tertiary, light ? 0.12 : 0.22)
    readonly property color onTertiaryContainer: onColor(tertiaryContainer)

    readonly property color success: Qt.hsla(0.38, 0.44, light ? 0.34 : 0.68, 1)
    readonly property color warning: Qt.hsla(0.12, 0.68, light ? 0.38 : 0.72, 1)
    readonly property color error: Color.urgent
}
