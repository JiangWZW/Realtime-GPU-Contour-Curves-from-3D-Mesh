using System.Collections.Generic;
using System.Linq;
// using Sirenix.Utilities;
// using Sirenix.Utilities;
using Unity.Mathematics;
using UnityEngine;

namespace MPipeline.GeometryProcessing
{
    public static class TriMeshProcessor
    {
        /// <summary>
        /// "Welds" uv boundary of mesh
        /// </summary>
        /// <param name="tvList"></param>
        /// <param name="vpList"></param>
        /// <param name="errorBound"></param>
        /// <returns></returns>
        public static bool MergeVertsOnUVBoundary(
            ref int[] tvList, float3[] vpList, float errorBound = 0.00000001f)
        {
            int vertCount = vpList.Length;
            int faceCount = tvList.Length / 3;

            // Utility arrays
            // --------------------------------------------------
            // Sort changes vertex order,
            // so we cache authentic vertex index (vertId) 
            List<(float3 point, int vertId)> vpListSorted =
                new List<(float3 point, int vertId)>();
            // MergeWith[vertId] := for vert#vertId,
            // which vertex it merges to.
            List<int> MergeWith = new List<int>();
            // Init these arrays
            for (int vertId = 0; vertId < vertCount; vertId++)
            {
                // vpListSorted[i] = (vert position, vert id)
                vpListSorted.Add((vpList[vertId], vertId));
                // MergeWith[i] = i
                MergeWith.Add(vertId);
            }

            // Sort by x coord
            vpListSorted.Sort(
                (v0, v1) => v0.point.x.CompareTo(v1.point.x));


            // Start searching for verts with same position
            // so that we can merge them later.
            // -------------------------------------------------
            for (int i = 0; i < vertCount; i++)
            {
                int ithVert = vpListSorted[i].vertId;
                bool isIMerged = MergeWith[ithVert] != ithVert;

                float3 srcVertPos = vpListSorted[i].point;
                bool3 compRes = new bool3(true, true, true);

                // When to start a search --------------------------------
                // j < vertexCount --- inside range of array
                // !isMerged --- the one with Least Index than others
                // compRes.x --- inside the chunk of pos.x == srcVertPos.x
                for (int j = i + 1; j < vertCount && (!isIMerged) && compRes.x; j++)
                {
                    float3 compVertPos = vpListSorted[j].point;
                    // vert#vertId & vert#compVertId have same position?
                    compRes = srcVertPos == compVertPos;
                    if (compRes.x && compRes.y && compRes.z)
                    {
                        int jthVert = vpListSorted[j].vertId;
                        // Among a batch of verts with same position,
                        // only the one with LEAST INDEX has right to merge others.
                        // ("least index" under the context of sorted array)
                        bool isJMerged = MergeWith[jthVert] != jthVert;
                        MergeWith[jthVert] = isJMerged ? MergeWith[jthVert] : ithVert;
                    }
                }
            }

            // Now we now for arbitrary vert#i, what should we do:
            // 1) Dont merge (MergeWith[i] == i)
            // 2) Merge with MergeWith[i] (!= i)
            for (int face = 0; face < faceCount; face++)
            {
                int[] verts = GetTriangleVerts(face, tvList);
                if (verts.Length != 3)
                {
                    Debug.LogError("Wrong number of verts in a triangle: " +
                                   verts.Length + ".");
                }

                for (int vOffset = 0; vOffset < 3; vOffset++)
                {
                    tvList[face * 3 + vOffset] = MergeWith[verts[vOffset]];
                }
            }

            return true;
        }

