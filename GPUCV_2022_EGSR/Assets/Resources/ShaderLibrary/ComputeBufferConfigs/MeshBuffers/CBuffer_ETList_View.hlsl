#ifndef CBUFFER_ETLIST_VIEW_INCLUDED
#define CBUFFER_ETLIST_VIEW_INCLUDED

#include "../../ComputeAddressingDefs.hlsl"

// == 3bit == 2 uint words
#define BITS_OFFSET_ETLIST (BITS_WORD_OFFSET + 1)
#define CBuffer_ETList_AddrAt(id) (id << BITS_OFFSET_ETLIST)

#endif /* CBUFFER_ETLIST_VIEW_INCLUDED */
