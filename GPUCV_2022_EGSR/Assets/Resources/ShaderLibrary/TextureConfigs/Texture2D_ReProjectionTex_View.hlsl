#ifndef TEXTURE2D_REPROJECTIONTex_VIEW
#define TEXTURE2D_REPROJECTIONTex_VIEW

#include "../CustomShaderInputs.hlsl"

#ifdef UAV_ReProjectionTex
	RWTexture2D<uint> _ReProjectionTex;
#else
	Texture2D<uint> _ReProjectionTex;
#endif

struct StampGridSample
{
	bool valid;
	bool stampOnStroke;
	uint stampId;
};

StampGridSample SampleGridData(uint2 coord)
{
	uint gridSample = _ReProjectionTex.Load(int3(coord, 0));

	StampGridSample res;
	res.valid = gridSample != 0;
	res.stampId =		GetRPJSampleAttr(RPJ_ID, gridSample);
	res.stampOnStroke = GetRPJSampleAttr(STROKE_SAMPLE, gridSample);

	return res;
}


#endif