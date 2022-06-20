#ifndef DRAWINDIRECTPERCONTOUR_INCLUDED
#define DRAWINDIRECTPERCONTOUR_INCLUDED

#include "./BrushToolBox.hlsl"

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

#include "./ComputeBufferConfigs/MeshBuffers/CBuffer_EVList_View.hlsl"

#include "./ComputeBufferConfigs/CBuffer_BufferRawContourToEdge_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawFlagsPerContour_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerContour_View.hlsl"

#include "./ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"

////////////////////////////////////////////////////////////////
/// Indirect Draw Shader --- Per Contour
//== Shader Inputs ===============================================

float4 CVector_ScreenTexelSize_SS;
float4 CVector_CameraPos_WS;
int CVal_NormalEdge_Count;
int CVal_NonConcaveEdge_Count;

float4x4 CMatrix_M;
float4x4 CMatrix_V;
float4x4 CMatrix_P;
float4x4 CMatrix_I_P;
float4x4 CMatrix_MVP;

StructuredBuffer<float4>    CBuffer_VPList;
StructuredBuffer<float4>    CBuffer_VNList;
ByteAddressBuffer           CBuffer_EVList;

ByteAddressBuffer CBuffer_BufferRawContourToEdge;
ByteAddressBuffer CBuffer_BufferRawFlagsPerContour;
ByteAddressBuffer CBuffer_BufferRawRasterDataPerContour;

//== Utility Functions ===============================================
uint wang_hash(uint seed)
{
    seed = (seed ^ 61) ^ (seed >> 16);
    seed *= 9;
    seed = seed ^ (seed >> 4);
    seed *= 0x27d4eb2d;
    seed = seed ^ (seed >> 15);
    return seed;
}

//== Structures ===============================================
struct ProceduralVertexOutput{
    float4 posCS            : SV_POSITION;
    float4 color            : COLOR;
};
struct Vertex{
    float4 posOS;
    float4 normal;
    float NdotV;
};
Vertex newVertex(int vertList_Id){
    float4 data_VP = CBuffer_VPList[vertList_Id];
    float4 data_VN = CBuffer_VNList[vertList_Id];
    
    Vertex vout;
    vout.posOS  = float4(data_VP.x, data_VP.y, data_VP.z, 1.0);
    vout.normal = float4(data_VN.x, data_VN.y, data_VN.z, 0.0);
    vout.NdotV  = data_VP.w;
 
    return vout;
}

bool _DrawGBuffer;

