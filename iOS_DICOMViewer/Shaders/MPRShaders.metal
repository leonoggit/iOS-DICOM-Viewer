//
//  MPRShaders.metal
//  iOS_DICOMViewer
//
//  Metal shaders for Multi-Planar Reconstruction (MPR)
//  Implements 2D slice extraction from 3D volume data
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct MPRRenderParams {
    float3 volumeSize;
    float3 voxelSpacing;
    uint sliceIndex;
    uint plane;  // 0=axial, 1=sagittal, 2=coronal
    float windowCenter;
    float windowWidth;
    float zoom;
    float2 panOffset;
    float rotation;
    bool flipHorizontal;
    bool flipVertical;
    float2 crosshairPosition;
    bool crosshairEnabled;
};

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

// MARK: - Utility Functions

// Apply window/level transformation
static float applyWindowLevel(float value, float center, float width) {
    float lower = center - width * 0.5;
    float upper = center + width * 0.5;
    return saturate((value - lower) / (upper - lower));
}

// Apply 2D transformation (zoom, pan, rotation, flip)
float2 applyTransform(float2 coord, constant MPRRenderParams& params) {
    float2 centeredCoord = coord - 0.5;
    
    // Apply flip
    if (params.flipHorizontal) {
        centeredCoord.x = -centeredCoord.x;
    }
    if (params.flipVertical) {
        centeredCoord.y = -centeredCoord.y;
    }
    
    // Apply rotation
    if (params.rotation != 0.0) {
        float cosR = cos(params.rotation);
        float sinR = sin(params.rotation);
        float2 rotated = float2(
            centeredCoord.x * cosR - centeredCoord.y * sinR,
            centeredCoord.x * sinR + centeredCoord.y * cosR
        );
        centeredCoord = rotated;
    }
    
    // Apply zoom
    centeredCoord /= params.zoom;
    
    // Apply pan
    centeredCoord -= params.panOffset;
    
    return centeredCoord + 0.5;
}

// Get 3D texture coordinate from 2D slice coordinate
float3 getVolumeCoordinate(float2 sliceCoord, constant MPRRenderParams& params) {
    float3 volumeCoord;
    float normalizedSlice = float(params.sliceIndex) / (params.volumeSize[params.plane] - 1.0);
    
    switch (params.plane) {
        case 0: // Axial (XY plane, Z slice)
            volumeCoord = float3(sliceCoord.x, sliceCoord.y, normalizedSlice);
            break;
        case 1: // Sagittal (YZ plane, X slice)
            volumeCoord = float3(normalizedSlice, sliceCoord.x, sliceCoord.y);
            break;
        case 2: // Coronal (XZ plane, Y slice)
            volumeCoord = float3(sliceCoord.x, normalizedSlice, sliceCoord.y);
            break;
        default:
            volumeCoord = float3(sliceCoord.x, sliceCoord.y, normalizedSlice);
            break;
    }
    
    return volumeCoord;
}

// MARK: - MPR Slice Rendering

