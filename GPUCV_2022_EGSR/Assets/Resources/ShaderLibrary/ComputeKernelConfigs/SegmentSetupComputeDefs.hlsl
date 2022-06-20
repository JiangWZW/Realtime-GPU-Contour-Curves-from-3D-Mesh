#ifndef SEGMENTATIONCOMPUTEDEFS_INCLUDED
#define SEGMENTATIONCOMPUTEDEFS_INCLUDED
    
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

    #include "../CustomShaderInputs.hlsl"
    // Mesh Buffers(Raw)
    // Raw Buffers - Per Edge Granularity
    // Raw Buffers - Per Contour Granularity
    #include "../ComputeBufferConfigs/CBuffer_BufferRawContourToSegment_View.hlsl"
    // Raw Buffers - Per Segment Granularity
    #include "../ComputeBufferConfigs/CBuffer_BufferRawSegmentsToContour_View.hlsl"
    // Arg Buffers
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"
    
    #define USE_LOOK_BACK_TABLE_KERNEL_SEGMENTSCAN
    #include "../ComputeBufferConfigs/CBuffer_BufferRawLookBacks_View.hlsl"
    #undef  USE_LOOK_BACK_TABLE_KERNEL_SEGMENTSCAN
    
    #define USE_LOOK_BACK_TABLE_KERNEL_SEGMENTVISIBILITY_DEPTHTEST
    #include "../ComputeBufferConfigs/CBuffer_BufferRawLookBacks1_View.hlsl"
    #undef  USE_LOOK_BACK_TABLE_KERNEL_SEGMENTVISIBILITY_DEPTHTEST

    // =========================================================
    #define GROUP_SIZE_0 1024 // When you change this, make sure
    // that group size matches with indirect-dispatch args
    // in kernel "ContourSegmentation_SegmentScan".
    
    
    // ========================
    #define GROUP_SIZE_1 256
    #define BITS_GROUP_SIZE_1 8

    
    // =========================================================
    #define GROUP_SIZE_2 1024
    #define MAX_NUM_GROUPS_2 1024
    #define BITS_GROUP_SIZE_2 10

    // Make sure this matches GROUP_SIZE_0 in 
    // "SegmentVisibilityComputeDefs.hlsl"
    #define GROUP_SIZE_NEXT 256 
    #define BITS_GROUP_SIZE_NEXT 8

    // ---------------------------------
    // Constants for Compaction 
    // ---------------------------------
    uint AddOp(uint a, uint b){
        return a + b;
    }

    #define SCAN_BLOCK_SIZE GROUP_SIZE_2
    #include "../ScanPrimitives.hlsl"
    

#endif /* SEGMENTATIONCOMPUTEDEFS_INCLUDED */