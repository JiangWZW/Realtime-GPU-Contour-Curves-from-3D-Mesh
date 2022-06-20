#ifndef PBDPARTICLELOADSTORESHORTCUTS_INCLUDED
#define PBDPARTICLELOADSTORESHORTCUTS_INCLUDED

#include "./ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"

#ifdef BUFFER_RW
	RWByteAddressBuffer CBuffer_BufferRawProceduralGeometry;
#else
#	ifdef BUFFER_R
		ByteAddressBuffer CBuffer_BufferRawProceduralGeometry;
#	endif
#endif


float2 LoadParticlePosition(uint ptclId, uint subbuff)
{
	return asfloat(
		CBuffer_BufferRawProceduralGeometry.Load2(
			CBuffer_PCG_PBD_Coord_AddrAt(ptclId, subbuff)));
}
float2 LoadParticlePosition(uint ptclId)
{
	return asfloat(
		CBuffer_BufferRawProceduralGeometry.Load2(
			CBuffer_PCG_PBD_Coord_AddrAt(ptclId, 
				ID_SubBuff_Active(ParticlePosition)))
	);
}
void StoreParticlePosition(uint ptclId, uint subbuff, float2 pos)
{
	CBuffer_BufferRawProceduralGeometry.Store2(
		CBuffer_PCG_PBD_Coord_AddrAt(
			ptclId, subbuff
		),
		asuint(pos)
	);
}
void StoreParticlePosition(uint ptclId, float2 pos)
{
	StoreParticlePosition(
		ptclId, ID_SubBuff_Active(ParticlePosition), pos
	);
}


float LoadParticleTemporalVisibility(uint ptclId, uint subbuff)
{
	return asfloat(
		CBuffer_BufferRawProceduralGeometry.Load(
			CBuffer_PCG_PBD_TemporalVisibility_AddrAt(ptclId, subbuff)
		)
	);
}
float LoadParticleTemporalVisibility(uint ptclId)
{
	return LoadParticleTemporalVisibility(
		ptclId, ID_SubBuff_Active(ParticleTemporalVisibility)
	);
}
void StoreParticleTemporalVisibility(uint ptclId, uint subbuff, float visibility)
{
	CBuffer_BufferRawProceduralGeometry.Store(
		CBuffer_PCG_PBD_TemporalVisibility_AddrAt(ptclId, subbuff),
		asuint(visibility)
	);
}
void StoreParticleTemporalVisibility(uint ptclId, float visibility)
{
	StoreParticleTemporalVisibility(
		ptclId, ID_SubBuff_Active(ParticleTemporalVisibility), 
		visibility
	);
}


float2 LoadParticleTangent(uint ptclId, uint subbuff)
{
	return asfloat(
		CBuffer_BufferRawProceduralGeometry.Load2(
			CBuffer_PCG_PBD_ParticleTangent_AddrAt(ptclId, subbuff)));
}
float2 LoadParticleTangent(uint ptclId)
{
	return LoadParticleTangent(
		ptclId, ID_SubBuff_Active(ParticleTangent)
	);
}
void StoreParticleTangent(uint ptclId, uint subbuff, float2 tangent)
{
	CBuffer_BufferRawProceduralGeometry.Store2(
		CBuffer_PCG_PBD_ParticleTangent_AddrAt(ptclId, subbuff),
		asuint(tangent)
	);
}
void StoreParticleTangent(uint ptclId, float2 tangent)
{
	StoreParticleTangent(
		ptclId, ID_SubBuff_Active(ParticleTangent), tangent
	);
}


// TODO: upgrade to multi-buffering
void StoreParticleVelocity(uint ptclId, uint subbuff, float2 velocity)
{
	CBuffer_BufferRawProceduralGeometry.Store2(
		CBuffer_PCG_PBD_Velocity_AddrAt(ptclId, 0),
		asuint(float2(.0f, .0f))
	);
}



