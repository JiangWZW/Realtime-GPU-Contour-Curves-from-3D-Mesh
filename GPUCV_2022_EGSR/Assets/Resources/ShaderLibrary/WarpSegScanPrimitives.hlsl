#ifndef WARPSEGSCANPROMITIVES_INCLUDED
#define WARPSEGSCANPROMITIVES_INCLUDED

#include "./ComputeAddressingDefs.hlsl"

#define WARP_SIZE 32

#ifndef CAT
// Macro expansion, for details, see
// ---------------------------------------
// https://stackoverflow.com/questions/1489932/how-to-concatenate-twice-with-the-c-preprocessor-and-expand-a-macro-as-in-arg
#define CAT_(x, y) x ## y
#define CAT(x, y) CAT_(x, y)
#endif

// Type & Type conversion & Scan OP
// ---------------------------------------
#define T SCAN_DATA_TYPE
#define T_SCALAR SCAN_SCALAR_TYPE
#define T_IDENTITY SCAN_ZERO_VALUE

#define tag SCAN_FUNCTION_TAG
#define SCAN_OP OP
#define DATA_SIZE SCAN_BLOCK_SIZE
#define MAX_THREAD_GROUP_SIZE 1024u
#define MAX_REDUCE_BLOCKS MAX_THREAD_GROUP_SIZE

// Dealing with none-u32 types(float, double, etc)
#ifdef SCAN_DATA_TYPE_NON_UINT
#	define AS_T CAT(as, T_SCALAR)
#   define UINT_TO_T(x) (AS_T(x))
#   define T_TO_UINT(x) (asuint(x))
#else
#   define UINT_TO_T(x) (x)
#   define T_TO_UINT(x) (x)
#endif

// Dealing with vector types(float/uint2,3,4(vec), float/uint2x2(mat), etc)
#ifdef SCAN_DATA_VECTOR_STRIDE
#	define T_STRIDE (((SCAN_DATA_VECTOR_STRIDE) * (1u << BITS_WORD_OFFSET)))
#	define STORE_SEGSCAN_VAL CAT(Store, SCAN_DATA_VECTOR_STRIDE)
#	define LOAD_SEGSCAN_VAL CAT(Load, SCAN_DATA_VECTOR_STRIDE)
#else
// Scalar data type
#	define T_STRIDE ((1u << BITS_WORD_OFFSET))
#	define STORE_SEGSCAN_VAL Store
#	define LOAD_SEGSCAN_VAL Load
#endif


// Warp Scan LDS Caches
#define SCAN_CACHE CAT(ScanCache, tag)
// - reduce kernel will use this cache, which might have group size
// - of maximum - 1024, so we set the cache size as maximum.
// - of course, this is not optimal design, but the cache size is
// - relatively small, an i'm too lazy to modify this...
#define SCAN_CACHE_SIZE (MAX_THREAD_GROUP_SIZE / WARP_SIZE)
#define SCAN_CACHE_HF CAT(ScanCacheHF, tag)

#define DECLARE_SCAN_CACHE(T) \
	groupshared T SCAN_CACHE[SCAN_CACHE_SIZE]; \

#define DECLARE_SCAN_CACHE_HF \
	groupshared uint SCAN_CACHE_HF[SCAN_CACHE_SIZE]; \


#define REDUCE_SCAN_CACHE CAT(ReduceScanCache, tag)
#define REDUCE_SCAN_CACHE_SIZE (MAX_THREAD_GROUP_SIZE / WARP_SIZE)
#define REDUCE_SCAN_CACHE_HF CAT(ReduceScanCacheHF, tag)

#define DECLARE_REDUCE_SCAN_CACHE(T) \
	groupshared T REDUCE_SCAN_CACHE[REDUCE_SCAN_CACHE_SIZE]; \

#define DECLARE_REDUCE_SCAN_CACHE_HF \
	groupshared uint REDUCE_SCAN_CACHE_HF[REDUCE_SCAN_CACHE_SIZE]; \



// value & head-flag stored in
// an "Interleaved Layout"
// Here are 4 functions for I/O addressing
#define DECLARE_FUNC_SEGSCAN_ADDR_SCAN_BUFFER \
uint CAT(tag, _SegScanBuffer_PartialSum_AddrAt)(uint elemId)						\
{																					\
	return elemId * T_STRIDE;														\
}																					\
uint CAT(tag, _SegScanBuffer_PartialHF_AddrAt)(uint elemId, uint elemCount)			\
{																					\
	return ((elemCount * T_STRIDE) + (elemId << 2));								\
}																					\

#define SegScanBuffer_PartialSum_AddrAt CAT(tag, _SegScanBuffer_PartialSum_AddrAt)
#define SegScanBuffer_PartialHF_AddrAt CAT(tag, _SegScanBuffer_PartialHF_AddrAt)


