#ifndef B4BDACBF_2971_4974_A449_FEFCC97BB7C2135
#define B4BDACBF_2971_4974_A449_FEFCC97BB7C2135

#include "../ComputeAddressingDefs.hlsl"
#include "../CustomShaderInputs.hlsl"
#include "../MultiBuffering_ParticleData.hlsl"
#include "./ArgsBuffers/CBuffer_CachedArgs_View.hlsl"

#define BUFFER_STRIDE(tag) tag##_STRIDE

//						Stroke(Pixel-Edge) Vertices
//////////////////////////////////////////////////////////////////////////////
// Data Arrangement
// float2 vertPosNDC[4]
#define BITS_STROKE_STAMP_VERT_STRIDE_OFFSET ((BITS_BLOCK_OFFSET))

#define STROKE_VERT_BUFFER 0
#define STROKE_VERT_STRIDE ((1 << BITS_STROKE_STAMP_VERT_STRIDE_OFFSET))
#define STROKE_VERT_LENGTH (MAX_STAMP_EDGE_COUNT * STROKE_VERT_STRIDE)

uint CBuffer_ProceduralGeometry_StrokeVertices_AddrAt(uint vertexId)
{
	return STROKE_VERT_BUFFER + ((vertexId) << BITS_WORD_OFFSET/*f16f16*/);
}

uint CBuffer_ProceduralGeometry_StrokeStampVertices_AddrAt(uint drawStampId)
{
	return STROKE_VERT_BUFFER + ((drawStampId) << BITS_STROKE_STAMP_VERT_STRIDE_OFFSET);
}

uint CBuffer_ProceduralGeometry_StrokePathVertices_AddrAt(uint drawSpineId)
{
	return STROKE_VERT_BUFFER + (drawSpineId * (3 << BITS_WORD_OFFSET));
}

void CBuffer_ProceduralGeometry_StrokeStampVertices_Store(
	RWByteAddressBuffer buffer,
	float4x2 vertices,
	uint drawStampId)
{
	uint strAddr = CBuffer_ProceduralGeometry_StrokeStampVertices_AddrAt(
		drawStampId
	);

	buffer.Store4(
		strAddr,
		uint4(
			PackF16F16(vertices[0].xy),
			PackF16F16(vertices[1].xy),
			PackF16F16(vertices[2].xy),
			PackF16F16(vertices[3].xy)
		)
	);
}

void CBuffer_ProceduralGeometry_StrokePathVertices_Store(
	RWByteAddressBuffer buffer,
	float3x2 vertices,
	uint drawSpineId)
{
	uint strAddr = CBuffer_ProceduralGeometry_StrokePathVertices_AddrAt(
		drawSpineId
	);
	buffer.Store3(
		strAddr,
		uint3(
			PackF16F16(vertices[0].xy),
			PackF16F16(vertices[1].xy),
			PackF16F16(vertices[2].xy)
		)
	);
}

#define BITS_STROKE_VERT_COLOR_STRIDE_OFFSET ((BITS_BLOCK_OFFSET))
#define STROKE_VERT_COLOR_BUFFER (STROKE_VERT_BUFFER + STROKE_VERT_LENGTH)
#define STROKE_VERT_COLOR_STRIDE ((1 << BITS_STROKE_VERT_COLOR_STRIDE_OFFSET))
#define STROKE_VERT_COLOR_LENGTH (MAX_STAMP_COUNT * STROKE_VERT_COLOR_STRIDE)

uint CBuffer_ProceduralGeometry_StrokeVertColor_AddrAt(uint spineId)
{
	return STROKE_VERT_COLOR_BUFFER + ((spineId) << BITS_STROKE_VERT_COLOR_STRIDE_OFFSET);
}

void CBuffer_ProceduralGeometry_StrokeVertColor_Store(
	RWByteAddressBuffer buffer,
	float4 color,
	uint spineId)
{
	uint strAddr = CBuffer_ProceduralGeometry_StrokeVertColor_AddrAt(spineId);
	buffer.Store4(strAddr, asuint(color));
}

// Custom data per-spine as an alternative to vertex color.
// Maximum stride:=uint4
uint CBuffer_ProceduralGeometry_StrokeCustomData_AddrAt(uint spineId, uint stride)
{
	return STROKE_VERT_COLOR_BUFFER + ((spineId)*stride);
}
struct SpineData_ParticleCoverage
{
	uint Stride() { return (1 << BITS_BLOCK_OFFSET); }
	uint ptclId;
	uint springLen;
	float coverageScore;
	bool drawPtcl;

	void Setup(uint id, uint rank, uint len, uint maxLen, bool drawPtclIn)
	{
		uint headPtclId = id - rank;
		ptclId = (rank < (len >> 1u))
			? (headPtclId) : (headPtclId + len - 1u);

		springLen = len;
		coverageScore = (float)len / (float)maxLen;
		// coverageScore = coverageScore * .99f + .01f; // (0, 1)->(.01, 1)
		// coverageScore += ((rank < (len >> 1u)) ? .01f : .0f);
		drawPtcl = drawPtclIn;
	}
	uint4 Encode()
	{
		uint zPacked = 0; // note: maximum 24 free bits here
		zPacked |= drawPtcl;

		uint4 encoded = uint4(ptclId, springLen, zPacked, 0u/*to be added*/);
		encoded.xyz = PackU24x4(encoded);

		encoded.w = asuint(coverageScore);

		return encoded;
	}
	void Decode(uint4 encoded)
	{
		coverageScore = asfloat(encoded.w);

		uint4 unpacked = UnpackU24x4(encoded.xyz);

		ptclId = unpacked.x;
		springLen = unpacked.y;

		uint zPacked = unpacked.z;
		drawPtcl = (zPacked & 1u);
	}
};

struct SpineData_ContourCoverage
{
	uint Stride() { return (1 << BITS_BLOCK_OFFSET); }
	uint edgeId;
	uint stkLen;
	float coverageScore;
	bool drawEdge;

