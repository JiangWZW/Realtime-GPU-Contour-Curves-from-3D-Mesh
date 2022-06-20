#ifndef CBUFFER_BUFFERRAWRASTERDATAPERSEG_INCLUDED
#define CBUFFER_BUFFERRAWRASTERDATAPERSEG_INCLUDED

#include "../CustomShaderInputs.hlsl"
#include "../ComputeAddressingDefs.hlsl"
//						Per Seg Raster Data
//////////////////////////////////////////////////////////////////////////////
#define BITS_PER_SEG_RASTER_DATA_STRIDE_OFFSET (BITS_BLOCK_OFFSET)
#define PER_SEG_RASTER_DATA_BUFFER 0
#define PER_SEG_RASTER_DATA_STRIDE (1 << BITS_PER_SEG_RASTER_DATA_STRIDE_OFFSET)

#define NUM_SUBBUFF_PER_SEG_RASTER_DATA 1
#define PER_SEG_RASTER_DATA_SUB_BUFF_LENGTH (MAX_VISIBLE_SEG_COUNT * PER_SEG_RASTER_DATA_STRIDE)

#define PER_SEG_RASTER_DATA_LENGTH (NUM_SUBBUFF_PER_SEG_RASTER_DATA * PER_SEG_RASTER_DATA_SUB_BUFF_LENGTH)
// At most 1 subbuff for now
uint CBuffer_BufferRawRasterDataPerVisibleSeg(uint subbuff, uint visibleSegId)
{
	return (PER_SEG_RASTER_DATA_BUFFER) + 
		(subbuff * (PER_SEG_RASTER_DATA_SUB_BUFF_LENGTH))
		+ (visibleSegId << BITS_PER_SEG_RASTER_DATA_STRIDE_OFFSET);
}

//                          Sub-Buffer 0
// Data Layout
// .x : View Space Z
// .y: edge tangent x
// .z: edge tangent y
// .w: screen space depth gradient
uint4 ENCODE_PER_SEG_RASTER_DATA(
	float zview,
	float2 tangent,
	float attrib2
)
{
	return uint4(
		asuint(zview),
		asuint(tangent).xy,
		asuint(attrib2)
	);
}

#define RASTER_DATA_PER_SEG_VIEWZ(rasterData) ((rasterData.x))
#define GET_RASTER_DATA_PER_SEG_VIEWZ(rasterData) \
        (asfloat(RASTER_DATA_PER_SEG_VIEWZ(rasterData)))

#define RASTER_DATA_PER_SEG_FLAG(rasterData) ((rasterData.y))
#define GET_RASTER_DATA_PER_SEG_FLAG(rasterData) \
        (asfloat(RASTER_DATA_PER_SEG_FLAG(rasterData)))

#define RASTER_DATA_PER_SEG_TANGENT(rasterData) ((rasterData.z))
#define GET_RASTER_DATA_PER_SEG_TANGENT(rasterData) \
        (asfloat(RASTER_DATA_PER_SEG_TANGENT(rasterData)))

#define RASTER_DATA_PER_SEG_DZSS(rasterData) ((rasterData.w))
#define GET_RASTER_DATA_PER_SEG_DZSS(rasterData) \
        (asfloat(RASTER_DATA_PER_SEG_DZSS(rasterData)))



//						Visible Segment to Contour
//////////////////////////////////////////////////////////////////////////////
#define BITS_VISIBLE_SEG_TO_CONTOUR_STRIDE_OFFSET (BITS_DWORD_OFFSET)
#define VISIBLE_SEG_TO_CONTOUR_BUFFER (PER_SEG_RASTER_DATA_BUFFER + PER_SEG_RASTER_DATA_LENGTH)
#define VISIBLE_SEG_TO_CONTOUR_STRIDE (1 << BITS_VISIBLE_SEG_TO_CONTOUR_STRIDE_OFFSET)
#define VISIBLE_SEG_TO_CONTOUR_LENGTH (MAX_VISIBLE_SEG_COUNT * VISIBLE_SEG_TO_CONTOUR_STRIDE)
// .x: asuint(linearInterpFactor), .y: contourId
uint CBuffer_BufferRawVisibleSegToContour(uint visibleSegId)
{
	return (VISIBLE_SEG_TO_CONTOUR_BUFFER)
		+ (visibleSegId << BITS_VISIBLE_SEG_TO_CONTOUR_STRIDE_OFFSET);
}




// ----------------------------------------------------------------------
// After thinning kernel, we consider the raster data above as redundant,
// so that we can use this large buffer for something else
// 
// Macros for tangent convolution
// ------------------------------------------------
uint PingPongBuffer_ParticleTangent_AddrAt(
	uint ptclId, uint pingpong, uint stride)
{
	pingpong = (pingpong % 2u); // for safety
	return (ptclId + pingpong * MAX_PBD_PARTICLE_COUNT) * stride;
}


// Macros for particle segmentation
// ------------------------------------------------







// Legacy Code Shit Hole 
// -----------------------------
#define CONV_DATA_STRIDE 2
#define CONV_DATA_T vector<float, CONV_DATA_STRIDE>
#define INVALID_CONV_DATA(data) (((data.x) == -1))

// Convolution radius
#define SMOOTH_RADIUS 16
#define SMOOTH_LDS_LEN (GROUP_SIZE_0 + 2 * SMOOTH_RADIUS)

// Patch configs
#define NULL_LEFT_TAIL (0xffffffff)
#define NULL_RIGHT_HEAD 0
#define NUM_PATCHES_PER_GROUP ((SMOOTH_RADIUS * 2))

// Patch Edge Indices, pre-stored to accelerate convolution
#define G_PATCH_BUFFER 0
#define BITS_PATCH_INDEX BITS_WORD_OFFSET
#define MAX_NUM_GROUPS 2048
#define G_PATCH_BUFFER_LEN (((MAX_NUM_GROUPS * NUM_PATCHES_PER_GROUP) << BITS_PATCH_INDEX))

uint Conv_Buffer_PatchData_AddrAt(uint gIdx, uint groupId)
{
	return ((((gIdx * NUM_PATCHES_PER_GROUP) + groupId) << BITS_PATCH_INDEX));
}

// Temp buffer to place intermediate convolution results
#define CONV_DATA_BUFFER (G_PATCH_BUFFER + G_PATCH_BUFFER_LEN)
uint Conv_Buffer_ConvData_AddrAt(uint subbuff, uint idx)
{
	return (CONV_DATA_BUFFER) + ((subbuff * MAX_STAMP_EDGE_COUNT + idx) << BITS_WORD_OFFSET);
}

#endif /* CBUFFER_BUFFERRAWRASTERDATAPERSEG_INCLUDED */
