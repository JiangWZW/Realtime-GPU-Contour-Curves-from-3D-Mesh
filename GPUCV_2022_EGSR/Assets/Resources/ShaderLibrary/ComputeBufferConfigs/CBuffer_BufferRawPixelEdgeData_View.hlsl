#ifndef C539303C_93E4_4047_82EB_2DA7C947B48A
#define C539303C_93E4_4047_82EB_2DA7C947B48A

#include "../ComputeAddressingDefs.hlsl"
#include "../CustomShaderInputs.hlsl"
#include "../ImageProcessing.hlsl"
#include "../FrameCounter.hlsl"

// A Stamp may have less than 4 contour edges
#define INVALID_STAMP_EDGE (0xffffffff)

////////////////////////////////////////////////////////////////
// Stamp Edge Info Encoding:
// high <------------------------------------------ low
//   2  :	  2    :     2    :    2     :   24
// | ?? | Prev Dir | Next Dir | Curr Dir | StampID |
// ID of the stamp to which this edge belongs
#define BIT_BEG_STAMP_ID (0)
#define BIT_LEN_STAMP_ID (24)
// Current edge direction tag
#define BIT_BEG_CURR_DIR (BIT_BEG_STAMP_ID + BIT_LEN_STAMP_ID)
#define BIT_LEN_CURR_DIR (2)
// Next edge direction tag
#define BIT_BEG_NEXT_DIR (BIT_BEG_CURR_DIR + BIT_LEN_CURR_DIR)
#define BIT_LEN_NEXT_DIR (2)
// Prev edge direction tag
#define BIT_BEG_PREV_DIR (BIT_BEG_NEXT_DIR + BIT_LEN_NEXT_DIR)
#define BIT_LEN_PREV_DIR (2)


uint EncodeStampEdgeData(
	uint stampID,
	uint edgeDir,
	uint nextDir,
	uint prevDir
)
{
	uint res = 0;	// ///////// ____ ____ ____ ____ ____ ____ ____ ____
	res |= prevDir; // ///////// ____ ____ ____ ____ ____ ____ ____ __PP
	res <<= BIT_LEN_NEXT_DIR; // ____ ____ ____ ____ ____ ____ ____ PP__
	res |= nextDir; // ///////// ____ ____ ____ ____ ____ ____ ____ PPNN
	res <<= BIT_LEN_CURR_DIR; // ____ ____ ____ ____ ____ ____ __PP NN__
	res |= edgeDir; // ///////// ____ ____ ____ ____ ____ ____ __PP NNDD	
	res <<= BIT_LEN_STAMP_ID; // __PP NNDD ____ ____ ____ ____ ____ ____
	res |= stampID; // ///////// __PP NNDD SSSS SSSS SSSS SSSS SSSS SSSS

	return res;
}

uint ComputeStampEdgeData(uint edgeDir, uint stampId, uint boxCode)
{
	return
		HasPixelEdge(edgeDir, boxCode)
			? EncodeStampEdgeData(
				stampId, edgeDir,
				FindNextEdgeDir(edgeDir, boxCode),
				FindPrevEdgeDir(edgeDir, boxCode)
			)
			: INVALID_STAMP_EDGE;
}

uint CountStampEdges(uint4 stampEdgeData)
{
	float4 validEdge =
		float4(
			(float)((uint) (stampEdgeData.x != INVALID_STAMP_EDGE)),
			(float)((uint) (stampEdgeData.y != INVALID_STAMP_EDGE)),
			(float)((uint) (stampEdgeData.z != INVALID_STAMP_EDGE)),
			(float)((uint) (stampEdgeData.w != INVALID_STAMP_EDGE))
		);
    return (uint) (validEdge.x + validEdge.y + validEdge.z + validEdge.w);
}

#ifndef CAT
// Macro expansion, for details, see
// ---------------------------------------
// https://stackoverflow.com/questions/1489932/how-to-concatenate-twice-with-the-c-preprocessor-and-expand-a-macro-as-in-arg
#define CAT_(x, y) x ## y
#define CAT(x, y) CAT_(x, y)
#endif

#define GET_STAMP_EDGE_STAMP_ID(data) (EXTRACT_BITS(data, BIT_BEG_STAMP_ID, BIT_LEN_STAMP_ID))
#define GET_STAMP_EDGE_DIR_CURR(data) (EXTRACT_BITS(data, BIT_BEG_CURR_DIR, BIT_LEN_CURR_DIR))
#define GET_STAMP_EDGE_DIR_NEXT(data) (EXTRACT_BITS(data, BIT_BEG_NEXT_DIR, BIT_LEN_NEXT_DIR))
#define GET_STAMP_EDGE_DIR_PREV(data) (EXTRACT_BITS(data, BIT_BEG_PREV_DIR, BIT_LEN_PREV_DIR))

