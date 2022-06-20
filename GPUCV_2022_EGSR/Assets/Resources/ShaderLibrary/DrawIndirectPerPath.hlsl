#ifndef DRAWINDIRECTPERSTAMP_INCLUDED
#define DRAWINDIRECTPERSTAMP_INCLUDED

// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
// #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
// #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

#include "./BrushToolBox.hlsl"

#include "./ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"

#include "../ShaderLibrary/TextureConfigs/Texture2D_ContourGBufferTex_View.hlsl"

#include "./ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"


//== Structures ===============================
struct ProceduralPathVertexOutput
{
	float4 posCS : SV_POSITION;
	float4 color : COLOR;
	float2 uvCoord : TEXCOORD1;
	nointerpolation float2 packedData : TEXCOORD2;
};





//== Shader Resources ===========================
StructuredBuffer<int> CBuffer_CachedArgs;
ByteAddressBuffer CBuffer_BufferRawProceduralGeometry;

SamplerState sampler_point_repeat;
SamplerState sampler_linear_repeat;
Texture2D<float4> _BrushTex_Main;
uint _BrushTexCount;

uint _PathStyle;
// Match LineDrawingControlPanel.VectorizedPathStyle
#define PATH_STYLE_SEGMENTATION 0u
#define PATH_STYLE_UV 1u
#define PATH_STYLE_TEXTURED 2u

ProceduralPathVertexOutput StrokePath_VS(
	uint pointInstanceId : SV_VertexID
)
{
	uint vertexId = GetWingQuadVertexIndex(pointInstanceId);
	uint wingId = pointInstanceId / POINTS_PER_WING_QUAD;
	
	float2 vPos = UnpackF16F16(
		CBuffer_BufferRawProceduralGeometry.Load(
			CBuffer_ProceduralGeometry_StrokeVertices_AddrAt(vertexId)
		));
	float2 uv = GetWingQuadVertexUV(vertexId);

	float4 stampCol = asfloat(
		CBuffer_BufferRawProceduralGeometry.Load4(
			CBuffer_ProceduralGeometry_StrokeVertColor_AddrAt(wingId)
		));
	uint stkLen = (uint)(.1f + stampCol.b);

	ProceduralPathVertexOutput output;
	output.posCS = float4(vPos.xy, (float)(stkLen % 4096) / 4096.0f, 1);
	output.posCS.y *= -1;

	output.uvCoord = uv;
	output.color = stampCol;

	output.packedData.x = stampCol.x; // packed screen color r8g8b8a8
	output.packedData.y = 0;

	// last edge in brush path won't generate spine geometry
	if (stampCol.a < .5f)
	{
		output.posCS = 0;
		output.uvCoord = 0;
		output.color = 1;
		output.packedData = 0;
	}
	
	return output;
}


float4 StrokePath_FS(
	ProceduralPathVertexOutput input
) : SV_TARGET
{
	uint stkLen = (uint)(.1f + input.color.b);
	uint randSeed = WangHash(WangHash((uint)(stkLen * 0.8))) % _BrushTexCount;

	float2 uvBaseOffset = float2(0, (float)randSeed / (float)_BrushTexCount);
	float2 uvSubOffset = float2(input.color.g, (input.uvCoord.y) / (float)_BrushTexCount);
	float2 uvBrushTex = 
		// float2(input.color.g, input.uvCoord.y);
		uvBaseOffset + uvSubOffset;
	float4 brushCol = _BrushTex_Main.Sample(sampler_point_repeat, uvBrushTex);

	float2 uvScreenTex = input.posCS.xy / _ScreenParams.xy;
	float4 screenCol = UnpackR8G8B8A8(asuint(input.packedData.x));

	float4 col;
	// if (_PathStyle == PATH_STYLE_SEGMENTATION)
	{
		col = float4(
			.8 * RandColRgb(stkLen, stkLen * 17),
			1
		);
	}
	if (_PathStyle == PATH_STYLE_TEXTURED)
	{
		col = brushCol;
		// col.rgb =
		// 	brushCol.b * 2.0 *
		// 	(input.uvCoord.y < .5f ? (input.uvCoord.y < .0f ? 0 : .3 * screenCol.rgb) : 1.5 * screenCol.rgb);
		// col.a = brushCol.a; brushCol.a < .00001 ? 0 : max(.999, brushCol.a);
	}
	if (_PathStyle == PATH_STYLE_UV)
	{
		col = float4(
			uvBrushTex.xy, 
			.0f, 1.0f
		);
	}

	return col;
}





