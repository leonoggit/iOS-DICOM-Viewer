//
//  AnomalyDetectionShaders.metal
//  iOS_DICOMViewer
//
//  Metal shaders for anomaly detection visualization
//  Includes GradCAM heatmap rendering and bounding box overlays
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// MARK: - Structs
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct AnomalyBoundingBox {
    float4 bounds; // x, y, width, height in normalized coordinates
    float4 color;
    float confidence;
    int severity;
};

// MARK: - Vertex Shaders
vertex VertexOut heatmapVertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

vertex VertexOut boundingBoxVertexShader(uint vertexID [[vertex_id]],
                                        constant AnomalyBoundingBox& box [[buffer(0)]]) {
    // Generate vertices for a bounding box
    float2 vertices[4] = {
        float2(box.bounds.x, box.bounds.y),                                    // Top-left
        float2(box.bounds.x + box.bounds.z, box.bounds.y),                    // Top-right
        float2(box.bounds.x + box.bounds.z, box.bounds.y + box.bounds.w),    // Bottom-right
        float2(box.bounds.x, box.bounds.y + box.bounds.w)                     // Bottom-left
    };
    
    VertexOut out;
    out.position = float4(vertices[vertexID] * 2.0 - 1.0, 0.0, 1.0);
    out.texCoord = vertices[vertexID];
    return out;
}

// MARK: - Fragment Shaders

