#ifndef EAAA378E_E86D_49E0_BE17_E1FD30B4A0E1
#define EAAA378E_E86D_49E0_BE17_E1FD30B4A0E1

// LinearEyeDepth
// #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl" 

#include "../CustomShaderInputs.hlsl"
#include "../ImageProcessing.hlsl"

#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawEdgeLoopData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerStamp_View.hlsl"

// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"

uint4 ComputeStampEdgeDataX4(uint stampId, uint boxCode)
{
    uint4 edges = uint4(
		ComputeStampEdgeData(0, stampId, boxCode),
		ComputeStampEdgeData(1, stampId, boxCode),
		ComputeStampEdgeData(2, stampId, boxCode),
		ComputeStampEdgeData(3, stampId, boxCode)
	);
    return edges;
}



#ifdef INIT_KERNELS
// Make sure matches with GROUP_SIZE_NEXT 
// in ".hlsl"
#define GROUP_SIZE_0 256
#define BITS_GROUP_SIZE_0 8

#define GROUP_SIZE_1 256
#define BITS_GROUP_SIZE_1 8

#define GROUP_SIZE_2 256
#define BITS_GROUP_SIZE_2 8

#define SCAN_BLOCK_SIZE GROUP_SIZE_1
#include "../ScanPrimitives.hlsl"

#endif

#ifdef TRACING_KERNELS
#define GROUP_SIZE_0 256
#define BITS_GROUP_SIZE_0 8

#define GROUP_SIZE_1 256
#define BITS_GROUP_SIZE_1 8

#define GROUP_SIZE_2 256
#define BITS_GROUP_SIZE_2 8

#endif

#ifdef SERIALIZATION_KERNELS
#define GROUP_SIZE_0 256
#define BITS_GROUP_SIZE_0 8

#define GROUP_SIZE_1 256
#define BITS_GROUP_SIZE_1 8

#define GROUP_SIZE_2 256
#define BITS_GROUP_SIZE_2 8

// Make sure this matches with
// 'group_size_0' in despeckling shader
#define GROUP_SIZE_NEXT 256
#define BITS_GROUP_NEXT 8

#define EDGE_LOOP_INFO PINGPONG_STAMP_LINKAGE_1
#endif





#endif /* EAAA378E_E86D_49E0_BE17_E1FD30B4A0E1 */
