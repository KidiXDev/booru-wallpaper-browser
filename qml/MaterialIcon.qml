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
        variableAxes: {
            FILL: root.fill,
            GRAD: root.grade,
            opsz: root.fontStyle.pointSize,
            wght: root.fontStyle.weight
        }
    })
}
