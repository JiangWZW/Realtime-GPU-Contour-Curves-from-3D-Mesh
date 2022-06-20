// Hi, Welcome to my personal hell! :)
// ############################################################################
//						Segmented Scan Code Generator
// ############################################################################

// Before include "WarpSegScanPrimitives.hlsl"
// to spawn function/shmem generators,
// Input macros will be needed in the source file
// where you include this code_gen header.

// Inputs ---------------------
// Example: 
// (- basic -)
// #define OP(a, b) (a + b)				// Scan operation
// #define SCAN_FUNCTION_TAG SegScanTest// Alias name for this set of scan ops
// #define SCAN_DATA_TYPE uint2			// Input data type for scan operation
// #define SCAN_SCALAR_TYPE uint		// Input data component type,
//										// - for instance,
//										// - if SCAN_DATA_TYPE = float3x2,
//										// - then SCAN_SCALAR_TYPE = float
// #define SCAN_BLOCK_SIZE 256			// Typically thread_group_size
//
// (- optional -)
// #define SCAN_DATA_TYPE_NON_UINT		// Value type is not "uint" or "uintm(xn)"
// #define SCAN_DATA_VECTOR_STRIDE 2	// Use this if SCAN_DATA_TYPE is vector
//										// (uint2,3,4 also need)
// ---------------------------------------
// Force file to regenerate macros & functions
#ifdef WARPSEGSCANPROMITIVES_INCLUDED
#undef WARPSEGSCANPROMITIVES_INCLUDED
#undef T_STRIDE
#undef STORE_SEGSCAN_VAL
#undef LOAD_SEGSCAN_VAL
#endif
#include "./WarpSegScanPrimitives.hlsl"

// ---------------------------------------
// After WarpSegScanPrimitives.hlsl being pre-processed,
// macros inside it will expand into
// *) function generators:	DECLARE_FUNC_XXX
// *) shmem generators:		DECLARE_SCAN_CACHE(_XXX)

#define T SCAN_DATA_TYPE

DECLARE_SCAN_CACHE(T)
DECLARE_SCAN_CACHE_HF

DECLARE_FUNC_SEGSCAN_WAVE_INC(T) // <- SegScanIncWave_tag
DECLARE_FUNC_SEGSCAN_BLOCK_INC(T, CAT(SegScanIncWave_, tag))

DECLARE_FUNC_SEGSCAN_ADDR_REDUCE_BUFFER
DECLARE_FUNC_SEGSCAN_STORE_TO_REDUCTION_BUFFER(T)
DECLARE_FUNC_SEGSCAN_LOAD_FROM_REDUCTION_BUFFER(T)

DECLARE_FUNC_SEGSCAN_ADDR_SCAN_BUFFER
DECLARE_FUNC_SEGSCAN_STORE_TO_SCAN_BUFFER(T)
DECLARE_FUNC_SEGSCAN_LOAD_FROM_SCAN_BUFFER(T)

DECLARE_FUNC_SEGSCAN_UPSWEEP(T)

DECLARE_FUNC_SEGSCAN_REDUCTION(T)

DECLARE_FUNC_SEGSCAN_DWSWEEP(T)


// Clear Internal Macros -------------
#undef SegScanBuffer_PartialSum_AddrAt
#undef SegScanBuffer_PartialHF_AddrAt
#undef ReduceBuffer_BlockSum_AddrAt
#undef ReduceBuffer_BlockHF_AddrAt  
// Clear Input Macros ----------------
// Basic
#undef T
#undef OP
#undef SCAN_FUNCTION_TAG
#undef SCAN_SCALAR_TYPE
#undef SCAN_DATA_TYPE
#undef SCAN_BLOCK_SIZE
#undef UINT_TO_T
#undef T_TO_UINT
#undef T_STRIDE
#undef SCAN_ZERO_VALUE
#undef DECLARE_FUNC_SEGSCAN_WAVE_INC
// Optional 
#ifdef SCAN_DATA_VECTOR_STRIDE
#	undef SCAN_DATA_VECTOR_STRIDE
#endif
#ifdef SCAN_DATA_TYPE_NON_UINT
#	undef SCAN_DATA_TYPE_NON_UINT
#	undef AS_T
#endif
// ------------------------------------
