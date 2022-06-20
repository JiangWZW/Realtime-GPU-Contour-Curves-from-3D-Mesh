// Hi, Welcome to my personal hell! :)
// ############################################################################
//							Scan Code Generator
// ############################################################################

// Before include "WarpScanPrimitives.hlsl"
// to spawn function/shmem generators,
// Input macros will be needed in the source file
// where you include this code_gen header.

// Inputs ---------------------
// Example: 
// (- basic -)
// #define TG_COUNTER					// Global atomic counter
// #define LDS_COUNTER					// TGSM counter
// #define OP(a, b) (a + b)				// Scan operation
// #define SCAN_FUNCTION_TAG ScanTest// Alias name for this set of scan ops
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
#ifdef WARPSCANPRIMITIVES_INCLUDED
#undef WARPSCANPRIMITIVES_INCLUDED
#undef T_STRIDE
#undef STORE_SCAN_VAL
#undef LOAD_SCAN_VAL
#endif
#include "./WaveScanPrimitives.hlsl"

// ---------------------------------------
// After WarpScanPrimitives.hlsl being pre-processed,
// macros inside it will expand into
// *) function generators:	DECLARE_FUNC_XXX
// *) shmem generators:		DECLARE_SCAN_CACHE(_XXX)

#ifndef OP
#define OP(a, b) ((a + b))
#endif


DECLARE_SCAN_CACHE(T)

DECLARE_FUNC_ADD_SCAN_WAVE(T)
DECLARE_DECLARE_FUNC_SCAN_BLOCK(CAT(AddScanWave_, tag), tag, SCAN_BLOCK_SIZE)

DECLARE_FUNC_STREAM_COMPACTION(TG_COUNTER, TGSM_COUNTER)


// Clear Internal Macros -------------
#undef ScanBuffer_PartialSum_AddrAt
#undef ReduceBuffer_BlockSum_AddrAt
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
#undef TG_COUNTER
#undef TGSM_COUNTER
// Optional
#ifdef SCAN_ZERO_VALUE
#	undef SCAN_ZERO_VALUE
#endif
#ifdef SCAN_DATA_VECTOR_STRIDE
#	undef SCAN_DATA_VECTOR_STRIDE
#endif
#ifdef SCAN_DATA_TYPE_NON_UINT
#	undef SCAN_DATA_TYPE_NON_UINT
#	undef AS_T
#endif
// ------------------------------------
