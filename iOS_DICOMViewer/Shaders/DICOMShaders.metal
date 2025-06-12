#include <metal_stdlib>
using namespace metal;

struct WindowLevelParams {
    float window;
    float level;
    float rescaleSlope;
    float rescaleIntercept;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Vertex shader for full-screen quad
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

// Fragment shader
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              texture2d<float> texture [[texture(0)]]) {
    sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = texture.sample(textureSampler, in.texCoord);
    return color;
}

// Window/Level compute kernel
kernel void windowLevelKernel(device const uint16_t* pixelData [[buffer(0)]],
                             texture2d<float, access::write> outputTexture [[texture(0)]],
                             constant WindowLevelParams& params [[buffer(1)]],
                             uint2 gid [[thread_position_in_grid]]) {

    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    uint index = gid.y * outputTexture.get_width() + gid.x;
    float pixelValue = float(pixelData[index]);

    // Apply rescale transformation
    pixelValue = pixelValue * params.rescaleSlope + params.rescaleIntercept;

    // Apply window/level
    float minValue = params.level - params.window / 2.0;
    float maxValue = params.level + params.window / 2.0;

    float normalizedValue = (pixelValue - minValue) / params.window;
    normalizedValue = clamp(normalizedValue, 0.0, 1.0);

    outputTexture.write(float4(normalizedValue, normalizedValue, normalizedValue, 1.0), gid);
}
