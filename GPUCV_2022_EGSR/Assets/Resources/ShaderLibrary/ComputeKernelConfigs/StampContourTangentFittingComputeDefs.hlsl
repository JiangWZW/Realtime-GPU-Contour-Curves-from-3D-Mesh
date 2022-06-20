#ifndef STAMPCONTOURTANGENTFITTINGCOMPUTEDEFS_INCLUDED
#define STAMPCONTOURTANGENTFITTINGCOMPUTEDEFS_INCLUDED

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


// Inputs -----------------------------
#define tag QuadraticFit
#define MAX_CONV_RADIUS EDGE_CONV_RADIUS
#define GROUP_SIZE_CONV 256
#define BITS_GROUP_SIZE 8

#define T_CONV float2

RWByteAddressBuffer CBuffer_BufferRawPixelEdgeData;
RWByteAddressBuffer CBuffer_BufferRawRasterDataPerSeg;
#define PING_PONG_BUFFER CBuffer_BufferRawRasterDataPerSeg

float2 LoadEdgeCoord(uint edgeId)
{
	uint coordPacked = CBuffer_BufferRawPixelEdgeData.Load(
		CBuffer_PixelEdgeCoord_Encoded_AddrAt(edgeId)
	);
	float2 edgeCoord = DecodePixelEdgeCoord(coordPacked);

	return edgeCoord;

}

T_CONV LoadSmoothedEdgeCoord(uint elemIdGl)
{
	float2 coord;
	[branch]
	if (_PingPong != 0)
	{
		coord = (_ScreenParams.xy) *
			UnpackR16G16(
				PING_PONG_BUFFER.Load(
					Conv_Buffer_ConvData_AddrAt(
						3 + ((_PingPong + 1) % 2), 
						elemIdGl
					)
				)
			);
	}
	else
	{
		coord = LoadEdgeCoord(elemIdGl);
	}

	return coord;
}
#define DEVICE_LOAD_CONV_DATA(elemIdGl) (LoadSmoothedEdgeCoord(elemIdGl))


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






#endif /* STAMPCONTOURTANGENTFITTINGCOMPUTEDEFS_INCLUDED */
