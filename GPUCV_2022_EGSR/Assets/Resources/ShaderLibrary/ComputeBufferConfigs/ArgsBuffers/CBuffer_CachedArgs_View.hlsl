#ifndef CBUFFER_CACHEDARGS_VIEW_INCLUDED
#define CBUFFER_CACHEDARGS_VIEW_INCLUDED

// ------- args buffer #0 ----------
#define ContourCounter      0
#define SegmentCounter      1
#define PixelEdgeCounter    1
// Share the same slot
#define ViewEdgeCounter     2
#define VisibleSegCounter   2
#define PatchCounter        2
#define PathCounter			2

#define PixelCounter        3

// ------- args buffer 1 ----------
#define ScanCounter0    0
#define ScanCounter1    1
#define NumGroups0      2
#define CircularStampCounter 2
#define DrawPrimitiveCounter 2
#define NumGroups1      3

// -------- temp buffer ------------
#define FrontFaceCounter 0
#define FaceInQuadCounter 1

// -------- temp buffer 1 ------------
#define HistorySampleCounter 0
#define StampDrawCallCounter 2
#define SpineCounter 3
#define ParticleCoverageSpineCounter 4
#define ContourCoverageSpineCounter 5
#define PixelEdgeCounter_History 6
#define JFATileCounter 7
#define PBDParticleCounter 8
#define EdgeLoopCounter 9

#define Subbuffer_ParticleSegmentationInputKey 10
#define Subbuffer_ParticleSegmentationOutput 11
#define Subbuffer_ParticleSegmentCullInputKey 12
#define Subbuffer_StrokeSegmentationInputKey 13
#define Subbuffer_StrokeSegmentationOutput 14
#define Subbuffer_StrokeSegmentCullInputKey 15

#define PBDParticleCounterTemp 16
#define PBDSpringLenMax 17
#define PBDStrokeLenMax 18
#define PBDSpringSegmentCounter 19



// Record multi-ping-pong buffer info
#define SubBuff_Active_Name(tag) (CAT(CAT(SubBuff_, tag), _Active))
#define SubBuff_Cached_Name(tag) (CAT(CAT(SubBuff_, tag), _Cached))

#define ID_SubBuff_Active(tag) (CBuffer_StructuredTempBuffer1[SubBuff_Active_Name(tag)])
#define ID_SubBuff_Cached(tag) (CBuffer_StructuredTempBuffer1[SubBuff_Cached_Name(tag)])

#define Swap_ID_Subbuff(tag, numSubbuff) \
	uint CAT(id_active_, tag) = ID_SubBuff_Active(tag); \
	ID_SubBuff_Cached(tag) = CAT(id_active_, tag); \
	CAT(id_active_, tag) += 1u; \
	CAT(id_active_, tag) %= numSubbuff; \
	ID_SubBuff_Active(tag) = CAT(id_active_, tag); \


#define SubBuff_ParticlePosition_Active 32u
#define SubBuff_ParticlePosition_Cached ((SubBuff_ParticlePosition_Active + 1u))

#define SubBuff_ParticleTangent_Active ((SubBuff_ParticlePosition_Cached + 1u))
#define SubBuff_ParticleTangent_Cached ((SubBuff_ParticleTangent_Active + 1u))

#define SubBuff_SpringAABB_Active ((SubBuff_ParticleTangent_Cached + 1u))
#define SubBuff_SpringAABB_Cached ((SubBuff_SpringAABB_Active + 1u))

#define SubBuff_ParticleCullInfo_Active ((SubBuff_SpringAABB_Cached + 1u))
#define SubBuff_ParticleCullInfo_Cached ((SubBuff_ParticleCullInfo_Active + 1u))

#define SubBuff_ParticleState_Active ((SubBuff_ParticleCullInfo_Cached + 1u))
#define SubBuff_ParticleState_Cached ((SubBuff_ParticleState_Active + 1u))

#define SubBuff_ParticleTemporalVisibility_Active ((SubBuff_ParticleState_Cached + 1u))
#define SubBuff_ParticleTemporalVisibility_Cached ((SubBuff_ParticleTemporalVisibility_Active + 1u))

#define SubBuff_SpringLength_Active ((SubBuff_ParticleTemporalVisibility_Cached + 1u))
#define SubBuff_SpringLength_Cached ((SubBuff_SpringLength_Active + 1u))







