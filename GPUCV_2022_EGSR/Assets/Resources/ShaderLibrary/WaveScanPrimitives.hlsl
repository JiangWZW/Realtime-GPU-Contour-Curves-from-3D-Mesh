
#ifndef WARPSCANPRIMITIVES_INCLUDED
#define WARPSCANPRIMITIVES_INCLUDED

#include "./ComputeAddressingDefs.hlsl"

#define WARP_SIZE 32
#define WARP_COUNT (SCAN_BLOCK_SIZE / WARP_SIZE)



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
#define MAX_THREAD_GROUP_SIZE 1024u
#define MAX_REDUCE_BLOCKS MAX_THREAD_GROUP_SIZE


#ifdef SCAN_DATA_TYPE_NON_UINT
#	define AS_T CAT(as, SCAN_SCALAR_TYPE)
#   define UINT_TO_T(x) (AS_T(x))
#   define T_TO_UINT(x) (asuint(x))
#else
#   define UINT_TO_T(x) (x)
#   define T_TO_UINT(x) (x)
#endif

// Dealing with vector types(float/uint2,3,4(vec), float/uint2x2(mat), etc)
#ifdef SCAN_DATA_VECTOR_STRIDE
#	define T_STRIDE (((SCAN_DATA_VECTOR_STRIDE) * (1u << BITS_WORD_OFFSET)))
#	define STORE_SCAN_VAL CAT(Store, SCAN_DATA_VECTOR_STRIDE)
#	define LOAD_SCAN_VAL CAT(Load, SCAN_DATA_VECTOR_STRIDE)
#else
// Scalar data type
#	define T_STRIDE ((1u << BITS_WORD_OFFSET))
#	define STORE_SCAN_VAL Store
#	define LOAD_SCAN_VAL Load
#endif



// Warp Scan LDS Caches
// ------------------------------------------------------------
#define SCAN_CACHE CAT(ScanCache, tag)
// - reduce kernel will use this cache, which might have group size
// - of maximum - 1024, so we set the cache size as maximum.
// - of course, this is not a optimal design, but the cache size is
// - relatively small, an i'm too lazy to modify this...
#define SCAN_CACHE_SIZE (MAX_THREAD_GROUP_SIZE / WARP_SIZE)

#define DECLARE_SCAN_CACHE(T) \
	groupshared T SCAN_CACHE[SCAN_CACHE_SIZE]; \



// - See "Efficient Parallel Scan Algorithms for GPUs"
// My implementation here is slightly modified version,
// which specially designed for HLSL, instead of CUDA.
// -----------------------------------------------------------------------------

// For intra-wave scan, 
// there are two special cases for optimization:
// 1) For summation, one can just use "WavePrefixSum"
// 2) For bit counting, just use "WavePrefixCountBits"
//
// However, when scan operator is sth. else,
// for example, max, min, etc, 
// Generic Intra-Wave Scan is needed:
#define WARP_SCAN_PASS(i)														\
	prev = WaveReadLaneAt(scanResWarp, laneId - i);								\
	scanResWarp =																\
		((i <= laneId) ? (SCAN_OP(prev, scanResWarp)) : scanResWarp);			\

		
#define DECLARE_FUNC_GENERIC_SCAN_WAVE(T)										\
T CAT(GenericScanWave_, tag)(T val, bool inclusive = false)						\
{																				\
	uint laneId = WaveGetLaneIndex();											\
																				\
	T scanResWarp = val;														\
	T prev;																		\
	/*inclusive generic warp scan*/												\
	WARP_SCAN_PASS(1u)															\
	WARP_SCAN_PASS(2u)															\
	WARP_SCAN_PASS(4u)															\
	WARP_SCAN_PASS(8u)															\
	WARP_SCAN_PASS(16u)															\
																				\
	T prevIncSum = WaveReadLaneAt(scanResWarp, max(laneId, 1) - 1);	/*EXC only*/\
	return inclusive ? scanResWarp : 											\
		(laneId > 0 ? prevIncSum : T_IDENTITY);									\
}																				\


#define DECLARE_FUNC_ADD_SCAN_WAVE(T)											\
T CAT(AddScanWave_, tag)(T val, bool inclusive = false)							\
{																				\
	T scanResWarp = WavePrefixSum(val);	/*exclusive*/							\
																				\
	return (!inclusive) ? scanResWarp : (scanResWarp + val);					\
}																				\


#define DECLARE_FUNC_BIT_SCAN_WAVE(T)											\
T CAT(BitScanWave_, tag)(bool val, bool inclusive = false)						\
{																				\
	uint scanResWarp = WavePrefixCountBits(val);	/*exclusive*/				\
																				\
	return (!inclusive) ? scanResWarp : (scanResWarp + val);					\
}																				\


