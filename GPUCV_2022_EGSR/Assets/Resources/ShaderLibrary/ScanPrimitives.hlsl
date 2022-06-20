#ifndef SCANPROMITIVES_INCLUDED
#define SCANPROMITIVES_INCLUDED

///////////////////////////////////////////
// Macros for device-level scan operation
// Input: SCAN_BLOCK_SIZE
#define LOOKBACK_CACHE_SIZE SCAN_BLOCK_SIZE
///////////////////////////////////////////

///////////////////////////////////////////////////////////////
// Padding Macros for Eliminating Bank Conficts
// Input: SCAN_BLOCK_SIZE
#define NUM_BANKS       32
#define LOG_NUM_BANKS   5
#define OFFSET_BANK_CONFLICT_FREE(x) ((x) >> LOG_NUM_BANKS)

#define DATA_SIZE       2 * SCAN_BLOCK_SIZE
#define LDS_SCAN_TABLE_SIZE (DATA_SIZE + DATA_SIZE / NUM_BANKS)
///////////////////////////////////////////////////////////////

// Returns (Global_scanAddr0, Global_scanAddr1, LDS_scanAddr0, LDS_scanAddr1)
// LDS_scanAddr0/1 : index of element 0/1 in shared memory
// Global_scanAddr0/1 : index of element in global compute buffer
uint4 ComputeWorkEffecientScanIndices(uint groupIdx, uint groupTicket)
{
	const uint groupOffset = ((uint)DATA_SIZE) * groupTicket;

	uint ai = groupIdx; //   0   1   2   3 ... 255  => ai
	// ------ + 1 * 512 ------- (Suppose groupTicket == 1)
	uint scanAddrA = groupOffset + ai; // 512 513 514 515 ... 767  => scanAddrA

	uint bi = ai + DATA_SIZE / 2; // 256 257 258 259 ... 511   => bi
	uint scanAddrB = groupOffset + bi; // 768 641 642 643 ... 1151  => scanAddrB

	return uint4(scanAddrA, scanAddrB, ai, bi);
}

// Note: Multi-Inspection fails when thread count exceeds about 2^16
#define Scan_Device(LookBackBuffer, LookBackCache, OpFunc, Decode, Encode, IsInvalid, aggregateReadyFlag, name) \
    uint SimpleScanDevice_##name(\
        uint groupIdx, \
        uint grpTicket, \
        uint groupSize, \
        uint lookBackBufferOffset, \
        uint2 prefixSumAB, \
        uint dataInitialBi \
    ){ \
        uint aggregateThisGroup = 0;                                                            \
        /* Last thread in group: */                                                             \
        if (groupIdx == groupSize - 1){                                                         \
            /* Compute aggregate & use that to update look-back table */                        \
            aggregateThisGroup = OpFunc(prefixSumAB.y, dataInitialBi);                          \
            LookBackBuffer.Store( /* Update global look-back table */                           \
                (lookBackBufferOffset + grpTicket) << 2,                                        \
                Encode(aggregateReadyFlag, aggregateThisGroup)                                  \
            );                                                                                  \
        }                                                                                       \
                                                                                                \
        /* # threads to use as inspectors */                                                    \
        const uint numInspectorThreads = grpTicket; /* Note when ticket == 0  */                \
        const bool isInspectorThread = (grpTicket != 0 && groupIdx < numInspectorThreads);                        \
        /* Keeps inspecting & polling for valid look-back data */                               \
        uint dataRaw = LookBackBuffer.Load((lookBackBufferOffset + groupIdx.x) << 2);           \
        [allow_uav_condition]                                                                   \
        while (isInspectorThread && (IsInvalid(dataRaw))){                                      \
            DeviceMemoryBarrier();                                                              \
            dataRaw = LookBackBuffer.Load((lookBackBufferOffset + groupIdx.x) << 2);            \
        }                                                                                       \
        /* Non-inspected slots are 0 */                                                         \
        LookBackCache[groupIdx] =                                                               \
            (isInspectorThread) ? Decode(dataRaw) : 0;                                          \
        GroupMemoryBarrierWithGroupSync();                                                      \
                                                                                                \
                                                                                                \
        /* Compute exclusive sum  */                                                            \
        uint exclusiveSum = 0;                                                                  \
        uint appendVal = 0;                                                                     \
        uint upperlim = 1 << (firstbithigh(numInspectorThreads) + 1);                           \
        for (uint offset = 1; offset < upperlim; offset <<= 1){                                 \
            exclusiveSum = LookBackCache[groupIdx];                                             \
            appendVal = (offset <= groupIdx) ?                                                  \
                    LookBackCache[groupIdx - offset] : 0;                                       \
            exclusiveSum = OpFunc(appendVal, exclusiveSum);                                     \
            GroupMemoryBarrierWithGroupSync();                                                  \
                                                                                                \
            LookBackCache[groupIdx] = exclusiveSum;                                             \
            GroupMemoryBarrierWithGroupSync();                                                  \
        }                                                                                       \
                                                                                                \
        exclusiveSum = (grpTicket == 0) ? 0 : LookBackCache[numInspectorThreads - 1];           \
                                                                                                \
        return exclusiveSum;                                                                    \
    }

