import QtQuick
import QtQuick.Shapes
import WallpaperBrowser

// The M3 Expressive loading indicator: a shape that keeps morphing into the next one while it
// spins. Pure QML (no M3Shapes dependency): each shape is a radial profile r(a) = 1 + amp*cos(n*a),
// morphed by blending the profiles
Item {
    id: root

    // [lobes, amplitude] per shape: cookie, squarish, pentagon, sunny, burst, oval
    readonly property var profiles: containsIcon ? [[9, 0.07], [4, 0.1], [2, 0.14], [8, 0.1], [4, 0.1], [2, 0.14]] : [[12, 0.06], [9, 0.07], [5, 0.08], [2, 0.14], [8, 0.1], [4, 0.1], [2, 0.14]]
    property int shapeIndex
    property real cRotation
    property real lRotation
    property real thisLRotation
    property bool containsIcon
    property int fromIndex
    property real morphProgress: 1
    property color color: Colours.palette.m3primary
    property real implicitSize: 38

    property bool animated: true
    property int morphAnimRotation: 60
    property real morphScale: 0.14
    property alias rotateAnimDuration: rotateAnim.duration

    readonly property int points: 72

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    function radius(profile: var, angle: real): real {
        return 1 + profile[1] * Math.cos(profile[0] * angle);
    }

    property real stiffness: 180
    property real dampingRatio: 0.6
    property real visibilityThreshold: 0.075

    readonly property real springDuration: {
        const wn = Math.sqrt(stiffness);
        const r = -dampingRatio * wn;
        const c = 1 / Math.sqrt(1 - dampingRatio * dampingRatio);
        return Math.log(visibilityThreshold / c) / r;
    }
    readonly property real springMaxVelocity: {
        const wn = Math.sqrt(stiffness);
        const factor = Math.exp(-root.z * Math.acos(root.z) / Math.sqrt(1 - root.z * root.z)); // Upstream reads Item.z (0) here
        return wn * factor;
    }
    property bool springSettled: true
    property real startedAt

    function spring(t: real): var {
        const wn = Math.sqrt(stiffness);
        const za = dampingRatio * wn;

        const wd = wn * Math.sqrt(1 - dampingRatio * dampingRatio);
        const r = za / wd;
        const pos = 1 - Math.exp(-za * t) * (Math.cos(wd * t) + r * Math.sin(wd * t));
        const vel = Math.exp(-za * t) * (wn * wn / wd) * Math.sin(wd * t);

        return [pos, vel];
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"

            PathPolyline {
                path: {
                    const from = root.profiles[root.fromIndex], to = root.profiles[root.shapeIndex];
                    const c = root.implicitSize / 2, s = c / 1.15;
                    const pts = [];
                    for (let i = 0; i < root.points; i++) {
                        const a = i / root.points * 2 * Math.PI;
                        const r = (1 - root.morphProgress) * root.radius(from, a) + root.morphProgress * root.radius(to, a);
                        pts.push(Qt.point(c + s * r * Math.cos(a), c + s * r * Math.sin(a)));
                    }
                    return pts;
                }
            }
        }
    }

    FrameAnimation {
        running: root.animated && !root.springSettled
        onTriggered: {
            const t = (Date.now() - root.startedAt) / 1000;

            if (t >= root.springDuration) {
                root.springSettled = true;
            } else {
                const [pos, vel] = root.spring(t);
                root.morphProgress = Math.min(1, pos); // Overshooting the morph looks weird
                root.thisLRotation = pos * root.morphAnimRotation;
                root.scale = 1 + vel * root.morphScale / root.springMaxVelocity;
            }
        }
    }

    Timer {
        interval: 650
        repeat: true
        triggeredOnStart: true
        running: root.animated
        onTriggered: {
            root.fromIndex = root.shapeIndex;
            root.shapeIndex = (root.shapeIndex + 1) % root.profiles.length;
            root.morphProgress = 0;

            root.rotation = root.rotation;
            root.lRotation = (root.lRotation + root.thisLRotation) % 360;
            root.thisLRotation = 0;
            root.rotation = Qt.binding(() => root.cRotation + root.lRotation + root.thisLRotation);

            root.springSettled = false;
            root.startedAt = Date.now();
        }
    }

    RotationAnimation on cRotation {
        id: rotateAnim

        running: root.animated
        from: 0
        to: 360
        easing.type: Easing.Linear
        loops: Animation.Infinite
        duration: 4666
    }

    Behavior on color {
        CAnim {}
    }
}
