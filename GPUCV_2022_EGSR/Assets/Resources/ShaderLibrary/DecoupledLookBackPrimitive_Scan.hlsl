#ifndef DECOUPLED_LOOKBACK_PRIMITIVES_INCLUDED
#define DECOUPLED_LOOKBACK_PRIMITIVES_INCLUDED

#include "./ComputeAddressingDefs.hlsl"

// --- Input Example ---------------------------------
// RWByteAddressBuffer CBuffer_BufferRawLookBacks;
// #define LOOK_BACK_BUFFER CBuffer_BufferRawLookBacks
// float4 op(float4 a, float4 b)
// {
// 	return a + b;
// }
// #define OP op
// #define SCAN_DATA_TYPE float4
// #define SCAN_SCALAR_TYPE float
// #define SCAN_ZERO_VALUE .0f
// #define SCAN_DATA_VECTOR_STRIDE 4
// #define SCAN_BLOCK_SIZE GROUP_SIZE_0
// #define REDUCE_BLOCK_SIZE 1024
// #define SCAN_DATA_TYPE_NON_UINT
// ------------------------------------------------



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
#define NUM_SCAN_BLOCKS ((numGroups))



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
#	define STORE_SCAN_VAL CAT(Store, SCAN_DATA_VECTOR_STRIDE)
#	define LOAD_SCAN_VAL CAT(Load, SCAN_DATA_VECTOR_STRIDE)
#else
// Scalar data type
#	define T_STRIDE ((1u << BITS_WORD_OFFSET))
#	define STORE_SCAN_VAL Store
#	define LOAD_SCAN_VAL Load
#endif

// Global Look-Back Buffer
#define LookBackTable LOOK_BACK_BUFFER

// Group Shared Look-Back Info
// Type of look-back cache
struct CAT(LDSLookBackArgs_, tag)
{
	T exclusive_prefix;
	T inclusive_prefix;
	T block_inclusive_sum;
};
#define LDSLookBackArgs CAT(LDSLookBackArgs_, tag)

struct CAT(LDSLookBackArgs_SegScan_, tag)
{
	bool block_inclusive_hf; // inclusive OR-reduction of hf
};
#define LDSLookBackArgs_SegScan CAT(LDSLookBackArgs_SegScan_, tag)

// Name of look-back cache
#define SCAN_LOOK_BACK_CACHE CAT(LDS_temp_storage_, tag)
#define SEGSCAN_LOOK_BACK_CACHE CAT(LDS_temp_storage_segscan_, tag)

#define DECLARE_LOOK_BACK_SCAN_CACHE(T) \
	groupshared LDSLookBackArgs SCAN_LOOK_BACK_CACHE; \
	groupshared LDSLookBackArgs_SegScan SEGSCAN_LOOK_BACK_CACHE; \


// group shared dynamic block index. 
// Shared by multiple scans in the same kernel
#define DYNAMIC_TILE_ID_CACHE LDS_DynamicBlockID
#define DECLARE_DYNAMIC_BLOCK_ID_CACHE \
	groupshared uint DYNAMIC_TILE_ID_CACHE; \

// Tile States =======================---
// Not yet processed
#define SCAN_TILE_INVALID 111u
 // Tile aggregate is available
#define SCAN_TILE_PARTIAL 1u
// Inclusive tile prefix is available
#define SCAN_TILE_INCLUSIVE 2u
// Out-of-bounds (e.g., padding)
#define SCAN_TILE_OOB 99u
// ---=================================---


/* warp size == look-back window size */
#define TILE_STATUS_PADDING (((int)32))

/* look-back buffer layout */
#define Addr_LookBackBlockCounter (0)
#define Size_LookBackBlockCounter ((1 << BITS_WORD_OFFSET))

#define Stride_FlagPerLookBackBlock ((1 << BITS_WORD_OFFSET))
#define Addr_FlagPerLookBackBlock ((Addr_LookBackBlockCounter + Size_LookBackBlockCounter))
#define Size_FlagPerLookBackBlock (((NUM_SCAN_BLOCKS + TILE_STATUS_PADDING) * (Stride_FlagPerLookBackBlock)))

