#ifndef MULTIBUFFERING_PARTICLEDATA_INCLUDED
#define MULTIBUFFERING_PARTICLEDATA_INCLUDED


#ifdef MULTIBUFFERING_PARTICLEDATA_READONLY
	StructuredBuffer<uint> CBuffer_StructuredTempBuffer1;
#else
	RWStructuredBuffer<uint> CBuffer_StructuredTempBuffer1;
#endif


#endif /* MULTIBUFFERING_PARTICLEDATA_INCLUDED */
