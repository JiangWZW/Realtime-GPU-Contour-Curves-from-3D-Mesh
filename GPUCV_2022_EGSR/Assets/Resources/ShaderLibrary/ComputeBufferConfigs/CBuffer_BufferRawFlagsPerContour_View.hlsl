#ifndef CBUFFER_BUFFERRAWFLAGSPERCONTOUR_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWFLAGSPERCONTOUR_VIEW_INCLUDED

    #include "../ComputeAddressingDefs.hlsl"

    // Current layout
    // -------------------------------------------------------
    // [31,..., 1]:empty 
    
    // [0]:front-facing flag
    // ---------------------
    // Returns 0 if first adj face is front-facing, 1 otherwise
    // == 0: the first face in etlist is front-facing, 
    // == 1: the second face is front-facing;
    // for details, see "TriMeshProcessor.GetEdgeAdjTriangleList" 
    bool ShouldSwapWindingOrder(uint contourFlag){
        return (1 == (contourFlag & 1));
    }

    #define BITS_OFFSET_FLAGS_PER_CONTOUR BITS_WORD_OFFSET
    #define CBuffer_BufferRawFlagsPerContour_AddrAt(id) (id << BITS_OFFSET_FLAGS_PER_CONTOUR)

#endif /* CBUFFER_BUFFERRAWFLAGSPERCONTOUR_VIEW_INCLUDED */
