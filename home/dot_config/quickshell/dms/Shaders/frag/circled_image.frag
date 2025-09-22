#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float imageOpacity;
} ubuf;

void main() {
    // Center coordinates around (0, 0)
    vec2 uv = qt_TexCoord0 - 0.5;
    
    // Calculate distance from center
    float distance = length(uv);
    
    // Create circular mask - anything beyond radius 0.5 is transparent
    float mask = 1.0 - smoothstep(0.48, 0.52, distance);
    
    // Sample the texture
    vec4 color = texture(source, qt_TexCoord0);
    
    // Apply the circular mask and opacity
    float finalAlpha = color.a * mask * ubuf.imageOpacity * ubuf.qt_Opacity;
    fragColor = vec4(color.rgb * finalAlpha, finalAlpha);
}