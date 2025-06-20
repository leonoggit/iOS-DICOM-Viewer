//
//  ROIShaders.metal
//  iOS_DICOMViewer
//
//  Metal shaders for ROI (Region of Interest) tool rendering
//  Provides high-performance GPU rendering of medical imaging annotations
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct ROIVertex {
    float2 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

struct ROIVertexOut {
    float4 position [[position]];
    float4 color;
    float2 texCoord;
    float pointSize [[point_size]];
};

struct ROIUniforms {
    float4x4 projectionMatrix;
    float4x4 modelViewMatrix;
    float2 viewportSize;
    float lineWidth;
    float opacity;
};

// MARK: - Line Rendering Shaders

vertex ROIVertexOut roiLineVertex(ROIVertex in [[stage_in]],
                                 constant ROIUniforms& uniforms [[buffer(1)]]) {
    ROIVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.color = in.color;
    out.color.a *= uniforms.opacity;
    out.texCoord = in.texCoord;
    out.pointSize = uniforms.lineWidth;
    
    return out;
}

fragment float4 roiLineFragment(ROIVertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Circle Rendering Shaders

vertex ROIVertexOut roiCircleVertex(ROIVertex in [[stage_in]],
                                   constant ROIUniforms& uniforms [[buffer(1)]]) {
    ROIVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.color = in.color;
    out.color.a *= uniforms.opacity;
    out.texCoord = in.texCoord;
    out.pointSize = uniforms.lineWidth;
    
    return out;
}

fragment float4 roiCircleFragment(ROIVertexOut in [[stage_in]]) {
    // Create smooth circle edges using distance field
    float2 center = float2(0.5, 0.5);
    float distance = length(in.texCoord - center);
    float radius = 0.5;
    float lineWidth = 0.02; // Normalized line width
    
    // Create antialiased circle outline
    float alpha = 1.0 - smoothstep(radius - lineWidth, radius, distance);
    alpha *= smoothstep(radius - lineWidth - 0.01, radius - lineWidth, distance);
    
    float4 color = in.color;
    color.a *= alpha;
    
    return color;
}

// MARK: - Point Rendering Shaders

vertex ROIVertexOut roiPointVertex(ROIVertex in [[stage_in]],
                                  constant ROIUniforms& uniforms [[buffer(1)]]) {
    ROIVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.color = in.color;
    out.color.a *= uniforms.opacity;
    out.texCoord = in.texCoord;
    out.pointSize = uniforms.lineWidth * 2.0; // Points are larger than lines
    
    return out;
}

fragment float4 roiPointFragment(ROIVertexOut in [[stage_in]],
                                float2 pointCoord [[point_coord]]) {
    // Create smooth circular points
    float distance = length(pointCoord - float2(0.5, 0.5));
    float alpha = 1.0 - smoothstep(0.4, 0.5, distance);
    
    float4 color = in.color;
    color.a *= alpha;
    
    return color;
}

// MARK: - Filled Shape Rendering Shaders

vertex ROIVertexOut roiFilledVertex(ROIVertex in [[stage_in]],
                                   constant ROIUniforms& uniforms [[buffer(1)]]) {
    ROIVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.color = in.color;
    out.color.a *= uniforms.opacity;
    out.texCoord = in.texCoord;
    
    return out;
}

fragment float4 roiFilledFragment(ROIVertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Dashed Line Rendering Shaders

vertex ROIVertexOut roiDashedLineVertex(ROIVertex in [[stage_in]],
                                       constant ROIUniforms& uniforms [[buffer(1)]]) {
    ROIVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.color = in.color;
    out.color.a *= uniforms.opacity;
    out.texCoord = in.texCoord;
    out.pointSize = uniforms.lineWidth;
    
    return out;
}

fragment float4 roiDashedLineFragment(ROIVertexOut in [[stage_in]]) {
    // Create dashed line pattern
    float dashLength = 10.0;
    float gapLength = 5.0;
    float totalLength = dashLength + gapLength;
    
    float position = in.texCoord.x * 100.0; // Scale for visibility
    float cycle = fmod(position, totalLength);
    
    float alpha = step(cycle, dashLength);
    
    float4 color = in.color;
    color.a *= alpha;
    
    return color;
}

// MARK: - Text Background Rendering Shaders

vertex ROIVertexOut roiTextBackgroundVertex(ROIVertex in [[stage_in]],
                                           constant ROIUniforms& uniforms [[buffer(1)]]) {
    ROIVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.color = float4(0.0, 0.0, 0.0, 0.7); // Semi-transparent black background
    out.texCoord = in.texCoord;
    
    return out;
}

fragment float4 roiTextBackgroundFragment(ROIVertexOut in [[stage_in]]) {
    // Create rounded rectangle background for text
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    
    // Calculate distance to rounded rectangle
    float2 d = abs(uv - center) - float2(0.4, 0.3); // Rectangle size
    float distance = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
    
    float radius = 0.05; // Corner radius
    float alpha = 1.0 - smoothstep(radius - 0.01, radius, distance);
    
    float4 color = in.color;
    color.a *= alpha;
    
    return color;
}

// MARK: - Selection Highlight Shaders

vertex ROIVertexOut roiSelectionVertex(ROIVertex in [[stage_in]],
                                      constant ROIUniforms& uniforms [[buffer(1)]],
                                      constant float& time [[buffer(2)]]) {
    ROIVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    
    // Animate selection highlight
    float pulse = 0.5 + 0.5 * sin(time * 4.0);
    out.color = float4(1.0, 1.0, 0.0, pulse); // Yellow with pulsing alpha
    out.texCoord = in.texCoord;
    out.pointSize = uniforms.lineWidth * 1.5;
    
    return out;
}

fragment float4 roiSelectionFragment(ROIVertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Crosshair Shaders

vertex ROIVertexOut roiCrosshairVertex(ROIVertex in [[stage_in]],
                                      constant ROIUniforms& uniforms [[buffer(1)]]) {
    ROIVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.color = float4(1.0, 1.0, 0.0, 0.8); // Yellow crosshair
    out.texCoord = in.texCoord;
    out.pointSize = 1.0;
    
    return out;
}

fragment float4 roiCrosshairFragment(ROIVertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Grid Rendering Shaders

vertex ROIVertexOut roiGridVertex(ROIVertex in [[stage_in]],
                                 constant ROIUniforms& uniforms [[buffer(1)]]) {
    ROIVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.color = float4(0.5, 0.5, 0.5, 0.3); // Light gray grid
    out.texCoord = in.texCoord;
    out.pointSize = 1.0;
    
    return out;
}

fragment float4 roiGridFragment(ROIVertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - Measurement Arrow Shaders

vertex ROIVertexOut roiArrowVertex(ROIVertex in [[stage_in]],
                                  constant ROIUniforms& uniforms [[buffer(1)]]) {
    ROIVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.color = in.color;
    out.color.a *= uniforms.opacity;
    out.texCoord = in.texCoord;
    out.pointSize = uniforms.lineWidth;
    
    return out;
}

fragment float4 roiArrowFragment(ROIVertexOut in [[stage_in]]) {
    // Create arrow head shape
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    
    // Arrow pointing right
    float arrowWidth = 0.3;
    float arrowHeight = 0.6;
    
    float2 p = abs(uv - center);
    
    // Arrow shape using distance field
    float arrow = step(p.y, arrowHeight * (0.5 - p.x / arrowWidth));
    
    float4 color = in.color;
    color.a *= arrow;
    
    return color;
}

// MARK: - Anti-aliased Line Shaders

vertex ROIVertexOut roiAALineVertex(ROIVertex in [[stage_in]],
                                   constant ROIUniforms& uniforms [[buffer(1)]],
                                   uint vid [[vertex_id]]) {
    ROIVertexOut out;
    
    float4 position = float4(in.position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.color = in.color;
    out.color.a *= uniforms.opacity;
    out.texCoord = in.texCoord;
    
    return out;
}

fragment float4 roiAALineFragment(ROIVertexOut in [[stage_in]]) {
    // Anti-aliased line using coverage
    float coverage = 1.0;
    
    // Calculate distance from line center
    float distance = abs(in.texCoord.y - 0.5) * 2.0;
    
    // Apply anti-aliasing
    coverage = 1.0 - smoothstep(0.8, 1.0, distance);
    
    float4 color = in.color;
    color.a *= coverage;
    
    return color;
}

// MARK: - Utility Functions

// Convert screen coordinates to normalized device coordinates
float4 screenToNDC(float2 screenPos, float2 viewportSize) {
    float2 ndc = (screenPos / viewportSize) * 2.0 - 1.0;
    ndc.y = -ndc.y; // Flip Y coordinate
    return float4(ndc, 0.0, 1.0);
}

// Calculate distance from point to line segment
float distanceToLineSegment(float2 point, float2 a, float2 b) {
    float2 pa = point - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Create smooth step function for anti-aliasing
float smoothEdge(float distance, float thickness) {
    float edge = thickness * 0.5;
    return 1.0 - smoothstep(edge - 1.0, edge + 1.0, distance);
}

// Generate circle SDF (Signed Distance Field)
float circleSDF(float2 position, float2 center, float radius) {
    return length(position - center) - radius;
}

// Generate rectangle SDF
float rectangleSDF(float2 position, float2 center, float2 size) {
    float2 d = abs(position - center) - size * 0.5;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Generate rounded rectangle SDF
float roundedRectangleSDF(float2 position, float2 center, float2 size, float radius) {
    float2 d = abs(position - center) - size * 0.5 + radius;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}