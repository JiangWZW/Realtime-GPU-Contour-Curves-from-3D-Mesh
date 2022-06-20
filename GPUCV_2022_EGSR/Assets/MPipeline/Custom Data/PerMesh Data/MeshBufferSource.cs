using System;
using MPipeline.Custom_Data.PerMesh_Data;
using MPipeline.GeometryProcessing;
using Sirenix.OdinInspector;
using Unity.Mathematics;
using UnityEngine;

namespace Assets.MPipeline.Custom_Data.PerMesh_Data
{
    [CreateAssetMenu(fileName = "MeshDataSource.asset", menuName = "LDPipeline Data/Mesh/MeshBufferSource", order = 1)]
    public class MeshBufferSource : ScriptableObject, ILineDrawingDataPreLoad<MeshDataSrcPreload>
    {
        public Mesh mesh;

        [BoxGroup("All")]
        [TitleGroup("All/Mesh Data", null, TitleAlignments.Centered)]
        [BoxGroup("All/Mesh Data/Vertex Buffers")]
        [BoxGroup("All/Mesh Data/Vertex Buffers/Vert Position", false)]
        [ReadOnly]
        public float3[] vertexPosition = null;

        [BoxGroup("All/Mesh Data/Vertex Buffers/Vert Normal", false)] [ReadOnly]
        public float3[] vertexNormal = null;

        [BoxGroup("All/Mesh Data/Vertex Buffers/Vert Edges", false)] [ReadOnly]
        public int[] vertexEdges = null;

        [BoxGroup("All/Mesh Data/Face Buffers")]
        [BoxGroup("All/Mesh Data/Face Buffers/Triangle Verts", false)]
        [ReadOnly]
        public int[] triangleVerts = null;

        [BoxGroup("All/Mesh Data/Face Buffers/Triangle Normal", false)] [ReadOnly]
        public float4[] triangleNormal = null;

        [BoxGroup("All/Mesh Data/Face Buffers/Triangle Adjacency", false)] [ReadOnly]
        public int[] triangleTriangles = null;

        [BoxGroup("All/Mesh Data/Edge Buffers")] [BoxGroup("All/Mesh Data/Edge Buffers/Edge Verts", false)] [ReadOnly]
        public int[] edgeVerts = null;

        [BoxGroup("All/Mesh Data/Edge Buffers/Edge Triangles", false)] [ReadOnly]
        public int[] edgeTriangles = null;

        public int VertexCount => vertexPosition.Length;
        public int TriangleListSize => triangleVerts.Length;
        public int TriangleCount => TriangleListSize / 3;
        public int EdgeCount => edgeVerts.Length / 2;

        public int NumEdges => NumNonConcaveEdges + NumConcaveEdges;
        public int NumNonConcaveEdges => NumNormalEdges + NumBoundaryEdges;
        
        // Convex, Non-boundary, or to say, 2-Manifold Edges
        public int NumNormalEdges => numNormalEdges;

        public int NumConcaveEdges => numConcaveEdges;
        public int NumBoundaryEdges => numBoundaryEdges;
        public int NumSingularEdges => numSingularEdges;

        [SerializeField] [ReadOnly] private int numNormalEdges;
        [SerializeField] [ReadOnly] private int numConcaveEdges;
        [SerializeField] [ReadOnly] private int numBoundaryEdges;
        [SerializeField] [ReadOnly] private int numSingularEdges;
        [SerializeField] [ReadOnly] private int maxVertexValence;

        [TitleGroup("Mesh Analysis", null, TitleAlignments.Centered, true)]
        [GUIColor("@MyGuiColors.MorandiLightBlue()")]
        [Button("Extract Data", ButtonSizes.Medium, ButtonStyle.CompactBox)]
        public void Load()
        {
            if (mesh == null)
            {
                Debug.LogError("Null mesh ref, exit");
                return;
            }

            Load(new MeshDataSrcPreload(mesh));

            Debug.Log("Mesh buffers extracted successfully.");
        }

        public void Load(MeshDataSrcPreload src)
        {
            mesh = src.Mesh;
            if (mesh == null)
            {
                Debug.LogError("null mesh input");
                return;
            }
            
            // Note: make sure that lists initialize in 
            // the correct order.
            // ----------------------------------------
            InitVpList(mesh);
            InitVnList(mesh);

            InitTvList(mesh);
            InitTnList();

            InitEdgeBuffers();

            InitVEList();
        }


        // Utilities ----------------------------------------------------------
        private void InitTnList()
        {
            if (triangleVerts == null)
            {
                Debug.LogError("Null tvlist.");
                return;
            }

            if (vertexPosition == null)
            {
                Debug.LogError("Null vpList.");
                return;
            }

            triangleNormal = TriMeshProcessor.GetTriangleNormalList(triangleVerts, vertexPosition).ToArray();
        }

        private void InitEdgeBuffers()
        {
            TriMeshProcessor.ExtractEdgeBuffers(
                // inputs <==
                vertexPosition,
                triangleVerts,
                triangleNormal,
                // ==> output params
                out numNormalEdges,
                out numConcaveEdges,
                out numBoundaryEdges,
                out numSingularEdges,
                // ==> output buffers
                out edgeVerts,
                out edgeTriangles,
                true);
        }

        private void InitVpList(Mesh mesh)
        {
            Vector3[] vpCopy = mesh.vertices;
            vertexPosition = Array.ConvertAll(
                vpCopy,
                srcVal => (float3) srcVal
            );
        }

        private void InitVnList(Mesh mesh)
        {
            Vector3[] vnCopy = mesh.normals;
            vertexNormal = Array.ConvertAll(
                vnCopy,
                srcVal => (float3) srcVal
            );
        }

        private void InitVEList()
        {
            vertexEdges = TriMeshProcessor.GetVertexAdjEdgeList(edgeVerts, VertexCount, out maxVertexValence);
        }

        private void InitTvList(Mesh mesh)
        {
            triangleVerts = mesh.triangles;
            // Note: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            // TODO: this function leaves some isolated verts,
            // TODO: might have some side effects for later mesh ops,
            // TODO: which needs further investigation
            TriMeshProcessor.MergeVertsOnUVBoundary(ref triangleVerts, vertexPosition);
        }

        public bool Loaded { get; set; }
    }
}