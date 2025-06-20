//
//  VolumeRenderingShaders.metal
//  iOS_DICOMViewer
//
//  Advanced Metal shaders for 3D volume rendering
//  Implements ray casting, MIP, isosurface rendering, and gradient-based shading
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct VolumeRenderParams {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 modelViewProjectionMatrix;
    float4x4 inverseModelViewProjectionMatrix;
    float3 cameraPosition;
    float3 volumeSize;
    float3 voxelSpacing;
    float stepSize;
    float densityThreshold;
    float opacityScale;
    float brightnessScale;
    float windowCenter;
    float windowWidth;
    uint frameNumber;
};

struct VolumeRenderSettings {
    int renderMode;           // 0=raycast, 1=mip, 2=isosurface, 3=dvr
    int qualityLevel;         // 0=low, 1=medium, 2=high, 3=ultra
    bool enableGradientShading;
    bool enableAmbientOcclusion;
    bool enableJittering;
    int maxSamples;
    bool earlyRayTermination;
    int compositingMode;      // 0=front-to-back, 1=back-to-front, 2=additive, 3=maximum
};

// MARK: - Utility Functions

// Generate pseudo-random number for jittering
float random(float2 co, float seed) {
    return fract(sin(dot(co.xy + seed, float2(12.9898, 78.233))) * 43758.5453);
}

// Apply window/level transformation
static float applyWindowLevel(float value, float center, float width) {
    float lower = center - width * 0.5;
    float upper = center + width * 0.5;
    return saturate((value - lower) / (upper - lower));
}

// Compute gradient using central differences
float3 computeGradient(texture3d<float, access::sample> volume, 
                      float3 position, 
                      sampler volumeSampler) {
    float3 offset = 1.0 / float3(volume.get_width(), volume.get_height(), volume.get_depth());
    
    float dx = volume.sample(volumeSampler, position + float3(offset.x, 0, 0)).r -
               volume.sample(volumeSampler, position - float3(offset.x, 0, 0)).r;
    float dy = volume.sample(volumeSampler, position + float3(0, offset.y, 0)).r -
               volume.sample(volumeSampler, position - float3(0, offset.y, 0)).r;
    float dz = volume.sample(volumeSampler, position + float3(0, 0, offset.z)).r -
               volume.sample(volumeSampler, position - float3(0, 0, offset.z)).r;
    
    return float3(dx, dy, dz) / (2.0 * offset);
}

// Phong lighting calculation
float3 calculateLighting(float3 normal, float3 viewDir, float3 lightDir, float3 color) {
    float3 normalizedNormal = normalize(normal);
    float3 normalizedLight = normalize(lightDir);
    float3 normalizedView = normalize(viewDir);
    
    // Ambient
    float3 ambient = 0.2 * color;
    
    // Diffuse
    float diffuse = max(dot(normalizedNormal, normalizedLight), 0.0);
    
    // Specular
    float3 reflectDir = reflect(-normalizedLight, normalizedNormal);
    float spec = pow(max(dot(normalizedView, reflectDir), 0.0), 32.0);
    
    return ambient + diffuse * color + spec * float3(1.0);
}

// MARK: - Gradient Computation

kernel void computeGradients(texture3d<float, access::read> volume [[texture(0)]],
                           texture3d<float, access::write> gradients [[texture(1)]],
                           uint3 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= volume.get_width() || gid.y >= volume.get_height() || gid.z >= volume.get_depth()) {
        return;
    }
    
    uint3 volumeSize = uint3(volume.get_width(), volume.get_height(), volume.get_depth());
    
    // Compute gradient using central differences with clamped indices
    uint3 gradient_pos_x = min(gid + uint3(1, 0, 0), volumeSize - 1);
    uint3 gradient_neg_x = (gid.x > 0) ? (gid - uint3(1, 0, 0)) : gid;
    uint3 gradient_pos_y = min(gid + uint3(0, 1, 0), volumeSize - 1);
    uint3 gradient_neg_y = (gid.y > 0) ? (gid - uint3(0, 1, 0)) : gid;
    uint3 gradient_pos_z = min(gid + uint3(0, 0, 1), volumeSize - 1);
    uint3 gradient_neg_z = (gid.z > 0) ? (gid - uint3(0, 0, 1)) : gid;
    
    float3 gradient;
    gradient.x = volume.read(gradient_pos_x).r - volume.read(gradient_neg_x).r;
    gradient.y = volume.read(gradient_pos_y).r - volume.read(gradient_neg_y).r;
    gradient.z = volume.read(gradient_pos_z).r - volume.read(gradient_neg_z).r;
    
    gradient /= 2.0;
    float magnitude = length(gradient);
    
    gradients.write(float4(gradient, magnitude), gid);
}

