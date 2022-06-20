using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Runtime.InteropServices.WindowsRuntime;
using System.Text;
using Unity.Mathematics;
using UnityEditor;

namespace MPipeline.DebugTools
{
    public static class GPUScanValidator
    {
        public static bool DeviceScan<T>(
            List<T> input,
            List<T> output,
            // List<List<float4>> lookBackWindows, 
            // List<float> lookBackPrevSums, 
            int groupSize, 
            int dataSize,
            T zeroValue,
            Func<T, T, T> op,
            Func<T, T, bool> equals, 
            out string errorMsg,
            bool inclusive = false
        ) where T : struct
        {
            errorMsg = "";
            StringBuilder message = new StringBuilder("Scan Validator Message: ");
            T currScanValue = zeroValue;

            bool zeroError = true;

            for (int i = 0; i < dataSize; i++)
            {
                if (inclusive)
                {
                    // Inclusive scan
                    currScanValue = op(currScanValue, input[i]);
                }

                if (!@equals(currScanValue, output[i]))
                {
                    if (zeroError)
                    {
                        message.AppendLine("Invalid scan result found at " + i + ".");
                    }
                    zeroError = false;
                }

                if (!inclusive)
                {
                    // Exclusive scan
                    currScanValue = op(currScanValue, input[i]);
                }
            }

            if (zeroError)
            {
                // Output validation states, in case that this input params are wrong.
                message.Clear();
                message.AppendLine("Congrats, scan test passed");
                message.AppendLine("#Total Elems: \t" + dataSize);
            }

            errorMsg = message.ToString();

            return zeroError;
        }

        public static bool ScanInterBlock(
            List<uint> bufferInputVals,
            List<uint> bufferPrefixSum,
            uint totalPrefixSum,
            int blockSize,
            int numBlocks,
            int dataSize,
            out StringBuilder errorMessage
        )
        {
            errorMessage = new StringBuilder("Scan Validator Message: ");

            //         1) Make sure I/O buffers have the right sizes
            // ===============================================================
            if (bufferInputVals.Count < dataSize)
            {
                errorMessage.AppendLine("Input buffer has smaller size: " +
                                        bufferInputVals.Count +
                                        ", than the actual elem count: " +
                                        dataSize + ".");
                return false;
            }

            if (bufferPrefixSum.Count < dataSize)
            {
                errorMessage.AppendLine("Output buffer has smaller size: " +
                                        bufferPrefixSum.Count +
                                        ", than the actual elem count: " +
                                        dataSize + ".");
                return false;
            }

            // Shrink to eliminate all trash values
            int trashDataCount = bufferInputVals.Count - dataSize;
            bufferInputVals.RemoveRange(dataSize, trashDataCount);
            trashDataCount = bufferPrefixSum.Count - dataSize;
            bufferPrefixSum.RemoveRange(dataSize, trashDataCount);


            //                             2) Check general coherency
            // =====================================================================================
            // 1st elem in args buffer is the total scan sum
            // ---------------------------------------------
            if (totalPrefixSum <= 0)
            {
                errorMessage.AppendLine("Invalid args buffer element[0]:= " +
                                        totalPrefixSum + ", it should be" +
                                        "larger than 0.");
                return false;
            }

            // Min Prefix Sum == 0
            uint minPrefixSum = bufferPrefixSum.Min();
            if (minPrefixSum != 0)
            {
                errorMessage.AppendLine("prefix sums start from an non-zero value.");
            }


            // (Total sum) == (last elem) + (prefix-sum in last elem)
            // ------------------------------------------------------
            uint maxPrefixSum = bufferPrefixSum.Max();
            int maxPrefixSumIndex =
                // Last element that has the max prefix value
                bufferPrefixSum.FindLastIndex(
                    pSum => pSum == maxPrefixSum
                );
            uint lastElem = bufferInputVals[maxPrefixSumIndex]; // same index
            uint totalSum = totalPrefixSum;

            if (maxPrefixSum + lastElem != totalSum)
            {
                errorMessage.AppendLine("Scan result doesn't match with total sum in args buffer,\n" +
                                        "maxPrefixSum: " + maxPrefixSum +
                                        ", \n lastElem: " + lastElem +
                                        ", \n totalSum: " + totalSum +
                                        ", \n lastElem + maxPrefixSum: " + (lastElem + maxPrefixSum));
                return false;
            }

            //                        2) Fine-Grained Validation Tests
            // =====================================================================================
            List<int> failedElems = new List<int>();

            for (int block = 0; block < numBlocks; block++)
            {
                for (int slot = 0; slot < blockSize - 1; slot++)
                {
                    // index might go out of bound
                    int index = math.min(blockSize * block + slot, dataSize - 2);

                    if (bufferPrefixSum[index] + bufferInputVals[index] != bufferPrefixSum[index + 1])
                    {
                        failedElems.Add(index);
                    }
                }
            }

            if (failedElems.Count != 0)
            {
                errorMessage.AppendLine("Incorrect result detected.");
                return false;
            }


            // Finally, if data passed every test, then clear all error texts
            errorMessage.Clear();
            return true;
        }

