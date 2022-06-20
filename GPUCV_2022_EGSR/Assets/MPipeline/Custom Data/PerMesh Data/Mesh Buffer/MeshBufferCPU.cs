using System.Collections;
using System.Collections.Generic;
using Assets.MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
using MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
using UnityEngine;

[System.Serializable]
public class MeshBufferCPU<T> : MeshBuffer<List<T>>
    where T : struct
{
    [SerializeField]
    public List<T> _buffer;

    private int _count;

    public sealed override List<T> Buffer
    {
        get => _buffer;
        set => _buffer = value;
    }

    public MeshBufferCPU(
        MeshBufferInfo infoIn
    ) : base(infoIn)
    {
        Buffer = new List<T>(infoIn.count);
        _count = infoIn.count;
    }

    public override int Count => _count;
}