#define DECLARE_FUNC_SEGSCAN_ADDR_REDUCE_BUFFER \
uint CAT(tag, _ReduceBuffer_BlockSum_AddrAt)(uint bufferOffset, uint blockId)	\
{																				\
	return bufferOffset + blockId * T_STRIDE;									\
}																				\
uint CAT(tag, _ReduceBuffer_BlockHF_AddrAt)(uint bufferOffset, uint blockId)	\
{																				\
	return																		\
		bufferOffset +															\
		(MAX_REDUCE_BLOCKS * T_STRIDE)	/* offset from scan results */			\
		+ (blockId << 2);				/* elem offset */						\
}																				\

#define ReduceBuffer_BlockSum_AddrAt CAT(tag, _ReduceBuffer_BlockSum_AddrAt)
#define ReduceBuffer_BlockHF_AddrAt CAT(tag, _ReduceBuffer_BlockHF_AddrAt)




/////////////////////////////////////////////////////////////////////////////////
// Parallel Segment Scan Implementation
// - See "Efficient Parallel Scan Algorithms for GPUs"
// My implementation here is slightly modified version,
// which specially designed for HLSL, instead of CUDA.

// -----------------------------------------------------------------------------
// Intra-Wave SegScan, see Figure.3 in paper
#define WARP_SEGSCAN_PASS(i)													\
	prev = WaveReadLaneAt(scanResWarp, laneId - i);								\
	scanResWarp =																\
		((i <= distToSeghead) ? (SCAN_OP(prev, scanResWarp)) : scanResWarp);	\
		
#define DECLARE_FUNC_SEGSCAN_WAVE_INC(T)					\
T CAT(SegScanIncWave_, tag)(								\
	bool inclusive,											\
	uint laneId, T val, bool hf,							\
	out uint hfBitMaskWholeWave,							\
	out uint hfBitMaskPrevLanes, 							\
	out T scanResWarpInc									\
)																				\
{																				\
	T scanResWarp = val;														\
																				\
	uint laneMaskRt = /* Inclusive lane mask */									\
		((~(0u)) >> (WaveGetLaneCount() - 1 - laneId));							\
	hfBitMaskWholeWave = WaveActiveBallot(hf);									\
	hfBitMaskPrevLanes = (hfBitMaskWholeWave & laneMaskRt);						\
																				\
	uint distToSeghead =														\
		hfBitMaskPrevLanes != 0 ?												\
			laneId - firstbithigh(hfBitMaskPrevLanes) : laneId;					\
	T prev;																		\
																				\
	WARP_SEGSCAN_PASS(1u)														\
	WARP_SEGSCAN_PASS(2u)														\
	WARP_SEGSCAN_PASS(4u)														\
	WARP_SEGSCAN_PASS(8u)														\
	WARP_SEGSCAN_PASS(16u)														\
																				\
	scanResWarpInc = scanResWarp;	/* output inclusive sum */					\
	/* Note: hf is inclusive throughout the whole device scan process */		\
	/* Here we only change scanResWarp according to scan type */				\
	T prevIncSum = WaveReadLaneAt(scanResWarp, max(laneId, 1) - 1);	/*EXC only*/\
	return inclusive ? scanResWarp : 											\
		((laneId > 0 && distToSeghead != 0) ? prevIncSum : T_IDENTITY);			\
}																				\