	void Setup(uint headEdgeId, uint len, uint maxLen, float viewZ, bool drawPtclIn)
	{
		edgeId = headEdgeId;
		stkLen = len;
		coverageScore = viewZ;  (float)len / (float)maxLen;
		drawEdge = drawPtclIn;
	}
	uint4 Encode()
	{
		uint zPacked = 0; // note: maximum 24 free bits here
		zPacked |= drawEdge;

		uint4 encoded = uint4(edgeId, stkLen, zPacked, 0u/*to be added*/);
		encoded.xyz = PackU24x4(encoded);
		encoded.w = asuint(coverageScore);

		return encoded;
	}
	void Decode(uint4 encoded)
	{
		coverageScore = asfloat(encoded.w);

		uint4 unpacked = UnpackU24x4(encoded.xyz);

		edgeId = unpacked.x;
		stkLen = unpacked.y;

		uint zPacked = unpacked.z;
		drawEdge = (zPacked & 1u);
	}
};



//						Stroke(Pixel-Edge) Raster Data
//////////////////////////////////////////////////////////////////////////////
// Data Arrangement
// uint edgeId			: Edge ID
// uint stampCoord		: (packed)screen-space stamp coord, range [0, 1]
// uint stampScale		: (packed)normalized stamp scale, range [0, 1] (see MAX_STAMP_QUAD_SCALE)
// float edgeTangent	: (packed)stamp tangent vector
#define BITS_STROKE_RASTER_DATA_STRIDE_OFFSET ((BITS_BLOCK_OFFSET))

#define STROKE_RASTER_DATA_BUFFER (STROKE_VERT_COLOR_BUFFER + STROKE_VERT_COLOR_LENGTH)
#define STROKE_RASTER_DATA_STRIDE ((1 << BITS_STROKE_RASTER_DATA_STRIDE_OFFSET))
#define STROKE_RASTER_DATA_LENGTH (MAX_STAMP_EDGE_COUNT * STROKE_RASTER_DATA_STRIDE)

uint CBuffer_ProceduralGeometry_StrokeRasterData_AddrAt(uint drawPrimId)
{
	return STROKE_RASTER_DATA_BUFFER + (
		drawPrimId << BITS_STROKE_RASTER_DATA_STRIDE_OFFSET
	);
}

void CBuffer_ProceduralGeometry_StrokeRasterData_Store(
	uint drawPrimId,
	uint pixelEdgeId,
	float2 stampCoord,
	float2 stampScale,
	float2 edgeTangent,
	RWByteAddressBuffer buffer
)
{
	uint strAddr = CBuffer_ProceduralGeometry_StrokeRasterData_AddrAt(drawPrimId);
	uint packedCoord = PackR16G16(stampCoord);

	float2 stampScaleNormalized = min(1.0f, stampScale / MAX_STAMP_QUAD_SCALE);
	uint packedScale = PackR16G16(stampScaleNormalized);

	uint packedTangent = PackUnitVector_2D(edgeTangent);

	buffer.Store4(
		strAddr,
		uint4(
			pixelEdgeId,
			packedCoord,
			packedScale,
			packedTangent
		)
	);
}

void CBuffer_ProceduralGeometry_StrokeRasterData_Load(
	uint drawPrimId,
	out uint pixelEdgeId,
	out float2 stampCoord,
	out float2 stampScale,
	out float2 edgeTangent,
	RWByteAddressBuffer buffer
)
{
	uint ldAddr = CBuffer_ProceduralGeometry_StrokeRasterData_AddrAt(drawPrimId);
	uint4 ldData = buffer.Load4(ldAddr);

	pixelEdgeId = ldData.x;
	stampCoord = UnpackR16G16(ldData.y);
	stampScale = MAX_STAMP_QUAD_SCALE * UnpackR16G16(ldData.z);
	edgeTangent = UnpackUnitVector_2D(ldData.w);
}



#define BITS_PBD_PARTICLE_POSITION_STRIDE_OFFSET ((BITS_DWORD_OFFSET))
#define PBD_PARTICLE_POSITION_BUFFER (STROKE_RASTER_DATA_BUFFER + STROKE_RASTER_DATA_LENGTH)
#define NUM_SUBBUFF_PBD_PARTICLE_POSITION (3u)
#define PBD_PARTICLE_POSITION_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_PARTICLE_POSITION_STRIDE_OFFSET))
#define PBD_PARTICLE_POSITION_LENGTH ((NUM_SUBBUFF_PBD_PARTICLE_POSITION * PBD_PARTICLE_POSITION_SUB_LENGTH))
uint CBuffer_PCG_PBD_Coord_AddrAt(uint particleId, uint subbuff)
{
	uint subbuffOffset = (subbuff % 3u) * (PBD_PARTICLE_POSITION_SUB_LENGTH);
	return PBD_PARTICLE_POSITION_BUFFER +
		subbuffOffset + 
		(particleId << BITS_PBD_PARTICLE_POSITION_STRIDE_OFFSET);
}
uint CBuffer_PCG_PBD_Coord_AddrAt(uint particleId)
{
	return CBuffer_PCG_PBD_Coord_AddrAt(
		particleId, ID_SubBuff_Active(ParticlePosition)
	);
}


// Ping-Pong Scheme in PBD solvers
#define Subbuff_X_MainLoop_In (ID_SubBuff_Active(ParticlePosition))
#define Subbuff_X_MainLoop_Out Subbuff_X_MainLoop_In
#define Subbuff_X_InnerLoop_In ((Subbuff_X_MainLoop_In + 1u) % NUM_SUBBUFF_PBD_PARTICLE_POSITION)
#define Subbuff_X_InnerLoop_Out ((Subbuff_X_MainLoop_In + 2u) % NUM_SUBBUFF_PBD_PARTICLE_POSITION)

// Ping-Pong Scheme in Resampler
#define Subbuff_X_Resampler_In Subbuff_X_MainLoop_Out
#define Subbuff_X_Resampler_Out Subbuff_X_InnerLoop_In



#define NUM_SUBBUFF_PBD_SPRING_AABB 2u

