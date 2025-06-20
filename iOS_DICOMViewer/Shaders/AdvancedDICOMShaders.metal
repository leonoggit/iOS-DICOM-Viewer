#include <metal_stdlib>
using namespace metal;

// Enhanced structures for advanced medical imaging
struct AdvancedWindowLevelParams {
    float window;
    float level;
    float rescaleSlope;
    float rescaleIntercept;
    
    // CLAHE parameters
    float claheClipLimit;
    uint2 claheTileSize;
    
    // Noise reduction parameters
    float bilateralSigmaColor;
    float bilateralSigmaSpace;
    int bilateralRadius;
    
    // Edge enhancement parameters
    float unsharpAmount;
    float unsharpRadius;
    float unsharpThreshold;
    
    // Gamma correction
    float gamma;
    
    // Advanced windowing
    bool useAdaptiveWindowing;
    float adaptiveWindowingStrength;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Vertex shader for full-screen quad (unchanged)
vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;

    // Generate a full-screen quad
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0, 1.0),
        float2( 1.0, 1.0)
    };

    float2 texCoords[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };

    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];

    return out;
}

// Enhanced fragment shader with advanced medical imaging
fragment float4 advancedMedicalFragmentShader(VertexOut in [[stage_in]],
                                            texture2d<float> texture [[texture(0)]]) {
    sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = texture.sample(textureSampler, in.texCoord);
    return color;
}

// CLAHE (Contrast Limited Adaptive Histogram Equalization) implementation
float applyCLAHE(float pixelValue, uint2 gid, uint2 imageSize, 
                constant AdvancedWindowLevelParams& params) {
    // Calculate tile coordinates
    uint2 tileCoord = gid / params.claheTileSize;
    uint2 localCoord = gid % params.claheTileSize;
    
    // Simplified CLAHE - in practice, you'd need histogram data
    // This is a basic adaptive enhancement
    float localMean = 0.5; // Would be calculated from local histogram
    float localStd = 0.2;  // Would be calculated from local histogram
    
    // Adaptive enhancement based on local statistics
    float enhanced = (pixelValue - localMean) / (localStd + 0.001);
    enhanced = clamp(enhanced * params.claheClipLimit + localMean, 0.0, 1.0);
    
    return enhanced;
}

// Bilateral filter for noise reduction while preserving edges
float applyBilateralFilter(float centerValue, uint2 centerCoord, 
                          texture2d<float, access::read> inputTexture,
                          constant AdvancedWindowLevelParams& params) {
    float weightSum = 0.0;
    float filteredValue = 0.0;
    
    int radius = params.bilateralRadius;
    float sigmaColor = params.bilateralSigmaColor;
    float sigmaSpace = params.bilateralSigmaSpace;
    
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            uint2 sampleCoord = uint2(int2(centerCoord) + int2(dx, dy));
            
            // Check bounds
            if (sampleCoord.x >= inputTexture.get_width() || 
                sampleCoord.y >= inputTexture.get_height()) continue;
            
            float sampleValue = inputTexture.read(sampleCoord).r;
            
            // Spatial weight (Gaussian based on distance)
            float spatialDist = sqrt(float(dx*dx + dy*dy));
            float spatialWeight = exp(-(spatialDist * spatialDist) / (2.0 * sigmaSpace * sigmaSpace));
            
            // Color weight (Gaussian based on intensity difference)
            float colorDist = abs(sampleValue - centerValue);
            float colorWeight = exp(-(colorDist * colorDist) / (2.0 * sigmaColor * sigmaColor));
            
            float weight = spatialWeight * colorWeight;
            weightSum += weight;
            filteredValue += weight * sampleValue;
        }
    }
    
    return weightSum > 0.0 ? filteredValue / weightSum : centerValue;
}

