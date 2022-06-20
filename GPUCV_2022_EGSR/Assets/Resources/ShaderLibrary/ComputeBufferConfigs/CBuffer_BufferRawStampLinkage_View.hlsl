#ifndef CBUFFER_BUFFERRAWSTAMPLINKAGE_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWSTAMPLINKAGE_VIEW_INCLUDED

#include "../ComputeAddressingDefs.hlsl"
#include "../CustomShaderInputs.hlsl"
#include "../FrameCounter.hlsl"

// #define BITS_OFFSET_BUFFER_RAW_STAMP_TANGENT BITS_BLOCK_OFFSET
// PINGPONG_0 and _1 subbuffers are used for ping-pong in the list ranking process.
#define PINGPONG_STAMP_LINKAGE_0 0
#define PINGPONG_STAMP_LINKAGE_1 1
#define ORIGINAL_STAMP_LINKAGE 2

uint CBuffer_BufferRawStampLinkage_AddrAt(uint subbuff, uint id)
{
	return (((MAX_STAMP_COUNT * subbuff + id) << (BITS_BLOCK_OFFSET)));
}
uint CBuffer_BufferRawStampLinkageSlot_AddrAt(uint subbuff, uint stampId, uint slotId)
{
	// .xy: slot #0, .zw: slot #1
    uint linkageBlockAddr = CBuffer_BufferRawStampLinkage_AddrAt(subbuff, stampId);
    uint slotOffset = slotId << BITS_DWORD_OFFSET;
    return linkageBlockAddr + slotOffset;
}

// Data Layout 
//    .w    .z    .y    .x
// high <----------------- low
//   22 : 20 : 22 : 22 : 20 : 22
// | ?? | R1 | L1 | MX | R0 | L0 |
// |<-- Slot#1 -->|<-- Slot#0 -->|
// MX: Max stamp id
// R1: Rank #1 L1: Link #1 
// R0: Rank #0 L0: Link #0
// _________ .w _________|__________ .z __________|
// <-- ??:22 --><-R1:10->|<-R1:10-><--- L1:22 --->|
// _________ .y _________|__________ .x __________|
// <-- MX:22 --><-R0:10->|<-R0:10-><--- L0:22 --->|
#define STAMP_LINK_SLICEMASK_LOW (0x003fffff)
#define STAMP_LINK_SLICEMASK_HIGH (0x000003ff)

uint2 EncodeStampLinkageSlot(uint link, uint rank, uint extraInfo)
{
	uint2 res = 0;
	res.x = (link & STAMP_LINK_SLICEMASK_LOW) | ((rank << 22) & (~STAMP_LINK_SLICEMASK_LOW));
	res.y = ((rank >> 10) & STAMP_LINK_SLICEMASK_HIGH) | ((extraInfo << 10) & (~STAMP_LINK_SLICEMASK_HIGH));
	return res;
}

uint4 EncodeStampLinkage(uint link0, uint rank0, uint link1, uint rank1, uint maxID)
{
	uint4 linkData = uint4(0, 0, 0, 0);
    linkData.xy = EncodeStampLinkageSlot(link0, rank0, maxID); // Slot #0
    linkData.zw = EncodeStampLinkageSlot(link1, rank1, 0); // Slot #1
	return linkData;
}


#define GET_STAMP_LINK_0(linkData) ((linkData.x & (STAMP_LINK_SLICEMASK_LOW)))

#define GET_STAMP_RANK_0_SLICE_X(linkData) ((linkData.x & (~STAMP_LINK_SLICEMASK_LOW)))
#define GET_STAMP_RANK_0_SLICE_Y(linkData) ((linkData.y & (STAMP_LINK_SLICEMASK_HIGH)))
uint GET_STAMP_RANK_0(uint4 linkData)
{
	uint2 slices = uint2(
		GET_STAMP_RANK_0_SLICE_X(linkData),
		GET_STAMP_RANK_0_SLICE_Y(linkData)
	);
	return ((slices.x >> 22) | (slices.y << 10));
}

#define GET_STAMP_LINK_1(linkData) ((linkData.z & (STAMP_LINK_SLICEMASK_LOW)))

