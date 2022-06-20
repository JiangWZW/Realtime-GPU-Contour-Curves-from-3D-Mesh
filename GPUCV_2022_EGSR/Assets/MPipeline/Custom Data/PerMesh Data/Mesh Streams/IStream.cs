using System;
using System.Collections;
using System.Collections.Generic;
using Assets.MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
using MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
using Sirenix.Utilities;
using UnityEngine;
using UnityEngine.Rendering;

public interface IStream<S, D, TData>
{
    void flush(S src, D dest);
}

public abstract class IMeshStreamCC<T> :
    IStream<List<T>, MeshBufferCPU<T>, T>
    where T : struct
{
    // ----------------------------------------------------
    // Static Methods
    public static void Flush(List<T> src, MeshBufferCPU<T> dest)
    {
        // Update buffer
        if (dest.Buffer == null)
        {
            Debug.LogError(
                "Error: Null reference to TVBuffer.\n");
        }

        dest.Buffer.Clear(); // Always clean buffer before insertion
        // Resize beforehand
        if (dest.Buffer.Capacity < src.Count)
        {
            // Resize
            dest.Buffer.Capacity = src.Count;
        }

        // Copy data
        dest.Buffer.AddRange(src);
    }

    public static void Flush(T[] src, MeshBufferCPU<T> dest)
    {
        // Update buffer
        if (dest.Buffer == null)
        {
            Debug.LogError(
                "Error: Null reference to MeshBufferCPU.\n");
        }

        dest.Buffer.Clear(); // Always clean buffer before insertion
        // Resize beforehand
        if (dest.Buffer.Capacity < src.Length)
        {
            // Resize
            dest.Buffer.Capacity = src.Length;
        }

        // Copy data
        dest.Buffer.AddRange(src);
    }
    
    /// <summary>
    /// Flush with special need of keeping dest buffer size,
    /// this happens when we have pre-defined dest buffer,
    /// e.g, mesh buffers are initialized with rounded size by
    /// the need of fitting into thread groups.
    /// </summary>
    /// <param name="src"></param>
    /// <param name="dest"></param>
    /// <param name="clearVal"></param>
    public static void FlushDestFixed(T[] src, MeshBufferCPU<T> dest, T clearVal)
    {
        int destSizeMinusSrc = dest.Count - src.Length;

        Flush(src, dest);
        // Now, src & dest has the same size as 'originalLengthSrc'
        // Then, we add dummy elems for remainders
        for (int i = 0; i < destSizeMinusSrc; i++)
        {
            dest.Buffer.Add(clearVal);
        }
    }

    public static void Flush(MeshBufferCPU<T> src, MeshBufferCPU<T> dest)
    {
        // Flush data
        Flush(src.Buffer, dest);
        // Update additional info, 
        // 1. count as list.count gets upfated automatically;
        // 2. stride won't change 'cause both side have same type <T>.
        dest.UpdateMeshBufferInfo(
            new MeshBufferInfo()
            {
                hlslName = string.Copy(src.hlslName),
                stride = src.stride
            }
        );
    }


    // ----------------------------------------------------
    // Instance Methods
    public void flush(List<T> src, MeshBufferCPU<T> dest)
    {
        IMeshStreamCC<T>.Flush(src, dest);
    }

    public void flush(MeshBufferCPU<T> src, MeshBufferCPU<T> dest)
    {
        IMeshStreamCC<T>.Flush(src, dest);
    }

    public void flush(T[] src, MeshBufferCPU<T> dest)
    {
        IMeshStreamCC<T>.Flush(src, dest);
    }
}


