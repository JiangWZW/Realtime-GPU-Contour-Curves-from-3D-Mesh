#ifndef STAMPCONTOURTANGENTOPTIMIZECOMPUTEDEFS_INCLUDED
#define STAMPCONTOURTANGENTOPTIMIZECOMPUTEDEFS_INCLUDED

#include "../CustomShaderInputs.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl" 


#include "../ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerSeg_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"

// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"



 
uint _PingPong;
#ifdef NUM_PATCHES_PER_GROUP
#	undef NUM_PATCHES_PER_GROUP
#endif

// Inputs -----------------------------
#define tag TangentFiltering
#define MAX_CONV_RADIUS EDGE_CONV_RADIUS
#define GROUP_SIZE_CONV 256
#define BITS_GROUP_SIZE 8

#define T_CONV float2

RWByteAddressBuffer CBuffer_BufferRawPixelEdgeData;
RWByteAddressBuffer CBuffer_BufferRawRasterDataPerSeg;
#define PING_PONG_BUFFER CBuffer_BufferRawRasterDataPerSeg


CONV_DATA_T LoadGlobalConvData(uint edgeId)
{
	return UnpackUnitVector_2D(
		(PING_PONG_BUFFER.Load(
			Conv_Buffer_ConvData_AddrAt(_PingPong, edgeId))
		)
	);
}

#define DEVICE_LOAD_CONV_DATA(elemIdGl) (LoadGlobalConvData(elemIdGl))


uint LoadPatchIdGl(uint blockId, uint patchIdLc)
{
	return CBuffer_BufferRawPixelEdgeData.Load(
		CBuffer_PixelEdgeData_EdgeConvPatch_AddrAt(
			blockId, patchIdLc
		)
	);
}
#define DEVICE_LOAD_CONV_PATCH_ID(blockId, patchIdLc) (LoadPatchIdGl(blockId, patchIdLc))

#include "../SegmentedConvolutionPrimitive_Loop1D.hlsl"



#endif /* STAMPCONTOURTANGENTOPTIMIZECOMPUTEDEFS_INCLUDED */
