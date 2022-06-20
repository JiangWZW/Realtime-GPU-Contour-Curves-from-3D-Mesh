#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "./CustomShaderInputs.hlsl"


Texture2D<float4> _MainTex;
Texture2D<float> _MainTex_Paper;
Texture2D<float> _CurveTex_Brush;
Texture2D<float> _PaperHeightMap;
Texture2D<float4> _BrushTex_Main;

SamplerState sampler_point_clamp;
SamplerState sampler_linear_clamp;
SamplerState sampler_linear_repeat;

struct Attributes
{
	float4 positionOS : POSITION;
	float2 uv : TEXCOORD0;
};


struct Varyings
{
	float4 positionHCS : SV_POSITION;
	float2 uv : TEXCOORD0;
};


Varyings Vert(Attributes v)
{
	Varyings o;
	o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
	o.uv = v.uv;
	return o;
}

float4 FragInitPaper(Varyings i) : SV_Target
{
	float alpha = _MainTex_Paper.Sample(sampler_linear_clamp, i.uv);
	return float4(1, 1, 1, 1/*(alpha)*/); // TODO: is this pass useful? may just clear?
}

float3 FragToneMapping(Varyings i) : SV_Target
{
	float4 col = _MainTex.Sample(sampler_linear_clamp, i.uv);

	// Stroke by Stamping
	// bool hasInk = any(col.rgb < .995);
	// // if (hasInk && col.a > 0) col.rgb *= rcp(col.a);
	// float remapFactor = 
	// 	_CurveTex_Brush.Sample(sampler_linear_clamp, float2(col.g, .5f));
	// return remapFactor * col.rgb;

	
	// Screen-Space Stroke UV-Mapping
	float4 brushSample = 1;
	if (col.a > 0) {
		// col.rg /= col.a;
		brushSample = _BrushTex_Main.Sample(
			sampler_point_clamp, col.gr
		);
		
	}else
	{
		brushSample = 1;
		brushSample.a = 0;
	}
	return /*float4(col.gr, 1, 1); */brushSample.rgba;
}
