
#ifndef STROKEEXTRACTIONCOMPUTEDEFS_INCLUDED
#define STROKEEXTRACTIONCOMPUTEDEFS_INCLUDED
    
    // Mesh Buffers(Raw)
    // Raw Buffers - Per Edge Granularity
    // Raw Buffers - Per Contour Granularity
    // Raw Buffers - Per Segment Granularity
    // Raw Buffers - Per View-Edge Granularity
    #include "../ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerVEdge_View.hlsl"
    // Arg Buffers
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"
    
    // Make sure matches with GROUP_SIZE_NEXT 
    // in "ViewEdgeExtractionComputeDefs.hlsl"
    #define GROUP_SIZE_0 256

#endif /* STROKEEXTRACTIONCOMPUTEDEFS_INCLUDED */