uint LoadParticleState(uint ptclId, uint subbuff)
{
	return CBuffer_BufferRawProceduralGeometry.Load(
		CBuffer_PCG_PBD_State_AddrAt(ptclId, subbuff)
	);
}
uint LoadParticleState(uint ptclId)
{
	return LoadParticleState(ptclId, ID_SubBuff_Active(ParticleState));
}
void StoreParticleState(uint ptclId, uint subbuff, uint state)
{
	CBuffer_BufferRawProceduralGeometry.Store(
		CBuffer_PCG_PBD_State_AddrAt(ptclId, subbuff),
		state
	);
}
void StoreParticleState(uint ptclId, uint state)
{
	StoreParticleState(ptclId, ID_SubBuff_Active(ParticleState), state);
}


uint LoadSpringLength(uint ptclId, uint subbuff)
{
	return CBuffer_BufferRawProceduralGeometry.Load(
		CBuffer_PCG_PBD_StringLength_AddrAt(ptclId, subbuff)
	);
}
uint LoadSpringLength(uint ptclId)
{
	return LoadSpringLength(ptclId, ID_SubBuff_Active(SpringLength));
}
void StoreSpringLength(uint ptclId, uint subbuff, uint springLen)
{
	CBuffer_BufferRawProceduralGeometry.Store(
		CBuffer_PCG_PBD_StringLength_AddrAt(ptclId, subbuff),
		springLen
	);
}
void StoreSpringLength(uint ptclId, uint springLen)
{
	StoreSpringLength(
		ptclId, ID_SubBuff_Active(SpringLength), springLen
	);
}


AABB_CenterLen LoadSpringAABB(uint ptclId, uint subbuff)
{
	uint centerU32 = CBuffer_BufferRawProceduralGeometry.Load(
		CBuffer_PCG_PBD_AABB_Center_AddrAt(ptclId, subbuff)
	);
	uint sizeXYU32 = CBuffer_BufferRawProceduralGeometry.Load(
		CBuffer_PCG_PBD_AABB_XYSize_AddrAt(ptclId, subbuff)
	);
	AABB_CenterLen aabb;
	aabb.DecodeCenter(centerU32);
	aabb.DecodeSizeXY(sizeXYU32);

	return aabb;
}
AABB_CenterLen LoadSpringAABB(uint ptclId)
{
	return LoadSpringAABB(
		ptclId, ID_SubBuff_Active(SpringAABB)
	);
}
void StoreSpringAABB(uint ptclId, uint subbuff, AABB_CenterLen aabb)
{
	CBuffer_BufferRawProceduralGeometry.Store(
		CBuffer_PCG_PBD_AABB_Center_AddrAt(ptclId, subbuff),
		aabb.EncodeCenter()
	);
	CBuffer_BufferRawProceduralGeometry.Store(
		CBuffer_PCG_PBD_AABB_XYSize_AddrAt(ptclId, subbuff),
		aabb.EncodeSizeXY()
	);
}
void StoreSpringAABB(uint ptclId, AABB_CenterLen aabb)
{
	StoreSpringAABB(ptclId, ID_SubBuff_Active(SpringAABB), aabb);
}



// Segmentation Keys
bool LoadSegmentCullFlag(uint ptclId, uint ptclCount)
{
	uint cullFlag = CBuffer_BufferRawProceduralGeometry.Load(
		CBuffer_PCG_PBD_SegmentationKey_AddrAt(
			ptclId,
			CBuffer_SubBuff_ParticleSegmentCullingKey
		)
	);

	return (ptclId < ptclCount) ? (cullFlag == PTCL_SEG_KEY_CULLED) : true;
}

uint LoadParticleCullInfo(uint ptclId)
{
	return CBuffer_BufferRawProceduralGeometry.Load(
		CBuffer_PCG_PBD_ParticleCullInfo_AddrAt(ptclId)
	);
}



#ifdef BUFFER_RW
#	undef BUFFER_RW
#endif
#ifdef BUFFER_R
#	undef BUFFER_R
#endif

#endif /* PBDPARTICLELOADSTORESHORCUTS_INCLUDED */
