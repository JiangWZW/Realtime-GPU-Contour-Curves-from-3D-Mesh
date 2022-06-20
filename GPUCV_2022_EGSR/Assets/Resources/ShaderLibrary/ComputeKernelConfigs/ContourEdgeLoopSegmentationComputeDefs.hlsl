#ifndef E7287B3D_02C1_4575_A34C_CC711C06D23F
#define E7287B3D_02C1_4575_A34C_CC711C06D23F


#include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerSeg_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
// #include "../ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"


// Arg Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"


uint F32_TO_U32(float f32) { return ((uint)((f32)+.1f)); }
#define GROUP_SIZE_0 256
#define BITS_GROUP_SIZE_0 8




uint add_u32(uint a, uint b) { return a + b; }


#define SCAN_FUNCTION_TAG Add_u32
#define OP add_u32
#define SCAN_DATA_TYPE uint
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE 0u
// #define SCAN_DATA_VECTOR_STRIDE 2
#define SCAN_BLOCK_SIZE GROUP_SIZE_0
// #define SCAN_DATA_TYPE_NON_UINT
#include "../WarpSegScanCodeGen.hlsl"


#define SCAN_FUNCTION_TAG Add_u32_A
globallycoherent RWByteAddressBuffer CBuffer_BufferRawLookBacks;
#define LOOK_BACK_BUFFER CBuffer_BufferRawLookBacks
#define OP add_u32
#define SCAN_DATA_TYPE uint
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE 0u
// #define SCAN_DATA_VECTOR_STRIDE 2
#define SCAN_BLOCK_SIZE GROUP_SIZE_0
// #define SCAN_DATA_TYPE_NON_UINT
#include "../DecoupledLookBackCodeGen_Scan.hlsl"


#define SCAN_FUNCTION_TAG Add_u32_B
globallycoherent RWByteAddressBuffer CBuffer_BufferRawLookBacks1;
#define LOOK_BACK_BUFFER CBuffer_BufferRawLookBacks1
#define OP add_u32
#define SCAN_DATA_TYPE uint
#define SCAN_SCALAR_TYPE uint
#define SCAN_ZERO_VALUE 0u
// #define SCAN_DATA_VECTOR_STRIDE 2
#define SCAN_BLOCK_SIZE GROUP_SIZE_0
// #define SCAN_DATA_TYPE_NON_UINT
#include "../DecoupledLookBackCodeGen_Scan.hlsl"


#endif /* E7287B3D_02C1_4575_A34C_CC711C06D23F */
