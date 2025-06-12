#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct ThresholdParams {
    float minThreshold;
    float maxThreshold;
};

struct MorphologyParams {
    int operation;  // 0=erosion, 1=dilation, 2=opening, 3=closing
    int radius;
};

struct RegionGrowingParams {
    float2 seedPoint;
    float tolerance;
    int maxIterations;
};

struct EdgeDetectionParams {
    float threshold;
    int filterType; // 0=Sobel, 1=Canny, 2=Laplacian
};

// MARK: - Threshold Segmentation Kernel

kernel void thresholdSegmentationKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant ThresholdParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    float pixelValue = inputTexture.read(gid).r;
    
    // Apply Hounsfield Unit thresholding for CT data
    uint result = (pixelValue >= params.minThreshold && pixelValue <= params.maxThreshold) ? 255 : 0;
    
    outputTexture.write(uint4(result, 0, 0, 0), gid);
}

// MARK: - Advanced Threshold with Histogram Analysis

kernel void adaptiveThresholdKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant float& adaptiveThreshold [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Local window for adaptive thresholding
    int windowSize = 15;
    int halfWindow = windowSize / 2;
    
    float sum = 0.0;
    int count = 0;
    
    // Calculate local mean
    for (int dy = -halfWindow; dy <= halfWindow; dy++) {
        for (int dx = -halfWindow; dx <= halfWindow; dx++) {
            int2 coord = int2(gid) + int2(dx, dy);
            if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                sum += inputTexture.read(uint2(coord)).r;
                count++;
            }
        }
    }
    
    float localMean = sum / float(count);
    float pixelValue = inputTexture.read(gid).r;
    
    uint result = (pixelValue > (localMean + adaptiveThreshold)) ? 255 : 0;
    outputTexture.write(uint4(result, 0, 0, 0), gid);
}

// MARK: - Region Growing Kernel

kernel void regionGrowingKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::read_write> maskTexture [[texture(1)]],
    constant RegionGrowingParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    float pixelValue = inputTexture.read(gid).r;
    uint currentMask = maskTexture.read(gid).r;
    
    // If already processed or seed point
    if (currentMask > 0) {
        return;
    }
    
    // Check if pixel is within tolerance of seed
    float2 currentPos = float2(gid);
    float distance = length(currentPos - params.seedPoint);
    
    if (distance < 50.0) { // Within region
        float seedValue = inputTexture.read(uint2(params.seedPoint)).r;
        if (abs(pixelValue - seedValue) <= params.tolerance) {
            maskTexture.write(uint4(255, 0, 0, 0), gid);
        }
    }
}

// MARK: - Morphological Operations Kernel

kernel void morphologyKernel(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant MorphologyParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    int radius = params.radius;
    bool isErosion = (params.operation == 0 || params.operation == 2); // erosion or opening
    
    uint result = isErosion ? 255 : 0; // Start with white for erosion, black for dilation
    
    // Apply morphological operation in circular kernel
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            if (dx*dx + dy*dy <= radius*radius) { // Circular kernel
                int2 coord = int2(gid) + int2(dx, dy);
                
                if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                    coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                    
                    uint neighborValue = inputTexture.read(uint2(coord)).r;
                    
                    if (isErosion) {
                        result = min(result, neighborValue); // Erosion: min operation
                    } else {
                        result = max(result, neighborValue); // Dilation: max operation
                    }
                }
            }
        }
    }
    
    outputTexture.write(uint4(result, 0, 0, 0), gid);
}

// MARK: - Edge Detection Kernel (Sobel)

kernel void edgeDetectionKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant EdgeDetectionParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Sobel edge detection
    float sobelX[9] = {-1, 0, 1, -2, 0, 2, -1, 0, 1};
    float sobelY[9] = {-1, -2, -1, 0, 0, 0, 1, 2, 1};
    
    float gradientX = 0.0;
    float gradientY = 0.0;
    
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            int2 coord = int2(gid) + int2(dx, dy);
            int kernelIndex = (dy + 1) * 3 + (dx + 1);
            
            if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                
                float pixelValue = inputTexture.read(uint2(coord)).r;
                gradientX += pixelValue * sobelX[kernelIndex];
                gradientY += pixelValue * sobelY[kernelIndex];
            }
        }
    }
    
    float magnitude = sqrt(gradientX * gradientX + gradientY * gradientY);
    uint result = (magnitude > params.threshold) ? 255 : 0;
    
    outputTexture.write(uint4(result, 0, 0, 0), gid);
}

// MARK: - Connected Components Labeling Kernel

kernel void connectedComponentsKernel(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant int& minComponentSize [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    uint pixelValue = inputTexture.read(gid).r;
    
    if (pixelValue == 0) {
        outputTexture.write(uint4(0, 0, 0, 0), gid);
        return;
    }
    
    // Simple flood fill approach (simplified for GPU)
    // In practice, this would need multiple passes or CPU post-processing
    // for full connected components analysis
    
    int componentSize = 0;
    int searchRadius = 10; // Limited search for GPU efficiency
    
    // Count connected pixels in local neighborhood
    for (int dy = -searchRadius; dy <= searchRadius; dy++) {
        for (int dx = -searchRadius; dx <= searchRadius; dx++) {
            int2 coord = int2(gid) + int2(dx, dy);
            
            if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                
                if (inputTexture.read(uint2(coord)).r > 0) {
                    componentSize++;
                }
            }
        }
    }
    
    uint result = (componentSize >= minComponentSize) ? 255 : 0;
    outputTexture.write(uint4(result, 0, 0, 0), gid);
}