// -----------------------------------------------------------------------------
// Intra-Block SegScan, see Figure.4 in paper
#define DECLARE_FUNC_SEGSCAN_BLOCK_INC(T, WaveSegScanInc)						\
T CAT(SegScanIncBlock_, tag)(													\
	bool inclusive,																\
	uint groupIdx : SV_GroupIndex,												\
	T val, bool hf, out bool hfScanBlock										\
) {																				\
	const uint waveSize = WaveGetLaneCount();									\
	uint laneId = WaveGetLaneIndex();											\
	uint waveId = groupIdx.x / waveSize;										\
																				\
	T valScanWaveInc;															\
	uint hfBitMaskWholeWave, hfBitMaskPrevLanes;								\
	T valScanWave = WaveSegScanInc(												\
		inclusive,																\
		laneId, val, hf,														\
		/* out */																\
		hfBitMaskWholeWave, hfBitMaskPrevLanes,									\
		valScanWaveInc															\
	);																			\
	/* OR-reduction of self&prev lanes' flags in this wave */					\
	bool hfScanWave = hfBitMaskPrevLanes != 0;									\
																				\
	T valWaveTotal = WaveReadLaneAt(											\
		valScanWaveInc, waveSize - 1											\
	);																			\
	bool hfWaveTotal = /* OR-reduction of ALL flags in this wave */				\
		(hfBitMaskWholeWave != 0);												\
																				\
	GroupMemoryBarrierWithGroupSync();											\
																				\
	if (laneId == waveSize - 1)													\
	{																			\
		SCAN_CACHE[waveId] = valWaveTotal;										\
		SCAN_CACHE_HF[waveId] = hfWaveTotal;									\
	}																			\
																				\
	GroupMemoryBarrierWithGroupSync();											\
																				\
																				\
	if (waveId == 0)															\
	{																			\
		T valWave = SCAN_CACHE[laneId];											\
		uint hfWave = SCAN_CACHE_HF[laneId];									\
		T dummy;																\
		T prevWaveSum = WaveSegScanInc(											\
			true, /* always inclusive scan */									\
			laneId, valWave, hfWave,											\
			/* out */															\
			hfBitMaskWholeWave, hfBitMaskPrevLanes, 							\
			dummy																\
		);																		\
																				\
		if (laneId < SCAN_CACHE_SIZE)											\
		{																		\
			SCAN_CACHE[laneId] = prevWaveSum;									\
			SCAN_CACHE_HF[laneId] = hfBitMaskPrevLanes;							\
		}																		\
	}																			\
																				\
	GroupMemoryBarrierWithGroupSync();											\
																				\
	T valScanBlock = valScanWave;												\
	if (waveId != 0 && (!hfScanWave))											\
	{																			\
		T prevWaveAcc = SCAN_CACHE[waveId - 1];									\
		valScanBlock = SCAN_OP(prevWaveAcc, valScanBlock);						\
	}																			\
																				\
	hfScanBlock = hfScanWave;													\
	if (waveId != 0)															\
	{																			\
		hfScanBlock = (hfScanBlock || (SCAN_CACHE_HF[waveId - 1] != 0));		\
	}																			\
																				\
	return valScanBlock;														\
}																				\


// Helper function to store per-block sums into reduction buffer
#define DECLARE_FUNC_SEGSCAN_STORE_TO_REDUCTION_BUFFER(T)	\
void CAT(SegScanStoreReductionData_, tag)(												\
	RWByteAddressBuffer reductionBuffer, uint reductionBufferOffset,					\
	uint3 gIdx : SV_GroupID,															\
	uint groupIdx : SV_GroupIndex,														\
	T valPrefixSum, bool hfPrefixSum													\
) {																						\
	if (groupIdx == SCAN_BLOCK_SIZE - 1)												\
	{																					\
		reductionBuffer.STORE_SEGSCAN_VAL(												\
			ReduceBuffer_BlockSum_AddrAt(reductionBufferOffset, gIdx.x),				\
			T_TO_UINT(valPrefixSum)														\
		);																				\
		reductionBuffer.Store(															\
			ReduceBuffer_BlockHF_AddrAt(reductionBufferOffset, gIdx.x),					\
			hfPrefixSum																	\
		);																				\
	}																					\
}																						\

// Help function to store partial sum&flag-sum after up-sweeping
#define DECLARE_FUNC_SEGSCAN_STORE_TO_SCAN_BUFFER(T)	\
void CAT(SegScanStorePartialSum_, tag)(													\
	RWByteAddressBuffer buffer, uint bufferOffset,									\
	uint elemId, uint elemCount,													\
	T partialSum, bool partialHF													\
) {																					\
	if (elemId < elemCount)															\
	{																				\
		buffer.STORE_SEGSCAN_VAL(													\
			bufferOffset + SegScanBuffer_PartialSum_AddrAt(elemId),					\
			T_TO_UINT(partialSum)													\
		);																			\
		buffer.Store(																\
			bufferOffset + SegScanBuffer_PartialHF_AddrAt(elemId, elemCount),		\
			partialHF																\
		);																			\
	}																				\
}																					\


#define DECLARE_FUNC_SEGSCAN_UPSWEEP(T)										\
void CAT(SegScanInc_UpSweep_, tag)(											\
	uint3 id : SV_DispatchThreadID,											\
	uint groupIdx : SV_GroupIndex,											\
	uint3 gIdx : SV_GroupID,												\
	RWByteAddressBuffer scanBuffer,											\
	RWByteAddressBuffer reductionBuffer,									\
	uint scanBufferOffset, uint reductionBufferOffset,						\
	bool inclusive,															\
	T val, bool hf,															\
	uint elemCount															\
) {																			\
	bool hfPrefixSum;														\
																			\
	T valPrefixSum = CAT(SegScanIncBlock_, tag)(							\
		inclusive, groupIdx, val, hf, hfPrefixSum							\
	);																		\
																			\
	CAT(SegScanStorePartialSum_, tag)(										\
		scanBuffer, scanBufferOffset,										\
		id.x, elemCount,													\
		valPrefixSum, hfPrefixSum											\
	);																		\
																			\
	if (!inclusive)															\
	{ /* Reduction needs inclusive sum */									\
		valPrefixSum = hf ? val : OP(valPrefixSum, val);					\
	} /* hf-sum is always inclusive*/										\
	CAT(SegScanStoreReductionData_, tag)(									\
		reductionBuffer, reductionBufferOffset,								\
		gIdx, groupIdx,														\
		valPrefixSum, hfPrefixSum											\
	);																		\
}																			\

