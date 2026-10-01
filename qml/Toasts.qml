pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import WallpaperBrowser

// Port of caelestia's toasts (modules/utilities/toasts): same look, enter/exit and stacking animations
ListView {
    id: root

    function show(title: string, message: string, icon: string, type: string): void {
        toasts.insert(0, {
            title,
            message,
            icon,
            type
        });
    }

    implicitWidth: 430 - Tokens.padding.medium * 2
    implicitHeight: contentHeight
    interactive: false
    spacing: Tokens.spacing.small
    verticalLayoutDirection: ListView.BottomToTop

    model: ListModel {
        id: toasts
    }

    add: Transition {
        Anim {
            properties: "opacity,scale"
            from: 0
            to: 1
        }
    }

    remove: Transition {
        Anim {
            property: "opacity"
            to: 0
            type: Anim.DefaultEffects
        }
        Anim {
            property: "scale"
            to: 0.7
        }
    }

    displaced: Transition {
        Anim {
            property: "y"
        }
    }

    delegate: StyledRect {
        id: toast

        required property int index
        required property string title
        required property string message
        required property string icon
        required property string type
        readonly property bool success: type === "success"
        readonly property bool error: type === "error"

        width: ListView.view.width
        implicitHeight: layout.implicitHeight + Tokens.padding.large
        radius: Tokens.rounding.large
        color: success ? Colours.palette.m3successContainer : error ? Colours.palette.m3errorContainer : Colours.palette.m3surface
        border.width: 1
        border.color: Qt.alpha(success ? Colours.palette.m3success : error ? Colours.palette.m3error : Colours.palette.m3outlineVariant, 0.3)

        Timer {
            running: true
            interval: toast.error ? 8000 : 4000
            onTriggered: toasts.remove(toast.index)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: toasts.remove(toast.index)
        }

        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: 3
        }

        RowLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            StyledRect {
                radius: Tokens.rounding.large
                color: toast.success ? Colours.palette.m3success : toast.error ? Colours.palette.m3error : Colours.palette.m3surfaceContainerHigh
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Tokens.padding.large

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: toast.icon
                    color: toast.success ? Colours.palette.m3onSuccess : toast.error ? Colours.palette.m3onError : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: toast.title
                    color: toast.success ? Colours.palette.m3onSuccessContainer : toast.error ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurface
                    font: Tokens.font.title.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: toast.message
                    color: toast.success ? Colours.palette.m3onSuccessContainer : toast.error ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurface
                    opacity: 0.8
                    elide: Text.ElideMiddle
                }
            }
        }
    }
}