#define Stride_InclusiveSumPerBlock T_STRIDE
#define Addr_InclusiveSumPerBlock ((Addr_FlagPerLookBackBlock + Size_FlagPerLookBackBlock))
#define Size_InclusiveSumPerBlock (((NUM_SCAN_BLOCKS + TILE_STATUS_PADDING) * (Stride_InclusiveSumPerBlock)))

#define Stride_PartialSumPerBlock T_STRIDE
#define Addr_PartialSumPerBlock ((Addr_InclusiveSumPerBlock + Size_InclusiveSumPerBlock))
#define Size_PartialSumPerBlock (((NUM_SCAN_BLOCKS + TILE_STATUS_PADDING) * (Stride_PartialSumPerBlock)))


#define Load_LookBackFlag(tileIdx) \
	LookBackTable.Load(															\
		Addr_FlagPerLookBackBlock +												\
		(TILE_STATUS_PADDING + tileIdx) * (int)Stride_FlagPerLookBackBlock		\
	)																			\
        
#define Store_LookBackFlag(tileIdx, data) \
	LookBackTable.Store(														\
		Addr_FlagPerLookBackBlock +                                             \
        (TILE_STATUS_PADDING + tileIdx) * (int)Stride_FlagPerLookBackBlock,     \
		data																	\
	)																			\

#define Store_LookBackFlag_Padding(paddingIdx, data) \
	LookBackTable.Store(														\
		Addr_FlagPerLookBackBlock +												\
        (paddingIdx) * (int)Stride_FlagPerLookBackBlock,						\
		data																	\
	)																			\


#define Load_LookBackSum(tag, tileIdx) \
	UINT_TO_T(                                                          \
		LookBackTable.LOAD_SCAN_VAL(                                    \
			CAT(Addr_, tag) +                                           \
			(TILE_STATUS_PADDING + tileIdx) * (int)CAT(Stride_, tag)    \
		)                                                               \
	)                                                                   \
        
#define Store_LookBackSum(tag, tileIdx, data) \
	LookBackTable.STORE_SCAN_VAL(                                       \
		CAT(Addr_, tag) +                                               \
        (TILE_STATUS_PADDING + tileIdx) * (int)CAT(Stride_, tag),       \
		T_TO_UINT(data)                                                 \
	)                                                                   \

#define Store_LookBackSum_Padding(tag, paddingIdx, data) \
	LookBackTable.STORE_SCAN_VAL(                           \
		CAT(Addr_, tag) +                                   \
        (paddingIdx) * (int)CAT(Stride_, tag),              \
		T_TO_UINT(data)                                     \
	)                                                       \


#define DECLARE_FUNC_INIT_SCAN_LOOKBACK_BUFFER(T)										\
/* Initialize (from device) */																\
void CAT(InitializeLookBackTable_, tag)(												\
    uint3 idx : SV_DispatchThreadID, 													\
	uint numCleanerThreads, 															\
	uint numGroups																		\
){																						\
	/* 1) Zero counter */																\
    if (idx.x == 0u)																	\
    { 																					\
	    LookBackTable.Store(															\
			Addr_LookBackBlockCounter, 0u												\
        );																				\
    }																					\
																						\
	/* 2) Init look-back data */														\
	bool clear_thread = idx.x < numCleanerThreads;										\
	uint clear_stride = (numGroups + numCleanerThreads - 1) / numCleanerThreads;		\
	for (uint i = 0; i < clear_stride; ++i)												\
	{																					\
		uint clear_tile_idx = idx.x * clear_stride + i;									\
		if (clear_tile_idx < numGroups && clear_thread)									\
	    {																				\
	        /* Not-yet-set */															\
    		Store_LookBackSum(InclusiveSumPerBlock, clear_tile_idx, T_IDENTITY);		\
    		Store_LookBackSum(PartialSumPerBlock,   clear_tile_idx, T_IDENTITY);		\
    		Store_LookBackFlag(clear_tile_idx, SCAN_TILE_INVALID);						\
	    }																				\
	}																					\
																						\
																						\
	clear_stride = (TILE_STATUS_PADDING + numCleanerThreads - 1) / numCleanerThreads;	\
	for (uint i = 0; i < clear_stride; ++i)												\
	{																					\
		uint padding_idx = idx.x * clear_stride + i;									\
	    if (padding_idx < TILE_STATUS_PADDING)											\
	    {																				\
	        /* Padding */																\
    		Store_LookBackSum_Padding(InclusiveSumPerBlock, padding_idx, T_IDENTITY);	\
    		Store_LookBackSum_Padding(PartialSumPerBlock,   padding_idx, T_IDENTITY);	\
    		Store_LookBackFlag_Padding(padding_idx, SCAN_TILE_OOB);						\
	    }																				\
	}																					\
}																						\




