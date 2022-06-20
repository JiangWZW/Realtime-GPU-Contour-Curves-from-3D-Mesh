#ifndef DEFINED_COMPACTION_COMPUTE_DEFS
    #define DEFINED_COMPACTION_COMPUTE_DEFS
    #include "../UtilityMacros.hlsl"

    #define KERNEL_CONTOUR_COMPACTION true

    #include "../ComputeBufferConfigs/CBuffer_BufferRawPerFace_View.hlsl"
    #include "../ComputeBufferConfigs/CBuffer_BufferRawPerEdge_View.hlsl"
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
    #define USE_LOOK_BACK_TABLE_KERNEL_STAMPPIXELEXTRACTION
    #include "../ComputeBufferConfigs/CBuffer_BufferRawLookBacks_View.hlsl"
    #undef  USE_LOOK_BACK_TABLE_KERNEL_STAMPPIXELEXTRACTION
    
    #define GROUP_SIZE_0 256

    // #define SCAN_BLOCK_SIZE GROUP_SIZE_0
    // #include "../ScanPrimitives.hlsl"

    // Match struct definitions in MPipeline.Custom_Data.HLSL_Data_Types
    struct DrawIndirectArgs
    {
        uint VertPerInst;
        uint InstCount;
        uint VertOffset;
        uint InstOffset;
    }; 

#endif