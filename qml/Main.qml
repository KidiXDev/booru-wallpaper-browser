pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Templates as T
import WallpaperBrowser

Window {
    id: root

    readonly property var sources: JSON.parse(Booru.sources()) // [{id, name}], first is the default
    property string source: sources[0].id
    readonly property string sourceName: sources.find(s => s.id === source)?.name ?? source
    readonly property var sorts: [["schedule", "Latest", "latest"], ["trending_up", "Top", "score"], ["shuffle", "Random", "random"]]
    readonly property int previewIndex: preview.visible ? preview.index : -1
    property ListModel posts: ListModel {}
    property int sort
    property int page
    property int pending
    property bool more: true
    property string error
    property var downloads: ({}) // "source:id" -> "busy" | "setting" | "done"

    function fetch(n: int): void {
        pending = n;
        error = "";
        Booru.search(source, search.text, sorts[sort][2], n);
    }

    function reset(): void {
        preview.hide();
        posts.clear();
        more = true;
        fetch(1);
    }

    function loadMore(): void {
        if (more && !Booru.busy && !error)
            fetch(page + 1);
    }

    // Small pages (safe filter) may not fill the view, so the grid never scrolls to trigger loadMore
    function fillView(): void {
        if (grid.contentHeight < grid.height + grid.cellHeight * 2)
            loadMore();
    }

    // Post ids are only unique per source
    function downloadState(source: string, id: int): string {
        return downloads[`${source}:${id}`] ?? "";
    }

    function setDownload(source: string, id: int, state: string): void {
        const d = Object.assign({}, downloads);
        d[`${source}:${id}`] = state;
        downloads = d;
    }

    function download(source: string, id: int, apply: bool): void {
        const state = downloadState(source, id);
        if (state === "busy" || state === "setting")
            return;
        setDownload(source, id, apply ? "setting" : "busy");
        Booru.download(source, id, apply);
    }

    function setSource(id: string): void {
        if (id === source)
            return;
        source = id;
        reset();
    }

    function searchTag(tag: string): void {
        search.text = tag;
        reset();
    }

    function openPreview(index: int, from: Item): void {
        preview.show(index, from);
    }

    function cardAt(index: int): WallCard {
        grid.positionViewAtIndex(index, GridView.Contain);
        grid.forceLayout();
        return grid.itemAtIndex(index) as WallCard;
    }

    width: 1280
    height: 820
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: "Wallpapers"
    color: Colours.palette.m3surface
    Component.onCompleted: loadMore()

    Behavior on color {
        CAnim {}
    }

    FontLoader {
        id: gsf

        source: Booru.fontUrl()
    }

    Binding {
        target: Tokens
        property: "family"
        value: gsf.name
        when: gsf.status === FontLoader.Ready
    }

    Connections {
        function onResults(json: string, error: string): void {
            if (error) {
                root.error = error;
                if (root.posts.count)
                    toasts.show("Couldn't load more", error, "cloud_off", "error");
                return;
            }
            const page = JSON.parse(json);
            for (const post of page.posts)
                root.posts.append(post);
            root.page = root.pending;
            root.more = page.more;
            Qt.callLater(root.fillView);
        }

        function onDownloaded(source: string, id: int, path: string, error: string): void {
            const applied = root.downloadState(source, id) === "setting";
            root.setDownload(source, id, path ? "done" : "");
            if (error)
                toasts.show(applied && path ? "Couldn't set wallpaper" : "Download failed", error, "error", "error");
            else if (applied)
                toasts.show("Wallpaper set", path.slice(path.lastIndexOf("/") + 1), "wallpaper", "success");
            else
                toasts.show("Downloaded", path.replace(/^\/home\/[^/]+/, "~"), "download_done", "success");
        }

        target: Booru
    }

    Shortcut {
        sequences: ["/", "Ctrl+F"]
        enabled: !search.activeFocus // Tags can contain "/"
        onActivated: search.forceActiveFocus()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (preview.open)
                preview.hide();
            else
                search.focus = false;
        }
    }

    Shortcut {
        sequence: "Left"
        enabled: preview.open
        onActivated: preview.step(-1)
    }

    Shortcut {
        sequence: "Right"
        enabled: preview.open
        onActivated: preview.step(1)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.extraLarge
        anchors.bottomMargin: 0
        spacing: Tokens.spacing.large

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.largeIncreased

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: "Wallpapers"
                    font: Tokens.font.title.large
                }

                StyledText {
                    text: `${root.posts.count} from ${root.sourceName}`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                    animate: true
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: search.implicitHeight

                SearchBar {
                    id: search

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, 560)
                    placeholderText: "Search tags, e.g. scenery sky"
                    font: Tokens.font.body.medium
                    onAccepted: root.reset()
                }

                Connections {
                    function onClicked(): void {
                        root.reset();
                    }

                    target: search.clearIcon
                }
            }

            IconTextButton {
                id: sourceButton

                icon: "travel_explore"
                text: root.sourceName
                font: Tokens.font.body.medium
                type: ButtonBase.Tonal
                isRound: true
                checked: sourceMenu.expanded
                horizontalPadding: Tokens.padding.large
                verticalPadding: Tokens.padding.medium
                onClicked: sourceMenu.expanded = !sourceMenu.expanded
            }

            Row {
                spacing: Tokens.spacing.small

                Repeater {
                    model: root.sorts

                    IconTextButton {
                        required property var modelData
                        required property int index

                        icon: modelData[0]
                        text: modelData[1]
                        font: Tokens.font.body.medium
                        type: ButtonBase.Tonal
                        isRound: true
                        checked: root.sort === index
                        horizontalPadding: Tokens.padding.large
                        verticalPadding: Tokens.padding.medium
                        onClicked: {
                            if (root.sort === index)
                                return;
                            root.sort = index;
                            root.reset();
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: grid

                readonly property int columns: Math.max(1, Math.floor(width / 340))
                readonly property real fade: Tokens.padding.extraExtraLarge / Math.max(1, height)
                property bool doneFakeFlick

                anchors.fill: parent
                anchors.leftMargin: -Tokens.spacing.small
                anchors.rightMargin: -Tokens.spacing.small
                topMargin: Tokens.padding.small
                bottomMargin: Tokens.padding.extraLarge
                cellWidth: width / columns
                cellHeight: Math.round(cellWidth * 10 / 16)
                maximumFlickVelocity: 3000
                model: root.posts
                onAtYEndChanged: if (atYEnd) root.loadMore()
                onHeightChanged: Qt.callLater(root.fillView)

                delegate: WallCard {
                    app: root
                }

                // New pages cascade in
                add: Transition {
                    id: addTrans

                    SequentialAnimation {
                        PropertyAction {
                            property: "opacity"
                            value: 0
                        }
                        PauseAnimation {
                            duration: Math.min(addTrans.ViewTransition.index - addTrans.ViewTransition.targetIndexes[0], 12) * 30
                        }
                        ParallelAnimation {
                            Anim {
                                property: "opacity"
                                to: 1
                                type: Anim.DefaultEffects
                            }
                            Anim {
                                property: "scale"
                                from: 0.85
                                to: 1
                            }
                        }
                    }
                }

                // Same bouncy overscroll as caelestia's StyledListView
                rebound: Transition {
                    onRunningChanged: {
                        if (!running && !grid.doneFakeFlick) {
                            grid.doneFakeFlick = true;
                            grid.flick(1, 1);
                            grid.flick(-1, -1);
                            Qt.callLater(() => grid.cancelFlick());
                        }
                    }

                    Anim {
                        properties: "x,y"
                    }
                }

                footer: Item {
                    width: grid.width
                    height: root.posts.count && (root.more || root.error) ? 112 : 0

                    LoadingIndicator {
                        anchors.centerIn: parent
                        implicitSize: 40
                        visible: Booru.busy
                        animated: visible
                    }

                    IconTextButton {
                        anchors.centerIn: parent
                        visible: !Booru.busy && root.error !== ""
                        icon: "refresh"
                        text: "Retry"
                        type: ButtonBase.Tonal
                        isRound: true
                        onClicked: {
                            root.error = "";
                            root.loadMore();
                        }
                    }
                }

                T.ScrollBar.vertical: StyledScrollBar {
                    flickable: grid
                }

                // Edge fade like caelestia's VerticalFadeFlickable
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: fadeMask
                    maskSpreadAtMin: 1
                    maskThresholdMin: 0.5
                }

                Rectangle {
                    id: fadeMask

                    property real topOpacity: grid.atYBeginning ? 1 : 0
                    property real bottomOpacity: grid.atYEnd ? 1 : 0

                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.rgba(0, 0, 0, fadeMask.topOpacity)
                        }
                        GradientStop {
                            position: grid.fade
                            color: "black"
                        }
                        GradientStop {
                            position: 1 - grid.fade
                            color: "black"
                        }
                        GradientStop {
                            position: 1
                            color: Qt.rgba(0, 0, 0, fadeMask.bottomOpacity)
                        }
                    }

                    Behavior on topOpacity {
                        Anim {
                            type: Anim.SlowEffects
                        }
                    }

                    Behavior on bottomOpacity {
                        Anim {
                            type: Anim.SlowEffects
                        }
                    }
                }

                Timer {
                    running: grid.doneFakeFlick
                    interval: 10
                    onTriggered: grid.doneFakeFlick = false
                }
            }

            // First page loading
            StyledRect {
                anchors.centerIn: parent
                implicitWidth: firstLoad.implicitSize + Tokens.padding.large * 2
                implicitHeight: implicitWidth
                radius: Tokens.rounding.full
                color: Colours.palette.m3primaryContainer
                scale: root.posts.count === 0 && Booru.busy ? 1 : 0
                visible: scale > 0

                LoadingIndicator {
                    id: firstLoad

                    anchors.centerIn: parent
                    containsIcon: true
                    implicitSize: 56
                    animated: parent.visible
                    color: Colours.palette.m3onPrimaryContainer
                }

                Behavior on scale {
                    Anim {}
                }
            }

            // Empty and error states, styled after nexus' "No local wallpapers found"
            StyledRect {
                anchors.centerIn: parent
                implicitWidth: Math.min(parent.width, 480)
                implicitHeight: emptyLayout.implicitHeight + Tokens.padding.extraExtraLarge * 2
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer
                opacity: root.posts.count === 0 && !Booru.busy ? 1 : 0
                scale: opacity > 0 ? 1 : 0.9
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                Behavior on scale {
                    Anim {}
                }

                ColumnLayout {
                    id: emptyLayout

                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.extraExtraLarge * 2
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.error ? "cloud_off" : "hide_image"
                        color: Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.error ? `Couldn't load ${root.sourceName}` : "No wallpapers found"
                        color: Colours.palette.m3outline
                        font: Tokens.font.title.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.error !== ""
                        text: root.error
                        color: Colours.palette.m3outline
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    IconTextButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Tokens.spacing.medium
                        visible: root.error !== ""
                        icon: "refresh"
                        text: "Retry"
                        type: ButtonBase.Tonal
                        isRound: true
                        onClicked: root.reset()
                    }
                }
            }
        }
    }

    Menu {
        id: sourceMenu

        attachTo: sourceButton
        attachSideX: Menu.Left
        thisSideX: Menu.Left
        marginY: Tokens.spacing.small
        active: items.find(i => i.value === root.source) ?? null
        items: root.sources.map(s => menuItem.createObject(sourceMenu, {
                text: s.name,
                value: s.id
            }))
        onItemSelected: item => root.setSource(item.value)
    }

    Component {
        id: menuItem

        MenuItem {
            text: ""
            icon: "public"
        }
    }

    Preview {
        id: preview

        anchors.fill: parent
        app: root
        onIndexChanged: {
            if (index < 0)
                return;
            grid.positionViewAtIndex(index, GridView.Contain);
            if (index >= root.posts.count - 4)
                root.loadMore();
        }
    }

    Toasts {
        id: toasts

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large
    }
}
