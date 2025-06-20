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

// MARK: - Enhanced Urinary Tract Segmentation Kernels

struct UrinaryTractParams {
    float kidneyMinHU;
    float kidneyMaxHU;
    float ureterMinHU;
    float ureterMaxHU;
    float bladderMinHU;
    float bladderMaxHU;
    float stoneMinHU;
    float stoneMaxHU;
    int isContrastEnhanced;
};

struct BilateralSeparationParams {
    float2 leftKidneyCenter;
    float2 rightKidneyCenter;
    float separationThreshold;
    int imageWidth;
};

// MARK: - Bilateral Kidney Segmentation Kernel

kernel void bilateralKidneySegmentationKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> leftKidneyMask [[texture(1)]],
    texture2d<uint, access::write> rightKidneyMask [[texture(2)]],
    constant UrinaryTractParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    float hounsfield = inputTexture.read(gid).r;
    
    // Check if pixel is within kidney HU range
    bool isKidneyTissue = (hounsfield >= params.kidneyMinHU && hounsfield <= params.kidneyMaxHU);
    
    if (!isKidneyTissue) {
        leftKidneyMask.write(uint4(0, 0, 0, 0), gid);
        rightKidneyMask.write(uint4(0, 0, 0, 0), gid);
        return;
    }
    
    // Bilateral separation based on anatomical position
    // Left kidney typically at x < imageWidth/2, right kidney at x > imageWidth/2
    int midLine = int(inputTexture.get_width()) / 2;
    
    if (int(gid.x) < midLine) {
        // Left side - potential left kidney
        leftKidneyMask.write(uint4(255, 0, 0, 0), gid);
        rightKidneyMask.write(uint4(0, 0, 0, 0), gid);
    } else {
        // Right side - potential right kidney
        leftKidneyMask.write(uint4(0, 0, 0, 0), gid);
        rightKidneyMask.write(uint4(255, 0, 0, 0), gid);
    }
}

// MARK: - Tubular Structure Enhancement Kernel

kernel void tubularStructureEnhancementKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant UrinaryTractParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    float hounsfield = inputTexture.read(gid).r;
    
    // Ureter detection - low HU values for fluid
    bool isUreter = (hounsfield >= params.ureterMinHU && hounsfield <= params.ureterMaxHU);
    
    if (isUreter) {
        // Enhanced tubular structure detection using local gradient analysis
        float gradientMagnitude = 0.0;
        float3x3 sobelX = float3x3(-1, 0, 1, -2, 0, 2, -1, 0, 1);
        float3x3 sobelY = float3x3(-1, -2, -1, 0, 0, 0, 1, 2, 1);
        
        float gx = 0.0, gy = 0.0;
        
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                int2 coord = int2(gid) + int2(dx, dy);
                
                if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                    coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                    
                    float pixelValue = inputTexture.read(uint2(coord)).r;
                    gx += pixelValue * sobelX[dy + 1][dx + 1];
                    gy += pixelValue * sobelY[dy + 1][dx + 1];
                }
            }
        }
        
        gradientMagnitude = sqrt(gx * gx + gy * gy);
        
        // Tubular structures have specific gradient characteristics
        bool isTubular = (gradientMagnitude > 10.0 && gradientMagnitude < 100.0);
        
        outputTexture.write(uint4(isTubular ? 255 : 0, 0, 0, 0), gid);
    } else {
        outputTexture.write(uint4(0, 0, 0, 0), gid);
    }
}

// MARK: - Bladder Segmentation Kernel

kernel void bladderSegmentationKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant UrinaryTractParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    float hounsfield = inputTexture.read(gid).r;
    
    // Bladder detection - urine HU values
    bool isBladder = (hounsfield >= params.bladderMinHU && hounsfield <= params.bladderMaxHU);
    
    if (isBladder) {
        // Additional checks for large, smooth, fluid-filled structure
        float variance = 0.0;
        float mean = 0.0;
        int count = 0;
        int radius = 5;
        
        // Calculate local statistics to ensure smooth, uniform region
        for (int dy = -radius; dy <= radius; dy++) {
            for (int dx = -radius; dx <= radius; dx++) {
                if (dx*dx + dy*dy <= radius*radius) {
                    int2 coord = int2(gid) + int2(dx, dy);
                    
                    if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                        coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                        
                        float neighborValue = inputTexture.read(uint2(coord)).r;
                        mean += neighborValue;
                        count++;
                    }
                }
            }
        }
        
        mean /= float(count);
        
        // Calculate variance
        for (int dy = -radius; dy <= radius; dy++) {
            for (int dx = -radius; dx <= radius; dx++) {
                if (dx*dx + dy*dy <= radius*radius) {
                    int2 coord = int2(gid) + int2(dx, dy);
                    
                    if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                        coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                        
                        float neighborValue = inputTexture.read(uint2(coord)).r;
                        variance += (neighborValue - mean) * (neighborValue - mean);
                    }
                }
            }
        }
        
        variance /= float(count);
        
        // Bladder should have low variance (uniform fluid)
        bool isUniformFluid = (variance < 100.0);
        
        outputTexture.write(uint4(isUniformFluid ? 255 : 0, 0, 0, 0), gid);
    } else {
        outputTexture.write(uint4(0, 0, 0, 0), gid);
    }
}

// MARK: - Urinary Stone Detection Kernel

