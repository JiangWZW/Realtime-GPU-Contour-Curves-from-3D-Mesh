#ifndef CBUFFER_BUFFERRAWSEGMENTSTOCONTOUR_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWSEGMENTSTOCONTOUR_VIEW_INCLUDED

    #include "../ComputeAddressingDefs.hlsl"
    #define BITS_OFFSET_BUFFERRAW_SEGMENTS_TO_CONTOUR BITS_WORD_OFFSET
    #define CBuffer_BufferRawSegmentsToContour_AddrAt(id) (id << BITS_OFFSET_BUFFERRAW_SEGMENTS_TO_CONTOUR)

    #ifndef MAX_UINT_VAL
    #   define MAX_UINT_VAL 4294967295
    #endif
    // #define TRASH_VAL_SEGMENTS_TO_CONTOUR MAX_UINT_VAL
    // bool CBuffer_BufferRawSegmentsToContour_IsTrashData(uint data){
    //     return (data == (uint)TRASH_VAL_SEGMENTS_TO_CONTOUR);
    // }

#endif /* CBUFFER_BUFFERRAWSEGMENTSTOCONTOUR_VIEW_INCLUDED */