#define GET_STAMP_RANK_1_SLICE_X(linkData) ((linkData.z & (~STAMP_LINK_SLICEMASK_LOW)))
#define GET_STAMP_RANK_1_SLICE_Y(linkData) ((linkData.w & (STAMP_LINK_SLICEMASK_HIGH)))
uint GET_STAMP_RANK_1(uint4 linkData)
{
    uint2 slices = uint2(
		GET_STAMP_RANK_1_SLICE_X(linkData),
		GET_STAMP_RANK_1_SLICE_Y(linkData)
	);
    return ((slices.x >> 22) | (slices.y << 10));
}

// _________ .w _________|__________ .z __________|
// <-- ??:22 --><-R1:10->|<-R1:10-><--- L1:22 --->|
// _________ .y _________|__________ .x __________|
// <-- MX:22 --><-R0:10->|<-R0:10-><--- L0:22 --->|
uint GET_STAMP_MAX_ID(uint4 linkData)
{
	return ((linkData.y & (~STAMP_LINK_SLICEMASK_HIGH)) >> 10);
}



// We need some "Special" notation for non-skeleton pixels
#define NULL_STAMP_LINKPTR (0x003fffff)

struct LinkDataRT
{
	uint link0;
	uint rank0;
	uint link1;
	uint rank1;
	uint maxID;
};


LinkDataRT ExtractLinkage(uint4 linkDataRaw)
{
	LinkDataRT res;
	res.link0 = GET_STAMP_LINK_0(linkDataRaw);
	res.rank0 = GET_STAMP_RANK_0(linkDataRaw);
	res.link1 = GET_STAMP_LINK_1(linkDataRaw);
	res.rank1 = GET_STAMP_RANK_1(linkDataRaw);
	res.maxID = GET_STAMP_MAX_ID(linkDataRaw);

	return res;
}

uint4 PackLinkageRT(LinkDataRT data)
{
	return EncodeStampLinkage(
		data.link0, data.rank0, data.link1, data.rank1, data.maxID
	);
}

LinkDataRT StampPointerJumping_Dbg(
	uint stampId, uint StampCount, uint pingpongFlag,
	RWByteAddressBuffer LinkageBuffer,
	out bool isRedundant
)
{
	LinkDataRT link = ExtractLinkage(
		LinkageBuffer.Load4(
			CBuffer_BufferRawStampLinkage_AddrAt(
				pingpongFlag, stampId)));
	LinkDataRT linkNew = link;

	// If this pixel is deleted in previous thinning passes,
	isRedundant = (link.link0 == NULL_STAMP_LINKPTR);
	// or this thread is a "trash thread", just ignore it;
	isRedundant = (stampId >= StampCount) || isRedundant;

	LinkDataRT link0 = ExtractLinkage(
		LinkageBuffer.Load4(
			CBuffer_BufferRawStampLinkage_AddrAt(
				pingpongFlag, link.link0)));

	bool isStrokeEnd = (link0.link0 == link.link0 || link0.link1 == link.link0);
	bool updateAt0 = (link0.link0 != stampId);

	linkNew.link0 = isStrokeEnd ? link.link0 : (updateAt0 ? link0.link0 : link0.link1);
	linkNew.rank0 += isStrokeEnd ? 0 : (updateAt0 ? link0.rank0 : link0.rank1);
	linkNew.maxID = max(linkNew.maxID, link0.maxID);

	LinkDataRT link1 =
		ExtractLinkage(LinkageBuffer.Load4(
			CBuffer_BufferRawStampLinkage_AddrAt(
				pingpongFlag, link.link1)));

	isStrokeEnd = (link1.link0 == link.link1 || link1.link1 == link.link1);
	updateAt0 = (link1.link0 != stampId);
	linkNew.link1 = isStrokeEnd ? link.link1 : (updateAt0 ? link1.link0 : link1.link1);
	linkNew.rank1 += isStrokeEnd ? 0 : (updateAt0 ? link1.rank0 : link1.rank1);
	linkNew.maxID = max(linkNew.maxID, link1.maxID);


	LinkageBuffer.Store4(
		CBuffer_BufferRawStampLinkage_AddrAt(
			(pingpongFlag + 1) % 2, stampId
		),
		isRedundant ? PackLinkageRT(link) : PackLinkageRT(linkNew)
	);

	return linkNew;
}