        public static int[] GetVertexAdjEdgeList(int[] evList, int numVerts, out int maxValence)
        {
            int edgeCount = evList.Length / 2;

            Dictionary<int, List<int>> vertToFaces = new Dictionary<int, List<int>>();
            for (int vertId = 0; vertId < numVerts; vertId++)
            {
                // Initial state: vert==>adj_edge_list(empty)
                vertToFaces.Add(vertId, new List<int>());
            }

            for (int edgeId = 0; edgeId < edgeCount; edgeId++)
            {
                int v0 = evList[edgeId * 2];
                vertToFaces.TryGetValue(v0, out List<int> veList0);
                Debug.Assert(veList0 != null, nameof(veList0) + " != null");
                veList0.Add(edgeId);

                int v1 = evList[edgeId * 2 + 1];
                vertToFaces.TryGetValue(v1, out List<int> veList1);
                Debug.Assert(veList1 != null, nameof(veList1) + " != null");
                veList1.Add(edgeId);
            }
            // Now we have
            // vert==>adj_edge_list[edge0->edge1->]......
            
            int startPos = numVerts + 1;
            // CSR Layout of VE-List: //////////////////////////
            // Brief:
            // first #numVerts + 1 elems are starting ids
            // later elems: vert-edge adjacency in CSR format
            // (CSR: Compressed-Sparse-Matrix)
            // --------------------------------------------------
            // e.g:    0     startPosInCSR: 
            //       / |\    [0, 3, 5, 7,*10*] + numVerts + 1(5)
            //     /  |  \   adjEdgesCSR: 
            //   /   |    \ |<--0 -->|<-1 ->|<-2->|<- 3 ->|
            // 1 --- 3 --- 2 [1, 3, 2, 0, 3, 0, 3, 0, 1, 2]
            // _______________0________3_____5_____7_______*10*
            // ==> Final result == [startPosInCSR | adjEdgesCSR]
            // _0__1__2___3____4____5__6__7__8__9__10_11_12_13_14
            // [5, 8, 10, 12, *15*, 1, 3, 2, 0, 3, 0, 3, 0, 1, 2]
            // |<==  Start Idx  ==>|<--0 -->|<-1->|<-2->|<- 3 ->|
            // ____________________|<==  Adj. Edges of Verts ==>|
            //-///////////////////////////////////////////////////
            maxValence = 0;
            List<int> startPosInCSR = new List<int>();
            List<int> adjEdgesCSR = new List<int>();
            for (int vert = 0; vert < numVerts; vert++)
            {
                vertToFaces.TryGetValue(vert, out List<int> adjEdges);
                Debug.Assert(adjEdges != null, nameof(adjEdges) + " != null");
                // Where the adj-edge-list of this vert starts
                startPosInCSR.Add(startPos);
                // Append adj list of this vert
                adjEdgesCSR.AddRange(adjEdges);
                // Offset by #adj_edges
                startPos += adjEdges.Count;

                maxValence = math.max(maxValence, adjEdges.Count);
            }
            // One more elem, 'cause otherwise we need to check
            // if current vertex is the last vertex,
            // which can cause branches on GPU side...
            startPosInCSR.Add(startPos);

            startPosInCSR.AddRange(adjEdgesCSR);
            
            // Unit Testing
            int baseOffset = numVerts;
            for (int v = 0; v < numVerts; ++v)
            {
                // [start, end)
                int start = startPosInCSR[v];
                int end = startPosInCSR[v + 1];
                for (int i = start; i < end; i++)
                {
                    int edgeIdx = startPosInCSR[i];
                    int v0 = evList[edgeIdx * 2];
                    int v1 = evList[edgeIdx * 2 + 1];
                    if (v0 != v && v1 != v)
                    {
                        // Inconsistent adjacency
                        Debug.LogError("Incorrect VEList data.");
                    }
                }
            }

            return startPosInCSR.ToArray();
        }

        public static List<float4> GetTriangleNormalList(int[] tvList, float3[] vpList)
        {
            List<float4> tnList = new List<float4>();
            int triCount = tvList.Length / 3;
            for (int triangle = 0; triangle < triCount; triangle++)
            {
                int begIdx = triangle * 3;
                int[] verts =
                {
                    tvList[begIdx], tvList[++begIdx], tvList[++begIdx]
                };
                // Winding Order Matters,
                // See https://docs.unity3d.com/Manual/ComputingNormalPerpendicularVector.html
                // and https://docs.unity3d.com/Manual/UsingtheMeshClass.html
                float3 edgeVec01 = vpList[verts[1]] - vpList[verts[0]];
                float3 edgeVec02 = vpList[verts[2]] - vpList[verts[0]];

                float3 normal = math.normalizesafe(math.cross(edgeVec02, edgeVec01));
                tnList.Add(new float4(normal, 0.0f));
            }

            return tnList;
        }

        private static int[] GetTriangleVerts(int triangleId, int[] tvList)
        {
            int startVert = triangleId * 3;
            return new[]
            {
                tvList[startVert],
                tvList[++startVert],
                tvList[++startVert]
            };
        }