kernel void urinaryStoneDetectionKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant UrinaryTractParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    float hounsfield = inputTexture.read(gid).r;
    
    // Stone detection - very high HU values
    bool isStone = (hounsfield >= params.stoneMinHU && hounsfield <= params.stoneMaxHU);
    
    if (isStone) {
        // Additional validation for stone-like characteristics
        // Stones are typically small, dense, and have sharp boundaries
        
        float contrast = 0.0;
        int radius = 3;
        
        // Calculate local contrast to ensure sharp boundaries
        float centerValue = hounsfield;
        float peripherySum = 0.0;
        int peripheryCount = 0;
        
        for (int dy = -radius; dy <= radius; dy++) {
            for (int dx = -radius; dx <= radius; dx++) {
                int distance = dx*dx + dy*dy;
                
                if (distance > (radius-1)*(radius-1) && distance <= radius*radius) {
                    int2 coord = int2(gid) + int2(dx, dy);
                    
                    if (coord.x >= 0 && coord.x < int(inputTexture.get_width()) &&
                        coord.y >= 0 && coord.y < int(inputTexture.get_height())) {
                        
                        peripherySum += inputTexture.read(uint2(coord)).r;
                        peripheryCount++;
                    }
                }
            }
        }
        
        if (peripheryCount > 0) {
            float peripheryMean = peripherySum / float(peripheryCount);
            contrast = centerValue - peripheryMean;
        }
        
        // Stones should have high contrast with surroundings
        bool hasStoneCharacteristics = (contrast > 200.0);
        
        outputTexture.write(uint4(hasStoneCharacteristics ? 255 : 0, 0, 0, 0), gid);
    } else {
        outputTexture.write(uint4(0, 0, 0, 0), gid);
    }
}

// MARK: - Kidney Boundary Refinement Kernel

kernel void kidneyBoundaryRefinementKernel(
    texture2d<uint, access::read> inputMask [[texture(0)]],
    texture2d<float, access::read> originalImage [[texture(1)]],
    texture2d<uint, access::write> outputMask [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputMask.get_width() || gid.y >= inputMask.get_height()) {
        return;
    }
    
    uint currentPixel = inputMask.read(gid).r;
    
    if (currentPixel == 0) {
        outputMask.write(uint4(0, 0, 0, 0), gid);
        return;
    }
    
    // Boundary refinement using gradient information
    float originalValue = originalImage.read(gid).r;
    
    // Check if this pixel is on the boundary
    bool isBoundary = false;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            
            int2 coord = int2(gid) + int2(dx, dy);
            
            if (coord.x >= 0 && coord.x < int(inputMask.get_width()) &&
                coord.y >= 0 && coord.y < int(inputMask.get_height())) {
                
                uint neighborMask = inputMask.read(uint2(coord)).r;
                if (neighborMask == 0) {
                    isBoundary = true;
                    break;
                }
            }
        }
        if (isBoundary) break;
    }
    
    if (isBoundary) {
        // Apply gradient-based boundary refinement
        float gradientMagnitude = 0.0;
        
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                int2 coord = int2(gid) + int2(dx, dy);
                
                if (coord.x >= 0 && coord.x < int(originalImage.get_width()) &&
                    coord.y >= 0 && coord.y < int(originalImage.get_height())) {
                    
                    float neighborValue = originalImage.read(uint2(coord)).r;
                    gradientMagnitude += abs(neighborValue - originalValue);
                }
            }
        }
        
        // Keep boundary pixel if gradient is strong enough
        bool keepPixel = (gradientMagnitude > 50.0);
        outputMask.write(uint4(keepPixel ? 255 : 0, 0, 0, 0), gid);
    } else {
        // Interior pixel - keep as is
        outputMask.write(uint4(255, 0, 0, 0), gid);
    }
}

// MARK: - Anatomical Constraint Validation Kernel

kernel void anatomicalConstraintValidationKernel(
    texture2d<uint, access::read> kidneyMask [[texture(0)]],
    texture2d<uint, access::read> ureterMask [[texture(1)]],
    texture2d<uint, access::read> bladderMask [[texture(2)]],
    texture2d<uint, access::write> validatedMask [[texture(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= kidneyMask.get_width() || gid.y >= kidneyMask.get_height()) {
        return;
    }
    
    uint kidneyPixel = kidneyMask.read(gid).r;
    uint ureterPixel = ureterMask.read(gid).r;
    uint bladderPixel = bladderMask.read(gid).r;
    
    // Anatomical constraints:
    // 1. Kidneys should be in upper region
    // 2. Bladder should be in lower region
    // 3. Ureters should connect kidneys to bladder
    
    float relativeY = float(gid.y) / float(kidneyMask.get_height());
    
    bool isValid = true;
    
    // Kidney constraint - should be in upper 2/3 of image
    if (kidneyPixel > 0 && relativeY > 0.8) {
        isValid = false; // Kidney too low
    }
    
    // Bladder constraint - should be in lower 1/3 of image
    if (bladderPixel > 0 && relativeY < 0.5) {
        isValid = false; // Bladder too high
    }
    
    // Output validated pixel
    uint outputValue = 0;
    if (isValid) {
        if (kidneyPixel > 0) outputValue = 1;      // Kidney = 1
        else if (ureterPixel > 0) outputValue = 2; // Ureter = 2
        else if (bladderPixel > 0) outputValue = 3; // Bladder = 3
    }
    
    validatedMask.write(uint4(outputValue * 85, 0, 0, 0), gid); // Scale for visibility
}