// MARK: - Volume Ray Casting

kernel void volumeRaycast(texture3d<float, access::sample> volume [[texture(0)]],
                         texture2d<float, access::write> output [[texture(1)]],
                         texture1d<float, access::sample> transferFunction [[texture(2)]],
                         texture3d<float, access::sample> gradients [[texture(3)]],
                         constant VolumeRenderParams& params [[buffer(0)]],
                         constant VolumeRenderSettings& settings [[buffer(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    sampler volumeSampler(filter::linear, address::clamp_to_edge);
    sampler transferSampler(filter::linear, address::clamp_to_edge);
    
    // Generate ray from screen coordinates
    float2 screenPos = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());
    screenPos = screenPos * 2.0 - 1.0;
    
    // Transform to world space
    float4 rayClip = float4(screenPos.x, screenPos.y, -1.0, 1.0);
    float4 rayEye = params.inverseModelViewProjectionMatrix * rayClip;
    rayEye /= rayEye.w;
    
    float3 rayOrigin = params.cameraPosition;
    float3 rayDirection = normalize(rayEye.xyz - rayOrigin);
    
    // Apply jittering for higher quality
    if (settings.enableJittering) {
        float jitter = random(screenPos, float(params.frameNumber)) * params.stepSize;
        rayOrigin += rayDirection * jitter;
    }
    
    // Ray-box intersection with volume
    float3 boxMin = float3(-0.5);
    float3 boxMax = float3(0.5);
    
    float3 invRayDir = 1.0 / rayDirection;
    float3 t1 = (boxMin - rayOrigin) * invRayDir;
    float3 t2 = (boxMax - rayOrigin) * invRayDir;
    
    float3 tMin = min(t1, t2);
    float3 tMax = max(t1, t2);
    
    float tNear = max(max(tMin.x, tMin.y), tMin.z);
    float tFar = min(min(tMax.x, tMax.y), tMax.z);
    
    if (tNear > tFar || tFar < 0.0) {
        output.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }
    
    // Ray marching
    float t = max(tNear, 0.0);
    float4 accumulatedColor = float4(0.0);
    int sampleCount = 0;
    
    float3 lightDirection = normalize(float3(1.0, 1.0, -1.0));
    
    while (t < tFar && accumulatedColor.a < 0.99 && sampleCount < settings.maxSamples) {
        float3 worldPos = rayOrigin + t * rayDirection;
        float3 texCoord = worldPos + 0.5; // Convert to texture coordinates [0,1]
        
        // Sample volume density
        float density = volume.sample(volumeSampler, texCoord).r;
        
        // Apply window/level transformation
        density = applyWindowLevel(density, params.windowCenter, params.windowWidth);
        
        if (density > 0.01) { // Skip empty space
            // Apply transfer function
            float4 sampleColor = transferFunction.sample(transferSampler, density);
            sampleColor.rgb *= params.brightnessScale;
            sampleColor.a *= params.opacityScale;
            
            // Enhanced shading with gradients
            if (settings.enableGradientShading && gradients.get_width() > 0) {
                float4 gradientData = gradients.sample(volumeSampler, texCoord);
                float3 gradient = gradientData.xyz;
                float gradientMagnitude = gradientData.w;
                
                if (gradientMagnitude > 0.001) {
                    float3 normal = normalize(gradient);
                    float3 viewDir = -rayDirection;
                    
                    // Apply lighting
                    sampleColor.rgb = calculateLighting(normal, viewDir, lightDirection, sampleColor.rgb);
                    
                    // Enhance opacity based on gradient magnitude
                    sampleColor.a *= (1.0 + gradientMagnitude * 2.0);
                }
            }
            
            // Compositing based on mode
            switch (settings.compositingMode) {
                case 0: // Front-to-back
                    accumulatedColor.rgb += (1.0 - accumulatedColor.a) * sampleColor.a * sampleColor.rgb;
                    accumulatedColor.a += (1.0 - accumulatedColor.a) * sampleColor.a;
                    break;
                case 1: // Back-to-front  
                    accumulatedColor = sampleColor + accumulatedColor * (1.0 - sampleColor.a);
                    break;
                case 2: // Additive
                    accumulatedColor += sampleColor * params.stepSize;
                    break;
                case 3: // Maximum
                    accumulatedColor = max(accumulatedColor, sampleColor);
                    break;
            }
            
            // Early ray termination
            if (settings.earlyRayTermination && accumulatedColor.a > 0.95) {
                break;
            }
        }
        
        t += params.stepSize;
        sampleCount++;
    }
    
    accumulatedColor.a = min(accumulatedColor.a, 1.0);
    output.write(accumulatedColor, gid);
}

// MARK: - Maximum Intensity Projection

kernel void maximumIntensityProjection(texture3d<float, access::sample> volume [[texture(0)]],
                                     texture2d<float, access::write> output [[texture(1)]],
                                     texture1d<float, access::sample> transferFunction [[texture(2)]],
                                     texture3d<float, access::sample> gradients [[texture(3)]],
                                     constant VolumeRenderParams& params [[buffer(0)]],
                                     constant VolumeRenderSettings& settings [[buffer(1)]],
                                     uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    sampler volumeSampler(filter::linear, address::clamp_to_edge);
    sampler transferSampler(filter::linear, address::clamp_to_edge);
    
    // Generate ray
    float2 screenPos = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());
    screenPos = screenPos * 2.0 - 1.0;
    
    float4 rayClip = float4(screenPos.x, screenPos.y, -1.0, 1.0);
    float4 rayEye = params.inverseModelViewProjectionMatrix * rayClip;
    rayEye /= rayEye.w;
    
    float3 rayOrigin = params.cameraPosition;
    float3 rayDirection = normalize(rayEye.xyz - rayOrigin);
    
    // Ray-box intersection
    float3 boxMin = float3(-0.5);
    float3 boxMax = float3(0.5);
    
    float3 invRayDir = 1.0 / rayDirection;
    float3 t1 = (boxMin - rayOrigin) * invRayDir;
    float3 t2 = (boxMax - rayOrigin) * invRayDir;
    
    float3 tMin = min(t1, t2);
    float3 tMax = max(t1, t2);
    
    float tNear = max(max(tMin.x, tMin.y), tMin.z);
    float tFar = min(min(tMax.x, tMax.y), tMax.z);
    
    if (tNear > tFar || tFar < 0.0) {
        output.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }
    
    // Find maximum intensity along ray
    float t = max(tNear, 0.0);
    float maxIntensity = 0.0;
    int sampleCount = 0;
    
    while (t < tFar && sampleCount < settings.maxSamples) {
        float3 worldPos = rayOrigin + t * rayDirection;
        float3 texCoord = worldPos + 0.5;
        
        float density = volume.sample(volumeSampler, texCoord).r;
        density = applyWindowLevel(density, params.windowCenter, params.windowWidth);
        
        maxIntensity = max(maxIntensity, density);
        
        t += params.stepSize;
        sampleCount++;
    }
    
    // Apply transfer function to maximum intensity
    float4 color = transferFunction.sample(transferSampler, maxIntensity);
    color.rgb *= params.brightnessScale;
    
    output.write(color, gid);
}

// MARK: - Isosurface Rendering

kernel void isosurfaceRender(texture3d<float, access::sample> volume [[texture(0)]],
                            texture2d<float, access::write> output [[texture(1)]],
                            texture1d<float, access::sample> transferFunction [[texture(2)]],
                            texture3d<float, access::sample> gradients [[texture(3)]],
                            constant VolumeRenderParams& params [[buffer(0)]],
                            constant VolumeRenderSettings& settings [[buffer(1)]],
                            uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    sampler volumeSampler(filter::linear, address::clamp_to_edge);
    
    // Generate ray
    float2 screenPos = (float2(gid) + 0.5) / float2(output.get_width(), output.get_height());
    screenPos = screenPos * 2.0 - 1.0;
    
    float4 rayClip = float4(screenPos.x, screenPos.y, -1.0, 1.0);
    float4 rayEye = params.inverseModelViewProjectionMatrix * rayClip;
    rayEye /= rayEye.w;
    
    float3 rayOrigin = params.cameraPosition;
    float3 rayDirection = normalize(rayEye.xyz - rayOrigin);
    
    // Ray-box intersection
    float3 boxMin = float3(-0.5);
    float3 boxMax = float3(0.5);
    
    float3 invRayDir = 1.0 / rayDirection;
    float3 t1 = (boxMin - rayOrigin) * invRayDir;
    float3 t2 = (boxMax - rayOrigin) * invRayDir;
    
    float3 tMin = min(t1, t2);
    float3 tMax = max(t1, t2);
    
    float tNear = max(max(tMin.x, tMin.y), tMin.z);
    float tFar = min(min(tMax.x, tMax.y), tMax.z);
    
    if (tNear > tFar || tFar < 0.0) {
        output.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }
    
    // Find isosurface intersection
    float t = max(tNear, 0.0);
    float isoValue = params.densityThreshold;
    bool foundIntersection = false;
    float4 finalColor = float4(0.0);
    
    float previousDensity = 0.0;
    int sampleCount = 0;
    
    while (t < tFar && !foundIntersection && sampleCount < settings.maxSamples) {
        float3 worldPos = rayOrigin + t * rayDirection;
        float3 texCoord = worldPos + 0.5;
        
        float density = volume.sample(volumeSampler, texCoord).r;
        density = applyWindowLevel(density, params.windowCenter, params.windowWidth);
        
        // Check for isosurface crossing
        if (sampleCount > 0 && 
            ((previousDensity < isoValue && density >= isoValue) ||
             (previousDensity > isoValue && density <= isoValue))) {
            
            // Refine intersection point using linear interpolation
            float t_intersect = t - params.stepSize + 
                               params.stepSize * (isoValue - previousDensity) / (density - previousDensity);
            
            float3 intersectionPos = rayOrigin + t_intersect * rayDirection;
            float3 intersectionTexCoord = intersectionPos + 0.5;
            
            // Compute surface normal from gradient
            float3 normal = float3(0.0, 0.0, 1.0);
            if (gradients.get_width() > 0) {
                float4 gradientData = gradients.sample(volumeSampler, intersectionTexCoord);
                if (length(gradientData.xyz) > 0.001) {
                    normal = normalize(gradientData.xyz);
                }
            } else {
                // Fallback: compute gradient on the fly
                normal = normalize(computeGradient(volume, intersectionTexCoord, volumeSampler));
            }
            
            // Shading
            float3 viewDir = -rayDirection;
            float3 lightDir = normalize(float3(1.0, 1.0, -1.0));
            
            float3 baseColor = float3(0.8, 0.6, 0.4); // Default isosurface color
            float3 litColor = calculateLighting(normal, viewDir, lightDir, baseColor);
            
            finalColor = float4(litColor * params.brightnessScale, 1.0);
            foundIntersection = true;
        }
        
        previousDensity = density;
        t += params.stepSize;
        sampleCount++;
    }
    
    output.write(finalColor, gid);
}