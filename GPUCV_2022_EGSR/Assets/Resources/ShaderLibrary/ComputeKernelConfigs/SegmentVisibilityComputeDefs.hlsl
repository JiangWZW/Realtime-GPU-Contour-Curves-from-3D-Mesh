#ifndef SEGMENTVISIBILITYCOMPUTEDEFS_INCLUDED
#define SEGMENTVISIBILITYCOMPUTEDEFS_INCLUDED

// LinearEyeDepth
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl" 

#include "../CustomShaderInputs.hlsl"
#include "../ImageProcessing.hlsl"

// Mesh Buffers(Raw)
// Raw Buffers - Per Edge Granularity
// Raw Buffers - Per Contour Granularity
#include "../ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerContour_View.hlsl"
// Raw Buffers - Per Segment Granularity
#include "../ComputeBufferConfigs/CBuffer_BufferRawSegmentsToContour_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawContourToSegment_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerSegment_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerSeg_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawVisibleSegToSeg_View.hlsl"


#include "../TextureConfigs/Texture2D_ContourGBufferTex_View.hlsl"


// Arg Buffers 
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"

#define USE_LOOK_BACK_TABLE_KERNEL_SEGMENTVISIBILITY_DEPTHTEST
#include "../ComputeBufferConfigs/CBuffer_BufferRawLookBacks1_View.hlsl"
#undef  USE_LOOK_BACK_TABLE_KERNEL_SEGMENTVISIBILITY_DEPTHTEST

#include "../ComputeBufferConfigs/CBuffer_BufferRawLookBacks_View.hlsl"

// Make sure this matches GROUP_SIZE_NEXT in SegmentSetupComputeDefs.hlsl
#define GROUP_SIZE_0 1024
#define BITS_GROUP_SIZE_0 10

// Make sure this matches GROUP_SIZE_0 in 
// ViewEdgeExtractionComputeDefs.hlsl and ContourPixelExtractionComputeDefs.hlsl
#define GROUP_SIZE_NEXT 256
#define BITS_GROUP_SIZE_NEXT 8

// Values used to linearize the Z buffer (http://www.humus.name/temp/Linearize%20depth.txt)
// x = 1-far/near
// y = far/near
// z = x/far
// w = y/far
// or in case of a reversed depth buffer (UNITY_REVERSED_Z is 1)
// x = -1+far/near
// y = 1
// z = x/far
// w = 1/far
// float4 _ZBufferParams; // this is needed to compile functions

float EdgeFunc2D(float2 v0, float2 v1, float2 p)
{
	// --------------------------------------------------------------
	// Let edge e with 2 verts(v0, v1),
	// and v0->v1 has clockwise winding order in screen;
	// (By default, DX11 assigns verts in triangle in clockwise order)
	// ---------------------------------------------------------------
	// Then we can define edge function:
	// F_0_1(P) = (x1 - x0)(yp - y0) - (y1 - y0)(xp - x0)
	float2 v0v1 = v1 - v0;
	float2 v0p = p - v0;
	return (v0v1.x * v0p.y - v0v1.y * v0p.x);
}

bool IsFragBelongToTriangle(
	float2 frag, // fragment to test 
	// start & end point on triangle edge, follow CW order
	float2 v0, float2 v1,
	bool isTopLeftEdge // top / left edge?
)
{
	// outside edge: 0
	// on edge: 1
	// inside edge: 2
	uint insideEdge = (uint)(1 + sign(EdgeFunc2D(v0, v1, frag)));

	uint rasterFlag = insideEdge + (uint)(isTopLeftEdge);
	return (2 <= rasterFlag);
}

float2 ComputeDualOffset(
	float2 frag, float2 v0, float2 v1,
	bool isTopLeftEdge, bool isXMajor
)
{
	float2 stepInDualAxis = isXMajor ? float2(0, -1) : float2(-1, 0);
	bool isCenterOut = !IsFragBelongToTriangle(frag, v0, v1, isTopLeftEdge);
	bool isBottomOut = !IsFragBelongToTriangle(frag + stepInDualAxis, v0, v1, isTopLeftEdge);
	float offset = isBottomOut ? -1 : 1;
	offset = isCenterOut ? 0 : offset;

	return isXMajor ? float2(0, offset) : float2(offset, 0);
}

float2 ComputeFragmentPosSS(
	float4 edgeBegEnd,
	uint headSegId,
	uint currSegId,
	bool isXMajor,
	out float linearFactor,
	out float linearStep
)
{
	// edgeBegEnd.x = floor(edgeBegEnd.x);
	// edgeBegEnd.z = ceil(edgeBegEnd.z);
	// Flip xy/zw to yx/wz if edge is y-major,
	// so that we always have 'major' axis coord in first slot
	edgeBegEnd = isXMajor ? edgeBegEnd.xyzw : edgeBegEnd.yxwz;
	float majorAxisBegPos = floor(edgeBegEnd.x);
	float majorAxisOffset = (float)(currSegId - headSegId) + 0.5;

	float2 targTexel; // .x: Major axis, .y: Dual axis
	targTexel.x = majorAxisBegPos + majorAxisOffset;
	linearStep = 1.0 / (edgeBegEnd.z - edgeBegEnd.x);
	linearFactor = saturate((targTexel.x - edgeBegEnd.x) * linearStep);
	targTexel.y = lerp(edgeBegEnd.y, edgeBegEnd.w, linearFactor);

	
	targTexel = isXMajor ? targTexel.xy : targTexel.yx; // Flip to actual coord

	linearStep =
		abs(edgeBegEnd.w - edgeBegEnd.y) / 
		(ceil(edgeBegEnd.z) - floor(edgeBegEnd.x));
	
	return targTexel;
}

