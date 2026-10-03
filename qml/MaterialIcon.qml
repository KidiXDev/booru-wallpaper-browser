import QtQuick
import WallpaperBrowser

StyledText {
    id: root

    property real fill
    property int grade: Colours.light ? 0 : -25
    property font fontStyle: Tokens.font.icon.small

    font: Qt.font({
        family: Tokens.font.icon.small.family, // fontStyle only sets size/weight, like upstream
        pointSize: fontStyle.pointSize,
        weight: fontStyle.weight,
        // Hinting snapped glyphs up to 1.5px high at 1x (heart, wallpaper), off-centre in round
        // buttons. The icons are drawn on a 24-unit grid, so they stay crisp without it
        hintingPreference: Font.PreferNoHinting,
        variableAxes: {
            FILL: root.fill,
            GRAD: root.grade,
            opsz: root.fontStyle.pointSize,
            wght: root.fontStyle.weight
        }
    })
}