#define BITS_PBD_SPRING_AABB_CENTER_STRIDE_OFFSET ((BITS_WORD_OFFSET))
#define PBD_SPRING_AABB_CENTER_BUFFER (PBD_PARTICLE_POSITION_BUFFER + PBD_PARTICLE_POSITION_LENGTH)
#define PBD_SPRING_AABB_CENTER_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_SPRING_AABB_CENTER_STRIDE_OFFSET))
#define PBD_SPRING_AABB_CENTER_LENGTH ((NUM_SUBBUFF_PBD_SPRING_AABB * PBD_SPRING_AABB_CENTER_SUB_LENGTH))
// Bounding Box packed(centerCoord)
// Use DecodePixelCoord to unpack
uint CBuffer_PCG_PBD_AABB_Center_AddrAt(uint particleId, uint2 subbuff)
{
	uint subbuffOffset = subbuff * PBD_SPRING_AABB_CENTER_SUB_LENGTH;

	return PBD_SPRING_AABB_CENTER_BUFFER
		+ subbuffOffset
		+ (particleId << BITS_PBD_SPRING_AABB_CENTER_STRIDE_OFFSET);
}
uint CBuffer_PCG_PBD_AABB_Center_AddrAt(uint particleId)
{
	return CBuffer_PCG_PBD_AABB_Center_AddrAt(
		particleId, ID_SubBuff_Active(SpringAABB)
	);
}
#define BITS_PBD_SPRING_AABB_SCALE_STRIDE_OFFSET ((BITS_WORD_OFFSET))
#define PBD_SPRING_AABB_SCALE_BUFFER (PBD_SPRING_AABB_CENTER_BUFFER + PBD_SPRING_AABB_CENTER_LENGTH)
#define PBD_SPRING_AABB_SCALE_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_SPRING_AABB_SCALE_STRIDE_OFFSET))
#define PBD_SPRING_AABB_SCALE_LENGTH ((NUM_SUBBUFF_PBD_SPRING_AABB * PBD_SPRING_AABB_SCALE_SUB_LENGTH))
// Bounding Box packed(aabbLen_Y, aabbLen_Y))
// Use DecodePixelCoord to unpack
uint CBuffer_PCG_PBD_AABB_XYSize_AddrAt(uint particleId, uint subbuff)
{
	uint subbuffOffset = subbuff * PBD_SPRING_AABB_SCALE_SUB_LENGTH;

	return PBD_SPRING_AABB_SCALE_BUFFER
		+ subbuffOffset
		+ (particleId << BITS_PBD_SPRING_AABB_SCALE_STRIDE_OFFSET);
}
uint CBuffer_PCG_PBD_AABB_XYSize_AddrAt(uint particleId)
{
	return CBuffer_PCG_PBD_AABB_XYSize_AddrAt(
		particleId, ID_SubBuff_Active(SpringAABB)
	);
}
struct AABB_CenterLen
{
	float2 center;
	float2 sizeXY; // half width, half height
	float ScaleFactor() { return .5f * max(sizeXY.x, sizeXY.y); }
	void DecodeCenter(uint centerU32);
	void DecodeSizeXY(uint scaleU32);
	uint EncodeCenter();
	uint EncodeSizeXY();
};

void AABB_CenterLen::DecodeCenter(uint centerU32)
{
	center = (float2)DecodePixelCoord(centerU32);
}
void AABB_CenterLen::DecodeSizeXY(uint sizeXYU32)
{
	sizeXY = (float2)DecodePixelCoord(sizeXYU32);
}
uint AABB_CenterLen::EncodeCenter()
{
	return PackPixelCoord((uint2)(center + .1f));
}
uint AABB_CenterLen::EncodeSizeXY()
{
	return PackPixelCoord((uint2)(sizeXY + .1f));
}

float2 ScreenToLocalCoord(AABB_CenterLen aabb, float2 screenCoord)
{
	float2 localCoord = screenCoord - aabb.center;
	localCoord /= aabb.ScaleFactor();

	return localCoord;
}
double2 ScreenToLocalCoord(AABB_CenterLen aabb, double2 screenCoord)
{
	double2 localCoord = screenCoord - (double2)aabb.center;
	localCoord /= ((double)aabb.ScaleFactor());

	return localCoord;
}
float2 LocalToScreenCoord(AABB_CenterLen aabb, float2 localCoord)
{
	float2 screenCoord = localCoord * aabb.ScaleFactor();
	screenCoord += aabb.center;

	return screenCoord;
}
double2 LocalToScreenCoord(AABB_CenterLen aabb, double2 localCoord)
{
	double2 screenCoord = localCoord * ((double)aabb.ScaleFactor());
	screenCoord += ((double2)aabb.center);

	return screenCoord;
}
float2 ScreenToLocalVec(AABB_CenterLen aabb, float2 screenVec)
{
	return screenVec / aabb.ScaleFactor();
}
float2 LocalToScreenVec(AABB_CenterLen aabb, float2 localVec)
{
	return localVec * aabb.ScaleFactor();
}
AABB_CenterLen LoadSpringAABB(
	uint ptclId,
	RWByteAddressBuffer BufferRawProceduralGeometry, 
	uint subbuff)
{
	uint centerU32 = BufferRawProceduralGeometry.Load(
		CBuffer_PCG_PBD_AABB_Center_AddrAt(ptclId, subbuff)
	);
	uint sizeXYU32 = BufferRawProceduralGeometry.Load(
		CBuffer_PCG_PBD_AABB_XYSize_AddrAt(ptclId, subbuff)
	);
	AABB_CenterLen aabb;
	aabb.DecodeCenter(centerU32);
	aabb.DecodeSizeXY(sizeXYU32);

	return aabb;
}
AABB_CenterLen LoadSpringAABB(
	uint ptclId, 
	RWByteAddressBuffer BufferRawProceduralGeometry)
{
	return LoadSpringAABB(
		ptclId, BufferRawProceduralGeometry,
		ID_SubBuff_Active(SpringAABB)
	);
}

#define BITS_PBD_PARTICLE_VELOCITY_STRIDE_OFFSET ((BITS_DWORD_OFFSET))
#define PBD_PARTICLE_VELOCITY_BUFFER (PBD_SPRING_AABB_SCALE_BUFFER + PBD_SPRING_AABB_SCALE_LENGTH)
#define PBD_PARTICLE_VELOCITY_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_PARTICLE_VELOCITY_STRIDE_OFFSET))
#define PBD_PARTICLE_VELOCITY_LENGTH (2 * (PBD_PARTICLE_VELOCITY_SUB_LENGTH))
uint CBuffer_PCG_PBD_Velocity_AddrAt(uint particleId, uint subbuff)
{
	uint subbuffOffset = (subbuff % 2u) * (PBD_PARTICLE_VELOCITY_SUB_LENGTH);
	return PBD_PARTICLE_VELOCITY_BUFFER +
		subbuffOffset + 
		(particleId << BITS_PBD_PARTICLE_VELOCITY_STRIDE_OFFSET);
}



