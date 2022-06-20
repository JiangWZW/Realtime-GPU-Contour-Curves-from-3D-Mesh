using System.Collections.Generic;
using MPipeline.Custom_Data.PerCameraData;
using MPipeline.Custom_Data.PerMesh_Data;
using MPipeline.SRP_Assets.Passes;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

namespace Assets.MPipeline.SRP_Assets.Passes
{
    public class CsKernel : ICommandBufferConnected, ILineDrawingShaderResourceConnected
    {
        public readonly ComputeShader ComputeShader;
        public readonly int KernelIndex;

        public Vector3Int GroupsPerDispatch; // Dispatch(x, y, z)
        public Vector3Int ThreadsPerGroup; // [numthreads(x, y, z)]

        private CommandBuffer _cmd = null;
        private LineDrawingBuffers _lineDrawingBuffers = null;
        private LineDrawingTextures _lineDrawingTextures = null;
    
        private List<int> _meshBufferHandles;
        private List<int> _ldBufferHandles;
        private List<int> _ldTextureHandles;
        private List<(int id, RenderTargetIdentifier targ)> _externalTextures;
    
        public List<int> MeshBufferHandles => _meshBufferHandles;

        public List<int> LDBufferHandles => _ldBufferHandles;
        public bool hasLineDrawingBufferBinding = false;
        public List<int> LDTextureHandles => _ldTextureHandles;
        public bool hasLineDrawingTextureBinding = false;

        public void SetMeshBuffers(params int[] types)
        {
            if (_meshBufferHandles == null)
            {
                _meshBufferHandles = new List<int>();
            }
            else
            {
                _meshBufferHandles.Clear();
            }

            // Casting enum to int needs unbox, which can cause 
            // perf loss in realtime.
            foreach (int bufferType in types)
            {
                _meshBufferHandles.Add(bufferType);
            }
        }

        public void SetLineDrawingBuffers(params int[] types)
        {
            if (_ldBufferHandles == null)
            {
                _ldBufferHandles = new List<int>();
            }
            else
            {
                _ldBufferHandles.Clear();
            }

            foreach (int buffer in types)
            {
                _ldBufferHandles.Add(buffer);
            }

            hasLineDrawingBufferBinding = types.Length != 0;
        }

        public void SetExternalTextures(params (int id, RenderTargetIdentifier targ)[] textureIds)
        {
            if (_externalTextures == null)
            {
                _externalTextures = new List<(int id, RenderTargetIdentifier targ)>();
            }
            else
            {
                _externalTextures.Clear();
            }

            foreach (var tex in textureIds)
            {
                _externalTextures.Add(tex);
            }
        }

        public void SetLineDrawingTextures(params int[] textureHandles)
        {
            if (_ldTextureHandles == null)
            {
                _ldTextureHandles = new List<int>();
            }
            else
            {
                _ldTextureHandles.Clear();
            }

            foreach (var handle in textureHandles)
            {
                _ldTextureHandles.Add(handle);
            }

            hasLineDrawingTextureBinding = textureHandles.Length != 0;
        }

        public void BindExternalTexturesCommand()
        {
            foreach (var texture in _externalTextures)
            {
                _cmd.SetComputeTextureParam(
                    ComputeShader, KernelIndex,
                    texture.id,
                    texture.targ);
            }
        }

        public CsKernel(
            ComputeShader cs, string kernelName,
            int gpdX = 1, int gpdY = 1, int gpdZ = 1
        )
        {
            _meshBufferHandles = new List<int>();
            _ldBufferHandles = new List<int>();
            _ldTextureHandles = new List<int>();

            ComputeShader = cs;

            KernelIndex = cs.FindKernel(kernelName);

            GroupsPerDispatch = new Vector3Int(
                gpdX, gpdY, gpdZ
            );
            uint x, y, z;
            cs.GetKernelThreadGroupSizes(
                KernelIndex,
                out x, out y, out z
            );
            ThreadsPerGroup.x = (int) x;
            ThreadsPerGroup.y = (int) y;
            ThreadsPerGroup.z = (int) z;
        }

