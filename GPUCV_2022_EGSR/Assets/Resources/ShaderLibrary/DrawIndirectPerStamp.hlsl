#ifndef DRAWINDIRECTPERSTAMP_INCLUDED
#define DRAWINDIRECTPERSTAMP_INCLUDED

// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
// #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
// #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

#include "./BrushToolBox.hlsl"

#include "./ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"

#include "./ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"


#define ENBLE_TANGENT_FEATURE
#define ENABLE_SHAPE_FACTOR_DEPTH_GRADIENT


//== Structures ===============================
struct ProceduralStampVertexOutput_Legacy
{
	float4 posCS : SV_POSITION;
	float4 color : COLOR;
	float2 baryCoord : TEXCOORD0;
	float2 uvCoord : TEXCOORD1;
};


struct ProceduralStampVertexOutput
{
	float4 posCS : SV_POSITION;
	float4 color : COLOR;
	float2 uvCoord : TEXCOORD1;
};


struct StampDensityVertexOutput
{
	float4 posCS : SV_POSITION;
	float2 uvCoord : TEXCOORD1;
	float4 data : COLOR;
};


//== Shader Resources ===========================
float4 CVector_ScreenTexelSize_SS;

ByteAddressBuffer CBuffer_BufferRawStampGBuffer;
ByteAddressBuffer CBuffer_BufferRawStampPixels;

Texture2D<float4> _BrushTex_Main;
Texture2D<float> _BrushTex_Paper;
SamplerState sampler_point_repeat;


//== Utility functions ========================
// _ZBufferParams: Unity built-in param
// in case of a reversed depth buffer (UNITY_REVERSED_Z is 1)
// x = f/n - 1
// y = 1
// z = x/f = 1/n - 1/f
// w = 1/f
// float4 _ZBufferParams;
// Zhclip = Zndc * Zview 
// ------ = [-n/(f - n)] * Zview + [fn/(f - n)]
// ------ = [-1/(f/n - 1)] * ZView + [1/(1/n - 1/f)]
// ------ = [-1/x] * Zview + [1/z]
// ------ = A*Zview + B
// ------ A = -1/x, B = 1 / z;
float ViewToHClipZ(float zview)
{
	float2 coeffs = float2(
		-1 / _ZBufferParams.x,
		1 / _ZBufferParams.z
	);
	return dot(coeffs, float2(zview, 1));
}


StructuredBuffer<int> CBuffer_CachedArgs;

//== Shader Programs =========================================
ProceduralStampVertexOutput_Legacy Stamp_VS(
	uint vertId : SV_VertexID
)
{
	uint vertIdLocal = vertId % 12;
	uint primId = vertId / 12;

	const uint StampCount = CBuffer_CachedArgs_PixelCounter;
	
	uint xyPacked = CBuffer_BufferRawStampPixels.Load(primId << 2);
	uint2 coordSS = DecodePixelCoord(xyPacked);
	float2 posNDC = ((float2)coordSS + float2(.5, .5)) / _ScreenParams.xy;
	posNDC = posNDC * 2 - 1;

	// LinkDataRT linkData = /* Load link here */
	// float minRank = min(linkData.rank0, linkData.rank1);
	// float splineLen = linkData.rank0 + linkData.rank1;
	bool shouldRender = true /* && (minRank % 8 == 0)*/
		/*isSimpleTopo && isSkeleton*//* && (minRank % 8 == 0)*/;

	float2 tangent = float2(1, 0);
#ifdef ENBLE_TANGENT_FEATURE
	tangent = 0;/*asfloat(
		CBuffer_BufferRawStampGBuffer.Load2(
			CBuffer_BufferRawStampTangent_AddrAt(primId)));*/
	tangent = normalize(tangent);
#endif

	float2 lineScale = float2(_LineWidth, _StampLength) * (_ScreenParams.zw - 1.0f);

#ifdef ENABLE_SHAPE_FACTOR_DEPTH_GRADIENT
	float2 zbuffer = 0;/*asfloat(
		CBuffer_BufferRawStampGBuffer.Load2(
			CBuffer_BufferRawStampZBuffer_AddrAt(primId)));*/
	float zview = zbuffer.y;
	float zhclip = ViewToHClipZ(zview);
	float zGrad = smoothstep(
		0, 1,
		saturate(0.2 * zbuffer.x)
	);
	lineScale *= (zGrad + 1).xx;
#endif


	float2 baryCoords = float2(0, 0);
	float2 uvCoords = float2(0, 0);

	float pixelPerfect = _ScreenParams.x * (_ScreenParams.w - 1);
	// lineScale.y *= pixelPerfect;
	// tangent.y *= pixelPerfect;
	float2 posOut = ComputeStampPointNDC_xy(
		posNDC, tangent,
		// width on normal dir, length on tangent dir(line dir)
		lineScale,
		vertIdLocal,
		baryCoords,
		uvCoords
	);

	ProceduralStampVertexOutput_Legacy output;
	output.posCS = float4(posOut.xy, 1, 1);
	output.posCS.y *= -1;

	output.posCS.z = 1;
	output.posCS.w = 1;

	output.baryCoord = baryCoords;
	output.uvCoord = uvCoords;
	output.color = float4(0, 0, shouldRender, 0);

	return output;
}

