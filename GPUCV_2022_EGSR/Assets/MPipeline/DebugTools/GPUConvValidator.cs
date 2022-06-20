using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

public static class GPUConvValidator
{
    public static bool EdgeLoopConvolution<T>(
        int convRadius, 
        List<T> input, List<T> output,
        List<int> segLen, List<int> segHead, 
        int elemCount, int numThreadGroups,
        Func<T, T, T> Convolution, 
        Func<T, T, bool> Equal, 
        T zeroVal, 
        List<List<int>> DebugInfos
    ) where T : struct
    {
        bool succ = true;
        for (int elem = 0; elem < elemCount; elem++)
        {
            int headElem = segHead[elem];
            int loopLen = segLen[elem];

            // convolution for input[elem]
            T val = zeroVal;
            for (int offset = -convRadius; offset <= convRadius; offset++)
            {
                int offsetSign = offset < 0 ? -1 : (offset == 0 ? 0 : 1);
                int offsetAbs = math.abs(offset);
                offsetAbs %= loopLen;

                int offsetNormalized = offsetSign * offsetAbs;
                int neighElem = elem;
                neighElem -= headElem;
                neighElem = 
                    (neighElem + offsetNormalized + loopLen) % loopLen;
                neighElem += headElem;

                val = Convolution(input[neighElem], val);
            }

            if (!Equal(val, output[elem]))
            {
                succ = false;
            }
        }

        return succ;
    }
}
