using MPipeline.Custom_Data.PerMesh_Data;
using Sirenix.OdinInspector;
using UnityEngine;

namespace Assets.MPipeline.Custom_Data.PerMesh_Data
{
    public interface ILineDrawingData
    {
        bool Loaded { get; set; }
    }

    public interface ILineDrawingDataPreLoad<in TDataSource> : ILineDrawingData
    {
        void Load(TDataSource src);
    }

    public interface ILineDrawingDataRuntime<in TDataSource, in TDataUpdate> : ILineDrawingData
        where TDataSource : IRuntimeLDDataSource
        where TDataUpdate : IRuntimeLDDataUpdate
    {
        void Update(TDataUpdate src);
        void Init(TDataSource src);
    }

    public interface IPreloadLDDataSource
    {
    }

    public interface IRuntimeLDDataSource
    {
        GameObject GameObject { get; }
    }

    public interface IRuntimeLDDataUpdate
    {
    }

    public abstract class LDDataRuntimeFactory<TDataSrc>
        where TDataSrc : IRuntimeLDDataSource { }

    public abstract class PerMeshDataRuntimeFactory : 
        LDDataRuntimeFactory<MeshDataSrcRT>
    {
        public static TProduct CreateData<TProduct>(MeshDataSrcRT dataSrc)
        where TProduct: ILineDrawingDataRuntime<MeshDataSrcRT, MeshUpdateSrc>, new()
        {
            TProduct data = new TProduct();
            data.Init(dataSrc);
            data.Loaded = true;
            return data;
        }
    }
    
    public abstract class LDDataPreloadFactory<TDataSrc>
        where TDataSrc : IPreloadLDDataSource { }

    public abstract class PerMeshDataPreloadFactory : 
        LDDataPreloadFactory<MeshDataSrcPreload>
    {
        public static TProduct CreateData<TProduct>(MeshDataSrcPreload dataSrc)
            where TProduct: ScriptableObject, ILineDrawingDataPreLoad<MeshDataSrcPreload>, new()
        {
            TProduct data = ScriptableObject.CreateInstance<TProduct>();
            data.Load(dataSrc);
            data.Loaded = true;
            
            return data;
        }
    }

    public abstract class PerMeshData : ScriptableObject
    {
        // Flags ---------------------------------------
        protected bool initializedDeprecated = false;

        protected bool loadedDeprecated = false;

        public bool LoadedDeprecated => loadedDeprecated;

        public bool InitializedDeprecated => initializedDeprecated;

        // Lifecycle Management ------------------------
        public virtual void PreloadMeshData(MeshBufferSource myMesh)
        {
            if (mesh == null && (myMesh == null || myMesh.mesh == null) )
            {
                // This means that we are in editor mode,
                // or the input mesh is found as null in runtime.
                Debug.LogError("Error: Invalid Mesh: Mesh is empty.\n");
                return;
            }

            if (mesh != null && myMesh.mesh != null)
            {
                Debug.LogWarning("Warning: Old mesh will be replaced.\n");
            }

            // In editor mode, myMesh is null. So we need to check this
            mesh = myMesh == null ? mesh : myMesh.mesh;
        }


        public virtual void Init(GameObject go, MeshBufferSource myMesh)
        {
            // Assign Properties
            PreloadMeshData(myMesh);
        }


        // Basic Mesh Data ---------------------------------------------------
        [BoxGroup("Box0", false)]
        [TitleGroup("Box0/Source Mesh", null, TitleAlignments.Centered)]
        [PreviewField(75, Sirenix.OdinInspector.ObjectFieldAlignment.Center)]
        [InlineEditor(InlineEditorModes.LargePreview)]
        public Mesh mesh;
    }
}