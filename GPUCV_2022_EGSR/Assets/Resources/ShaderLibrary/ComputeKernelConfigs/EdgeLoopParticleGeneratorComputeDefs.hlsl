#ifndef CAB64EDE_BDE2_4227_9CD9_5F1E185B9FE2
#define CAB64EDE_BDE2_4227_9CD9_5F1E185B9FE2

#pragma use_dxc

#include "../BrushToolBox.hlsl"
#include "../CustomShaderInputs.hlsl"
#include "../JFAInputs.hlsl"

#include "../ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawEdgeLoopData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"

// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"

#define GROUP_SIZE_0 256
#define BITS_GROUP_SIZE_0 8

// Match with "PBDParticleSolver.compute"
#define GROUP_SIZE_PBD_SOLVER 512
#define BITS_GROUP_SIZE_PBD_SOLVER 9

float _PBD_SM_Yield; // init plastic yield 

StructuredBuffer<uint> CBuffer_CachedArgs1;

#endif /* CAB64EDE_BDE2_4227_9CD9_5F1E185B9FE2 */
