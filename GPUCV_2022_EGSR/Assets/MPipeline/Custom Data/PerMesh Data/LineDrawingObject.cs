using System.Collections.Generic;
using Assets.MPipeline.Custom_Data.PerMesh_Data;
using Sirenix.OdinInspector;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

namespace MPipeline.Custom_Data.PerMesh_Data
{
    public class LineDrawingObject : MonoBehaviour
    {
        // Object rotation for testing strokes' temporal coherence
        [LabelText("X轴旋转速度")]
        [PropertyRange(0f, 0.5f)] public float RotateX = .0f;
        [LabelText("Y轴旋转速度")]
        [PropertyRange(0f, 1.0f)] public float RotateY = .0f;
        [LabelText("Z轴旋转速度")]
        [PropertyRange(0f, 0.5f)] public float RotateZ = .0f;

        [LabelText("X轴移动速度")]
        [PropertyRange(-0.05f, 0.05f)] public float TranslateX = .0f;
        [LabelText("Y轴移动速度")]
        [PropertyRange(-0.01f, 0.01f)] public float TranslateY = .0f;
        [LabelText("Z轴移动速度")]
        [PropertyRange(-0.5f, 0.5f)] public float TranslateZ = .0f;
        
        [LabelText("运动周期")]
        [PropertyRange(1000f, 10000f)] public float Period = 1000f;


        ///-////////////////////////////////----------------------------------
        // Cameras that should render this LDO
        private List<Camera> _cameras = new List<Camera>();

        // LDMs bond with cameras
        private readonly List<LineDrawingMaster> _ldmList =
            new List<LineDrawingMaster>();

        /// Mesh Data ////////////////////------------------------------------
        // Accessors for basic mesh properties
        public int TriangleCount => meshBufferSrc.TriangleCount;
        public int VertexCount => meshBufferSrc.VertexCount;

        // ---------------------------------//
        // Cached mesh data, as data source
        // for both *CPU & GPU* sides.
        public MeshBufferSource meshBufferSrc;

        // ---------------------------------//
        // Scriptable Object on *CPU* side. //
        private MeshDataCPURuntime _meshDataCpuRuntime;
        private MeshDataCPUPreload _meshDataCpuPreload;

        // ---------------------------------//
        // Scriptable Object on *GPU* side. //
        public MeshDataGPU meshDataGPU; // GPU Side

        public void Awake()
        {
            // Check/bind camera(s) --------------------------------------
            // Have any camera in list?
            if (_cameras.Count == 0)
            {
                Camera firstCamInScene = (Camera) FindObjectsOfType(typeof(Camera))[0];
                _cameras.Add(firstCamInScene);
            }


            // Init & Load  mesh data on CPU side ------------------------------
            Mesh inputMesh;
            
            bool isSkinned = !(gameObject.TryGetComponent(out MeshFilter meshFilter));

            if (isSkinned)
            {
                gameObject.TryGetComponent(out SkinnedMeshRenderer skinnedMeshRenderer);
                inputMesh = skinnedMeshRenderer.sharedMesh;
            }
            else
            {
                inputMesh = meshFilter.sharedMesh;
            }
            
            
            // 1) Check/Init pre-loaded data ----------
            if (meshBufferSrc == null)
            {
                meshBufferSrc =
                    PerMeshDataPreloadFactory.CreateData<MeshBufferSource>(
                        new MeshDataSrcPreload(inputMesh));
            }

            if (_meshDataCpuPreload == null)
            {
                _meshDataCpuPreload =
                    PerMeshDataPreloadFactory.CreateData<MeshDataCPUPreload>(
                        new MeshDataCPUSrc(inputMesh, meshBufferSrc));
            }

            if (!_meshDataCpuPreload.Loaded)
            {
                _meshDataCpuPreload.Load(new MeshDataCPUSrc(inputMesh, meshBufferSrc));
            }

            // 2) Init runtime data -------------------
            _meshDataCpuRuntime =
                PerMeshDataRuntimeFactory.CreateData<MeshDataCPURuntime>(
                    new MeshDataSrcRT(gameObject, meshBufferSrc, _cameras[0])
                );


            // Init & Load  mesh data on GPU side ------------------------------
            if (null == meshDataGPU)
            {
                meshDataGPU = ScriptableObject.CreateInstance<MeshDataGPU>();
            }

            meshDataGPU.Load(gameObject, meshBufferSrc);


            // Register itself to LDM mesh pool -------------------------------
            foreach (Camera cam in _cameras)
            {
                LineDrawingMaster ldm = 
                    PerCameraDataFactory.GetOrCreateSingleton<LineDrawingMaster>(cam);

                ldm.Add(this);
                _ldmList.Add(ldm); // Store reference to this LDM in a list.
            }

            // Register event / delegates
            ContourExtractionPass.UpdatePerMeshData +=
                (cam, cmd) => OnUpdatePerMeshData_ContourExtraction(cam, cmd);
        }

