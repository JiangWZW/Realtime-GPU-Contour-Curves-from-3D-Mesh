#ifndef CBuffer_BufferRawStampGBuffer_VIEW_INCLUDED
#define CBuffer_BufferRawStampGBuffer_VIEW_INCLUDED

#include "../ComputeAddressingDefs.hlsl"
#include "../CustomShaderInputs.hlsl"

//						INTERLEAVED GBUFFER FOR STAMPS
//////////////////////////////////////////////////////////////////////////////
// tangent.xy
#define BITS_OFFSET_STAMP_TANGENT BITS_WORD_OFFSET

#define STAMP_TANGENT_BUFFER 0
#define STAMP_TANGENT_STRIDE ((1 << BITS_OFFSET_STAMP_TANGENT))
#define STAMP_TANGENT_LENGTH (MAX_STAMP_COUNT * STAMP_TANGENT_STRIDE)

#define CBuffer_BufferRawStampVectorInfo_AddrAt(id) (id << BITS_OFFSET_STAMP_TANGENT)
float2 GET_STAMP_GBUFFER_TANGENT(uint data) {
	return (UnpackUnitVector_2D_FromFp(asfloat(data)));
}

#define BITS_OFFSET_STAMP_MOVEC BITS_DWORD_OFFSET
#define STAMP_MOVEC_BUFFER (STAMP_TANGENT_BUFFER + STAMP_TANGENT_LENGTH)
#define STAMP_MOVEC_STRIDE ((1 << BITS_OFFSET_STAMP_MOVEC))
#define STAMP_MOVEC_LENGTH (MAX_STAMP_COUNT * STAMP_MOVEC_STRIDE)
uint CBuffer_BufferRawStampMotionVector_AddrAt(uint stampId)
{
	return (STAMP_MOVEC_BUFFER + (stampId << BITS_OFFSET_STAMP_MOVEC));
}


// .x: screen depth gradient
// .y: view space z (always negative for visible samples)
#define BITS_OFFSET_VIEW_DEPTH BITS_WORD_OFFSET

#define STAMP_VIEW_DEPTH_BUFFER (STAMP_MOVEC_BUFFER + STAMP_MOVEC_LENGTH)
#define STAMP_VIEW_DEPTH_STRIDE ((1 << BITS_OFFSET_VIEW_DEPTH))
#define STAMP_VIEW_DEPTH_LENGTH (MAX_STAMP_COUNT * STAMP_VIEW_DEPTH_STRIDE)

uint CBuffer_BufferRaw_StampViewDepth_AddrAt(uint stampId)
{
	return STAMP_VIEW_DEPTH_BUFFER +
		(stampId << BITS_OFFSET_VIEW_DEPTH);
}


// .x: screen depth gradient
// .y: view space z (always negative for visible samples)
#define BITS_OFFSET_DEPTH_GRAD BITS_WORD_OFFSET

#define STAMP_DEPTH_GRAD_BUFFER (STAMP_VIEW_DEPTH_BUFFER + STAMP_VIEW_DEPTH_LENGTH)
#define STAMP_DEPTH_GRAD_STRIDE ((1 << BITS_OFFSET_DEPTH_GRAD))
#define STAMP_DEPTH_GRAD_LENGTH (MAX_STAMP_COUNT * BITS_OFFSET_DEPTH_GRAD)

uint CBuffer_BufferRawStamp_ScreenDepthGrad_AddrAt(uint stampId)
{
	return STAMP_DEPTH_GRAD_BUFFER +
		(stampId << BITS_OFFSET_DEPTH_GRAD);
}










	







// JFA data (!!! Deprecated !!!)
#define OFFSET_BUFFER_RAW_STAMP_JFA_DATA 

#define BITS_OFFSET_BUFFER_RAW_STAMP_JFA_DATA BITS_WORD_OFFSET
#define CBuffer_BufferRawStampJFABuffer_AddrAt(id) (              \
		CBuffer_BufferRawStampZBuffer_AddrAt(0) + \
        (MAX_STAMP_COUNT << BITS_OFFSET_DEPTH_INFO) + \
        (id << BITS_OFFSET_BUFFER_RAW_STAMP_JFA_DATA))

#endif /* CBuffer_BufferRawStampGBuffer_VIEW_INCLUDED */