#define Scan_Device_Test(LookBackBuffer, LookBackCache, OpFunc, Decode, Encode, IsInvalid, aggregateReadyFlag, name) \
    uint SimpleScanDevice_##name(\
        uint groupIdx, \
        uint grpTicket, \
        uint groupSize, \
        uint lookBackBufferOffset, \
        uint2 prefixSumAB, \
        uint dataInitialBi \
    ){ \
        uint aggregateThisGroup = 0;                                                             \
        /* Last thread in group: */                                                              \
        if (groupIdx == groupSize - 1){                                                          \
            /* Compute aggregate & use that to update look-back table */                         \
            LookBackCache[0] = OpFunc(prefixSumAB.y, dataInitialBi);                             \
        }                                                                                        \
        GroupMemoryBarrierWithGroupSync();                                                       \
        aggregateThisGroup = LookBackCache[0];                                                   \
                                                                                                 \
        /* # threads to use as inspectors */                                                     \
        uint inspecLookbackPos = (grpTicket == 0) ? 0 : (grpTicket - 1);                         \
        uint holdedLookbackPos = grpTicket;                                                      \
        inspecLookbackPos += lookBackBufferOffset;                                               \
        holdedLookbackPos += lookBackBufferOffset;                                               \
                                                                                                 \
        /* Keeps inspecting & polling for valid look-back data */                                \
        const bool isInspectorThread = (groupIdx == 0);                                          \
        uint dataRaw = 0;                                                                        \
        if (grpTicket != 0 && isInspectorThread){                                                \
            dataRaw = LookBackBuffer.Load((inspecLookbackPos) << 2);                             \
            [allow_uav_condition]                                                                \
            while ((IsInvalid(dataRaw))){                                                        \
                DeviceMemoryBarrier();                                                           \
                dataRaw = LookBackBuffer.Load((inspecLookbackPos) << 2);                         \
            }                                                                                    \
        }                                                                                        \
                                                                                                 \
        uint inclusiveSumPrevGrp = (grpTicket == 0) ? 0 : Decode(dataRaw);                       \
        uint inclusiveSumThisGrp = OpFunc(aggregateThisGroup, inclusiveSumPrevGrp);              \
                                                                                                 \
        if (isInspectorThread){                                                                  \
            LookBackBuffer.Store( /* Update global look-back table */                            \
                (holdedLookbackPos) << 2,                                                        \
                Encode(aggregateReadyFlag, inclusiveSumThisGrp)                                  \
            );                                                                                   \
            LookBackCache[1] = inclusiveSumPrevGrp;                                              \
        }                                                                                        \
        DeviceMemoryBarrier();                                                                   \
        GroupMemoryBarrierWithGroupSync(); \
        uint exclusiveSum = LookBackCache[1];                                                    \
                                                                                                 \
        return exclusiveSum;                                                                     \
    }