struct EdgeToStampData
{
	uint stampID;
	uint currDir;
	uint nextDir;
	uint prevDir;
};

EdgeToStampData DecodeEdgeToStampData(uint dataRaw)
{
	EdgeToStampData res;
	res.currDir = GET_STAMP_EDGE_DIR_CURR(dataRaw);
	res.nextDir = GET_STAMP_EDGE_DIR_NEXT(dataRaw);
	res.prevDir = GET_STAMP_EDGE_DIR_PREV(dataRaw);
	res.stampID = GET_STAMP_EDGE_STAMP_ID(dataRaw);

	return res;
}

//                   Stamp-to-Edges Buffer
/////////////////////////////////////////////////////////////// 
#define BITS_STAMP_EDGE_STRIDE_OFFSET (BITS_BLOCK_OFFSET)
//  Data Layout --- For details, see "ImageProcessing.hlsl"
//  In general, this buffer stores 4 edge data (encoded as above)
//  surrounding each stamp.
//  +=== uint4 Edges  ===+      0      
//  |   .x: Edge #0      |    *-->*    
//  |   .y: Edge #1      |  3 | P | 1  
//  |   .z: Edge #2      |    *<--*    
//  |   .w: Edge #3      |      2      
//  +====================+-------------------------------------
#define STAMP_EDGE_BUFFER (0)
#define STAMP_EDGE_STRIDE (1 << BITS_STAMP_EDGE_STRIDE_OFFSET)
#define STAMP_EDGE_SUBBUFF_LENGTH (MAX_STAMP_EDGE_COUNT * STAMP_EDGE_STRIDE)
#define STAMP_EDGE_NUM_SUBBUFF 3
#define STAMP_EDGE_LENGTH (STAMP_EDGE_NUM_SUBBUFF * STAMP_EDGE_SUBBUFF_LENGTH)

uint CBuffer_PixelEdgeData_StampToEdges_AddrAt(uint stampId, uint edgeDir)
{
	return
		( // Base offset + Slot offset
			(stampId << BITS_STAMP_EDGE_STRIDE_OFFSET) +
			(edgeDir << BITS_WORD_OFFSET)
		);
}

uint CBuffer_PixelEdgeData_StampToEdges_AddrAt(uint subbuff, uint stampId, uint edgeDir)
{
	return
		(subbuff * STAMP_EDGE_SUBBUFF_LENGTH) +
		( // Base offset + Slot offset
			(stampId << BITS_STAMP_EDGE_STRIDE_OFFSET) +
			(edgeDir << BITS_WORD_OFFSET)
		);
}


//                   Edges to Stamp Buffer
////////////////////////////////////////////////////////////////////////////
// Stores edge data for each edge.
// which contains pointer to the stamp this edge belongs to.
// for encoding details, see notes at top.
#define BITS_EDGES_TO_STAMP_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGES_TO_STAMP_BUFFER (STAMP_EDGE_BUFFER + STAMP_EDGE_LENGTH)
#define EDGES_TO_STAMP_STRIDE (1 << BITS_EDGES_TO_STAMP_STRIDE_OFFSET)
#define EDGES_TO_STAMP_LENGTH (MAX_STAMP_EDGE_COUNT * EDGES_TO_STAMP_STRIDE)

uint CBuffer_PixelEdgeData_EdgesToStamp_AddrAt(uint edgeId)
{
    return EDGES_TO_STAMP_BUFFER +
			(edgeId << BITS_EDGES_TO_STAMP_STRIDE_OFFSET);
}

//								Edge Scan Buffer
//////////////////////////////////////////////////////////////////////////////
// Memory allocated dedicated for scanning edge data.
// This sub-buffer does not occupy space in current buffer
// instead, we re-use other buffer
#define BITS_EDGE_SCAN_STRIDE_OFFSET (BITS_DWORD_OFFSET)

#define EDGE_SCAN_BUFFER (0) // (re-use other buffer, not this one.)
#define EDGE_SCAN_STRIDE (1 << BITS_EDGE_SCAN_STRIDE_OFFSET)
#define EDGE_SCAN_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_SCAN_STRIDE * 2)
// _______________________________________________________________#### About * 2: 
// Segmented scan needs head flag array to indicate start of each segment.
// When type of data is not of uint, we need to store flag & uint separately.
uint CBuffer_PixelEdgeData_ScanWorkbench_AddrAt(uint edgeId)
{
	return EDGE_SCAN_BUFFER +
		(edgeId << BITS_EDGE_SCAN_STRIDE_OFFSET);
}

// Seg-scan for despeckling process
uint2 EncodeDifferentialArea_HF_Coord(uint headFlag, uint2 stampCoord, float da)
{
	uint stampCoordPacked = PackPixelCoord(stampCoord);
	uint u32 = ((stampCoordPacked << 1) | headFlag);
	return uint2(u32, asuint(da));
}