// -------------------------------------------------------------------
// Edge Link Configuration
// -------------------------------------------------------------------
uint CBuffer_BufferRawEdgeLinkage_AddrAt(uint subbuff, uint id)
{
	return (((MAX_STAMP_EDGE_COUNT * subbuff + id) << (BITS_DWORD_OFFSET)));
}
uint CBuffer_BufferRawEdgeIndirect_AddrAt(uint subbuff, uint id)
{
	return (
		(CBuffer_BufferRawEdgeLinkage_AddrAt(ORIGINAL_STAMP_LINKAGE + 1, 0))
		+ ((MAX_STAMP_EDGE_COUNT * subbuff + id) << BITS_WORD_OFFSET)
	);
}

/**
 * \brief Get certain component in link data,
 * valid for MaxIDLink and EdgeLink, for now.
 * 
 * \param slotId 0 for extra info, 1 for next edge id.
 * \return data(uint) in that slot.
 */
uint CBuffer_BufferRawEdgeLinkageSlot_AddrAt(uint subbuff, uint edgeId, uint slotId)
{
	return (
		CBuffer_BufferRawEdgeLinkage_AddrAt(subbuff, edgeId) // base offset
		+ (slotId << BITS_WORD_OFFSET) // slot offset
	);
}

// Link Data for finding link list head(seed):
// -------------------------------------------------------
uint SeparateBy1(uint x) {
	x &= 0x0000ffff;                 // x = ---- ---- ---- ---- fedc ba98 7654 3210
	x = (x ^ (x << 8)) & 0x00ff00ff; // x = ---- ---- fedc ba98 ---- ---- 7654 3210
	x = (x ^ (x << 4)) & 0x0f0f0f0f; // x = ---- fedc ---- ba98 ---- 7654 ---- 3210
	x = (x ^ (x << 2)) & 0x33333333; // x = --fe --dc --ba --98 --76 --54 --32 --10
	x = (x ^ (x << 1)) & 0x55555555; // x = -f-e -d-c -b-a -9-8 -7-6 -5-4 -3-2 -1-0
	return x;
}

uint CompactBy1(uint x) {
	x &= 0x55555555;                 // x = -f-e -d-c -b-a -9-8 -7-6 -5-4 -3-2 -1-0
	x = (x ^ (x >> 1)) & 0x33333333; // x = --fe --dc --ba --98 --76 --54 --32 --10
	x = (x ^ (x >> 2)) & 0x0f0f0f0f; // x = ---- fedc ---- ba98 ---- 7654 ---- 3210
	x = (x ^ (x >> 4)) & 0x00ff00ff; // x = ---- ---- fedc ba98 ---- ---- 7654 3210
	x = (x ^ (x >> 8)) & 0x0000ffff; // x = ---- ---- ---- ---- fedc ba98 7654 3210
	return x;
}

uint MortonCode2(uint2 xy) {
	return SeparateBy1(xy.x) | (SeparateBy1(xy.y) << 1);
}

uint2 MortonDecode2(uint c) {
	uint2 xy;
	xy.x = CompactBy1(c);
	xy.y = CompactBy1(c >> 1);

	return xy;
}

uint EncodeEdgeMaxID(uint2 stampCoord, uint currDir)
{
	// stamp coord (12 X 2) bits, currDir 2bits
	stampCoord.x = (stampCoord.x << 1) | (currDir >> 1);// 12 + 1 = 13 bits
	stampCoord.y = (stampCoord.y << 1) | (currDir & 1); // 12 + 1 = 13 bits
	return MortonCode2(stampCoord & 0x0000ffff/*0x00001fff*/);
}

void DecodeEdgeMaxID(uint maxID, out uint2 stampCoord, out uint currDir)
{
	uint2 decoded = MortonDecode2(maxID);
	stampCoord = decoded >> 1;
	currDir = ((decoded.x & 1) << 1) | (decoded.y & 1);
}
void DecodeEdgeMaxID(uint maxID, out uint2 stampCoord)
{
	uint2 decoded = MortonDecode2(maxID);
	stampCoord = decoded >> 1;
}

#define GET_EDGE_LINK_0_MAX_ID(rawLink) ((((rawLink).x)))
void DecodeMaxIDLink(
	uint2 rawLink,
	out uint maxID, out uint nextEdgeID)
{
	maxID = rawLink.x;
	nextEdgeID = rawLink.y;
}

uint2 EncodeMaxIDLink(uint maxID, uint nextEdgeID)
{
	return uint2(maxID, nextEdgeID);
}