        private static List<(int, int)> GetEdgesWithSortedVerts(int startVert, int[] tvList)
        {
            // tvList[0 1 2, 3 4 5,...]
            // e.g 2 3 5, 7 5 3
            List<int> triagVerts = new List<int>
            {
                tvList[startVert], tvList[++startVert], tvList[++startVert]
            };
            triagVerts.Sort();
            // => 2 3 5, 3 5 7

            List<(int, int)> edges = new List<(int, int)>
            {
                (triagVerts[0], triagVerts[1]), // (2, 3) 
                (triagVerts[0], triagVerts[2]), // (2, 5)
                (triagVerts[1], triagVerts[2]) // (3, 5)
            };

            return edges;
        }

        /// <summary>
        /// Extracts edge vertex list, 2 verts in same edge are sorted by
        /// their vertex index value.
        /// </summary>
        /// <param name="tvList"></param>
        /// <returns></returns>
        private static List<(int v0, int v1)> GetEdgeList(int[] tvList)
        {
            HashSet<(int, int)> edgeList = new HashSet<(int, int)>();
            int triCount = tvList.Length / 3;
            for (int triangle = 0; triangle < triCount; triangle++)
            {
                int vertex = triangle * 3;
                List<(int, int)> edgesInTriag = GetEdgesWithSortedVerts(vertex, tvList);

                foreach ((int, int) edge in edgesInTriag)
                {
                    if (!edgeList.Contains(edge))
                    {
                        edgeList.Add(edge);
                    }
                }
            }

            return edgeList.ToList();
        }

        private static int[] GetEdgeVertexList(int[] tvList)
        {
            List<int> output = new List<int>();

            // (int, int) to flattened int array
            List<(int v0, int v1)> edgeList = GetEdgeList(tvList);
            for (int edgeIdx = 0; edgeIdx < edgeList.Count; edgeIdx++)
            {
                (int v0, int v1) = edgeList[edgeIdx];
                output.Add(math.min(v0, v1));
                output.Add(math.max(v0, v1));
            }

            return output.ToArray();
        }


