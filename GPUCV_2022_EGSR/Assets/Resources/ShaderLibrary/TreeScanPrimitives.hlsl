#ifndef TREESCANPROMITIVES_INCLUDED
#define TREESCANPROMITIVES_INCLUDED

// Macro expansion, for details, see
// ---------------------------------------
// https://stackoverflow.com/questions/1489932/how-to-concatenate-twice-with-the-c-preprocessor-and-expand-a-macro-as-in-arg
#define CAT(x, y) CAT_(x, y)
#define CAT_(x, y) x ## y

// Type & Type conversion & Scan OP
// ---------------------------------------
#define T SCAN_SCALAR_TYPE
#define tag SCAN_FUNCTION_TAG
#define OP SCAN_OP

#ifdef SCAN_DATA_TYPE_NON_UINT
#	define AS_T CAT(as, SCAN_SCALAR_TYPE)
#   define UINT_TO_T(x) (AS_T(x))
#   define T_TO_UINT(x) (asuint(x))
#else
#   define UINT_TO_T(x) (x)
#   define T_TO_UINT(x) (x)
#endif

// How may word is used as reduce data in 2nd-seg-scan step
#define SEG_SCAN_REDUCE_STRIDE 2
#define SEGSCAN_REDUCE_DATA_ADDR(blockIndex) ((((blockIndex) * SEG_SCAN_REDUCE_STRIDE) << BITS_WORD_OFFSET))

// Padding Macros for Eliminating Bank Conflicts
// Input: SCAN_BLOCK_SIZE
// ---------------------------------------------------------
#define NUM_BANKS       32
#define LOG_NUM_BANKS   5
#define OFFSET_BANK_CONFLICT_FREE(x) ((x) >> LOG_NUM_BANKS)

#define DATA_SIZE       (2 * SCAN_BLOCK_SIZE)

// Tree Scan LDS Caches
// ------------------------------------------------------------
#define TREE_SCAN_CACHE CAT(TreeScanCache, tag)
#define TREE_SCAN_CACHE_SIZE (DATA_SIZE + DATA_SIZE / NUM_BANKS)
#define TREE_SCAN_CACHE_HF CAT(TreeScanCacheHF, tag)

#define DECLARE_TREE_SCAN_CACHE \
	groupshared T TREE_SCAN_CACHE[TREE_SCAN_CACHE_SIZE]; \

#define DECLARE_TREE_SCAN_CACHE_HF \
	groupshared uint TREE_SCAN_CACHE_HF[TREE_SCAN_CACHE_SIZE]; \

#define DECLARE_SCAN_LOOK_BACK_DATA(INVALID_LOOK_BACK_VAL)		\
bool IsInvalid(uint lookBackData)								\
{																\
	return (lookBackData == INVALID_LOOK_BACK_VAL);				\
}																\
float DecodeLookBackVal(uint lookBackData)						\
{																\
	return UINT_TO_T(lookBackData);								\
}																\
uint EncodeLookBackVal(float val)								\
{																\
	return T_TO_UINT(val);										\
}																\



/**
 * \brief Encode head flag after tree reduction with initial head flag.
 * \return headFlag | (initHeadFlag << 1)
 */
uint EncodeHeadFlags(uint currHeadFlag, uint originalHeadFlag)
{
	return currHeadFlag | (originalHeadFlag << 1);
}

#define DECODE_CURR_HF(cached) (((cached) & 1))
#define DECODE_ORIG_HF(cached) (((cached) >> 1))


#ifdef SCAN_DATA_TYPE_NON_UINT

#define SEGSCAN_GLOBAL_DATA_STRIDE 2
#define DECLARE_ENCODE_HF_DATA_FUNCTION                                                       \
/**                                                                                           \
 * \brief Encodes up-sweep result(data+head-flag) and initial head-flag                       \
 * \param partialORTreeHF head-flag after upsweep                                             \
 * \param originalHF original head-flag before upsweep                                        \
 * \param partialSumTreeVal partial sum of segmented data after upsweep                       \
 * \return packed data, .x: encoded flags, .y: partial sum as uint                            \
 */                                                                                           \
uint2 EncodeHFAndData(bool originalHF, bool partialORTreeHF, T partialSumTreeData)            \
{                                                                                             \
    return uint2(												                              \
		EncodeHeadFlags(partialORTreeHF, originalHF),	                                      \
		T_TO_UINT(partialSumTreeData)							                              \
	);															                              \
}                                                                                             \

#define GET_REDUCE_DATA_ENCODED_HF(data) (((data).x))
#define GET_REDUCE_DATA_INIT_HF(data) (((data).x >> 1))
#define GET_REDUCE_DATA_CURR_HF(data) (((data).x & 1))
#define GET_REDUCE_DATA_BLOCK_SUM(data) ((UINT_TO_T(data.y)))

