#ifndef CBUFFER_BUFFERRAWFLAGSPERSTAMP_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWFLAGSPERSTAMP_VIEW_INCLUDED

#include "../ComputeAddressingDefs.hlsl"
#include "../ImageProcessing.hlsl"
#include "../CustomShaderInputs.hlsl"

#define BITS_OFFSET_STAMP_FLAG BITS_WORD_OFFSET
#define STAMP_FLAGS_BUFFER 0u
#define STAMP_FLAGS_LENGTH ((MAX_STAMP_COUNT << BITS_WORD_OFFSET))

uint CBuffer_BufferRaw_FlagsPerStamp_AddrAt(uint offset)
{
    return STAMP_FLAGS_BUFFER + ((offset) << BITS_OFFSET_STAMP_FLAG);
}


//! Bit layout for per-stamp-flag
// |0_____________23_24__25__29___30|31|     
// |      24        | 1 | 4 | 1 | 1 | 1|
// |  Best Edge Id  | CF| TF|STK|SDF| ?|
#define BIT_BEG_STAMP_EDGE_ID 0u
#define BIT_LEN_STAMP_EDGE_ID 24u
// 
#define BIT_BEG_STAMP_CONTOUR (BIT_BEG_STAMP_EDGE_ID + BIT_LEN_STAMP_EDGE_ID)
#define BIT_LEN_STAMP_CONTOUR 1u
//
#define BIT_BEG_STAMP_TOPO (BIT_BEG_STAMP_CONTOUR + BIT_LEN_STAMP_CONTOUR)
#define BIT_LEN_STAMP_TOPO 4u
//
#define BIT_BEG_STAMP_STK (BIT_BEG_STAMP_TOPO + BIT_LEN_STAMP_TOPO)
#define BIT_LEN_STAMP_STK 1u
//
#define BIT_BEG_STAMP_SDF (BIT_BEG_STAMP_STK + BIT_LEN_STAMP_STK)
#define BIT_LEN_STAMP_SDF 1u

void SetStampFlags_Internal(
    uint attrVal, uint attrBitBeg, uint attrBitLen, inout uint stampFlags)
{
    stampFlags &= (GEN_BIT_CLEAR_MASK(attrBitBeg, attrBitLen));
    stampFlags |= (attrVal << attrBitBeg);
}
#define SetStampFlag(tag, attr_val, stampFlags) \
	SetStampFlags_Internal(attr_val, CAT(BIT_BEG_, tag), CAT(BIT_LEN_, tag), stampFlags) \

uint GetStampFlags_Internal(uint attrBitBeg, uint attrBitLen, uint stampFlags)
{
    return EXTRACT_BITS(stampFlags, attrBitBeg, attrBitLen);
}
#define GetStampFlag(tag, stampFlags) \
	GetStampFlags_Internal(CAT(BIT_BEG_, tag), CAT(BIT_LEN_, tag), stampFlags) \


uint EncodeStampFlag(
	bool contourStamp,
	uint topologyId,
	uint strokeFlag = 0
)
{
    uint res = 0;
    SetStampFlag(STAMP_CONTOUR, contourStamp, res);
    SetStampFlag(STAMP_TOPO,    topologyId, res);
    SetStampFlag(STAMP_STK,     strokeFlag, res);

    return res;
}


float2 StampFlag_GetSplatOffset(uint stampSplatID)
{
    return -1.0f * splatOffset[stampSplatID];
}



#define BITS_OFFSET_STAMP_PTCL_COVERAGE ((BITS_WORD_OFFSET))
#define STAMP_PTCL_COVERAGE_BUFFER ((STAMP_FLAGS_BUFFER + STAMP_FLAGS_LENGTH))
#define STAMP_PTCL_COVERAGE_LENGTH ((MAX_STAMP_COUNT << BITS_WORD_OFFSET))
uint CBuffer_BufferRaw_StampCoverageByParticle_AddrAt(uint stampId)
{
    return STAMP_PTCL_COVERAGE_BUFFER + 
        ((stampId) << BITS_OFFSET_STAMP_PTCL_COVERAGE);
}























// ===========================================================================
// Deprecated
// ===========================================================================

#define TOPOTYPE_JUNCTION_END 6
#define IS_JUNCTION_END_PIXEL(topo) (((topo) == TOPOTYPE_JUNCTION_END))


uint StampFlag_SetTopo(uint flag, uint newTopo)
{
    return (flag & 0xfffffff1) | (newTopo << 1);
}



// (4-11) 3x3 Neighbor Code: encodes binary values of 3x3 neighbors ==========
uint StampFlag_BoxCode(uint flag)
{
    return ((flag >> 4) & 0x000000ff);
}


// (12) Degenerate Stamp Flag: ===================================================
#define BIT_BEG_STAMP_DEGEN_FLAG (12)
#define BIT_LEN_STAMP_DEGEN_FLAG (1)


// (12-?) Curve Handle Id: ===================================================
// this tells the allocated index for a stamp of type
// "junction-end"(Stroke-ID) or "junction"(Junction-ID)
// temporarily occupies free bits.
#define FREE_BITS_CLEAR_MASK 0x00000fff // Keep low 12 bits
#define CLEAR_FREE_BITS(flag) (((flag) & FREE_BITS_CLEAR_MASK))
uint StampFlag_SetStrokeHandleID(uint flag, uint handle)
{
    return ((CLEAR_FREE_BITS(flag)) | (handle << 12));
}

uint StampFlag_GetStrokeHandleID(uint flag)
{
    return (flag >> 12);
}

uint StampFlag_SetJunctionHandleID(uint flag, uint handle)
{
    return ((CLEAR_FREE_BITS(flag)) | (handle << 12));
}

uint StampFlag_GetJunctionHandleID(uint flag)
{
    return (flag >> 12);
}
// ===========================================================================



// (12-?) Neighbor Id: =======================================================
// This is only valid for non-singular(junction, line-end) stamps,
// which tells the relative position of 2 adjacent stamps Link0 and Link1:
// 3x3-neighbor-code format:
// | 7 | 0 | 1 | total X8 possible positions(0~7);
// | 6 | P | 2 | so each adjacent pixel(stamp) will take X3 bits to-
// | 5 | 4 | 3 | -store its position relative to current stamp 'P' at center
// Link0 will be stored at low 3 bits
// Link1 will be stored at high 3 bits
// --- (for linkage info, see StampLinkingComputeDefs.hlsl)
uint StampFlag_SetNeighborCodePosIDs(uint flag, uint neighPosIDs)
{
    return ((CLEAR_FREE_BITS(flag)) | (neighPosIDs << 12));
}

uint2 StampFlag_GetNeighborCodePosIDs(uint flag)
{
    uint neighborCodePosIDsRaw = (flag >> 12);
    uint2 neighborCodePosIDs = uint2(
		(neighborCodePosIDsRaw >> 3) & 0x00000007,
		neighborCodePosIDsRaw & 0x00000007
	);
    return neighborCodePosIDs;
}
// ===========================================================================


#endif /* CBUFFER_BUFFERRAWFLAGSPERSTAMP_VIEW_INCLUDED */
