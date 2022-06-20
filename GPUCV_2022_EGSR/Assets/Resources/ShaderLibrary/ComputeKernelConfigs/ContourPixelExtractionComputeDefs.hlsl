#ifndef CONTOURPIXELEXTRACTIONCOMPUTEDEFS_INCLUDED
#define CONTOURPIXELEXTRACTIONCOMPUTEDEFS_INCLUDED
    // External Source
    // #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

    // Mesh Buffers(Raw)
    #include "../CustomComputeInputs.hlsl"
    // Raw Buffers - Per Edge Granularity
    // Raw Buffers - Per Contour Granularity
    // Raw Buffers - Per Segment Granularity
    #include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerSegment_View.hlsl"
    #include "../ComputeBufferConfigs/CBuffer_BufferRawVisibleSegToSeg_View.hlsl"
    // Arg Buffers
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"
    
    #define USE_LOOK_BACK_TABLE_KERNEL_STAMPPIXELEXTRACTION
    #include "../ComputeBufferConfigs/CBuffer_BufferRawLookBacks_View.hlsl"
    #undef  USE_LOOK_BACK_TABLE_KERNEL_STAMPPIXELEXTRACTION
    
    // Make sure this matches GROUP_SIZE_NEXT in SegmentVisibilityComputeDefs.hlsl
    #define GROUP_SIZE_0 256

    // this function finishes allocation operation for 
    // one segment.
    // - strBuffer: buffer as output target, 
    // - strAddr: output address, 
    // - strData: output data
    void VEdgeCompaction(
        RWByteAddressBuffer strBuffer, 
        uint strAddr, uint strData
    ){
        strBuffer.Store(strAddr, strData);
    }

    void VEdgeCompaction_X4(
        RWByteAddressBuffer strBuffer,
        uint4 strAddr_X4, 
        uint4 allocate_X4,
        uint4 strData_X4
    ){
        bool4 mask = (allocate_X4 == uint4(0, 0, 0, 0));
        if (!mask.x){
            VEdgeCompaction(strBuffer, strAddr_X4.x, strData_X4.x);
        }
        if (!mask.y){
            VEdgeCompaction(strBuffer, strAddr_X4.y, strData_X4.y);
        }
        if (!mask.z){
            VEdgeCompaction(strBuffer, strAddr_X4.z, strData_X4.z);
        }
        if (!mask.w){
            VEdgeCompaction(strBuffer, strAddr_X4.w, strData_X4.w);
        }
    }

    // Make sure this matches GROUP_SIZE_0 
    // Or StampThinning.hlsl --- when _RenderMode == RENDER_VIEWSTAMP
    #define GROUP_SIZE_NEXT 256
    #define BITS_GROUP_SIZE_NEXT 8 

    #define SCAN_BLOCK_SIZE GROUP_SIZE_0
    #include "../ScanPrimitives.hlsl"
#endif /* CONTOURPIXELEXTRACTIONCOMPUTEDEFS_INCLUDED */