void DecodeDifferentialAreaAndHF(uint2 data, 
	out uint headFlag, out uint2 stampCoord, out float da)
{
	stampCoord = DecodePixelCoord(data.x >> 1);
	headFlag = (data.x & 1);
	da = asfloat(data.y);
}


//						Edge Attribute List Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_ATTRIB_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGE_ATTRIB_BUFFER (EDGES_TO_STAMP_BUFFER + EDGES_TO_STAMP_LENGTH)
#define EDGE_ATTRIB_STRIDE ((1 << BITS_EDGE_ATTRIB_STRIDE_OFFSET))

#define EDGE_ATTRIB_SUB_LEN (MAX_STAMP_EDGE_COUNT * EDGE_ATTRIB_STRIDE)
// X4 Sub-Buffers:
// #0: Edge Attribute;
// #1, 2, 3, 4, 5: Temp buffers for segment denoising/least-squares fitting
#define EDGE_ATTRIB_NUM_SUB (6)
#define EDGE_ATTRIB_LENGTH (EDGE_ATTRIB_NUM_SUB * EDGE_ATTRIB_SUB_LEN)

uint CBuffer_PixelEdgeData_SerializedAttribs_AddrAt(
	uint subSlot, uint edgeId
){
	return EDGE_ATTRIB_BUFFER // buffer offset
		+ (subSlot * EDGE_ATTRIB_SUB_LEN) // Sub-buffer offset
		+ (edgeId << BITS_EDGE_ATTRIB_STRIDE_OFFSET); // Element offset
}

float ComputeDifferentialArea(uint edgeDir, uint yCoord)
{
	float dxdt = (edgeDir == 0) ? 1 : ((edgeDir == 2) ? -1 : 0);
	yCoord += (edgeDir == 0) ? 1 : 0;
	// Ãæ»ýÎ¢Ôª dArea = y * dx/dt * dt(== 1)
	return dxdt * yCoord;
}

// Stamp Edge Attrib Encoding:
//  high <---------------------------------------------- low
// |  4 bits	|      2 bit     	|   2 bits	|    24 bits	|
// | (reserved)	|  Head/Tail Flag 	|  Curr Dir	| StampID/Coord	|
// Stamp Info of this edge, ID / Coord depending on the situation
#define BIT_BEG_STAMP_INFO 0
#define BIT_LEN_STAMP_INFO 24
// Current edge direction tag
#define BIT_BEG_EDGE_DIR (BIT_BEG_STAMP_INFO + BIT_LEN_STAMP_INFO)
#define BIT_LEN_EDGE_DIR 2
// Head flag, indicates if this is head/tail element of an edge sub-list(segment)
#define BIT_BEG_HEAD_FLAG (BIT_BEG_EDGE_DIR + BIT_LEN_EDGE_DIR) 
#define BIT_LEN_HEAD_FLAG 2
#define EDGE_SEG_FLAG_HEAD_BIT	1
#define EDGE_SEG_FLAG_TAIL_BIT	2

// If this whole edge-loop is parameterized as a single stroke
#define BIT_BEG_LOOP_FLAG BIT_BEG_HEAD_FLAG
#define BIT_LEN_LOOP_FLAG 1
// The same as the rpj flag "BIT_BEG_COMPLEX_LINE" 
// Note: Make sure this doesn't conflict with rpj flag
#define BIT_BEG_AMBIGUOUS (BIT_BEG_LOOP_FLAG + BIT_LEN_LOOP_FLAG)
#define BIT_LEN_AMBIGUOUS 1
#define BIT_BEG_BISECTION (BIT_BEG_AMBIGUOUS)
#define BIT_LEN_BISECTION (BIT_LEN_AMBIGUOUS)

// Temporary flags: --------------------------------------------
//  high <------
// |  4 bits	|
// | (reserved)	|
// |			 \.
// |DF OR HD DE| temp data (phase I)
// |~~ ~~ ~~ ~~| temp data (phase II) (~~ means bit keep the same)
// |32 30 29 28| bit addr.
// 'DE':
// Delete flag, once this flag is set as true,
// then this edge is considered as deleted
#define BIT_BEG_DEL_FLAG (BIT_BEG_HEAD_FLAG + BIT_LEN_HEAD_FLAG)
#define BIT_LEN_DEL_FLAG 1
// 'HD':
// History Draw Flag,
// (deprecated)
#define BIT_BEG_H_DRAW_FLAG (BIT_BEG_DEL_FLAG + BIT_LEN_DEL_FLAG)
#define BIT_LEN_H_DRAW_FLAG 1
// 'OR':
// Edge Orientation flag,
// true if edge-loop is 'inside' a surface
// false otherwise
#define BIT_BEG_ORIENT_FLAG (BIT_BEG_H_DRAW_FLAG + BIT_LEN_H_DRAW_FLAG)
#define BIT_LEN_ORIENT_FLAG 1

