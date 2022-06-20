#ifndef STAMP_ATTRIBUTE_FLOODING_INCLUDED
#define STAMP_ATTRIBUTE_FLOODING_INCLUDED

#include "../CustomShaderInputs.hlsl"
#include "../JFAInputs.hlsl"

#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerStamp_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"

// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"
// https://docs.microsoft.com/en-us/cpp/c-language/type-float?view=msvc-160
#define MAX_F32 3.402823465e+38

#define GROUP_SIZE_0 256
#define BITS_GROUP_SIZE_0 8

#define BITS_GROUP_SIZE_JFA_LOOP ((BITS_JFA_TILE_SIZE << 1))
#define GROUP_SIZE_JFA_LOOP ((1 << BITS_GROUP_SIZE_JFA_LOOP))




float InitJFASeed(uint2 fragCoord)
{
	JFAData jfa;
	jfa.coord = fragCoord;
	jfa.isSeed = true;
	
	return EncodeJFAData(jfa);
}


struct MinInfo
{
	float minSqrDist;
	float2 closestCoord;
	bool foundSeed;
};
void GetMinDistancePoint(
	float2 curPos, float jfaTexSample, inout MinInfo minInfo
){
	JFAData jfa = DecodeJFAData(jfaTexSample);

	if(jfa.isSeed)
	{
		float2 vec = curPos - (float2)(jfa.coord);
		float sqrDist = dot(vec, vec);
		
		if(sqrDist < minInfo.minSqrDist)
		{
			minInfo.closestCoord = (float2)(jfa.coord);
			minInfo.minSqrDist = sqrDist;
			minInfo.foundSeed = true;
		}
	}
}







// =======================================================
#define SCAN_FUNCTION_TAG Tiling
groupshared uint LDS_PrevBlockSum = 0;
RWStructuredBuffer<uint> CBuffer_StructuredTempBuffer1;

uint op0(uint a, uint b)
{
	return a + b;
}

#define OP op0
#define SCAN_DATA_TYPE uint
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE 0u
#define SCAN_BLOCK_SIZE GROUP_SIZE_0

#define TG_COUNTER CBuffer_JFATileCounter
#define TGSM_COUNTER LDS_PrevBlockSum

#include "../StreamCompactionCodeGen.hlsl"
// =======================================================




#endif
