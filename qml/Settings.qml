pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import WallpaperBrowser

Item {
    id: root

    required property var sources
    property bool open
    property var settings: ({})
    property bool changed
    property real cacheSize // Bytes

    signal closed(changed: bool)
    signal saveFailed(error: string)

    function show(): void {
        settings = JSON.parse(Booru.settings());
        cacheSize = Booru.cacheSize();
        changed = false;
        open = true;
    }

    function hide(): void {
        if (!open)
            return;
        focus = false; // Commits the field being edited
        if (cacheSave.running)
            saveCacheLimit();
        open = false;
        closed(changed);
    }

    function save(s: var): void {
        const error = Booru.saveSettings(JSON.stringify(s));
        if (error) {
            saveFailed(error);
            return;
        }
        // Spicy mode and credentials change what searches return, so Main reloads on close
        changed = changed || s.spicy !== settings.spicy || s.credentials !== settings.credentials;
        settings = JSON.parse(Booru.settings()); // Re-read, a pasted "&api_key=…&user_id=…" gets split
    }

    // Saving trims the cache to the limit, a scan of its directory, so it waits for the value to settle
    function saveCacheLimit(): void {
        cacheSave.stop();
        save(Object.assign({}, settings, {
            cache_mb: cacheSave.mb
        }));
        cacheSize = Booru.cacheSize();
    }

    function credential(source: string, key: string): string {
        return settings.credentials?.[source]?.[key] ?? "";
    }

    // Writes every field of the source so the backend knows which keys a paste can fill
    function setCredential(source: var, key: string, value: string): void {
        const creds = {};
        for (const f of source.account.fields)
            creds[f.key] = credential(source.id, f.key);
        creds[key] = value.trim();
        const s = Object.assign({}, settings);
        s.credentials = Object.assign({}, settings.credentials, {
            [source.id]: creds
        });
        save(s);
    }

    property real slide: open ? 0 : Tokens.padding.extraLarge

    visible: opacity > 0
    opacity: open ? 1 : 0
    enabled: open

    Behavior on slide {
        Anim {}
    }

    Timer {
        id: cacheSave

        property int mb

        interval: 500
        onTriggered: root.saveCacheLimit()
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.forceActiveFocus()
    }

    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3surface
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.extraLarge
        anchors.topMargin: Tokens.padding.extraLarge + root.slide
        anchors.bottomMargin: 0
        spacing: Tokens.spacing.extraLargeIncreased

        RowLayout {
            spacing: Tokens.spacing.largeIncreased

            IconButton {
                icon: "arrow_back"
                type: ButtonBase.Tonal
                isRound: true
                inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                inactiveOnColour: Colours.palette.m3onSurfaceVariant
                onClicked: root.hide()
            }

            StyledText {
                Layout.fillWidth: true
                text: "Settings"
                font: Tokens.font.title.large
            }
        }

        Flickable {
            id: flickable

            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: content.implicitHeight + Tokens.padding.extraLarge
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            T.ScrollBar.vertical: StyledScrollBar {
                flickable: flickable
            }

            ColumnLayout {
                id: content

                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(flickable.width, 760)
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    first: true
                    text: "Content"
                }

                ToggleRow {
                    first: true
                    last: true
                    text: "Spicy Mode"
                    subtext: "Enable NSFW Post"
                    font: Tokens.font.body.medium
                    checked: root.settings.spicy ?? false
                    onToggled: root.save(Object.assign({}, root.settings, {
                        spicy: checked
                    }))
                }

                SectionHeader {
                    text: "Cache"
                }

                StepperRow {
                    first: true
                    label: "Cache limit (MB)"
                    subtext: "Thumbnails and previews kept on disk"
                    from: 0
                    to: 51200
                    stepSize: 256
                    value: root.settings.cache_mb ?? 0
                    onMoved: value => {
                        cacheSave.mb = Math.round(value);
                        cacheSave.restart();
                    }
                }

                ConnectedRect {
                    Layout.fillWidth: true
                    implicitHeight: cacheRow.implicitHeight + Tokens.padding.medium * 2
                    last: true

                    RowLayout {
                        id: cacheRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: "Cached images"
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: `${(root.cacheSize / 1048576).toFixed(1)} MB used`
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                            }
                        }

                        IconTextButton {
                            icon: "delete"
                            text: "Clear cache"
                            type: ButtonBase.Text
                            disabled: root.cacheSize === 0
                            onClicked: {
                                Booru.clearCache();
                                root.cacheSize = Booru.cacheSize();
                            }
                        }
                    }
                }

                SectionHeader {
                    text: "Accounts"
                }

                Repeater {
                    model: root.sources.filter(s => s.account)

                    ColumnLayout {
                        id: account

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.topMargin: index > 0 ? Tokens.spacing.large : 0
                        spacing: Tokens.spacing.extraSmall / 2

                        ConnectedRect {
                            Layout.fillWidth: true
                            implicitHeight: accountRow.implicitHeight + Tokens.padding.medium * 2
                            first: true

                            RowLayout {
                                id: accountRow

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Tokens.padding.largeIncreased
                                anchors.rightMargin: Tokens.padding.medium
                                spacing: Tokens.spacing.medium

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: account.modelData.name
                                        font: Tokens.font.body.medium
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: account.modelData.account.note
                                        color: Colours.palette.m3outline
                                        font: Tokens.font.label.small
                                        wrapMode: Text.Wrap
                                    }
                                }

                                IconTextButton {
                                    icon: "open_in_new"
                                    text: "Open site"
                                    type: ButtonBase.Text
                                    onClicked: Qt.openUrlExternally(account.modelData.account.url)
                                }
                            }
                        }

                        Repeater {
                            model: account.modelData.account.fields

                            TextFieldRow {
                                required property var modelData
                                required property int index

                                last: index === account.modelData.account.fields.length - 1
                                label: modelData.label
                                secret: modelData.secret
                                placeholderText: modelData.key === "api_key" && account.modelData.id === "gelbooru" ? "or paste &api_key=…&user_id=…" : ""
                                value: root.credential(account.modelData.id, modelData.key)
                                onEditingFinished: value => root.setCredential(account.modelData, modelData.key, value)
                            }
                        }
                    }
                }
            }
        }
    }
}