// 'DF': Is this edge on a visible & parametrized stroke
#define BIT_BEG_DRAW_FLAG (BIT_BEG_ORIENT_FLAG + BIT_LEN_ORIENT_FLAG)
#define BIT_LEN_DRAW_FLAG 1


void SetEdgeAttrib(uint attrVal, uint attrBitBeg, uint attrBitLen, inout uint edgeAttribs)
{
	edgeAttribs &= (GEN_BIT_CLEAR_MASK(attrBitBeg, attrBitLen));
	edgeAttribs |= (attrVal << attrBitBeg);
}

uint GetEdgeAttrib(uint attrBitBeg, uint attrBitLen, uint edgeAttribs)
{
	return EXTRACT_BITS(edgeAttribs, attrBitBeg, attrBitLen);
}

uint EncodeEdgeAttrib(uint stampInfo, uint edgeDir, uint headFlag)
{
	uint res = 0;	// /////////	____ ____ ____ ____ ____ ____ ____ ____
	res |= headFlag; // /////////	____ ____ ____ ____ ____ ____ ____ __HH
	res <<= BIT_LEN_EDGE_DIR; //	____ ____ ____ ____ ____ ____ ____ HH__
	res |= edgeDir; // /////////	____ ____ ____ ____ ____ ____ ____ HHDD
	res <<= BIT_LEN_STAMP_INFO; //	____ HHDD ____ ____ ____ ____ ____ ____
	res |= stampInfo; // /////////	____ HHDD SSSS SSSS SSSS SSSS SSSS SSSS

	return res;
}


uint EncodeSegHeadTailFlags(uint isNewHead, uint isNewTail)
{
	//		1		  0		bit
	// |isNewTail isNewHead|
	return ((isNewTail << 1) | isNewHead);
}
uint EncodeBisectionHeadTailFlags(uint isBisectHead, uint isBisectTail)
{
	//	2		1		  0		bit
	//  1  |isNewTail isNewHead|
	// bit2==1 indicates this head&tail is a bisection mark,
	// generated from path-loop bisection:
	// we slice path-loop into two paths
	return ((1 << 2) | (isBisectTail << 1) | isBisectHead);
}
void DecodeSegHeadTailFlags(uint code, out uint isHead, out uint isTail)
{
	isHead = ((code & 1));
	isTail = ((code >> 1) & 1);
}
bool IsBisectionHeadTailFlags(uint code)
{
	return (1 == ((code >> 2) & 1));
}

struct EdgeAttrib
{
	uint stampInfo;
	uint edgeDir;
	uint segFlag;
};

EdgeAttrib DecodeEdgeAttrib(uint edgeAttribDataRaw)
{
	EdgeAttrib edgeAttrib;
	edgeAttrib.stampInfo = EXTRACT_COMPONENT(edgeAttribDataRaw, STAMP_INFO);
	edgeAttrib.edgeDir = EXTRACT_COMPONENT(edgeAttribDataRaw, EDGE_DIR);
	edgeAttrib.segFlag = EXTRACT_COMPONENT(edgeAttribDataRaw, HEAD_FLAG);

	return edgeAttrib;
}


//						Edge Coordinate
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_COORD_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGE_COORD_BUFFER (EDGE_ATTRIB_BUFFER + EDGE_ATTRIB_LENGTH)
#define EDGE_COORD_LENGTH ((MAX_STAMP_EDGE_COUNT << BITS_EDGE_COORD_STRIDE_OFFSET))
uint CBuffer_PixelEdgeCoord_Encoded_AddrAt(uint edgeId)
{
	return EDGE_COORD_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_COORD_STRIDE_OFFSET); // Element offset
}

uint EncodePixelEdgeCoord(uint2 pixelCoord, uint edgeDir)
{
	uint pixelCoordPacked = PackPixelCoord(pixelCoord);
	uint res = EncodeEdgeAttrib(
		pixelCoordPacked, edgeDir, 
		0 // TODO: not needed here
	);
	return res;
}
float2 DecodePixelEdgeCoord(uint data)
{
	EdgeAttrib res = DecodeEdgeAttrib(data);
	uint edgeDir = res.edgeDir;
	uint2 pixelCoord = DecodePixelCoord(res.stampInfo);
	float2 edgeCoord = (float2)pixelCoord + 0.5 * MoveAtOppositeStamp(edgeDir);

	return edgeCoord;
}


//						Edge Chain Code (x32)
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_CHAIN_CODE_STRIDE_OFFSET (BITS_DWORD_OFFSET)