#define SEGSCAN_STORE_GLOBAL CAT(Store, SEGSCAN_GLOBAL_DATA_STRIDE)
#define SEGSCAN_LOAD_GLOBAL CAT(Load, SEGSCAN_GLOBAL_DATA_STRIDE)

#else

#define SEGSCAN_GLOBAL_DATA_STRIDE 1
#define DECLARE_ENCODE_HF_DATA_FUNCTION															\
/**																								\
 * \brief Encodes up-sweep result(data+head-flag) and initial head-flag							\
 * \param partialORTreeHF head-flag after upsweep												\
 * \param originalHF original head-flag before upsweep											\
 * \param partialSumTreeVal partial sum of segmented data after upsweep							\
 * \return packed data, low 2 bits for encoded flags, higher bits for data						\
 */																								\
uint EncodeHFAndData(bool originalHF, bool partialORTreeHF, uint partialSumTreeData)			\
{																								\
    return      																				\
		(partialSumTreeData << 2) | (EncodeHeadFlags(partialORTreeHF, originalHF));				\
}																								\

#define GET_REDUCE_DATA_ENCODED_HF(data) (((data) & 3))
#define GET_REDUCE_DATA_INIT_HF(data) (DECODE_ORIG_HF(GET_REDUCE_DATA_ENCODED_HF(data)))
#define GET_REDUCE_DATA_CURR_HF(data) (DECODE_CURR_HF(GET_REDUCE_DATA_ENCODED_HF(data)))
#define GET_REDUCE_DATA_BLOCK_SUM(data) ((data) >> 2)

#define SEGSCAN_STORE_GLOBAL Store
#define SEGSCAN_LOAD_GLOBAL Load

#endif

#define SEGSCAN_GLOBAL_DATA_ADDR(index) ((((index) * SEGSCAN_GLOBAL_DATA_STRIDE) << BITS_WORD_OFFSET))

// Returns (Global_scanAddr0, Global_scanAddr1, LDS_scanAddr0, LDS_scanAddr1)
// LDS_scanAddr0/1 : index of element 0/1 in shared memory
// Global_scanAddr0/1 : index of element in global compute buffer
/**
 * \brief Returns (Global_scanAddr0, Global_scanAddr1, LDS_scanAddr0, LDS_scanAddr1)
 *			LDS_scanAddr0/1 : index of element 0/1 in shared memory
 *			Global_scanAddr0/1 : index of element in global compute buffer
 */
#define DECLARE_TREE_SCAN_INDEXING_FUNCTION \
uint4 GetTreeScanIndices(					\
	uint groupIdx : SV_GroupIndex,			\
	uint3 gIdx : SV_GroupID					\
){  																				\
	const uint groupOffset = (DATA_SIZE) * gIdx.x;									\
																					\
	uint ai = groupIdx; /*   0   1   2   3 ... 255  => ai						*/	\
	/* ------ + 1 * 512 ------- (Suppose gIdx.x == 1)						*/		\
	uint scanAddrA = groupOffset + ai; /* 512 513 514 515 ... 767  => scanAddrA	*/	\
																					\
	uint bi = ai + DATA_SIZE / 2; /* 256 257 258 259 ... 511   => bi			*/	\
	uint scanAddrB = groupOffset + bi; /* 768 641 642 643 ... 1151  => scanAddrB*/	\
																					\
	return uint4(scanAddrA, scanAddrB, ai, bi);										\
} \