        public static void ExtractEdgeBuffers(
            // inputs <==
            float3[] vpList,
            int[] tvList,
            float4[] tnList,
            // ==> output params
            out int numNormalEdges,
            out int numConcaveEdges,
            out int numBoundaryEdges,
            out int numSingularEdges,
            // ==> output buffers
            out int[] evListShuffled,
            out int[] etListShuffled,
            bool debugMode = false)
        {
            // Edge Mapping ------------------------------------------------------
            // 0 ==> ............................................ ==> n - 1
            // [internal & convex edges], [concave edges], [boundary edges]
            List<int> edgeIdxMap = new List<int>(); // arr[index] = original_index
            // temp containers for different edges
            List<int> boundaryEdges = new List<int>();
            List<int> concaveEdges = new List<int>();
            List<int> singularEdges = new List<int>();
            numBoundaryEdges = numConcaveEdges = numNormalEdges = -1;


            // Utility structures ------------------------------------------------------- 
            // --- Edge List
            int[] evList = GetEdgeVertexList(tvList); // needed for getting adj faces <==
            int edgeCount = evList.Length / 2;
            evListShuffled = new int[edgeCount * 2]; // edge list after shuffle ==>

            // --- Adjacency list <#edge, List of[faces adj. to #edge]>
            List<List<int>> adjFacesList = GetEdgeAdjTriangleList(evList, tvList);

            // -- Edge Triangle List
            int[] etList = new int[edgeCount * 2];
            for (int edge = 0; edge < edgeCount; edge++)
            {
                List<int> adjFaces = adjFacesList[edge];
                int idx = 0;
                for (; idx < adjFaces.Count && idx < 2; idx++)
                {
                    etList[edge * 2 + idx] = adjFaces[idx];
                }

                for (; idx < 2; idx++)
                {
                    // For boundary edges, we add max integer as dummy triangle
                    etList[edge * 2 + idx] = int.MaxValue;
                }
            }

            etListShuffled = new int[edgeCount * 2]; // edge triangles after shuffle


            // Iterate over edges ----------------------------------------------
            for (int edgeIdx = 0; edgeIdx < edgeCount; edgeIdx++)
            {
                List<int> currentEdgeAdjFaces = adjFacesList[edgeIdx];

                switch (currentEdgeAdjFaces.Count)
                {
                    case 0:
                        // Wireframe Edges are weird, ---------------
                        // send warning about mesh quality issues
                        Debug.LogWarning(
                            "Wireframe edges found when computing edge-face adjacency." +
                            " Check you algorithm & mesh.");

                        singularEdges.Add(edgeIdx);
                        break;

                    case 1:
                        // Boundary edge ---------------------------------
                        boundaryEdges.Add(edgeIdx);
                        break;

                    case 2:
                        // Internal edge ---------------------------------

                        // Convexity Test
                        // ----------------------
                        int face0 = currentEdgeAdjFaces[0];
                        int face1 = currentEdgeAdjFaces[1];

                        List<int[]> vertsInFace = new List<int[]>();
                        vertsInFace.Add(GetTriangleVerts(face0, tvList));
                        vertsInFace.Add(GetTriangleVerts(face1, tvList));
                        int unsharedVertInF0 = 0;
                        for (int i = 0; i < 3; i++)
                        {
                            int vertInF0 = vertsInFace[0][i];
                            bool isSharedVert = false;
                            for (int j = 0; j < 3; j++)
                            {
                                int vertInF1 = vertsInFace[1][j];
                                if (vertInF0 == vertInF1)
                                {
                                    isSharedVert = true;
                                }
                            }

                            if (isSharedVert) continue;
                            unsharedVertInF0 = vertInF0;
                            break;
                        }

                        float3 baryCenterF1 = float3.zero;
                        for (int i = 0; i < 3; i++)
                        {
                            baryCenterF1 += vpList[vertsInFace[1][i]];
                        }

                        baryCenterF1 /= 3.0f;

                        float3 pointInF0 = vpList[unsharedVertInF0];
                        float3 pointInF1 = baryCenterF1;

                        double3 viewVec = math.normalize(pointInF0 - pointInF1);
                        double3 normalF1 = tnList[face1].xyz;

                        double dotVec10N1 = math.dot(viewVec, normalF1);
                        if (dotVec10N1 < 0)
                        {
                            // Concave, angle < 90 degree
                            concaveEdges.Add(edgeIdx);
                        }
                        else
                        {
                            // Convex
                            edgeIdxMap.Add(edgeIdx);
                        }

                        break;

                    default: // Singular edges,
                        // throw them away if you don't want to f**k everything up
                        singularEdges.Add(edgeIdx);
                        Debug.LogWarning(
                            "Singular edge found when constructing degenerated quads." +
                            " Check you algorithm & mesh.");
                        break;
                }
            }

            numNormalEdges = edgeIdxMap.Count;
            numBoundaryEdges = boundaryEdges.Count;
            numConcaveEdges = concaveEdges.Count;
            numSingularEdges = singularEdges.Count;
            // edgeIdxMap already has all normalEdges
            edgeIdxMap.AddRange(boundaryEdges);
            edgeIdxMap.AddRange(concaveEdges);
            edgeIdxMap.AddRange(singularEdges);


            // Shuffle buffer(s) via mapping -------------------------------------------------
            // shuffle evList
            for (int edgeIdxMapped = 0; edgeIdxMapped < edgeIdxMap.Count; edgeIdxMapped++)
            {
                int edgeIdxOriginal = edgeIdxMap[edgeIdxMapped];
                // ==> evList
                evListShuffled[edgeIdxMapped * 2] = evList[edgeIdxOriginal * 2];
                evListShuffled[edgeIdxMapped * 2 + 1] = evList[edgeIdxOriginal * 2 + 1];
                // ==> etList
                etListShuffled[edgeIdxMapped * 2] = etList[edgeIdxOriginal * 2];
                etListShuffled[edgeIdxMapped * 2 + 1] = etList[edgeIdxOriginal * 2 + 1];
            }


            // Test --------------------------------------
            if (debugMode)
            {
                // Same count?
                if ((edgeIdxMap.ToHashSet().Count) != edgeCount)
                {
                    Debug.LogError("Edge count from shuffled edge and original are not equal.\n" +
                                   "before shuffle: #edges = " + evList.Length +
                                   "; after shuffle: #edges in output = " + edgeIdxMap.Count);
                }

                // Same elements in buffers?
                // --- EVList
                HashSet<(int v0, int v1)> before = new HashSet<(int v0, int v1)>();
                HashSet<(int v0, int v1)> after = new HashSet<(int v0, int v1)>();
                for (int i = 0; i < evList.Length; i++)
                {
                    before.Add((evList[i], evList[i + 1]));
                    after.Add((evListShuffled[i], evListShuffled[++i]));
                }

                if (!before.SetEquals(after))
                {
                    Debug.LogError("Inconsistency between shuffled & original EV-list.\n" +
                                   "Check your algorithm for further details.");
                }

                // --- ETList
                before.Clear();
                after.Clear();
                for (int i = 0; i < etList.Length; i++)
                {
                    before.Add((etList[i], etList[i + 1]));
                    after.Add((etListShuffled[i], etListShuffled[++i]));
                }

                if (!before.SetEquals(after))
                {
                    Debug.LogError("Inconsistency between shuffled & original ET-list .\n" +
                                   "Check your algorithm for further details.");
                }

                // Coherence between different buffers ?
            }
        }