#define DECLARE_DECLARE_FUNC_SCAN_BLOCK(WavePrefixSumFunc, tag, TG_SIZE)	\
T CAT(ScanBlock_, tag)(T value, uint groupIdx : SV_GroupIndex, bool inclusive = false)	\
{																	\
	T sum = WavePrefixSumFunc(value, inclusive);					\
																	\
	/* Get wave size and wave index */								\
	const uint waveSize = WaveGetLaneCount();						\
	const uint waveIdx = groupIdx / waveSize;						\
																	\
																	\
	if (WaveGetLaneIndex() == waveSize - 1)							\
		{SCAN_CACHE[waveIdx] = inclusive ? sum : OP(sum, value);}	\
	GroupMemoryBarrierWithGroupSync();								\
																	\
	const uint numWaves = TG_SIZE / waveSize;						\
	if (groupIdx < numWaves)										\
	{																\
		const T laneSum = SCAN_CACHE[groupIdx];						\
		const T waveSum = WavePrefixSumFunc(laneSum, false);		\
																	\
		SCAN_CACHE[groupIdx] = waveSum;								\
	}																\
	GroupMemoryBarrierWithGroupSync();								\
																	\
																	\
	sum = OP(SCAN_CACHE[waveIdx], sum);								\
	return sum;														\
}																	\




// Here are 4 functions for I/O addressing
#define DECLARE_FUNC_SCAN_ADDR_SCAN_BUFFER \
uint CAT(tag, _ScanBuffer_PartialSum_AddrAt)(uint elemId)							\
{																					\
	return elemId * T_STRIDE;														\
}																					\

#define ScanBuffer_PartialSum_AddrAt CAT(tag, _ScanBuffer_PartialSum_AddrAt)


#define DECLARE_FUNC_SCAN_ADDR_REDUCE_BUFFER \
uint CAT(tag, _ReduceBuffer_BlockSum_AddrAt)(uint bufferOffset, uint blockId)	\
{																				\
	return bufferOffset + blockId * T_STRIDE;									\
}																				\

#define ReduceBuffer_BlockSum_AddrAt CAT(tag, _ReduceBuffer_BlockSum_AddrAt)



// Help function to store partial sum&flag-sum after up-sweeping
#define DECLARE_FUNC_SCAN_STORE_TO_SCAN_BUFFER(T)									\
void CAT(ScanStorePartialSum_, tag)(												\
	RWByteAddressBuffer buffer, uint bufferOffset,									\
	uint elemId, uint elemCount,													\
	T partialSum																	\
) {																					\
	if (elemId < elemCount)															\
	{																				\
		buffer.STORE_SCAN_VAL(														\
			bufferOffset + ScanBuffer_PartialSum_AddrAt(elemId),					\
			T_TO_UINT(partialSum)													\
		);																			\
	}																				\
}																					\

// Helper function to store per-block sums into reduction buffer
#define DECLARE_FUNC_SCAN_STORE_TO_REDUCTION_BUFFER(T)									\
void CAT(ScanStoreReductionData_, tag)(													\
	RWByteAddressBuffer reductionBuffer, uint reductionBufferOffset,					\
	uint3 gIdx : SV_GroupID,															\
	uint groupIdx : SV_GroupIndex,														\
	T blockInclusiveSum																	\
) {																						\
	if (groupIdx == SCAN_BLOCK_SIZE - 1)												\
	{																					\
		reductionBuffer.STORE_SCAN_VAL(													\
			ReduceBuffer_BlockSum_AddrAt(reductionBufferOffset, gIdx.x),				\
			T_TO_UINT(blockInclusiveSum)												\
		);																				\
	}																					\
}																						\


#define DECLARE_FUNC_SCAN_UPSWEEP(T)										\
void CAT(Scan_UpSweep_, tag)(												\
	bool inclusive,															\
	uint3 id : SV_DispatchThreadID,											\
	uint groupIdx : SV_GroupIndex,											\
	uint3 gIdx : SV_GroupID,												\
	RWByteAddressBuffer scanBuffer,											\
	RWByteAddressBuffer reductionBuffer,									\
	T val,																	\
	uint scanBufferOffset, uint reductionBufferOffset,						\
	uint elemCount															\
) {																			\
	bool hfPrefixSum;														\
																			\
	T valPrefixSum = CAT(ScanBlock_, tag)(									\
		 val, groupIdx, inclusive											\
	);																		\
																			\
	CAT(ScanStorePartialSum_, tag)(											\
		scanBuffer, scanBufferOffset,										\
		id.x, elemCount,													\
		valPrefixSum														\
	);																		\
																			\
	if (!inclusive)															\
	{																		\
		valPrefixSum = OP(valPrefixSum, val); /*Per-block partial sum*/		\
	}																		\
	CAT(ScanStoreReductionData_, tag)(										\
		reductionBuffer, reductionBufferOffset,								\
		gIdx, groupIdx,														\
		valPrefixSum														\
	);																		\
}																			\


