// Hi, Welcome to my personal hell! :)
// ############################################################################
//								Code Generator
//					for Device Scan with Decoupled Look-Back 
// ############################################################################

// Input macros will be needed in the source file
// where you include this code_gen header.

// Inputs ---------------------
// Example: 
// (- basic -)
// #define LOOK_BACK_BUFFER				// Global look-back buffer, 
//										// needs to be cleared in a prev kernel,
//										// clear function code is generated as
//										// "InitializeLookBackTable_tag"
//										
// #define OP(a, b) (a + b)				// Scan operation
// #define SCAN_FUNCTION_TAG ScanTest	// Alias name for this set of scan ops (_tag)
// #define SCAN_DATA_TYPE uint2			// Input data type for scan operation
// #define SCAN_SCALAR_TYPE uint		// Input data component type,
//										// - for instance,
//										// - if SCAN_DATA_TYPE = float3x2,
//										// - then SCAN_SCALAR_TYPE = float
// #define SCAN_BLOCK_SIZE 256			// thread_group_size of up/dw-sweep kernels
//
// (- optional -)
// #define SCAN_DATA_TYPE_NON_UINT		// Value type is not "uint" or "uint(xn)"
// #define SCAN_DATA_VECTOR_STRIDE 2	// Use this if SCAN_DATA_TYPE is vector
//										// (uint2,3,4 also need)
// ---------------------------------------
// Force file to regenerate macros & functions
#ifdef DECOUPLED_LOOKBACK_PRIMITIVES_INCLUDED
#undef DECOUPLED_LOOKBACK_PRIMITIVES_INCLUDED
#undef T_STRIDE
#undef STORE_SCAN_VAL
#undef LOAD_SCAN_VAL
#endif
#include "./DecoupledLookBackPrimitive_Scan.hlsl"

// ---------------------------------------------------------------
// After DecoupledLookBackPrimitive_Scan.hlsl being pre-processed,
// macros inside it will expand into
// *) function generators:	DECLARE_FUNC_XXX
// *) shmem generators:		DECLARE_SCAN_CACHE(_XXX)


// Group shared memory to store some utility data 
DECLARE_LOOK_BACK_SCAN_CACHE(T)


// Global look-back buffer initializer,
// Properly initialize each TG's scan sum & state
DECLARE_FUNC_INIT_SCAN_LOOKBACK_BUFFER(T)

// First wave maintains a look-back window,
// sliding through predecessor blocks' outputs in look-back buffer,
// after each slide step,
// we need to use wave-seg-scan to collect window sum
DECLARE_FUNC_SEGSCAN_WAVE_INC(T)

// Each TG is assigned with a dynamic TGId,
// use this to fetch input scan data
#ifndef BLOCK_ID_CACHE_DECLARED
#define BLOCK_ID_CACHE_DECLARED

	DECLARE_DYNAMIC_BLOCK_ID_CACHE

#endif

DECLARE_FUNC_REGISTER_DYNAMIC_BLOCK_ID


// Single Pass Scan with Decoupled Look-back -----
DECLARE_FUNC_SCAN_SET_LOOKBACK_INCLUSIVE(T)
DECLARE_FUNC_SCAN_SET_LOOKBACK_PARTIAL(T)

DECLARE_FUNC_SCAN_WAIT_FOR_VALID_LOOKBACK(T)
DECLARE_FUNC_SCAN_PROCESS_LOOKBACK_WINDOW(T)
DECLARE_FUNC_SEGSCAN_PROCESS_LOOKBACK_WINDOW(T)

DECLARE_FUNC_SCAN_DECOUPLED_LOOK_BACK(T)
DECLARE_FUNC_SEGSCAN_DECOUPLED_LOOK_BACK(T)

// Main function
// Returns Exclusive Sum of Prev Blocks
DECLARE_FUNC_SCAN_SINGLE_PASS(T)
// Returns Exclusive Sum of Prev Blocks
DECLARE_FUNC_SEGSCAN_SINGLE_PASS(T)
// -----------------------------------------------


// Clear Internal Macros -------------
#undef WARP_SEGSCAN_PASS
#undef DECLARE_FUNC_SEGSCAN_WAVE_INC
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
#undef LOOK_BACK_BUFFER
#undef LOOK_BACK_BUFFER_OFFSET
#undef TILE_STATUS_PADDING
#undef Addr_LookBackBlockCounter
#undef Size_LookBackBlockCounter
#undef Size_FlagPerLookBackBlock
#undef Load_LookBackFlag
#undef Store_LookBackFlag
#undef LDSLookBackArgs
#undef LDSLookBackArgs_SegScan
#undef DYNAMIC_TILE_ID_CACHE

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