        public static uint WangHash(uint seed)
        {
            seed = (seed ^ 61) ^ (seed >> 16);
            seed *= 9;
            seed ^= (seed >> 4);
            seed *= 0x27d4eb2d;
            seed ^= (seed >> 15);
            return seed;
        }

        public static bool SegmentedScanIntraWave<T>(
            List<T> input,
            List<bool> headFlags,
            List<T> output,
            int dataSize,
            T zeroValue,
            Func<T, T, T> op,
            out string errorMsg,
            bool inclusive = false
        )
        {
            int waveSize = 32;
            errorMsg = "";
            StringBuilder message = new StringBuilder("Scan Validator Message: ");
            T currScanValue = zeroValue;
            bool noError = true;

            for (int i = 0; i < dataSize; i++)
            {
                if (headFlags[i] || (i % waveSize == 0))
                {
                    currScanValue = zeroValue;
                }

                if (inclusive)
                {
                    // Inclusive scan
                    currScanValue = op(currScanValue, input[i]);
                }

                if (!currScanValue.Equals(output[i]))
                {
                    message.AppendLine("Invalid scan result found at " + i + ".\n" +
                                       "output value: " + output[i] + "\t " +
                                       "correct value: " + currScanValue);
                    noError = false;
                }

                if (!inclusive)
                {
                    // Exclusive scan
                    currScanValue = op(currScanValue, input[i]);
                }
            }

            errorMsg = noError ? "Congrats, Segmented scan test passed." : message.ToString();
            return true;
        }

        public static bool SegmentedScanIntraBlock<T>(
            List<T> input,
            List<bool> headFlags,
            List<T> output,
            int dataSize,
            int threadBlockSize,
            T zeroValue,
            Func<T, T, T> op,
            out string errorMsg,
            bool inclusive = false
        )
        {
            errorMsg = "";
            StringBuilder message = new StringBuilder("Scan Validator Message: ");
            T currScanValue = zeroValue;
            bool noError = true;

            for (int i = 0; i < dataSize; i++)
            {
                if (headFlags[i] || (i % threadBlockSize == 0))
                {
                    currScanValue = zeroValue;
                }

                if (inclusive)
                {
                    // Inclusive scan
                    currScanValue = op(currScanValue, input[i]);
                }

                if ((!currScanValue.Equals(output[i])))
                {
                    message.AppendLine("Invalid scan result found at " + i + ".\n" +
                                       "output value: " + output[i] + "\t " +
                                       "correct value: " + currScanValue);
                    noError = false;
                    break;
                }

                if (!inclusive)
                {
                    // Exclusive scan
                    currScanValue = op(currScanValue, input[i]);
                }
            }

            errorMsg = noError ? "Congrats, Segmented scan test passed." : message.ToString();
            return true;
        }


