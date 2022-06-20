#ifndef CBUFFER_CALCULATEDNDVRAW_VIEW_INCLUDED
    #define CBUFFER_CALCULATEDNDVRAW_VIEW_INCLUDED
    #include "../ComputeAddressingDefs.hlsl"

    // CBuffer_CalculatedNdVRaw -------------------------------------
    #define BITS_OFFSET_CALCULATED_NDV BITS_WORD_OFFSET
    #define CBuffer_CalculatedNdVRaw_AddrAt(id) (id << BITS_OFFSET_CALCULATED_NDV)

#endif