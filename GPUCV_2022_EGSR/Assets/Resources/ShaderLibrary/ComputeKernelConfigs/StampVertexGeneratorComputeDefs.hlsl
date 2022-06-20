#ifndef D1377014_0EC1_4558_A29D_1399432EF0F2
#define D1377014_0EC1_4558_A29D_1399432EF0F2

#include "../BrushToolBox.hlsl"
#include "../CustomShaderInputs.hlsl"

#include "../ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerStamp_View.hlsl"



// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"


//== Utility functions ========================
#define CLAMP_K 1.645f
float HuberClamping(float clampK, float x)
{
	return abs(x) < clampK ? x : sign(x) * clampK;
}

#define CLAMP_FORE_K 0.001f
#define CLAMP_FORE_CK 2.52f
float ForecastLoss(float x)
{
	x /= CLAMP_FORE_K;
	x = 1.0f - x * x;
	x = 1.0f - x * x * x;
	return CLAMP_FORE_CK * (abs(x) < CLAMP_FORE_K ? x : 1.0f);
}


float ForecastError(float errPrev, float residual, float factor)
{
	return sqrt(
		errPrev * errPrev
		* lerp(1.0f, ForecastLoss(residual / errPrev), factor)
	);
}

void ExtremaIdentification(inout float4 v)
{
	v.xy = v.x < v.y ? v.xy : v.yx;
	v.zw = v.z < v.w ? v.zw : v.wz;
	v.xz = v.x < v.z ? v.xz : v.zx;
	v.yw = v.y < v.w ? v.yw : v.wy;
}

void ShiftVectorAndFillNew(inout float4 v, float newVal) {
	v.xyz = v.yzw;
	v.w = newVal;
}

float smoothing_factor(float t_e, float cutoff)
{
	float r = 2.0f * PI * cutoff * t_e;
	return r / (r + 1.0f);
}
	

float exponential_smoothing(float a, float x, float x_prev)
{
	return lerp(x_prev, x, a);
}

#define min_cutoff 0.0002f
#define beta 0.001f
#define d_cutoff 0.001f
float OneEuroFilter(float t_e, float x, float x_prev, float dx_prev)
{
// #define DBG_EMA_FILTER
	// The filtered derivative of the signal.
	float a_d = smoothing_factor(t_e, d_cutoff);
	float dx = (x - x_prev) / t_e;
	float dx_hat = exponential_smoothing(a_d, dx, dx_prev);

	// The filtered signal.
	float cutoff = min_cutoff + beta * abs(dx_hat);
	float a = smoothing_factor(t_e, cutoff);
	float x_hat = exponential_smoothing(a, x, x_prev);

	x_prev = x_hat;
	dx_prev = dx_hat;
	
	return x_hat;
}



float StrokeScaleTemporalFilter(
	bool rebootFilter,
	float step,
	float scaleNormalizedCurr,
	float scaleNormalizedPrev,
	float deltaScalePrev
)
{
	if (rebootFilter)
	{
		return lerp(scaleNormalizedCurr, scaleNormalizedPrev, .2f);
	}
	return lerp(scaleNormalizedCurr, scaleNormalizedPrev, .9f);
	OneEuroFilter(
		1.0f,
		// exp2((float)(motionVecLen) / 2.0f),
		scaleNormalizedCurr,
		scaleNormalizedPrev,
		deltaScalePrev
	);
}


float StrokeParameterTemporalFilter(
	bool rebootFilter,
	float paramCurr, float paramPrev
){
	if (rebootFilter)
	{
		paramCurr = lerp(paramCurr, paramPrev, .3f);
	}
	else
	{
		paramCurr = lerp(paramCurr, paramPrev, .9f);
	}
	
	return paramCurr;
}

