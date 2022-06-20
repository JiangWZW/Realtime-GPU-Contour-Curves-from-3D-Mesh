#ifndef RADIXSORTCOMPUTEDEFS_20_INCLUDED
#define RADIXSORTCOMPUTEDEFS_20_INCLUDED

    #define KERNEL_CONTOUR_INDIRECTION true

    // Mesh Buffers(Raw)
    // Raw Buffers - Per Edge Granularity
    // Raw Buffers - Per Contour Granularity
    // Raw Buffers - Per Segment Granularity
    // Args Buffers
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"
    
    #define BITS_PER_DIGIT  8
    #define BITS_PER_CODE   32
    #define NUM_DIGITS (32 / BITS_PER_DIGIT)

    // Misc Buffers - Radix Sort
    #include "../ComputeBufferConfigs/CBuffer_StructuredKeyValuePair_View.hlsl"
    #include "../ComputeBufferConfigs/CBuffer_StructuredGlobalDigitStart_View.hlsl"
    
    #define WARP_SIZE 32

    // Match with GROUP_SIZE_NEXT in "SegmentVisibilityComputeDefs.hlsl"
    #define GROUP_SIZE_0 256

    #define GROUP_SIZE_1 (1 << (BITS_PER_DIGIT - 1))
    #define BITS_GROUP_SIZE_1 (BITS_PER_DIGIT - 1)

    #define GROUP_SIZE_2 128
    #define BITS_GROUP_SIZE_2 7

    // Match with GROUP_SIZE_1 in
    #define GROUP_SIZE_NEXT 256
    #define BITS_GROUP_SIZE_NEXT 8

#endif /* RADIXSORTCOMPUTEDEFS_20_INCLUDED */
