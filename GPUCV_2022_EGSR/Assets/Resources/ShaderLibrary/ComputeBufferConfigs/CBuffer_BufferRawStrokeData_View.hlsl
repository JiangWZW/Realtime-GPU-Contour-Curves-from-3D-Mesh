#ifndef BE8A6707_4049_4FFA_9330_E7BF20C4BA1A
#define BE8A6707_4049_4FFA_9330_E7BF20C4BA1A

#include "../ComputeAddressingDefs.hlsl"
#include "../CustomShaderInputs.hlsl"

#ifdef STAGE_RECONN_STROKES
//                      Junction Table
/////////////////////////////////////////////////////////////// 
#define BITS_JUNCTION_LINK_OFFSET (BITS_BLOCK_OFFSET)
//  Data Layout
//  +===== uint StampID ====+=========
//  |   Junction StampID    | .......
//  +- - - uint4 Links - - -+         
//  |   .x: StampID #0      |
//  |   .y: StampID #1      | .......
//  |   .z: StampID #2      |
//  |   .w: StampID #3      |
//  +=======================+=========
//              *Links*
// | 3 | 0 | 0 | Note: for each junction,
// | 3 | P | 1 | it's true that ONLY 1 of 2
// | 2 | 2 | 1 | consecutive stamps can be a skeleton
// RenderDoc Shortcut:
// uint junctionStampID;
// uint StampID_0;
// uint StampID_1;
// uint StampID_2;
// uint StampID_3;
// ---------------------------------------------------
#define JUNCTION_TABLE_BUFFER (0)
#define JUNCTION_TABLE_STRIDE (5 << BITS_WORD_OFFSET)
#define JUNCTION_TABLE_LENGTH (MAX_JUNCTION_COUNT * JUNCTION_TABLE_STRIDE)

uint CBuffer_StrokeData_JunctionTable_JunctionPtr_AddrAt(uint id)
{
	return id * JUNCTION_TABLE_STRIDE;
}

uint CBuffer_StrokeData_JunctionTable_JunctionEnd_AddrAt(uint junctionId, uint offset)
{
	uint dataStart = CBuffer_StrokeData_JunctionTable_JunctionPtr_AddrAt(junctionId);
	return (dataStart + ((1 + offset) << BITS_WORD_OFFSET));
}

#define JUNCTION_COUNTER (CBuffer_ScanCounter(0))

#define JUNCTION_TABLE_INVALID_STAMPID (0xffffffff)







//                      Trail Table
///////////////////////////////////////////////////////////////
// RenderDoc Shortcut:
// uint header;
// uint4x4 d0;
// uint4x4 d1;
// uint4x4 d2;
// uint4x4 d3;
#define TRAIL_TABLE_BUFFER (JUNCTION_TABLE_BUFFER + JUNCTION_TABLE_LENGTH)
// TRAIL LAYOUT
// -------------------------------------------------------
// Whole trail table is divided into consecutive trails, 
// one for each junction-end;
// Each "trail" has x16 stamp-data chunks(uint4), 
// with one additional header at front;
// |<---------- Trail #i ------------>|
// TrailHead, chunk#0__________chink#15

// CHUNK LAYOUT
// ----------------------------------------------------------
// Each chunk caches attributes of a stamp SAMPLE,
// which has lees than 16 ranks distance from a junction-end, 
// (with junction end itself, which has rank of 0)
// sorted by its rank;
// +===== uint4 chunk ======+
// --- .x: stampCoord       |
// --- .y: asuint(depth)    |
// --- .zw: asuint(tangent) |
// +========================+

// uint : header info
#define TRAIL_HEAD_STRIDE (1 << BITS_WORD_OFFSET)
// uint4: sample data chunk
#define STAMP_STRIDE (4 << BITS_WORD_OFFSET)

#define TRAIL_STRIDE (1 * TRAIL_HEAD_STRIDE + NUM_STAMPS_PER_TRAIL * STAMP_STRIDE)

#define TRAIL_TABLE_LENGTH (TRAIL_STRIDE * MAX_TRAIL_COUNT)

#define TrailCounter (CBuffer_ScanCounter(1))

uint CBuffer_StrokeData_TrailHeader_AddrAt(uint trailId)
{
	return (TRAIL_TABLE_BUFFER + // Sub-Buffer offset
		trailId * TRAIL_STRIDE); // Offset of trail segment 
}

uint CBuffer_StrokeData_TrailSample_AddrAt(uint trailId, uint stampRank)
{
	return (TRAIL_TABLE_BUFFER + // Sub-Buffer offset
		trailId * TRAIL_STRIDE + // Offset of trail segment 
		TRAIL_HEAD_STRIDE + // Skip header data
		stampRank * STAMP_STRIDE // Offset of stamp data chunk
	);
}

uint4 EncodeTrailSampleData(uint stampCoord, float depth, float2 tangent)
{
	return uint4(
		stampCoord,
		asuint(depth),
		asuint(tangent.xy)
	);
}

#define TRAIL_TABLE_NULL_STAMP 0xffffffff


struct StampDataChunkRT
{
	float2 coord;
	float depth;
	float2 tangent;
};


StampDataChunkRT ExtractStampDataChunkRT(uint4 dataRaw, out bool validData)
{
	StampDataChunkRT res;
	res.coord = (float2)DecodePixelCoord(dataRaw.x);
	res.depth = asfloat(dataRaw.y);
	res.tangent = asfloat(dataRaw.zw);

	validData = (dataRaw.x != TRAIL_TABLE_NULL_STAMP);

	return res;
}






// Weighted Lest Square Parameters
// ------------------------------------------------------------------
// [0] = Sum{ w^2 * arcLen^2 }
// [1] = Sum{ w^2 * arcLen^3 }
// [2] = Sum{ w^2 * arcLen^4 }
// [3] = Sum{ w^2 * arcLen^1 * (x_i - x_junction) }
// [4] = Sum{ w^2 * arcLen^2 * (x_i - x_junction) }
// [5] = Sum{ w^2 * arcLen^1 * (y_i - y_junction) }
// [6] = Sum{ w^2 * arcLen^2 * (y_i - y_junction) }
// [7] = Sum{ w^2 * arcLen^1 * (z_i - z_junction) }
// [8] = Sum{ w^2 * arcLen^2 * (z_i - z_junction) }
// RenderDoc Shortcut
// float4 d0;
// float4 d1;
// float d2;
#define WLS_PARAMS_BUFFER (TRAIL_TABLE_BUFFER + TRAIL_TABLE_LENGTH)

#define NUM_PARAMS_PER_TRAIL 10
#define PARAM_UNIT_STRIDE (1 << BITS_WORD_OFFSET)
#define PARAM_CHUNK_STRIDE (NUM_PARAMS_PER_TRAIL * PARAM_UNIT_STRIDE)

#define WLS_PARAMS_BUFFER_LENGTH (MAX_TRAIL_COUNT * PARAM_CHUNK_STRIDE)

uint CBuffer_StrokeData_WLSParams_AddrAt(uint trailId, uint paramId)
{
	return (
		WLS_PARAMS_BUFFER + // Sub-buffer Offset
		trailId * PARAM_CHUNK_STRIDE + // Trail offset(per chunk)
		paramId * PARAM_UNIT_STRIDE // Parameter offset(per word)
	);
}

#endif /* STAGE_RECONN_STROKES */


#endif /* BE8A6707_4049_4FFA_9330_E7BF20C4BA1A */
