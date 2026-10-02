pragma ComponentBehavior: Bound

import QtQuick

// An image cropped to fill a rounded rect, drawn straight from the image's own texture by a small
// shader (assets/shaders/roundedimage.frag). StyledClippingRect needed two offscreen layers per
// card, and a Shape filled with the image (ShapePath.fillItem) crashes on Qt < 6.11: the curve
// renderer gives texture fills a material type past the end of its static array (type[5] of 5), so
// they can share a type with another material and get drawn with its shader
ShaderEffect {
    id: root

    property real radius
    property real zoom: 1 // Scale around the centre, still clipped to the shape
    property alias source: img.source
    property alias sourceSize: img.sourceSize
    property alias asynchronous: img.asynchronous
    readonly property alias status: img.status

    // Uniforms, by name
    readonly property Image tex: img
    readonly property size itemSize: Qt.size(width, height)
    // Share of the image shown on each axis to cover the item, like Image.PreserveAspectCrop
    readonly property size uvScale: {
        const iw = Math.max(1, img.implicitWidth);
        const ih = Math.max(1, img.implicitHeight);
        const s = Math.max(width / iw, height / ih) * zoom;
        return Qt.size(Math.min(1, width / (iw * s)), Math.min(1, height / (ih * s)));
    }
    readonly property real aaWidth: 1 / Screen.devicePixelRatio

    visible: img.status === Image.Ready && width > 0 && height > 0
    // Atlas sub-rects came out wrong at fractional scaling, so Qt hands over a copy outside the atlas,
    // as the curve renderer's texture fill did too
    supportsAtlasTextures: false
    fragmentShader: "qrc:/shaders/shaders/roundedimage.frag.qsb"

    // Only a texture source for the shader, never drawn itself
    Image {
        id: img

        visible: false
        fillMode: Image.PreserveAspectCrop
    }
}