#define BITS_PBD_PARTICLE_STATE_STRIDE_OFFSET ((BITS_WORD_OFFSET))
#define PBD_PARTICLE_STATE_BUFFER (PBD_PARTICLE_VELOCITY_BUFFER + PBD_PARTICLE_VELOCITY_LENGTH)
#define PBD_PARTICLE_STATE_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_PARTICLE_STATE_STRIDE_OFFSET))
#define NUM_SUBBUFF_PBD_PARTICLE_STATE 2u
#define PBD_PARTICLE_STATE_LENGTH (NUM_SUBBUFF_PBD_PARTICLE_STATE * PBD_PARTICLE_STATE_SUB_LENGTH)
uint CBuffer_PCG_PBD_State_AddrAt(uint particleId, uint subbuff)
{
	uint subbuffOffset = subbuff * PBD_PARTICLE_STATE_SUB_LENGTH;
	return PBD_PARTICLE_STATE_BUFFER
		+ subbuffOffset
		+ (particleId << BITS_PBD_PARTICLE_STATE_STRIDE_OFFSET);
}
uint CBuffer_PCG_PBD_State_AddrAt(uint particleId)
{
	return CBuffer_PCG_PBD_State_AddrAt(
		particleId, ID_SubBuff_Active(ParticleState)
	);
}
#define Subbuff_PtclState_Resampler 1u


#define BIT_BEG_PTCL_RANK 0
#define BIT_LEN_PTCL_RANK 24
// 
#define BIT_BEG_PTCL_TAIL ((BIT_BEG_PTCL_RANK + BIT_LEN_PTCL_RANK))
#define BIT_LEN_PTCL_TAIL 1
//
#define BIT_BEG_PTCL_LOOP ((BIT_BEG_PTCL_TAIL + BIT_LEN_PTCL_TAIL))
#define BIT_LEN_PTCL_LOOP 1
//
#define BIT_BEG_PTCL_HIDE ((BIT_BEG_PTCL_LOOP + BIT_LEN_PTCL_LOOP))
#define BIT_LEN_PTCL_HIDE 1

void SetParticleState_Internal(
    uint attrVal, uint attrBitBeg, uint attrBitLen, inout uint state)
{
    state &= (GEN_BIT_CLEAR_MASK(attrBitBeg, attrBitLen));
    state |= (attrVal << attrBitBeg);
}
#define SetParticleState(tag, attr_val, state) \
	SetParticleState_Internal(attr_val, CAT(BIT_BEG_, tag), CAT(BIT_LEN_, tag), state) \
	

uint GetParticleState_Internal(uint attrBitBeg, uint attrBitLen, uint sampleAttr)
{
    return EXTRACT_BITS(sampleAttr, attrBitBeg, attrBitLen);
}
#define GetParticleState(tag, state) \
	GetParticleState_Internal(CAT(BIT_BEG_, tag), CAT(BIT_LEN_, tag), state) \



#define BITS_PBD_SPRING_LENGTH_STRIDE_OFFSET ((BITS_WORD_OFFSET))
#define PBD_SPRING_LENGTH_BUFFER (PBD_PARTICLE_STATE_BUFFER + PBD_PARTICLE_STATE_LENGTH)
#define PBD_SPRING_LENGTH_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_SPRING_LENGTH_STRIDE_OFFSET))
#define NUM_SUBBUFF_PBD_SPRING_LENGTH (2u)
#define PBD_SPRING_LENGTH_LENGTH (NUM_SUBBUFF_PBD_SPRING_LENGTH * PBD_SPRING_LENGTH_SUB_LENGTH)
// Spring Length
uint CBuffer_PCG_PBD_StringLength_AddrAt(uint particleId, uint subbuff)
{
	uint subbuffOffset = subbuff * PBD_SPRING_LENGTH_SUB_LENGTH;
	return PBD_SPRING_LENGTH_BUFFER
		+ subbuffOffset
		+ (particleId << BITS_PBD_SPRING_LENGTH_STRIDE_OFFSET);
}
uint CBuffer_PCG_PBD_StringLength_AddrAt(uint particleId)
{
	return CBuffer_PCG_PBD_StringLength_AddrAt(
		particleId, ID_SubBuff_Active(SpringLength)
	);
}
#define Subbuff_SpringLen_Resampler 1u


#define BITS_PBD_PARTICLE_TANGENT_STRIDE_OFFSET ((BITS_DWORD_OFFSET))
#define PBD_PARTICLE_TANGENT_BUFFER (PBD_SPRING_LENGTH_BUFFER + PBD_SPRING_LENGTH_LENGTH)
#define NUM_SUBBUFF_PBD_PARTICLE_TANGENT (2u)
#define PBD_PARTICLE_TANGENT_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_PARTICLE_TANGENT_STRIDE_OFFSET))
#define PBD_PARTICLE_TANGENT_LENGTH ((NUM_SUBBUFF_PBD_PARTICLE_TANGENT * PBD_PARTICLE_TANGENT_SUB_LENGTH))
// Spring Length
uint CBuffer_PCG_PBD_ParticleTangent_AddrAt(uint particleId, uint subbuff)
{
	uint subbuffOffset = subbuff * PBD_PARTICLE_TANGENT_SUB_LENGTH;
	return PBD_PARTICLE_TANGENT_BUFFER
		+ subbuffOffset
		+ (particleId << BITS_PBD_PARTICLE_TANGENT_STRIDE_OFFSET);
}
uint CBuffer_PCG_PBD_ParticleTangent_AddrAt(uint particleId)
{
	return CBuffer_PCG_PBD_ParticleTangent_AddrAt(
		particleId, ID_SubBuff_Active(ParticleTangent)
	);
}

#define BITS_PBD_TEMPORAL_VISIBILITY_STRIDE_OFFSET ((BITS_WORD_OFFSET))
#define PBD_TEMPORAL_VISIBILITY_BUFFER (PBD_PARTICLE_TANGENT_BUFFER + PBD_PARTICLE_TANGENT_LENGTH)
#define NUM_SUBBUFF_PBD_TEMPORAL_VISIBILITY (2u)
#define PBD_TEMPORAL_VISIBILITY_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_TEMPORAL_VISIBILITY_STRIDE_OFFSET))
#define PBD_TEMPORAL_VISIBILITY_LENGTH ((NUM_SUBBUFF_PBD_TEMPORAL_VISIBILITY * PBD_TEMPORAL_VISIBILITY_SUB_LENGTH))
// Spring Length
uint CBuffer_PCG_PBD_TemporalVisibility_AddrAt(uint particleId, uint subbuff)
{
	uint subbuffOffset = subbuff * PBD_TEMPORAL_VISIBILITY_SUB_LENGTH;
	return PBD_TEMPORAL_VISIBILITY_BUFFER
		+ subbuffOffset
		+ (particleId << BITS_PBD_TEMPORAL_VISIBILITY_STRIDE_OFFSET);
}
uint CBuffer_PCG_PBD_TemporalVisibility_AddrAt(uint particleId)
{
	return CBuffer_PCG_PBD_TemporalVisibility_AddrAt(
		particleId, ID_SubBuff_Active(ParticleTemporalVisibility)
	);
}


