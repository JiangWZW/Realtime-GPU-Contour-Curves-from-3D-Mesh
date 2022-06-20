#ifndef CBUFFER_BUFFERRAWCONTOURTOSEGMENT_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWCONTOURTOSEGMENT_VIEW_INCLUDED

    #include "../ComputeAddressingDefs.hlsl"

    #define BITS_OFFSET_BUFFER_RAW_CONTOUR_TO_SEGMENT BITS_WORD_OFFSET
    #define CBuffer_BufferRawContourToSegment_AddrAt(id) (id << BITS_OFFSET_BUFFER_RAW_CONTOUR_TO_SEGMENT)

    #ifndef MAX_UINT_VAL
    #   define MAX_UINT_VAL 4294967295
    #endif
    #define TRASH_VAL_CONTOUR_TO_SEGMENT MAX_UINT_VAL
    bool CBuffer_BufferRawContourToSegment_IsTrashData(uint data){
        return (data == (uint)TRASH_VAL_CONTOUR_TO_SEGMENT);
    }

#endif /* CBUFFER_BUFFERRAWCONTOURTOSEGMENT_VIEW_INCLUDED */
