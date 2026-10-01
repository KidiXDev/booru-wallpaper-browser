pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import WallpaperBrowser

// Fullscreen preview. The clicked card's image morphs into place (shared element)
// and flies back to its card on close
Item {
    id: root

    required property var app // Main, untyped since the root file can't be referenced as a type reliably
    property int index: -1
    property bool open
    property rect closeTo
    readonly property var post: index >= 0 && index < app.posts.count ? app.posts.get(index) : null
    readonly property string dl: post ? app.downloadState(post.source, post.id) : ""
    readonly property real aspect: post ? post.width / Math.max(1, post.height) : 16 / 10
    readonly property bool settled: open && !openAnim.running
    readonly property rect target: {
        const side = navLeft.implicitWidth + Tokens.padding.extraLarge * 2;
        const top = Tokens.padding.extraLarge;
        const maxW = width - side * 2;
        const maxH = height - info.implicitHeight - top - Tokens.padding.extraLarge * 2;
        const w = Math.max(0, Math.min(maxW, maxH * aspect));
        const h = w / aspect;
        return Qt.rect((width - w) / 2, top + (maxH - h) / 2, w, h);
    }

    function show(i: int, from: Item): void {
        index = i;
        const r = from.mapToItem(root, 0, 0, from.width, from.height);
        open = true;
        closeAnim.stop();
        frame.x = r.x;
        frame.y = r.y;
        frame.width = r.width;
        frame.height = r.height;
        frame.radius = Tokens.rounding.large;
        openAnim.restart();
    }

    function hide(): void {
        if (!open)
            return;
        open = false;
        openAnim.stop();
        // Freeze the frame where it is, then fly back to the card (or shrink if it's gone)
        frame.x = frame.x;
        frame.y = frame.y;
        frame.width = frame.width;
        frame.height = frame.height;
        const card = app.cardAt(index);
        closeTo = card ? card.image.mapToItem(root, 0, 0, card.image.width, card.image.height) : Qt.rect(target.x + target.width / 2, target.y + target.height / 2, 0, 0);
        closeAnim.restart();
    }

    function step(delta: int): void {
        const i = index + delta;
        if (open && i >= 0 && i < app.posts.count)
            index = i;
    }

    visible: open || closeAnim.running

    ParallelAnimation {
        id: openAnim

        onFinished: {
            frame.x = Qt.binding(() => root.target.x);
            frame.y = Qt.binding(() => root.target.y);
            frame.width = Qt.binding(() => root.target.width);
            frame.height = Qt.binding(() => root.target.height);
        }

        Anim {
            target: frame
            property: "x"
            to: root.target.x
        }
        Anim {
            target: frame
            property: "y"
            to: root.target.y
        }
        Anim {
            target: frame
            property: "width"
            to: root.target.width
        }
        Anim {
            target: frame
            property: "height"
            to: root.target.height
        }
        Anim {
            target: frame
            property: "radius"
            to: Tokens.rounding.extraLarge
            type: Anim.DefaultEffects
        }
    }

    ParallelAnimation {
        id: closeAnim

        Anim {
            target: frame
            property: "x"
            to: root.closeTo.x
        }
        Anim {
            target: frame
            property: "y"
            to: root.closeTo.y
        }
        Anim {
            target: frame
            property: "width"
            to: root.closeTo.width
        }
        Anim {
            target: frame
            property: "height"
            to: root.closeTo.height
        }
        Anim {
            target: frame
            property: "radius"
            to: Tokens.rounding.large
            type: Anim.DefaultEffects
        }
    }

    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: root.open ? 0.7 : 0

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Elevation {
        anchors.fill: frame
        radius: frame.radius
        level: 4
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    StyledClippingRect {
        id: frame

        color: Colours.tPalette.m3surfaceContainer

        // Morph between posts of different sizes while open, and follow window resizes
        Behavior on x {
            enabled: root.settled

            Anim {}
        }
        Behavior on y {
            enabled: root.settled

            Anim {}
        }
        Behavior on width {
            enabled: root.settled

            Anim {}
        }
        Behavior on height {
            enabled: root.settled

            Anim {}
        }

        MouseArea {
            anchors.fill: parent
        }

        // Grid thumbnail is cached, so it shows instantly while the sample loads
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: root.post?.preview ?? ""
        }

        Image {
            id: full

            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            source: root.post?.sample ?? ""
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.SlowEffects
                }
            }
        }

        StyledRect {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.large
            implicitWidth: sampleIndicator.implicitSize + Tokens.padding.small * 2
            implicitHeight: implicitWidth
            radius: Tokens.rounding.full
            color: Colours.palette.m3primaryContainer
            scale: full.status === Image.Loading && root.settled ? 1 : 0
            visible: scale > 0

            LoadingIndicator {
                id: sampleIndicator

                anchors.centerIn: parent
                implicitSize: 28
                animated: parent.visible
                color: Colours.palette.m3onPrimaryContainer
            }

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }
    }

    RowLayout {
        id: nav

        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.extraLarge
        anchors.rightMargin: Tokens.padding.extraLarge
        anchors.bottomMargin: info.implicitHeight + Tokens.padding.extraLarge
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        IconButton {
            id: navLeft

            icon: "chevron_left"
            type: ButtonBase.Tonal
            isRound: true
            font: Tokens.font.icon.large
            disabled: root.index <= 0
            onClicked: root.step(-1)
        }

        Item {
            Layout.fillWidth: true
        }

        IconButton {
            icon: "chevron_right"
            type: ButtonBase.Tonal
            isRound: true
            font: Tokens.font.icon.large
            disabled: root.index >= root.app.posts.count - 1
            onClicked: root.step(1)
        }
    }

    IconButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.large
        icon: "close"
        type: ButtonBase.Tonal
        isRound: true
        opacity: root.open ? 1 : 0
        onClicked: root.hide()

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Elevation {
        anchors.fill: info
        radius: info.radius
        level: 3
        opacity: info.opacity
    }

    StyledRect {
        id: info

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.extraLarge
        width: Math.min(parent.width - Tokens.padding.extraLarge * 2, 1000)
        implicitHeight: infoLayout.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer
        opacity: root.open ? 1 : 0

        transform: Translate {
            y: root.open ? 0 : Tokens.padding.extraExtraLarge

            Behavior on y {
                Anim {}
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            id: infoLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            anchors.leftMargin: Tokens.padding.extraLarge
            spacing: Tokens.spacing.medium

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    text: root.post ? `${root.post.width} × ${root.post.height}` : ""
                    font: Tokens.font.title.medium
                    animate: true
                }

                StyledText {
                    text: {
                        const p = root.post;
                        if (!p)
                            return "";
                        // Not every site reports file size
                        const size = p.size ? `${(p.size / 1048576).toFixed(1)} MB` : "";
                        return [p.ext.toUpperCase(), size, `★ ${p.score}`, `#${p.id}`].filter(s => s).join("  ·  ");
                    }
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.large
                    animate: true
                }

                // Tags search on click, capped to two rows
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    Layout.maximumHeight: 28 * 2 + spacing
                    clip: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: root.post?.tags.split(" ").filter(t => t) ?? []

                        StyledRect {
                            id: tag

                            required property string modelData

                            implicitWidth: tagLabel.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: 28
                            radius: Tokens.rounding.full
                            color: Colours.tPalette.m3surfaceContainerHigh

                            StyledText {
                                id: tagLabel

                                anchors.centerIn: parent
                                text: tag.modelData.replace(/_/g, " ")
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.medium
                            }

                            StateLayer {
                                color: Colours.palette.m3onSurfaceVariant
                                onClicked: root.app.searchTag(tag.modelData)
                            }
                        }
                    }
                }
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "open_in_new"
                type: ButtonBase.Tonal
                isRound: true
                onClicked: Qt.openUrlExternally(root.post.url)
            }

            IconTextButton {
                Layout.alignment: Qt.AlignVCenter
                icon: root.dl === "done" ? "download_done" : root.dl === "busy" ? "downloading" : "download"
                text: root.dl === "done" ? "Saved" : root.dl === "busy" ? "Saving" : "Download"
                label.animate: true
                font: Tokens.font.body.large
                type: ButtonBase.Tonal
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                disabled: root.dl === "busy" || root.dl === "setting"
                onClicked: root.app.download(root.post.source, root.post.id, false)
            }

            IconTextButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "wallpaper"
                text: root.dl === "setting" ? "Applying" : "Set wallpaper"
                label.animate: true
                font: Tokens.font.body.large
                type: ButtonBase.Filled
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                disabled: root.dl === "busy" || root.dl === "setting"
                onClicked: root.app.download(root.post.source, root.post.id, true)
            }
        }
    }
}