float2 StampTangentTemporalFilter(
	bool rebootFilter,
	float2 coarseTangent, float2 pedgeTangent, float2 historyTangent,
	bool stampDegenerated, bool stampParametrized)
{
	if (rebootFilter)
	{
		return coarseTangent;
	}
	float tdth = dot(historyTangent, coarseTangent);
	float tdte = dot(pedgeTangent, coarseTangent);

	float2 estimatedTangent =
		(tdte < 0 ? -coarseTangent : coarseTangent);
	float interpFactor = .5 * abs(tdth) * abs(tdth);
	
	if (stampDegenerated)
	{
		estimatedTangent =
			(tdte < 0 ? coarseTangent : -coarseTangent);
	}
	if (!(stampParametrized))
	{
		estimatedTangent = coarseTangent;
		abs(tdth) < .1f ? coarseTangent :
			(tdth < 0 ? -coarseTangent : coarseTangent);
	}

	return normalize(
		slerp(
			coarseTangent,
			slerp(
				historyTangent,
				estimatedTangent,
				.5
			),
			.5f
		)
	);
}

uint EncodeEdgeToStampRPJSampleID(uint edgeOnStroke, uint sampleID)
{
	return ((sampleID << 1) | (edgeOnStroke & 1));
}
uint DecodeEdgeToStampRPJSampleID(uint raw, out uint edgeOnStroke)
{
	edgeOnStroke = (raw & 1);
	uint sampleID = (raw >> 1);
	
	return sampleID;
}


uint EncodeSplatToCenterRPJSampleID(
	uint validSample, uint sampleOnStroke, uint sampleID)
{
	if (!validSample)
	{
		sampleID = 0;
	}
	uint flag = ((validSample << 1) | sampleOnStroke);
	return ((sampleID & 0x00ffffff) | (flag << 24));
}
uint DecodeSplatToCenterRPJSampleID(
	uint raw, out uint validSample, out uint sampleOnStroke)
{
	uint flag = ((raw >> 24));
	validSample = ((flag >> 1) & 1);
	sampleOnStroke = (flag & 1);

	uint sampleID = (raw & 0x00ffffff);

	return sampleID;
}


float Impulse(float segrank, float seglen, float edgeThres, float edgeRatio)
{
	edgeThres = min(seglen * edgeRatio, edgeThres);
	return (segrank < edgeThres) ?
		.9 * smoothstep(0, edgeThres, segrank) + .1
		: ((segrank < seglen - edgeThres) ?
			1.0f : (1.0f - .9 * smoothstep(seglen - edgeThres, seglen, segrank)));
}

float ComputeHistoryStability(
	bool onStroke, bool edgeLoop,
	float segRank, float segLength)
{
	float scoreInternal =
		(onStroke ? 1.0f : -1.0f) *
		clamp(((float)segLength) / 32.0f, .0f, 1.0f);
	float strokeDecay =
		edgeLoop
			? 1.0f
			: Impulse(
				segRank, segLength,
				32.0f, .1f);
	
	return (scoreInternal * strokeDecay);
}


#define GROUP_SIZE_0 256
#define BITS_GROUP_SIZE_0 8



groupshared uint LDS_PrevGroupSum = 0;
groupshared uint LDS_PrevGroupSum1 = 0;

// =======================================================
#define SCAN_FUNCTION_TAG Compaction_1

#define SCAN_DATA_TYPE uint
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE 0u
// #define SCAN_DATA_VECTOR_STRIDE 2
#define SCAN_BLOCK_SIZE GROUP_SIZE_0

#define TG_COUNTER CBuffer_HistorySampleCounter(1)
#define TGSM_COUNTER LDS_PrevGroupSum

#include "../StreamCompactionCodeGen.hlsl"
// =======================================================
// =======================================================
#define SCAN_FUNCTION_TAG Compaction_2

#define SCAN_DATA_TYPE uint
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE 0u
// #define SCAN_DATA_VECTOR_STRIDE 2
#define SCAN_BLOCK_SIZE GROUP_SIZE_0

#define TG_COUNTER CBuffer_StampDrawCallCounter
#define TGSM_COUNTER LDS_PrevGroupSum1

#include "../StreamCompactionCodeGen.hlsl"
// =======================================================


#endif /* D1377014_0EC1_4558_A29D_1399432EF0F2 */