float2 ComputeSSDzDxy(float3x3 samples)
{
	// Sobel
	// _11 _12 _13   1  2  1  -1  0  1
	// _21 _22 _23   0  0  0  -2  0  2
	// _31 _32 _33  -1 -2 -1  -1  0  1
	float2 dzdxy = float2(
		dot((samples._13_23_33 - samples._11_21_31), float3(1, 2, 1)),
		dot((samples._11_12_13 - samples._31_32_33), float3(1, 2, 1))
	);
	return (dzdxy) * 0.25f; // /4 to normalize
}

float InterpolateEyeDepth(
	double2 wHClip, double linearFactor
)
{
	// Note: --------------------------------------------
	// Following commented code returns perspect-correct
	// depth, using that fact that 1/Depth_view is linear
	// in NDC space;
	// return rcp(
	//         lerp(-1.0 / wHClip.x, 
	//              -1.0 / wHClip.y,
	//             linearFactor
	//         )
	//     );
	// Original formula above doesn't need -1.0,
	// and returns the "real" view space depth;
	//
	// But as we know, view space depth is negative
	// in frustum(camera looks at -z axis), so it's
	// a good choise to flip the sign; (-1.0 * ...)
	// Also this will help to match the value from 
	// LinearEyeDepth(depthSample.r, _ZBufferParms).
	return -1.0 / (
		lerp(-1.0 / wHClip.x, // w_hclip == -z_view =>
		     -1.0 / wHClip.y, // 1/z_view = -1/w_hclip
		     linearFactor
		)
	);
}


// From "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
// ----------------------------------------------------------------------------------
// .x = cameraWidth 
// .y = cameraHeight 
// .z = 1.0f + 1.0f / cameraWidth 
// .w = 1.0f + 1.0f / cameraHeight
// float4 _ScreenParams;
float _CustomDepthTextureScale;
Texture2D<float> _CustomDepthTexture;
SamplerState sampler_linear_clamp;
SamplerState sampler_point_clamp;


float EyeDepthSampleAt(float2 texel)
{
	return LinearEyeDepth(
		_CustomDepthTexture.SampleLevel(
			sampler_linear_clamp, // Sampler
			texel, // uv coord
			0 // LOD level
		),
		_ZBufferParams
	);
}

float EyeDepthLoadAt(uint2 texel)
{
	return LinearEyeDepth(
		_CustomDepthTexture.Load(
			int3(texel.xy, 0)
		),
		_ZBufferParams
	);
}

/**
 * \return 3x3 neighbor eye-depth samples 
 */
float3x3 DepthSample3x3Box(float2 texel, float2 resInv)
{
	float3x3 depthSample;
	texel *= resInv;
	// Top-Left
	depthSample._11 = EyeDepthSampleAt(texel + float2(-resInv.x, resInv.y));
	// Top-Center
	depthSample._12 = EyeDepthSampleAt(texel + float2(0, resInv.y));
	// Top-Right
	depthSample._13 = EyeDepthSampleAt(texel + float2(resInv.x, resInv.y));

	// Left
	depthSample._21 = EyeDepthSampleAt(texel + float2(-resInv.x, 0));
	// Center
	depthSample._22 = EyeDepthSampleAt(texel);
	// Right
	depthSample._23 = EyeDepthSampleAt(texel + float2(resInv.x, 0));

	// Bottom-Left
	depthSample._31 = EyeDepthSampleAt(texel + float2(-resInv.x, -resInv.y));
	// Bottom-Center
	depthSample._32 = EyeDepthSampleAt(texel + float2(0, -resInv.y));
	// Bottom-Right
	depthSample._33 = EyeDepthSampleAt(texel + float2(resInv.x, -resInv.y));

	return depthSample;
}

/**
 * \return 3x3 neighbor eye-depth samples
 */
