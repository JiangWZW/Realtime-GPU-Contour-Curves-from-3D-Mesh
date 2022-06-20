#ifndef DRAWINDIRECTPEREDGE_INCLUDED
#define DRAWINDIRECTPEREDGE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

#include "./ComputeBufferConfigs/CBuffer_BufferRawPerEdge_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawFlagsPerEdge_View.hlsl"
#include "./ComputeBufferConfigs/MeshBuffers/CBuffer_EVList_View.hlsl"
#include "./ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"

////////////////////////////////////////////////////////////////
// Interactive Parameters
float _LineWidth;
float _StampLength;

////////////////////////////////////////////////////////////////
// Resources
int CVal_NormalEdge_Count;
int CVal_NonConcaveEdge_Count;
float4x4 CMatrix_M;
float4x4 CMatrix_MVP;

float4 CVector_CameraPos_WS;
float4 CVector_ScreenTexelSize_SS;

ByteAddressBuffer CBuffer_EVList;
ByteAddressBuffer CBuffer_BufferRawFlagsPerEdge;

StructuredBuffer<float4>    CBuffer_VPList;
StructuredBuffer<float4>    CBuffer_VNList;

/////////////////////////////////////////////////
// Structures
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

////////////////////////////////////////////////////////////////
/// Indirect Draw Shader --- Per Edge
ProceduralVertexOutput ExtractedEdge_VS(
    uint vert_Id : SV_VertexID
){
    ProceduralVertexOutput output;
    
    // Get primitive ids
    // -----------------------------------------
    uint edgeId = vert_Id / 4; 
    uint vertId = vert_Id % 4;

    // Load Resources
    // -----------------------------------------
    uint ldAddr = CBuffer_EVList_AddrAt(edgeId);
    uint2 ldData = CBuffer_EVList.Load2(ldAddr);
    
    // Debug Flag(s)
    // ----------------------------------------------
    // Edge Flag
    uint edgeFlag = CBuffer_BufferRawFlagsPerEdge.Load(
        CBuffer_BufferRawFlagsPerEdge_AddrAt(edgeId)
    );
    
    bool isContour = isContourEdge(edgeFlag);
    bool isConcave = (edgeId >= (uint)CVal_NormalEdge_Count);
    
    float3 background = float3(0.8235294, 0.8900843, 0.92);
    output.color = float4(background * .7, 1);
    output.color = (isContour) ? float4(1, 0, 0, 1) : output.color;
    // output.color = (isConcave) ? float4(0, 1, 0, 1) : output.color;
    
    // Compute vertex position
    // ---------------------------------------------
    Vertex v0 = newVertex(ldData.x);
    Vertex v1 = newVertex(ldData.y);
    float4 posWS0 = mul(CMatrix_M, v0.posOS);
    float4 posWS1 = mul(CMatrix_M, v1.posOS);
    
    // --- Normal offset,
    // in case of some super-concave edge "stabs" into mesh
    // and thus become invisible
    float offsetByNormal = 0.001;
    posWS0.xyz += offsetByNormal * v0.normal.xyz;
    posWS1.xyz += offsetByNormal * v1.normal.xyz;
    
    // --- Quad topology
    float3 lineDir = 0.5 * (posWS1.xyz - posWS0.xyz);
    float3 quadCenter = 0.5 * (posWS0.xyz + posWS1.xyz);
    float3 viewDir = normalize(CVector_CameraPos_WS.xyz - quadCenter);
    
    float offsetDecay = (edgeFlag == 1) ? 0.01 : 0.0025;
    float linewidth = 0.75;
    offsetDecay *= linewidth;
    float3 offset = offsetDecay * normalize(cross(viewDir, normalize(lineDir)));

    float lineDirFactor = (vertId < 2) ? -1 : 1;
    float offsetFactor = (vertId == 0 || vertId == 3) ? 1 : -1;

    float3 wdPos = quadCenter + lineDirFactor * lineDir + offsetFactor * offset;
    
    // --- Extra offset for concave edges
    // Concave edges might get hidden by its 2 adjacent faces, 
    // so we move it "out" a bit
    wdPos.xyz += isConcave ? (0.001 * viewDir.xyz) : float3(0, 0, 0);
    
    output.posCS = TransformWorldToHClip(wdPos);
    
    return output;
}

float4 ExtractedEdge_FS(
    ProceduralVertexOutput input 
) : SV_TARGET
{
    float4 col = input.color; 
    if (col.a < 0.9) discard;
    return col; 
}

#endif /* DRAWINDIRECTPEREDGE_INCLUDED */
