#ifndef STROKECOVERAGECULLINGCOMPUTEDEFS_INCLUDED
#define STROKECOVERAGECULLINGCOMPUTEDEFS_INCLUDED


#include "../BrushToolBox.hlsl"
#include "../CustomShaderInputs.hlsl"
#include "../JFAInputs.hlsl"

#include "../ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawEdgeLoopData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerStamp_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"

#include "../TextureConfigs/Texture2D_ContourGBufferTex_View.hlsl"
#include "../TextureConfigs/Texture2D_JFATex_View.hlsl"

// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"

#define GROUP_SIZE_0 256
#define BITS_GROUP_SIZE_0 8

#define GROUP_SIZE_PBD_SOLVER 512
#define BITS_GROUP_SIZE_PBD_SOLVER 9


#endif /* STROKEPARTICLERESAMPLERCOMPUTEDEFS_INCLUDED */