#define DECLARE_FUNC_SCAN_SET_LOOKBACK_INCLUSIVE(T)										\
/* Update the specified tile's inclusive value and corresponding status	*/				\
void CAT(SetInclusive_, tag)(int tile_idx, int numGroups, T tile_inclusive)				\
{																						\
    /* Update tile partial value */														\
    Store_LookBackSum(InclusiveSumPerBlock, tile_idx, tile_inclusive);					\
																						\
    /* Fence */																			\
    DeviceMemoryBarrier(); /* This fence does not do anything */ 						\
																						\
    /* Update tile status */															\
    Store_LookBackFlag(tile_idx, SCAN_TILE_INCLUSIVE);									\
}																						\




#define DECLARE_FUNC_SCAN_SET_LOOKBACK_PARTIAL(T)										\
/* Update the specified tile's partial value and corresponding status */				\
void CAT(SetPartial_, tag)(int tile_idx, int numGroups, T tile_partial)					\
{																						\
    /* Update tile partial value */														\
    Store_LookBackSum(PartialSumPerBlock, tile_idx, tile_partial);						\
																						\
    /* Fence */																			\
    DeviceMemoryBarrier(); /* This fence does not do anything */ 						\
																						\
    /* Update tile status */															\
    Store_LookBackFlag(tile_idx, SCAN_TILE_PARTIAL);									\
}																						\



 
#define DECLARE_FUNC_SCAN_WAIT_FOR_VALID_LOOKBACK(T)								\
/* Wait for the corresponding tile to become non-invalid	*/						\
void CAT(WaitForValid_, tag)(														\
        int             tile_idx,													\
		int             numGroups, 													\
        out uint        status,														\
        out T           value														\
){																					\
    status = SCAN_TILE_INVALID;														\
	value  = T_IDENTITY;															\
																					\
																					\
	while ((status == SCAN_TILE_INVALID)) \
    {																				\
		DeviceMemoryBarrier();														\
        status = Load_LookBackFlag(tile_idx);										\
    }																				\
																					\
																					\
	DeviceMemoryBarrier();															\
																					\
																					\
	if (status == SCAN_TILE_PARTIAL){												\
        value =																		\
            Load_LookBackSum(PartialSumPerBlock, tile_idx);							\
    }																				\
    if (status == SCAN_TILE_INCLUSIVE){												\
        value = 																	\
            Load_LookBackSum(InclusiveSumPerBlock, tile_idx);						\
    }																				\
																					\
}																					\




// -----------------------------------------------------------------------------
// Intra-Wave SegScan, see Figure.3 in paper
// "Efficient Parallel Scan Algorithms for GPUs"
#define WARP_SEGSCAN_PASS(i)													\
	prev = WaveReadLaneAt(scanResWarp, laneId - i);								\
	scanResWarp =																\
		((i <= distToSeghead) ? (SCAN_OP(prev, scanResWarp)) : scanResWarp);	\

#define DECLARE_FUNC_SEGSCAN_WAVE_INC(T)					\
T CAT(SegScanWave_, tag)(									\
	bool inclusive,											\
	uint laneId, T val, bool hf,  							\
	out bool hfIncSumWave /* wave inclusive OR-reduction of hf */ \
)																				\
{																				\
	T scanResWarp = val;														\
																				\
	uint laneMaskRt = /* Inclusive lane mask */									\
		((~(0u)) >> (WaveGetLaneCount() - 1 - laneId));							\
	uint hfBitMaskWholeWave = WaveActiveBallot(hf);								\
	uint hfBitMaskPrevLanes = (hfBitMaskWholeWave & laneMaskRt);				\
	hfIncSumWave = hfBitMaskWholeWave.x != 0;									\
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
	/* output inclusive sum */					                                \
	return scanResWarp; 											            \
}																				\
// -----------------------------------------------------------------------------



