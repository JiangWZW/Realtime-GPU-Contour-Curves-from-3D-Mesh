using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// Descriptor for class <c>CBuffers</c>.
/// <para>
/// When you want to create a CBuffer, 
/// you need to provide a valid descriptor first.
/// </para>
/// 1. type: Type of this compute buffer.
/// 2. name: Buffer's name in hlsl code.
/// 3. count: Element count.
/// 4. stride: Bytes per element.
/// </summary>
public class CBufferDescriptor : CustomBufferDescriptor
{
    public ComputeBufferType type;

    public CBufferDescriptor(
        ComputeBufferType bufferType = ComputeBufferType.Structured,
        string nameIn = "",
        int countIn = -1,
        int strideIn = -1
    ) : base(nameIn, countIn, strideIn)
    {
        type = bufferType;
    }
}

public class CBuffer : CustomBuffer<CBufferDescriptor>
{
    public ComputeBuffer GPUData;
    public bool Initialized; // always true since 1st alloc
    public bool Allocated; // only true when allocated
    public int Id;

    public CBuffer()
    {
        GPUData = null;
        Allocated = Initialized = false;
        Id = -1;
    }

    public override int Count
    {
        get { return GPUData.count; }
    }

    public override void Release()
    {
        if (Allocated)
        {
            GPUData.Release();
        }

        Allocated = false;
        Id = -1;
    }

    /// <summary>
    /// Allocate compute buffer in a safe manner.
    /// </summary>s
    public override void AllocSafely(
        CBufferDescriptor desc
    )
    {
        if (Allocated)
        {
            // Allocated buffer needs to be released first.
            Realloc(desc);
        }
        else
        {
            // Released buffer || Uninitialized buffer
            Alloc(desc);
        }
    }

    public override void Realloc(CBufferDescriptor desc)
    {
        Release();
        Alloc(desc);
    }

    public override void Alloc(CBufferDescriptor desc)
    {
        if (Allocated)
        {
            // buffer already allocated, do nothing & return
            return;
        }

        _Alloc(
            desc.count, desc.stride, desc.type, desc.name
        );
    }

    ///-////////////////-----------------------------------
    // Don't set this as public 'cause it doesn't
    // accomplish a full allocation process (init the desc),
    // which is inappropriate according to SOLID principle.
    private void _Alloc(
        int count, int stride, ComputeBufferType type,
        string name
    )
    {
        // Buffer must be cleared before Alloc
        // Alloc memory
        GPUData = new ComputeBuffer(count, stride, type);
        Allocated = Initialized = true;
        string nameHLSL = name; // Name in hlsl shaders
        GPUData.name = name; // Name for debugging
        Id = Shader.PropertyToID(nameHLSL);
    }


    public void SetData<T>(
        List<T> data) where T : struct
    {
        if (!Allocated) return;
        GPUData.SetData(data);
    }

    public void SetData(Array data)
    {
        if (!Allocated) return;
        GPUData.SetData(data);
    }
    
    public void SetDataCommand<T>(List<T> data, CommandBuffer cmd) where T : struct
    {
        if (!Allocated) return;
        cmd.SetBufferData(GPUData, data);
    }

    public void SetDataCommand(Array data, CommandBuffer cmd)
    {
        if (!Allocated) return;
        cmd.SetBufferData(GPUData, data);
    }
}