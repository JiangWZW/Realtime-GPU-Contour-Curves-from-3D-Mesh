#ifndef DRAWINDIRECTPEREDGE_INCLUDED
#define DRAWINDIRECTPEREDGE_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

#include "./ComputeBufferConfigs/CBuffer_BufferRawPerVert_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawPerFace_View.hlsl"
#include "./ComputeBufferConfigs/MeshBuffers/CBuffer_TVList_View.hlsl"
#include "./ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"


////////////////////////////////////////////////////////////////
// Resources
float4x4 CMatrix_M;
uint CVal_Triangle_Count;

ByteAddressBuffer           CBuffer_BufferRawPerFace;
ByteAddressBuffer           CBuffer_BufferRawPerVert;
ByteAddressBuffer           CBuffer_BufferRawDebug;
ByteAddressBuffer           CBuffer_TVList;
StructuredBuffer<float4>    CBuffer_VPList;

/////////////////////////////////////////////////
// Structures
struct ProceduralVertexOutput{
    float4 posCS : SV_POSITION;
    float4 color : COLOR;
};

////////////////////////////////////////////////////////////////
/// Indirect Draw Shader --- Per Edge
ProceduralVertexOutput ExtractedFace_VS(
    uint vertInstanceId : SV_VertexID
){
    ProceduralVertexOutput output;
    
    // Get primitive ids
    // -----------------------------------------
    uint triangleId = vertInstanceId / 3; 
	uint vertId = vertInstanceId % 3;

    triangleId = CBuffer_BufferRawPerFace.Load(
        CBuffer_BufferRawPerFace_Subbuff_AddrAt(
            CVal_Triangle_Count, triangleId
        )
    );
	
    vertId = CBuffer_TVList.Load((triangleId * 3 + vertId) << BITS_WORD_OFFSET);

    float4 vPos = asfloat(
	    CBuffer_BufferRawPerVert.Load4(
		    CBuffer_BufferRawPerVert_VP_AddrAt(vertId)));

    vPos.y *= -1;
    output.posCS = vPos;
    output.color = float4(0.5, 0.3, 0.2, 1);

    // Debug, fetch more info
    uint triInstanceId = vertInstanceId / 3;
    uint debugVal = CBuffer_BufferRawDebug.Load(triInstanceId << 2);

    output.color.rgb = (float)debugVal;
	
    return output;
}

float4 ExtractedFace_FS(
    ProceduralVertexOutput input
) : SV_TARGET
{
    if (input.color.r < 0.1) discard;
    return input.color; 
}

#endif /* DRAWINDIRECTPEREDGE_INCLUDED */