#define WorkEfficientScan_Block(ldsBuffer, OpFunc, name) \
    uint2 ScanBlock_##name( \
        uint groupIdx, \
        uint gId, \
        uint groupSize, \
        uint dataSize, \
        uint ai, \
        uint bi, \
        uint initialDataAi, \
        uint initialDataBi \
    ){ \
        /* Bank Offset == index >> bits_banks(5 in Nvidia card) */                    \
        uint aiOffset = OFFSET_BANK_CONFLICT_FREE(ai);                                \
        uint biOffset = OFFSET_BANK_CONFLICT_FREE(bi);                                \
                                                                                        \
        /*  Store data into LDS with memory bank offset                               \
        ---------------------------------------------------------------------         \
        about 'tailvalue':                                                            \
        in prefix sum, last elem is going to be erased                                \
        but we will need it later, so cache it here                                 */\
        ldsBuffer[ai + aiOffset] = initialDataAi;                                     \
        const uint tailValue = initialDataBi;                                         \
        ldsBuffer[bi + biOffset] = tailValue;                                         \
        /* about LDS memory layout:                                                   \
        Interleaved storage,                                                          \
        that is, ith(i % 32 == 0) is not used;                                        \
        e.g:                                                                          \
        [0, 31]  X [32, 63] X  [64, 95]  X [96, 127]  -- Input CBuffer                \
            + 0________+1___________+2___________+3 ... -- + OFFSET_BANK...(x)        \
        [0, 31] 32 [33, 64] 65 [66, 97] 98 [99, 130]  -- ldsBuffer                   */\
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
        uint d = dataSize / 2; /* [0, ... , d]th threads are dispatched */            \
        for (; d > 0; d >>= 1){                                                       \
            GroupMemoryBarrierWithGroupSync();                                        \
            if (groupIdx < d){                                                        \
                ai = offset * (2 * groupIdx + 1) - 1;                                 \
                bi = offset * (2 * groupIdx + 2) - 1;                                 \
                ai += OFFSET_BANK_CONFLICT_FREE(ai);                                  \
                bi += OFFSET_BANK_CONFLICT_FREE(bi);                                  \
                                                                                        \
                ldsBuffer[bi] = OpFunc(ldsBuffer[ai], ldsBuffer[bi]);                 \
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
            uint lastIndex = dataSize - 1 + OFFSET_BANK_CONFLICT_FREE(dataSize - 1);  \
            ldsBuffer[lastIndex] = 0;                                                 \
        }                                                                             \
        \
        \
        \
        /* ///////////////////////////////////////////////////////////////////////// */\
        /* Phase IV                 Down-Sweeping                                    */\
        /* Util this point,                                                          */\
        /* d == 0,                                                                   */\
        /* offset == GROUP_SIZE * 2 == dataSize                                      */\
        /* This is actually "rolling back + mirror" version of Phase I,              */\
        /* So this execution code is a mirrored loop                                 */\
        for (d = 1; d < dataSize; d *= 2){                                            \
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
                uint aiValOld = ldsBuffer[ai];                                        \
                ldsBuffer[ai] = ldsBuffer[bi];                                        \
                ldsBuffer[bi] = OpFunc(aiValOld, ldsBuffer[bi]);                      \
            }                                                                         \
        }                                                                             \
        GroupMemoryBarrierWithGroupSync();                                            \
        \
        \
        \
        uint pSumAtAi = ldsBuffer[groupIdx + aiOffset];                               \
        uint pSumAtBi = ldsBuffer[groupIdx + groupSize + biOffset];                   \
        \
        \
        \
        return uint2(pSumAtAi, pSumAtBi);                                             \
    } \

#endif /* SCANPROMITIVES_INCLUDED */
