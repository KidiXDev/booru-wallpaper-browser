pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// An image cropped to fill a rounded rect, drawn as a shape filled with the image's own texture.
// StyledClippingRect needs two offscreen layers (content and mask) per instance, which on a grid of
// cards added up to tens of MB of textures
Shape {
    id: root

    property real radius
    property real zoom: 1 // Scale around the centre, still clipped to the shape
    property alias source: img.source
    property alias sourceSize: img.sourceSize
    property alias asynchronous: img.asynchronous
    readonly property alias status: img.status

    preferredRendererType: Shape.CurveRenderer // Antialiased edges without multisampling
    visible: img.status === Image.Ready

    ShapePath {
        strokeWidth: -1
        fillItem: img
        // The texture is laid out from the origin at its pixel size over the device pixel ratio:
        // scale it to cover, then centre
        fillTransform: {
            const dpr = Screen.devicePixelRatio;
            const iw = Math.max(1, img.implicitWidth) / dpr;
            const ih = Math.max(1, img.implicitHeight) / dpr;
            const s = Math.max(root.width / iw, root.height / ih) * root.zoom;
            const tx = (root.width - iw * s) / 2;
            const ty = (root.height - ih * s) / 2;
            return Qt.matrix4x4(s, 0, 0, tx, 0, s, 0, ty, 0, 0, 1, 0, 0, 0, 0, 1);
        }

        PathRectangle {
            width: root.width
            height: root.height
            radius: Math.min(root.radius, root.width / 2, root.height / 2)
        }
    }

    // Only a texture source for the fill, never drawn itself
    Image {
        id: img

        visible: false
        fillMode: Image.PreserveAspectCrop
    }
}