#define EDGE_CHAIN_CODE_BUFFER (EDGE_COORD_BUFFER + EDGE_COORD_LENGTH)
#define EDGE_CHAIN_CODE_LENGTH ((MAX_STAMP_EDGE_COUNT << BITS_EDGE_CHAIN_CODE_STRIDE_OFFSET))
uint CBuffer_PixelEdgeData_ChainCode_AddrAt(uint edgeId)
{
	return EDGE_CHAIN_CODE_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_CHAIN_CODE_STRIDE_OFFSET); // Element offset
}
void AppendToChainCode(uint neighEdgeDir, inout uint chainCode)
{
	chainCode <<= 2;
	chainCode |= neighEdgeDir;
}
uint PopFromChainCode(inout uint chainCode)
{
	uint neighEdgeDir = (chainCode >> 30);
	chainCode <<= 2;

	return neighEdgeDir;
}


//						Edge Refined Coordinate
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_SMOOTH_COORD_STRIDE_OFFSET (BITS_DWORD_OFFSET)

#define EDGE_SMOOTH_COORD_BUFFER (EDGE_CHAIN_CODE_BUFFER + EDGE_CHAIN_CODE_LENGTH)
#define EDGE_SMOOTH_COORD_STRIDE ((1 << BITS_EDGE_SMOOTH_COORD_STRIDE_OFFSET))
#define EDGE_SMOOTH_COORD_LENGTH ((MAX_STAMP_EDGE_COUNT * EDGE_SMOOTH_COORD_STRIDE))
uint CBuffer_PixelEdgeData_SmoothCoord_AddrAt(uint edgeId)
{
	return EDGE_SMOOTH_COORD_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_SMOOTH_COORD_STRIDE_OFFSET); // Element offset
}


//						Edge-loop Arc Parametrization
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_LOOP_ARC_PARAM_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGE_LOOP_ARC_PARAM_BUFFER (EDGE_SMOOTH_COORD_BUFFER + EDGE_SMOOTH_COORD_LENGTH)
#define EDGE_LOOP_ARC_PARAM_STRIDE ((1 << BITS_EDGE_LOOP_ARC_PARAM_STRIDE_OFFSET))
#define EDGE_LOOP_ARC_PARAM_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_LOOP_ARC_PARAM_STRIDE)
// Pixel-edge's arc-len parameter
uint CBuffer_PixelEdgeData_EdgeLoopArcLenParam_AddrAt(uint edgeId)
{
	return EDGE_LOOP_ARC_PARAM_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_LOOP_ARC_PARAM_STRIDE_OFFSET); // Element offset
}


//						Path Arc Parametrization
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_ARC_LEN_PARAM_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGE_ARC_LEN_PARAM_BUFFER (EDGE_LOOP_ARC_PARAM_BUFFER + EDGE_LOOP_ARC_PARAM_LENGTH)
#define EDGE_ARC_LEN_PARAM_STRIDE ((1 << BITS_EDGE_ARC_LEN_PARAM_STRIDE_OFFSET))
#define EDGE_ARC_LEN_PARAM_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_ARC_LEN_PARAM_STRIDE)
// Pixel-edge's arc-len parameter
uint CBuffer_PixelEdgeData_ArcLenParam_AddrAt(uint edgeId)
{
	return EDGE_ARC_LEN_PARAM_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_ARC_LEN_PARAM_STRIDE_OFFSET); // Element offset
}


//							Path Arc Length
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_PATH_ARC_LEN_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGE_PATH_ARC_LEN_BUFFER (EDGE_ARC_LEN_PARAM_BUFFER + EDGE_ARC_LEN_PARAM_LENGTH)
#define EDGE_PATH_ARC_LEN_STRIDE ((1 << BITS_EDGE_PATH_ARC_LEN_STRIDE_OFFSET))
#define EDGE_PATH_ARC_LEN_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_PATH_ARC_LEN_STRIDE)
uint CBuffer_PixelEdgeData_PathArcLen_AddrAt(uint edgeId)
{
	return EDGE_PATH_ARC_LEN_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_PATH_ARC_LEN_STRIDE_OFFSET); // Element offset
}



//						Edge Tangent Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_TANGENT_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGE_TANGENT_BUFFER (EDGE_PATH_ARC_LEN_BUFFER + EDGE_PATH_ARC_LEN_LENGTH)
#define EDGE_TANGENT_STRIDE ((1 << BITS_EDGE_TANGENT_STRIDE_OFFSET))
#define EDGE_TANGENT_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_TANGENT_STRIDE)

uint CBuffer_PixelEdgeData_EdgeTangent_AddrAt(uint edgeId)
{
	return EDGE_TANGENT_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_TANGENT_STRIDE_OFFSET); // Element offset
}

