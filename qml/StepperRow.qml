pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import WallpaperBrowser

ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property int value
    property int from: 0
    property int to: 99
    property int stepSize: 1

    signal moved(value: int)

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: label

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        StyledSpinBox {
            from: root.from
            to: root.to
            stepSize: root.stepSize
            value: root.value
            cLayer: 2
            onValueModified: root.moved(value)
        }
    }
}