        public static bool SegmentedScan<T>(
            List<T> input,
            List<bool> headFlags,
            List<T> output,
            int dataSize,
            int groupSize, 
            T zeroValue,
            T errorThreshold, 
            Func<T, T, T> op,
            Func<T, T, T> dist, 
            Func<T, T, bool> smallerThan, 
            out string errorMsg,
            bool inclusive = false
        ) where T: struct
        {
            errorMsg = "";
            StringBuilder message = new StringBuilder("Scan Validator Message: ");
            T maxErrorFound = zeroValue;
            T currScanValue = zeroValue;
            bool noError = true;

            for (int i = 0; i < dataSize; i++)
            {
                if (headFlags[i])
                {
                    currScanValue = zeroValue;
                }

                if (inclusive)
                {
                    // Inclusive scan
                    currScanValue = op(currScanValue, input[i]);
                }

                T error = dist(currScanValue, output[i]);
                if (smallerThan(errorThreshold, error))
                {
                    if (smallerThan(maxErrorFound, error))
                    {
                        maxErrorFound = error;

                        message.Clear();
                        int elemId = inclusive ? i : i;
                        message.AppendLine(
                            "Invalid scan result found at " + i + ", " +
                            "[" + i / groupSize + ", " + i % groupSize + "]." + "\n" +
                            "output: (val=" + output[i] + ")\t " +
                            "correct output: (" +
                            "hf=" + headFlags[i] + ", " +
                            "val=" + currScanValue +
                            ")" + " max diff=" + maxErrorFound
                        );
                        message.AppendLine(
                            "last output: (val=" + output[i == 0 ? 0 : i - 1]
                        );
                        message.AppendLine("#Elems: " + dataSize);
                        message.AppendLine("Input value: " + input[elemId] + "\t"
                                           + "Head Flag: " + headFlags[elemId]);
                        // message.AppendLine("#Group Index:" + ((elemId) % threadBlockSize));
                        // message.AppendLine("#Group ID:" + ((elemId) / threadBlockSize));

                        noError = false;
                    }
                }

                if (!inclusive)
                {
                    // Exclusive scan
                    currScanValue = op(currScanValue, input[i]);
                }
            }

            errorMsg = noError ? "Congrats, Segmented scan test passed." : message.ToString();
            return true;
        }

        // float values may have precision loss on CPU side.
        // need to use double instead
        public static bool SegmentedScanf32x4(
            List<float4> input,
            List<bool> headFlags,
            List<float4> output,
            int dataSize,
            float4 zeroValue,
            float4 errorThreshold, 
            Func<float4, float4, float4> op,
            out string errorMsg,
            bool inclusive = false
        )
        {
            errorMsg = "";
            StringBuilder message = new StringBuilder("Scan Validator Message: ");
            float4 currScanValue = zeroValue;
            bool noError = true;

            List<float4> groundTruthOutput = new List<float4>();

            float4 maxError = .0f;
            for (int i = 0; i < dataSize; i++)
            {
                if (headFlags[i])
                {
                    currScanValue = zeroValue;
                }

                if (inclusive)
                {
                    // Inclusive scan
                    currScanValue = op(currScanValue, input[i]);
                    groundTruthOutput.Add(currScanValue);
                }

                float4 error = currScanValue - output[i];
                if (math.any(math.abs(error) > errorThreshold))
                {
                    if (math.any(math.abs(error) > maxError))
                    {
                        message.Clear();

                        int elemId = inclusive ? i : i - 1;
                        message.AppendLine(
                            "Invalid scan result found at " + i + ".\n" +
                            "output: (val=" + output[i] + ")\t " +
                            "correct output: (" +
                            "hf=" + headFlags[i] + ", " +
                            "val=" + currScanValue +
                            ")" + "\n" + 
                            "Difference=" + (currScanValue - output[i])
                        );
                        message.AppendLine("#Elems: " + dataSize);
                        message.AppendLine("Input value: " + input[elemId] + "\t"
                                           + "Head Flag: " + headFlags[elemId]);
                    }

                    noError = false;
                }

                if (!inclusive)
                {
                    // Exclusive scan
                    currScanValue = op(currScanValue, input[i]);
                    groundTruthOutput.Add(currScanValue);
                }
            }

            errorMsg = noError ? "Congrats, Segmented scan test passed." : message.ToString();
            return true;
        }
    }
}