#define DECLARE_TREE_SCAN_FUNC_BLOCK \
    CAT(T, 2) CAT(TreeScanBlockExc, tag)( \
        uint groupIdx, \
        uint3 gIdx : SV_GroupID, \
        T initialDataAi, \
        T initialDataBi  \
    ){ \
		uint4 scanAddrs = GetTreeScanIndices(groupIdx, gIdx);						  \
		uint ai = scanAddrs.z; \
		uint bi = scanAddrs.w; \
        /* Bank Offset == index >> bits_banks(5 in Nvidia card) */                    \
        uint aiOffset = OFFSET_BANK_CONFLICT_FREE(ai);                                \
        uint biOffset = OFFSET_BANK_CONFLICT_FREE(bi);                                \
                                                                                        \
        /*  Store data into LDS with memory bank offset                               \
        ---------------------------------------------------------------------         \
        about 'tailvalue':                                                            \
        in prefix sum, last elem is going to be erased                                \
        but we will need it later, so cache it here                                 */\
        TREE_SCAN_CACHE[ai + aiOffset] = initialDataAi;                                     \
        TREE_SCAN_CACHE[bi + biOffset] = initialDataBi;                                     \
        /* about LDS memory layout:                                                   \
        Interleaved storage,                                                          \
        that is, ith(i % 32 == 0) is not used;                                        \
        e.g:                                                                          \
        [0, 31]  X [32, 63] X  [64, 95]  X [96, 127]  -- Input CBuffer                \
            + 0________+1___________+2___________+3 ... -- + OFFSET_BANK...(x)        \
        [0, 31] 32 [33, 64] 65 [66, 97] 98 [99, 130]  -- TREE_SCAN_CACHE                   */\
        \
        \
        \
        /* //////////////////////////////////////////////////////////////////////// */\
        /* Scan --- Phase II        Up-Sweeping                                     */\
        /* Work Indices:                                                            */\
        /* offset = 2^k                                                             */\
        /* a(i, k) = (2^k) * (2i + 1) - 1 = (2*gidx)*offset + offset - 1            */\
        /* b(i, k) = a(i, k) + 2^k = a(i, k) + offset                               */\
        /* i ~ groupIdx, k ~ iteration, all start from 0.                           */\
        uint offset = 1;     /* Step Length == 2^k */                                 \
        uint d = DATA_SIZE / 2; /* [0, ... , d]th threads are dispatched */            \
        for (; d > 0; d >>= 1){                                                       \
            GroupMemoryBarrierWithGroupSync();                                        \
            if (groupIdx < d){                                                        \
                ai = offset * (2 * groupIdx + 1) - 1;                                 \
                bi = offset * (2 * groupIdx + 2) - 1;                                 \
                ai += OFFSET_BANK_CONFLICT_FREE(ai);                                  \
                bi += OFFSET_BANK_CONFLICT_FREE(bi);                                  \
                                                                                        \
                TREE_SCAN_CACHE[bi] = OP(TREE_SCAN_CACHE[ai], TREE_SCAN_CACHE[bi]);		\
            }                                                                         \
            offset *= 2;                                                              \
        }                                                                             \
        \
        \
        \
        /* ////////////////////////////////////////////////////////////////////////*/ \
        /* Phase III */                                                               \
        if (groupIdx == 0){                                                           \
            /* Zero out last elem, prepare for up-sweeping */                         \
            uint lastIndex = DATA_SIZE - 1 + OFFSET_BANK_CONFLICT_FREE(DATA_SIZE - 1);  \
            TREE_SCAN_CACHE[lastIndex] = SCAN_ZERO_VAL;                                     \
        }                                                                             \
        \
        \
        \
        /* ///////////////////////////////////////////////////////////////////////// */\
        /* Phase IV                 Down-Sweeping                                    */\
        /* Util this point,                                                          */\
        /* d == 0,                                                                   */\
        /* offset == GROUP_SIZE * 2 == DATA_SIZE                                      */\
        /* This is actually "rolling back + mirror" version of Phase I,              */\
        /* So this execution code is a mirrored loop                                 */\
        for (d = 1; d < DATA_SIZE; d *= 2){                                            \
            offset >>= 1;                                                             \
            GroupMemoryBarrierWithGroupSync();                                        \
            if (groupIdx < d){                                                        \
                /* So the indexing function is the same, (rolling back)               \
                just the roles of ai & bi are switched                              */\
                ai = offset * (2 * groupIdx + 1) - 1;                                 \
                bi = offset * (2 * groupIdx + 2) - 1;                                 \
                ai += OFFSET_BANK_CONFLICT_FREE(ai);                                  \
                bi += OFFSET_BANK_CONFLICT_FREE(bi);                                  \
                /* swap */                                                            \
                T aiValOld = TREE_SCAN_CACHE[ai];                                        \
                TREE_SCAN_CACHE[ai] = TREE_SCAN_CACHE[bi];                               \
                TREE_SCAN_CACHE[bi] = OP(aiValOld, TREE_SCAN_CACHE[bi]);              \
            }                                                                         \
        }                                                                             \
        GroupMemoryBarrierWithGroupSync();                                            \
        \
        \
        \
        T pSumAtAi = TREE_SCAN_CACHE[groupIdx + aiOffset];                               \
        T pSumAtBi = TREE_SCAN_CACHE[groupIdx + SCAN_BLOCK_SIZE + biOffset];             \
        \
        \
        return CAT(T, 2)(pSumAtAi, pSumAtBi);											\
    } \


#define DECLARE_TREE_SCAN_FUNC_DEVICE \
void CAT(TreeScanDevice, tag)(																	\
	uint groupIdx : SV_GroupIndex)																\
{																								\
	/* scanAddrs: */																			\
	/* -- .x: Global_scanAddr0, .y: Global_scanAddr1,	*/										\
	/* -- .z: LDS_scanAddr0, .w: LDS_scanAddr1			*/										\
	const uint4 scanAddrs = GetTreeScanIndices(groupIdx, 0);									\
	T blockSum0 = UINT_TO_T(REDUCED_BUFFER.Load(scanAddrs.x << 2));								\
	T blockSum1 = UINT_TO_T(REDUCED_BUFFER.Load(scanAddrs.y << 2));								\
																								\
	CAT(T, 2) res = CAT(TreeScanBlockExc, tag)													\
	(																							\
		groupIdx, 0,																			\
		blockSum0, blockSum1																	\
	);																							\
	/* inclusive sum needed*/																	\
	REDUCED_BUFFER.Store(scanAddrs.x << 2, T_TO_UINT(res.x));									\
	REDUCED_BUFFER.Store(scanAddrs.y << 2, T_TO_UINT(res.y));									\
}																								\



