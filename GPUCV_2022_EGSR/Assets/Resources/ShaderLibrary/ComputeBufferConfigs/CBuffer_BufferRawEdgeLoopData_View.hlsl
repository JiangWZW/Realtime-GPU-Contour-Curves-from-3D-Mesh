#ifndef BE5F8364_7847_47BA_9E3C_2F832DBB4323
#define BE5F8364_7847_47BA_9E3C_2F832DBB4323

#include "../ComputeAddressingDefs.hlsl"
#include "../CustomShaderInputs.hlsl"
#include "../FrameCounter.hlsl"



//						Edge Loop Flag Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_LOOP_FLAG_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define EDGE_LOOP_FLAG_BUFFER (0)
#define EDGE_LOOP_FLAG_STRIDE ((1 << BITS_EDGE_LOOP_FLAG_STRIDE_OFFSET))
#define EDGE_LOOP_FLAG_LENGTH (MAX_EDGE_LOOP_COUNT * EDGE_LOOP_FLAG_STRIDE)
// TODO: This is not properly initialized yet.
uint CBuffer_EdgeLoopData_Flags_AddrAt(uint edgeloopId)
{
	return EDGE_LOOP_FLAG_BUFFER // buffer offset
		+ (edgeloopId << BITS_EDGE_LOOP_FLAG_STRIDE_OFFSET); // Element offset
}

// Brush Path Info Encoding:
// high <------------------------------ low
// |                                      |
// |                                      |
// Template for define bits:
// #define BIT_BEG_EDGELOOP_FREE_BITS 0
// #define BIT_LEN_EDGELOOP_FREE_BITS 7
// #define BIT_BEG_EDGELOOP_CIRC_PATH ((BIT_BEG_EDGELOOP_FREE_BITS + BIT_LEN_EDGELOOP_FREE_BITS))
// #define BIT_LEN_EDGELOOP_CIRC_PATH 1
// #define BIT_BEG_EDGELOOP_BISEC_LEN ((BIT_BEG_EDGELOOP_CIRC_PATH + BIT_LEN_EDGELOOP_CIRC_PATH))
// #define BIT_LEN_EDGELOOP_BISEC_LEN 24

void SetEdgeLoopAttrib(uint attrVal, uint attrBitBeg, uint attrBitLen, inout uint edgeLoopAttribs)
{
	edgeLoopAttribs &= (GEN_BIT_CLEAR_MASK(attrBitBeg, attrBitLen));
	edgeLoopAttribs |= (attrVal << attrBitBeg);
}

uint GetEdgeLoopAttrib(uint attrBitBeg, uint attrBitLen, uint edgeLoopAttribs)
{
	return EXTRACT_BITS(edgeLoopAttribs, attrBitBeg, attrBitLen);
}

uint EncodePathFlags()
{
	uint res = 0;	// ////////////////  ____ ____ ____ ____ ____ ____ ____ ____
	// res |= XXX;		// ////  ____ ____ LLLL LLLL LLLL LLLL LLLL LLLL
	// res <<= BIT_LEN_XXX; //	 ____ ___L LLLL LLLL LLLL LLLL LLLL LLL_
	return res;
}


//						Edge Loop Head Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_LOOP_HEAD_EDGE_ID_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define LOOP_HEAD_EDGE_ID_BUFFER (EDGE_LOOP_FLAG_BUFFER + EDGE_LOOP_FLAG_LENGTH)
#define LOOP_HEAD_EDGE_ID_STRIDE ((1 << BITS_LOOP_HEAD_EDGE_ID_STRIDE_OFFSET))
#define NUM_LOOP_HEAD_EDGE_ID_SUB_BUFF 2
#define LOOP_HEAD_EDGE_ID_SUB_LENGTH ((MAX_EDGE_LOOP_COUNT * LOOP_HEAD_EDGE_ID_STRIDE))
#define LOOP_HEAD_EDGE_ID_LENGTH (NUM_LOOP_HEAD_EDGE_ID_SUB_BUFF * LOOP_HEAD_EDGE_ID_SUB_LENGTH)
uint CBuffer_EdgeLoopData_HeadEdgeID_AddrAt(uint edgeloopId, bool fromLastFrame = false)
{
	uint subbuffOffset = (
		(((_FrameCounter + fromLastFrame) % 2u) * LOOP_HEAD_EDGE_ID_SUB_LENGTH)
	);
	return LOOP_HEAD_EDGE_ID_BUFFER // buffer offset
		+ subbuffOffset // ping-pong between frames
		+ (edgeloopId << BITS_LOOP_HEAD_EDGE_ID_STRIDE_OFFSET); // Element offset
}


