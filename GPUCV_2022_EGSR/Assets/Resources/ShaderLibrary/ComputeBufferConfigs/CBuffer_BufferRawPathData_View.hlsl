#ifndef ACFDD250_E1B1_461F_AD80_1E67DC7BF749
#define ACFDD250_E1B1_461F_AD80_1E67DC7BF749
#include "../ComputeAddressingDefs.hlsl"
#include "../CustomShaderInputs.hlsl"
#include "../ImageProcessing.hlsl"
#include "../FrameCounter.hlsl"



//						Path Flag Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_PATH_FLAG_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define PATH_FLAG_BUFFER (0)
#define PATH_FLAG_STRIDE ((1 << BITS_PATH_FLAG_STRIDE_OFFSET))
#define PATH_FLAG_LENGTH (MAX_PATH_COUNT * PATH_FLAG_STRIDE)
uint CBuffer_PathData_Flags_AddrAt(uint pathId)
{
	return PATH_FLAG_BUFFER // buffer offset
		+ (pathId << BITS_PATH_FLAG_STRIDE_OFFSET); // Element offset
}

// Brush Path Info Encoding:
// high <------------------------------ low
// |       24        |    1     |    7    |
// | len_bisect_left | edgeloop |	 ?	  |
//
// len_bisect_left(BISEC_LEN):
// Path may get "sliced" to two halves, 
// example, path A and B consists a edge-loop
// [ A1A2A3 B0B1B2 A0 ] (A/Bi := ith edge in path)
// We record length of the left half part : len(A1A2A3)=3

#define AFTER_BITS(TAG) ((CAT(BIT_BEG_, TAG)) + (CAT(BIT_LEN_, TAG)))

#define BIT_BEG_PATH_FREE_BITS 0
#define BIT_LEN_PATH_FREE_BITS 7
#define BIT_BEG_PATH_CIRC_PATH ((BIT_BEG_PATH_FREE_BITS + BIT_LEN_PATH_FREE_BITS))
#define BIT_LEN_PATH_CIRC_PATH 1
#define BIT_BEG_PATH_BISEC_LEN ((BIT_BEG_PATH_CIRC_PATH + BIT_LEN_PATH_CIRC_PATH))
#define BIT_LEN_PATH_BISEC_LEN 24


void SetPathAttrib(uint attrVal, uint attrBitBeg, uint attrBitLen, inout uint pathAttribs)
{
	pathAttribs &= (GEN_BIT_CLEAR_MASK(attrBitBeg, attrBitLen));
	pathAttribs |= (attrVal << attrBitBeg);
}

uint GetPathAttrib(uint attrBitBeg, uint attrBitLen, uint pathAttribs)
{
	return EXTRACT_BITS(pathAttribs, attrBitBeg, attrBitLen);
}

uint EncodePathFlags(bool bCircularPath, uint leftBisectedLen)
{
	leftBisectedLen &= 0x00ffffff; // 24 bits
	
	uint res = 0;	// ////////////////  ____ ____ ____ ____ ____ ____ ____ ____
	res |= leftBisectedLen;		// ////  ____ ____ LLLL LLLL LLLL LLLL LLLL LLLL
	res <<= BIT_LEN_PATH_CIRC_PATH; //	 ____ ___L LLLL LLLL LLLL LLLL LLLL LLL_
	res |= (uint)bCircularPath;     // ____ ___L LLLL LLLL LLLL LLLL LLLL LLLE
	res <<= BIT_LEN_PATH_FREE_BITS; //	 LLLL LLLL LLLL LLLL LLLL LLLL E___ ____

	return res;
}


