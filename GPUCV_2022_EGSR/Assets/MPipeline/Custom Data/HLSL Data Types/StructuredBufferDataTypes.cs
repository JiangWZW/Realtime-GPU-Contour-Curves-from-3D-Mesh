using System;
using System.Security.Cryptography;
using UnityEngine;

namespace MPipeline.Custom_Data.HLSL_Data_Types
{
    public interface IStructuredDataType
    {
        int Stride();
    }

    public struct ContourLine : IStructuredDataType
    {
        public int Stride()
        {
            // 128 bits
            return 4 + 4 + 4 + 4;
        }

        // Point Attribs
        public uint IdxP0;
        public uint IdxP1;
        public uint IdxTriangle;
        public uint Flag;
    }

    public struct ContourPoint : IStructuredDataType
    {
        public int Stride()
        {
            return 4 + 4 + 4 * 2;
        }

        public uint IdxLine;
        public uint Dummy;
        public Vector2 Pos;
    }
}