float3x3 DepthLoad3x3Box(uint2 texel, float2 resInv)
{
	float3x3 depthSample;
	// Top-Left
	depthSample._11 = EyeDepthLoadAt(texel + uint2(-1, 1));
	// Top-Center
	depthSample._12 = EyeDepthLoadAt(texel + uint2(0, 1));
	// Top-Right
	depthSample._13 = EyeDepthLoadAt(texel + uint2(1, 1));

	// Left
	depthSample._21 = EyeDepthLoadAt(texel + uint2(-1, 0));
	// Center
	depthSample._22 = EyeDepthLoadAt(texel);
	// Right
	depthSample._23 = EyeDepthLoadAt(texel + uint2(1, 0));

	// Bottom-Left
	depthSample._31 = EyeDepthLoadAt(texel + uint2(-1, -1));
	// Bottom-Center
	depthSample._32 = EyeDepthLoadAt(texel + uint2(0, -1));
	// Bottom-Right
	depthSample._33 = EyeDepthLoadAt(texel + uint2(1, -1));

	return depthSample;
}

#define CROSS_CC _11
#define CROSS_T _12
#define CROSS_TT _13
#define CROSS_R _21
#define CROSS_RR _22
#define CROSS_B _23
#define CROSS_BB _31
#define CROSS_L _32
#define CROSS_LL _33

float3x3 DepthSample3x3Cross(Texture2D<float> depthTex, float2 texel, float2 resInv)
{
	float3x3 depthSample;
	texel *= resInv;

	depthSample.CROSS_CC = EyeDepthSampleAt(texel);

	depthSample.CROSS_T = EyeDepthSampleAt(texel + float2(0, resInv.y));
	depthSample.CROSS_TT = EyeDepthSampleAt(texel + float2(0, 2 * resInv.y));

	depthSample.CROSS_R = EyeDepthSampleAt(texel + float2(resInv.x, 0));
	depthSample.CROSS_RR = EyeDepthSampleAt(texel + float2(2 * resInv.x, 0));

	depthSample.CROSS_B = EyeDepthSampleAt(texel + float2(0, -resInv.y));
	depthSample.CROSS_BB = EyeDepthSampleAt(texel + float2(0, -2 * resInv.y));

	depthSample.CROSS_L = EyeDepthSampleAt(texel + float2(-resInv.x, 0));
	depthSample.CROSS_LL = EyeDepthSampleAt(texel + float2(-2 * resInv.x, 0));

	return depthSample;
}

float DepthTest(float3x3 depthSampleBox, float depthOffset, float segmentEyeDepth)
{
	depthSampleBox = (segmentEyeDepth <= (depthSampleBox + depthOffset));

	// Option #1
	// depthSampleBox = clamp(depthSampleBox - segmentEyeDepth, -1, 1);
	// depthSampleBox._11 += (depthSampleBox._22);
	depthSampleBox._12_22_32 += depthSampleBox._13_23_33;
	depthSampleBox._11_21_31 += depthSampleBox._12_22_32;
	depthSampleBox._11 += (depthSampleBox._21 + depthSampleBox._31);

	return depthSampleBox._11;
}

// Reprojection Utilities
// -------------------------------------------
static int2 conservativeRasterPatchOffsets[4] = {
	int2(-1, 0),
	int2(1, 0),
	int2(0, 1),
	int2(0, -1)
};

bool isValidHistorySample(float2 rpjSample)
{
	return any(rpjSample != 0);
}

bool historySampleDepthTest(float3x3 depthSampleBox, float historyDepth, float segmentEyeDepth)
{
	return 
		(DepthTest(depthSampleBox, 0.01, -1.0f * historyDepth) >= 1.0f)
		&& abs(historyDepth + segmentEyeDepth) < 0.05;
}



uint wang_hash(uint seed)
{
	seed = (seed ^ 61) ^ (seed >> 16);
	seed *= 9;
	seed = seed ^ (seed >> 4);
	seed *= 0x27d4eb2d;
	seed = seed ^ (seed >> 15);
	return seed;
}

#define SCAN_BLOCK_SIZE GROUP_SIZE_0


RWStructuredBuffer<uint> CBuffer_CachedArgs;

groupshared uint LDS_PrevBlockSum = 0;
// =======================================================
#define SCAN_FUNCTION_TAG PixelGen

uint op0(uint a, uint b)
{
	return a + b;
}

#define OP op0
#define SCAN_DATA_TYPE uint
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE 0u
// #define SCAN_DATA_VECTOR_STRIDE 2
#define SCAN_BLOCK_SIZE GROUP_SIZE_0

#define TG_COUNTER CBuffer_CachedArgs_PixelCounter
#define TGSM_COUNTER LDS_PrevBlockSum

#include "../StreamCompactionCodeGen.hlsl"
// =======================================================

 

groupshared uint LDS_PrevBlockSum1 = 0;
// =======================================================
#define SCAN_FUNCTION_TAG VisibleSegGen

uint op1(uint a, uint b)
{
	return a + b;
}

#define OP op1
#define SCAN_DATA_TYPE uint
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE 0u
// #define SCAN_DATA_VECTOR_STRIDE 2
#define SCAN_BLOCK_SIZE GROUP_SIZE_0

#define TG_COUNTER CBuffer_CachedArgs_VisibleSegCounter
#define TGSM_COUNTER LDS_PrevBlockSum1

#include "../StreamCompactionCodeGen.hlsl"
// =======================================================


#endif /* SEGMENTVISIBILITYCOMPUTEDEFS_INCLUDED */
