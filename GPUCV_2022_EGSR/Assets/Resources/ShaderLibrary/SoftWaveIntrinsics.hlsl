#ifndef SOFTWARE_WAVE_INTRINSICS_INCLUDED
#   define SOFTWARE_WAVE_INTRINSICS_INCLUDED
#       ifndef PLATFORM_SUPPORTS_WAVE_INTRINSICS

#include "./UtilityMacros.hlsl"

// -----------------------------------------------------------------------------------
// I. Brief
// Technique that simulates cross-lane operations(wave intrinsics in DX)
// in DirectX Shader Model 6.0, see
// https://github.com/Microsoft/DirectXShaderCompiler/wiki/Wave-Intrinsics#type-waveprefixsum-type-value-
// Work inspired by Star-X, see
// https://github.com/StarsX/ParticleEmitter/blob/master/ParticleEmitter/XUSG/Shaders/CSPrefixSum.hlsl
// https://github.com/StarsX/PoissonSolver/blob/master/PoissonSolver/CSScanBlockBuffer.hlsli


// ------------------------------------------------------------------------------------
// II. Notes
// 1) For resons that I do this, see
// https://forum.unity.com/threads/wave-intrinsics-support-for-compute-shader.824916/#post-5461866
// https://forum.unity.com/threads/wave-intrinsics-in-hdrp.825312/

// 2)For reasons why this black-magic-shit work correctly && when/where it may go wrong,
// see
// https://stackoverflow.com/questions/21535471/how-is-a-warp-formed-and-handled-by-the-hardware-warp-scheduler
// https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#hardware-implementation
// https://devblogs.nvidia.com/cooperative-groups/


#ifndef WAVE_SIZE_MIN
#   define WAVE_SIZE_MIN 32
#endif

#ifndef WAVE_SIZE_MAX
#   define WAVE_SIZE_MAX 64
#endif

// Make sure wave & group sizes are defined
#ifndef WAVE_SIZE
#   define WAVE_SIZE WAVE_SIZE_MIN
#   define WAVE_BITS 5
#else
#   ifndef WAVE_BITS
#       define WAVE_BITS BITS_TO_REPRESENT(WAVE_SIZE)
#   endif
#endif

#ifndef GROUP_SIZE
#   define GROUP_SIZE 64
#   define GROUP_BITS 6
#else
#   ifndef GROUP_BITS
#       define GROUP_BITS BITS_TO_REPRESENT(GROUP_SIZE)
#   endif
#endif


#define _GetWaveIndex(groupIdx) (groupIdx >> WAVE_BITS)
#define _GetLaneIndex(groupIdx) (groupIdx - (_GetWaveIndex(groupIdx) << WAVE_BITS))
#define _GetLaneIndexFast(groupIdx, waveIdx) (groupIdx - waveIdx << WAVE_BITS)
#define _WavePostfixSum(laneIdx, groupIdx, data, pSumOut, buffer)                   \
    buffer[groupIdx] = data;                                                        \
    GroupMemoryBarrierWithGroupSync();                                              \
	for (uint s = 1; s < WAVE_SIZE; s <<= 1){                                       \
        pSumOut = buffer[groupIdx];                                                 \
        pSumOut += (laneIdx >= s) ? buffer[groupIdx - s] : 0;                       \
		buffer[groupIdx] = pSumOut;                                                 \
    }                                                                               \
    GroupMemoryBarrierWithGroupSync();                                              \



#   endif // !PLATFORM_SUPPORTS_WAVE_INTRINSICS
#endif // Include Guard