#define DECLARE_FUNC_SCAN_REDUCTION(T)	\
void CAT(ScanReduction_, tag)(												\
	RWByteAddressBuffer reductionBuffer, uint reductionBufferOffset,		\
	uint groupIdx : SV_GroupIndex)											\
{																			\
	uint rwAddrVal =														\
		ReduceBuffer_BlockSum_AddrAt(reductionBufferOffset, groupIdx);		\
	T valBlock = UINT_TO_T(													\
		reductionBuffer.LOAD_SCAN_VAL(rwAddrVal)							\
	);																		\
																			\
																			\
	T valScan = CAT(ScanBlock_, Reduce)(									\
		valBlock, groupIdx, true											\
	);																		\
																			\
																			\
	reductionBuffer.STORE_SCAN_VAL(											\
		rwAddrVal, T_TO_UINT(valScan)										\
	);																		\
}																			\

#define DECLARE_FUNC_SCAN_LOAD_FROM_REDUCTION_BUFFER(T)	\
T CAT(ScanLoadPrevBlockReductionSum_, tag)(												\
	RWByteAddressBuffer reductionBuffer, uint reductionBufferOffset,					\
	uint blockId																		\
) {																						\
	T prevBlockSum = UINT_TO_T(															\
		reductionBuffer.LOAD_SCAN_VAL(													\
			ReduceBuffer_BlockSum_AddrAt(												\
				reductionBufferOffset,													\
				(blockId == 0) ? 0 : (blockId - 1))										\
		)																				\
	);																					\
	return prevBlockSum;																\
}																						\


#define DECLARE_FUNC_SCAN_LOAD_FROM_SCAN_BUFFER(T)										\
void CAT(ScanLoadPartialSum_, tag)(														\
	RWByteAddressBuffer scanBuffer,														\
	uint bufferOffset,																	\
	uint elemId,																		\
	uint elemCount,																		\
	out T intraBlockSum 																\
)																						\
{																						\
	intraBlockSum = UINT_TO_T(															\
		scanBuffer.LOAD_SCAN_VAL(														\
			bufferOffset + ScanBuffer_PartialSum_AddrAt(elemId)							\
		)																				\
	);																					\
}																						\


#define DECLARE_FUNC_SCAN_DWSWEEP(T)													\
T CAT(ScanDwSweep_, tag)(																\
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
		CAT(ScanLoadPrevBlockReductionSum_, tag)(										\
				reductionBuffer, reductionBufferOffset, gIdx.x);						\
																						\
	T intraBlockSum;																	\
	CAT(ScanLoadPartialSum_, tag)(														\
		scanBuffer, scanBufferOffset,													\
		id.x, elemCount,																\
		intraBlockSum																	\
	);																					\
																						\
	T globalSum = intraBlockSum;														\
	if ((!firstBlock))																	\
	{ /* not 1st block */																\
		globalSum = OP(prevBlockSum, globalSum);										\
	}																					\
																						\
	return globalSum;																	\
}																						\



// =========================================================
// Creates a stream compaction function.
// InterlockCounter: Atomic for TG-wise compaction
// LDS_PrevBlockSum: broadcast InterlockCounter to entire TG
// Note:
// 1) Zero InterlockCounter before launching this kernel.
// 2) Zero LDS_PrevBlockSum before calling this function.
#define DECLARE_FUNC_STREAM_COMPACTION(InterlockCounter, LDS_PrevBlockSum)		\
uint CAT(StreamCompaction_, tag)(uint groupIdx : SV_GroupIndex, uint scanValue)	\
{																			\
	uint blockPrefix = CAT(ScanBlock_, tag)(scanValue, groupIdx, false);	\
																			\
	if (groupIdx == SCAN_BLOCK_SIZE - 1)									\
	{																		\
		InterlockedAdd(														\
			InterlockCounter,												\
			(blockPrefix + scanValue),										\
			LDS_PrevBlockSum												\
		);																	\
	}																		\
	GroupMemoryBarrierWithGroupSync();										\
																			\
	return LDS_PrevBlockSum + blockPrefix;									\
}																			\



#endif /* SCANPROMITIVES_INCLUDED */