#define DECLARE_FUNC_SCAN_PROCESS_LOOKBACK_WINDOW(T)																	\
/* Block until all predecessors within the warp-wide window have non-invalid status */								\
void CAT(ProcessWindow_, tag)(																									\
    int         predecessor_idx,    /*Preceding tile index to inspect*/												\
    int         numGroups, 																							\
    out uint	predecessor_status, /*[out] Preceding tile status*/													\
    out T		window_aggregate    /*[out] Relevant partial reduction from this window of preceding tiles*/		\
)   																												\
{																													\
	/* Busy-wait for a valid look-back sum,*/																		\
	/* either partial or inclusive */																				\
    T value;																							\
    CAT(WaitForValid_, tag)(																						\
		predecessor_idx, numGroups,																					\
		predecessor_status, value 																					\
	);																												\
																													\
																													\
    /* Perform a segmented reduction to get the prefix for the current window. */									\
    /* Here we scan *backwards* because we are now scanning *down* towards thread0. */								\
	uint lane_id     = WaveGetLaneIndex();																			\
	T    segscan_val = value;																						\
	bool segscan_hf  = (predecessor_status == SCAN_TILE_INCLUSIVE);													\
																													\
	bool hfIncSum;																												\
    T segscan_res = 																								\
        CAT(SegScanWave_, tag)(																						\
			true, lane_id, 																							\
			segscan_val, segscan_hf, 																					\
			/*out*/ hfIncSum \
		);																											\
	window_aggregate = WaveReadLaneAt(segscan_res, WaveGetLaneCount() - 1);											\
}																													\




/* BlockScan prefix callback functor (called by the first warp) */		
/* SCAN_LOOK_BACK_CACHE *must be initialized* before this function call */
#define DECLARE_FUNC_SCAN_DECOUPLED_LOOK_BACK(T)							\
void CAT(DecoupledLookBack_, tag)(																					\
    uint tile_idx, uint laneId, uint numGroups, 																	\
    T lookbackPredVal																								\
){																													\
    T inclusive_prefix, exclusive_prefix;																			\
																													\
    /* Update our status with our tile-partial-sum */																\
    if (laneId == 0)																								\
    {																												\
    	if (0 != tile_idx)																							\
    	{																											\
    		CAT(SetPartial_, tag)(tile_idx, numGroups, lookbackPredVal);											\
    	}else																										\
    	{																											\
    		CAT(SetInclusive_, tag)(tile_idx, numGroups, lookbackPredVal);											\
    	}																											\
    }																												\
    																												\
    DeviceMemoryBarrier();																							\
    																												\
	/* Keep sliding the window back until */																		\
    /* we come across a tile			  */																		\
    /* whose inclusive prefix is known    */																		\
    int         predecessor_idx = (int)tile_idx - 32 + (int)laneId;													\
    uint        predecessor_status = SCAN_TILE_INVALID;																\
    T           window_aggregate;																					\
																													\
    exclusive_prefix = T_IDENTITY;																					\
																													\
	while (0 < tile_idx && !WaveActiveAnyTrue(predecessor_status == SCAN_TILE_INCLUSIVE))							\
    {																												\
		DeviceMemoryBarrier();																						\
		/* --- Update exclusive tile prefix with the window prefix --- */											\
		CAT(ProcessWindow_, tag)(																					\
			predecessor_idx, numGroups,																				\
			predecessor_status, window_aggregate																	\
		);																											\
        exclusive_prefix = OP(window_aggregate, exclusive_prefix);													\
        predecessor_idx -= (int)(32u);																				\
    }																												\
																													\
    DeviceMemoryBarrier();																							\
																													\
    /* Compute the inclusive tile prefix and update the status for this tile */										\
    if (laneId.x == 0)																								\
    {																												\
        inclusive_prefix = OP(exclusive_prefix, lookbackPredVal);													\
		CAT(SetInclusive_, tag)(tile_idx, numGroups, inclusive_prefix);												\
																													\
    	SCAN_LOOK_BACK_CACHE.inclusive_prefix = inclusive_prefix;													\
    	SCAN_LOOK_BACK_CACHE.exclusive_prefix = exclusive_prefix;													\
    }																												\
}																													\


