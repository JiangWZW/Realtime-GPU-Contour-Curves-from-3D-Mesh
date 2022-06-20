using System;
using System.Collections.Generic;
using System.Reflection;
using Unity.Mathematics;
using UnityEngine;
using Object = System.Object;

namespace Assets.MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer
{
    public class MeshBufferInfo
    {
        public string hlslName;
        public int count;
        public int stride;

        public MeshBufferInfo()
        {
            hlslName = "";
            count = -1;
            stride = 0;
        }

        public MeshBufferInfo(CBufferDescriptor desc)
        {
            count = desc.count;
            stride = desc.stride;
            hlslName = desc.name;
        }

        public static MeshBufferInfo PresetMeshBufferInfo(
            MeshBufferSource mesh, int meshBufferPresetType)
        {
            MeshBufferInfo info = new MeshBufferInfo();
            int bufferType = meshBufferPresetType;
            info.count = MeshBufferPreset.GetBufferLength(mesh, bufferType);
            info.stride = MeshBufferPreset.GetStrideOfType(bufferType);
            info.hlslName = MeshBufferPreset.GetHlslNameOfType(bufferType);

            return info;
        }

        public CBufferDescriptor ToCBufferDescriptor(
            ComputeBufferType type)
        {
            return new CBufferDescriptor(type, hlslName, count, stride);
        }
    }

    public static class MeshBufferPreset
    {
        // Hard-coded Constants
        public static readonly int NumBufferPresets;

        public static class BufferType
        {
            public static readonly int VP = 0; // Vertex Position
            public static readonly int VN = 1; // Vertex Normal
            
            public static readonly int EV = 2; // Edge List
            public static readonly int ET = 3; // Edge Triangles
            
            public static readonly int TN = 4; // Triangle Normal
            public static readonly int TV = 5; // Triangle List
            public static readonly int TT = 6; // Triangle Adjacency
        }

        private static readonly Type RawBufferElemType = typeof(uint);

        private static readonly Dictionary<int, Type> ElemTypes =
            new Dictionary<int, Type>
            {
                {BufferType.VP, typeof(float4)},
                {BufferType.VN, typeof(float4)},

                {BufferType.EV, RawBufferElemType},
                {BufferType.ET, RawBufferElemType},
                
                {BufferType.TN, typeof(float4)},
                {BufferType.TV, RawBufferElemType},
                {BufferType.TT, typeof(uint)},
            };

        // Provides serialized access to strides
        private const int RawBufferStride = sizeof(uint);

        private static readonly Dictionary<int, int> Strides = new Dictionary<int, int>
        {
            {BufferType.VP, sizeof(float) * 4},
            {BufferType.VN, sizeof(float) * 4},
            
            {BufferType.EV, RawBufferStride},
            {BufferType.ET, RawBufferStride},

            {BufferType.TN, sizeof(uint) * 4},
            {BufferType.TV, RawBufferStride},
            {BufferType.TT, sizeof(uint)},
        };

        private static readonly Dictionary<int, ComputeBufferType> ComputeBufferTypes =
            new Dictionary<int, ComputeBufferType>
            {
                {BufferType.VP, ComputeBufferType.Structured},
                {BufferType.VN, ComputeBufferType.Structured},
                
                {BufferType.EV, ComputeBufferType.Raw},
                {BufferType.ET, ComputeBufferType.Raw},
                
                {BufferType.TN, ComputeBufferType.Structured},
                {BufferType.TV, ComputeBufferType.Raw},
                {BufferType.TT, ComputeBufferType.Structured},
            };

        private const int MaxGroupSize = 256;

        private static int RoundSize(int originalSize)
        {
            int numGroups = Mathf.CeilToInt(f: (float) originalSize / (float)MaxGroupSize);
            return numGroups * MaxGroupSize;
        }
        private static readonly Dictionary<int, Func<MeshBufferSource, int>> BufferLengthFuncs =
            new Dictionary<int, Func<MeshBufferSource, int>>
            {
                {BufferType.VP, mesh => RoundSize(mesh.VertexCount)},
                {BufferType.VN, mesh => RoundSize(mesh.VertexCount)},
                
                {BufferType.EV, mesh => RoundSize(mesh.EdgeCount * 2)},
                {BufferType.ET, mesh => RoundSize(mesh.EdgeCount * 2)},
                
                {BufferType.TN, mesh => RoundSize(mesh.TriangleCount)},
                {BufferType.TV, mesh => RoundSize(mesh.TriangleListSize)},
                {BufferType.TT, mesh => RoundSize(mesh.TriangleListSize)},
            };


        // Automatically generated fields ---------------------------
        private static readonly Dictionary<int, string> BufferTags;

        private static readonly Dictionary<int, string> BufferNamesHlsl;


        // Field Extractors ------------------------------------------------
        public static Type GetElementTypeOf(int bufferType)
        {
            if (ElemTypes.TryGetValue(bufferType, out Type output))
            {
                return output;
            }

            return typeof(Object);
        }

        public static int GetStrideOfType(int type)
        {
            return Strides[type];
        }

        public static ComputeBufferType GetComputeBufferTypeOf(int type)
        {
            return ComputeBufferTypes[type];
        }

        public static string GetHlslNameOfType(int type)
        {
            return BufferNamesHlsl[type];
        }

        public static int GetBufferLength(MeshBufferSource mesh, int type)
        {
            return BufferLengthFuncs[type].Invoke(mesh);
        }

        static MeshBufferPreset()
        {
            BufferTags = new Dictionary<int, string>();
            CalculateBufferTags();

            BufferNamesHlsl = new Dictionary<int, string>();
            CalculateBufferHlslNames();

            NumBufferPresets = BufferTags.Count;
        }

        private static void CalculateBufferHlslNames()
        {
            foreach (var bufferTypeTagPair in BufferTags)
            {
                BufferNamesHlsl.Add(
                    bufferTypeTagPair.Key, // <== Buffer Type
                    // Calculated Buffer Name in HLSL Code. ==>
                    ObjectNaming.getBufferHlslName(bufferTypeTagPair.Value)
                );
            }
        }

        private static void CalculateBufferTags()
        {
            Type typeBuffers = typeof(BufferType);
            FieldInfo[] props =
                typeBuffers.GetFields();
            foreach (FieldInfo prop in props)
            {
                string bufferTag = prop.Name + "List";
                BufferTags.Add((int) prop.GetValue(null), bufferTag);
            }
        }

        public static bool IsValidBufferType(int type)
        {
            return (0 <= type && type < NumBufferPresets);
        }
    }

    public abstract class MeshBuffer<TBufferType>
    {
        // Instance ----------------------------------------------
        public string hlslName;
        public abstract int Count { get; }
        public int stride;

        public abstract TBufferType Buffer { get; set; }

        public MeshBuffer(
            MeshBufferInfo infoIn
        )
        {
            UpdateMeshBufferInfo(infoIn);
        }

        public void UpdateMeshBufferInfo(
            MeshBufferInfo infoIn
        )
        {
            hlslName = String.Copy(infoIn.hlslName);
            stride = infoIn.stride;
        }
    }
}