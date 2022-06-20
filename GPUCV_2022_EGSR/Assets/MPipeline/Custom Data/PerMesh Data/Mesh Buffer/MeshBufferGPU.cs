using System.Collections;
using System.Collections.Generic;
using System.Security.Principal;
using Assets.MPipeline.Custom_Data.PerMesh_Data;
using Assets.MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
using MPipeline.Custom_Data.PerMesh_Data;
using MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
using UnityEngine;


// Has nothing to do with value type, so set as uint.
public class MeshBufferGPU : MeshBuffer<CBuffer>
{
    // type gets cached, in case of later realloc ops
    private readonly ComputeBufferType _type;
    private CBuffer _cBuffer;

    public sealed override CBuffer Buffer
    {
        get => _cBuffer;
        set => _cBuffer = value;
    }

    public MeshBufferGPU(
        CBufferDescriptor desc
    ):base(new MeshBufferInfo(desc))
    {
        _type = desc.type;
        
        Buffer = new CBuffer();
        Buffer.AllocSafely(desc);
    }

    public override int Count => Buffer.Count;

    // Utils
    public static CBufferDescriptor presetMeshBufferDescriptor(
        MeshBufferSource mesh, int meshBufferPresetType)
    {
        return new CBufferDescriptor(
            MeshBufferPreset.GetComputeBufferTypeOf(meshBufferPresetType),
            MeshBufferPreset.GetHlslNameOfType(meshBufferPresetType),
            MeshBufferPreset.GetBufferLength(mesh, meshBufferPresetType),
            MeshBufferPreset.GetStrideOfType(meshBufferPresetType)
        );
    }
    
    
    public CBufferDescriptor GetBufferDescriptor()
    {
        CBufferDescriptor desc = new CBufferDescriptor(
            _type,
            hlslName,
            Count,
            stride
        );
        return desc;
    }
}