//						Edge Curvature Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_CURV_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGE_CURV_BUFFER (EDGE_TANGENT_BUFFER + EDGE_TANGENT_LENGTH)
#define EDGE_CURV_STRIDE ((1 << BITS_EDGE_CURV_STRIDE_OFFSET))
#define EDGE_CURV_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_CURV_STRIDE)

uint CBuffer_PixelEdgeData_EdgeCurvature_AddrAt(uint edgeId)
{
	return EDGE_CURV_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_CURV_STRIDE_OFFSET); // Element offset
}

//						Edge Curvature-Derivative Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_CURV_DERIV_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGE_CURV_DERIV_BUFFER (EDGE_CURV_BUFFER + EDGE_CURV_LENGTH)
#define EDGE_CURV_DERIV_STRIDE ((1 << BITS_EDGE_CURV_DERIV_STRIDE_OFFSET))
#define EDGE_CURV_DERIV_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_CURV_DERIV_STRIDE)

uint CBuffer_PixelEdgeData_EdgeCurvatureDerivative_AddrAt(uint edgeId)
{
	return EDGE_CURV_DERIV_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_CURV_DERIV_STRIDE_OFFSET); // Element offset
}

//						Edge Parameter Buffer
//////////////////////////////////////////////////////////////////////////////
// Stores edge rank normalized to [0, 1] and length of edge
#define BITS_EDGE_PARAM_STRIDE_OFFSET (BITS_DWORD_OFFSET)

#define EDGE_PARAM_BUFFER (EDGE_CURV_DERIV_BUFFER + EDGE_CURV_DERIV_LENGTH)
#define EDGE_PARAM_STRIDE ((1 << BITS_EDGE_PARAM_STRIDE_OFFSET))
#define EDGE_PARAM_SUB_BUF_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_PARAM_STRIDE)
#define NUM_EDGE_PARAM_SUB_BUFF 4u
#define EDGE_PARAM_LENGTH (NUM_EDGE_PARAM_SUB_BUFF * EDGE_PARAM_SUB_BUF_LENGTH)

#define EDGE_PARAM_STROKE ((_FrameCounter) % 2u)
// #define EDGE_PARAM_STROKE_HISTORY ((_FrameCounter + 1u) % 2u)
#define EDGE_PARAM_BRUSH_PATH ((2u + ((_FrameCounter) % 2u)))
// #define EDGE_PARAM_BRUSH_PATH_HISTORY ((2u + ((_FrameCounter + 1u) % 2u)))
uint CBuffer_PixelEdgeData_EdgeParam_AddrAt(uint subbuff, uint edgeId)
{
	return EDGE_PARAM_BUFFER // buffer offset
		+ (subbuff * EDGE_PARAM_SUB_BUF_LENGTH)
		+ (edgeId << BITS_EDGE_PARAM_STRIDE_OFFSET); // Element offset
}

uint CBuffer_PixelEdgeData_EdgeParam_LoadSegRank(
	RWByteAddressBuffer buffer, uint subbuff, uint edgeId
) {
	return buffer.Load(
		CBuffer_PixelEdgeData_EdgeParam_AddrAt(subbuff, edgeId)
	);
}
uint CBuffer_PixelEdgeData_EdgeParam_LoadSegLength(
	RWByteAddressBuffer buffer, uint subbuff, uint edgeId
) {
	return buffer.Load(
		CBuffer_PixelEdgeData_EdgeParam_AddrAt(subbuff, edgeId) 
		+ (1 << BITS_WORD_OFFSET)
	);
}
uint CBuffer_PixelEdgeData_EdgeParam_LoadSegLength(
	ByteAddressBuffer buffer, uint subbuff, uint edgeId
) {
	return buffer.Load(
		CBuffer_PixelEdgeData_EdgeParam_AddrAt(subbuff, edgeId)
		+ (1 << BITS_WORD_OFFSET)
	);
}

void CBuffer_PixelEdgeData_EdgeParam_LoadAll(
	RWByteAddressBuffer buffer, uint subbuff, uint edgeId, 
	out float edgeRank, out float segLength
){
	uint2 data = buffer.Load2(
		CBuffer_PixelEdgeData_EdgeParam_AddrAt(subbuff, edgeId)
	);
	edgeRank = (float)data.x;
	segLength = (float)data.y;
}
void CBuffer_PixelEdgeData_EdgeParam_LoadAll(
	RWByteAddressBuffer buffer, uint subbuff, uint edgeId,
	out uint edgeRank, out uint segLength
) {
	uint2 data = buffer.Load2(
		CBuffer_PixelEdgeData_EdgeParam_AddrAt(subbuff, edgeId)
	);
	edgeRank  = data.x;
	segLength = data.y;
}


