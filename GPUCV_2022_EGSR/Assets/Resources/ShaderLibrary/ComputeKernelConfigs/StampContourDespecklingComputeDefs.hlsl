#ifndef E7287B3D_02C1_4575_A34C_CC711C06D23F
#define E7287B3D_02C1_4575_A34C_CC711C06D23F


#include "../TreeScanPrimitives.hlsl"

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



#define SCAN_FUNCTION_TAG EdgeLoopAnalysis
uint3 op(uint3 a, uint3 b)
{
	b.x = asuint(asfloat(a.x) + asfloat(b.x));
	b.y = PackPixelCoord(
		min(DecodePixelCoord(a.y), DecodePixelCoord(b.y)
	));
	b.z = PackPixelCoord(
		max(DecodePixelCoord(a.z), DecodePixelCoord(b.z)
	));

	return b;
}
#define OP op
#define SCAN_DATA_TYPE uint3
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE uint3(asuint(.0f), 0xffffffff, 0u)
#define SCAN_DATA_VECTOR_STRIDE 3
#define SCAN_BLOCK_SIZE GROUP_SIZE_0
// #define SCAN_DATA_TYPE_NON_UINT
#include "../WarpSegScanCodeGen.hlsl"



#endif /* E7287B3D_02C1_4575_A34C_CC711C06D23F */
