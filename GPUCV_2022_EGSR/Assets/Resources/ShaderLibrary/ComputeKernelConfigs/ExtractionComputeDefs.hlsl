#ifndef DEFINED_EXTRACTION_COMPUTE_DEFS
#define DEFINED_EXTRACTION_COMPUTE_DEFS
#define PASS_CONTOUR_EXTRACTION true

#include "../CustomShaderInputs.hlsl"

// Pass Buffers
#include "../ComputeBufferConfigs/CBuffer_BufferRawPerVert_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPerFace_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPerEdge_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerEdge_View.hlsl"
// Mesh Buffers (Raw only)
#include "../ComputeBufferConfigs/MeshBuffers/CBuffer_TVList_View.hlsl"
#include "../ComputeBufferConfigs/MeshBuffers/CBuffer_ETList_View.hlsl"
// Args Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"


#define FLAG_BACK_FACE 0
#define FLAG_PARA_FACE 1
#define FLAG_FRONT_FACE 2

#define IS_FRONT_FACE(faceFlag) ((faceFlag) > 0)
#define NOT_PARA_FACE(faceFlag) (faceFlag != FLAG_PARA_FACE)
#define SAME_FACE_DIR(fFlag0, fFlag1) (fFlag0 == fFlag1)

#define GROUP_SIZE 128



#endif
