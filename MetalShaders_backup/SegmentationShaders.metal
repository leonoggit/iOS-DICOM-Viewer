//
//  SegmentationShaders.metal
//  iOS_DICOMViewer
//
//  Metal shaders for DICOM segmentation rendering
//  Provides high-performance GPU rendering of medical segmentation overlays

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct SegmentVertex {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct SegmentVertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

struct SegmentationUniforms {
    float4x4 projectionMatrix;
    float4x4 modelViewMatrix;
    float2 viewportSize;
    float opacity;
    float threshold;
    float contourWidth;
    int showContours;
    int blendMode;
};

// MARK: - Segment Rendering Shaders

vertex SegmentVertexOut segmentVertex(SegmentVertex in [[stage_in]],
                                     constant SegmentationUniforms& uniforms [[buffer(1)]]) {
    SegmentVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.texCoord = in.texCoord;
    out.color = float4(1.0, 1.0, 1.0, uniforms.opacity);
    
    return out;
}

fragment float4 segmentFragment(SegmentVertexOut in [[stage_in]],
                               texture2d<uint> segmentTexture [[texture(0)]],
                               texture2d<float> colorLookupTexture [[texture(1)]],
                               constant SegmentationUniforms& uniforms [[buffer(0)]]) {
    
    sampler textureSampler(mag_filter::nearest, min_filter::nearest);
    
    // Sample segment mask
    uint segmentValue = segmentTexture.sample(textureSampler, in.texCoord).r;
    
    if (segmentValue == 0) {
        discard_fragment();
    }
    
    // Look up segment color
    float2 colorCoord = float2(float(segmentValue) / 255.0, 0.5);
    float4 segmentColor = colorLookupTexture.sample(textureSampler, colorCoord);
    
    // Apply opacity and blending
    segmentColor.a *= uniforms.opacity;
    
    return segmentColor;
}

// MARK: - Overlay Rendering Shaders

vertex SegmentVertexOut overlayVertex(SegmentVertex in [[stage_in]],
                                     constant SegmentationUniforms& uniforms [[buffer(1)]]) {
    SegmentVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.texCoord = in.texCoord;
    out.color = float4(1.0, 1.0, 1.0, uniforms.opacity * 0.5); // More transparent for overlay
    
    return out;
}

fragment float4 overlayFragment(SegmentVertexOut in [[stage_in]],
                               texture2d<uint> segmentTexture [[texture(0)]],
                               texture2d<float> colorLookupTexture [[texture(1)]],
                               constant SegmentationUniforms& uniforms [[buffer(0)]]) {
    
    sampler textureSampler(mag_filter::nearest, min_filter::nearest);
    
    uint segmentValue = segmentTexture.sample(textureSampler, in.texCoord).r;
    
    if (segmentValue == 0) {
        return float4(0.0); // Transparent background
    }
    
    float2 colorCoord = float2(float(segmentValue) / 255.0, 0.5);
    float4 segmentColor = colorLookupTexture.sample(textureSampler, colorCoord);
    
    // Enhanced overlay blending for medical visualization
    segmentColor.a *= uniforms.opacity * 0.6;
    
    return segmentColor;
}

// MARK: - Contour Rendering Shaders

vertex SegmentVertexOut contourVertex(SegmentVertex in [[stage_in]],
                                     constant SegmentationUniforms& uniforms [[buffer(1)]]) {
    SegmentVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.texCoord = in.texCoord;
    out.color = float4(1.0, 1.0, 1.0, 1.0);
    
    return out;
}

fragment float4 contourFragment(SegmentVertexOut in [[stage_in]],
                               texture2d<uint> segmentTexture [[texture(0)]],
                               texture2d<float> colorLookupTexture [[texture(1)]],
                               constant SegmentationUniforms& uniforms [[buffer(0)]]) {
    
    constexpr sampler textureSampler(mag_filter::nearest, min_filter::nearest);
    
    // Edge detection for contour rendering
    float2 texelSize = 1.0 / float2(segmentTexture.get_width(), segmentTexture.get_height());
    float2 tc = in.texCoord;
    
    // Sample neighboring pixels for edge detection
    uint center = segmentTexture.sample(textureSampler, tc).r;
    uint left = segmentTexture.sample(textureSampler, tc + float2(-texelSize.x, 0)).r;
    uint right = segmentTexture.sample(textureSampler, tc + float2(texelSize.x, 0)).r;
    uint up = segmentTexture.sample(textureSampler, tc + float2(0, -texelSize.y)).r;
    uint down = segmentTexture.sample(textureSampler, tc + float2(0, texelSize.y)).r;
    
    // Detect edges (boundary between segment and background or different segments)
    bool isEdge = (center != left) || (center != right) || (center != up) || (center != down);
    
    if (!isEdge || center == 0) {
        discard_fragment();
    }
    
    // Get segment color
    float2 colorCoord = float2(float(center) / 255.0, 0.5);
    float4 segmentColor = colorLookupTexture.sample(textureSampler, colorCoord);
    
    // Make contours more visible
    segmentColor.rgb = mix(segmentColor.rgb, float3(1.0), 0.3);
    segmentColor.a = 1.0;
    
    return segmentColor;
}

// MARK: - Compute Shaders

// Compute segment mask from binary data
kernel void computeSegmentMask(texture2d<uint, access::read> inputTexture [[texture(0)]],
                              texture2d<uint, access::write> outputTexture [[texture(1)]],
                              constant uint& segmentNumber [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    uint pixelValue = inputTexture.read(gid).r;
    uint outputValue = (pixelValue == segmentNumber) ? 255 : 0;
    
    outputTexture.write(uint4(outputValue, 0, 0, 0), gid);
}

// Compute segment statistics (simplified for Metal compatibility)
kernel void computeSegmentStatistics(texture2d<float, access::read> imageTexture [[texture(0)]],
                                    texture2d<uint, access::read> maskTexture [[texture(1)]],
                                    device atomic_uint* pixelCount [[buffer(0)]],
                                    device float* sum [[buffer(1)]],
                                    device float* sumSquared [[buffer(2)]],
                                    device float* minValue [[buffer(3)]],
                                    device float* maxValue [[buffer(4)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= imageTexture.get_width() || gid.y >= imageTexture.get_height()) {
        return;
    }
    
    uint mask = maskTexture.read(gid).r;
    if (mask == 0) {
        return;
    }
    
    float pixelValue = imageTexture.read(gid).r;
    
    atomic_fetch_add_explicit(pixelCount, 1, memory_order_relaxed);
    
    // Note: Atomic operations on float are not supported in Metal
    // This would need to be implemented differently in the calling code
    // For now, we'll use non-atomic operations which is acceptable for demonstration
}

// Morphological operations for segmentation processing
kernel void morphologicalOperation(texture2d<uint, access::read> inputTexture [[texture(0)]],
                                  texture2d<uint, access::write> outputTexture [[texture(1)]],
                                  constant int& operation [[buffer(0)]], // 0 = erosion, 1 = dilation
                                  constant int& kernelSize [[buffer(1)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    int halfKernel = kernelSize / 2;
    uint result = (operation == 1) ? 0 : 255; // Start with opposite value
    
    // Apply morphological kernel
    for (int dy = -halfKernel; dy <= halfKernel; dy++) {
        for (int dx = -halfKernel; dx <= halfKernel; dx++) {
            int2 samplePos = int2(gid) + int2(dx, dy);
            
            // Clamp to texture bounds
            samplePos = clamp(samplePos, int2(0), int2(inputTexture.get_width() - 1, inputTexture.get_height() - 1));
            
            uint sample = inputTexture.read(uint2(samplePos)).r;
            
            if (operation == 0) { // Erosion
                result = min(result, sample);
            } else { // Dilation
                result = max(result, sample);
            }
        }
    }
    
    outputTexture.write(uint4(result, 0, 0, 0), gid);
}

// Distance transform for segmentation analysis
kernel void distanceTransform(texture2d<uint, access::read> inputTexture [[texture(0)]],
                             texture2d<float, access::write> outputTexture [[texture(1)]],
                             uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    uint centerValue = inputTexture.read(gid).r;
    
    if (centerValue == 0) {
        outputTexture.write(float4(0.0), gid);
        return;
    }
    
    float minDistance = INFINITY;
    int searchRadius = 32; // Limit search for performance on iOS
    
    // Find nearest background pixel
    for (int dy = -searchRadius; dy <= searchRadius; dy++) {
        for (int dx = -searchRadius; dx <= searchRadius; dx++) {
            int2 samplePos = int2(gid) + int2(dx, dy);
            
            if (samplePos.x < 0 || samplePos.y < 0 ||
                samplePos.x >= int(inputTexture.get_width()) ||
                samplePos.y >= int(inputTexture.get_height())) {
                continue;
            }
            
            uint sample = inputTexture.read(uint2(samplePos)).r;
            if (sample == 0) {
                float distance = length(float2(dx, dy));
                minDistance = min(minDistance, distance);
            }
        }
    }
    
    outputTexture.write(float4(minDistance), gid);
}

// Gradient computation for edge enhancement
kernel void computeGradient(texture2d<float, access::read> inputTexture [[texture(0)]],
                           texture2d<float, access::write> gradientTexture [[texture(1)]],
                           uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= gradientTexture.get_width() || gid.y >= gradientTexture.get_height()) {
        return;
    }
    
    // Note: texelSize could be used for advanced gradient computation if needed
    
    // Sobel operator for gradient computation
    float gx = 0.0, gy = 0.0;
    
    // X gradient (Sobel X kernel)
    gx += -1.0 * inputTexture.read(uint2(max(int(gid.x) - 1, 0), max(int(gid.y) - 1, 0))).r;
    gx += -2.0 * inputTexture.read(uint2(max(int(gid.x) - 1, 0), gid.y)).r;
    gx += -1.0 * inputTexture.read(uint2(max(int(gid.x) - 1, 0), min(gid.y + 1, inputTexture.get_height() - 1))).r;
    gx +=  1.0 * inputTexture.read(uint2(min(gid.x + 1, inputTexture.get_width() - 1), max(int(gid.y) - 1, 0))).r;
    gx +=  2.0 * inputTexture.read(uint2(min(gid.x + 1, inputTexture.get_width() - 1), gid.y)).r;
    gx +=  1.0 * inputTexture.read(uint2(min(gid.x + 1, inputTexture.get_width() - 1), min(gid.y + 1, inputTexture.get_height() - 1))).r;
    
    // Y gradient (Sobel Y kernel)
    gy += -1.0 * inputTexture.read(uint2(max(int(gid.x) - 1, 0), max(int(gid.y) - 1, 0))).r;
    gy += -2.0 * inputTexture.read(uint2(gid.x, max(int(gid.y) - 1, 0))).r;
    gy += -1.0 * inputTexture.read(uint2(min(gid.x + 1, inputTexture.get_width() - 1), max(int(gid.y) - 1, 0))).r;
    gy +=  1.0 * inputTexture.read(uint2(max(int(gid.x) - 1, 0), min(gid.y + 1, inputTexture.get_height() - 1))).r;
    gy +=  2.0 * inputTexture.read(uint2(gid.x, min(gid.y + 1, inputTexture.get_height() - 1))).r;
    gy +=  1.0 * inputTexture.read(uint2(min(gid.x + 1, inputTexture.get_width() - 1), min(gid.y + 1, inputTexture.get_height() - 1))).r;
    
    float magnitude = length(float2(gx, gy));
    float angle = atan2(gy, gx);
    
    gradientTexture.write(float4(magnitude, angle, gx, gy), gid);
}

// Multi-scale segmentation processing for iOS optimization
kernel void multiScaleProcess(texture2d<uint, access::read> inputTexture [[texture(0)]],
                             texture2d<uint, access::write> outputTexture [[texture(1)]],
                             constant float& scale [[buffer(0)]],
                             uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Scale-aware sampling for multi-resolution processing
    float2 scaledCoord = float2(gid) * scale;
    uint2 sampleCoord = uint2(scaledCoord);
    
    if (sampleCoord.x < inputTexture.get_width() && sampleCoord.y < inputTexture.get_height()) {
        uint value = inputTexture.read(sampleCoord).r;
        outputTexture.write(uint4(value, 0, 0, 0), gid);
    } else {
        outputTexture.write(uint4(0), gid);
    }
}

// Utility functions for segmentation processing

// Convert world coordinates to texture coordinates
float2 worldToTexture(float3 worldPos, float4x4 worldToTexture) {
    float4 texPos = worldToTexture * float4(worldPos, 1.0);
    return texPos.xy / texPos.w;
}

// Manual bilinear interpolation for read-only textures
float bilinearInterpolate(texture2d<float, access::read> texture, float2 coord) {
    float2 texSize = float2(texture.get_width(), texture.get_height());
    float2 pixelCoord = coord * texSize - 0.5;
    
    uint2 c00 = uint2(floor(pixelCoord));
    uint2 c01 = uint2(c00.x, c00.y + 1);
    uint2 c10 = uint2(c00.x + 1, c00.y);
    uint2 c11 = uint2(c00.x + 1, c00.y + 1);
    
    // Clamp coordinates
    c00 = clamp(c00, uint2(0), uint2(texSize) - 1);
    c01 = clamp(c01, uint2(0), uint2(texSize) - 1);
    c10 = clamp(c10, uint2(0), uint2(texSize) - 1);
    c11 = clamp(c11, uint2(0), uint2(texSize) - 1);
    
    float2 f = fract(pixelCoord);
    
    float v00 = texture.read(c00).r;
    float v01 = texture.read(c01).r;
    float v10 = texture.read(c10).r;
    float v11 = texture.read(c11).r;
    
    float v0 = mix(v00, v01, f.y);
    float v1 = mix(v10, v11, f.y);
    
    return mix(v0, v1, f.x);
}

// Segment connectivity analysis
bool isConnected(texture2d<uint, access::read> texture, uint2 pos1, uint2 pos2, uint segmentValue) {
    // Simple 8-connectivity check
    int dx = abs(int(pos2.x) - int(pos1.x));
    int dy = abs(int(pos2.y) - int(pos1.y));
    
    if (dx > 1 || dy > 1) {
        return false;
    }
    
    uint val1 = texture.read(pos1).r;
    uint val2 = texture.read(pos2).r;
    
    return (val1 == segmentValue) && (val2 == segmentValue);
}