pragma Singleton

import QtQuick
import WallpaperBrowser

// Same API as caelestia's Colours service (palette.m3<name>), fed from the shell's
// scheme.json. Polled so the app recolours with the shell, e.g. after setting a wallpaper
QtObject {
    id: root

    property string raw
    readonly property var scheme: {
        try {
            return JSON.parse(raw);
        } catch (e) {
            return {};
        }
    }
    readonly property bool light: scheme.mode === "light"
    readonly property M3Palette palette: M3Palette {
        colours: root.scheme.colours ?? {}
    }
    // The shell's transparent variant, this window is opaque so it's the same palette
    readonly property M3Palette tPalette: palette

    function reload(): void {
        const text = Booru.scheme();
        if (text !== raw)
            raw = text;
    }

    // Fallbacks are the shell's default scheme
    component M3Palette: QtObject {
        id: p

        required property var colours

        function get(name: string, fallback: string): color {
            const c = p.colours[name];
            return c ? `#${c}` : fallback;
        }

        readonly property color m3background: p.get("background", "#131317")
        readonly property color m3onBackground: p.get("onBackground", "#e4e1e7")
        readonly property color m3surface: p.get("surface", "#131317")
        readonly property color m3surfaceDim: p.get("surfaceDim", "#131317")
        readonly property color m3surfaceBright: p.get("surfaceBright", "#39393d")
        readonly property color m3surfaceContainerLowest: p.get("surfaceContainerLowest", "#0d0e12")
        readonly property color m3surfaceContainerLow: p.get("surfaceContainerLow", "#1b1b1f")
        readonly property color m3surfaceContainer: p.get("surfaceContainer", "#1f1f23")
        readonly property color m3surfaceContainerHigh: p.get("surfaceContainerHigh", "#292a2e")
        readonly property color m3surfaceContainerHighest: p.get("surfaceContainerHighest", "#343438")
        readonly property color m3onSurface: p.get("onSurface", "#e4e1e7")
        readonly property color m3surfaceVariant: p.get("surfaceVariant", "#45464f")
        readonly property color m3onSurfaceVariant: p.get("onSurfaceVariant", "#c6c5d1")
        readonly property color m3inverseSurface: p.get("inverseSurface", "#e4e1e7")
        readonly property color m3inverseOnSurface: p.get("inverseOnSurface", "#303034")
        readonly property color m3outline: p.get("outline", "#8f909a")
        readonly property color m3outlineVariant: p.get("outlineVariant", "#45464f")
        readonly property color m3shadow: p.get("shadow", "#000000")
        readonly property color m3scrim: p.get("scrim", "#000000")
        readonly property color m3primary: p.get("primary", "#b7c4ff")
        readonly property color m3onPrimary: p.get("onPrimary", "#1e2d60")
        readonly property color m3primaryContainer: p.get("primaryContainer", "#6674ac")
        readonly property color m3onPrimaryContainer: p.get("onPrimaryContainer", "#ffffff")
        readonly property color m3inversePrimary: p.get("inversePrimary", "#4e5c92")
        readonly property color m3secondary: p.get("secondary", "#c1c5e0")
        readonly property color m3onSecondary: p.get("onSecondary", "#2a2f44")
        readonly property color m3secondaryContainer: p.get("secondaryContainer", "#41465c")
        readonly property color m3onSecondaryContainer: p.get("onSecondaryContainer", "#afb4ce")
        readonly property color m3tertiary: p.get("tertiary", "#f1b3e6")
        readonly property color m3onTertiary: p.get("onTertiary", "#4c1f49")
        readonly property color m3tertiaryContainer: p.get("tertiaryContainer", "#b67fae")
        readonly property color m3onTertiaryContainer: p.get("onTertiaryContainer", "#000000")
        readonly property color m3error: p.get("error", "#ffb4ab")
        readonly property color m3onError: p.get("onError", "#690005")
        readonly property color m3errorContainer: p.get("errorContainer", "#93000a")
        readonly property color m3onErrorContainer: p.get("onErrorContainer", "#ffdad6")
        readonly property color m3success: p.get("success", "#b5ccba")
        readonly property color m3onSuccess: p.get("onSuccess", "#213528")
        readonly property color m3successContainer: p.get("successContainer", "#374b3e")
        readonly property color m3onSuccessContainer: p.get("onSuccessContainer", "#d1e9d6")
    }

    readonly property Timer poll: Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: root.reload()
    }
}
