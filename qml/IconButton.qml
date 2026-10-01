import QtQuick
import WallpaperBrowser

ButtonBase {
    id: root

    property alias icon: label.text
    readonly property alias label: label

    font: Tokens.font.icon.medium
    padding: type === ButtonBase.Text ? Tokens.padding.extraSmall / 2 : Tokens.padding.small

    activeColour: type === ButtonBase.Filled ? Colours.palette.m3primary : Colours.palette.m3secondary
    inactiveColour: {
        if (!isToggle && type === ButtonBase.Filled)
            return Colours.palette.m3primary;
        return type === ButtonBase.Filled ? Colours.tPalette.m3surfaceContainer : Colours.palette.m3secondaryContainer;
    }
    activeOnColour: type === ButtonBase.Filled ? Colours.palette.m3onPrimary : type === ButtonBase.Tonal ? Colours.palette.m3onSecondary : Colours.palette.m3primary
    inactiveOnColour: {
        if (!isToggle && type === ButtonBase.Filled)
            return Colours.palette.m3onPrimary;
        return type === ButtonBase.Tonal ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant;
    }

    implicitWidth: implicitHeight
    implicitHeight: {
        // Ensure even size so icon is centered properly
        const h = label.implicitHeight + padding * 2;
        if (h % 2 !== 0)
            return h + 1;
        return h;
    }

    MaterialIcon {
        id: label

        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1 // AHHHHHHH material symbols whyyyy
        color: root.onColour
        fontStyle: root.font
        fill: !root.isToggle || root.internalChecked ? 1 : 0

        Behavior on fill {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
