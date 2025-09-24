// ===== wp_pixelate.frag =====
#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source1;  // Current wallpaper (underlay)
layout(binding = 2) uniform sampler2D source2;  // Next wallpaper (pixelated overlay → sharp)

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;      // 0..1
    float centerX;       // (unused, API compat)
    float centerY;       // (unused)
    float smoothness;    // controls starting block size (0..1)
    float aspectRatio;   // (unused)

    // Fill mode parameters
    float fillMode;      // 0=no(center), 1=crop, 2=fit, 3=stretch
    float imageWidth1;
    float imageHeight1;
    float imageWidth2;
    float imageHeight2;
    float screenWidth;
    float screenHeight;
    vec4  fillColor;
} ubuf;

vec2 calculateUV(vec2 uv, float imgWidth, float imgHeight) {
    vec2 transformedUV = uv;
    if (ubuf.fillMode < 0.5) {
        vec2 screenPixel = uv * vec2(ubuf.screenWidth, ubuf.screenHeight);
        vec2 imageOffset = (vec2(ubuf.screenWidth, ubuf.screenHeight) - vec2(imgWidth, imgHeight)) * 0.5;
        vec2 imagePixel = screenPixel - imageOffset;
        transformedUV = imagePixel / vec2(imgWidth, imgHeight);
    } else if (ubuf.fillMode < 1.5) {
        float scale = max(ubuf.screenWidth / imgWidth, ubuf.screenHeight / imgHeight);
        vec2 scaledImageSize = vec2(imgWidth, imgHeight) * scale;
        vec2 offset = (scaledImageSize - vec2(ubuf.screenWidth, ubuf.screenHeight)) / scaledImageSize;
        transformedUV = uv * (vec2(1.0) - offset) + offset * 0.5;
    } else if (ubuf.fillMode < 2.5) {
        float scale = min(ubuf.screenWidth / imgWidth, ubuf.screenHeight / imgHeight);
        vec2 scaledImageSize = vec2(imgWidth, imgHeight) * scale;
        vec2 offset = (vec2(ubuf.screenWidth, ubuf.screenHeight) - scaledImageSize) * 0.5;
        vec2 screenPixel = uv * vec2(ubuf.screenWidth, ubuf.screenHeight);
        vec2 imagePixel = (screenPixel - offset) / scale;
        transformedUV = imagePixel / vec2(imgWidth, imgHeight);
    }
    return transformedUV;
}

vec4 sampleWithFillMode(sampler2D tex, vec2 uv, float w, float h) {
    vec2 tuv = calculateUV(uv, w, h);
    if (tuv.x < 0.0 || tuv.x > 1.0 || tuv.y < 0.0 || tuv.y > 1.0) return ubuf.fillColor;
    return texture(tex, tuv);
}

vec2 quantizeUV(vec2 uv, float cellPx) {
    vec2 screenSize = vec2(max(1.0, ubuf.screenWidth), max(1.0, ubuf.screenHeight));
    float cell = max(1.0, ceil(cellPx));                  // integer pixel cells
    vec2 grid = floor(uv * screenSize / cell) * cell + 0.5 * cell;
    return grid / screenSize;
}

void main() {
    vec2 uv = qt_TexCoord0;

    vec4 oldCol = sampleWithFillMode(source1, uv, ubuf.imageWidth1, ubuf.imageHeight1);

    float p = clamp(ubuf.progress, 0.0, 1.0);
    float pe = p * p * (3.0 - 2.0 * p); // smootherstep for opacity

    // Screen-relative starting cell size:
    // smoothness=0 → ~10% of min(screen), smoothness=1 → ~80% of min(screen)
    float s = clamp(ubuf.smoothness, 0.0, 1.0);
    float minSide = min(max(1.0, ubuf.screenWidth), max(1.0, ubuf.screenHeight));
    float startPx = mix(minSide * 0.10, minSide * 0.80, s);   // big and obvious even on small screens

    // Cell size shrinks continuously from startPx → 1 as p grows
    float cellPx = mix(startPx, 1.0, p);

    // Sample next as pixelated overlay
    vec2 uvq = quantizeUV(uv, cellPx);
    vec4 newPix = sampleWithFillMode(source2, uvq, ubuf.imageWidth2, ubuf.imageHeight2);

    // As we approach the end, sharpen the next from pixelated → full-res
    float sharpen = smoothstep(0.75, 1.0, p);              // only near the end
    vec4 newFull = sampleWithFillMode(source2, uv, ubuf.imageWidth2, ubuf.imageHeight2);
    vec4 newCol = mix(newPix, newFull, sharpen);

    vec4 outColor = mix(oldCol, newCol, pe);

    // Snaps
    if (p <= 0.0) outColor = oldCol;
    if (p >= 1.0) outColor = newFull;

    fragColor = outColor * ubuf.qt_Opacity;
}