        public void OnDestroy()
        {
            _meshDataCpuRuntime.Dispose();
            meshDataGPU.ReleaseBuffers();
            ContourExtractionPass.UpdatePerMeshData -=
                (cam, cmd) => OnUpdatePerMeshData_ContourExtraction(cam, cmd);
        }

        public void OnDisable()
        {
            // Releasing CBuffers
            _meshDataCpuRuntime.Dispose();
            meshDataGPU.ReleaseBuffers();

            // Remove from LDMs
            foreach (LineDrawingMaster ldm in _ldmList)
            {
                if (ldm != null)
                {
                    ldm.Remove(this);
                }

                // Output log info
                Debug.Log(
                    gameObject +
                    " cancelled registrition as LineDrawingObject from LineDrawingMaster."
                );
            }
        }
       
        private float _currFrame = 0;

        public void Update()
        {
            // Rotation
            float turnaround = math.sin(2.0f * math.PI * (_currFrame / Period));
            gameObject.transform.Rotate(
                RotateX * turnaround
                , RotateY * turnaround
                , RotateZ * turnaround
                , Space.Self
            );
            gameObject.transform.Translate(
                new Vector3(
                    turnaround * TranslateX,
                    turnaround * TranslateY,
                    turnaround * TranslateZ
                ),
                Space.World
            );
            ++_currFrame;
        }
        
        private void OnUpdatePerMeshData_ContourExtraction(
            Camera cam,
            CommandBuffer cmd
        )
        {
            // Check if this mesh is bond with camera
            if (!_cameras.Contains(cam))
            {
                return;
            }

            // -----------------------------------------
            // First time this delegate is called,
            // load data form CPU into GPU.
            // Check if Per-Mesh Buffers have been initialized.
            if (!meshDataGPU.LoadedDeprecated)
            {
                // If not, setup these buffers.
                #region Load mesh data to compute buffers (VRAM <<< RAM)

                meshDataGPU.LoadMeshBuffersCommand(
                    _meshDataCpuPreload, cmd
                );

                #endregion
            }

            // update runtime data
            MeshUpdateSrc meshUpdateSrc = new MeshUpdateSrc(gameObject, cam);
            _meshDataCpuRuntime.Update(meshUpdateSrc);
        }

        //-//////////////////////////////////////////////////////////////////////////-//
        //                               Data Streaming                               //
        //-//////////////////////////////////////////////////////////////////////////-//
        public void BindMeshVectorsWith(CommandBuffer command, ComputeShader cs)
        {
            _meshDataCpuRuntime.VectorProps.BindPropsAllCommand(command, cs);
        }

        public void BindMeshMatricesWith(CommandBuffer command, ComputeShader cs)
        {
            _meshDataCpuRuntime.MatrixProps.BindPropsAllCommand(command, cs);
        }

        public void BindMeshVectorsWith(MaterialPropertyBlock matProps)
        {
            _meshDataCpuRuntime.VectorProps.BindPropsAllCommand(matProps);
        }

        public void BindMeshMatricesWith(MaterialPropertyBlock propsBlock)
        {
            _meshDataCpuRuntime.MatrixProps.BindPropsAllCommand(propsBlock);
        }

        public void BindMeshConstantWith(CommandBuffer command, ComputeShader cs)
        {
            _meshDataCpuRuntime.IntegerProps.BindPropsAllCommand(command, cs);
        }

        public void BindMeshConstantWith(MaterialPropertyBlock matProps)
        {
            _meshDataCpuRuntime.IntegerProps.BindPropsAllCommand(matProps);
        }
    }
}