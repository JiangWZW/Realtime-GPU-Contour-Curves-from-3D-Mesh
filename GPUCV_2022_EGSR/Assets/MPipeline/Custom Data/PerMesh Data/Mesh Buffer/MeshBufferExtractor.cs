using System;
using System.Collections.Generic;
using Assets.MPipeline.Custom_Data.PerMesh_Data;
using Assets.MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
using Unity.Mathematics;
using UnityEngine;
using Object = System.Object;

namespace MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer
{
    public static class MeshBufferExtractor
    {
        private static readonly
            Dictionary<int, Func<MeshBufferSource, Object>> ExtractorsCPU =
                new Dictionary<int, Func<MeshBufferSource, object>>
                {
                    {
                        // -----------=== VPBuffer Extractor ===-------------
                        MeshBufferPreset.BufferType.VP, source =>
                        {
                            // 1) Fetch buffer info & initialization ------
                            MeshBufferCPU<float4> vpBuffer =
                                initMeshBufferCPU<float4>(
                                    source,
                                    MeshBufferPreset.BufferType.VP);
                            
                            // 2) Create temp array & flush in data -------
                            float4[] vpCopy = Array.ConvertAll(
                                source.vertexPosition,
                                input =>
                                    new float4(input.xyz, 1.0f));

                            IMeshStreamCC<float4>.FlushDestFixed(
                                vpCopy, vpBuffer, float4.zero);

                            return vpBuffer;
                        }
                    },
                    {
                        // -----------=== VNBuffer Extractor ===-------------
                        MeshBufferPreset.BufferType.VN, source =>
                        {
                            MeshBufferCPU<float4> vnBuffer =
                                initMeshBufferCPU<float4>(
                                    source, 
                                    MeshBufferPreset.BufferType.VN);

                            float4[] vnCopy = Array.ConvertAll(
                                source.vertexNormal,
                                input =>
                                    new float4(input.xyz, 1.0f));
                            
                            IMeshStreamCC<float4>.FlushDestFixed(
                                vnCopy, vnBuffer, float4.zero);

                            return vnBuffer;
                        }
                    },
                    {
                        // -----------=== TVBuffer Extractor ===-------------
                        MeshBufferPreset.BufferType.TV, source =>
                        {
                            MeshBufferCPU<uint> tvBuffer =
                                initMeshBufferCPU<uint>(
                                    source,
                                    MeshBufferPreset.BufferType.TV);
                            
                            uint[] tvCopyAligned = new uint[tvBuffer.Count]; 
                            uint[] tvCopy = Array.ConvertAll(
                                source.triangleVerts, input => (uint) input);
                            if (tvCopyAligned.Length < tvCopy.Length)
                            {
                                Debug.LogError("Invalid length of" + tvCopyAligned.Length +
                                               " " + tvCopy.Length);
                            }
                            for (int i = 0; i < tvCopy.Length; i++)
                            {
                                tvCopyAligned[i] = tvCopy[i];
                            }
                            
                            IMeshStreamCC<uint>.FlushDestFixed(
                                tvCopyAligned, tvBuffer, 0);

                            return tvBuffer;
                        }
                    },
                    {
                        // -----------=== TNBuffer Extractor ===-------------
                        MeshBufferPreset.BufferType.TN, source =>
                        {
                            MeshBufferCPU<float4> tnBuffer =
                                initMeshBufferCPU<float4>(
                                    source,
                                    MeshBufferPreset.BufferType.TN);
                            
                            IMeshStreamCC<float4>.FlushDestFixed(
                                source.triangleNormal, tnBuffer, float4.zero);

                            return tnBuffer;
                        }
                    },
                    {
                        // -----------=== EVBuffer Extractor ===-------------
                        MeshBufferPreset.BufferType.EV, source =>
                        {
                            MeshBufferCPU<uint> evBuffer =
                                initMeshBufferCPU<uint>(
                                    source,
                                    MeshBufferPreset.BufferType.EV);

                            uint[] evCopy = Array.ConvertAll(
                                source.edgeVerts, val => (uint) val);
                            
                            IMeshStreamCC<uint>.FlushDestFixed(
                                evCopy, evBuffer, uint.MinValue);

                            return evBuffer;
                        }
                    },
                    {
                        // -----------=== ETBuffer Extractor ===-------------
                        MeshBufferPreset.BufferType.ET, source =>
                        {
                            MeshBufferCPU<uint> etBuffer =
                                initMeshBufferCPU<uint>(
                                    source,
                                    MeshBufferPreset.BufferType.ET);

                            uint[] etCopy = Array.ConvertAll(
                                source.edgeTriangles, val => (uint) val);
                            
                            IMeshStreamCC<uint>.FlushDestFixed(
                                etCopy, etBuffer, uint.MinValue);

                            return etBuffer;
                        }
                    }
                };

        public static bool ExtractFromMesh<TElement>(
            MeshBufferSource source, int bufferType, out MeshBufferCPU<TElement> meshBuffer)
            where TElement : struct
        {
            // Check typing inputs ------------------------------------
            meshBuffer = null;
            if (!MeshBufferPreset.IsValidBufferType(bufferType))
            {
                return false;
            }

            Type presetElemType = MeshBufferPreset.GetElementTypeOf(bufferType);
            if (presetElemType != typeof(TElement))
            {
                return false;
            }

            // Extract ----------------
            Func<MeshBufferSource, object> extractor = ExtractorsCPU[bufferType];
            meshBuffer = (MeshBufferCPU<TElement>) extractor(source);

            return true;
        }

        private static void AddExtractorCPU<TStride>(
            int targetBufferType,
            Func<MeshBufferSource, MeshBufferCPU<TStride>> extractor) where TStride : struct
        {
            // Invalid buffer type code --------------
            if (!MeshBufferPreset.IsValidBufferType(targetBufferType))
            {
                return;
            }

            // Unmatched buffer element type ---------
            Type typeStridePredefined = MeshBufferPreset.GetElementTypeOf(targetBufferType);
            if (typeStridePredefined != typeof(TStride))
            {
                return;
            }

            // ---------------------------------------------------
            // Here, we cast extractors:
            // Func<mesh, buffer<T>> =>cast=> Func<mesh, Object>
            // --- to avoid generic.
            ExtractorsCPU.Add(
                targetBufferType,
                o => (object) extractor(o)
            );
        }

        private static MeshBufferCPU<T> initMeshBufferCPU<T>(
            MeshBufferSource source, int bufferType) where T : struct
        {
            MeshBufferInfo bufferInitInfo =
                MeshBufferInfo.PresetMeshBufferInfo(
                    source, bufferType);
            MeshBufferCPU<T> meshBufferCPU =
                new MeshBufferCPU<T>(bufferInitInfo);

            return meshBufferCPU;
        }
    }
}