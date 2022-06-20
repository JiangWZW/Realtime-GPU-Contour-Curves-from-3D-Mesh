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
#define MULTIBUFFERING_PARTICLEDATA_READONLY
#include "../ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"


// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"

// https://docs.microsoft.com/en-us/cpp/c-language/type-float?view=msvc-160
#define MAX_F32 3.402823465e+38

#define GROUP_SIZE_0 256u
#define BITS_GROUP_0 8u

#define GROUP_SIZE_REDUCE 512
#define BITS_GROUP_REDUCE 8


// Scan function inputs
RWByteAddressBuffer CBuffer_BufferRawRasterDataPerSeg;
#define LS_SCAN_BUFFER CBuffer_BufferRawRasterDataPerSeg
RWByteAddressBuffer CBuffer_BufferRawLookBacks;

// =======================================================
#define SCAN_FUNCTION_TAG ArcLenParam
float op2(float a, float b)
{
	return a + b;
}
#define OP op2
#define SCAN_DATA_TYPE float
#define SCAN_SCALAR_TYPE float
#define SCAN_ZERO_VALUE .0f
// #define SCAN_DATA_VECTOR_STRIDE ?
#define SCAN_BLOCK_SIZE GROUP_SIZE_0

#define SCAN_DATA_TYPE_NON_UINT
// ----------------------------
#include "../WarpSegScanCodeGen.hlsl"
// =======================================================


#endif /* EAAA378E_E86D_49E0_BE17_E1FD30B4A0E1 */