#define BITS_PBD_CONSTRAINT_STRETCH_STRIDE_OFFSET ((BITS_WORD_OFFSET))
#define PBD_CONSTRAINT_STRETCH_BUFFER (PBD_TEMPORAL_VISIBILITY_BUFFER + PBD_TEMPORAL_VISIBILITY_LENGTH)
#define PBD_CONSTRAINT_STRETCH_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_CONSTRAINT_STRETCH_STRIDE_OFFSET))
// Stretch constraint (ptclId, ptclId + 1)
uint CBuffer_PCG_PBD_Constraint_Stretch_AddrAt(uint particleId)
{
	return PBD_CONSTRAINT_STRETCH_BUFFER +
		(particleId << BITS_PBD_CONSTRAINT_STRETCH_STRIDE_OFFSET);
}


#define PBD_CONSTRAINT_LRA_STRIDE (((3 << BITS_WORD_OFFSET)))
#define PBD_CONSTRAINT_LRA_BUFFER (PBD_CONSTRAINT_STRETCH_BUFFER + PBD_CONSTRAINT_STRETCH_LENGTH)
#define PBD_CONSTRAINT_LRA_LENGTH ((MAX_PBD_PARTICLE_COUNT * PBD_CONSTRAINT_LRA_STRIDE))
// Long-Range-Attachment (ptclId)
uint CBuffer_PCG_PBD_Constraint_LRA_AddrAt(uint particleId)
{
	return PBD_CONSTRAINT_LRA_BUFFER +
		(particleId * PBD_CONSTRAINT_LRA_STRIDE);
}
struct LRAConstraint
{
	float maxDist;
	float2 pinPoint;

	void cstr(float maxDistIn, float2 pinPointIn)
		{ maxDist = maxDistIn; pinPoint = pinPointIn;  }

	void SetInvalid() { maxDist = -1; }
	bool Invalid() { return maxDist < 0; }

	uint3 Encode()
		{ return asuint(float3(pinPoint, maxDist)); }
	void Decode(uint3 encode)
		{ pinPoint = asfloat(encode.xy); maxDist = asfloat(encode.z); }
};



#define BITS_PBD_SM_A_SAT_STRIDE_OFFSET (((BITS_BLOCK_OFFSET)))
#define PBD_SM_A_SAT_BUFFER (PBD_CONSTRAINT_LRA_BUFFER + PBD_CONSTRAINT_LRA_LENGTH)
#define PBD_SM_A_SAT_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_SM_A_SAT_STRIDE_OFFSET))
// Shape Matching: Summed Array Table (ptclId) Affine Matrix Aj
uint CBuffer_PCG_PBD_ShapeMatch_Aj_SAT_AddrAt(uint particleId)
{
	return PBD_SM_A_SAT_BUFFER +
		(particleId << BITS_PBD_SM_A_SAT_STRIDE_OFFSET);
}

#define BITS_PBD_SM_T_SAT_STRIDE_OFFSET (((BITS_BLOCK_OFFSET)))
#define PBD_SM_T_SAT_BUFFER (PBD_SM_A_SAT_BUFFER + PBD_SM_A_SAT_LENGTH)
#define PBD_SM_T_SAT_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_SM_T_SAT_STRIDE_OFFSET))
// Shape Matching: Summed Array Table (ptclId) Mass Center Tj
uint CBuffer_PCG_PBD_ShapeMatch_Tj_SAT_AddrAt(uint particleId)
{
	return PBD_SM_T_SAT_BUFFER +
		(particleId << BITS_PBD_SM_T_SAT_STRIDE_OFFSET);
}

#define PBD_SM_A0j_SAT_STRIDE (((3 << BITS_WORD_OFFSET)))
#define PBD_SM_A0j_SAT_BUFFER (PBD_SM_T_SAT_BUFFER + PBD_SM_T_SAT_LENGTH)
#define PBD_SM_A0j_SAT_LENGTH ((MAX_PBD_PARTICLE_COUNT * PBD_SM_A0j_SAT_STRIDE))
// Shape Matching: Summed Array Table (ptclId) Mass Center Tj
uint CBuffer_PCG_PBD_ShapeMatch_A0j_SAT_AddrAt(uint particleId)
{
	return PBD_SM_A0j_SAT_BUFFER +
		(particleId * PBD_SM_A0j_SAT_STRIDE);
}

#define BITS_PBD_SM_TRANSFORM_SAT_STRIDE_OFFSET (((BITS_DWORD_OFFSET)))
#define PBD_SM_TRANSFORM_SAT_BUFFER (PBD_SM_A0j_SAT_BUFFER + PBD_SM_A0j_SAT_LENGTH)
#define PBD_SM_TRANSFORM_SAT_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_SM_TRANSFORM_SAT_STRIDE_OFFSET))
// Shape Matching: Summed Array Table (ptclId) Goal Coord gi
uint CBuffer_PCG_PBD_ShapeMatch_Transform_SAT_AddrAt(uint particleId)
{
	return PBD_SM_TRANSFORM_SAT_BUFFER +
		(particleId << BITS_PBD_SM_TRANSFORM_SAT_STRIDE_OFFSET);
}

#define BITS_PBD_SM_ROTATION_SAT_STRIDE_OFFSET (((BITS_BLOCK_OFFSET)))
#define PBD_SM_ROTATION_SAT_BUFFER (PBD_SM_TRANSFORM_SAT_BUFFER + PBD_SM_TRANSFORM_SAT_LENGTH)
#define PBD_SM_ROTATION_SAT_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_SM_ROTATION_SAT_STRIDE_OFFSET))
// Shape Matching: Summed Array Table (ptclId) Goal Coord gi
uint CBuffer_PCG_PBD_ShapeMatch_Rotation_SAT_AddrAt(uint particleId)
{
	return PBD_SM_ROTATION_SAT_BUFFER +
		(particleId << BITS_PBD_SM_ROTATION_SAT_STRIDE_OFFSET);
}