uint2 EncodeEdgeHistoryParam(uint edgeRank, uint segLen, bool drawFlag)
{
	return uint2(
		((edgeRank << 1) | drawFlag),
		segLen
	);
}
void DecodeEdgeHistoryParam(
	uint2 dataRaw,
	out uint edgeRank, out uint segLen, out bool drawFlag)
{
	edgeRank = (dataRaw.x >> 1);
	drawFlag = (dataRaw.x & 1);
	segLen = dataRaw.y;
}



//						Edge Depth Buffer
//////////////////////////////////////////////////////////////////////////////
// Stores edge rank normalized to [0, 1] and length of edge
#define BITS_EDGE_DEPTH_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGE_DEPTH_BUFFER (EDGE_PARAM_BUFFER + EDGE_PARAM_LENGTH)
#define EDGE_DEPTH_STRIDE ((1 << BITS_EDGE_DEPTH_STRIDE_OFFSET))
#define EDGE_DEPTH_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_DEPTH_STRIDE)

uint CBuffer_PixelEdgeData_EdgeDepth_AddrAt(uint edgeId)
{
	return EDGE_DEPTH_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_DEPTH_STRIDE_OFFSET); // Element offset
}

//						Edge Depth Gradient Buffer
//////////////////////////////////////////////////////////////////////////////
// Stores edge rank normalized to [0, 1] and length of edge
#define BITS_EDGE_ZGRAD_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGE_ZGRAD_BUFFER (EDGE_DEPTH_BUFFER + EDGE_DEPTH_LENGTH)
#define EDGE_ZGRAD_STRIDE ((1 << BITS_EDGE_ZGRAD_STRIDE_OFFSET))
#define EDGE_ZGRAD_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_ZGRAD_STRIDE)

uint CBuffer_PixelEdgeData_EdgeZGrad_AddrAt(uint edgeId)
{
	return EDGE_ZGRAD_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_ZGRAD_STRIDE_OFFSET); // Element offset
}


//						Edge Loop Convolution Patch Data
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_CONV_PATCH_STRIDE_OFFSET (BITS_WORD_OFFSET)

#define EDGE_CONV_RADIUS 32
#define EDGE_CONV_MAX_NUM_GROUPS 1024
#define EDGE_CONV_NUM_PATCHES_PER_GROUP ((EDGE_CONV_RADIUS * 2))
#define EDGE_CONV_MAX_NUM_PATCHES (EDGE_CONV_MAX_NUM_GROUPS * EDGE_CONV_NUM_PATCHES_PER_GROUP)

#define EDGE_CONV_PATCH_BUFFER (EDGE_ZGRAD_BUFFER + EDGE_ZGRAD_LENGTH)
#define EDGE_CONV_PATCH_STRIDE ((1 << BITS_EDGE_CONV_PATCH_STRIDE_OFFSET))
#define EDGE_CONV_PATCH_LENGTH (EDGE_CONV_MAX_NUM_PATCHES * EDGE_CONV_PATCH_STRIDE)


uint CBuffer_PixelEdgeData_EdgeConvPatch_AddrAt(
	uint gIdx, uint patchId
){
	return EDGE_CONV_PATCH_BUFFER +
	((
		(gIdx * EDGE_CONV_NUM_PATCHES_PER_GROUP) + patchId) 
			<< BITS_EDGE_CONV_PATCH_STRIDE_OFFSET
	);
}



//							Segmentation Key
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_SEG_KEY_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define EDGE_SEG_KEY_BUFFER ((EDGE_CONV_PATCH_BUFFER + 2 * EDGE_CONV_PATCH_LENGTH))
#define EDGE_SEG_KEY_STRIDE ((1 << BITS_EDGE_SEG_KEY_STRIDE_OFFSET))
#define NUM_SUBBUFF_EDGE_SEG_KEY 2u
#define EDGE_SEG_KEY_SUB_LENGTH ((MAX_STAMP_EDGE_COUNT * EDGE_SEG_KEY_STRIDE))
#define EDGE_SEG_KEY_LENGTH ((NUM_SUBBUFF_EDGE_SEG_KEY * EDGE_SEG_KEY_SUB_LENGTH))
uint CBuffer_PixelEdgeData_SegmentKey_AddrAt(uint subbuff, uint edgeId)
{
	uint subbuffOffset = subbuff * EDGE_SEG_KEY_SUB_LENGTH;
	return EDGE_SEG_KEY_BUFFER // buffer offset
		+ subbuffOffset // sub-buffer offset
		+ (edgeId << BITS_EDGE_SEG_KEY_STRIDE_OFFSET); // Element offset
}
#define STROKE_SEG_KEY_CULLED 0xffffffff




