pragma ComponentBehavior: Bound

import QtQuick
import WallpaperBrowser

Item {
    id: root

    required property var app // Main, untyped since the root file can't be referenced as a type reliably
    required property var model
    required property int index
    readonly property alias image: clip
    readonly property string dl: app.downloadState(model.source, model.id)
    readonly property bool busy: dl === "busy" || dl === "setting"
    readonly property bool active: hover.hovered || busy

    width: GridView.view.cellWidth
    height: GridView.view.cellHeight

    HoverHandler {
        id: hover
    }

    Item {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.small
        // The preview flies this image out, so hide the original meanwhile
        opacity: root.app.previewIndex === root.index ? 0 : 1

        Elevation {
            anchors.fill: clip
            radius: clip.radius
            level: root.active ? 3 : 0
            z: -1
        }

        StyledRect {
            id: clip

            anchors.fill: parent
            radius: root.active ? Tokens.rounding.extraLarge : Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            Loader {
                anchors.centerIn: parent

                opacity: img.status === Image.Ready ? 0 : 1
                active: opacity > 0

                sourceComponent: StyledRect {
                    implicitWidth: indicator.implicitSize + Tokens.padding.large * 2
                    implicitHeight: indicator.implicitSize + Tokens.padding.large * 2

                    color: Colours.palette.m3primaryContainer
                    radius: Tokens.rounding.full

                    LoadingIndicator {
                        id: indicator

                        anchors.centerIn: parent
                        containsIcon: true
                        implicitSize: Math.min(clip.width, clip.height) * 0.2
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            RoundedImage {
                id: img

                anchors.fill: parent
                radius: clip.radius
                asynchronous: true
                sourceSize: root.app.thumbSize
                source: root.model.preview
                opacity: status === Image.Ready ? 1 : 0
                zoom: root.active ? 1.06 : 1

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }

                Behavior on zoom {
                    Anim {}
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.min(parent.height, 72)
                bottomLeftRadius: clip.radius
                bottomRightRadius: clip.radius
                opacity: root.active ? 1 : 0

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(0, 0, 0, 0.65)
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            StyledText {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.padding.large
                text: `${root.model.width} × ${root.model.height}`
                color: "white"
                font: Tokens.font.label.large
                opacity: root.active ? 1 : 0

                transform: Translate {
                    y: root.active ? 0 : Tokens.padding.small

                    Behavior on y {
                        Anim {}
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }

        StateLayer {
            radius: clip.radius
            color: "white"
            onClicked: root.app.openPreview(root.index, clip)
        }

        // The hover buttons, busy indicator and saved badge are built only while shown (and while they
        // fade out): most cards never show them, and they were most of each card's objects

        Loader {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.small
            opacity: hover.hovered && !root.busy ? 1 : 0
            active: opacity > 0

            transform: Translate {
                y: hover.hovered ? 0 : Tokens.padding.large

                Behavior on y {
                    Anim {}
                }
            }

            sourceComponent: Row {
                spacing: Tokens.spacing.small

                IconButton {
                    icon: "favorite"
                    type: ButtonBase.Tonal
                    isRound: true
                    isToggle: true
                    checked: root.app.isFavorite(root.model.source, root.model.id)
                    onClicked: root.app.toggleFavorite(root.index)
                }

                IconButton {
                    icon: root.dl === "done" ? "download_done" : "download"
                    type: ButtonBase.Tonal
                    isRound: true
                    onClicked: root.app.download(root.model.source, root.model.id, false)
                }

                IconButton {
                    icon: "wallpaper"
                    type: ButtonBase.Filled
                    isRound: true
                    onClicked: root.app.download(root.model.source, root.model.id, true)
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Loader {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.small
            scale: root.busy ? 1 : 0
            active: scale > 0

            sourceComponent: StyledRect {
                implicitWidth: busyIndicator.implicitSize + Tokens.padding.small * 2
                implicitHeight: implicitWidth
                radius: Tokens.rounding.full
                color: Colours.palette.m3primaryContainer

                LoadingIndicator {
                    id: busyIndicator

                    anchors.centerIn: parent
                    implicitSize: 24
                    animated: root.busy
                    color: Colours.palette.m3onPrimaryContainer
                }
            }

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }

        Loader {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            scale: root.dl === "done" && !hover.hovered ? 1 : 0
            active: scale > 0

            sourceComponent: StyledRect {
                implicitWidth: check.implicitHeight + Tokens.padding.extraSmall * 2
                implicitHeight: implicitWidth
                radius: Tokens.rounding.full
                color: Colours.palette.m3primary

                MaterialIcon {
                    id: check

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1
                    text: "check"
                    fill: 1
                    color: Colours.palette.m3onPrimary
                    fontStyle: Tokens.font.icon.small
                }
            }

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }
    }
}
