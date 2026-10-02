// RoundedImage: the source texture cropped to fill the item (like Image.PreserveAspectCrop) and cut
// to a rounded rect with antialiased corners. Compiled to roundedimage.frag.qsb by
// scripts/compile_shaders.sh
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize; // Logical pixels
    vec2 uvScale; // Share of the image shown on each axis
    float radius;
    float aaWidth; // One device pixel, in logical pixels
};

layout(binding = 1) uniform sampler2D tex;

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 halfSize = itemSize * 0.5;
    float r = min(radius, min(halfSize.x, halfSize.y));
    // Signed distance to the rounded rect's edge, negative inside
    vec2 q = abs(p - halfSize) - (halfSize - vec2(r));
    float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    float coverage = clamp(0.5 - dist / aaWidth, 0.0, 1.0);

    vec2 uv = (vec2(1.0) - uvScale) * 0.5 + qt_TexCoord0 * uvScale;
    vec4 color = texture(tex, uv);
    fragColor = color * coverage * qt_Opacity;
}
