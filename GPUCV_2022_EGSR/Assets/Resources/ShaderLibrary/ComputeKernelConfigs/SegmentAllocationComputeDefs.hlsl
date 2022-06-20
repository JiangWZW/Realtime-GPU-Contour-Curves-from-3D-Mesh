#ifndef SEGMENTATIONCOMPUTEDEFS_INCLUDED
#define SEGMENTATIONCOMPUTEDEFS_INCLUDED
    
    #define KERNEL_CONTOUR_INDIRECTION true

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

    #include "../CustomComputeInputs.hlsl"
    // Mesh Buffers(Raw)
    #include "../ComputeBufferConfigs/MeshBuffers/CBuffer_EVList_View.hlsl"
    // Raw Buffers - Per Edge Granularity
    #include "../ComputeBufferConfigs/CBuffer_BufferRawPerEdge_View.hlsl"
    #include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerEdge_View.hlsl"
    // Raw Buffers - Per Contour Granularity
    #include "../ComputeBufferConfigs/CBuffer_BufferRawContourToEdge_View.hlsl"
    #include "../ComputeBufferConfigs/CBuffer_BufferRawContourToSegment_View.hlsl"
    // Raw Buffers - Per Segment Granularity
    #include "../ComputeBufferConfigs/CBuffer_BufferRawSegmentsToContour_View.hlsl"
    // Args Buffers
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
    #define USE_LOOK_BACK_TABLE_KERNEL_SEGMENTSCAN
    #include "../ComputeBufferConfigs/CBuffer_BufferRawLookBacks_View.hlsl"


    // ----------------------------------------------------------
    // Padding Macros for Eliminating Bank Conficts
    // ----------------------------------------------------------
    // Remember to match with GROUP_SIZE_1 in SetupComputeDefs.hlsl
    #define GROUP_SIZE_1 1024
    #define GROUP_SIZE_1_BITS 10

    #define GROUP_SIZE_NEXT 128
    #define BITS_GROUP_SIZE_NEXT 7

    #define SCAN_BLOCK_SIZE GROUP_SIZE_1
    #include "../ScanPrimitives.hlsl"

#endif /* SEGMENTATIONCOMPUTEDEFS_INCLUDED */