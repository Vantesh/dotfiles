#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Custom properties with non-conflicting names
    float itemWidth;
    float itemHeight;
    float cornerRadius;
    float imageOpacity;
} ubuf;

// Function to calculate the signed distance from a point to a rounded box
float roundedBoxSDF(vec2 centerPos, vec2 boxSize, float radius) {
    vec2 d = abs(centerPos) - boxSize + radius;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

void main() {
    // Get size from uniforms
    vec2 itemSize = vec2(ubuf.itemWidth, ubuf.itemHeight);
    float cornerRadius = ubuf.cornerRadius;
    float itemOpacity = ubuf.imageOpacity;
    
    // Normalize coordinates to [-0.5, 0.5] range
    vec2 uv = qt_TexCoord0 - 0.5;
    
    // Scale by aspect ratio to maintain uniform rounding
    vec2 aspectRatio = itemSize / max(itemSize.x, itemSize.y);
    uv *= aspectRatio;
    
    // Calculate half size in normalized space
    vec2 halfSize = 0.5 * aspectRatio;
    
    // Normalize the corner radius
    float normalizedRadius = cornerRadius / max(itemSize.x, itemSize.y);
    
    // Calculate distance to rounded rectangle
    float distance = roundedBoxSDF(uv, halfSize, normalizedRadius);
    
    // Create smooth alpha mask
    float smoothedAlpha = 1.0 - smoothstep(0.0, fwidth(distance), distance);
    
    // Sample the texture
    vec4 color = texture(source, qt_TexCoord0);
    
    // Apply the rounded mask and opacity
    // Make sure areas outside the rounded rect are completely transparent
    float finalAlpha = color.a * smoothedAlpha * itemOpacity * ubuf.qt_Opacity;
    fragColor = vec4(color.rgb * finalAlpha, finalAlpha);
}