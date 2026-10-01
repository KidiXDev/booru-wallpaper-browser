import QtQuick
import WallpaperBrowser

ColorAnimation {
    duration: Tokens.anim.durations.expressiveSlowEffects
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Tokens.anim.curves.expressiveSlowEffects
}
