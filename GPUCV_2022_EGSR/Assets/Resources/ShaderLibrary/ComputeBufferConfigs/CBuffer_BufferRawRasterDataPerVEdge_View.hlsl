#ifndef CBUFFER_BUFFERRAWRASTERDATAPERVEDGE_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWRASTERDATAPERVEDGE_VIEW_INCLUDED
    #include "../ComputeAddressingDefs.hlsl"

    // RenderDoc Shorcut --------------
    // float2 pos0;
    // float2 pos1;
    // float2 eyeZ;
    // uint contourId;
    // uint dummy;
    #define BITS_OFFSET_BUFFER_RAW_RASTERDATA_PER_VEDGE BITS_CHUNK_OFFSET
    #define CBuffer_BufferRawRasterDataPerVEdge_AddrAt(id) (id << BITS_OFFSET_BUFFER_RAW_RASTERDATA_PER_VEDGE)

    // Data Layout (uint4x2)
    // Why uint4x2, not 2x4? ---------------------------------------
    // Matrices are stored in column-major fasion
    // in DX platform with hlsl compiler.
    // so each Load4() op loads a 4x1 colmn of original matrix data.
    // -------------------------------------------------------------
    // +---------Column--------->
    // =       _1       _2       
    // R _1 [vpos0.x | (eye space z0)]   
    // o _2 [vpos0.y | (eye space z1)]   
    // w _3 [vpos1.x | (Reserved)] 
    // = _4 [vpos1.y | (Reserved)]
    #define VEDGE_RASTER_VERTS(rasterData) ((rasterData._11_21_31_41))
    #define GET_VEDGE_RASTER_VERTS(rasterData) (asfloat(VEDGE_RASTER_VERTS(rasterData)))
    #define VEDGE_RASTER_VERT0(rasterData) ((rasterData._11_21))
    #define GET_VEDGE_RASTER_VERT0(rasterData) (asfloat(VEDGE_RASTER_VERT0(rasterData)))
    #define VEDGE_RASTER_VERT1(rasterData) ((rasterData._31_41))
    #define GET_VEDGE_RASTER_VERT1(rasterData) (asfloat(VEDGE_RASTER_VERT1(rasterData)))

    #define VEDGE_RASTER_LINZ(rasterData) (rasterData._12_22)
    #define GET_VEDGE_RASTER_LINZ(rasterData) (asfloat(VEDGE_RASTER_LINZ(rasterData)))

#endif /* CBUFFER_BUFFERRAWRASTERDATAPERVEDGE_VIEW_INCLUDED */