#define DECLARE_FUNC_SEGSCAN_REDUCTION(T)	\
void CAT(SegScanReduction_, tag)(											\
	RWByteAddressBuffer reductionBuffer, uint reductionBufferOffset,		\
	uint groupIdx : SV_GroupIndex)											\
{																			\
	uint rwAddrVal =														\
		ReduceBuffer_BlockSum_AddrAt(reductionBufferOffset, groupIdx);		\
	T valBlock = UINT_TO_T(													\
		reductionBuffer.LOAD_SEGSCAN_VAL(rwAddrVal)							\
	);																		\
	uint rwAddrHF = ReduceBuffer_BlockHF_AddrAt(							\
		reductionBufferOffset, groupIdx										\
	);																		\
	uint hfBlock =															\
		reductionBuffer.Load(rwAddrHF);										\
																			\
																			\
	bool hfScanDevice;														\
	T valSegScan = CAT(SegScanIncBlock_, tag)(								\
		true, groupIdx, valBlock, hfBlock, hfScanDevice						\
	);																		\
																			\
																			\
	reductionBuffer.STORE_SEGSCAN_VAL(										\
		rwAddrVal, T_TO_UINT(valSegScan)									\
	);																		\
}																			\

#define DECLARE_FUNC_SEGSCAN_LOAD_FROM_REDUCTION_BUFFER(T)	\
T CAT(SegScanLoadPrevBlockReductionSum_, tag)(											\
	RWByteAddressBuffer reductionBuffer, uint reductionBufferOffset,					\
	uint blockId																		\
) {																						\
	T prevBlockSum = UINT_TO_T(															\
		reductionBuffer.LOAD_SEGSCAN_VAL(												\
			ReduceBuffer_BlockSum_AddrAt(												\
				reductionBufferOffset,													\
				(blockId == 0) ? 0 : (blockId - 1))										\
		)																				\
	);																					\
	return prevBlockSum;																\
}																						\


#define DECLARE_FUNC_SEGSCAN_LOAD_FROM_SCAN_BUFFER(T)					\
void CAT(SegScanLoadPartialSum_, tag)(													\
	RWByteAddressBuffer scanBuffer,														\
	uint bufferOffset,																	\
	uint elemId,																		\
	uint elemCount,																		\
	out T intraBlockSum,																\
	out bool intraBlockHF																\
)																						\
{																						\
	intraBlockSum = UINT_TO_T(															\
		scanBuffer.LOAD_SEGSCAN_VAL(													\
			bufferOffset + SegScanBuffer_PartialSum_AddrAt(elemId)						\
		)																				\
	);																					\
	intraBlockHF =																		\
		scanBuffer.Load(																\
			bufferOffset + SegScanBuffer_PartialHF_AddrAt(elemId, elemCount)			\
		);																				\
}																						\

#define DECLARE_FUNC_SEGSCAN_DWSWEEP(T)													\
T CAT(SegScanDwSweep_, tag)(																		\
	uint3 id,																			\
	uint3 gIdx,																			\
	RWByteAddressBuffer scanBuffer,														\
	RWByteAddressBuffer reductionBuffer,												\
	uint scanBufferOffset, uint reductionBufferOffset,									\
	uint elemCount																		\
) {																						\
	bool firstBlock = (gIdx.x == 0);													\
																						\
	T prevBlockSum =																	\
		CAT(SegScanLoadPrevBlockReductionSum_, tag)(									\
				reductionBuffer, reductionBufferOffset, gIdx.x);						\
																						\
	T intraBlockSum;																	\
	bool intraBlockHF;																	\
	CAT(SegScanLoadPartialSum_, tag)(													\
		scanBuffer, scanBufferOffset,													\
		id.x, elemCount,																\
		intraBlockSum, intraBlockHF														\
	);																					\
																						\
	T globalSum = intraBlockSum;														\
	if ((!firstBlock) && (!intraBlockHF))												\
	{ /* not 1st block && no head elem ahead in this block(0..0X...) */					\
		globalSum = SCAN_OP(prevBlockSum, globalSum);									\
	}																					\
																						\
	return globalSum;																	\
}																						\




#endif /* SCANPROMITIVES_INCLUDED */
