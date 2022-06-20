#ifndef SEGMENTATIONCOMPUTEDEFS_INCLUDED
#define SEGMENTATIONCOMPUTEDEFS_INCLUDED

#define KERNEL_CONTOUR_INDIRECTION true

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

#include "../CustomShaderInputs.hlsl"
// Mesh Buffers(Raw)
#include "../ComputeBufferConfigs/MeshBuffers/CBuffer_EVList_View.hlsl"
// Raw Buffers - Per Edge Granularity
#include "../ComputeBufferConfigs/CBuffer_BufferRawPerEdge_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerEdge_View.hlsl"
// Raw Buffers - Per Contour Granularity
#include "../ComputeBufferConfigs/CBuffer_BufferRawContourToEdge_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawContourToSegment_View.hlsl"
// Raw Buffers - Per Segment Granularity
#include "../ComputeBufferConfigs/CBuffer_BufferRawSegmentsToContour_View.hlsl"
// Args Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawLookBacks_View.hlsl"


// Remember to match with GROUP_SIZE_1 in SetupComputeDefs.hlsl
#define GROUP_SIZE_0 256
#define GROUP_SIZE_0_BITS 8

// Remember to match with GROUP_SIZE in SegmentSetupComputeDefs.hlsl
#define GROUP_SIZE_NEXT 1024
#define BITS_GROUP_SIZE_NEXT 10


// =======================================================
#define SCAN_FUNCTION_TAG AllocSegs

uint op0(uint a, uint b)
{
	return a + b;
}

#define OP op0
#define SCAN_DATA_TYPE uint
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE 0u
// #define SCAN_DATA_VECTOR_STRIDE 2
#define SCAN_BLOCK_SIZE GROUP_SIZE_0
#define REDUCE_BLOCK_SIZE 1024

// #define SCAN_DATA_TYPE_NON_UINT
#include "../WaveScanCodeGen.hlsl"
// =======================================================



#endif /* SEGMENTATIONCOMPUTEDEFS_INCLUDED */