// MARK: - Lung-Specific Segmentation Kernel

kernel void lungSegmentationKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> lungMask [[texture(1)]],
    texture2d<uint, access::write> airwayMask [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    float hounsfield = inputTexture.read(gid).r;
    
    // Lung parenchyma: -900 to -500 HU
    bool isLung = (hounsfield >= -900.0 && hounsfield <= -500.0);
    
    // Airways: -1000 to -900 HU (air-filled)
    bool isAirway = (hounsfield >= -1000.0 && hounsfield <= -900.0);
    
    // Additional checks for lung borders and vessels
    if (isLung) {
        // Check for vessel-like structures (higher density within lung)
        if (hounsfield > -300.0) {
            isLung = false; // Likely vessel or nodule
        }
    }
    
    lungMask.write(uint4(isLung ? 255 : 0, 0, 0, 0), gid);
    airwayMask.write(uint4(isAirway ? 255 : 0, 0, 0, 0), gid);
}

// MARK: - Bone Segmentation with Cortical/Trabecular Separation

kernel void boneSegmentationKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> corticalMask [[texture(1)]],
    texture2d<uint, access::write> trabecularMask [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    float hounsfield = inputTexture.read(gid).r;
    
    // Cortical bone: >800 HU (dense bone)
    bool isCortical = (hounsfield > 800.0);
    
    // Trabecular bone: 200-800 HU (spongy bone)
    bool isTrabecular = (hounsfield >= 200.0 && hounsfield <= 800.0);
    
    corticalMask.write(uint4(isCortical ? 255 : 0, 0, 0, 0), gid);
    trabecularMask.write(uint4(isTrabecular ? 255 : 0, 0, 0, 0), gid);
}

// MARK: - Vessel Enhancement Kernel

kernel void vesselEnhancementKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> vesselMask [[texture(1)]],
    constant float& contrastThreshold [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    float pixelValue = inputTexture.read(gid).r;
    
    // Enhanced vessels typically have high attenuation (100-500 HU)
    bool isVessel = (pixelValue >= contrastThreshold && pixelValue <= 500.0);
    
    if (isVessel) {
        // Additional vessel-like structure checks
        float variance = 0.0;
        float mean = 0.0;
        int count = 0;
        
        // Calculate local statistics for tubular structure detection
        for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
                int2 coord = int2(gid) + int2(dx, dy);
                
                if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                    coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                    
                    float neighborValue = inputTexture.read(uint2(coord)).r;
                    mean += neighborValue;
                    count++;
                }
            }
        }
        
        mean /= float(count);
        
        // Calculate variance
        for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
                int2 coord = int2(gid) + int2(dx, dy);
                
                if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                    coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                    
                    float neighborValue = inputTexture.read(uint2(coord)).r;
                    variance += (neighborValue - mean) * (neighborValue - mean);
                }
            }
        }
        
        variance /= float(count);
        
        // Vessels should have relatively uniform intensity
        isVessel = (variance < 1000.0); // Threshold for uniformity
    }
    
    vesselMask.write(uint4(isVessel ? 255 : 0, 0, 0, 0), gid);
}

// MARK: - Multi-Scale Segmentation Kernel

kernel void multiScaleSegmentationKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant float4& thresholds [[buffer(0)]], // min1, max1, min2, max2
    constant int& scaleLevel [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Multi-scale analysis for better organ boundary detection
    int scale = 1 << scaleLevel; // 1, 2, 4, 8...
    
    float localMean = 0.0;
    int count = 0;
    
    // Sample at different scales
    for (int dy = -scale; dy <= scale; dy += scale) {
        for (int dx = -scale; dx <= scale; dx += scale) {
            int2 coord = int2(gid) + int2(dx, dy);
            
            if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                
                localMean += inputTexture.read(uint2(coord)).r;
                count++;
            }
        }
    }
    
    localMean /= float(count);
    
    // Apply multi-threshold segmentation
    bool inRange1 = (localMean >= thresholds.x && localMean <= thresholds.y);
    bool inRange2 = (localMean >= thresholds.z && localMean <= thresholds.w);
    
    uint result = (inRange1 || inRange2) ? 255 : 0;
    outputTexture.write(uint4(result, 0, 0, 0), gid);
}

// MARK: - Noise Reduction Kernel

kernel void noiseReductionKernel(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Median filter for noise reduction
    uint values[9];
    int index = 0;
    
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            int2 coord = int2(gid) + int2(dx, dy);
            
            if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                values[index++] = inputTexture.read(uint2(coord)).r;
            } else {
                values[index++] = 0;
            }
        }
    }
    
    // Simple bubble sort for median
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8 - i; j++) {
            if (values[j] > values[j + 1]) {
                uint temp = values[j];
                values[j] = values[j + 1];
                values[j + 1] = temp;
            }
        }
    }
    
    uint median = values[4]; // Middle value
    outputTexture.write(uint4(median, 0, 0, 0), gid);
}