//						Path Head Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_PATH_HEAD_EDGE_ID_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define PATH_HEAD_EDGE_ID_BUFFER (PATH_FLAG_BUFFER + PATH_FLAG_LENGTH)
#define PATH_HEAD_EDGE_ID_STRIDE ((1 << BITS_PATH_HEAD_EDGE_ID_STRIDE_OFFSET))
#define NUM_PATH_HEAD_EDGE_ID_SUB_BUFF 2
#define PATH_HEAD_EDGE_ID_SUB_LENGTH ((MAX_PATH_COUNT * PATH_HEAD_EDGE_ID_STRIDE))
#define PATH_HEAD_EDGE_ID_LENGTH (NUM_PATH_HEAD_EDGE_ID_SUB_BUFF * PATH_HEAD_EDGE_ID_SUB_LENGTH)
uint CBuffer_PathData_HeadEdgeID_AddrAt(uint pathId, bool isLastFramePath = false)
{
	uint subbuffOffset = (
		(((_FrameCounter + isLastFramePath) % 2u) * PATH_HEAD_EDGE_ID_SUB_LENGTH)
	);
	return PATH_HEAD_EDGE_ID_BUFFER // buffer offset
		+ subbuffOffset // ping-pong between frames
		+ (pathId << BITS_PATH_HEAD_EDGE_ID_STRIDE_OFFSET); // Element offset
}


//						Path Tail Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_PATH_TAIL_EDGE_ID_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define PATH_TAIL_EDGE_ID_BUFFER (PATH_HEAD_EDGE_ID_BUFFER + PATH_HEAD_EDGE_ID_LENGTH)
#define PATH_TAIL_EDGE_ID_STRIDE ((1 << BITS_PATH_TAIL_EDGE_ID_STRIDE_OFFSET))
#define NUM_PATH_TAIL_EDGE_ID_SUB_BUFF 2
#define PATH_TAIL_EDGE_ID_SUB_LENGTH ((MAX_PATH_COUNT * PATH_TAIL_EDGE_ID_STRIDE))
#define PATH_TAIL_EDGE_ID_LENGTH ((NUM_PATH_TAIL_EDGE_ID_SUB_BUFF * PATH_TAIL_EDGE_ID_SUB_LENGTH))
uint CBuffer_PathData_TailEdgeID_AddrAt(uint pathId, bool isLastFramePath = false)
{
	uint subbuffOffset = (
		(((_FrameCounter + isLastFramePath) % 2u) * PATH_TAIL_EDGE_ID_SUB_LENGTH)
	);
	return PATH_TAIL_EDGE_ID_BUFFER // buffer offset
		+ subbuffOffset // ping-pong between frames
		+ (pathId << BITS_PATH_TAIL_EDGE_ID_STRIDE_OFFSET); // Element offset
}


//						Path Length Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_PER_PATH_LENGTH_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define PER_PATH_LENGTH_BUFFER (PATH_TAIL_EDGE_ID_BUFFER + PATH_TAIL_EDGE_ID_LENGTH)
#define PER_PATH_LENGTH_STRIDE ((1 << BITS_PER_PATH_LENGTH_STRIDE_OFFSET))
#define NUM_PER_PATH_LENGTH_SUB_BUFF 2
#define PER_PATH_LENGTH_SUB_LENGTH ((MAX_PATH_COUNT * PER_PATH_LENGTH_STRIDE))
#define PER_PATH_LENGTH_LENGTH (NUM_PER_PATH_LENGTH_SUB_BUFF * PER_PATH_LENGTH_SUB_LENGTH)
uint CBuffer_PathData_Length_AddrAt(uint pathId, bool isLastFramePath = false)
{
	uint subbuffOffset = (
		(((_FrameCounter + isLastFramePath) % 2u) * PER_PATH_LENGTH_SUB_LENGTH)
	);
	return PER_PATH_LENGTH_BUFFER // buffer offset
		+ subbuffOffset // ping-pong between frames
		+ (pathId << BITS_PER_PATH_LENGTH_STRIDE_OFFSET); // Element offset
}

#endif /* ACFDD250_E1B1_461F_AD80_1E67DC7BF749 */
