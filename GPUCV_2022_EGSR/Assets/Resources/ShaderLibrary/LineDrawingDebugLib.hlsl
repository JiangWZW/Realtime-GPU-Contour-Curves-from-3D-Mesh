#ifndef LINE_DRAWING_DEBUG_DEFINED
#define LINE_DRAWING_DEBUG_DEFINED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

#include "./ComputeAddressingDefs.hlsl"

#include "./ComputeBufferConfigs/CBuffer_BufferRawPerFace_View.hlsl"


#include "./ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerSeg_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawFlagsPerSegment_View.hlsl"

#include "./ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerVEdge_View.hlsl"

#include "./ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"

#include "./ComputeBufferConfigs/MeshBuffers/CBuffer_TVList_View.hlsl"
#include "./ComputeBufferConfigs/MeshBuffers/CBuffer_EVList_View.hlsl"

#include "../ShaderLibrary/TextureConfigs/Texture2D_ContourGBufferTex_View.hlsl"


#include "./ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"



////////////////////////////////////////////////////////////////
/// Indirect Draw Shader --- Per Face
ByteAddressBuffer CBuffer_TVList;
ByteAddressBuffer CBuffer_BufferRawPerFace;

StructuredBuffer<float4>    CBuffer_VPList;
StructuredBuffer<float4>    CBuffer_VNList;

float4 CVector_ScreenTexelSize_SS;

float4x4 CMatrix_M; // Model to World Transform
float4x4 CMatrix_MVP;

//== Structures ===============================================
struct ProceduralVertexOutput{
    float4 posCS                 : SV_POSITION;
    nointerpolation uint4 packedData : COLOR;
};

