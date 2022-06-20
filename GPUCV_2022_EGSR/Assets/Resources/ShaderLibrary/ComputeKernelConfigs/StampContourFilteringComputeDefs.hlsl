#ifndef EAAA378E_E86D_49E0_BE17_E1FD30B4A0E1
#define EAAA378E_E86D_49E0_BE17_E1FD30B4A0E1

#include "../CustomShaderInputs.hlsl"
#include "../ImageProcessing.hlsl"

#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerStamp_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerSeg_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPathData_View.hlsl"


// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"



// ------------------------------------------------
// Whether this edge is good enough to be displayed
uint ShouldDrawEdge(uint edgeAttribs)
{
	return
	(1 == GetEdgeAttrib(BIT_BEG_DRAW_FLAG, BIT_LEN_DRAW_FLAG, edgeAttribs));
}

float cubicPulse(float c, float w, float x)
{
	x = abs(x - c);
	if (x > w) return 0.0;
	x /= w;
	return 1.0 - x * x * (3.0 - 2.0 * x);
}


// -------------------------------------------------------------
// TODO: to match with the same macro in normalization kernel
#define MAX_DELTA_PARAM_PER_FRAME 8
float BlendPathParam(
	float pathRank, float pathLen,
	float pathHeadParamFitted, float pathTailParamFitted,
	bool blendWithPrev, float prevPathTailParam, 
	bool blendWithNext, float nextPathHeadParam
)
{
	float middleParam = 
		.5f * (pathHeadParamFitted + pathTailParamFitted);
	float maxDeltaSlope = 
		1.0f + (2.0f * MAX_DELTA_PARAM_PER_FRAME / (pathLen - 1.0f));
	float deltaParam = maxDeltaSlope * (.5f * (pathLen - 1.0f));

	float newHeadParam = pathHeadParamFitted;
	if (blendWithPrev)
	{
		newHeadParam = max(
			middleParam - deltaParam,
			lerp(pathHeadParamFitted, prevPathTailParam, .5f)
		);
	}

	float newTailParam = pathTailParamFitted;
	if (blendWithNext)
	{
		newTailParam = min(
			middleParam + deltaParam,
			lerp(pathTailParamFitted, nextPathHeadParam, .5f)
		);
	}


	return lerp(newHeadParam, newTailParam, pathRank / (pathLen - 1));
}



#define GROUP_SIZE_0 256
#define BITS_GROUP_0 8

#define GROUP_SIZE_1 256
#define BITS_GROUP_1 8

#define GROUP_SIZE_2 256
#define BITS_GROUP_2 8

#define GROUP_SIZE_CONV 256u
#define BTIS_GROUP_CONV 8u

// Make sure to match with GROUP_SIZE_0 in
// "ContourDenoisingComputeDefs.hlsl"
#define GROUP_SIZE_NEXT 256
#define BITS_GROUP_NEXT 8

#define NEW_CONV_SCHEME

uint F32_TO_U32(float f32) { return ((uint)((f32)+.1f)); }


#endif /* EAAA378E_E86D_49E0_BE17_E1FD30B4A0E1 */
