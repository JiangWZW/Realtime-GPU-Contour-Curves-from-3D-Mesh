#ifndef CBUFFER_BUFFERRAWPERFACE_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWPERFACE_VIEW_INCLUDED

#include "../ComputeAddressingDefs.hlsl"

// CBuffer_BufferRawPerFace -------------------------------------
// struct layout

// RenderDoc Shortcut --------------
// uint4 stride0;
// uint2 stride10;
// float2 stride11;
#define BITS_OFFSET_BUFFER_RAW_PER_FACE BITS_WORD_OFFSET
#define CBuffer_BufferRawPerFace_AddrAt(id) (id << BITS_OFFSET_BUFFER_RAW_PER_FACE)

uint CBuffer_BufferRawPerFace_Subbuff_AddrAt(uint subbuffOffset, uint id)
{
	return ((subbuffOffset + id) << BITS_OFFSET_BUFFER_RAW_PER_FACE);
}

// Composite & Extract Flags ---------------------
// flag: 000, 100, 111 ---- smooth contour flag
// facingFlag: 00, 01, 10 - front/back facing flag
#define Encode_Flags_32bit(flag, facingFlag) (facingFlag | (flag << 2))
#define Decode_Flag_0(code) ((code >> 2) & 7)
#define Decode_Flag_1(code) (code & 3)

#endif /* CBUFFER_BUFFERRAWPERFACE_VIEW_INCLUDED */