#define DECLARE_TREE_SCAN_FUNC_DWSWEEP \
vector<T, 2> CAT(TreeScanDownSweep, tag)(uint groupIdx : SV_GroupIndex, uint3 gIdx : SV_GroupID)	\
{																								\
	uint4 scanAddrs = GetTreeScanIndices(groupIdx, gIdx);										\
	vector<T, 2> blockSumAiBi =																	\
		UINT_TO_T(																				\
			uint2(																				\
				(SCAN_BUFFER.Load(scanAddrs.x << 2)),											\
				(SCAN_BUFFER.Load(scanAddrs.y << 2))											\
			));																					\
	T prevBlockSum = UINT_TO_T(REDUCED_BUFFER.Load((gIdx.x) << 2));								\
	return vector<T, 2>(																		\
		OP(prevBlockSum, blockSumAiBi.x),														\
		OP(prevBlockSum, blockSumAiBi.y)														\
	);																							\
}																								\



#define DECLARE_TREE_SCAN_FUNC_DEVICE_LOOKBACK(lookbackbuffer) \
T CAT(TreeScanDeviceExc, tag)(uint blockId, uint tid, T dataBi, CAT(T, 2) val)           \
{																		\
	uint blockLast = SCAN_BLOCK_SIZE - 1;								\
																		\
	/* Step 4: Inspector thread(s) look-back for prev block sum */    \
	bool isInspectorThread = tid == 0;                                \
	uint lookBackAddr = (blockId - 1) << BITS_WORD_OFFSET;            \
	uint lookBackData = 0;                                            \
	if (blockId != 0 && isInspectorThread)                            \
	{                                                                 \
		lookBackData = lookbackbuffer.Load(lookBackAddr);                \
		[allow_uav_condition]                                            \
		while ((IsInvalid(lookBackData)))                                \
		{                                                                \
			DeviceMemoryBarrier();                                          \
			lookBackData = lookbackbuffer.Load(lookBackAddr);               \
		}                                                                \
		TREE_SCAN_CACHE[tid] = DecodeLookBackVal(lookBackData);             \
	}                                                                 \
	GroupMemoryBarrierWithGroupSync();                                \
																			\
																			\
	/* Step 5: Accumulate results from Step 3, as appropriate . */			\
	T prevBlockTotal = TREE_SCAN_CACHE[0];										\
	val.x = OP(prevBlockTotal, val.x);										\
	val.y = OP(prevBlockTotal, val.y);										\
	GroupMemoryBarrierWithGroupSync();										\
																			\
																			\
	/* Step 6: The last thread in each block writes partial results */\
	if (tid == blockLast)                                             \
	{                                                                 \
		lookbackbuffer.Store(                                            \
			blockId << BITS_WORD_OFFSET, /* Update pos */                   \
			EncodeLookBackVal(OP(val.y, dataBi))                                \
		);                                                               \
	}                                                                 \
                                                                   \
	return val;                                                       \
}                                                                  \


