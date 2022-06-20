#ifndef STAMPVERTEXGENERATORCOMPUTEDEFS_20_20_E5_89_AF_E6_9C_AC_INCLUDED
#define STAMPVERTEXGENERATORCOMPUTEDEFS_20_20_E5_89_AF_E6_9C_AC_INCLUDED


#include "../BrushToolBox.hlsl"
#include "../CustomShaderInputs.hlsl"

#include "../ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerStamp_View.hlsl"

#define UAV_ReProjectionTex
#include "../TextureConfigs/Texture2D_ReProjectionTex_View.hlsl"
#include "../TextureConfigs/Texture2D_ContourGBufferTex_View.hlsl"

// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"


#define GROUP_SIZE_0 256
#define BITS_GROUP_SIZE_0 8



#endif /* STAMPVERTEXGENERATORCOMPUTEDEFS_20_20_E5_89_AF_E6_9C_AC_INCLUDED */
