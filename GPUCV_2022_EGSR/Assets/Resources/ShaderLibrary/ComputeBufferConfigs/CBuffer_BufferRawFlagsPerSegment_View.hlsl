#ifndef CBUFFER_BUFFERRAWFLAGSPERSEGMENT_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWFLAGSPERSEGMENT_VIEW_INCLUDED
#include "../ComputeAddressingDefs.hlsl"
#include "../CustomShaderInputs.hlsl"

#define BITS_OFFSET_FLAGS_PER_SEG BITS_WORD_OFFSET
#define CBuffer_BufferRawFlagsPerSegment_AddrAt(id) (id << BITS_OFFSET_FLAGS_PER_SEG)

    // Data layout:
    // ===================================================================================
    // Pixel coord of this segment is packed into 30bits
    // as xxx,yyy, 14bits for each axis, which means we support at most 4kx4k resolution
    // [31_________________________ 2] [3, 2] [1] [0]
    // |<---- Pixel Coord ---------->|  DUAL   PF  V 
    // |<---    28 bits   ---------->|
    //                                  2  
    // DUAL: Dual Pixel to Produce // 3 P 1
    // PF: Pixel Generate Flag          0
    // V: Segment Visibility
    // ===================================================================================
uint EncodeSegmentFlag(
        uint pixelCoord, // Index of contour, to which this segment belongs
        bool isPixelSeg, // Flag: if this segment represents a unique pixel
        bool visible, // Flag: is segment visible
		uint dualFragOffsetCode
    )
{
    uint strData = pixelCoord;      // ____ PPPP PPPP PPPP PPPP PPPP PPPP PPPP
    strData <<= 2;                  // __PP PPPP PPPP PPPP PPPP PPPP PPPP PP__
    strData |= dualFragOffsetCode;  // __PP PPPP PPPP PPPP PPPP PPPP PPPP PPDD
    strData <<= 1;                  // _PPP PPPP PPPP PPPP PPPP PPPP PPPP PDD_
    strData |= isPixelSeg;          // _PPP PPPP PPPP PPPP PPPP PPPP PPPP PDDP
    strData <<= 1;                  // PPPP PPPP PPPP PPPP PPPP PPPP PPPP DDP_
    strData |= visible;             // PPPP PPPP PPPP PPPP PPPP PPPP PPPP DDPV
    return strData;
}
// Decode Methods
// xxx, yyy (14 bits each axis)
#define SEG_PIXEL_COORD(code) (((code) >> 4))
#define SEG_PIXEL_COORD_MASK 0x00003fff
uint2 DecodeSegCoordFromSegFlag(uint segFlag)
{
    uint xyPacked = SEG_PIXEL_COORD(segFlag);
    uint2 xy = uint2(
            (xyPacked >> 14) & SEG_PIXEL_COORD_MASK,
            (xyPacked & SEG_PIXEL_COORD_MASK)
        );
    return xy;
}
uint EncodeSegCoordFromSegPosition(float2 segPos)
{
    uint2 snappedPos = (uint2)segPos;
    return ((snappedPos.x << 14) | snappedPos.y);
}

#define SEG_IS_VISIBLE(code) ((((code) & 1) == 1))
uint4 Segs_Visibility_X4(uint4 code_X4)
{
    uint4 mask = uint4(1, 1, 1, 1);
    return ((code_X4) & mask);
}

#define SEG_FLAG_OFFSET_PIXEL 1
uint4 Segs_PixelFlag_X4(uint4 code_X4)
{
    uint4 mask = uint4(1, 1, 1, 1);
    return ((code_X4 >> SEG_FLAG_OFFSET_PIXEL) & mask);
}

#endif /* CBUFFER_BUFFERRAWFLAGSPERSEGMENT_VIEW_INCLUDED */
