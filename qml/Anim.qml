import QtQuick
import WallpaperBrowser

NumberAnimation {
    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: Anim.DefaultSpatial

    duration: {
        const d = Tokens.anim.durations;
        if (type < Anim.StandardSmall || type > Anim.SlowEffects)
            return d.normal;
        const expressive = [d.expressiveFastSpatial, d.expressiveDefaultSpatial, d.expressiveSlowSpatial, d.expressiveFastEffects, d.expressiveDefaultEffects, d.expressiveSlowEffects];
        if (type >= Anim.FastSpatial)
            return expressive[type - Anim.FastSpatial];
        return [d.small, d.normal, d.large, d.extraLarge][type % 4];
    }
    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        const c = Tokens.anim.curves;
        if (type >= Anim.FastSpatial && type <= Anim.SlowEffects)
            return [c.expressiveFastSpatial, c.expressiveDefaultSpatial, c.expressiveSlowSpatial, c.expressiveFastEffects, c.expressiveDefaultEffects, c.expressiveSlowEffects][type - Anim.FastSpatial];
        if (type >= Anim.EmphasizedSmall && type <= Anim.EmphasizedExtraLarge)
            return c.emphasized;
        return c.standard;
    }
}