struct Vertex{
    float4 posOS;
    float4 normal;
    float NdotV;
};
struct ProceduralStampVertexOutput{
    float4 posCS : SV_POSITION;
    float4 color : COLOR;
    float2 baryCoord : TEXCOORD0;
    float2 uvCoord : TEXCOORD1;
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

//== Shader Programs ==========================================
ProceduralVertexOutput ExtractedFace_VS(
    uint vert_Id : SV_VertexID
){
    ProceduralVertexOutput output;
    Vertex v;
    
    uint instId = vert_Id / 3;
    uint ldAddr = CBuffer_TVList_AddrAtVertID(vert_Id);
    uint vertList_Id = CBuffer_TVList.Load(ldAddr);
    
    v = newVertex(vertList_Id);

//     // 方案一: 使用自己配置的M, VP变换矩阵,
//     // 分2次乘法 => 偶尔会有闪烁(Z-Fighting)
    float4 posWS = mul(CMatrix_M, v.posOS);
//     output.posCS = mul(CMatrix_VP, posWS);
    // 方案二: 使用自己配置的MVP变换矩阵,
    // 一次乘法 => 严重的闪烁(Z-Fighting)
    // output.posCS = mul(CMatrix_MVP, v.posOS);
// #if UNITY_UV_STARTS_AT_TOP
//     // Our world space, view space, screen space and NDC space are Y-up.
//     // Our clip space is flipped upside-down due to poor legacy Unity design.
//     // The flip is baked into the projection matrix, so we only have to flip
//     // manually when going from CS to NDC and back.
//     output.posCS.y = -output.posCS.y;
// #endif // 原因: 精度问题,考虑手工用double精度在GPU侧进行计算.
    
    // 方案三: 使用URP内置的矩阵
    // => 没有任何闪烁
    output.posCS = TransformWorldToHClip(posWS.xyz);

    // Test for "ComputeNormalizedDeviceCoordinatesWithZ"
    // float4 posNDC = float4(0, 0, 1, 1);
    // posNDC.xyz = ComputeNormalizedDeviceCoordinatesWithZ(v.posOS.xyz, CMatrix_MVP);
    // posNDC.xy = posNDC.xy * 2 - float2(1, 1);
    // output.posCS = posNDC;

    // TODO: code for debug & test, delete later
    uint dataRaw;
    ldAddr = CBuffer_BufferRawPerFace_AddrAt(instId);
    dataRaw = CBuffer_BufferRawPerFace.Load(ldAddr);
    

    // Front/Back Facing ------------------------------------------
    uint facingFlag = dataRaw.x;
    
    float4 colorFBFacing = float4(1, 1, 1, 0);
    colorFBFacing = (facingFlag == 0) ? float4(0.8, 0.65, 0.65, 1) : colorFBFacing;
    colorFBFacing = (facingFlag == 1) ? float4(0, 1, 0, 1) : colorFBFacing;
    colorFBFacing = (facingFlag == 2) ? float4(0, 0, 1, 1) : colorFBFacing;
    output.packedData = colorFBFacing;

    return output;
}

float4 ExtractedFace_FS(
    ProceduralVertexOutput input 
) : SV_TARGET
{
    float4 col = input.packedData; 
    if (col.a < 0.99999) discard;
    return col; 
}

////////////////////////////////////////////////////////////////
/// Indirect Draw Shader --- Per Contour
ByteAddressBuffer CBuffer_BufferRawContourToEdge;
ByteAddressBuffer CBuffer_BufferRawFlagsPerContour;
ByteAddressBuffer CBuffer_BufferRawRasterDataPerContour;
float4x4 CMatrix_I_P;
float4x4 CMatrix_V;
float4x4 CMatrix_P;

#include "./BrushToolBox.hlsl"

////////////////////////////////////////////////////////////////////////////////
//         Indirect Draw Shader --- Per View Edge

ByteAddressBuffer CBuffer_BufferRawRasterDataPerVEdge;
ByteAddressBuffer CBuffer_BufferRawDebug;
StructuredBuffer<uint> CBuffer_CachedArgs;
StructuredBuffer<float> CBuffer_StructuredQuadVertices;

ProceduralVertexOutput ViewEdge_VS(
    uint vert_Id : SV_VertexID
){
    ProceduralVertexOutput output;
    
    uint viewEdgeId = vert_Id / 42; 
    uint vertIdLocal = vert_Id % 42;
    
    uint ldAddr = CBuffer_BufferRawRasterDataPerVEdge_AddrAt(viewEdgeId);
    uint4x2 rasterData;
    rasterData._11_21_31_41 = CBuffer_BufferRawRasterDataPerVEdge.Load4(ldAddr);
    ldAddr = MoveAddrSingleBlock(ldAddr);
    rasterData._12_22_32_42 = CBuffer_BufferRawRasterDataPerVEdge.Load4(ldAddr);
    float2 eyeDepth = GET_VEDGE_RASTER_LINZ(rasterData);
    
    
    // ----------------------------------------------------------------
    // Color
    output.packedData = float4(0, 0, 0, 1);
    
    // Contour Index
    // uint3 random;
    uint contourId = rasterData._32;
    // uint edgeId = CBuffer_BufferRawContourToEdge.Load(
    //     CBuffer_BufferRawContourToEdge_AddrAt(contourId)
    // );
    // uint contourCount = CBuffer_CachedArgs_SegmentCounter;
    // output.packedData.xyz = contourId < 128 ? float3(1, 0, 0) : float3(0, 0, 0);
    // random.r = wang_hash(edgeId);
    // random.g = wang_hash(random.r);
    // random.b = wang_hash(random.g);
    // float3 randomColor = (float3)(random.xyz % 32) / 32.0;
    // output.packedData = float4(0 * randomColor.xyz, 1);    

    // Tangent Field
    // float4 tangent = asfloat(CBuffer_BufferRawDebug.Load4(viewEdgeId << 4));

    // Distace Field
    // output.packedData = 

    // Eye Depth
    // output.packedData = 


    // ----------------------------------------------------------------
    // HCS Position
    float2 posNDC0 = GET_VEDGE_RASTER_VERT0(rasterData);
    float2 posNDC1 = GET_VEDGE_RASTER_VERT1(rasterData);
    
    // Coord snapping, this happens at last, 
    // because we need original precise vert position
    // to compute info like tangent, etc
    // float2 screenRes = float2(1024, 768);
    // posNDC0 = (floor(screenRes * posNDC0) + float2(.5, .5)) / screenRes;
    // posNDC1 = (floor(screenRes * posNDC1) + float2(.5, .5)) / screenRes;

    float4 vertPosOut;
    vertPosOut.xy = ComputeCappedQuadPointNDC_xy(posNDC0, posNDC1, vertIdLocal, _LineWidth);
    vertPosOut.xy = vertPosOut.xy * 2 - float2(1, 1);
    vertPosOut.z = 0;
    vertPosOut.w = 1;
    // Note: flip y after transform into/from HClip Space in Unity
    // ---------------------------------------------------------------
    // For custom projection matrix, we need to flip y axis
    // after entering clip space.
    // For built-in matrix, the axis-flipping is already baked into 
    // the projection matrix itself.
    // e.g, vertPosOut = mul(UNITY_MATRIX_P, vertPosOut);
    output.posCS = vertPosOut; 

    return output;
}

ProceduralVertexOutput ViewEdge_VS_LinePrim(
    uint vert_Id : SV_VertexID
){
    ProceduralVertexOutput output;
    
    uint viewEdgeId = vert_Id / 2; 
    uint vertIdLocal = vert_Id % 2;
    
    uint ldAddr = CBuffer_BufferRawRasterDataPerVEdge_AddrAt(viewEdgeId);
    uint4x2 rasterData;
    rasterData._11_21_31_41 = CBuffer_BufferRawRasterDataPerVEdge.Load4(ldAddr);
    ldAddr = MoveAddrSingleBlock(ldAddr);
    rasterData._12_22_32_42 = CBuffer_BufferRawRasterDataPerVEdge.Load4(ldAddr);
    float2 eyeDepth = GET_VEDGE_RASTER_LINZ(rasterData);

    // ----------------------------------------------------------------
    // HCS Position
    float2 posNDC0 = GET_VEDGE_RASTER_VERT0(rasterData);
    float2 posNDC1 = GET_VEDGE_RASTER_VERT1(rasterData);
    
    // float2 screenRes = float2(1024, 768); // Note: res has changed
    // posNDC0 = (floor(screenRes * (0.5 * posNDC0 + .5)) + 0.5) / screenRes;
    // posNDC1 = (floor(screenRes * (0.5 * posNDC1 + .5)) + 0.5) / screenRes;
    // posNDC0 = saturate(posNDC0) * 2 - float2(1, 1);
    // posNDC1 = saturate(posNDC1) * 2 - float2(1, 1);

    // ----------------------------------------------------------------
    // Color
    output.packedData = float4(0, 0, 0, 1);
    
    float4 vertPosOut;
    // TODO: .zw is not needed here, 
    // further optimization is needed
    vertPosOut.xy = vertIdLocal == 0 ? posNDC0 : posNDC1;
    vertPosOut.z = 0.99;
    vertPosOut.w = 1;

    // Note: flip y after transform into/from HClip Space in Unity
    // ---------------------------------------------------------------
    // For custom projection matrix, we need to flip y axis
    // after entering clip space.
    // For built-in matrix, the axis-flipping is already baked into 
    // the projection matrix itself.
    // e.g, vertPosOut = mul(UNITY_MATRIX_P, vertPosOut);
    // vertPosOut.y = 1 - vertPosOut.y;
    vertPosOut.xy = vertPosOut.xy * 2 - 1;

    output.posCS = vertPosOut; 

    return output;
}


float4 ViewEdge_FS(
    ProceduralVertexOutput input 
) : SV_TARGET
{
    float4 col = input.packedData; 
    // if (col.a < 0.9) discard;
    return col; 
}

ByteAddressBuffer CBuffer_BufferRawStampPixels;

ByteAddressBuffer CBuffer_BufferRawRasterDataPerSeg;
ByteAddressBuffer CBuffer_BufferRawFlagsPerSegment;


ContourSegRaster_VSOutput VisibleSegs_VS(
    uint vertId : SV_VertexID
){
    uint primId = vertId / (1u + STAMP_SPLAT_COUNT);
    uint splatId = vertId % (1u + STAMP_SPLAT_COUNT);
    uint segId = primId;

    ContourSegRasterData segRasterData;
    segRasterData.Decode(
        CBuffer_BufferRawRasterDataPerSeg.Load4(
            CBuffer_BufferRawRasterDataPerVisibleSeg(0, segId)
        )
    );
    
    // Offset non-center splats "behind"
    float zviewAfterOffset = segRasterData.viewZ + ((splatId != 0) ? -1.0 : 0);
    float zhclip = ViewToHClipZ(_ZBufferParams, zviewAfterOffset);

	
    uint segFlag = CBuffer_BufferRawFlagsPerSegment.Load(
        CBuffer_BufferRawFlagsPerSegment_AddrAt(segId)
    );
	// Coordinate is 2x up-sampled
#ifdef STAMP_MULTI_SAMPLE
    float2 posSS = DecodeSegCoordFromSegFlag(segFlag) / _StampMS;
    posSS = posSS + (float2)splatOffset[splatId];
#endif

	float4 posHClip;
    posHClip.xy = (posSS + float2(.5, .5)) / _ScreenParams.xy;
    posHClip.z = zhclip;
    posHClip.w = -1 * zviewAfterOffset;
    
    posHClip.xy = posHClip.xy * 2 - 1;
    posHClip.y *= -1;
    posHClip.xy *= posHClip.w;

    ContourSegRaster_VSOutput output;
    output.posCS = posHClip;
    output.Encode_packedData(segRasterData, splatId);
	
    return output;
}
 
uint4 VisibleSegs_FS(
    ContourSegRaster_VSOutput input
) : SV_TARGET
{
    uint4 col = input.packedData;
    return col; 
}

#endif
