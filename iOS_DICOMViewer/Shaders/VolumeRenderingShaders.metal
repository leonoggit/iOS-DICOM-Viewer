//
//  VolumeRenderingShaders.metal
//  iOS_DICOMViewer
//
//  Metal shaders for 3D volume rendering
//  Implements ray casting, transfer functions, and sampling
//

#include <metal_stdlib>
using namespace metal;

struct VolumeRenderParams {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3 cameraPosition;
    float3 volumeSize;
    float stepSize;
};

// Ray generation
kernel void generateRays(texture2d<float, access::write> rayDirections [[texture(0)]],
                        constant VolumeRenderParams& params [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    
    float2 uv = float2(gid) / float2(rayDirections.get_width(), rayDirections.get_height());
    uv = uv * 2.0 - 1.0;
    
    float4x4 invProj = params.projectionMatrix;
    float4x4 invView = params.viewMatrix;
    
    float4 rayClip = float4(uv.x, uv.y, -1.0, 1.0);
    float4 rayEye = invProj * rayClip;
    rayEye = float4(rayEye.xy, -1.0, 0.0);
    
    float3 rayWorld = normalize((invView * rayEye).xyz);
    
    rayDirections.write(float4(rayWorld, 1.0), gid);
}

// Volume ray casting
kernel void volumeRaycast(texture3d<float, access::sample> volume [[texture(0)]],
                         texture2d<float, access::write> output [[texture(1)]],
                         texture1d<float, access::sample> transferFunction [[texture(2)]],
                         constant VolumeRenderParams& params [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    // Generate ray
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
    uv = uv * 2.0 - 1.0;
    
    float3 rayOrigin = params.cameraPosition;
    float3 rayDirection = normalize(float3(uv.x, uv.y, -1.0));
    
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
        output.write(float4(0.0), gid);
        return;
    }
    
    // Ray marching
    float t = max(tNear, 0.0);
    float4 color = float4(0.0);
    
    constexpr sampler volumeSampler(filter::linear, address::clamp_to_edge);
    
    while (t < tFar && color.a < 0.99) {
        float3 pos = rayOrigin + t * rayDirection;
        float3 texCoord = pos + 0.5; // Convert to texture coordinates [0,1]
        
        float density = volume.sample(volumeSampler, texCoord).r;
        
        // Apply transfer function
        float4 sampleColor = transferFunction.sample(volumeSampler, density);
        
        // Front-to-back compositing
        color.rgb += (1.0 - color.a) * sampleColor.a * sampleColor.rgb;
        color.a += (1.0 - color.a) * sampleColor.a;
        
        t += params.stepSize;
    }
    
    output.write(color, gid);
}