        public void DispatchViaCmd(CommandBuffer command)
        {
            command.DispatchCompute(
                ComputeShader,
                KernelIndex,
                GroupsPerDispatch.x,
                GroupsPerDispatch.y,
                GroupsPerDispatch.z
            );
        }

        public void DispatchIndirectViaCmd(
            CommandBuffer command,
            ComputeBuffer indirectArgs)
        {
            command.DispatchCompute(ComputeShader, KernelIndex, indirectArgs, 0);
        }

        public void SetupNumGroups1D(int numGroups)
        {
            GroupsPerDispatch.x = numGroups;
            GroupsPerDispatch.y = 1;
            GroupsPerDispatch.z = 1;
        }
        public void SetupNumGroupsBy1D(int threadNumTotal)
        {
            GroupsPerDispatch.x =
                GetGroupNum1D(threadNumTotal);
            GroupsPerDispatch.y = 1;
            GroupsPerDispatch.z = 1;
        }


        private int GetGroupNum1D(int threadNumTotal)
        {
            int threadsPerGroup = ThreadsPerGroup.x * ThreadsPerGroup.y * ThreadsPerGroup.z;
            return (int) Mathf.Ceil(threadNumTotal / (float) threadsPerGroup);
        }

        public void SetupDispatchGroupAmount2D(int2 threadNumTotal)
        {
            int2 dispatchScale = GetGroupNum2D(threadNumTotal);
            GroupsPerDispatch.x = dispatchScale.x;
            GroupsPerDispatch.y = dispatchScale.y;
            GroupsPerDispatch.z = 1;
        }

        /// <summary>
        /// Calculates how many groups are needed,
        /// when threading layout is 2D
        /// </summary>
        /// <param name="threadNumTotal"></param>
        /// <returns></returns>
        private int2 GetGroupNum2D(int2 threadNumTotal)
        {
            // e.g #total threads:     75x129
            // --- #threads per group: 32x32x1
            // ==> #groups: ceil((75, 129) / (32, 32)) = (3, 5)
            float2 workScale = threadNumTotal;
            float2 groupScale = new float2(ThreadsPerGroup.x, ThreadsPerGroup.y);
            return (int2) (math.ceil(workScale / groupScale));
        }

        /// <summary>
        /// Shortcut for binding line-drawing resources to a cskernel.
        /// </summary>
        public void BindWithLineDrawingResources(
            LineDrawingBuffers buffers = null,
            LineDrawingTextures textures = null)
        {
            if (buffers != null) buffers.BindBuffersWithKernelCommand(this);
            if (textures != null) textures.BindTexturesWithKernelCommand(this);
        }

        public void BindWithMeshDataGPU(MeshDataGPU meshData)
        {
            if (meshData != null)
            {
                foreach (var bufferHandle in MeshBufferHandles)
                {
                    MeshBufferGPU meshBuffer = meshData.MeshBuffer(bufferHandle);
                    _cmd.SetComputeBufferParam(
                        ComputeShader,
                        KernelIndex,
                        meshBuffer.Buffer.Id,
                        meshBuffer.Buffer.GPUData
                    );
                }
            }
        }


        public void ConnectToCmd(
            CommandBuffer cmd)
        {
            _cmd = cmd;
        }

        public void DisconnectCmd()
        {
            _cmd = null;
        }

        public void ConnectToLineDrawingResources(
            LineDrawingBuffers buffers = null,
            LineDrawingTextures textures = null)
        {
            _lineDrawingBuffers = buffers;
            _lineDrawingTextures = textures;
        }

        public void DisconnectFromLineDrawingResources()
        {
            _lineDrawingTextures = null;
            _lineDrawingBuffers = null;
        }

        public void LineDrawingDispatch()
        {
            BindWithLineDrawingResources(_lineDrawingBuffers, _lineDrawingTextures);
            DispatchViaCmd(_cmd);
        }

        public void LineDrawingDispatchIndirect()
        {
            BindWithLineDrawingResources(_lineDrawingBuffers, _lineDrawingTextures);
            DispatchIndirectViaCmd(_cmd, _lineDrawingBuffers.indirectDispatcher.CurrentArgs);
        }
    }
}