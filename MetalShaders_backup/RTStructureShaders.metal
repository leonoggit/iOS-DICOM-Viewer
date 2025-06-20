//
//  RTStructureShaders.metal
//  iOS_DICOMViewer
//
//  Metal shaders for RT Structure Set rendering
//  Provides high-performance GPU rendering of radiation therapy structure sets

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct RTVertex {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float4 color [[attribute(2)]];
};

struct RTVertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float4 color;
    float depth;
};

struct RTStructureUniforms {
    float4x4 projectionMatrix;
    float4x4 modelViewMatrix;
    float4x4 viewMatrix;
    float2 viewportSize;
    float contourWidth;
    float opacity;
    int showFilled;
    int showWireframe;
    int cullBackFaces;
    int renderMode;
};

// MARK: - RT Contour Rendering Shaders

vertex RTVertexOut rtContourVertex(RTVertex in [[stage_in]],
                                  constant RTStructureUniforms& uniforms [[buffer(1)]],
                                  uint vid [[vertex_id]]) {
    RTVertexOut out;
    
    float4 worldPos = float4(in.position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * worldPos;
    out.normal = normalize((uniforms.modelViewMatrix * float4(in.normal, 0.0)).xyz);
    out.color = in.color;
    out.color.a *= uniforms.opacity;
    out.depth = out.position.z / out.position.w;
    
    return out;
}

fragment float4 rtContourFragment(RTVertexOut in [[stage_in]],
                                 constant RTStructureUniforms& uniforms [[buffer(0)]]) {
    
    // Basic contour rendering with depth-based transparency
    float4 color = in.color;
    
    // Enhanced visibility for medical visualization
    color.rgb = mix(color.rgb, float3(1.0), 0.1);
    
    // Apply uniform opacity
    color.a *= uniforms.opacity;
    
    return color;
}

// MARK: - Filled Structure Rendering Shaders

vertex RTVertexOut rtFilledVertex(RTVertex in [[stage_in]],
                                 constant RTStructureUniforms& uniforms [[buffer(1)]]) {
    RTVertexOut out;
    
    float4 worldPos = float4(in.position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * worldPos;
    out.normal = normalize((uniforms.modelViewMatrix * float4(in.normal, 0.0)).xyz);
    out.color = in.color;
    out.depth = out.position.z / out.position.w;
    
    return out;
}

fragment float4 rtFilledFragment(RTVertexOut in [[stage_in]],
                                constant RTStructureUniforms& uniforms [[buffer(0)]]) {
    
    float3 normal = normalize(in.normal);
    
    // Simple lighting for 3D visualization
    float3 lightDir = normalize(float3(0.0, 0.0, 1.0));
    float ndotl = max(dot(normal, lightDir), 0.0);
    
    // Ambient + diffuse lighting
    float3 ambient = in.color.rgb * 0.3;
    float3 diffuse = in.color.rgb * 0.7 * ndotl;
    
    float4 color = float4(ambient + diffuse, in.color.a * uniforms.opacity * 0.6);
    
    // Back face culling for filled structures
    if (uniforms.cullBackFaces && ndotl < 0.0) {
        color.a *= 0.3; // Make back faces more transparent
    }
    
    return color;
}

// MARK: - Wireframe Rendering Shaders

vertex RTVertexOut rtWireframeVertex(RTVertex in [[stage_in]],
                                    constant RTStructureUniforms& uniforms [[buffer(1)]]) {
    RTVertexOut out;
    
    float4 worldPos = float4(in.position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * worldPos;
    out.normal = normalize((uniforms.modelViewMatrix * float4(in.normal, 0.0)).xyz);
    out.color = in.color;
    out.depth = out.position.z / out.position.w;
    
    return out;
}

fragment float4 rtWireframeFragment(RTVertexOut in [[stage_in]],
                                   constant RTStructureUniforms& uniforms [[buffer(0)]]) {
    
    // Enhanced wireframe rendering for medical visualization
    float4 color = in.color;
    
    // Make wireframes more visible
    color.rgb = mix(color.rgb, float3(1.0), 0.2);
    color.a = 1.0; // Full opacity for wireframes
    
    return color;
}

// MARK: - Volume Rendering Shaders (Future Enhancement)

vertex RTVertexOut rtVolumeVertex(RTVertex in [[stage_in]],
                                 constant RTStructureUniforms& uniforms [[buffer(1)]]) {
    RTVertexOut out;
    
    float4 worldPos = float4(in.position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * worldPos;
    out.normal = normalize((uniforms.modelViewMatrix * float4(in.normal, 0.0)).xyz);
    out.color = in.color;
    out.depth = out.position.z / out.position.w;
    
    return out;
}

fragment float4 rtVolumeFragment(RTVertexOut in [[stage_in]],
                                constant RTStructureUniforms& uniforms [[buffer(0)]]) {
    
    // Volume rendering for 3D structures (placeholder for future enhancement)
    float3 normal = normalize(in.normal);
    
    // Volumetric lighting approximation
    float3 viewDir = normalize(-in.worldPosition);
    float fresnel = pow(1.0 - max(dot(normal, viewDir), 0.0), 2.0);
    
    float4 color = in.color;
    color.rgb = mix(color.rgb, float3(1.0), fresnel * 0.3);
    color.a *= uniforms.opacity * (0.5 + fresnel * 0.5);
    
    return color;
}

// MARK: - Multi-planar Reconstruction (MPR) Shaders

struct MPRVertex {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct MPRVertexOut {
    float4 position [[position]];
    float2 texCoord;
    float3 worldPosition;
};

vertex MPRVertexOut rtMPRVertex(MPRVertex in [[stage_in]],
                               constant RTStructureUniforms& uniforms [[buffer(1)]],
                               constant float4x4& mprTransform [[buffer(2)]]) {
    MPRVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * position;
    out.texCoord = in.texCoord;
    out.worldPosition = (mprTransform * position).xyz;
    
    return out;
}

fragment float4 rtMPRFragment(MPRVertexOut in [[stage_in]],
                             texture3d<float> structureVolume [[texture(0)]],
                             constant RTStructureUniforms& uniforms [[buffer(0)]],
                             constant float3& planeNormal [[buffer(1)]],
                             constant float3& planePoint [[buffer(2)]]) {
    
    sampler volumeSampler(mag_filter::linear, min_filter::linear);
    
    // Sample structure volume at current world position
    float3 texCoord3D = (in.worldPosition + 1.0) * 0.5; // Normalize to [0,1]
    float structureValue = structureVolume.sample(volumeSampler, texCoord3D).r;
    
    if (structureValue < 0.1) {
        discard_fragment();
    }
    
    // Calculate distance from plane for depth cueing
    float distanceFromPlane = abs(dot(in.worldPosition - planePoint, planeNormal));
    float depthAlpha = exp(-distanceFromPlane * 2.0); // Exponential falloff
    
    // Color based on structure value and distance
    float4 color = float4(structureValue, structureValue * 0.8, structureValue * 0.6, depthAlpha);
    color.a *= uniforms.opacity;
    
    return color;
}

// MARK: - Compute Shaders for RT Structure Processing

// Generate contour mesh from points
kernel void generateContourMesh(device float3* inputPoints [[buffer(0)]],
                               device float3* outputVertices [[buffer(1)]],
                               device uint* outputIndices [[buffer(2)]],
                               constant uint& pointCount [[buffer(3)]],
                               constant uint& segmentsPerContour [[buffer(4)]],
                               uint tid [[thread_position_in_grid]]) {
    
    if (tid >= pointCount) {
        return;
    }
    
    uint vertexIndex = tid * 2; // Each point generates 2 vertices for thick lines
    uint indexBase = tid * 6; // Each segment generates 2 triangles (6 indices)
    
    if (tid < pointCount - 1) {
        float3 current = inputPoints[tid];
        float3 next = inputPoints[tid + 1];
        
        // Calculate perpendicular vector for line thickness
        float3 direction = normalize(next - current);
        float3 perpendicular = normalize(cross(direction, float3(0, 0, 1))) * 0.5; // Line thickness
        
        // Generate quad vertices
        outputVertices[vertexIndex] = current + perpendicular;
        outputVertices[vertexIndex + 1] = current - perpendicular;
        outputVertices[vertexIndex + 2] = next + perpendicular;
        outputVertices[vertexIndex + 3] = next - perpendicular;
        
        // Generate triangle indices
        outputIndices[indexBase] = vertexIndex;
        outputIndices[indexBase + 1] = vertexIndex + 1;
        outputIndices[indexBase + 2] = vertexIndex + 2;
        
        outputIndices[indexBase + 3] = vertexIndex + 1;
        outputIndices[indexBase + 4] = vertexIndex + 3;
        outputIndices[indexBase + 5] = vertexIndex + 2;
    }
}

// Simplify contour for iOS performance optimization
kernel void simplifyContour(device float3* inputPoints [[buffer(0)]],
                           device float3* outputPoints [[buffer(1)]],
                           device uint* outputCount [[buffer(2)]],
                           constant uint& inputCount [[buffer(3)]],
                           constant float& tolerance [[buffer(4)]],
                           uint tid [[thread_position_in_grid]]) {
    
    if (tid != 0) return; // Single thread processes entire contour
    
    // Douglas-Peucker simplification algorithm
    // Simplified version for GPU implementation
    
    uint outputIndex = 0;
    outputPoints[outputIndex++] = inputPoints[0]; // Always keep first point
    
    for (uint i = 1; i < inputCount - 1; i++) {
        float3 prev = inputPoints[i - 1];
        float3 current = inputPoints[i];
        float3 next = inputPoints[i + 1];
        
        // Calculate distance from current point to line between prev and next
        float3 lineVec = next - prev;
        float3 pointVec = current - prev;
        
        float lineLengthSq = dot(lineVec, lineVec);
        float t = (lineLengthSq > 0) ? dot(pointVec, lineVec) / lineLengthSq : 0;
        t = clamp(t, 0.0f, 1.0f);
        
        float3 projection = prev + t * lineVec;
        float distance = length(current - projection);
        
        // Keep point if distance exceeds tolerance
        if (distance > tolerance) {
            outputPoints[outputIndex++] = current;
        }
    }
    
    outputPoints[outputIndex++] = inputPoints[inputCount - 1]; // Always keep last point
    *outputCount = outputIndex;
}

// Compute structure intersection with plane for MPR views
kernel void computePlaneIntersection(texture3d<float, access::read> structureVolume [[texture(0)]],
                                    texture2d<float, access::write> outputTexture [[texture(1)]],
                                    constant float3& planeNormal [[buffer(0)]],
                                    constant float3& planePoint [[buffer(1)]],
                                    constant float4x4& worldToVolumeMatrix [[buffer(2)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Convert screen coordinates to world coordinates on the plane
    float2 screenCoord = (float2(gid) / float2(outputTexture.get_width(), outputTexture.get_height())) * 2.0 - 1.0;
    
    // Create orthonormal basis for the plane
    float3 normal = normalize(planeNormal);
    float3 tangent1 = normalize(cross(normal, float3(0, 0, 1)));
    float3 tangent2 = cross(normal, tangent1);
    
    // Calculate world position on the plane
    float3 worldPos = planePoint + screenCoord.x * tangent1 + screenCoord.y * tangent2;
    
    // Transform to volume coordinates
    float4 volumePos4 = worldToVolumeMatrix * float4(worldPos, 1.0);
    float3 volumeCoord = volumePos4.xyz / volumePos4.w;
    
    // Sample volume if coordinates are valid
    if (all(volumeCoord >= 0.0) && all(volumeCoord <= 1.0)) {
        float structureValue = structureVolume.read(uint3(volumeCoord * float3(structureVolume.get_width(),
                                                                              structureVolume.get_height(),
                                                                              structureVolume.get_depth()))).r;
        outputTexture.write(float4(structureValue, 0, 0, 1), gid);
    } else {
        outputTexture.write(float4(0), gid);
    }
}

// Distance field computation for structure sets
kernel void computeDistanceField(texture3d<float, access::read> structureVolume [[texture(0)]],
                                texture3d<float, access::write> distanceField [[texture(1)]],
                                constant float& maxDistance [[buffer(0)]],
                                uint3 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= distanceField.get_width() ||
        gid.y >= distanceField.get_height() ||
        gid.z >= distanceField.get_depth()) {
        return;
    }
    
    float centerValue = structureVolume.read(gid).r;
    
    if (centerValue > 0.5) {
        distanceField.write(float4(0.0), gid);
        return;
    }
    
    float minDistance = maxDistance;
    int searchRadius = int(maxDistance);
    
    // Search for nearest structure voxel
    for (int dz = -searchRadius; dz <= searchRadius; dz++) {
        for (int dy = -searchRadius; dy <= searchRadius; dy++) {
            for (int dx = -searchRadius; dx <= searchRadius; dx++) {
                int3 samplePos = int3(gid) + int3(dx, dy, dz);
                
                if (any(samplePos < 0) || 
                    samplePos.x >= int(structureVolume.get_width()) ||
                    samplePos.y >= int(structureVolume.get_height()) ||
                    samplePos.z >= int(structureVolume.get_depth())) {
                    continue;
                }
                
                float sample = structureVolume.read(uint3(samplePos)).r;
                if (sample > 0.5) {
                    float distance = length(float3(dx, dy, dz));
                    minDistance = min(minDistance, distance);
                }
            }
        }
    }
    
    distanceField.write(float4(minDistance / maxDistance), gid);
}

// Utility functions for RT structure processing

// Convert Hounsfield Units to normalized values
float hounsfieldsToNormalized(float hu) {
    return clamp((hu + 1000.0) / 2000.0, 0.0, 1.0);
}

// Apply windowing for medical imaging
float applyWindowing(float value, float windowCenter, float windowWidth) {
    float minValue = windowCenter - windowWidth * 0.5;
    float maxValue = windowCenter + windowWidth * 0.5;
    return clamp((value - minValue) / windowWidth, 0.0, 1.0);
}

// Calculate contour area using shoelace formula
float calculateContourArea(device float3* points, uint pointCount) {
    float area = 0.0;
    
    for (uint i = 0; i < pointCount; i++) {
        uint next = (i + 1) % pointCount;
        area += points[i].x * points[next].y - points[next].x * points[i].y;
    }
    
    return abs(area) * 0.5;
}

// Check if point is inside contour using ray casting
bool pointInContour(float2 point, device float3* contourPoints, uint pointCount) {
    bool inside = false;
    
    for (uint i = 0, j = pointCount - 1; i < pointCount; j = i++) {
        float2 pi = contourPoints[i].xy;
        float2 pj = contourPoints[j].xy;
        
        if (((pi.y > point.y) != (pj.y > point.y)) &&
            (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x)) {
            inside = !inside;
        }
    }
    
    return inside;
}