#define DECLARE_TREE_SEGSCAN_FUNC_UPSWEEP															\
DECLARE_ENCODE_HF_DATA_FUNCTION																		\
void CAT(TreeSegScanBlockExc_UpSweep_, tag)(														\
	uint groupIdx,																					\
	uint3 gIdx : SV_GroupID,																		\
	inout bool headFlagAi,																			\
	inout T initialDataAi,																			\
	inout bool headFlagBi,																			\
	inout T initialDataBi																			\
	)																								\
{																									\
	/* -------------------------------------------------------	*/									\
	/* nAddr:													*/									\
	/* .x: Global_scanAddr0, .y: Global_scanAddr1, 				*/									\
	/* .z: LDS_scanAddr0, .w: LDS_scanAddr1						*/									\
	const uint4 scanAddrs = GetTreeScanIndices(groupIdx, gIdx.x);									\
	uint ai = scanAddrs.z;																			\
	uint bi = scanAddrs.w;																			\
																									\
	/* Bank Offset == index >> bits_banks(5 in Nvidia card) */										\
	uint aiOffset = OFFSET_BANK_CONFLICT_FREE(ai);													\
	uint biOffset = OFFSET_BANK_CONFLICT_FREE(bi);													\
																									\
	/*  Store data into LDS with memory bank offset													\
	---------------------------------------------------------------------							\
	about 'tailvalue':																				\
	in prefix sum, last elem is going to be erased													\
	but we will need it later, so cache it here                                 */					\
	uint cacheAddrAi = ai + aiOffset;																\
	uint cacheAddrBi = bi + biOffset;																\
	TREE_SCAN_CACHE[cacheAddrAi] = initialDataAi;													\
	TREE_SCAN_CACHE_HF[cacheAddrAi] = headFlagAi;													\
	TREE_SCAN_CACHE[cacheAddrBi] = initialDataBi;													\
	TREE_SCAN_CACHE_HF[cacheAddrBi] = headFlagBi;													\
	/* about LDS memory layout:																		\
	Interleaved storage,																			\
	that is, ith(i % 32 == 0) is not used;															\
	e.g:																							\
	[0, 31]  X [32, 63] X  [64, 95]  X [96, 127]  -- Input CBuffer									\
		+ 0________+1___________+2___________+3 ... -- + OFFSET_BANK...(x)							\
	[0, 31] 32 [33, 64] 65 [66, 97] 98 [99, 130]  -- TREE_SCAN_CACHE			*/					\
																									\
																									\
	/* //////////////////////////////////////////////////////////////////////// */					\
	/* Scan --- Phase II        Up-Sweeping                                     */					\
	/* Work Indices:                                                            */					\
	/* offset = 2^k                                                             */					\
	/* a(i, k) = (2^k) * (2i + 1) - 1 = (2*gidx)*offset + offset - 1            */					\
	/* b(i, k) = a(i, k) + 2^k = a(i, k) + offset                               */					\
	/* i ~ groupIdx, k ~ iteration, all start from 0.                           */					\
	uint offset = 1; /* Step Length == 2^k */														\
	uint d = DATA_SIZE / 2; /* [0, ... , d]th threads are dispatched */								\
																									\
	bool activeThread;																				\
	for (; d > 0; d >>= 1)																			\
	{																								\
		activeThread = groupIdx < d;																\
																									\
		ai = offset * (2 * groupIdx + 1) - 1;														\
		bi = offset * (2 * groupIdx + 2) - 1;														\
		ai += OFFSET_BANK_CONFLICT_FREE(ai);														\
		bi += OFFSET_BANK_CONFLICT_FREE(bi);														\
																									\
		GroupMemoryBarrierWithGroupSync();															\
		bool isSegHeadAtBi = TREE_SCAN_CACHE_HF[bi];												\
		if (activeThread && (!isSegHeadAtBi))														\
		{																							\
			TREE_SCAN_CACHE[bi] = OP(TREE_SCAN_CACHE[ai], TREE_SCAN_CACHE[bi]);						\
		}																							\
																									\
		GroupMemoryBarrierWithGroupSync();															\
		TREE_SCAN_CACHE_HF[bi] =																	\
			activeThread																			\
			? isSegHeadAtBi || TREE_SCAN_CACHE_HF[ai]												\
			: isSegHeadAtBi;																		\
																									\
		offset *= 2;																				\
	}																								\
																									\
	GroupMemoryBarrierWithGroupSync();																\
																									\
	initialDataAi = TREE_SCAN_CACHE[cacheAddrAi];													\
	initialDataBi = TREE_SCAN_CACHE[cacheAddrBi];													\
	bool partialOrTreeAi = TREE_SCAN_CACHE_HF[cacheAddrAi];											\
	bool partialOrTreeBi = TREE_SCAN_CACHE_HF[cacheAddrBi];											\
																									\
	if (groupIdx == SCAN_BLOCK_SIZE - 1)															\
	{																								\
		REDUCED_BUFFER.SEGSCAN_STORE_GLOBAL(														\
			SEGSCAN_GLOBAL_DATA_ADDR(gIdx.x),														\
			EncodeHFAndData(																		\
				TREE_SCAN_CACHE_HF[0],																\
				partialOrTreeBi,																	\
				initialDataBi																		\
			)																						\
		);																							\
	}																								\
																									\
	SCAN_BUFFER.SEGSCAN_STORE_GLOBAL(																\
		SEGSCAN_GLOBAL_DATA_ADDR(scanAddrs.x),														\
		EncodeHFAndData(headFlagAi, partialOrTreeAi, initialDataAi)									\
	);																								\
	SCAN_BUFFER.SEGSCAN_STORE_GLOBAL(																\
		SEGSCAN_GLOBAL_DATA_ADDR(scanAddrs.y),														\
		EncodeHFAndData(headFlagBi, partialOrTreeBi, initialDataBi)									\
	);																								\
}																									\