        /// <summary>
        /// Generates an triangle adjacency list,
        /// the output list are computed according to following rules:
        /// <list type="bullet">
        /// <item>
        /// <description>
        /// Each edge #i has 2 slots #[2i, 2i + 1] to store their adj faces.
        /// </description>
        /// </item>
        /// <item>
        /// <description>
        /// For edges that have 2 adjacent faces("internal edges"),
        /// the first face has the same vertex order on that edge;
        /// the second face has inverse vert order.
        /// </description>
        /// </item>
        /// <item>
        /// <description>
        /// For edges that have less than 2 adjacent edge(boundary edges),
        /// dummy edges are appended with value of uint.maxvalue.
        /// </description>
        /// </item>
        /// </list>
        /// </summary>
        /// <param name="evList"></param>
        /// <param name="tvList"></param>
        /// <returns></returns>
        private static List<List<int>> GetEdgeAdjTriangleList(int[] evList, int[] tvList)
        {
            List<List<int>> adjFacesList = new List<List<int>>();
            // -- Hash Tables
            Dictionary<(int, int), List<int>> adjFacesOfEdge =
                new Dictionary<(int, int), List<int>>();

            // Init hash table use edge entries in evList
            int evListSize = evList.Length;
            for (int i = 0; i < evListSize; ++i)
            {
                int vert0 = evList[i];
                int vert1 = evList[++i];
                adjFacesOfEdge.Add(
                    // Fixed order for edges by index value (ascending),
                    // in case of duplication edges among adj triangles
                    (math.min(vert0, vert1), math.max(vert0, vert1)),
                    new List<int>() // No triangles registered yet
                );
            }

            // Update hash table using triangle list
            int triangleCount = tvList.Length / 3;
            for (int triangle = 0; triangle < triangleCount; ++triangle)
            {
                List<(int, int)> edgesInTriag =
                    GetEdgesWithSortedVerts(triangle * 3, tvList);
                foreach ((int, int) edge in edgesInTriag)
                {
                    if (!adjFacesOfEdge.ContainsKey(edge))
                    {
                        Debug.LogWarning("Input triangle list doesn't have" +
                                         " edge " + edge + ". Check consistency between" +
                                         "input evList & tvList.");
                        return null; // ==> EXIT Incoherence found between vtList and evList.
                    }

                    // No-duplicate-triangle is guaranteed 'cause
                    // we are iteration each triangle once in this loop.
                    adjFacesOfEdge[edge].Add(triangle);
                }
            }

            // Fill in output list from calculated hash table in previous step
            int edgeCount = evList.Length / 2;
            if (edgeCount != adjFacesOfEdge.Count)
            {
                Debug.LogError("Inconsistent edge count found when generating" +
                               "ET list.");
            }

            for (int edgeIdx = 0; edgeIdx < edgeCount; edgeIdx++)
            {
                (int v0, int v1) edge = EdgeWithSortedVerts(
                    evList[edgeIdx * 2], evList[edgeIdx * 2 + 1]
                ); // Make sure 2 verts in a edge are sorted
                if (!adjFacesOfEdge.ContainsKey(edge))
                {
                    Debug.LogError("Your algorithm is fucked up, check it again weak chicken.");
                    return null;
                }

                // Sort 2 adj faces, the face with same vertex order as on
                // this edge will be put at first
                List<int> adjFaces = adjFacesOfEdge[edge];
                if (adjFaces.Count == 2)
                {
                    bool[] hasSameOrder = {false, false};
                    for (int faceIdLocal = 0; faceIdLocal < 2; faceIdLocal++)
                    {
                        int[] vertsInFace = GetTriangleVerts(adjFaces[faceIdLocal], tvList);
                        for (int i = 0; i < 3; i++)
                        {
                            if (vertsInFace[i] == edge.v0 && vertsInFace[(i + 1) % 3] == edge.v1)
                            {
                                hasSameOrder[faceIdLocal] = true;
                                break;
                            }
                        }
                    }

                    if (hasSameOrder[0] == hasSameOrder[1])
                    {
                        Debug.LogError("Error: Faces share the same edge should have" +
                                       "inverse vertex order on that edge, but algorithm produced" +
                                       "some ill results that have the same vertex order.");
                    }

                    if (hasSameOrder[1])
                    {
                        // Swap position
                        int temp = adjFaces[1];
                        adjFaces[1] = adjFaces[0];
                        adjFaces[0] = temp;
                    }
                }

                adjFacesList.Add(adjFaces);
            }

            return adjFacesList;
        }