#define DECLARE_FUNC_SEGSCAN_PROCESS_LOOKBACK_WINDOW(T)																\
/* Block until all predecessors within the warp-wide window have non-invalid status */								\
void CAT(ProcessWindow_SegScan_, tag)(																				\
    int         predecessor_idx,    /*Preceding tile index to inspect*/												\
    int         numGroups, 																							\
    out uint	predecessor_status, /*[out] Preceding tile status*/													\
    out T		window_aggregate,   /*[out] Relevant partial reduction from this window of preceding tiles*/		\
    out bool	window_hf			/*[out] Relevant partial reduction from this window of preceding tiles*/		\
)   																												\
{																													\
	/* Busy-wait for a valid look-back sum,*/																		\
	/* either partial or inclusive */																				\
    T value;																										\
    CAT(WaitForValid_, tag)(																						\
		predecessor_idx, numGroups,																					\
		predecessor_status, value 																					\
	);																												\
																													\
																													\
    /* Perform a segmented reduction to get the prefix for the current window. */									\
    /* Here we scan *backwards* because we are now scanning *down* towards thread0. */								\
	uint lane_id     = WaveGetLaneIndex();																			\
	T    segscan_val = value;																						\
	bool segscan_hf  = (predecessor_status == SCAN_TILE_INCLUSIVE);													\
																													\
	bool wave_hf_sum;																								\
    T segscan_res = 																								\
        CAT(SegScanWave_, tag)(																						\
			true, lane_id, 																							\
			segscan_val, segscan_hf, 																				\
			/*out*/wave_hf_sum																						\
		);																											\
	window_aggregate = WaveReadLaneAt(segscan_res, WaveGetLaneCount() - 1);											\
	window_hf		 = wave_hf_sum;																					\
}																													\




/* BlockSegScan prefix callback functor (called by the first warp) */		
/* SCAN_LOOK_BACK_CACHE *must be initialized* before this function call */
#define DECLARE_FUNC_SEGSCAN_DECOUPLED_LOOK_BACK(T)							\
void CAT(DecoupledLookBack_SegScan_, tag)(																			\
    uint tile_idx, uint laneId, uint numGroups, 																	\
    T blockSum, bool blockHFInc																						\
){																													\
    T inclusive_prefix, exclusive_prefix;																			\
																													\
	bool earlySetInclusive = ((tile_idx == 0) || (blockHFInc));														\
    /* Update our status with our tile-partial-sum */																\
    if (laneId == 0)																								\
    {																												\
    	if (!earlySetInclusive)																						\
    	{																											\
    		CAT(SetPartial_, tag)(tile_idx, numGroups, blockSum);													\
    	}else																										\
    	{																											\
    		CAT(SetInclusive_, tag)(tile_idx, numGroups, blockSum);													\
    	}																											\
    }																												\
    																												\
    DeviceMemoryBarrier();																							\
    																												\
	/* Keep sliding the window back until */																		\
    /* we come across a tile			  */																		\
    /* whose inclusive prefix is known    */																		\
    int         predecessor_idx = (int)tile_idx - 32 + (int)laneId;													\
    uint        predecessor_status = SCAN_TILE_INVALID;																\
    T           window_aggregate;																					\
	bool		window_hf;																							\
																													\
    exclusive_prefix = T_IDENTITY;																					\
																													\
	while (0 < tile_idx && !WaveActiveAnyTrue(predecessor_status == SCAN_TILE_INCLUSIVE))							\
    {																												\
		DeviceMemoryBarrier();																						\
		/* --- Update exclusive tile prefix with the window prefix --- */											\
		CAT(ProcessWindow_SegScan_, tag)(																			\
			predecessor_idx, numGroups,																				\
			predecessor_status, window_aggregate, window_hf															\
		);																											\
																													\
        exclusive_prefix = OP(window_aggregate, exclusive_prefix);													\
        predecessor_idx -= (int)(32u);																				\
    }																												\
																													\
    DeviceMemoryBarrier();																							\
																													\
    /* Compute the inclusive tile prefix and update the status for this tile */										\
    if (laneId.x == 0)																								\
    {																												\
		inclusive_prefix = blockHFInc ? blockSum : OP(exclusive_prefix, blockSum);									\
        if (!earlySetInclusive)																						\
        {																											\
			CAT(SetInclusive_, tag)(tile_idx, numGroups, inclusive_prefix);											\
		}																											\
    	SCAN_LOOK_BACK_CACHE.inclusive_prefix = inclusive_prefix;													\
    	SCAN_LOOK_BACK_CACHE.exclusive_prefix = exclusive_prefix;													\
    }																												\
}


