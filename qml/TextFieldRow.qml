pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import WallpaperBrowser

// Port of caelestia modules/nexus/common/TextFieldRow.qml. The field is a plain outlined
// TextFieldBase instead of the shell's StyledTextField (no floating label or validation)
ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property string value
    property alias placeholderText: input.placeholderText
    property bool secret
    readonly property alias field: input

    signal editingFinished(value: string)

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + Tokens.padding.large * 2

    RowLayout {
        id: rowLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
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

        TextFieldBase {
            id: input

            Layout.preferredWidth: 320
            Layout.maximumWidth: root.width / 2
            Layout.alignment: Qt.AlignVCenter
            leftPadding: Tokens.padding.large
            rightPadding: Tokens.padding.large
            topPadding: Tokens.padding.small
            bottomPadding: Tokens.padding.small
            clip: true

            text: root.value
            echoMode: root.secret && !activeFocus ? TextInput.Password : TextInput.Normal
            onEditingFinished: {
                if (text !== root.value)
                    root.editingFinished(text);
            }

            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: input.leftPadding
                anchors.rightMargin: input.rightPadding
                visible: !input.text
                text: input.placeholderText
                color: Colours.palette.m3outline
                font: input.font
                elide: Text.ElideRight
            }

            background: StyledRect {
                radius: Tokens.rounding.small
                color: "transparent"
                border.width: input.activeFocus ? 2 : 1
                border.color: input.activeFocus ? Colours.palette.m3primary : Colours.palette.m3outline

                Behavior on border.color {
                    CAnim {}
                }
            }
        }
    }
}