        public static List<List<int>> GetTriAdjList(int[] tvList)
        {
            // Containers
            List<List<int>> adjFacesList = new List<List<int>>();
            // --- Hash Tables
            Dictionary<(int, int), List<int>> edgeToTriangles // Triangles adj to each edge
                = new Dictionary<(int, int), List<int>>();
            Dictionary<int, List<(int, int)>> triangleToEdges // Edges adj to each triangle
                = new Dictionary<int, List<(int, int)>>();

            // Build hash tables
            int triangleCount = tvList.Length / 3;
            for (int triangle = 0; triangle < triangleCount; ++triangle)
            {
                int vertex = triangle * 3;
                // => 2 3 5, 3 5 7

                List<(int, int)> edges = GetEdgesWithSortedVerts(vertex, tvList);
                // => (2, 3) (2, 5) (3, 5), || (3, 5) (3, 7) (5, 7)
                // .................------.....------..............

                // Register edge & triangle adjacency
                foreach (var edge in edges)
                {
                    if (edgeToTriangles.ContainsKey(edge))
                    {
                        // We wont have any duplicate triangles, obviously...
                        edgeToTriangles[edge].Add(triangle);
                    }
                    else
                    {
                        edgeToTriangles.Add(edge, new List<int> {triangle});
                    }

                    if (triangleToEdges.ContainsKey(triangle))
                    {
                        triangleToEdges[triangle].Add(edge);
                    }
                    else
                    {
                        triangleToEdges.Add(triangle, new List<(int, int)> {edge});
                    }
                }
            }


            // Use hash tables to get adjacency between triangles
            for (int triangle = 0; triangle < tvList.Length / 3; triangle++)
            {
                HashSet<int> adjFaces = new HashSet<int>();
                List<(int, int)> edges = triangleToEdges[triangle];
                foreach ((int, int) adjEdge in edges)
                {
                    List<int> adjFacesToThisEdge = edgeToTriangles[adjEdge];
                    foreach (int adjFace in adjFacesToThisEdge)
                    {
                        if (adjFaces.Contains(adjFace)) continue;
                        if (adjFace != triangle)
                        {
                            adjFaces.Add(adjFace);
                        }
                    }
                }

                if (adjFaces.Count != 0)
                {
                    adjFacesList.Add(adjFaces.ToList());
                }
                else
                {
                    // Isolated face, add empty list to ensure
                    // "serialized" result.
                    adjFacesList.Add(new List<int>());
                }
            }

            return adjFacesList;
        }

        private static int[] VertsInTriangle(int triangle, int[] tvList)
        {
            int vertBeg = triangle * 3;
            int[] vertsInTriangle =
            {
                tvList[vertBeg],
                tvList[++vertBeg],
                tvList[++vertBeg]
            };

            return vertsInTriangle;
        }

        private static (int, int) EdgeWithSortedVerts(int v0, int v1)
        {
            return (math.min(v0, v1), math.max(v0, v1));
        }

