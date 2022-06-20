#ifndef CBUFFER_BUFFERRAWFLAGSPEREDGE_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWFLAGSPEREDGE_VIEW_INCLUDED

#include "../ComputeAddressingDefs.hlsl"
#define BITS_OFFSET_FLAGS_PER_EDGE BITS_WORD_OFFSET

#define CBuffer_BufferRawFlagsPerEdge_AddrAt(id) (id << BITS_OFFSET_FLAGS_PER_EDGE)

// Edge Flag Encoding:
// bit[1]: is_font_face
// bit[0]: is_contour
// Returns 0 if first adj face is front-facing, 1 otherwise
uint AdjFrontFace(uint flag){
    return (flag >> 1) & (uint)(0x00000001);
}

bool isContourEdge(uint flag){
    return ((flag & 1) == 1);
}

#endif /* CBUFFER_BUFFERRAWFLAGSPEREDGE_VIEW_INCLUDED */
