#ifndef CBUFFER_BUFFERRAWSTAMPPIXELS_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWSTAMPPIXELS_VIEW_INCLUDED

#include "../ComputeAddressingDefs.hlsl"
#include "../CustomShaderInputs.hlsl"
#include "../FrameCounter.hlsl"

//						Stamp Coordinate
//////////////////////////////////////////////////////////////////////////////
#define BITS_STAMP_PIXEL_COORD_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define STAMP_PIXEL_COORD_BUFFER (0)
#define STAMP_PIXEL_COORD_STRIDE ((1 << BITS_STAMP_PIXEL_COORD_STRIDE_OFFSET))
#define STAMP_PIXEL_COORD_LENGTH (MAX_STAMP_COUNT * STAMP_PIXEL_COORD_STRIDE)
// #define BITS_OFFSET_STAMP_PIXELS BITS_WORD_OFFSET
#define CBuffer_BufferRawStampPixels_AddrAt(id) ((id) << BITS_STAMP_PIXEL_COORD_STRIDE_OFFSET)

// Note: After visibility kernel, Before thinning kernel,
// stamp coord is temporally encoded with some flag bits.
uint GetEncodedPixelCoordWithFlags(uint packedPixelCoord)
{
	return packedPixelCoord;
}

void DecodePixelCoordWithFlags(uint encoded, 
	out uint packedPixelCoord)
{
	packedPixelCoord = encoded;
}



//						Stamp Object Space Position
//////////////////////////////////////////////////////////////////////////////
// Object position comes from the fragment that current stamp belongs to
#define BITS_STAMP_OS_POSITION_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define STAMP_OS_POSITION_BUFFER (STAMP_PIXEL_COORD_BUFFER + STAMP_PIXEL_COORD_LENGTH)
#define STAMP_OS_POSITION_STRIDE ((3 << BITS_STAMP_OS_POSITION_STRIDE_OFFSET))
#define STAMP_OS_POSITION_LENGTH (MAX_STAMP_COUNT * STAMP_OS_POSITION_STRIDE)
uint CBuffer_StampPixels_ObjectSpacePosition_AddrAt(uint stampId)
{
	return STAMP_OS_POSITION_BUFFER +
		(stampId * STAMP_OS_POSITION_STRIDE);
}



#define BITS_JFA_TILE_SIZE 5
#define JFA_TILE_SIZE ((1 << BITS_JFA_TILE_SIZE))
#define MAX_JFA_MAP_RES (((MAX_JFA_TEX_RES + JFA_TILE_SIZE - 1u) / JFA_TILE_SIZE))
#define NUM_JFA_TILES ((MAX_JFA_MAP_RES * MAX_JFA_MAP_RES))
//				Stamp Tiling for Jump Flood Algorithm (JFA)
//////////////////////////////////////////////////////////////////////////////
#define BITS_STAMP_JFA_TILE_LIST_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define STAMP_JFA_TILE_LIST_BUFFER (STAMP_OS_POSITION_BUFFER + STAMP_OS_POSITION_LENGTH)
#define STAMP_JFA_TILE_LIST_STRIDE ((1 << BITS_STAMP_JFA_TILE_LIST_STRIDE_OFFSET))
#define STAMP_JFA_TILE_LIST_LENGTH (NUM_JFA_TILES * STAMP_JFA_TILE_LIST_STRIDE)
uint CBuffer_StampPixels_JFATileList_AddrAt(uint culledTileId)
{
	return STAMP_JFA_TILE_LIST_BUFFER +
		(culledTileId * STAMP_JFA_TILE_LIST_STRIDE);
}


#endif /* CBUFFER_BUFFERRAWSTAMPPIXELS_VIEW_INCLUDED */