#define DECLARE_TREE_SEGSCAN_FUNC_DEVICE																\
void CAT(TreeSegScanDeviceExc, tag)(																	\
	uint groupIdx : SV_GroupIndex																		\
)																										\
{																										\
	/* scanAddrs: */																					\
	/* -- .x: Global_scanAddr0, .y: Global_scanAddr1,	*/												\
	/* -- .z: LDS_scanAddr0, .w: LDS_scanAddr1			*/												\
	uint4 scanAddrs = GetTreeScanIndices(groupIdx, 0);													\
	uint ai = scanAddrs.z;																				\
	uint bi = scanAddrs.w;																				\
																										\
	uint2 reducedDataAi = REDUCED_BUFFER.SEGSCAN_LOAD_GLOBAL(											\
		(SEGSCAN_GLOBAL_DATA_ADDR(scanAddrs.x)));														\
	uint2 reducedDataBi = REDUCED_BUFFER.SEGSCAN_LOAD_GLOBAL(											\
		(SEGSCAN_GLOBAL_DATA_ADDR(scanAddrs.y)));														\
																										\
	T partialSumTreeAi = GET_REDUCE_DATA_BLOCK_SUM(reducedDataAi);										\
	uint partialOrTreeAi = GET_REDUCE_DATA_CURR_HF(reducedDataAi);										\
	uint firstInitialHFAi = GET_REDUCE_DATA_INIT_HF(reducedDataAi);										\
																										\
	T partialSumTreeBi = GET_REDUCE_DATA_BLOCK_SUM(reducedDataBi);										\
	uint partialOrTreeBi = GET_REDUCE_DATA_CURR_HF(reducedDataBi);										\
	uint firstInitialHFBi = GET_REDUCE_DATA_INIT_HF(reducedDataBi);										\
																										\
																										\
	/* Bank Offset == index >> bits_banks(5 in Nvidia card) */											\
	uint aiOffset = OFFSET_BANK_CONFLICT_FREE(ai);														\
	uint biOffset = OFFSET_BANK_CONFLICT_FREE(bi);														\
																										\
	uint cacheAddrAi = ai + aiOffset;																	\
	uint cacheAddrBi = bi + biOffset;																	\
																										\
	/*  Store data into LDS with memory bank offset														\
	---------------------------------------------------------------------								\
	about 'tailvalue':																					\
	in prefix sum, last elem is going to be erased														\
	but we will need it later, so cache it here                         */								\
	TREE_SCAN_CACHE[cacheAddrAi] = partialSumTreeAi;													\
	TREE_SCAN_CACHE_HF[cacheAddrAi] = partialOrTreeAi;													\
	TREE_SCAN_CACHE[cacheAddrBi] = partialSumTreeBi;													\
	TREE_SCAN_CACHE_HF[cacheAddrBi] = partialOrTreeBi;													\
	/* about LDS memory layout:																			\
	Interleaved storage,																				\
	that is, ith(i % 32 == 0) is not used;																\
	e.g:																								\
	[0, 31]  X [32, 63] X  [64, 95]  X [96, 127]  -- Input CBuffer										\
		+ 0________+1___________+2___________+3 ... -- + OFFSET_BANK...(x)								\
	[0, 31] 32 [33, 64] 65 [66, 97] 98 [99, 130]  -- TREE_SCAN_CACHE			*/						\
																										\
																										\
	/* //////////////////////////////////////////////////////////////////////// */						\
	/* Scan --- Phase II        Up-Sweeping                                     */						\
	/* Work Indices:                                                            */						\
	/* offset = 2^k                                                             */						\
	/* a(i, k) = (2^k) * (2i + 1) - 1 = (2*gidx)*offset + offset - 1            */						\
	/* b(i, k) = a(i, k) + 2^k = a(i, k) + offset                               */						\
	/* i ~ groupIdx, k ~ iteration, all start from 0.                           */						\
	uint offset = 1; /* Step Length == 2^k */															\
	uint d = DATA_SIZE / 2; /* [0, ... , d]th threads are dispatched */									\
																										\
	bool activeThread;																					\
	for (; d > 0; d >>= 1)																				\
	{																									\
		activeThread = groupIdx < d;																	\
																										\
		ai = offset * (2 * groupIdx + 1) - 1;															\
		bi = offset * (2 * groupIdx + 2) - 1;															\
		ai += OFFSET_BANK_CONFLICT_FREE(ai);															\
		bi += OFFSET_BANK_CONFLICT_FREE(bi);															\
																										\
		GroupMemoryBarrierWithGroupSync();																\
		bool isSegHeadAtBi = TREE_SCAN_CACHE_HF[bi];													\
		if (activeThread && (!isSegHeadAtBi))															\
		{																								\
			TREE_SCAN_CACHE[bi] = OP(TREE_SCAN_CACHE[ai], TREE_SCAN_CACHE[bi]);							\
		}																								\
																										\
		GroupMemoryBarrierWithGroupSync();																\
		TREE_SCAN_CACHE_HF[bi] =																		\
			activeThread																				\
			? isSegHeadAtBi || TREE_SCAN_CACHE_HF[ai]													\
			: isSegHeadAtBi;																			\
																										\
		offset *= 2;																					\
	}																									\
																										\
																										\
	/* ////////////////////////////////////////////////////////////////////////*/						\
	/* Phase III */																						\
	if (groupIdx == 0)																					\
	{																									\
		/* Zero out last elem, prepare for up-sweeping */												\
		uint lastIndex = DATA_SIZE - 1 + OFFSET_BANK_CONFLICT_FREE(DATA_SIZE - 1);						\
		TREE_SCAN_CACHE[lastIndex] = 0;																	\
	}																									\
																										\
	/* Compared to normal seg-scan,						*/												\
	/* need to encode original hfs differently here		*/												\
	GroupMemoryBarrierWithGroupSync();																	\
	TREE_SCAN_CACHE_HF[cacheAddrAi] =																	\
		EncodeHeadFlags(																				\
			TREE_SCAN_CACHE_HF[cacheAddrAi],															\
			firstInitialHFAi																			\
		);																								\
	TREE_SCAN_CACHE_HF[cacheAddrBi] =																	\
		EncodeHeadFlags(																				\
			TREE_SCAN_CACHE_HF[cacheAddrBi],															\
			firstInitialHFBi																			\
		);																								\
																										\
	/* ///////////////////////////////////////////////////////////////////////// */						\
	/* Phase IV                 Down-Sweeping                                    */						\
	/* Util this point,                                                          */						\
	/* d == 0,                                                                   */						\
	/* offset == GROUP_SIZE * 2 == DATA_SIZE                                      */					\
	/* This is actually "rolling back + mirror" version of Phase I,              */						\
	/* So this execution code is a mirrored loop                                 */						\
	for (d = 1; d < DATA_SIZE; d *= 2)																	\
	{																									\
		offset >>= 1;																					\
		/* So the indexing function is the same, (rolling back)											\
		 just the roles of ai & bi are switched               */										\
		ai = offset * (2 * groupIdx + 1) - 1;															\
		uint aiNext = ai + 1 + OFFSET_BANK_CONFLICT_FREE(ai + 1);										\
		bi = offset * (2 * groupIdx + 2) - 1;															\
		ai += OFFSET_BANK_CONFLICT_FREE(ai);															\
		bi += OFFSET_BANK_CONFLICT_FREE(bi);															\
																										\
		activeThread = groupIdx < d;																	\
																										\
		GroupMemoryBarrierWithGroupSync();																\
		T valAi = TREE_SCAN_CACHE[ai];																	\
		T valBi = TREE_SCAN_CACHE[bi];																	\
																										\
		GroupMemoryBarrierWithGroupSync();																\
		if (activeThread) /* swap */																	\
			TREE_SCAN_CACHE[ai] = valBi;																\
																										\
		GroupMemoryBarrierWithGroupSync();																\
																										\
		uint origHFAiNext = DECODE_ORIG_HF(TREE_SCAN_CACHE_HF[aiNext]);									\
		uint currHFAi = DECODE_CURR_HF(TREE_SCAN_CACHE_HF[ai]);											\
																										\
		if (activeThread)																				\
		{																								\
			TREE_SCAN_CACHE[bi] =																		\
				(origHFAiNext == 1) ? 0 : ((currHFAi == 1) ? valAi : valAi + valBi);					\
		}																								\
																										\
		GroupMemoryBarrierWithGroupSync();																\
		/* Clear current flag, keep original flag */													\
		TREE_SCAN_CACHE_HF[ai] &= 0x00000002;															\
	}																									\
																										\
	GroupMemoryBarrierWithGroupSync();																	\
																										\
	vector<T, 2> res = vector<T, 2>(TREE_SCAN_CACHE[cacheAddrAi], TREE_SCAN_CACHE[cacheAddrBi]);		\
																										\
	REDUCED_BUFFER.SEGSCAN_STORE_GLOBAL(SEGSCAN_GLOBAL_DATA_ADDR(scanAddrs.x), T_TO_UINT(res.x));		\
	REDUCED_BUFFER.SEGSCAN_STORE_GLOBAL(SEGSCAN_GLOBAL_DATA_ADDR(scanAddrs.y), T_TO_UINT(res.y));		\
}																										\