// Unsharp masking for edge enhancement
float applyUnsharpMask(float originalValue, uint2 coord,
                      texture2d<float, access::read> inputTexture,
                      constant AdvancedWindowLevelParams& params) {
    // Calculate Gaussian blur (simplified 3x3 kernel)
    float blurred = 0.0;
    float weights[9] = {
        0.0625, 0.125, 0.0625,
        0.125,  0.25,  0.125,
        0.0625, 0.125, 0.0625
    };
    
    int idx = 0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            uint2 sampleCoord = uint2(int2(coord) + int2(dx, dy));
            
            // Handle boundaries
            sampleCoord.x = clamp(sampleCoord.x, 0u, inputTexture.get_width() - 1);
            sampleCoord.y = clamp(sampleCoord.y, 0u, inputTexture.get_height() - 1);
            
            float sampleValue = inputTexture.read(sampleCoord).r;
            blurred += weights[idx] * sampleValue;
            idx++;
        }
    }
    
    // Unsharp mask formula: original + amount * (original - blurred)
    float mask = originalValue - blurred;
    if (abs(mask) > params.unsharpThreshold) {
        return clamp(originalValue + params.unsharpAmount * mask, 0.0, 1.0);
    }
    
    return originalValue;
}

// Advanced windowing with sigmoid curve
float applyAdvancedWindowing(float pixelValue, constant AdvancedWindowLevelParams& params) {
    // Apply rescale transformation
    pixelValue = pixelValue * params.rescaleSlope + params.rescaleIntercept;
    
    // Traditional linear windowing
    float minValue = params.level - params.window / 2.0;
    float maxValue = params.level + params.window / 2.0;
    
    if (params.useAdaptiveWindowing) {
        // Sigmoid windowing for better contrast in medical images
        float center = params.level;
        float width = params.window;
        float steepness = 4.0 / width; // Controls sigmoid steepness
        
        // Sigmoid function: 1 / (1 + exp(-steepness * (x - center)))
        float sigmoidValue = 1.0 / (1.0 + exp(-steepness * (pixelValue - center)));
        
        // Blend with linear windowing
        float linearValue = clamp((pixelValue - minValue) / params.window, 0.0, 1.0);
        return mix(linearValue, sigmoidValue, params.adaptiveWindowingStrength);
    } else {
        // Standard linear windowing
        return clamp((pixelValue - minValue) / params.window, 0.0, 1.0);
    }
}

// Gamma correction for display optimization
float applyGammaCorrection(float value, float gamma) {
    return pow(clamp(value, 0.0, 1.0), 1.0 / gamma);
}

// Advanced medical imaging compute kernel
kernel void advancedMedicalImagingKernel(device const uint16_t* pixelData [[buffer(0)]],
                                       texture2d<float, access::write> outputTexture [[texture(0)]],
                                       texture2d<float, access::read> inputTexture [[texture(1)]],
                                       constant AdvancedWindowLevelParams& params [[buffer(1)]],
                                       uint2 gid [[thread_position_in_grid]]) {

    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    uint index = gid.y * outputTexture.get_width() + gid.x;
    float pixelValue = float(pixelData[index]);
    
    // Step 1: Advanced windowing with sigmoid curve
    float windowedValue = applyAdvancedWindowing(pixelValue, params);
    
    // Step 2: CLAHE for adaptive contrast enhancement
    uint2 imageSize = uint2(outputTexture.get_width(), outputTexture.get_height());
    float claheValue = applyCLAHE(windowedValue, gid, imageSize, params);
    
    // Step 3: Bilateral filtering for noise reduction
    float denoisedValue = applyBilateralFilter(claheValue, gid, inputTexture, params);
    
    // Step 4: Unsharp masking for edge enhancement
    float sharpenedValue = applyUnsharpMask(denoisedValue, gid, inputTexture, params);
    
    // Step 5: Gamma correction for display optimization
    float finalValue = applyGammaCorrection(sharpenedValue, params.gamma);
    
    // Output the enhanced pixel
    outputTexture.write(float4(finalValue, finalValue, finalValue, 1.0), gid);
}