struct EdgeMaxIDLinkRT
{
	uint maxID;
	uint nextEdgeID;
};

EdgeMaxIDLinkRT ExtractEdgeMaxIdLinkRt(uint2 linkData)
{
	EdgeMaxIDLinkRT res;
	DecodeMaxIDLink(linkData, res.maxID, res.nextEdgeID);
	return res;
}
uint2 PackEdgeMaxIdLinkRT(EdgeMaxIDLinkRT linkDataRT)
{
	return EncodeMaxIDLink(linkDataRT.maxID, linkDataRT.nextEdgeID);
}


bool CompareMaxIDAndRank(EdgeMaxIDLinkRT link0, EdgeMaxIDLinkRT link1)
{
	return link0.maxID < link1.maxID;
}

// Test only, to test if the seed has been obtained
// #define TEST_SEED_DETECTION

EdgeMaxIDLinkRT EdgePointerJumpingMaxID_Dbg(
	uint edgeId, uint edgeCount, 
	uint pingpongFlag,
	RWByteAddressBuffer linkageBuffer,
	inout bool isRedundant
)
{
	isRedundant = isRedundant || (edgeId >= edgeCount);

	EdgeMaxIDLinkRT link =
		ExtractEdgeMaxIdLinkRt(
			linkageBuffer.Load2(
				CBuffer_BufferRawEdgeLinkage_AddrAt(
					pingpongFlag, edgeId
				)
			)
		);

	EdgeMaxIDLinkRT linkNext =
		ExtractEdgeMaxIdLinkRt(
			linkageBuffer.Load2(
				CBuffer_BufferRawEdgeLinkage_AddrAt(
					pingpongFlag, link.nextEdgeID
				)
			)
		);
	
#ifdef TEST_SEED_DETECTION
	bool foundSeed = (link.maxID == linkNext.maxID);
#endif
	
	// Update link data
	bool compare = CompareMaxIDAndRank(link, linkNext); // true if linkNext > link
	link.maxID = max(linkNext.maxID, link.maxID);
	link.nextEdgeID = linkNext.nextEdgeID;

	if (!isRedundant)
	{
		linkageBuffer.Store2(
			CBuffer_BufferRawEdgeLinkage_AddrAt(
				(pingpongFlag + 1) % 2, edgeId
			),
			PackEdgeMaxIdLinkRT(link)
		);
	}

	
#ifdef	TEST_SEED_DETECTION
	isRedundant = isRedundant || (foundSeed);
#endif

	
	return link;
}

// Link Data for connecting circular path into a list
struct EdgeLinkRT
{
	bool isSeed;
	uint nextEdgeID;
	uint rank;
};

uint EncodeEdgeRankingInfo(uint rank, bool isSeed)
{
	return (rank << 1 | isSeed);
}

#define DECODE_EDGE_LINK_1_RANK(rankInfo) (((rankInfo) >> 1))
#define DECODE_EDGE_LINK_1_SEED_FLAG(rankInfo) (((rankInfo) & 1))
void DecodeEdgeRankingInfo(uint rankInfo, out uint rank, out bool isSeed)
{
	rank = DECODE_EDGE_LINK_1_RANK(rankInfo);
	isSeed = DECODE_EDGE_LINK_1_SEED_FLAG(rankInfo);
}

uint2 EncodeEdgeLink(uint nextEdgeID, uint rank, bool isSeed)
{
	return uint2(EncodeEdgeRankingInfo(rank, isSeed), nextEdgeID);
}

#define GET_EDGE_LINK_1_RANK(linkData) (DECODE_EDGE_LINK_1_RANK(linkData.x))
#define GET_EDGE_LINK_1_SEED_FLAG(linkData) (DECODE_EDGE_LINK_1_SEED_FLAG(linkData.x))
#define GET_EDGE_LINK_1_NEXT(linkData) (linkData.y)

EdgeLinkRT ExtractEdgeLinkRT(uint2 linkData)
{
	EdgeLinkRT linkRT;
	linkRT.isSeed = GET_EDGE_LINK_1_SEED_FLAG(linkData);
	linkRT.nextEdgeID = GET_EDGE_LINK_1_NEXT(linkData);
	linkRT.rank = GET_EDGE_LINK_1_RANK(linkData);

	return linkRT;
}

uint2 PackEdgeLinkRT(EdgeLinkRT linkRT)
{
	uint2 linkData = EncodeEdgeLink(linkRT.nextEdgeID, linkRT.rank, linkRT.isSeed);
	return linkData;
}