#define DECLARE_TREE_SEGSCAN_FUNC_DWSWEEP															\
CAT(T, 2) CAT(TreeSegScanBlockExc_DwSweep_, tag)(													\
	uint groupIdx,																					\
	uint3 gIdx : SV_GroupID																			\
)																									\
{																									\
	/* Addressing & Data Loading												*/					\
	/* scanAddrs:																*/					\
	/* -- .x: Global_scanAddr0, .y: Global_scanAddr1, 							*/					\
	/* -- .z: LDS_scanAddr0, .w: LDS_scanAddr1									*/					\
	uint4 scanAddrs = GetTreeScanIndices(groupIdx, gIdx);											\
	uint2 upsweepResAi = SCAN_BUFFER.SEGSCAN_LOAD_GLOBAL(SEGSCAN_GLOBAL_DATA_ADDR(scanAddrs.x));	\
	uint2 upsweepResBi = SCAN_BUFFER.SEGSCAN_LOAD_GLOBAL(SEGSCAN_GLOBAL_DATA_ADDR(scanAddrs.y));	\
																									\
	T partialSumTreeAi = GET_REDUCE_DATA_BLOCK_SUM(upsweepResAi);									\
	uint encodedHFsAi = GET_REDUCE_DATA_ENCODED_HF(upsweepResAi);									\
	T partialSumTreeBi = GET_REDUCE_DATA_BLOCK_SUM(upsweepResBi);									\
	uint encodedHFsBi = GET_REDUCE_DATA_ENCODED_HF(upsweepResBi);									\
																									\
																									\
	/* Bank Offset == index >> bits_banks(5 in Nvidia card) */										\
	uint ai = scanAddrs.z;																			\
	uint bi = scanAddrs.w;																			\
	uint aiOffset = OFFSET_BANK_CONFLICT_FREE(ai);													\
	uint biOffset = OFFSET_BANK_CONFLICT_FREE(bi);													\
																									\
	/*  Store data into LDS with memory bank offset													\
	---------------------------------------------------------------------							\
	about 'tailvalue':																				\
	in prefix sum, last elem is going to be erased													\
	but we will need it later, so cache it here                                 */					\
	uint cacheAddrAi = ai + aiOffset;																\
	uint cacheAddrBi = bi + biOffset;																\
	TREE_SCAN_CACHE[cacheAddrAi] = partialSumTreeAi;												\
	TREE_SCAN_CACHE_HF[cacheAddrAi] = encodedHFsAi;													\
																									\
	/* Different from normal down-sweep that zeros out last elem, */								\
	/* We use output from prev inter-block scan kernel instead */									\
	TREE_SCAN_CACHE[cacheAddrBi] =																	\
		(groupIdx == SCAN_BLOCK_SIZE - 1)															\
		? UINT_TO_T( /* don't worry, here is just a shortcut */										\
			REDUCED_BUFFER.SEGSCAN_LOAD_GLOBAL(														\
				SEGSCAN_GLOBAL_DATA_ADDR(gIdx.x)))													\
		: partialSumTreeBi;																			\
	TREE_SCAN_CACHE_HF[cacheAddrBi] = encodedHFsBi;													\
																									\
																									\
	/* ///////////////////////////////////////////////////////////////////////// */					\
	/* Phase IV                 Down-Sweeping                                    */					\
	/* Util this point,                                                          */					\
	/* d == 0,                                                                   */					\
	/* offset == GROUP_SIZE * 2 == DATA_SIZE                                     */					\
	/* This is actually "rolling back + mirror" version of Phase I,              */					\
	/* So this execution code is a mirrored loop                                 */					\
	uint offset = DATA_SIZE;																		\
	uint d = 0;																						\
	bool activeThread;																				\
	for (d = 1; d < DATA_SIZE; d *= 2)																\
	{																								\
		offset >>= 1;																				\
		/* So the indexing function is the same, (rolling back)										\
		 just the roles of ai & bi are switched               */									\
		ai = offset * (2 * groupIdx + 1) - 1;														\
		bi = offset * (2 * groupIdx + 2) - 1;														\
		uint aiNext = ai + 1 + OFFSET_BANK_CONFLICT_FREE(ai + 1);									\
		ai += OFFSET_BANK_CONFLICT_FREE(ai);														\
		bi += OFFSET_BANK_CONFLICT_FREE(bi);														\
																									\
		activeThread = groupIdx < d;																\
																									\
		GroupMemoryBarrierWithGroupSync();															\
		T valAi = TREE_SCAN_CACHE[ai];																\
		T valBi = TREE_SCAN_CACHE[bi];																\
																									\
		GroupMemoryBarrierWithGroupSync();															\
		if (activeThread) /* swap */																\
			TREE_SCAN_CACHE[ai] = valBi;															\
																									\
		GroupMemoryBarrierWithGroupSync();															\
		uint origHFAiNext = DECODE_ORIG_HF(TREE_SCAN_CACHE_HF[aiNext]);								\
		uint currHFAi = DECODE_CURR_HF(TREE_SCAN_CACHE_HF[ai]);										\
																									\
		if (activeThread)																			\
		{																							\
			TREE_SCAN_CACHE[bi] =																	\
				(origHFAiNext == 1) ? 0 : ((currHFAi == 1) ? valAi : valAi + valBi);				\
		}																							\
																									\
		GroupMemoryBarrierWithGroupSync();															\
		/* Clear current flag, keep original flag */												\
		TREE_SCAN_CACHE_HF[ai] &= 0x00000002;														\
	}																								\
																									\
	GroupMemoryBarrierWithGroupSync();																\
																									\
	return CAT(T, 2)(TREE_SCAN_CACHE[cacheAddrAi], TREE_SCAN_CACHE[cacheAddrBi]);					\
}																									\


#endif /* SCANPROMITIVES_INCLUDED */
