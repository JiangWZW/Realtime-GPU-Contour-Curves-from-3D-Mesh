using System;
using System.Collections.Generic;
using Assets.MPipeline.Custom_Data.PerMesh_Data;
using Assets.MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
using MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
using Sirenix.Utilities;
using Unity.Collections;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

namespace MPipeline.Custom_Data.PerMesh_Data
{
    public class MeshDataGPU : PerMeshData
    {
        public int BufferCount
        {
            get { return _meshBuffers.Length; }
        }

        // /////////// --------------------------------------------------------
        // Compute Buffers
        private int[] _presetBufferTypes;

        public CBufferDescriptor[] descriptorOfBuffer;

        private MeshBufferGPU[] _meshBuffers;

        // /////////// --------------------------------------------------------
        /// Init & Release
        public void Load(GameObject go, MeshBufferSource myMesh, int bufferNum = 3)
        {
            // 1. Load Source Mesh
            // 2. Cache basic attribs,
            // like vertex / triangle count
            base.Init(go, myMesh);

            // Configure contained buffer types that
            // gonna to be used later.
            _presetBufferTypes = new[]
            {
                MeshBufferPreset.BufferType.VP,
                MeshBufferPreset.BufferType.VN,

                MeshBufferPreset.BufferType.EV,
                MeshBufferPreset.BufferType.ET,

                MeshBufferPreset.BufferType.TN,
                MeshBufferPreset.BufferType.TV,
            };

            // Configure buffer descriptors & init buffers
            int numPresetTypes = MeshBufferPreset.NumBufferPresets;
            // Every preset-mesh-buffer type,
            // we'll reserve a slot even if it's not needed.
            descriptorOfBuffer = new CBufferDescriptor[numPresetTypes];
            _meshBuffers = new MeshBufferGPU[numPresetTypes];

            HashSet<int> typeSet = _presetBufferTypes.ToHashSet();
            for (int bufferType = 0; bufferType < numPresetTypes; bufferType++)
            {
                // For every preset mesh buffer type,
                // check if they are currently ordered in GPU side.
                // That is, in list '_presetBufferTypes' or not.
                if (typeSet.Contains(bufferType))
                {
                    descriptorOfBuffer[bufferType] =
                        MeshBufferGPU.presetMeshBufferDescriptor(
                            myMesh, bufferType
                        );
                    _meshBuffers[bufferType] = new MeshBufferGPU(descriptorOfBuffer[bufferType]);
                }
                else
                {
                    // For buffers that we don't need, just set as null.
                    descriptorOfBuffer[bufferType] = null;
                    _meshBuffers[bufferType] = null;
                }
            }

            initializedDeprecated = true;
            loadedDeprecated = false; // Use LoadMeshBuffersCommand
        }

        public void LoadMeshBuffersCommand(
            // meshDataCPU must have finished loading
            MeshDataCPUPreload meshDataCPU,
            CommandBuffer cmd
        )
        {
            // c-buffers must have been initialized
            if (!initializedDeprecated || !meshDataCPU.Loaded)
            {
                Debug.LogError(
                    "Error: Trying to load data into non-initialized MeshBuffers.\n"
                    + "In: " + name + " of " + this.name + "."
                );
                return;
            }

            // Safe Guard for multiple calls
            if (loadedDeprecated)
            {
                Debug.LogWarning(
                    "Incorrect use of LoadMeshData() method, which should be called" +
                    " only once for each PerMeshData monobehaviour during its lifetime."
                );
                return;
            }

            // Load data into c-buffers
            int type;

            type = MeshBufferPreset.BufferType.VP;
            IMeshStreamCG<float4>.Flush(
                meshDataCPU.vpBuffer,
                MeshBuffer(type),
                cmd,
                false
            );

            type = MeshBufferPreset.BufferType.VN;
            IMeshStreamCG<float4>.Flush(
                meshDataCPU.vnBuffer,
                MeshBuffer(type),
                cmd,
                false
            );

            type = MeshBufferPreset.BufferType.EV;
            IMeshStreamCG<uint>.Flush(
                meshDataCPU.evBuffer,
                MeshBuffer(type),
                cmd,
                false
            );

            type = MeshBufferPreset.BufferType.ET;
            IMeshStreamCG<uint>.Flush(
                meshDataCPU.etBuffer,
                MeshBuffer(type),
                cmd,
                false
            );

            type = MeshBufferPreset.BufferType.TN;
            IMeshStreamCG<float4>.Flush(
                meshDataCPU.tnBuffer,
                MeshBuffer(type),
                cmd,
                true
            );

            type = MeshBufferPreset.BufferType.TV;
            IMeshStreamCG<uint>.Flush(
                meshDataCPU.tvBuffer,
                MeshBuffer(type),
                cmd,
                false
            );
            
            // Setup flag
            loadedDeprecated = true;
        }

        public void ReleaseBuffers()
        {
            foreach (MeshBufferGPU meshBuffer in _meshBuffers)
            {
                if (meshBuffer == null)
                {
                    continue;
                }

                if (meshBuffer.Buffer.Allocated)
                {
                    meshBuffer.Buffer.GPUData.Release();
                }
            }

            loadedDeprecated = false;
            initializedDeprecated = false;
        }


        // -----------------------------------------------
        // Getters
        public MeshBufferGPU MeshBuffer(int type)
        {
            return _meshBuffers[type];
        }

        public List<MeshBufferGPU> MeshBuffers(IEnumerable<int> bufferTypes)
        {
            List<MeshBufferGPU> selectedBuffers = new List<MeshBufferGPU>();

            foreach (int type in bufferTypes)
            {
                selectedBuffers.Add(MeshBuffer(type));
            }

            return selectedBuffers;
        }

        public void BindBuffersToMatProps(
            MaterialPropertyBlock props,
            params int[] handles)
        {
            foreach (int type in handles)
            {
                props.SetBuffer(
                    MeshBuffer(type).Buffer.Id,
                    MeshBuffer(type).Buffer.GPUData
                );
            }
        }

        // -------------------------------------------------
        // Monobehaviour Events
        private void Awake()
        {
        }

        private void Start()
        {
        }

        private void Update()
        {
        }
    }
}