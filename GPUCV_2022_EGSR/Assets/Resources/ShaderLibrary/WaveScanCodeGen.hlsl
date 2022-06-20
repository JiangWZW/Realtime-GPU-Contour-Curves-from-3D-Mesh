// Hi, Welcome to my personal hell! :)
// ############################################################################
//					Scan Code Generator
// ############################################################################

// Before include "WaveScanPrimitives.hlsl"
// to spawn function/shmem generators,
// Input macros will be needed in the source file
// where you include this code_gen header.

// Inputs ---------------------
// Example: 
// (- basic -)
// #define OP(a, b) (a + b)				// Scan operation
// #define SCAN_FUNCTION_TAG ScanTest// Alias name for this set of scan ops
// #define SCAN_DATA_TYPE uint2			// Input data type for scan operation
// #define SCAN_SCALAR_TYPE uint		// Input data component type,
//										// - for instance,
//										// - if SCAN_DATA_TYPE = float3x2,
//										// - then SCAN_SCALAR_TYPE = float
// #define SCAN_BLOCK_SIZE 256			// thread_group_size of up/dw-sweep kernels
// #define REDUCE_BLOCK_SIZE 1024		// thread_group_size of reduce kernel
//
// (- optional -)
// #define SCAN_DATA_TYPE_NON_UINT		// Value type is not "uint" or "uintm(xn)"
// #define SCAN_DATA_VECTOR_STRIDE 2	// Use this if SCAN_DATA_TYPE is vector
//										// (uint2,3,4 also need)
// #define USE_ADD_SCAN					// When the operator is +, define macro
//										// to pick the optimized scan implementation.
// #define USE_BIT_SCAN					// When operator is +,
//	Note: when use this macro,			// and input value is BOOLEAN, define macro
//	SCAN_DATA_TYPE = uint, NOT bool!	// to pick the optimized scan implementation.
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


DECLARE_SCAN_CACHE(T)

// For + and bit-counting scans, we have efficient
// wave intrinsics to carry out per-wave prefix sum.
#ifdef USE_ADD_SCAN // + scan
DECLARE_FUNC_ADD_SCAN_WAVE(T)
DECLARE_DECLARE_FUNC_SCAN_BLOCK(CAT(AddScanWave_, tag), tag, SCAN_BLOCK_SIZE)
DECLARE_DECLARE_FUNC_SCAN_BLOCK(CAT(AddScanWave_, tag), Reduce, REDUCE_BLOCK_SIZE)
#else
#ifdef USE_BIT_SCAN // bit counting(+scan with binary input values)
DECLARE_FUNC_BIT_SCAN_WAVE(T)
DECLARE_DECLARE_FUNC_SCAN_BLOCK(CAT(BitScanWave_, tag), tag, SCAN_BLOCK_SIZE)
DECLARE_DECLARE_FUNC_SCAN_BLOCK(CAT(BitScanWave_, tag), Reduce, REDUCE_BLOCK_SIZE)
#else
DECLARE_FUNC_GENERIC_SCAN_WAVE(T)
DECLARE_DECLARE_FUNC_SCAN_BLOCK(CAT(GenericScanWave_, tag), tag, SCAN_BLOCK_SIZE)
DECLARE_DECLARE_FUNC_SCAN_BLOCK(CAT(GenericScanWave_, tag), Reduce, REDUCE_BLOCK_SIZE)
#endif
#endif



DECLARE_FUNC_SCAN_ADDR_SCAN_BUFFER
DECLARE_FUNC_SCAN_STORE_TO_SCAN_BUFFER(T)
DECLARE_FUNC_SCAN_LOAD_FROM_SCAN_BUFFER(T)

DECLARE_FUNC_SCAN_ADDR_REDUCE_BUFFER
DECLARE_FUNC_SCAN_STORE_TO_REDUCTION_BUFFER(T)
DECLARE_FUNC_SCAN_LOAD_FROM_REDUCTION_BUFFER(T)

DECLARE_FUNC_SCAN_UPSWEEP(T) 

DECLARE_FUNC_SCAN_REDUCTION(T)

DECLARE_FUNC_SCAN_DWSWEEP(T)


// Clear Internal Macros -------------
#undef ScanBuffer_PartialSum_AddrAt
#undef ReduceBuffer_BlockSum_AddrAt
// Clear Input Macros ----------------
// Basic
#undef tag
#undef T
#undef OP
#undef SCAN_FUNCTION_TAG
#undef SCAN_SCALAR_TYPE
#undef SCAN_DATA_TYPE
#undef SCAN_BLOCK_SIZE
#undef UINT_TO_T
#undef T_TO_UINT
#undef T_STRIDE
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
