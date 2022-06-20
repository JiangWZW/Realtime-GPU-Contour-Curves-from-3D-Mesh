#ifndef TEXTURE2D_CONTOURGBUFFER_VIEW
#define TEXTURE2D_CONTOURGBUFFER_VIEW

#include "../CustomShaderInputs.hlsl"

Texture2D<uint4> _ContourGBuffer0; // Contains coverage info

struct ContourSegRasterData
{
	float	viewZ;
	float2	normal;
	float	depthGrad;
	uint	visibleSegIndex;

	uint4 Encode()
	{
		uint4 encoded;
		encoded.x = asuint(viewZ);
		encoded.y = visibleSegIndex;
		encoded.z = asuint(PackUnitVector_2D_ToFp(normal));
		encoded.w = asuint(depthGrad);
		return encoded;
	}
	void Decode(uint4 encoded)
	{
		viewZ = asfloat(encoded.x);
		visibleSegIndex = encoded.y;
		normal = UnpackUnitVector_2D_FromFp(asfloat(encoded.z));
		depthGrad = asfloat(encoded.w);
	}
};


struct ContourSegRaster_VSOutput
{
	float4 posCS                 : SV_POSITION;
	nointerpolation uint4 packedData : COLOR;

	void Encode_packedData(ContourSegRasterData segRasterData, uint splatId)
	{
		uint packedIds = ((segRasterData.visibleSegIndex << 4) | splatId);

		packedData = uint4(
			asuint(PackUnitVector_2D_ToFp(segRasterData.normal)),
			packedIds,
			asuint(segRasterData.depthGrad),
			asuint(-1.0 * segRasterData.viewZ/*negative to positive*/)
		);
	}
	void Decode_packedData(out ContourSegRasterData segRasterData, out uint splatId)
	{
		segRasterData.normal = 
			UnpackUnitVector_2D_FromFp(asfloat(packedData.x));
		segRasterData.visibleSegIndex = (packedData.y >> 4);
		segRasterData.depthGrad = asfloat(packedData.z);
		segRasterData.viewZ = -1.0 * asfloat(packedData.w)/*positive to negative*/;

		splatId = (packedData.y & 0x0000000f);
	}
};






// See "ParticleCoveragePath_VS/_FS"
struct ParticleCoverageVertexOutput
{ // vs specialized for particle coverage testing
	float4 posCS : SV_POSITION;
	nointerpolation uint2 cvrgData : TEXCOORD1;
	noperspective float2 uv : TEXCOORD2;

	void Encode_cvrgData(uint endPointPtclId)
	{
		cvrgData = uint2(endPointPtclId, 1);
	}
};

struct ParticleCoverageSample
{
	uint ptclId;
	bool validSample;

	uint4 GenerateTexSample(ParticleCoverageVertexOutput v2f)
	{
		uint4 texSample = uint4(asuint(v2f.uv), v2f.cvrgData);
		return texSample;
	}

	void DecodeFromTexSample(uint4 texSample)
	{ // .zw : uint2(segHead/tail-ptclId, springLen)
		ptclId = (texSample.z);
		validSample = any(texSample.zw != 0);
	}

	bool isPtclOnSample(uint voteSegHeadId, uint voteSegTailId)
	{ // Cooperated with SpineData_ParticleCoverage.Setup()
		// and following raster output scheme
		return ((ptclId == voteSegHeadId) || (ptclId == voteSegTailId));
	}
};






// See "ContourCoveragePath_VS/_FS"
struct ContourCoverageVertexOutput
{ // vs specialized for contour coverage testing
	float4 posCS : SV_POSITION;
	nointerpolation uint2 cvrgData : TEXCOORD1;
	noperspective float2 uv : TEXCOORD2;

	void Encode_cvrgData(uint stkHeadEdgeId, uint stkLen)
	{
		cvrgData = uint2(stkHeadEdgeId, stkLen);
	}
};

struct ContourCoverageSample
{
	uint ptclId;
	bool validSample;

	uint4 GenerateTexSample(ContourCoverageVertexOutput v2f)
	{
		uint4 texSample = uint4(asuint(v2f.uv), v2f.cvrgData);
		return texSample;
	}

	void DecodeFromTexSample(uint4 texSample)
	{ // .zw : uint2(segHeadId, ?)
		ptclId = (texSample.z);
		validSample = any(texSample.zw != 0);
	}

	bool isContourOnSample(uint stkHeadId)
	{ 
		return ((ptclId == stkHeadId));
	}
};



#endif