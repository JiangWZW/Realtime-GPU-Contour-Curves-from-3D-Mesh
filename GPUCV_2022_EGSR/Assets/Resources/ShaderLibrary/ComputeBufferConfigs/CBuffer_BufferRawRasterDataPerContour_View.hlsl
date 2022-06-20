#ifndef CBUFFER_BUFFERRAWRASTERDATAPERCONTOUR_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWRASTERDATAPERCONTOUR_VIEW_INCLUDED

#include "../CustomShaderInputs.hlsl"
#include "../ComputeAddressingDefs.hlsl"

///////////////////////////////////////////////////////////////////////////////
//                              SUB BUFFER #0                                //
//---------------------------------------------------------------------------//

#define BITS_PER_CONTOUR_RASTER_DATA_STRIDE_OFFSET (BITS_CHUNK_OFFSET)
#define PER_CONTOUR_RASTER_DATA_BUFFER 0
#define PER_CONTOUR_RASTER_DATA_STRIDE (1 << BITS_PER_CONTOUR_RASTER_DATA_STRIDE_OFFSET)
#define PER_CONTOUR_RASTER_DATA_LENGTH (MAX_CONTOUR_COUNT * PER_CONTOUR_RASTER_DATA_STRIDE)

// Data Layout (uint4x2)
// Why uint4x2, not 2x4? ---------------------------------------
// Matrices are stored in column-major fasion
// in DX platform with hlsl compiler.
// so each Load4() op loads a 4x1 colmn of original matrix data.
// -------------------------------------------------------------
// +---------Column--------->
// =       _1       _2       
// R _1 [begSS.x | wHClip.x] (SS: Screen-Space-Coord)   
// o _2 [begSS.y | wHClip.y]   
// w _3 [endSS.x | rasterFlag] 
// = _4 [endSS.y | numSegments] 
// float2 beg;
// float2 end;
// float2 wHClip;
// uint rasterFlag;
// uint numSegment;
uint CBuffer_BufferRawRasterDataPerContour_AddrAt(uint visibleSegId)
{
    return (PER_CONTOUR_RASTER_DATA_BUFFER)
        + (visibleSegId << BITS_PER_CONTOUR_RASTER_DATA_STRIDE_OFFSET);
}

#define RASTER_DATA_BEG_END(rasterData) (rasterData._11_21_31_41)
#define GET_RASTER_DATA_BEG_END(rasterData) (asfloat(RASTER_DATA_BEG_END(rasterData)))

#define RASTER_DATA_HCLIP_W(rasterData) (rasterData._12_22)
#define GET_RASTER_DATA_HCLIP_W(rasterData) (asfloat(RASTER_DATA_HCLIP_W(rasterData)))

#define RASTER_DATA_FLAG(rasterData) (rasterData._32)
#define GET_RASTER_DATA_FLAG(rasterData)(RASTER_DATA_FLAG(rasterData))

#define RASTER_DATA_SEG_COUNT(rasterData) (rasterData._42)
#define GET_RASTER_DATA_SEG_COUNT(rasterData) (RASTER_DATA_SEG_COUNT(rasterData))

#define IS_TOP_LEFT_EDGE(rasterData) ((1 == (1 & (GET_RASTER_DATA_FLAG(rasterData)))))
#define IS_X_MAJOR_EDGE(rasterData) ((1 == (1 & (GET_RASTER_DATA_FLAG(rasterData) >> 1))))
#define IS_CLIPPED_EDGE(rasterData) ((1 == (1 & (GET_RASTER_DATA_FLAG(rasterData) >> 2))))
#define IS_EDGE_CLOCKWISE(rasterData) ((1 == (1 & (GET_RASTER_DATA_FLAG(rasterData) >> 3))))
#define IS_OCCLUSION_CULLED(rasterData) ((1 == (1 & (GET_RASTER_DATA_FLAG(rasterData) >> 4))))

uint ENCODE_RASTER_FLAG(
    bool isTopLeft,
    bool isXMajor,
    bool isClipped,
    bool isCWOrder,
    bool isOcclusionCulled
){
    uint res = 0;
    res |= isOcclusionCulled;
    res <<= 1; 
    res |= isCWOrder;
    res <<= 1;
    res |= isClipped;
    res <<= 1;
    res |= isXMajor;
    res <<= 1;
    res |= isTopLeft;

    return res;
}

// How vertex order was defined:
// -----------------------------------------------------------------------
// (v0, v1) original data from EVList
// ---------==> ShouldSwapWindingOrder ? (v1, v0) : (v0, v1) --------==> 
// (v0', v1') with colock-wise order
// ---------==> begFromP0 ? (v0, v1) : (v1, v0) ---------==>
// (v0", v1") final order, with correct raster order
//////////////////////////////////////////////////////////////////////////
// 
// Given vertex pos (v0", v1") from raster data
// To retrieve to correct vertex order, (clockwise on screen)
// -----------------------------------------------------------------------
// let is_clockwise = begFromP0
// Follow (v0', v1') = is_clockwise ? (v0", v1") : (v1", v0")
//////////////////////////////////////////////////////////////////////////






///////////////////////////////////////////////////////////////////////////////
//                              SUB BUFFER #1                                //
//---------------------------------------------------------------------------//
#define BITS_PER_CONTOUR_RASTER_DATA_II_STRIDE_OFFSET (BITS_CHUNK_OFFSET)
#define PER_CONTOUR_RASTER_DATA_II_BUFFER (PER_CONTOUR_RASTER_DATA_BUFFER + PER_CONTOUR_RASTER_DATA_LENGTH)
#define PER_CONTOUR_RASTER_DATA_II_STRIDE (1 << BITS_PER_CONTOUR_RASTER_DATA_II_STRIDE_OFFSET)
#define PER_CONTOUR_RASTER_DATA_II_LENGTH (MAX_CONTOUR_COUNT * PER_CONTOUR_RASTER_DATA_II_STRIDE)

//             Element Layout
// float4 (.xyz:vert0_posOS | .w:zview0);
// float4 (.xyz:vert1_posOS | .w:zview1);
uint CBuffer_BufferRawRasterDataPerContour_II_AddrAt(uint id)
{
    return (PER_CONTOUR_RASTER_DATA_II_BUFFER)
		+ (id << BITS_PER_CONTOUR_RASTER_DATA_II_STRIDE_OFFSET);
}



#endif /* CBUFFER_BUFFERRAWRASTERDATAPERCONTOUR_VIEW_INCLUDED */