//						Edge Loop Tail Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_LOOP_TAIL_EDGE_ID_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define LOOP_TAIL_EDGE_ID_BUFFER (LOOP_HEAD_EDGE_ID_BUFFER + LOOP_HEAD_EDGE_ID_LENGTH)
#define LOOP_TAIL_EDGE_ID_STRIDE ((1 << BITS_LOOP_TAIL_EDGE_ID_STRIDE_OFFSET))
#define NUM_LOOP_TAIL_EDGE_ID_SUB_BUFF 2
#define LOOP_TAIL_EDGE_ID_SUB_LENGTH ((MAX_EDGE_LOOP_COUNT * LOOP_TAIL_EDGE_ID_STRIDE))
#define LOOP_TAIL_EDGE_ID_LENGTH ((NUM_LOOP_TAIL_EDGE_ID_SUB_BUFF * LOOP_TAIL_EDGE_ID_SUB_LENGTH))
// TODO: This is not properly initialized yet.
uint CBuffer_EdgeLoopData_TailEdgeID_AddrAt(uint edgeloopId, bool fromLastFrame = false)
{
	uint subbuffOffset = (
		(((_FrameCounter + fromLastFrame) % 2u) * LOOP_TAIL_EDGE_ID_SUB_LENGTH)
	);
	return LOOP_TAIL_EDGE_ID_BUFFER // buffer offset
		+ subbuffOffset // ping-pong between frames
		+ (edgeloopId << BITS_LOOP_TAIL_EDGE_ID_STRIDE_OFFSET); // Element offset
}


//						Edge Loop Length Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_PER_LOOP_LENGTH_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define PER_LOOP_LENGTH_BUFFER (LOOP_TAIL_EDGE_ID_BUFFER + LOOP_TAIL_EDGE_ID_LENGTH)
#define PER_LOOP_LENGTH_STRIDE ((1 << BITS_PER_LOOP_LENGTH_STRIDE_OFFSET))
#define NUM_PER_LOOP_LENGTH_SUB_BUFF 2
#define PER_LOOP_LENGTH_SUB_LENGTH ((MAX_EDGE_LOOP_COUNT * PER_LOOP_LENGTH_STRIDE))
#define PER_LOOP_LENGTH_LENGTH (NUM_PER_LOOP_LENGTH_SUB_BUFF * PER_LOOP_LENGTH_SUB_LENGTH)
uint CBuffer_EdgeLoopData_Length_AddrAt(uint edgeloopId, bool fromLastFrame = false)
{
	uint subbuffOffset = (
		(((_FrameCounter + fromLastFrame) % 2u) * PER_LOOP_LENGTH_SUB_LENGTH)
	);
	return PER_LOOP_LENGTH_BUFFER // buffer offset
		+ subbuffOffset // ping-pong between frames
		+ (edgeloopId << BITS_PER_LOOP_LENGTH_STRIDE_OFFSET); // Element offset
}


//						Edge Loop Bounding Box
//////////////////////////////////////////////////////////////////////////////
#define BITS_PER_LOOP_AABB_STRIDE_OFFSET (BITS_DWORD_OFFSET)

#define PER_LOOP_AABB_BUFFER (PER_LOOP_LENGTH_BUFFER + PER_LOOP_LENGTH_LENGTH)
#define PER_LOOP_AABB_STRIDE ((1 << BITS_PER_LOOP_AABB_STRIDE_OFFSET))
#define PER_LOOP_AABB_LENGTH (MAX_EDGE_LOOP_COUNT * PER_LOOP_AABB_STRIDE)
// min and max corner of edge-loop's aabb
// use DecodePixelCoord to unpack
uint CBuffer_EdgeLoopData_AABB_AddrAt(uint edgeloopId)
{
	return PER_LOOP_AABB_BUFFER // buffer offset
		+ (edgeloopId << BITS_PER_LOOP_AABB_STRIDE_OFFSET); // Element offset
}




//						Temporary Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_PER_LOOP_TEMP_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define PER_LOOP_TEMP_BUFFER (PER_LOOP_AABB_BUFFER + PER_LOOP_AABB_LENGTH)
#define PER_LOOP_TEMP_STRIDE ((1 << BITS_PER_LOOP_TEMP_STRIDE_OFFSET))
#define NUM_PER_LOOP_TEMP_SUB_BUFF 2
#define PER_LOOP_TEMP_SUB_LENGTH ((MAX_EDGE_LOOP_COUNT * PER_LOOP_TEMP_STRIDE))
#define PER_LOOP_TEMP_LENGTH (NUM_PER_LOOP_TEMP_SUB_BUFF * PER_LOOP_TEMP_SUB_LENGTH)
uint CBuffer_EdgeLoopData_Temp_AddrAt(uint subbuff, uint edgeloopId)
{
	uint subbuffOffset = subbuff * PER_LOOP_TEMP_SUB_LENGTH;
	return PER_LOOP_TEMP_BUFFER // buffer offset
		+ subbuffOffset // ping-pong between frames
		+ (edgeloopId << BITS_PER_LOOP_TEMP_STRIDE_OFFSET); // Element offset
}
#define TEMP_BUFF_LOOP_PBD_ADDR 0



#endif /* BE5F8364_7847_47BA_9E3C_2F832DBB4323 */