#define PBD_SM_PLASTIC_DEFORM_SAT_STRIDE (((3 << BITS_WORD_OFFSET)))
#define PBD_SM_PLASTIC_DEFORM_SAT_BUFFER (PBD_SM_ROTATION_SAT_BUFFER + PBD_SM_ROTATION_SAT_LENGTH)
#define PBD_SM_PLASTIC_DEFORM_SAT_LENGTH ((MAX_PBD_PARTICLE_COUNT * PBD_SM_PLASTIC_DEFORM_SAT_STRIDE))
// Shape Matching: Plastic Deform
uint CBuffer_PCG_PBD_ShapeMatch_PlasticDeform_AddrAt(uint particleId)
{
	return PBD_SM_PLASTIC_DEFORM_SAT_BUFFER +
		(particleId * PBD_SM_PLASTIC_DEFORM_SAT_STRIDE);
}

#define BITS_PBD_SM_PLASTIC_HARDEN_STRIDE_OFFSET (((BITS_WORD_OFFSET)))
#define PBD_SM_PLASTIC_HARDEN_BUFFER (PBD_SM_PLASTIC_DEFORM_SAT_BUFFER + PBD_SM_PLASTIC_DEFORM_SAT_LENGTH)
#define PBD_SM_PLASTIC_HARDEN_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_SM_PLASTIC_HARDEN_STRIDE_OFFSET))
// Shape Matching: Work Hardening for Plastic Deform
// Essentially increase the deform yield threshold along time
uint CBuffer_PCG_PBD_ShapeMatch_PlasticYield_AddrAt(uint particleId)
{
	return PBD_SM_PLASTIC_HARDEN_BUFFER +
		(particleId << BITS_PBD_SM_PLASTIC_HARDEN_STRIDE_OFFSET);
}


float FrobeniusNorm2x2(float2x2 Sp)
{
	float Sp_l2_norm = 
		dot(Sp._11_22, Sp._11_22)
		+ dot(Sp._12_21, Sp._12_21);
	return Sp_l2_norm;
}
void UpdatePlasticDeform(
	inout float2x2 Sp, float2x2 S, 
	float c_yield, float c_creep, float c_max, 
	float dt
){
	float S_norm = FrobeniusNorm2x2(S);
	if (c_yield < S_norm)
	{
#define I float2x2(1, 0, 0, 1)
		Sp = I + mul(dt*c_creep*(S - I), Sp); // temporal update

		float plasticity = FrobeniusNorm2x2(Sp - I);
		if (c_max < plasticity)
		{ // restrict plastic deformation
			Sp = I + (c_max*(Sp - I) / plasticity);	
		}

		Sp /= sqrt(determinant(Sp)); // conserve volume
		
#undef I
	}
}


//					Convolution Table
//////////////////////////////////////////////////////////////////////////////
#define BITS_PTCL_CONV_PATCH_STRIDE_OFFSET (BITS_WORD_OFFSET)
// Maximum supported convolution radius 
#define PTCL_CONV_RADIUS 32
#define PTCL_CONV_MAX_NUM_GROUPS 1024
#define PTCL_CONV_NUM_PATCHES_PER_GROUP ((PTCL_CONV_RADIUS * 2))
#define PTCL_CONV_MAX_NUM_PATCHES (PTCL_CONV_MAX_NUM_GROUPS * PTCL_CONV_NUM_PATCHES_PER_GROUP)

#define PTCL_CONV_PATCH_BUFFER (PBD_SM_PLASTIC_HARDEN_BUFFER + PBD_SM_PLASTIC_HARDEN_LENGTH)
#define PTCL_CONV_PATCH_STRIDE ((1 << BITS_PTCL_CONV_PATCH_STRIDE_OFFSET))
#define PTCL_CONV_PATCH_LENGTH (PTCL_CONV_MAX_NUM_PATCHES * PTCL_CONV_PATCH_STRIDE)


uint CBuffer_PCG_PBD_ConvPatchTable_AddrAt(
	uint gIdx, uint patchId
) {
	return PTCL_CONV_PATCH_BUFFER +
		(((gIdx * PTCL_CONV_NUM_PATCHES_PER_GROUP) + patchId)
			<< BITS_PTCL_CONV_PATCH_STRIDE_OFFSET
		);
}

#define BITS_PBD_CLOSEST_STAMP_STRIDE_OFFSET (((BITS_DWORD_OFFSET)))
#define PBD_CLOSEST_STAMP_BUFFER (PTCL_CONV_PATCH_BUFFER + PTCL_CONV_PATCH_LENGTH)
#define PBD_CLOSEST_STAMP_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_CLOSEST_STAMP_STRIDE_OFFSET))
uint CBuffer_PCG_PBD_ClosestStampDataCache_AddrAt(uint particleId)
{
	return PBD_CLOSEST_STAMP_BUFFER + 
		(particleId << BITS_PBD_CLOSEST_STAMP_STRIDE_OFFSET);
}
uint2 EncodeClosestStampData(
	bool foundStamp, uint stampId, uint2 stampCoord)
{
	uint2 encoded;
	encoded.x = ((stampId << 1) | foundStamp);
	encoded.y = PackPixelCoord(stampCoord);

	return encoded;
}
void DecodeClosestStampData(
	uint2 encoded, 
	out bool foundStamp, out uint stampId, out uint2 stampCoord
){
	stampId = (encoded.x >> 1);
	foundStamp = (encoded.x & 1);
	stampCoord = DecodePixelCoord(encoded.y);
}


#define BITS_PBD_CLOSEST_EDGE_STRIDE_OFFSET (((BITS_WORD_OFFSET)))
#define PBD_CLOSEST_EDGE_BUFFER (PBD_CLOSEST_STAMP_BUFFER + PBD_CLOSEST_STAMP_LENGTH)
#define PBD_CLOSEST_EDGE_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_CLOSEST_EDGE_STRIDE_OFFSET))
uint CBuffer_PCG_PBD_ClosestPixelEdgeCache_AddrAt(uint particleId)
{
	return PBD_CLOSEST_EDGE_BUFFER +
		(particleId << BITS_PBD_CLOSEST_EDGE_STRIDE_OFFSET);
}
uint EncodeClosestPixelEdgeData(
	bool foundEdgeOnStroke, uint edgeId)
{
	uint encoded;
	encoded = ((edgeId << 1) | foundEdgeOnStroke);

	return encoded;
}
void DecodeClosestPixelEdgeData(
	uint encoded, out bool foundEdgeOnStroke, out uint edgeId)
{
	edgeId = (encoded >> 1);
	foundEdgeOnStroke = (encoded & 1);
}