// GradCAM heatmap visualization
fragment float4 gradCAMHeatmapShader(VertexOut in [[stage_in]],
                                    texture2d<float> baseImage [[texture(0)]],
                                    texture2d<float> heatmap [[texture(1)]],
                                    constant float& alpha [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    // Sample base image
    float4 baseColor = baseImage.sample(s, in.texCoord);
    
    // Sample heatmap value
    float heatValue = heatmap.sample(s, in.texCoord).r;
    
    // Convert heat value to color using jet colormap
    float3 heatColor;
    if (heatValue < 0.25) {
        // Blue to cyan
        float t = heatValue * 4.0;
        heatColor = mix(float3(0.0, 0.0, 1.0), float3(0.0, 1.0, 1.0), t);
    } else if (heatValue < 0.5) {
        // Cyan to green
        float t = (heatValue - 0.25) * 4.0;
        heatColor = mix(float3(0.0, 1.0, 1.0), float3(0.0, 1.0, 0.0), t);
    } else if (heatValue < 0.75) {
        // Green to yellow
        float t = (heatValue - 0.5) * 4.0;
        heatColor = mix(float3(0.0, 1.0, 0.0), float3(1.0, 1.0, 0.0), t);
    } else {
        // Yellow to red
        float t = (heatValue - 0.75) * 4.0;
        heatColor = mix(float3(1.0, 1.0, 0.0), float3(1.0, 0.0, 0.0), t);
    }
    
    // Blend heatmap with base image
    float3 blendedColor = mix(baseColor.rgb, heatColor, heatValue * alpha);
    
    return float4(blendedColor, baseColor.a);
}

// Anomaly bounding box rendering
fragment float4 boundingBoxFragmentShader(VertexOut in [[stage_in]],
                                        constant AnomalyBoundingBox& box [[buffer(0)]]) {
    // Create thick border effect
    float2 uv = in.texCoord;
    float2 boxSize = float2(box.bounds.z, box.bounds.w);
    float2 localUV = (uv - float2(box.bounds.x, box.bounds.y)) / boxSize;
    
    float borderThickness = 0.02; // 2% of box size
    float border = 0.0;
    
    // Check if we're on the border
    if (localUV.x < borderThickness || localUV.x > 1.0 - borderThickness ||
        localUV.y < borderThickness || localUV.y > 1.0 - borderThickness) {
        border = 1.0;
    }
    
    // Apply severity-based animation
    float pulse = sin(box.confidence * 10.0) * 0.5 + 0.5;
    float4 color = box.color;
    color.a = border * (0.7 + pulse * 0.3);
    
    return color;
}

// MARK: - Compute Shaders

// Metal 4 tensor-based anomaly detection processing
kernel void processAnomalyTensor(texture2d<float, access::read> inputImage [[texture(0)]],
                               texture2d<float, access::write> outputTensor [[texture(1)]],
                               constant float4x4& convolutionWeights [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    
    // Simplified convolution for feature extraction
    float4 pixel = inputImage.read(gid);
    
    // Apply learned weights (from ML model)
    float4 features = convolutionWeights * pixel;
    
    // Activation (ReLU)
    features = max(features, 0.0);
    
    // Write to output tensor
    outputTensor.write(features, gid);
}

// GradCAM computation kernel
kernel void computeGradCAM(texture2d<float, access::read> activations [[texture(0)]],
                          texture2d<float, access::read> gradients [[texture(1)]],
                          texture2d<float, access::write> heatmap [[texture(2)]],
                          uint2 gid [[thread_position_in_grid]]) {
    
    // Read activation and gradient
    float4 activation = activations.read(gid);
    float4 gradient = gradients.read(gid);
    
    // Compute importance as weighted sum
    float importance = dot(activation, gradient);
    
    // Apply ReLU to focus on positive influence
    importance = max(importance, 0.0);
    
    // Normalize (this would be done globally in practice)
    importance = saturate(importance);
    
    // Write heatmap value
    heatmap.write(float4(importance, importance, importance, 1.0), gid);
}

// Temporal difference computation for change detection
kernel void computeTemporalDifference(texture2d<float, access::read> currentImage [[texture(0)]],
                                    texture2d<float, access::read> previousImage [[texture(1)]],
                                    texture2d<float, access::write> differenceMap [[texture(2)]],
                                    constant float& threshold [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    
    float4 current = currentImage.read(gid);
    float4 previous = previousImage.read(gid);
    
    // Compute absolute difference
    float4 diff = abs(current - previous);
    
    // Apply threshold
    float significance = length(diff.rgb) > threshold ? 1.0 : 0.0;
    
    // Color code based on change type
    float3 changeColor;
    if (current.r > previous.r) {
        // Increased density (potential growth)
        changeColor = float3(1.0, 0.0, 0.0); // Red
    } else if (current.r < previous.r) {
        // Decreased density (potential improvement)
        changeColor = float3(0.0, 1.0, 0.0); // Green
    } else {
        // No significant change
        changeColor = float3(0.0, 0.0, 1.0); // Blue
    }
    
    differenceMap.write(float4(changeColor * significance, significance), gid);
}

// MARK: - Metal Performance Shaders Graph Support

// Custom MPS kernel for anomaly segmentation
kernel void anomalySegmentationKernel(texture2d<float, access::read> inputFeatures [[texture(0)]],
                                    texture2d<float, access::write> segmentationMask [[texture(1)]],
                                    constant float& anomalyThreshold [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    
    float4 features = inputFeatures.read(gid);
    
    // Simple threshold-based segmentation (would be ML model output in practice)
    float anomalyScore = length(features.rgb);
    float mask = anomalyScore > anomalyThreshold ? 1.0 : 0.0;
    
    segmentationMask.write(float4(mask, mask, mask, 1.0), gid);
}

// MARK: - Visualization Enhancement Shaders

// Edge detection for anomaly boundaries
kernel void anomalyEdgeDetection(texture2d<float, access::read> segmentationMask [[texture(0)]],
                               texture2d<float, access::write> edgeMap [[texture(1)]],
                               uint2 gid [[thread_position_in_grid]]) {
    
    // Sobel edge detection
    float center = segmentationMask.read(gid).r;
    
    // Sample neighbors
    float top = segmentationMask.read(uint2(gid.x, gid.y - 1)).r;
    float bottom = segmentationMask.read(uint2(gid.x, gid.y + 1)).r;
    float left = segmentationMask.read(uint2(gid.x - 1, gid.y)).r;
    float right = segmentationMask.read(uint2(gid.x + 1, gid.y)).r;
    
    // Compute gradients
    float gx = right - left;
    float gy = bottom - top;
    
    // Edge magnitude
    float edge = length(float2(gx, gy));
    
    edgeMap.write(float4(edge, edge, edge, 1.0), gid);
}

// Confidence visualization overlay
fragment float4 confidenceOverlayShader(VertexOut in [[stage_in]],
                                      texture2d<float> baseImage [[texture(0)]],
                                      constant float& confidence [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    float4 color = baseImage.sample(s, in.texCoord);
    
    // Add confidence indicator in corner
    float2 cornerDist = abs(in.texCoord - float2(0.95, 0.05));
    if (length(cornerDist) < 0.03) {
        // Color based on confidence level
        float3 confColor;
        if (confidence > 0.8) {
            confColor = float3(0.0, 1.0, 0.0); // Green
        } else if (confidence > 0.6) {
            confColor = float3(1.0, 1.0, 0.0); // Yellow
        } else {
            confColor = float3(1.0, 0.0, 0.0); // Red
        }
        color.rgb = mix(color.rgb, confColor, 0.8);
    }
    
    return color;
}

// MARK: - Utility Functions

// Convert DICOM grayscale to RGB with window/level
float3 applyWindowLevel(float pixelValue, float windowCenter, float windowWidth) {
    float minValue = windowCenter - windowWidth / 2.0;
    float maxValue = windowCenter + windowWidth / 2.0;
    
    float normalized = saturate((pixelValue - minValue) / (maxValue - minValue));
    return float3(normalized);
}

// Apply medical imaging colormap
float3 applyMedicalColormap(float value, int colormapType) {
    switch (colormapType) {
        case 0: // Grayscale
            return float3(value);
            
        case 1: // Hot Iron
            return float3(
                smoothstep(0.0, 0.5, value),
                smoothstep(0.3, 0.8, value),
                smoothstep(0.6, 1.0, value)
            );
            
        case 2: // Rainbow
            float h = value * 4.0 + 0.67; // Start at blue
            float3 c = float3(1.0);
            float3 p = c * (1.0 - 1.0);
            float3 q = c * (1.0 - 1.0 * fract(h));
            float3 t = c * (1.0 - 1.0 * (1.0 - fract(h)));
            
            int i = int(h);
            switch (i % 6) {
                case 0: return float3(c.x, t.y, p.z);
                case 1: return float3(q.x, c.y, p.z);
                case 2: return float3(p.x, c.y, t.z);
                case 3: return float3(p.x, q.y, c.z);
                case 4: return float3(t.x, p.y, c.z);
                case 5: return float3(c.x, p.y, q.z);
            }
            
        default:
            return float3(value);
    }
}

// MARK: - iOS 26 Metal 4 Tensor Operations

// Example of using Metal 4 tensor operations for ML inference
kernel void metal4TensorConvolution(texture2d<float, access::read> input [[texture(0)]],
                                  texture2d<float, access::write> output [[texture(1)]],
                                  constant float* weights [[buffer(0)]],
                                  constant int& kernelSize [[buffer(1)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    
    float sum = 0.0;
    int halfKernel = kernelSize / 2;
    
    // Perform convolution
    for (int y = -halfKernel; y <= halfKernel; y++) {
        for (int x = -halfKernel; x <= halfKernel; x++) {
            uint2 samplePos = uint2(gid.x + x, gid.y + y);
            float4 sample = input.read(samplePos);
            
            int weightIndex = (y + halfKernel) * kernelSize + (x + halfKernel);
            sum += sample.r * weights[weightIndex];
        }
    }
    
    // Apply activation (ReLU)
    sum = max(sum, 0.0);
    
    output.write(float4(sum, sum, sum, 1.0), gid);
}