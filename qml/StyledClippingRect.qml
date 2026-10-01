pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// Stand-in for Quickshell's ClippingRectangle: children are clipped to the rounded shape
Item {
    id: root

    default property alias content: inner.data
    property real radius
    property color color: "transparent"

    StyledRect {
        anchors.fill: parent
        radius: root.radius
        color: root.color
    }

    Item {
        id: inner

        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskSpreadAtMin: 1
            maskThresholdMin: 0.5
        }
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }
}
