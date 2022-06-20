using System.Collections.Generic;
using System.Linq;
using Assets.MPipeline.DebugTools;
using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.Custom_Data.PerCameraData;
using MPipeline.Custom_Data.PerMesh_Data;
using MPipeline.SRP_Assets.Passes;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// LDM(LineDrawingMaster)  
/// Per-Camera-Singleton for registering all objects to be drawn.   
/// Also responsible to spawn other monobehaviours that needed in this camera 
/// for line drawing renderer.
/// <para>
/// If one LDM(LineDrawingMaster) is found binded with a camera,    
/// then one can be sure that other resources have also been created.
/// </para>
/// </summary>
public class LineDrawingMaster : MonoBehaviour, ILineDrawingData
{
    //-//////////////////////////////////////////////////////////////////////////-//
    //                              Per-Camera singleton                          //
    //-//////////////////////////////////////////////////////////////////////////-//
    // -----------------------------------------------------------------------------
    // Set of objects to be drawn into buffer
    public bool isMeshPoolFullFilled = false;
    public bool isPerCameraDataReady = false;

    public int numLDOsInScene = 0;
    public HashSet<LineDrawingObject> objectPool;

    public LineDrawingObject ldosBatched;
    private GameObject batchedMesh;

    // ---------------------------------------------------------------------------
    // Events

    public void Init(Camera cam)
    {
        if (objectPool == null)
        {
            objectPool = new HashSet<LineDrawingObject>();
        }

        // (#LDOs in scene)
        numLDOsInScene = FindObjectsOfType<LineDrawingObject>().Length;

        gameObject.TryGetComponent(out Material _);

        // Spawn all other resources in a serialized fashion.
        PerCameraDataFactory.TryCreateSingleton
        (
            cam, out LineDrawingBuffers buffers
        );
        PerCameraDataFactory.TryCreateSingleton
        (
            cam, out LineDrawingTextures textures
        );
        PerCameraDataFactory.TryCreateSingleton
        (
            cam, out LineDrawingProps cameraParams
        );
        PerCameraDataFactory.TryCreateSingleton(
            cam, out LineDrawingControlPanel controlPanel
        );

        isPerCameraDataReady = true;
    }

    private void CombineMeshes()
    {
        batchedMesh = new GameObject("Combined Mesh");
        
        GameObject go = batchedMesh;
        Vector3 goPos = go.transform.position;
        Quaternion goRot = go.transform.rotation;
        go.transform.position = Vector3.zero;
        go.transform.rotation = quaternion.identity;

        List<CombineInstance> combInstances = new List<CombineInstance>();
        foreach (LineDrawingObject ldo in objectPool)
        {
            combInstances.Add(
                new CombineInstance
                {
                    mesh = ldo.meshBufferSrc.mesh,
                }
            );
        }

        MeshFilter meshFilter = go.AddComponent<MeshFilter>();
        meshFilter.mesh = new Mesh();
        meshFilter.sharedMesh.indexFormat = IndexFormat.UInt32;
        meshFilter.mesh.CombineMeshes(
            combInstances.ToArray(),
            true,
            false // Don't even try this, this is suspicious as hell
        );
        go.transform.position = objectPool.ElementAt(0).transform.position;
        go.transform.rotation = objectPool.ElementAt(0).transform.rotation;
        go.transform.localScale = objectPool.ElementAt(0).transform.localScale;

        MeshRenderer meshRenderer = go.AddComponent<MeshRenderer>();
        meshRenderer.material = LineDrawingMaterials.PaperlikeMaterial();

        // Register batched mesh as line-drawing object
        ldosBatched = go.AddComponent<LineDrawingObject>();

        // Rotate this model for experimenting Temporal-Coherent techniques
        ldosBatched.TranslateX = objectPool.First().TranslateX;
        ldosBatched.TranslateZ = objectPool.First().TranslateZ;
        ldosBatched.RotateY = objectPool.First().RotateY;
        ldosBatched.Period = objectPool.First().Period;
    }

    public void Add(LineDrawingObject o)
    {
        Remove(o); // Clear previous record
        objectPool.Add(o);

        // Combine meshes after all ldo finished it's registration
        if (objectPool.Count == numLDOsInScene)
        {
            // CombineMeshes();
            ldosBatched = objectPool.First();
            isMeshPoolFullFilled = true;
        }
    }

    public void Remove(LineDrawingObject o)
    {
        objectPool.Remove(o);
    }
}