EdgeLinkRT EdgePointerJumping_Dbg(
	uint edgeId, uint edgeCount,
	uint pingpongFlag,
	RWByteAddressBuffer linkageBuffer,
	inout bool isRedundant
)
{
	isRedundant = isRedundant || (edgeId >= edgeCount);

	EdgeLinkRT link =
		ExtractEdgeLinkRT(
			linkageBuffer.Load2(
				CBuffer_BufferRawEdgeLinkage_AddrAt(
					pingpongFlag, edgeId
				)
			)
		);

	EdgeLinkRT linkNext =
		ExtractEdgeLinkRT(
			linkageBuffer.Load2(
				CBuffer_BufferRawEdgeLinkage_AddrAt(
					pingpongFlag, link.nextEdgeID
				)
			)
		);

	// Update link data
	link.rank =
		linkNext.isSeed ? link.rank : (linkNext.rank + link.rank);
	link.nextEdgeID =
		linkNext.isSeed ? link.nextEdgeID : linkNext.nextEdgeID;
	// link.isSeed = link.isSeed; // seed flag always stays the same

	if (!isRedundant)
	{
		linkageBuffer.Store2(
			CBuffer_BufferRawEdgeLinkage_AddrAt(
				(pingpongFlag + 1) % 2, edgeId
			),
			PackEdgeLinkRT(link)
		);
	}

	// Test optimization
	isRedundant = (isRedundant || (linkNext.isSeed && (!link.isSeed)));

	return link;
}

// After edge serialization, we don't need any original linkage info.
#define SERIALIZED_LINKAGE_BUFFER (ORIGINAL_STAMP_LINKAGE + 2)
// Serialized edges have linkage info designed as follows,
// for example, lets say we have a edge segment of length 6, started from a:
// seed	|	X											| Seed edge gets stored at first.
// Addr	|	a	a + 1	a + 2	a + 3	a + 4	a + 5	| Each boundary loop is stored linearly as a sub-array(segment_
// link	|	5	4		3		2		1		6		| Link data tells the distance to the end
uint CBuffer_BufferRawEdgeSerializedLinkage_AddrAt(bool lastFrame, uint id)
{
	uint subbuffOffset = (
		(MAX_STAMP_EDGE_COUNT << BITS_WORD_OFFSET)
		* ((_FrameCounter + lastFrame) % 2u)
	);
	return CBuffer_BufferRawEdgeLinkage_AddrAt(SERIALIZED_LINKAGE_BUFFER, 0)
		+ subbuffOffset
		+ (id << BITS_WORD_OFFSET);
}
uint CBuffer_BufferRawEdgeSerializedLinkage_AddrAt(uint id)
{
	return CBuffer_BufferRawEdgeSerializedLinkage_AddrAt(false, id);
}


uint EncodeEdgeSerializedLinkage(uint isTail, uint rank, uint listSize)
{
	uint link = isTail ? listSize : (rank - 1);
	return (link << 1) | (1 & isTail);
}

// Covers minimum knowledge of edge's position in its edge-loop
struct SerializedEdgeLinkage
{
	uint linkVal; // address offset to the last elem(tail) of edge-loop
	uint tailFlag; // if this is edge-loop tail, linkval==edge-loop length
};

SerializedEdgeLinkage DecodeSerializedEdgeLinkage(uint linkData)
{
	SerializedEdgeLinkage res;
	res.linkVal = linkData >> 1;
	res.tailFlag = linkData & 1;

	return res;
}

/**
 * \brief Computes address offset to the last elem of segment
 * \param linkData linkage value
 * \return 
 */
uint OffsetToEdgeSegmentTail(uint linkData)
{
	SerializedEdgeLinkage linkage = DecodeSerializedEdgeLinkage(linkData);
	return linkage.tailFlag ? 0 : linkage.linkVal;
}

uint OffsetToEdgeSegmentTail(SerializedEdgeLinkage linkage)
{
	return linkage.tailFlag ? 0 : linkage.linkVal;
}

uint OffsetToEdgeSegmentHead(SerializedEdgeLinkage linkage, SerializedEdgeLinkage linkageTail)
{
	return linkageTail.linkVal - 1
		- (linkage.tailFlag ? 0 : linkage.linkVal);
}