kernel void mprSliceRender(texture3d<float, access::sample> volume [[texture(0)]],
                          texture2d<float, access::write> output [[texture(1)]],
                          texture1d<float, access::sample> transferFunction [[texture(2)]],
                          constant MPRRenderParams& params [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    sampler volumeSampler(filter::linear, address::clamp_to_edge);
    sampler transferSampler(filter::linear, address::clamp_to_edge);
    
    // Convert pixel coordinates to normalized coordinates [0,1]
    float2 sliceCoord = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());
    
    // Apply transformations (zoom, pan, rotation, flip)
    sliceCoord = applyTransform(sliceCoord, params);
    
    // Check if coordinate is within valid range after transformation
    if (sliceCoord.x < 0.0 || sliceCoord.x > 1.0 || 
        sliceCoord.y < 0.0 || sliceCoord.y > 1.0) {
        output.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }
    
    // Get 3D volume coordinate
    float3 volumeCoord = getVolumeCoordinate(sliceCoord, params);
    
    // Sample volume density
    float density = volume.sample(volumeSampler, volumeCoord).r;
    
    // Apply window/level transformation
    density = applyWindowLevel(density, params.windowCenter, params.windowWidth);
    
    // Apply transfer function if available
    float4 color;
    if (transferFunction.get_width() > 1) {
        color = transferFunction.sample(transferSampler, density);
    } else {
        // Fallback to grayscale
        color = float4(density, density, density, 1.0);
    }
    
    // Draw crosshair if enabled and near crosshair position
    if (params.crosshairEnabled) {
        float2 pixelCoord = float2(gid);
        float2 outputSize = float2(output.get_width(), output.get_height());
        float2 crosshairPixel = params.crosshairPosition * outputSize;
        
        float crosshairThickness = 1.0;
        float crosshairLength = 20.0;
        
        // Check if pixel is on crosshair lines
        bool onHorizontalLine = abs(pixelCoord.y - crosshairPixel.y) < crosshairThickness &&
                               abs(pixelCoord.x - crosshairPixel.x) < crosshairLength;
        bool onVerticalLine = abs(pixelCoord.x - crosshairPixel.x) < crosshairThickness &&
                             abs(pixelCoord.y - crosshairPixel.y) < crosshairLength;
        
        if (onHorizontalLine || onVerticalLine) {
            // Blend crosshair color with image
            float3 crosshairColor = float3(1.0, 1.0, 0.0); // Yellow
            color.rgb = mix(color.rgb, crosshairColor, 0.7);
        }
    }
    
    output.write(color, gid);
}

// MARK: - Annotation Rendering (Vertex Shader)

vertex VertexOut mprAnnotationVertex(VertexIn in [[stage_in]],
                                   constant float4x4& transform [[buffer(0)]]) {
    VertexOut out;
    out.position = transform * float4(in.position, 0.0, 1.0);
    out.color = float4(1.0, 1.0, 0.0, 1.0); // Yellow for annotations
    return out;
}

// MARK: - Annotation Rendering (Fragment Shader)

fragment float4 mprAnnotationFragment(VertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Advanced MPR Features

// Oblique slice rendering for arbitrary plane orientations
kernel void mprObliqueRender(texture3d<float, access::sample> volume [[texture(0)]],
                            texture2d<float, access::write> output [[texture(1)]],
                            texture1d<float, access::sample> transferFunction [[texture(2)]],
                            constant float4x4& slicePlaneMatrix [[buffer(0)]],
                            constant MPRRenderParams& params [[buffer(1)]],
                            uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    constexpr sampler volumeSampler(filter::linear, address::clamp_to_edge);
    constexpr sampler transferSampler(filter::linear, address::clamp_to_edge);
    
    // Convert pixel coordinates to slice plane coordinates
    float2 sliceCoord = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());
    sliceCoord = sliceCoord * 2.0 - 1.0; // Convert to [-1, 1]
    
    // Transform slice coordinate to volume space using the slice plane matrix
    float4 volumePos = slicePlaneMatrix * float4(sliceCoord.x, sliceCoord.y, 0.0, 1.0);
    float3 volumeCoord = volumePos.xyz / volumePos.w;
    
    // Convert to texture coordinates [0, 1]
    volumeCoord = (volumeCoord + 1.0) * 0.5;
    
    // Check bounds
    if (any(volumeCoord < 0.0) || any(volumeCoord > 1.0)) {
        output.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }
    
    // Sample volume
    float density = volume.sample(volumeSampler, volumeCoord).r;
    density = applyWindowLevel(density, params.windowCenter, params.windowWidth);
    
    // Apply transfer function
    float4 color;
    if (transferFunction.get_width() > 1) {
        color = transferFunction.sample(transferSampler, density);
    } else {
        color = float4(density, density, density, 1.0);
    }
    
    output.write(color, gid);
}

