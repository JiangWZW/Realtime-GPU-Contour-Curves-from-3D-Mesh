using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;





/// <summary>
/// Container for global compute buffers in scene.
/// Once an buffer is created, it can be allocated, reallocated,
/// but it cannot be removed from this pool until the exit of program.
/// </summary>
public class CBufferPoolStatic : IEnumerable<CBuffer>
{
    [SerializeField]
    public List<CBuffer> buffers;

    /// <summary>
    /// How many buffers are presented in pool for now.
    /// </summary>
    /// <value></value>
    public int count{
        get{
            return buffers.Count;
        }
    }

    public CBuffer this[int buffer]{
        get{
            return buffers[buffer];
        }
    }

    public bool IsNull(){
        return (buffers == null);
    }

    public CBufferPoolStatic(){
        InitBuffers(0);
    }
    
    private void InitBuffers(int capacity = 0){
        buffers = new List<CBuffer>(capacity);
    }

    /// <summary>
    /// Fetch necessary info for shader resource binding.
    /// </summary>
    /// <param name="bufferHandle"></param>
    /// <param name="id">ShaderPropertyId, = -1 on invalid handle</param>
    /// <param name="data">ComputeShader, = null on invalid handle</param>
    /// <returns>true if handle is valid</returns>
    public bool TryGetBufferInfo(
        int bufferHandle, 
        out int id, out ComputeBuffer data)
    {
        if (bufferHandle >= count)
        { // Invalid handle, exit
            data = null;
            id = -1;
            return false;
        }
        
        data = buffers[bufferHandle].GPUData;
        id = buffers[bufferHandle].Id;
        return true;
    }
    
    public void TrySetBuffer(int buffer, Array data){
        if (data.Length != buffers[buffer].GPUData.count)
        {
            return;
        }
        buffers[buffer].SetData(data);
    }
    
    public void TrySetBufferCommand(int buffer, Array data, CommandBuffer cmd){
        if (data.Length != buffers[buffer].GPUData.count)
        {
            return;
        }
        buffers[buffer].SetDataCommand(data, cmd);
    }

    public void ResizeBuffer(int buffer, CBufferDescriptor desc){
        if (desc.count <= buffers[buffer].GPUData.count){
            return;
        }
        buffers[buffer].Realloc(desc);
    }

    public void ReallocBuffer(int buffer, CBufferDescriptor desc)
    {
        buffers[buffer].Realloc(desc);
    }

    /// <summary>
    /// Allocates a buffer to pool.
    /// </summary>
    /// <param name="desc">
    /// Descriptor of the new buffer.
    /// </param>
    /// <returns>
    /// Index of this newly created buffer, use this index 
    /// as buffer id to get buffer from pool.
    /// </returns>
    public int AppendBuffer(CBufferDescriptor desc){
        CBuffer newBuffer = new CBuffer();
        newBuffer.AllocSafely(desc);

        int index = buffers.Count; 
        buffers.Add(newBuffer);
        
        return index;
    }
    /// <summary>
    /// Allocates a series of buffers into the pool.
    /// </summary>
    /// <param name="descs">array that holds all the CBufferDescriptor s.</param>
    /// <param name="descnum"></param>
    /// <returns>Buffer Number before this append operation, 
    /// in other words, this is where your 1st new buffer get located.</returns>
    public void AppendBuffers(
        CBufferDescriptor[] descs,
        ref List<int> handles
    )
    {
        int oldLength = buffers.Count;
        // Where 1st new buffer located
        foreach (CBufferDescriptor t in descs)
        {
            handles.Add(AppendBuffer(t));
        }
    }

    /// <summary>
    /// Calls ComputeBuffer.Release() for a certain buffer.
    /// </summary>
    /// <param name="handle">integer handle of that buffer.</param>
    /// <returns>false if index out of range.</returns>
    public bool ReleaseBuffer(int handle){
        if (handle < 0 || buffers.Count <= handle){
            // Out of range
            return false;
        }
        buffers[handle].Release();
        return true;
    }
    /// <summary>
    /// Calls ComputeBuffer.Release() for all compute buffers,  
    /// and calls List.Clear() to remove all references to these    
    /// buffers in the list.
    /// </summary>
    public void ReleaseBuffers(){
        // Releasing resources on GPU side.
        foreach (CBuffer buffer in buffers)
        {
            if (buffer != null)
            {
                buffer.Release();
            }
            else
            {
                Debug.LogError("Invalid null custom global buffer detected.");
            }
        }
        // Releasing all references on CPU side.
        buffers.Clear();
    }

    public IEnumerator<CBuffer> GetEnumerator()
    {
        return buffers.GetEnumerator();
    }

    IEnumerator IEnumerable.GetEnumerator()
    {
        return GetEnumerator();
    }
}