ContourCoverageVertexOutput ContourCoveragePath_VS(
	uint pointInstanceId : SV_VertexID
)
{
	uint vertexId = GetWingQuadVertexIndex(pointInstanceId);
	uint spineId = pointInstanceId / POINTS_PER_WING_QUAD;

	float2 vPos = UnpackF16F16(
		CBuffer_BufferRawProceduralGeometry.Load(
			CBuffer_ProceduralGeometry_StrokeVertices_AddrAt(vertexId)
		));
	float2 uv = GetWingQuadVertexUV(vertexId);

	SpineData_ContourCoverage ptclData;
	ptclData.Decode(
		CBuffer_BufferRawProceduralGeometry.Load4(
			CBuffer_ProceduralGeometry_StrokeCustomData_AddrAt(
				spineId, (1 << BITS_BLOCK_OFFSET)))
	);


	ContourCoverageVertexOutput output;
	output.posCS = float4(
		vPos.xy, ptclData.coverageScore, 1
	);
	output.posCS.y *= -1;

	output.Encode_cvrgData(ptclData.edgeId, ptclData.stkLen);

	output.uv = uv;

	// last edge in brush path won't generate spine geometry
	if (!(ptclData.drawEdge))
	{
		output.posCS = float4(0, 0, 0, 1);
	}

	return output;
}

uint4 ContourCoveragePath_FS(
	ContourCoverageVertexOutput input
) : SV_TARGET
{
	// uint stkLen = input.cvrgData.y;
	// return float4(RandColRgb(stkLen, stkLen / 3), 1);
	ContourCoverageSample output;
	return output.GenerateTexSample(input);
}







ParticleCoverageVertexOutput ParticleCoveragePath_VS(
	uint pointInstanceId : SV_VertexID
)
{
	uint vertexId = GetWingQuadVertexIndex(pointInstanceId);
	uint spineId = pointInstanceId / POINTS_PER_WING_QUAD;

	float2 vPos = UnpackF16F16(
		CBuffer_BufferRawProceduralGeometry.Load(
			CBuffer_ProceduralGeometry_StrokeVertices_AddrAt(vertexId)
		));
	float2 uv = GetWingQuadVertexUV(vertexId);

	SpineData_ParticleCoverage ptclData;
	ptclData.Decode(
		CBuffer_BufferRawProceduralGeometry.Load4(
			CBuffer_ProceduralGeometry_StrokeCustomData_AddrAt(
				spineId, (1 << BITS_BLOCK_OFFSET)))
	);

	
	ParticleCoverageVertexOutput output;
	output.posCS = float4(
		vPos.xy, ptclData.coverageScore, 1.0f
	);
	output.posCS.y *= -1;

	output.Encode_cvrgData(ptclData.ptclId);

	output.uv = uv;

	// last edge in brush path won't generate spine geometry
	if (!(ptclData.drawPtcl))
	{
		output.posCS = float4(0, 0, 0, 1);
	}

	return output;
}

uint4 ParticleCoveragePath_FS(
	ParticleCoverageVertexOutput input
) : SV_TARGET
{
	ParticleCoverageSample output;
	return output.GenerateTexSample(input);
}






#endif /* DRAWINDIRECTPERSTAMP_INCLUDED */
