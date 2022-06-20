using MPipeline.Custom_Data.BasicDataTypes.Global_Properties;
using MPipeline.Custom_Data.PerMesh_Data;
using Unity.Mathematics;
using UnityEngine;

namespace Assets.MPipeline.Custom_Data.PerMesh_Data
{
    public class MeshDataSrcRT : IRuntimeLDDataSource
    {
        public MeshDataSrcRT(GameObject gameObject, MeshBufferSource meshData, Camera camera)
        {
            GameObject = gameObject;
            MeshData = meshData;
            Camera = camera;
        }

        public GameObject GameObject { get; }
        public MeshBufferSource MeshData { get; }

        public Camera Camera { get; }
    }

    public class MeshUpdateSrc : IRuntimeLDDataUpdate
    {
        public GameObject GameObject { get; }
        public Camera Camera { get; }

        public MeshUpdateSrc(GameObject gameObject, Camera camera)
        {
            GameObject = gameObject;
            Camera = camera;
        }
    }

    public class MeshDataCPURuntime : ILineDrawingDataRuntime<MeshDataSrcRT, MeshUpdateSrc>
    {
        public MatrixProps MatrixProps;
        public VectorProps VectorProps;
        public IntegerProps IntegerProps;

        public bool Loaded
        {
            get => _loaded;
            set => _loaded = value;
        }

        private bool _loaded;

        public MeshDataCPURuntime()
        {
            _loaded = false;
        }

        public void Update(MeshUpdateSrc src)
        {
            UpdateMeshMatrices(src);
            UpdateMeshVectors(src.Camera, src.GameObject);
        }

        public void Init(MeshDataSrcRT src)
        {
            InitMeshMatrices(src);
            InitMeshVectors();
            InitMeshIntegers(src);

            _loaded = true;
        }

        public void Dispose()
        {
            MatrixProps.Dispose();
            VectorProps.Dispose();
            IntegerProps.Dispose();

            _loaded = false;
        }

        // Utilities -------------------------------------------------
        private void InitMeshMatrices(MeshDataSrcRT meshDataSrcRT)
        {
            GameObject gameObject = meshDataSrcRT.GameObject;
            Camera camera = meshDataSrcRT.Camera;
            
            Matrix4x4 M = GetModelTransformMatrix(gameObject);
            Matrix4x4 V = LineDrawingProps.GetViewTransformMatrix(camera);
            Matrix4x4 P = LineDrawingProps.GetProjectionTransformMatrix(camera);
            Matrix4x4 MVP = P * V * M;
            float4x4 MV = V * M;
            Matrix4x4 MV_IT = ComputeInverseTransposeMVMatrix(MV);

            MatrixProps = new MatrixProps(
                (MatrixProps.Type.M, M),
                (MatrixProps.Type.I_M, M.inverse),
                (MatrixProps.Type.MVP, MVP),
                (MatrixProps.Type.I_MVP, MVP.inverse),
                (MatrixProps.Type.IT_MV, MV_IT),
                (MatrixProps.Type.PRE_MVP, MVP),
                (MatrixProps.Type.PRE_I_MVP, MVP.inverse)
            );
        }

        private void UpdateMeshMatrices(MeshUpdateSrc meshDataSrcRT)
        {
            GameObject gameObject = meshDataSrcRT.GameObject;
            Camera camera = meshDataSrcRT.Camera;
            Matrix4x4 M = GetModelTransformMatrix(gameObject);
            Matrix4x4 V = LineDrawingProps.GetViewTransformMatrix(camera);
            Matrix4x4 P = LineDrawingProps.GetProjectionTransformMatrix(camera);
            Matrix4x4 MVP = P * V * M;
            float4x4 MV = V * M;
            Matrix4x4 MV_IT = ComputeInverseTransposeMVMatrix(MV);

            (int id, Matrix4x4 data) MVP_Prev = MatrixProps[2]; // This is dangerous
            (int id, Matrix4x4 data) MV_Prev = MatrixProps[6];
            MatrixProps.SetGlobalMatricesUnsafe(
                // !!! Note: Be careful about the order that matrix multiplies!!!
                M,     M.inverse,     MVP,                   MVP.inverse, 
                MV_IT, MVP_Prev.data, MVP_Prev.data.inverse
            );
        }

        private static Matrix4x4 ComputeInverseTransposeMVMatrix(float4x4 mv)
        {
            float3x3 mv3X3 = (float3x3)mv;
            mv3X3 = math.transpose(math.inverse(mv3X3));
            Matrix4x4 mvIt = new Matrix4x4(
                new Vector4(mv3X3.c0.x, mv3X3.c0.y, mv3X3.c0.z, 0),
                new Vector4(mv3X3.c1.x, mv3X3.c1.y, mv3X3.c1.z, 0),
                new Vector4(mv3X3.c2.x, mv3X3.c2.y, mv3X3.c2.z, 0),
                new Vector4(0, 0, 0, 1)
            );

            return mvIt;
        }

        public static Matrix4x4 GetModelTransformMatrix(GameObject go)
        {
            // return go.transform.localToWorldMatrix;
            return go.GetComponent<Renderer>().localToWorldMatrix;
        }

        private void InitMeshVectors()
        {
            VectorProps = new VectorProps(
                new[]
                {
                    new PropDescriptor(
                        "Camera",
                        ObjectNaming.Vector.Usages.Position,
                        ObjectNaming.Space.Object),
                },
                new[]
                {
                    // Camera pos in object space initialized as 0
                    Vector4.zero
                }
            );
        }

        private void UpdateMeshVectors(Camera cam, GameObject go)
        {
            Vector4 camPos = LineDrawingProps.GetCameraPosWS(cam);
            camPos = GetModelTransformMatrix(go).inverse * camPos; // WS => OS => normalize
            VectorProps.UpdatePropsAll(new[] {camPos});
        }

        private void InitMeshIntegers(MeshDataSrcRT dataSrcRT)
        {
            MeshBufferSource myMesh = dataSrcRT.MeshData;
            
            PropDescriptor[] descs = {
                new PropDescriptor(
                    "Triangle", ObjectNaming.Scalar.Usage.Count),
                new PropDescriptor(
                    "Vertex", ObjectNaming.Scalar.Usage.Count),
                new PropDescriptor(
                    "NonConcaveEdge", ObjectNaming.Scalar.Usage.Count),
                new PropDescriptor(
                    "NormalEdge", ObjectNaming.Scalar.Usage.Count),
            };

            int[] values = {
                myMesh.TriangleCount,
                myMesh.VertexCount,
                myMesh.NumNonConcaveEdges,
                myMesh.NumNormalEdges
            };
            
            IntegerProps = new IntegerProps(descs, values);
        }
    }
}