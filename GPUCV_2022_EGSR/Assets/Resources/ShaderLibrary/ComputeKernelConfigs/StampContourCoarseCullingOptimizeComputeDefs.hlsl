#ifndef STAMPCONTOURCOARSEORIENTINGCOMPUTEDEFS_INCLUDED
#define STAMPCONTOURCOARSEORIENTINGCOMPUTEDEFS_INCLUDED

#include "../CustomShaderInputs.hlsl"
#include "../ImageProcessing.hlsl"

#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerStamp_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPathData_View.hlsl"


// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"



// Make sure to match with GROUP_SIZE_0 in
// "ContourDenoisingComputeDefs.hlsl"
#define GROUP_SIZE_NEXT 256
#define BITS_GROUP_NEXT 8

uint F32_TO_U32(float f32) { return ((uint)((f32)+.1f)); }






#define tag OrientCurrFrame
#define MAX_CONV_RADIUS EDGE_CONV_RADIUS

#define GROUP_SIZE_CONV 256u
#define BTIS_GROUP_CONV 8u


struct ConvolutionData
{
	float orientScore;
};
#define T_CONV ConvolutionData

RWByteAddressBuffer CBuffer_BufferRawPixelEdgeData;
ByteAddressBuffer CBuffer_BufferRawStampGBuffer;
ByteAddressBuffer CBuffer_BufferRawProceduralGeometry;

ConvolutionData EncodeConvData(
	float orient
) {
	ConvolutionData data;

	data.orientScore = orient;
	return data;
}

ConvolutionData LoadConvData(uint edgeId)
{
	uint attrsRaw = CBuffer_BufferRawPixelEdgeData.Load(
		CBuffer_PixelEdgeData_SerializedAttribs_AddrAt(3, edgeId));

	float orient =
		(1 == GetEdgeAttrib(
			BIT_BEG_ORIENT_FLAG, BIT_LEN_ORIENT_FLAG,
			attrsRaw
		)) ? 1 : -1;

	return EncodeConvData
	(
		orient
	);
}
#define DEVICE_LOAD_CONV_DATA(elemIdGl) (LoadConvData(elemIdGl))


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


#endif /* STAMPCONTOURCOARSEORIENTINGCOMPUTEDEFS_INCLUDED */