#define BITS_PBD_SDF_FINE_GRAINED_STRIDE_OFFSET (((BITS_DWORD_OFFSET)))
#define PBD_SDF_FINE_GRAINED_BUFFER (PBD_CLOSEST_EDGE_BUFFER + PBD_CLOSEST_EDGE_LENGTH)
#define PBD_SDF_FINE_GRAINED_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_SDF_FINE_GRAINED_STRIDE_OFFSET))
// Valid only after <<SpringParticleClosestStampOptimize_Main>>
// with _FineGrainedMatch on
uint CBuffer_PCG_PBD_SubPixelSDFCache_AddrAt(uint particleId)
{
	return PBD_SDF_FINE_GRAINED_BUFFER +
		(particleId << BITS_PBD_SDF_FINE_GRAINED_STRIDE_OFFSET);
}


#define BITS_PBD_CULL_INFO_STRIDE_OFFSET (((BITS_WORD_OFFSET)))
#define PBD_CULL_INFO_BUFFER (PBD_SDF_FINE_GRAINED_BUFFER + PBD_SDF_FINE_GRAINED_LENGTH)
#define NUM_SUBBUFF_PBD_CULL_INFO_SUBBUFF 1u
#define PBD_CULL_INFO_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_CULL_INFO_STRIDE_OFFSET))
#define PBD_CULL_INFO_LENGTH ((NUM_SUBBUFF_PBD_CULL_INFO_SUBBUFF * PBD_CULL_INFO_SUB_LENGTH))
// Cull booleans from each particle culling pass
uint CBuffer_PCG_PBD_ParticleCullInfo_AddrAt(uint particleId)
{
	return PBD_CULL_INFO_BUFFER
		+ (particleId << BITS_PBD_CULL_INFO_STRIDE_OFFSET);
}
struct ParticleCullInfo_ORI
{
	float visibility;
};

#define BIT_BEG_PTCL_CULL_ORI 0u
#define BIT_LEN_PTCL_CULL_ORI 1u
// 
#define BIT_BEG_PTCL_CULL_SDF (BIT_BEG_PTCL_CULL_ORI + BIT_LEN_PTCL_CULL_ORI)
#define BIT_LEN_PTCL_CULL_SDF 1u

#define SetParticleCullBits(tag, attr_val, cullBits) \
	SetParticleState_Internal(attr_val, CAT(BIT_BEG_, tag), CAT(BIT_LEN_, tag), cullBits) \

#define GetParticleCullBits(tag, cullBits) \
	GetParticleState_Internal(CAT(BIT_BEG_, tag), CAT(BIT_LEN_, tag), cullBits) \


bool ParticleCullingInfo_To_State_isHidden(uint cullBits)
{
	bool oriCulled = GetParticleCullBits(PTCL_CULL_ORI, cullBits);
	bool sdfCulled = GetParticleCullBits(PTCL_CULL_SDF, cullBits);

	return oriCulled || sdfCulled;
}


#define BITS_PBD_ALLOC_INFO_STRIDE_OFFSET (((BITS_WORD_OFFSET)))
#define PBD_ALLOC_INFO_BUFFER ((PBD_CULL_INFO_BUFFER + PBD_CULL_INFO_LENGTH))
#define PBD_ALLOC_INFO_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_ALLOC_INFO_STRIDE_OFFSET))
// Cull booleans from each particle culling pass
uint CBuffer_PCG_PBD_ParticleAllocInfo_AddrAt(uint particleId)
{
	return PBD_ALLOC_INFO_BUFFER
		+ (particleId << BITS_PBD_ALLOC_INFO_STRIDE_OFFSET);
}

#define BIT_BEG_PTCL_ALLOC_DISCARD 0u
#define BIT_LEN_PTCL_ALLOC_DISCARD 1u
// 
#define BIT_BEG_PTCL_ALLOC_RESAMPLE ((BIT_BEG_PTCL_ALLOC_DISCARD + BIT_LEN_PTCL_ALLOC_DISCARD))
#define BIT_LEN_PTCL_ALLOC_RESAMPLE 1u
// 
#define BIT_BEG_PTCL_ALLOC_EXTEND ((BIT_BEG_PTCL_ALLOC_RESAMPLE + BIT_LEN_PTCL_ALLOC_RESAMPLE))
#define BIT_LEN_PTCL_ALLOC_EXTEND 1u

void SetParticleaAllocBit_Internal(
	uint attrVal, uint attrBitBeg, uint attrBitLen, inout uint allocBits)
{
	allocBits &= (GEN_BIT_CLEAR_MASK(attrBitBeg, attrBitLen));
	allocBits |= (attrVal << attrBitBeg);
}
#define SetParticleAllocBit(tag, attr_val, allocBits) \
	SetParticleaAllocBit_Internal(attr_val, CAT(BIT_BEG_, tag), CAT(BIT_LEN_, tag), allocBits) \

uint GetParticleaAllocBit_Internal(uint attrBitBeg, uint attrBitLen, uint allocBits)
{
	return EXTRACT_BITS(allocBits, attrBitBeg, attrBitLen);
}
#define GetParticleAllocBit(tag, allocBits) \
	GetParticleaAllocBit_Internal(CAT(BIT_BEG_, tag), CAT(BIT_LEN_, tag), allocBits) \

 

