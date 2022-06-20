using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GBufferDescriptor : CustomBufferDescriptor
{
    public readonly GraphicsBuffer.Target view;

    public GBufferDescriptor(
        GraphicsBuffer.Target viewIn,
        string nameIn = "",
        int countIn = -1,
        int strideIn = -1
    ) : base(nameIn, countIn, strideIn){
        view = viewIn;
    }
}

public class GBuffer : CustomBuffer<GBufferDescriptor>
{
    private GraphicsBuffer data;
    private bool           initialized;
    private bool           allocated;
    private int id;
    

    # region getters
    // buffer.count
    public override int Count{
        get{
            return data.count;
        }
    }
    // this.initialized
    public bool Initialized{
        get {
            return initialized;
        }
    }
    // this.allocated
    public bool Allocated{
        get{
            return allocated;
        }
    }
    // this.id
    public int Id{
        get {
            return id;
        }
    }
    #endregion

    public GBuffer(){
        data = null;
        initialized = allocated = false;
        id = -1;
    }

    public override void Alloc(GBufferDescriptor desc){
        _Alloc(desc.view, desc.name, desc.count, desc.stride);
    }

    public override void Release(){
        if (allocated){
            data.Release();
        }
        allocated = false;
        id = -1;
    }

    public override void Realloc(
        GBufferDescriptor desc
    ){
        if (!allocated){
            return;
        }

        Release();
        Alloc(desc);
    }

    public override void AllocSafely(GBufferDescriptor desc){
        if (allocated){
            // Allocated buffer needs to be released first.
            Realloc(desc);
        }
        else {
            // Released buffer || Uninitialized buffer
            Alloc(desc);
        }
    }

    private void _Alloc(
        GraphicsBuffer.Target viewIn,
        string nameIn,
        int countIn,
        int strideIn
    ){
        if (allocated) { return; }

        // when allocated == false
        id = Shader.PropertyToID(nameIn);
        initialized = allocated = true;
        data = new GraphicsBuffer(
            viewIn, countIn, strideIn
        );
    }

}