#define CBuffer_CachedArgs_ContourCounter (CBuffer_CachedArgs[ContourCounter])
#define CBuffer_CachedArgs_SegmentCounter (CBuffer_CachedArgs[SegmentCounter])
#define CBuffer_CachedArgs_PixelEdgeCounter (CBuffer_CachedArgs[PixelEdgeCounter])
#define CBuffer_CachedArgs_ViewEdgeCounter (CBuffer_CachedArgs[ViewEdgeCounter])
#define CBuffer_CachedArgs_VisibleSegCounter (CBuffer_CachedArgs[VisibleSegCounter])
#define CBuffer_CachedArgs_PatchCounter (CBuffer_CachedArgs[PatchCounter])
#define CBuffer_CachedArgs_PathCounter (CBuffer_CachedArgs[PathCounter])
#define CBuffer_CachedArgs_PixelCounter (CBuffer_CachedArgs[PixelCounter])


#define CBuffer_CachedArgs_ScanCounter(i) (CBuffer_CachedArgs1[i])
#define CBuffer_CircularStampCounter (CBuffer_CachedArgs1[CircularStampCounter])
#define CBuffer_CachedArgs_DrawPrimitiveCounter (CBuffer_CachedArgs1[DrawPrimitiveCounter])
#define CBuffer_CachedArgs_NumGroups(i) (CBuffer_CachedArgs1[2 + i])

#define CBuffer_FrontFaceCounter (CBuffer_StructuredTempBuffer[FrontFaceCounter])
#define CBuffer_QuadFaceCounter (CBuffer_StructuredTempBuffer[FaceInQuadCounter])

#define CBuffer_HistorySampleCounter(frameMod2) (CBuffer_StructuredTempBuffer1[((HistorySampleCounter + frameMod2) % 2)])
#define CBuffer_StampDrawCallCounter (CBuffer_StructuredTempBuffer1[StampDrawCallCounter])
#define CBuffer_SpineCounter (CBuffer_StructuredTempBuffer1[SpineCounter])
#define CBuffer_ParticlCoverageSpineCounter (CBuffer_StructuredTempBuffer1[ParticleCoverageSpineCounter])
#define CBuffer_ContourCoverageSpineCounter (CBuffer_StructuredTempBuffer1[ContourCoverageSpineCounter])
#define CBuffer_HistoryPixelEdgeCounter (CBuffer_StructuredTempBuffer1[PixelEdgeCounter_History])
#define CBuffer_JFATileCounter (CBuffer_StructuredTempBuffer1[JFATileCounter])
#define CBuffer_PBDParticleCounter (CBuffer_StructuredTempBuffer1[PBDParticleCounter])
#define CBuffer_PBDParticleCounterTemp (CBuffer_StructuredTempBuffer1[PBDParticleCounterTemp])
#define CBuffer_PBDMaximumSpringLength (CBuffer_StructuredTempBuffer1[PBDSpringLenMax])
#define CBuffer_PBDMaximumStrokeLength (CBuffer_StructuredTempBuffer1[PBDStrokeLenMax])
#define CBuffer_EdgeLoopCounter (CBuffer_StructuredTempBuffer1[EdgeLoopCounter])
#define CBuffer_PBDSpringSegmentCounter (CBuffer_StructuredTempBuffer1[PBDSpringSegmentCounter])

#define CBuffer_SubBuff_ParticleSegmentKey (CBuffer_StructuredTempBuffer1[Subbuffer_ParticleSegmentationInputKey])
#define CBuffer_SubBuff_ParticleSegmentOutput (CBuffer_StructuredTempBuffer1[Subbuffer_ParticleSegmentationOutput])
#define CBuffer_SubBuff_ParticleSegmentCullingKey (CBuffer_StructuredTempBuffer1[Subbuffer_ParticleSegmentCullInputKey])

#define CBuffer_SubBuff_StrokeSegmentKey (CBuffer_StructuredTempBuffer1[Subbuffer_StrokeSegmentationInputKey])
#define CBuffer_SubBuff_StrokeSegmentOutput (CBuffer_StructuredTempBuffer1[Subbuffer_StrokeSegmentationOutput])
#define CBuffer_SubBuff_StrokeCullingFlag (CBuffer_StructuredTempBuffer1[Subbuffer_StrokeSegmentCullInputKey])

#endif /* CBUFFER_CACHEDARGS_VIEW_INCLUDED */