        public static void UnitTestOfGetTriAdjList()
        {
            // Triangle Adjacency Test
            int[] testTVList =
            {
                // a simple cube
                0, 2, 3,
                1, 2, 0,
                7, 1, 0,
                1, 7, 6,
                4, 6, 7,
                4, 5, 6,
                2, 5, 4,
                3, 4, 2,
                1, 5, 2,
                1, 6, 5,
                0, 3, 7,
                4, 7, 3
            };
            List<List<int>> testTTList = GetTriAdjList(testTVList);
            for (var triangle = 0; triangle < testTTList.Count; triangle++)
            {
                List<int> adjacencyList = testTTList[triangle];
                string adjListStr = "";
                adjListStr += "-------------------------------------------\n";
                adjListStr += ("List of triangle #" + triangle + " is: \n");
                adjListStr += "(";
                foreach (int adjFace in adjacencyList)
                {
                    adjListStr += (adjFace + " ");
                }

                Debug.Log(adjListStr + "). \n\n");
            }
        }

        public static bool UintTestOfGetEdgeList(int[] tvList, out string errorMessage)
        {
            bool succeeded = true;
            errorMessage = "";

            List<(int, int)> edgeList = GetEdgeList(tvList);

            // Vertex Order & Duplication test ---------------------------------------
            Dictionary<(int, int), int> dupCount = new Dictionary<(int, int), int>();
            HashSet<(int, int)> edgeHashSet = new HashSet<(int, int)>();
            foreach ((int vlow, int vhigh) edge in edgeList)
            {
                // Order
                if (edge.vhigh < edge.vlow)
                {
                    succeeded = false;
                    errorMessage += "Reversed vertex order found at edge " +
                                    "(" + edge.vlow + edge.vhigh + ").\n";
                }

                // Duplication
                if (!dupCount.ContainsKey(edge))
                {
                    dupCount.Add(edge, 0);
                    edgeHashSet.Add(edge);
                }
                else
                {
                    dupCount[edge] = dupCount[edge] + 1;
                }
            }

            foreach (KeyValuePair<(int, int), int> edgeWithDupCount in dupCount)
            {
                if (edgeWithDupCount.Value > 0)
                {
                    (int vlow, int vhigh) = edgeWithDupCount.Key;
                    succeeded = false;
                    errorMessage += "Edge (" + vlow + vhigh + ") was found" +
                                    " duplicated for " + edgeWithDupCount.Value +
                                    " times.\n";
                }
            }

            // Test data coherency with tvList ------------------------------
            int triangleCount = tvList.Length / 3;
            int edgeCount = edgeList.Count;
            // Check if edgeList covers triangleList
            for (int triangle = 0; triangle < triangleCount; triangle++)
            {
                List<(int, int)> edges = GetEdgesWithSortedVerts(triangle * 3, tvList);
                foreach ((int v0, int v1) edge in edges)
                {
                    if (!edgeHashSet.Contains(edge))
                    {
                        succeeded = false;
                        errorMessage += "Edge " + "(" + edge.v0 + edge.v1 + ")" +
                                        "is supposed to exist in edge list, but" +
                                        "its currently not found during test.\n";
                    }
                }
            }

            // Sample test, with a cube mesh
            int[] tvListSample =
            {
                // a simple cube
                0, 2, 3,
                1, 2, 0,
                7, 1, 0,
                1, 7, 6,
                4, 6, 7,
                4, 5, 6,
                2, 5, 4,
                3, 4, 2,
                1, 5, 2,
                1, 6, 5,
                0, 3, 7,
                4, 7, 3
            };
            HashSet<(int, int)> edgeListSample = new HashSet<(int, int)>
            {
                (0, 1), (0, 2), (0, 3), (0, 7),
                (1, 2), (1, 5), (1, 6), (1, 7),
                (2, 3), (2, 4), (2, 5),
                (3, 4), (3, 7),
                (4, 5), (4, 6),
                (5, 6),
                (6, 7)
            };
            HashSet<(int, int)> edgeListOutput = GetEdgeList(tvListSample).ToHashSet();
            foreach ((int, int) outputEdge in edgeListSample)
            {
                if (edgeListSample.Contains(outputEdge)) continue;
                succeeded = false;
                errorMessage += "Incorrect edge: " +
                                "(" + outputEdge.Item1 + outputEdge.Item2 + ") found" +
                                " in sample test.\n";
            }

            foreach ((int, int) edgeSample in edgeListSample)
            {
                if (edgeListOutput.Contains(edgeSample)) continue;
                succeeded = false;
                errorMessage += "Missing edge: " +
                                "(" + edgeSample.Item1 + edgeSample.Item2 + ")" +
                                " in sample test.\n";
            }

            return succeeded;
        }
    }
}