#define BITS_PBD_RESEG_KEY_STRIDE_OFFSET (((BITS_WORD_OFFSET)))
#define PBD_RESEG_KEY_BUFFER ((PBD_ALLOC_INFO_BUFFER + PBD_ALLOC_INFO_LENGTH))
#define PBD_RESEG_KEY_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_RESEG_KEY_STRIDE_OFFSET))
#define NUM_PBD_RESEG_KEY_SUBBUFF 2u
#define PBD_RESEG_KEY_LENGTH ((NUM_PBD_RESEG_KEY_SUBBUFF * PBD_RESEG_KEY_SUB_LENGTH))
uint CBuffer_PCG_PBD_SegmentationKey_AddrAt(uint particleId, uint subbuff)
{
	uint subbuffOffset = subbuff * PBD_RESEG_KEY_SUB_LENGTH;
	return PBD_RESEG_KEY_BUFFER
		+ subbuffOffset
		+ (particleId << BITS_PBD_RESEG_KEY_STRIDE_OFFSET);
}
// Segmentation Input -------------
#define PBD_SEGKEY_IN_ORI_CULL 0
#define PBD_SEGKEY_IN_STROKE_VOTE 1
// --------------------------------

// Segmentation Output ------------
#define PBD_SEG_OUT_PTCL_STATE 0 // output to state buffer
// output to temp seg buffer
// CBuffer_PCG_PBD_TempSegRank/Length_AddrAt
#define PBD_SEG_OUT_PTCL_STK_VOTE 1 
// --------------------------------

// any culled seg tagged with this key
#define PTCL_SEG_KEY_CULLED 0u/*0xfffffff3*/


#define BITS_PBD_STROKE_SEG_RANK_STRIDE_OFFSET (((BITS_WORD_OFFSET)))
#define PBD_STROKE_SEG_RANK_BUFFER (PBD_RESEG_KEY_BUFFER + PBD_RESEG_KEY_LENGTH)
#define NUM_SUBBUFF_PBD_STROKE_SEG_RANK (1u)
#define PBD_STROKE_SEG_RANK_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_STROKE_SEG_RANK_STRIDE_OFFSET))
#define PBD_STROKE_SEG_RANK_LENGTH ((NUM_SUBBUFF_PBD_STROKE_SEG_RANK * PBD_STROKE_SEG_RANK_SUB_LENGTH))
uint CBuffer_PCG_PBD_TempSegRank_AddrAt(uint particleId, uint subbuff)
{
	uint subbuffOffset = (subbuff - 1u) * PBD_STROKE_SEG_RANK_SUB_LENGTH;
	return PBD_STROKE_SEG_RANK_BUFFER
		+ subbuffOffset
		+ (particleId << BITS_PBD_STROKE_SEG_RANK_STRIDE_OFFSET);
}

#define BITS_PBD_STROKE_SEG_LENGTH_STRIDE_OFFSET (((BITS_WORD_OFFSET)))
#define PBD_STROKE_SEG_LENGTH_BUFFER (PBD_STROKE_SEG_RANK_BUFFER + PBD_STROKE_SEG_RANK_LENGTH)
#define NUM_SUBBUFF_PBD_STROKE_SEG_LENGTH (1u)
#define PBD_STROKE_SEG_LENGTH_SUB_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_STROKE_SEG_LENGTH_STRIDE_OFFSET))
#define PBD_STROKE_SEG_LENGTH_LENGTH ((NUM_SUBBUFF_PBD_STROKE_SEG_LENGTH * PBD_STROKE_SEG_LENGTH_SUB_LENGTH))
uint CBuffer_PCG_PBD_TempSegLength_AddrAt(uint particleId, uint subbuff)
{
	uint subbuffOffset = (subbuff - 1u) * PBD_STROKE_SEG_RANK_SUB_LENGTH;
	return PBD_STROKE_SEG_LENGTH_BUFFER
		+ subbuffOffset
		+ (particleId << BITS_PBD_STROKE_SEG_LENGTH_STRIDE_OFFSET);
}


#define BITS_PBD_TEMP_BUFF_0_STRIDE_OFFSET (((BITS_WORD_OFFSET)))
#define PBD_TEMP_BUFF_0_BUFFER (PBD_STROKE_SEG_LENGTH_BUFFER + PBD_STROKE_SEG_LENGTH_LENGTH)
#define PBD_TEMP_BUFF_0_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_TEMP_BUFF_0_STRIDE_OFFSET))
uint CBuffer_PCG_PBD_TempBuffer_0_AddrAt(uint particleId)
{
	return PBD_TEMP_BUFF_0_BUFFER +
		(particleId << BITS_PBD_TEMP_BUFF_0_STRIDE_OFFSET);
}

#define BITS_PBD_TEMP_BUFF_1_STRIDE_OFFSET (((BITS_WORD_OFFSET)))
#define PBD_TEMP_BUFF_1_BUFFER (PBD_TEMP_BUFF_0_BUFFER + PBD_TEMP_BUFF_0_LENGTH)
#define PBD_TEMP_BUFF_1_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_TEMP_BUFF_1_STRIDE_OFFSET))
uint CBuffer_PCG_PBD_TempBuffer_1_AddrAt(uint particleId)
{
	return PBD_TEMP_BUFF_1_BUFFER +
		(particleId << BITS_PBD_TEMP_BUFF_1_STRIDE_OFFSET);
}

#define BITS_PBD_TEMP_BUFF_2_STRIDE_OFFSET (((BITS_WORD_OFFSET)))
#define PBD_TEMP_BUFF_2_BUFFER (PBD_TEMP_BUFF_1_BUFFER + PBD_TEMP_BUFF_1_LENGTH)
#define PBD_TEMP_BUFF_2_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_TEMP_BUFF_2_STRIDE_OFFSET))
uint CBuffer_PCG_PBD_TempBuffer_2_AddrAt(uint particleId)
{
	return PBD_TEMP_BUFF_2_BUFFER +
		(particleId << BITS_PBD_TEMP_BUFF_2_STRIDE_OFFSET);
}

#define BITS_PBD_X2TEMP_BUFFER_0_STRIDE_OFFSET (((BITS_DWORD_OFFSET)))
#define PBD_X2TEMP_BUFFER_0_BUFFER (PBD_TEMP_BUFF_2_BUFFER + PBD_TEMP_BUFF_2_LENGTH)
#define PBD_X2TEMP_BUFFER_0_LENGTH ((MAX_PBD_PARTICLE_COUNT << BITS_PBD_X2TEMP_BUFFER_0_STRIDE_OFFSET))
uint CBuffer_PCG_PBD_x2TempBuffer_0_AddrAt(uint particleId)
{
	return PBD_X2TEMP_BUFFER_0_BUFFER +
		(particleId << BITS_PBD_X2TEMP_BUFFER_0_STRIDE_OFFSET);
}




#endif /* B4BDACBF_2971_4974_A449_FEFCC97BB7C2135 */