// Curved MPR rendering for vessel visualization
kernel void mprCurvedRender(texture3d<float, access::sample> volume [[texture(0)]],
                           texture2d<float, access::write> output [[texture(1)]],
                           texture1d<float, access::sample> transferFunction [[texture(2)]],
                           constant float3* curvePath [[buffer(0)]],
                           constant uint& pathLength [[buffer(1)]],
                           constant MPRRenderParams& params [[buffer(2)]],
                           uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    constexpr sampler volumeSampler(filter::linear, address::clamp_to_edge);
    constexpr sampler transferSampler(filter::linear, address::clamp_to_edge);
    
    // Convert pixel coordinates to curve parameters
    float2 sliceCoord = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());
    
    // U coordinate along the curve [0, 1]
    float u = sliceCoord.x;
    // V coordinate perpendicular to curve [-0.5, 0.5]
    float v = sliceCoord.y - 0.5;
    
    // Get position along curve
    float pathPos = u * float(pathLength - 1);
    uint pathIndex = uint(pathPos);
    float t = pathPos - float(pathIndex);
    
    if (pathIndex >= pathLength - 1) {
        output.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }
    
    // Interpolate along curve
    float3 p0 = curvePath[pathIndex];
    float3 p1 = curvePath[pathIndex + 1];
    float3 curvePoint = mix(p0, p1, t);
    
    // Calculate tangent vector
    float3 tangent = normalize(p1 - p0);
    
    // Calculate perpendicular vectors (simple approach)
    float3 up = float3(0.0, 1.0, 0.0);
    if (abs(dot(tangent, up)) > 0.9) {
        up = float3(1.0, 0.0, 0.0);
    }
    float3 right = normalize(cross(tangent, up));
    up = cross(right, tangent);
    
    // Calculate sampling position
    float3 samplePos = curvePoint + v * right * 10.0; // 10mm perpendicular distance
    
    // Convert to texture coordinates
    float3 volumeCoord = samplePos / params.volumeSize;
    
    // Check bounds
    if (any(volumeCoord < 0.0) || any(volumeCoord > 1.0)) {
        output.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }
    
    // Sample and render
    float density = volume.sample(volumeSampler, volumeCoord).r;
    density = applyWindowLevel(density, params.windowCenter, params.windowWidth);
    
    float4 color;
    if (transferFunction.get_width() > 1) {
        color = transferFunction.sample(transferSampler, density);
    } else {
        color = float4(density, density, density, 1.0);
    }
    
    output.write(color, gid);
}

// Multi-slice MIP (Maximum Intensity Projection) for thick slice viewing
kernel void mprThickSliceMIP(texture3d<float, access::sample> volume [[texture(0)]],
                            texture2d<float, access::write> output [[texture(1)]],
                            texture1d<float, access::sample> transferFunction [[texture(2)]],
                            constant MPRRenderParams& params [[buffer(0)]],
                            constant float& sliceThickness [[buffer(1)]],
                            uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    constexpr sampler volumeSampler(filter::linear, address::clamp_to_edge);
    constexpr sampler transferSampler(filter::linear, address::clamp_to_edge);
    
    float2 sliceCoord = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());
    sliceCoord = applyTransform(sliceCoord, params);
    
    if (sliceCoord.x < 0.0 || sliceCoord.x > 1.0 || 
        sliceCoord.y < 0.0 || sliceCoord.y > 1.0) {
        output.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }
    
    // Calculate thickness in slice units
    float volumeDepth = params.volumeSize[params.plane];
    float thicknessInSlices = sliceThickness / params.voxelSpacing[params.plane];
    int numSamples = max(1, int(thicknessInSlices));
    
    float maxIntensity = 0.0;
    float currentSlice = float(params.sliceIndex) - thicknessInSlices * 0.5;
    float stepSize = thicknessInSlices / float(numSamples);
    
    for (int i = 0; i < numSamples; i++) {
        float slicePos = currentSlice + float(i) * stepSize;
        
        if (slicePos >= 0.0 && slicePos < volumeDepth) {
            float normalizedSlice = slicePos / (volumeDepth - 1.0);
            float3 volumeCoord = getVolumeCoordinate(sliceCoord, params);
            
            // Update the slice coordinate
            volumeCoord[params.plane] = normalizedSlice;
            
            float density = volume.sample(volumeSampler, volumeCoord).r;
            maxIntensity = max(maxIntensity, density);
        }
    }
    
    // Apply window/level and transfer function
    maxIntensity = applyWindowLevel(maxIntensity, params.windowCenter, params.windowWidth);
    
    float4 color;
    if (transferFunction.get_width() > 1) {
        color = transferFunction.sample(transferSampler, maxIntensity);
    } else {
        color = float4(maxIntensity, maxIntensity, maxIntensity, 1.0);
    }
    
    output.write(color, gid);
}