#define DECLARE_FUNC_SCAN_SINGLE_PASS(T) \
T CAT(ScanDevice_DecoupledLookBack_, tag)(														\
    uint groupIdx, uint numGroups, 													\
    T scan_val, T block_scan_res, bool inclusive									\
){																					\
	uint tile_idx = DYNAMIC_TILE_ID_CACHE;											\
																					\
    /* Broadcast inclusive block partial sum */										\
	if (groupIdx == SCAN_BLOCK_SIZE - 1u)											\
	{																				\
		SCAN_LOOK_BACK_CACHE.block_inclusive_sum = 									\
            inclusive ? block_scan_res : OP(block_scan_res, scan_val);				\
	}																				\
	AllMemoryBarrierWithGroupSync();												\
																					\
																					\
	T block_partial_sum = SCAN_LOOK_BACK_CACHE.block_inclusive_sum;					\
																					\
																					\
	uint waveId = groupIdx / WaveGetLaneCount();									\
	uint laneId = WaveGetLaneIndex();												\
	if (waveId == 0u)																\
	{																				\
		CAT(DecoupledLookBack_, tag)(												\
			tile_idx, laneId, numGroups,											\
	        block_partial_sum														\
	    );																			\
	}																				\
    AllMemoryBarrierWithGroupSync();												\
																					\
	return OP(SCAN_LOOK_BACK_CACHE.exclusive_prefix, block_scan_res);									\
}																					\


#define DECLARE_FUNC_SEGSCAN_SINGLE_PASS(T) \
T CAT(SegScanDevice_DecoupledLookBack_, tag)(														\
    uint groupIdx, uint numGroups, 													\
    T scan_val, T block_scan_res, bool block_hf_inc, bool inclusive					\
    , uint inspectWaveId = 0 \
){																					\
	uint tile_idx = DYNAMIC_TILE_ID_CACHE;											\
																					\
    /* Broadcast inclusive block partial sum */										\
	if (groupIdx == SCAN_BLOCK_SIZE - 1u)											\
	{																				\
		SCAN_LOOK_BACK_CACHE.block_inclusive_sum = 									\
            inclusive ? block_scan_res : OP(block_scan_res, scan_val);				\
        SEGSCAN_LOOK_BACK_CACHE.block_inclusive_hf = block_hf_inc;					\
	}																				\
	AllMemoryBarrierWithGroupSync();												\
																					\
																					\
	T block_partial_sum = SCAN_LOOK_BACK_CACHE.block_inclusive_sum;					\
	bool block_hf_sum = SEGSCAN_LOOK_BACK_CACHE.block_inclusive_hf;					\
																					\
																					\
	uint waveId = groupIdx / WaveGetLaneCount();									\
	uint laneId = WaveGetLaneIndex();												\
	if (waveId == inspectWaveId)													\
	{																				\
		CAT(DecoupledLookBack_SegScan_, tag)(										\
			tile_idx, laneId, numGroups,											\
	        block_partial_sum, block_hf_sum											\
	    );																			\
	}																				\
    AllMemoryBarrierWithGroupSync();												\
																					\
	return block_hf_inc ? block_scan_res :											\
		OP(SCAN_LOOK_BACK_CACHE.exclusive_prefix, block_scan_res);					\
}																					\


#ifndef DECLARE_FUNC_REGISTER_DYNAMIC_BLOCK_ID

#define DECLARE_FUNC_REGISTER_DYNAMIC_BLOCK_ID											\
void CAT(RegisterAsDynamicBlock_, tag)(uint groupIdx, out uint tile_idx, out uint idx_dyn)	\
{																						\
	if (groupIdx == 0)																	\
	{																					\
		LookBackTable.InterlockedAdd(													\
			Addr_LookBackBlockCounter,													\
            1u,																			\
            DYNAMIC_TILE_ID_CACHE														\
        );																				\
	}																					\
																						\
	AllMemoryBarrierWithGroupSync();													\
																						\
	tile_idx = DYNAMIC_TILE_ID_CACHE;													\
	idx_dyn = tile_idx * SCAN_BLOCK_SIZE + groupIdx;									\
}																						\

#endif

#endif /* _INCLUDED */