//						Edge Loop Id Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_LOOP_ID_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define EDGE_LOOP_ID_BUFFER (EDGE_SEG_KEY_BUFFER + EDGE_SEG_KEY_LENGTH)
#define EDGE_LOOP_ID_STRIDE ((1 << BITS_EDGE_LOOP_ID_STRIDE_OFFSET))
#define EDGE_LOOP_ID_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_LOOP_ID_STRIDE)
// An unique ID for each edge loop. 
uint CBuffer_PixelEdgeData_EdgeLoopID_AddrAt(uint edgeId)
{
	return EDGE_LOOP_ID_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_LOOP_ID_STRIDE_OFFSET); // Element offset
}


//						Edge Path Id Buffer
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_PATH_ID_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define EDGE_PATH_ID_BUFFER (EDGE_LOOP_ID_BUFFER + EDGE_LOOP_ID_LENGTH)
#define EDGE_PATH_ID_STRIDE ((1 << BITS_EDGE_PATH_ID_STRIDE_OFFSET))
#define EDGE_PATH_ID_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_PATH_ID_STRIDE)
// An unique ID for each edge path. 
uint CBuffer_PixelEdgeData_EdgePathID_AddrAt(uint edgeId)
{
	return EDGE_PATH_ID_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_PATH_ID_STRIDE_OFFSET); // Element offset
}




//						Edge Temp Buffer #1
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_TEMP1_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define EDGE_TEMP1_BUFFER (EDGE_PATH_ID_BUFFER + EDGE_PATH_ID_LENGTH)
#define EDGE_TEMP1_STRIDE ((1 << BITS_EDGE_TEMP1_STRIDE_OFFSET))
#define EDGE_TEMP1_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_TEMP1_STRIDE)

uint CBuffer_PixelEdgeData_EdgeTemp1_AddrAt(uint edgeId)
{
	return EDGE_TEMP1_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_TEMP1_STRIDE_OFFSET); // Element offset
}
#define CBuffer_PixelEdgeData_ParticleStringStart_AddrAt CBuffer_PixelEdgeData_EdgeTemp1_AddrAt

//						Edge Temp Buffer #2
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_TEMP2_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define EDGE_TEMP2_BUFFER (EDGE_TEMP1_BUFFER + EDGE_TEMP1_LENGTH)
#define EDGE_TEMP2_STRIDE ((1 << BITS_EDGE_TEMP2_STRIDE_OFFSET))
#define EDGE_TEMP2_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_TEMP2_STRIDE)

uint CBuffer_PixelEdgeData_EdgeTemp2_AddrAt(uint edgeId)
{
	return EDGE_TEMP2_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_TEMP2_STRIDE_OFFSET); // Element offset
}
#define CBuffer_PixelEdgeData_EdgeIdBeforeShift_AddrAt CBuffer_PixelEdgeData_EdgeTemp2_AddrAt



//						Edge Temp Buffer #3
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_TEMP3_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define EDGE_TEMP3_BUFFER (EDGE_TEMP2_BUFFER + EDGE_TEMP2_LENGTH)
#define EDGE_TEMP3_STRIDE ((1 << BITS_EDGE_TEMP3_STRIDE_OFFSET))
#define EDGE_TEMP3_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_TEMP3_STRIDE)

uint CBuffer_PixelEdgeData_EdgeTemp3_AddrAt(uint edgeId)
{
	return EDGE_TEMP3_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_TEMP3_STRIDE_OFFSET); // Element offset
}


//						Edge Temp Buffer #4
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_TEMP4_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define EDGE_TEMP4_BUFFER (EDGE_TEMP3_BUFFER + EDGE_TEMP3_LENGTH)
#define EDGE_TEMP4_STRIDE ((1 << BITS_EDGE_TEMP4_STRIDE_OFFSET))
#define EDGE_TEMP4_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_TEMP4_STRIDE)

uint CBuffer_PixelEdgeData_EdgeTemp4_AddrAt(uint edgeId)
{
	return EDGE_TEMP4_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_TEMP4_STRIDE_OFFSET); // Element offset
}


//						Edge Temp Buffer #5
//////////////////////////////////////////////////////////////////////////////
#define BITS_EDGE_TEMP5_STRIDE_OFFSET (BITS_WORD_OFFSET)
#define EDGE_TEMP5_BUFFER (EDGE_TEMP4_BUFFER + EDGE_TEMP4_LENGTH)
#define EDGE_TEMP5_STRIDE ((1 << BITS_EDGE_TEMP5_STRIDE_OFFSET))
#define EDGE_TEMP5_LENGTH (MAX_STAMP_EDGE_COUNT * EDGE_TEMP5_STRIDE)

uint CBuffer_PixelEdgeData_EdgeTemp5_AddrAt(uint edgeId)
{
	return EDGE_TEMP5_BUFFER // buffer offset
		+ (edgeId << BITS_EDGE_TEMP5_STRIDE_OFFSET); // Element offset
}

#endif /* C539303C_93E4_4047_82EB_2DA7C947B48A */