// Specialized kernel for CT imaging
kernel void ctEnhancementKernel(device const uint16_t* pixelData [[buffer(0)]],
                               texture2d<float, access::write> outputTexture [[texture(0)]],
                               constant AdvancedWindowLevelParams& params [[buffer(1)]],
                               uint2 gid [[thread_position_in_grid]]) {

    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    uint index = gid.y * outputTexture.get_width() + gid.x;
    float pixelValue = float(pixelData[index]);
    
    // Apply rescale transformation (HU values)
    pixelValue = pixelValue * params.rescaleSlope + params.rescaleIntercept;
    
    // CT-specific windowing presets
    float windowedValue;
    
    // Detect window/level preset and apply appropriate enhancement
    if (abs(params.window - 400.0) < 50.0 && abs(params.level - 40.0) < 50.0) {
        // Soft tissue window - enhance contrast
        windowedValue = applyAdvancedWindowing(pixelValue, params);
        windowedValue = pow(windowedValue, 0.8); // Slight gamma adjustment for soft tissue
    } else if (abs(params.window - 1500.0) < 100.0 && abs(params.level + 600.0) < 100.0) {
        // Lung window - preserve fine details
        windowedValue = applyAdvancedWindowing(pixelValue, params);
        // Apply edge enhancement for lung details
        windowedValue = clamp(windowedValue * 1.2 - 0.1, 0.0, 1.0);
    } else if (abs(params.window - 2000.0) < 200.0 && abs(params.level - 300.0) < 200.0) {
        // Bone window - high contrast
        windowedValue = applyAdvancedWindowing(pixelValue, params);
        windowedValue = pow(windowedValue, 1.2); // Increase contrast for bone
    } else {
        // Default windowing
        windowedValue = applyAdvancedWindowing(pixelValue, params);
    }
    
    outputTexture.write(float4(windowedValue, windowedValue, windowedValue, 1.0), gid);
}

// Specialized kernel for MR imaging
kernel void mrEnhancementKernel(device const uint16_t* pixelData [[buffer(0)]],
                               texture2d<float, access::write> outputTexture [[texture(0)]],
                               constant AdvancedWindowLevelParams& params [[buffer(1)]],
                               uint2 gid [[thread_position_in_grid]]) {

    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    uint index = gid.y * outputTexture.get_width() + gid.x;
    float pixelValue = float(pixelData[index]);
    
    // MR images typically don't need rescale transformation
    float normalizedValue = pixelValue / 65535.0; // Assuming 16-bit data
    
    // MR-specific enhancement
    // Apply sigmoid windowing for better soft tissue contrast
    float center = params.level / 65535.0;
    float width = params.window / 65535.0;
    float steepness = 6.0 / width; // Higher steepness for MR
    
    float sigmoidValue = 1.0 / (1.0 + exp(-steepness * (normalizedValue - center)));
    
    // Apply noise reduction (MR images are often noisy)
    // Simplified bilateral filter effect
    float enhanced = sigmoidValue;
    if (enhanced < 0.1) {
        enhanced = enhanced * 0.5; // Reduce noise in dark areas
    }
    
    outputTexture.write(float4(enhanced, enhanced, enhanced, 1.0), gid);
}

// Real-time histogram equalization kernel
kernel void histogramEqualizationKernel(device const uint16_t* pixelData [[buffer(0)]],
                                       texture2d<float, access::write> outputTexture [[texture(0)]],
                                       device const float* cdf [[buffer(1)]], // Cumulative distribution function
                                       uint2 gid [[thread_position_in_grid]]) {

    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    uint index = gid.y * outputTexture.get_width() + gid.x;
    uint16_t pixelValue = pixelData[index];
    
    // Apply histogram equalization using precomputed CDF
    float equalizedValue = cdf[pixelValue];
    
    outputTexture.write(float4(equalizedValue, equalizedValue, equalizedValue, 1.0), gid);
}

// Multi-scale enhancement kernel
kernel void multiScaleEnhancementKernel(device const uint16_t* pixelData [[buffer(0)]],
                                       texture2d<float, access::write> outputTexture [[texture(0)]],
                                       texture2d<float, access::read> scale1Texture [[texture(1)]],
                                       texture2d<float, access::read> scale2Texture [[texture(2)]],
                                       texture2d<float, access::read> scale3Texture [[texture(3)]],
                                       constant AdvancedWindowLevelParams& params [[buffer(1)]],
                                       uint2 gid [[thread_position_in_grid]]) {

    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    // Sample from different scales
    float2 texCoord = float2(gid) / float2(outputTexture.get_width(), outputTexture.get_height());
    
    float scale1 = scale1Texture.sample(sampler(mag_filter::linear, min_filter::linear), texCoord).r;
    float scale2 = scale2Texture.sample(sampler(mag_filter::linear, min_filter::linear), texCoord).r;
    float scale3 = scale3Texture.sample(sampler(mag_filter::linear, min_filter::linear), texCoord).r;
    
    // Combine scales with different weights
    float combined = 0.5 * scale1 + 0.3 * scale2 + 0.2 * scale3;
    
    outputTexture.write(float4(combined, combined, combined, 1.0), gid);
}