//== Shader Programs ==========================================
ProceduralVertexOutput ExtractedContour_VS(
    uint vert_Id : SV_VertexID
){
    ProceduralVertexOutput output;
    Vertex v0;
    Vertex v1;
    
    // Load & Compute Primitive IDs
    // ------------------------------------------------------------
    uint contourId = vert_Id / 6;
    uint vertIdLocal = vert_Id % 6;
    
    uint edgeId = CBuffer_BufferRawContourToEdge.Load(
        CBuffer_BufferRawContourToEdge_AddrAt(contourId)
    );
    
    uint2 vertIds = CBuffer_EVList.Load2(CBuffer_EVList_AddrAt(edgeId));
    
    // Load Resources 
    // ---------------------------------------------------------------------------
    // Load contour flag
    uint contourFlag = CBuffer_BufferRawFlagsPerContour.Load(
        CBuffer_BufferRawFlagsPerContour_AddrAt(contourId)
    );
    // Rearrange verts to follow CW order on screen
    vertIds = ShouldSwapWindingOrder(contourFlag) ? vertIds.yx : vertIds.xy;
    
 
    // Load per-contour raster data
    uint ldAddr;
    ldAddr = CBuffer_BufferRawRasterDataPerContour_AddrAt(contourId); // Release
    uint4x2 rasterData;
    rasterData._11_21_31_41 = CBuffer_BufferRawRasterDataPerContour.Load4(ldAddr);
    ldAddr = MoveAddrSingleBlock(ldAddr);
    rasterData._12_22_32_42 = CBuffer_BufferRawRasterDataPerContour.Load4(ldAddr);

    // Compute condition flags
    // bool isBoundary = (!isConcave) && edgeId >= (uint)CVal_NormalEdge_Count;
    // bool isClipped = IS_CLIPPED_EDGE(rasterData);
    // bool isOcclusionCulled = IS_OCCLUSION_CULLED(rasterData);
    bool isConcave = edgeId >= (uint)CVal_NonConcaveEdge_Count;
    
    
    // Color
    // --------------------------------------------------------------------------
    output.color = float4(0, 0, 0, 1);
    // For smoother render on G-buffers, concave edges should be eleminated.
    // output.color = (isConcave) ? float4(1, 1, 1, 0) : output.color; // Release
    
    
    // -------------------------------------------
    // Position Transforms
    v0 = newVertex(vertIds.x);
    v1 = newVertex(vertIds.y);
    const float normalOffset = 0.0000;
    float3 posOS0 = v0.posOS.xyz + normalOffset * v0.normal.xyz;
    float3 posOS1 = v1.posOS.xyz + normalOffset * v1.normal.xyz;
    
    float3 posVS0 = mul(CMatrix_V, mul(CMatrix_M, float4(posOS0, 1.0))).xyz;
    float3 posVS1 = mul(CMatrix_V, mul(CMatrix_M, float4(posOS1, 1.0))).xyz;
    
    float4 posSS0 = mul(CMatrix_P, float4(posVS0.xyz, 1.0));
    posSS0.xy *= rcp(posSS0.w);
    posSS0.xy = 0.5 * posSS0.xy + float2(0.5, 0.5);

    float4 posSS1 = mul(CMatrix_P, float4(posVS1.xyz, 1.0));
    posSS1.xy *= rcp(posSS1.w);
    posSS1.xy = 0.5 * posSS1.xy + float2(0.5, 0.5);

    // G-Buffer Test: Quad TexCoord
    // ----------------------------------    
    // output.color.x = 
    // (
    //     vertIdLocal == 0 ||
    //     vertIdLocal == 1 ||
    //     vertIdLocal == 3
    // ) ? 0 : 1;
    // output.color.yz = output.color.xx;
	
    float4 posOut;
    float lineWidthUnit = _ScreenParams.z - 1;
    posOut = ComputeQuadPointNDC(posSS0, posSS1, vertIdLocal, lineWidthUnit * 2);

    // G-Buffer Test: Stroke Directional
    // ----------------------------------    
    // if (_DrawGBuffer)
    // {
    //     output.color.xy = normalize(posSS1.xy - posSS0.xy);
    //     output.color.y *= -1;
    //     output.color.xy = 0.5 * output.color.xy + float2(0.5, 0.5);
    //     output.color.z = 0;
    //     output.color.w = -1.0 * LinearEyeDepth(posOut.z, _ZBufferParams);
    // }

    // // Concave edges might get hidden by its 2 adjacent faces, 
    // // so we move it "out" a bit
    // vertPosOut.xyz += isConcave ? (-0.001 * viewDir.xyz) : float3(0, 0, 0);

    // Note: flip y after transform into/from HClip Space in Unity
    // ---------------------------------------------------------------
    // For custom projection matrix, we need to flip y axis
    // after entering clip space.
    // For built-in matrix, the axis-flipping is already baked into 
    // the projection matrix itself.
    // e.g, vertPosOut = mul(UNITY_MATRIX_P, vertPosOut);
    posOut.y = -posOut.y;
    output.posCS = posOut;

    return output;
}

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// Note: this haven't been tested & refined yet, 
// make sure to upgrade this piece of code before running in unity
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
ProceduralVertexOutput ExtractedContour_VS_LinePrim(
    uint vert_Id : SV_VertexID
){
    ProceduralVertexOutput output;
    Vertex v0;
    Vertex v1;
    
    uint contourId = vert_Id / 2;
    uint vertIdLocal = vert_Id % 2;
    
    uint ldAddr = CBuffer_BufferRawContourToEdge_AddrAt(contourId);
    uint edgeId = CBuffer_BufferRawContourToEdge.Load(ldAddr);
    
    uint2 vertIds;
    ldAddr = CBuffer_EVList_AddrAt(edgeId);
    vertIds = CBuffer_EVList.Load2(ldAddr);
    
    ldAddr = CBuffer_BufferRawFlagsPerContour_AddrAt(contourId);
    uint contourFlag = CBuffer_BufferRawFlagsPerContour.Load(ldAddr);
 
    // ----------------------------------------------------------------
    // Color
    output.color = float4(0, 0, 0, 1);
    
    // Per-chunk, Load per-contour raster data computed in prev kernel
    ldAddr = CBuffer_BufferRawRasterDataPerContour_AddrAt(contourId); // Release
    // ldAddr = CBuffer_BufferRawRasterDataPerContour_AddrAt(edgeId); // Debug
    uint4x2 rasterData;
    rasterData._11_21_31_41 = CBuffer_BufferRawRasterDataPerContour.Load4(ldAddr);
    ldAddr = MoveAddrSingleBlock(ldAddr);
    rasterData._12_22_32_42 = CBuffer_BufferRawRasterDataPerContour.Load4(ldAddr);

    // Extract condition flags
    // bool isBoundary = (!isConcave) && edgeId >= (uint)CVal_NormalEdge_Count;
    // bool isClipped = IS_CLIPPED_EDGE(rasterData);
    // bool isOcclusionCulled = IS_OCCLUSION_CULLED(rasterData);
    
    bool isConcave = edgeId >= (uint)CVal_NonConcaveEdge_Count;
    // Rearrange verts to follow CW order on screen
    vertIds = ShouldSwapWindingOrder(contourFlag) ? vertIds.yx : vertIds.xy;
    
    // ----------------------------------------------------------------
    // Position Transforms
    v0 = newVertex(vertIds.x);
    v1 = newVertex(vertIds.y);
    const float normalOffset = 0.0000;
    float3 posOS0 = v0.posOS.xyz + normalOffset * v0.normal.xyz;
    float3 posOS1 = v1.posOS.xyz + normalOffset * v1.normal.xyz;
    
    float3 posVS0 = mul(CMatrix_V, mul(CMatrix_M, float4(posOS0, 1.0))).xyz;
    float3 posVS1 = mul(CMatrix_V, mul(CMatrix_M, float4(posOS1, 1.0))).xyz;
    
    float4 posSS0 = mul(CMatrix_P, float4(posVS0.xyz, 1.0));
    float4 posSS1 = mul(CMatrix_P, float4(posVS1.xyz, 1.0));

    // G-Buffer Test: Line TexCoord
    // ----------------------------------    
    // output.color.x = 
    // (
    //     vertIdLocal == 0 ||
    //     vertIdLocal == 1 ||
    //     vertIdLocal == 3
    // ) ? 0 : 1;
    // output.color.yz = output.color.xx;

    // G-Buffer Test: Stroke Directional
    // ----------------------------------    
    output.color.xy = normalize(posSS1.xy - posSS0.xy);
    output.color.y *= -1;
    output.color.xy = 0.5 * output.color.xy + float2(0.5, 0.5);

    // uint3 seed;
    // seed.x = wang_hash(contourId) % 512;
    // seed.y = wang_hash(seed.x + contourId) % 512;
    // seed.z = wang_hash(seed.y + contourId) % 512;
    // float3 randomCol = (float3)(seed.xyz) / 512.0;
    // output.color.xyz = randomCol;


    // For smoother render on G-buffers, concave edges should be eleminated.
    output.color = (isConcave) ? float4(0, 0, 0, 0) : output.color;
    
    output.posCS = vertIdLocal == 0 ? posSS0 : posSS1;
    output.posCS.y *= -1;

    return output;
}


float4 ExtractedContour_FS(
    ProceduralVertexOutput input 
) : SV_TARGET
{
    float4 col = input.color; 
    
    if (col.a < 0.9) discard;
    
    return col; 
}

#endif /* DRAWINDIRECTPERCONTOUR_INCLUDED */
