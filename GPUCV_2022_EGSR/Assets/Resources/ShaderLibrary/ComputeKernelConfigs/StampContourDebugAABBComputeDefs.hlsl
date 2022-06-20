#ifndef E7287B3D_02C1_4575_A34C_CC711C06D23F
#define E7287B3D_02C1_4575_A34C_CC711C06D23F


#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawEdgeLoopData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"

// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"

#define GROUP_SIZE_0 256
#define BITS_GROUP_0 8

// Make sure to match with GROUP_SIZE_0
// in StampContourFilteringComputeDefs.hlsl
#define GROUP_SIZE_NEXT 256
#define BITS_GROUP_NEXT 8

uint2 op(uint2 a, uint2 b)
{
	b.x = PackPixelCoord(
		min(DecodePixelCoord(a.x), DecodePixelCoord(b.x))
	);
	b.y = PackPixelCoord(
		max(DecodePixelCoord(a.y), DecodePixelCoord(b.y))
	);

	return b;
}


// =======================================================
#define SCAN_FUNCTION_TAG AABB

#define OP op
#define SCAN_DATA_TYPE uint2
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE uint2(0xffffffff, 0)
// #define SCAN_DATA_VECTOR_STRIDE 2
#define SCAN_BLOCK_SIZE GROUP_SIZE_0
#define REDUCE_BLOCK_SIZE 1024

// #define SCAN_DATA_TYPE_NON_UINT
#include "../WaveScanCodeGen.hlsl"


// =======================================================
#define SCAN_FUNCTION_TAG AABB
globallycoherent RWByteAddressBuffer CBuffer_BufferRawLookBacks;
#define LOOK_BACK_BUFFER CBuffer_BufferRawLookBacks
#define OP op
#define SCAN_DATA_TYPE uint2
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE uint2(0xffffffff, 0)
#define SCAN_DATA_VECTOR_STRIDE 2
#define SCAN_BLOCK_SIZE GROUP_SIZE_0
// #define SCAN_DATA_TYPE_NON_UINT
#include "../DecoupledLookBackCodeGen_Scan.hlsl"



#endif /* E7287B3D_02C1_4575_A34C_CC711C06D23F */
