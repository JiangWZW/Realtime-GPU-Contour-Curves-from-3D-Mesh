using Unity.Mathematics;

namespace MPipeline.Custom_Data.HLSL_Data_Types
{
    public struct ExtractedData
    {
        private const int Stride = 32;
        private const int WordsPerElem = Stride / 4;

        public static int ElemCountFromNumWords(int wordsInBuffer)
        {
            return wordsInBuffer / WordsPerElem;
        }

        public static int WordCountFromNumElems(int elemsInBuffer)
        {
            return elemsInBuffer * WordsPerElem;
        }

        public uint4 PrimIds; // [Triangle, Vert0, Vert1, Vert2]
        public uint2 Adjacency; // [AdjTri0, AdjTri1]
        public float2 BlendFactors; // [Blend(V0, V1), Blend(V1, V2)]
    }

    public struct CompactedFlags
    {
        public uint4 Flags; // [F0, F1, F2, F3]
    }
}