float4 Stamp_FS(
	ProceduralStampVertexOutput_Legacy input
) : SV_TARGET
{
	float2 baryCoords = input.baryCoord;
	float radius = sqrt(dot(baryCoords, baryCoords));

	if (radius > 0.8 || input.color.b == 0)
	{
		discard;
	}
	float analyticalCol = smoothstep(0, 0.8, radius) * input.color.g;

	float4 col;
	// Case 0: Analytical Color
	col = float4(analyticalCol.xxx, 1);
	// Case 1: Sample Brush Texture
	//   col.rgb = 
	// _BrushTex_Main.Sample(sampler_linear_clamp, input.uvCoord).rgb;
	//   col.a = 1;
	//   col.rgb *= col.a;
	return col;
}

ByteAddressBuffer CBuffer_BufferRawProceduralGeometry;

ProceduralStampVertexOutput StrokeStamp_VS(
	uint vertId : SV_VertexID
)
{
	uint vertIdLocal = vertId % (uint)VERTS_PER_STAMP_QUAD;
	uint quadVertId = QuadVertexBuffer[vertIdLocal];
	uint primId = vertId / (uint)VERTS_PER_STAMP_QUAD;
	float2 vPos = UnpackF16F16(
		CBuffer_BufferRawProceduralGeometry.Load(
			(4 * primId + quadVertId) << BITS_WORD_OFFSET
		));
	float2 uv = .5 + .5 * QuadVPBuffer[quadVertId];
	// uv: from -1, 1 t0 0, 1

	float4 stampCol = asfloat(
		CBuffer_BufferRawProceduralGeometry.Load4(
			CBuffer_ProceduralGeometry_StrokeVertColor_AddrAt(primId)
		));
	
	ProceduralStampVertexOutput output;
	output.posCS = float4(vPos.xy, 1, 1);
	output.posCS.y *= -1;
	output.posCS *= stampCol.b;

	output.uvCoord = uv;
	output.color = stampCol;

	return output;
}

#define SHADING_RADIUS_MAX 0.5f
#define FLAT_SHADING_RADIUS 0.4f
#define INV_FLAT_RADIUS ((1.0f / (SHADING_RADIUS_MAX - FLAT_SHADING_RADIUS)))

float4 StrokeStamp_FS(
	ProceduralStampVertexOutput input
) : SV_TARGET
{
	float2 distToCenter = input.uvCoord - float2(.5, .5);
	float radius = length(distToCenter);

	float weight = (radius <= FLAT_SHADING_RADIUS)
		               ? 1.0
		               : 1.0 - smoothstep(0, 1, (radius - FLAT_SHADING_RADIUS) * INV_FLAT_RADIUS);
	float4 col;


	// *) Sample Brush/Paper Texture
#define BRUSH_TEX_RATIO 16.0f // TODO: dynamic input when system is mature
	// float2 screenCoord = input.posCS.xy / _ScreenParams.xy;
	// float2 brushTexSampleCoord =
	// 	float2(input.uvCoord.x / BRUSH_TEX_RATIO, input.uvCoord.y)
	// 	+ float2(input.color.g, 0);
		// + float2 ((screenCoord.x * screenCoord.y) * .5, 0);
	// float4 brushCol = _BrushTex_Main.Sample(
	// 	sampler_point_repeat,
	// 	brushTexSampleCoord
	// );
	// float paperCol = _BrushTex_Paper.Sample(
	// 	sampler_point_repeat,
	// 	(screenCoord/* + input.color.gg*/) * 12
	// );
	//
	// col.rgb = lerp(
	// 	brushCol.rgb,
	// 	saturate(paperCol.rrr - brushCol.rgb), 
	// 	radius * .2
	// );
	// col.a = lerp(
	// 	brushCol.a,
	// 	paperCol,
	// 	radius * .2
	// );
	// // col = brushCol;
	//
	//
	// col.a *= ((input.color.r));
	// // col.a *= min(1, 2 * pow((abs(distToCenter.y) * 2), .2));
	// // col.a *= min(1, 2 * pow(radius * 2, .2));
	//
	// col.rgb *= (col.a);

	// *) Debug Stroke Parameter
	bool isStrokeSample = true;
	col.r = isStrokeSample ? input.uvCoord.y : 1;
	col.g = isStrokeSample ? input.color.g : 1;
	col.b = isStrokeSample ? 1 : 0;
	col.a = isStrokeSample ? 1 : 0;
	return col;

	
	// return float4(0, 0, 0, 1);
}


#endif /* DRAWINDIRECTPERSTAMP_INCLUDED */