// Covers full knowledge of edge-loop that current edge lies in
struct EdgeLoopTopology
{
	uint headEdgeId;
	uint tailEdgeId;
	uint length;
};
EdgeLoopTopology FetchEdgeLoopTopology(
	bool fromLastFrame, 
	ByteAddressBuffer CBuffer_BufferRawStampLinkage, uint EdgeId
){
	EdgeLoopTopology edgeloop;
	
	SerializedEdgeLinkage link = DecodeSerializedEdgeLinkage(
		CBuffer_BufferRawStampLinkage.Load(
			CBuffer_BufferRawEdgeSerializedLinkage_AddrAt(fromLastFrame, EdgeId)));
	edgeloop.tailEdgeId = EdgeId + OffsetToEdgeSegmentTail(link);

	SerializedEdgeLinkage tailLink = DecodeSerializedEdgeLinkage(
		CBuffer_BufferRawStampLinkage.Load(
			CBuffer_BufferRawEdgeSerializedLinkage_AddrAt(fromLastFrame, edgeloop.tailEdgeId)));
	edgeloop.headEdgeId = EdgeId - OffsetToEdgeSegmentHead(link, tailLink);
	edgeloop.length = tailLink.linkVal;

	return edgeloop;
}


uint MoveElemIdAlongLoop(uint elemId, int offset, uint loopHeadElemId, uint loopLen)
{
	bool moveLeft = offset < 0;

	uint d = abs(offset);
	d = d % loopLen;

	elemId -= loopHeadElemId;
	elemId += (moveLeft ? (loopLen - d) : d);
	elemId = (elemId % loopLen);
	elemId += loopHeadElemId;

	return elemId;
}

uint MoveEdgeIdAlongEdgeLoop(EdgeLoopTopology edgeloop, uint startEdgeId, float offset)
{
	return MoveElemIdAlongLoop(
		startEdgeId, ((int)offset), 
		edgeloop.headEdgeId, edgeloop.length
	);
}

uint MoveEdgeIdToPathHead(
	EdgeLoopTopology edgeloop, 
	uint startEdgeId, uint startEdgePathRank
){
	return MoveEdgeIdAlongEdgeLoop(
		edgeloop, startEdgeId, 
		-((float)startEdgePathRank)
	);
}

uint MoveEdgeIdToPathTail(
	EdgeLoopTopology edgeloop, uint pathLen, 
	uint startEdgeId, uint startEdgePathRank
)
{
	return MoveEdgeIdAlongEdgeLoop(
		edgeloop, startEdgeId, 
		(float)(pathLen - 1 - startEdgePathRank)
	);
}

void IsPathBisectedByEdgeLoop(
	uint edgeId, uint pathRank, uint pathLen, 
	uint edgeloopHeadId, uint edgeloopTailId, 
	out bool bisectedPath_left,
	out bool bisectedPath_right
){
	// path split to both sides of the edgeloop,
	bisectedPath_left =
		(edgeloopHeadId + pathRank) > edgeId;
	bisectedPath_right =
		((edgeId - pathRank) + pathLen - 1) > edgeloopTailId;
}





// After edge serialization, we don't need any original linkage info.
// After denoising and slice edge-loop into strokes,
// a -------------------------> b	
// |							|	Original Edge-loop
// d <-------------------------	c
//
//	a' ------------------> b'....	
// 	.							.	Sliced Edge-loop
//	...	d' <--------------- c'...
// 
// we reuse 0 & 1th sub-buffer to store new linkage info. (doubled, each link needs uint2)
// linkage info is encoded the same way as in CBuffer_BufferRawEdgeSerializedLinkage.
// seed	|	X											| Seed edge gets stored at first.
// Addr	|	a	a + 1	a + 2	a + 3	a + 4	a + 5	| Each boundary loop is stored linearly as a sub-array(segment_
// link	|	5	4		3		2		1		6		| Link data tells the distance to the end
// uint CBuffer_BufferRawEdgeStrokeLinkage_AddrAt(uint id)
// {
// 	return CBuffer_BufferRawEdgeLinkage_AddrAt(PINGPONG_STAMP_LINKAGE_0, 0)
// 		+ (id << BITS_DWORD_OFFSET);
// } // Not needed, for now.


#endif /* CBUFFER_BUFFERRAWSTAMPLINKAGE_VIEW_INCLUDED */
