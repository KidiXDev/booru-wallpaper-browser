pragma Singleton

import QtQuick

// Same API and defaults as caelestia's Tokens (plugin/src/Caelestia/Config/tokens.hpp,
// appearanceconfig.hpp), so components port 1:1 between this app and the shell
QtObject {
    id: root

    // Set to Google Sans Flex by Main once its FontLoader is ready
    property string family

    readonly property Rounding rounding: Rounding {}
    readonly property TokenScale spacing: TokenScale {}
    readonly property TokenScale padding: TokenScale {}

    readonly property AnimTokens anim: AnimTokens {}

    readonly property Fonts font: Fonts {
        family: root.family
    }

    component TokenScale: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
        readonly property int extraLargeIncreased: 32
        readonly property int extraExtraLarge: 48
    }

    component Rounding: TokenScale {
        readonly property int full: 1000
        readonly property real scale: 1
    }

    // Cubic bezier points for easing.bezierCurve
    component Curves: QtObject {
        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
        readonly property list<real> expressiveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
        readonly property list<real> expressiveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
        readonly property list<real> expressiveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
    }

    component Durations: QtObject {
        readonly property int small: 200
        readonly property int normal: 400
        readonly property int large: 600
        readonly property int extraLarge: 1000
        readonly property int expressiveFastSpatial: 350
        readonly property int expressiveDefaultSpatial: 500
        readonly property int expressiveSlowSpatial: 650
        readonly property int expressiveFastEffects: 150
        readonly property int expressiveDefaultEffects: 200
        readonly property int expressiveSlowEffects: 300
    }

    component AnimTokens: QtObject {
        readonly property Curves curves: Curves {}
        readonly property Durations durations: Durations {}
    }

    component FontStyle: QtObject {
        required property string family
        required property list<int> sizes // large, medium, small
        property list<int> weights: [Font.Normal, Font.Normal, Font.Normal]
        property var vaxes: ({
                ROND: 25
            })

        function make(size: int, weight: int): font {
            return Qt.font({
                family: family,
                pointSize: size,
                weight: weight,
                variableAxes: Object.assign({
                    opsz: size,
                    wght: weight
                }, vaxes)
            });
        }

        readonly property font large: make(sizes[0], weights[0])
        readonly property font medium: make(sizes[1], weights[1])
        readonly property font small: make(sizes[2], weights[2])
    }

    component IconStyle: FontStyle {
        readonly property font extraLarge: make(36, Font.Normal)
    }

    component Fonts: QtObject {
        id: fonts

        required property string family

        readonly property FontStyle headline: FontStyle {
            family: fonts.family
            sizes: [32, 28, 24]
            weights: [Font.Medium, Font.Medium, Font.Medium]
        }
        readonly property FontStyle title: FontStyle {
            family: fonts.family
            sizes: [22, 16, 14]
            weights: [Font.Medium, Font.Medium, Font.Medium]
        }
        readonly property FontStyle body: FontStyle {
            family: fonts.family
            sizes: [16, 14, 12]
        }
        readonly property FontStyle label: FontStyle {
            family: fonts.family
            sizes: [14, 12, 11]
            weights: [Font.Medium, Font.Medium, Font.Normal]
        }
        // Sizes are 48/32/24/20 px at the shell's 1.33 pt ratio
        readonly property IconStyle icon: IconStyle {
            family: "Material Symbols Rounded"
            sizes: [24, 18, 15]
            vaxes: ({})
        }
    }
}
