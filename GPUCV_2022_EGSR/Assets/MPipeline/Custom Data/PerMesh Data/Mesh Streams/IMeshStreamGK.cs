using Assets.MPipeline.SRP_Assets.Passes;
using UnityEngine.Rendering;

namespace MPipeline.Custom_Data.PerMesh_Data.Mesh_Streams
{
    public class IMeshStreamGK : IStream<MeshBufferGPU, CsKernel, uint>
    {
        // Static methods
        public static void Flush(MeshBufferGPU src, CsKernel dest)
        {
            dest.ComputeShader.SetBuffer(
                dest.KernelIndex,
                src.Buffer.Id,
                src.Buffer.GPUData
            );
        }

        public static void Flush(MeshBufferGPU src, CsKernel dest, CommandBuffer cmd)
        {
            cmd.SetComputeBufferParam(
                dest.ComputeShader,
                dest.KernelIndex,
                src.Buffer.Id,
                src.Buffer.GPUData
            );
        }

        public static void Flush(
            MeshDataGPU src, CsKernel dest, CommandBuffer cmd)
        {
            foreach (var bufferHandle in dest.MeshBufferHandles)
            {
                MeshBufferGPU meshBufferGpu = src.MeshBuffer(bufferHandle);
                Flush(meshBufferGpu, dest, cmd);
            }
        }


        // Instance warpper(s)
        public CommandBuffer cmd;

        public IMeshStreamGK(
            CommandBuffer command
        )
        {
            ConnectToCommandQueue(command);
        }

        public void ConnectToCommandQueue(
            CommandBuffer command
        )
        {
            cmd = command;
        }

        public void flush(MeshBufferGPU src, CsKernel dest)
        {
            Flush(src, dest);
        }
    }
}