public abstract class IMeshStreamCG<T> :
    IStream<MeshBufferCPU<T>, MeshBufferGPU, T>
    where T : struct
{
    // Static Methods
    public static void Flush(MeshBufferCPU<T> src, MeshBufferGPU dest)
    {
        if (!dest.Buffer.Initialized)
        {
            Debug.LogError(
                "Error: Trying to Flush into an uninitialized CBuffer: " +
                dest.Buffer.ToString() + ",\n" +
                "which is illegal in normal situation.");
            return;
        }

        // This method works for both situation (allocated or not)
        CBufferDescriptor desc = dest.GetBufferDescriptor();
        dest.Buffer.AllocSafely(desc);
        dest.Buffer.SetData<T>(src.Buffer);

        dest.hlslName = string.Copy(src.hlslName);
    }

    public static void Flush(
        MeshBufferCPU<T> src, MeshBufferGPU dest,
        bool destAllocated
    )
    {
        if (!destAllocated)
        {
            Flush(src, dest);
            return;
        }

        if (!dest.Buffer.Allocated)
        {
            Debug.LogError(
                "Error: Trying to Flush into an unallocated CBuffer: " +
                dest.Buffer.ToString() + ",\n" +
                "which is illegal in normal situation.");
            return;
        }

        // This method works for both situation (allocated or not)
        dest.Buffer.SetData<T>(src.Buffer);

        dest.hlslName = string.Copy(src.hlslName);
    }

    public static void Flush(
        MeshBufferCPU<T> src, MeshBufferGPU dest,
        CommandBuffer cmd = null
    )
    {
        if (!dest.Buffer.Initialized)
        {
            Debug.LogError(
                "Error: Trying to Flush into an uninitialized CBuffer: " +
                dest.Buffer.ToString() + ",\n" +
                "which is illegal in normal situation.");
            return;
        }

        CBufferDescriptor desc = dest.GetBufferDescriptor();
        dest.Buffer.AllocSafely(desc);
        // dest.buffer.SetData<T>(src.buffer, cmd);
        cmd.SetBufferData(dest.Buffer.GPUData, src.Buffer);

        dest.hlslName = src.hlslName;
    }

    public static void Flush(
        MeshBufferCPU<T> src, MeshBufferGPU dest,
        CommandBuffer cmd,
        bool destAllocated = false
    )
    {
        if (!destAllocated)
        {
            Flush(src, dest, cmd);
            return;
        }

        if (!dest.Buffer.Allocated)
        {
            Debug.LogError(
                "Error: Trying to Flush into an unallocated CBuffer: " +
                dest.Buffer.ToString() + ",\n" +
                "which is illegal in normal situation.");
            return;
        }

        CBufferDescriptor desc = dest.GetBufferDescriptor();
        cmd.SetBufferData(dest.Buffer.GPUData, src.Buffer);
        dest.hlslName = src.hlslName;
    }

    // Instance Methods
    public void flush(MeshBufferCPU<T> src, MeshBufferGPU dest)
    {
        Flush(src, dest);
    }
}


public abstract class IMeshStreamGC<T> :
    IStream<MeshBufferGPU, MeshBufferCPU<T>, T>
    where T : struct
{
    // Static Methods
    public static void Flush(MeshBufferGPU src, MeshBufferCPU<T> dest)
    {
        if (null == dest.Buffer)
        {
            Debug.LogError(
                "Error: Trying to Flush into an uninitialized List: " +
                dest.Buffer.ToString() + ",\n" +
                "which is illegal in normal situation.");
            return;
        }

        // G2CTemp
        T[] temp = new T[src.Buffer.Count];
        src.Buffer.GPUData.GetData(temp);

        // CTemp2C
        dest.Buffer.Clear(); // Clear off old data
        IMeshStreamCC<T>.Flush(temp, dest);
    }


    // Instance Methods
    public void flush(MeshBufferGPU src, MeshBufferCPU<T> dest)
    {
        Flush(src, dest);
    }
}

public class IMeshStreamGMat
{
    public static void Flush(MeshBufferGPU src, MaterialPropertyBlock dest)
    {
        dest.SetBuffer(
            src.Buffer.Id, src.Buffer.GPUData
        );
    }

    public static void Flush(List<MeshBufferGPU> src, MaterialPropertyBlock dest)
    {
        foreach (MeshBufferGPU meshBuffer in src)
        {
            dest.SetBuffer(
                meshBuffer.Buffer.Id,
                meshBuffer.Buffer.GPUData
            );
        }
    }
}