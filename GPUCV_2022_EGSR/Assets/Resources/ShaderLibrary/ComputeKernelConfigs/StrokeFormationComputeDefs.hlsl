#ifndef EAAA378E_E86D_49E0_BE17_E1FD30B4A0E1
#define EAAA378E_E86D_49E0_BE17_E1FD30B4A0E1

// LinearEyeDepth


#include "../CustomShaderInputs.hlsl"
#include "../ImageProcessing.hlsl"
// Mesh Buffers(Raw)
// Raw Buffers - Per Edge Granularity
// Raw Buffers - Per Contour Granularity
// Raw Buffers - Per Segment Granularity
// Raw Buffers - Per Stamp Granularity
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerStamp_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"

// Raw Buffers - Per Stroke Granularity
#define STAGE_RECONN_STROKES
#include "../ComputeBufferConfigs/CBuffer_BufferRawStrokeData_View.hlsl"
#undef STAGE_RECONN_STROKES

// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"


#define ALPHA 1.0
#define BETA (-0.0015)

float FittingWeight(uint arcLen)
{
    return (1.0 /*ALPHA*/ * exp(0.001 /*BETA*/ * arcLen * arcLen) / arcLen);
}

// Make sure matches with GROUP_SIZE_NEXT 
// in "StampLinkingComputeDefs.hlsl"
#define GROUP_SIZE_0 256
#define BITS_GROUP_SIZE_0 8
#define STROKES_PER_GROUP (GROUP_SIZE_0 >> 4)

#define GROUP_SIZE_1 256
#define BITS_GROUP_SIZE_1 8

#define GROUP_SIZE_2 256
#define BITS_GROUP_SIZE_2 8

// Make sure this matches GROUP_SIZE_2 in
// "StampLinkComputeDefs.hlsl"
#define GROUP_SIZE_NEXT 256
#define BITS_GROUP_SIZE_NEXT 8

#endif /* EAAA378E_E86D_49E0_BE17_E1FD30B4A0E1 */
