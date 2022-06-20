#ifndef CBuffer_BufferRawContourToEdge_View_INCLUDED
#define CBuffer_BufferRawContourToEdge_View_INCLUDED

    #include "../ComputeAddressingDefs.hlsl"

    // CBuffer_BufferRawContourToEdge -------------------------------------
    // struct layout

    // RenderDoc Shorcut --------------
    #define BITS_OFFSET_BUFFER_RAW_CONTOUR_TO_EDGE BITS_WORD_OFFSET
    #define CBuffer_BufferRawContourToEdge_AddrAt(id) (id << BITS_OFFSET_BUFFER_RAW_CONTOUR_TO_EDGE)

    #ifndef MAX_UINT_VAL
    #   define MAX_UINT_VAL 4294967295
    #endif
    #define TRASH_VAL_CONTOUR_TO_EDGE MAX_UINT_VAL
    bool CBuffer_BufferRawContourToEdge_IsTrashData(uint data){
        return (data == (uint)TRASH_VAL_CONTOUR_TO_EDGE);
    }

#endif /* CBuffer_BufferRawContourToEdge_View_INCLUDED */
