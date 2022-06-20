#ifndef CBUFFER_TVLIST_VIEW_INCLUDED
#define CBUFFER_TVLIST_VIEW_INCLUDED

#include "../../ComputeAddressingDefs.hlsl"

#define CBuffer_TVList_AddrAtPrimID(id) ((id << BITS_WORD_OFFSET) * 3)
#define CBuffer_TVList_AddrAtVertID(id) (id << BITS_WORD_OFFSET)

#endif