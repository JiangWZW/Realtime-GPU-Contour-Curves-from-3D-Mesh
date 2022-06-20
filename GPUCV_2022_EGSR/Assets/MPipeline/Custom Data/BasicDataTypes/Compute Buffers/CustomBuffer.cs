using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public abstract class CustomBufferDescriptor
{
    public string name;
    public int count;
    public int stride;
    
    public CustomBufferDescriptor(
        string nameIn = "",
        int countIn = -1,
        int strideIn = -1
    )
    {
        name = nameIn;
        count = countIn;
        stride = strideIn;
    }
}

public abstract class CustomBuffer<BufferDesc>
where BufferDesc : CustomBufferDescriptor
{
    public abstract int Count { get; }

    public abstract void Release();
    public abstract void AllocSafely(BufferDesc desc);
    public abstract void Realloc(BufferDesc desc);
    public abstract void Alloc(BufferDesc desc);

    // public abstract void SetData<T>(List<T> source) where T : struct;
    // public abstract void SetData<T>(System.Array source);

}
