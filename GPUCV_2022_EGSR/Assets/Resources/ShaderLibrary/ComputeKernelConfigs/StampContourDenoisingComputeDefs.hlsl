#ifndef E7287B3D_02C1_4575_A34C_CC711C06D23F
#define E7287B3D_02C1_4575_A34C_CC711C06D23F


#include "../TreeScanPrimitives.hlsl"

#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerSeg_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"


// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"


#define SEGMENTATION_MAX_SCAN_VAL 67108864u
#define SEGMENTATION_MIN_SCAN_VAL 0u
uint F32_TO_U32(float f32) { return ((uint)((f32)+.1f)); }

void FormNewStrokes(
	uint EdgeId,
	float headEdgeIdOld,
	float tailEdgeIdOld,
	float edgeLoopLen,
	float newHeadOfOldTail,
	float newTailOfOldHead,
	inout float headEdgeIdNew,
	inout float tailEdgeIdNew,
	inout uint segLength,
	inout uint rank,
	out bool wholeEdgeLoopVisible)
{
	bool headEdgeIdUnderflow = round(headEdgeIdNew) < round(headEdgeIdOld);
	bool tailEdgeIdOverflow = (uint)tailEdgeIdOld < (uint)tailEdgeIdNew;
	uint edgeLoopLenU32 = F32_TO_U32(edgeLoopLen);
	
	wholeEdgeLoopVisible =
		(headEdgeIdUnderflow && tailEdgeIdOverflow);

	if (wholeEdgeLoopVisible)
	{
		// Whole edge-loop survived, no segmentation:
		headEdgeIdNew = headEdgeIdOld;
		tailEdgeIdNew = tailEdgeIdOld;
		segLength = edgeLoopLenU32;
	}
	else
	{
		// Edge-loop is sliced into drawable/deleted parts:
		// 
		// If over/down-flow happened, we should jump back/ahead to
		// segment head/tail for valid new segment ids
		headEdgeIdNew = headEdgeIdUnderflow
			? newHeadOfOldTail
			: headEdgeIdNew;
		tailEdgeIdNew = tailEdgeIdOverflow
			? newTailOfOldHead
			: tailEdgeIdNew;
		segLength = // Flaw of this method: when segLength == edgeLoopLen, returns 0
			((uint)(tailEdgeIdNew - headEdgeIdNew + 1.0 + edgeLoopLen + .1f))
			% edgeLoopLenU32;
		if (segLength == 0)
		{
			segLength = edgeLoopLenU32;
			wholeEdgeLoopVisible = true;
		}
	}

	rank = (uint)(((float)EdgeId) - headEdgeIdNew + edgeLoopLen + .1f)
		% edgeLoopLenU32;
}

// ------------------------------------------------
// Whether this edge is good enough to be displayed
float Impulse(float segrank, float seglen, float edgeThres, float edgeRatio)
{
	edgeThres = min(seglen * edgeRatio, edgeThres);
	return (segrank < edgeThres) ? 
			.9 * smoothstep(0, edgeThres, segrank) + .1
		       : ((segrank < seglen - edgeThres) ? 
				   1.0f : (1.0f - .9 * smoothstep(seglen - edgeThres, seglen, segrank)));
}


#define MIN_STROKE_LEN 32

#define GROUP_SIZE_0 256
#define BITS_GROUP_0 8

#define GROUP_SIZE_NEXT 256
#define BITS_GROUP_NEXT 8

#endif /* E7287B3D_02C1_4575_A34C_CC711C06D23F */
