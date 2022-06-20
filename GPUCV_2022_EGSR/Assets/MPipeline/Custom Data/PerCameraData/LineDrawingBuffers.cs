using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.Custom_Data.PerMesh_Data;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

namespace MPipeline.Custom_Data.PerCameraData
{
    /// <summary>
    /// Compute buffers that needed for line drawing passes.
    /// </summary>
    public class LineDrawingBuffers : MonoBehaviour, ILineDrawingData, ICommandBufferConnected
    {
        // =================================================================
        //             Compute Buffer Identifiers(or, handles)
        // =================================================================
        /// <summary>
        /// Buffer size with default size as 1 when start,
        /// will change afterwards.
        /// </summary>
        private const int BufferCountDefault = 1;

        private const int BlockSize = 4; // uint4
        private const int ChunkSize = BlockSize * 2; // uint2x4

        private const int BufferInitHandle = 0;

        // =================================================================
        // Raw Compute Buffer Best-Practice:
        // 1) Definition
        // Raw buffer have to be declared with
        // stride of 4 (uint), otherwise some
        // weired shit is gonna happen.
        // ------------------------------------
        // 2) Initialization
        // and if you want to init its data,
        // then use uint array only.
        // ---------------------------------
        // 3) Addressing
        // Raw buffer addresses BY PER BYTE,
        // not by word(uint),
        // which is a common mistake.
        private const string RawBufferPrefix = "BufferRaw";
        // All raw buffers follow the same syntax,
        // that is, BufferRaw_##"Tag"

        public static readonly int BufferRawPerVert = BufferInitHandle;

        // Granularity Level --- Per Face
        // /////////////////////////////////////////////////////////////
        public static readonly int BufferRawPerFace = BufferInitHandle;
        // -------------------------------------------------------------

        // Granularity Level --- Per Edge
        // ///////////////////////////////////////////////////////////////////
        public static readonly int BufferRawPerEdge = BufferInitHandle;
        public static readonly int BufferRawFlagsPerEdge = BufferInitHandle;

        // Granularity Level --- Per Contour
        // /////////////////////////////////////////////////////////////////////////////////
        public static readonly int BufferRawContourToEdge = BufferInitHandle;
        public static readonly int BufferRawContourToSegment = BufferInitHandle;
        public static readonly int BufferRawRasterDataPerContour = BufferInitHandle;
        public static readonly int BufferRawFlagsPerContour = BufferInitHandle;

        // Granularity Level --- Per Segment
        // ///////////////////////////////////////////////////////////////////////
        public static readonly int BufferRawSegmentsToContour = BufferInitHandle;
        public static readonly int BufferRawFlagsPerSegment = BufferInitHandle;
        public static readonly int BufferRawRasterDataPerSeg = BufferInitHandle;
        public static readonly int BufferRawVisibleSegToSeg = BufferInitHandle;
        
        // Granularity Level --- Per Stamp
        // ///////////////////////////////////////////////////////////////////////
        public static readonly int BufferRawStampPixels = BufferInitHandle;
        public static readonly int BufferRawStampGBuffer = BufferInitHandle;
        public static readonly int BufferRawStampLinkage = BufferInitHandle;
        public static readonly int BufferRawFlagsPerStamp = BufferInitHandle;
        public static readonly int BufferRawCircularStampData = BufferInitHandle;
        public static readonly int BufferRawPixelEdgeData = BufferInitHandle;
        public static readonly int BufferRawProceduralGeometry = BufferInitHandle;


        // Granularity Level --- Per Edge-Loop
        // ///////////////////////////////////////////////////////////////////////
        public static readonly int BufferRawEdgeLoopData = BufferInitHandle;


        // Granularity Level --- Per Stroke
        // ///////////////////////////////////////////////////////////////////////
        public static readonly int BufferRawStrokeData = BufferInitHandle;

        
        // Granularity Level --- Per Path
        // ///////////////////////////////////////////////////////////////////////
        public static readonly int BufferRawPathData = BufferInitHandle;


        // Granularity Level --- Per View Edge
        // ///////////////////////////////////////////////////////////////////////
        public static readonly int BufferRawVEdgeToSegment = BufferInitHandle;
        public static readonly int BufferRawRasterDataPerVEdge = BufferInitHandle;

        // Debug-only
        // ///////////////////////////////////////////////////////////
        public static readonly int BufferRawDebug = BufferInitHandle;

        // Look-back buffers
        // ////////////////////////////////////////////////////////////////
        public static readonly int BufferRawLookBacks = BufferInitHandle;
        public static readonly int BufferRawLookBacks1 = BufferInitHandle;
        public static readonly int BufferRawLookBacks2 = BufferInitHandle;
        public static readonly int BufferRawLookBacks3 = BufferInitHandle;
        public static readonly int BufferRawLookBacks4 = BufferInitHandle;
        public static readonly int BufferRawLookBacks5 = BufferInitHandle;

        
        
        // -----------------------------------------------------------------------
        // Structured Buffer Best-Practice:
        private const string StructuredBufferPrefix = "Structured";
        private const int DefaultSBufferStride = 4; // uint
        public static readonly (int handle, int stride)
            StructuredKeyValuePairs = (BufferInitHandle, DefaultSBufferStride);

        public static readonly (int handle, int stride)
            StructuredGlobalDigitStart = (BufferInitHandle, DefaultSBufferStride);

        public static readonly (int handle, int stride)
            StructuredTempBuffer = (BufferInitHandle, DefaultSBufferStride);
        public static readonly (int handle, int stride)
            StructuredTempBuffer1 = (BufferInitHandle, DefaultSBufferStride);

        // -----------------------------------------------------------------------
        // Indirect Args Best-Practice:
        // ================================================================
        // 1) Crash Case 0:
        // Once indirect argument buffer is loaded,
        // it can only be used as draw/dispatch buffers,
        // that is, 
        // any attempt to read/write them in later
        // shader kernels is undefined and WILL CAUSE A CRASH.
        // ----------------------------------------------------
        // 2) Dispatch Indirect:
        // The 3 uint/int values corresponds to
        // * NUMBER OF THREAD GROUPS *
        // (* NOT * total thread count!!)
        // you want to dispatch

        // Raw Args Buffers
        // ---------------------------------------------------------------------
        private const string ArgumentBufferTag = "Args";
        public static readonly int CachedArgs = BufferInitHandle;
        public static readonly int CachedArgs1 = BufferInitHandle;

        // Indirect Args Buffers
        // ----------------------------------------------------------------
        private const string IndirectArgumentTag = "IndirectArgs";

        // --- Indirect Draw Args
        private const string DrawArgumentTag = "Draw";
        public static readonly int FaceDrawIndirectArgs = BufferInitHandle;
        public static readonly int StampDrawIndirectArgs = BufferInitHandle;
        public static readonly int FragmentDrawIndirectArgs = BufferInitHandle;
        public static readonly int ParticleCoverageTestDrawIndirectArgs = BufferInitHandle;
        public static readonly int ContourCoverageTestDrawIndirectArgs = BufferInitHandle;
        public static readonly int ContourDrawIndirectArgs = BufferInitHandle;

        // --- Indirect Dispatch Args
        private const string DispatchArgumentTag = "Dispatch";
        public static readonly int DispatchIndirectArgs = BufferInitHandle;
        public static readonly int DispatchIndirectArgs1 = BufferInitHandle;

        public DispatchIndirectSwapChain dispatchIndirectSwapChain;


        public static readonly int DispatchIndirectArgsPerMeshContour    = BufferInitHandle;
        public static readonly int DispatchIndirectArgsPerContourSegment = BufferInitHandle;
        public static readonly int DispatchIndirectArgsTwoContourSegment = BufferInitHandle;
        public static readonly int DispatchIndirectArgsPerStamp          = BufferInitHandle;
        public static readonly int DispatchIndirectArgsTwoStamp          = BufferInitHandle;
        public static readonly int DispatchIndirectArgsPerPixelEdge      = BufferInitHandle;
        public static readonly int DispatchIndirectArgsTwoPixelEdge      = BufferInitHandle;
        public static readonly int DispatchIndirectArgsPerEdgeLoop       = BufferInitHandle;
        public static readonly int DispatchIndirectArgsPerJFATile        = BufferInitHandle;
        public static readonly int DispatchIndirectArgsEdgeRankingOPT    = BufferInitHandle;
        public static readonly int DispatchIndirectArgsPBDSolver         = BufferInitHandle;
        public static readonly int DispatchIndirectArgsPerPBDParticle    = BufferInitHandle;
        public static readonly int DispatchIndirectArgsPBDStrainLimiting = BufferInitHandle;
        public static readonly int DispatchIndirectArgsPBDSpringEndPoint = BufferInitHandle;
        public LineDrawingDispatchIndirectArgs indirectDispatcher;


        private bool _mInitialized = false;


        /// <summary>
        /// Raw Buffer Count,
        /// use 1 word(uint) per unit.
        /// </summary>
        private const int RawBufferStride = sizeof(uint);

        private int CountOf(int bufferIndex)
        {
            return _descriptors[bufferIndex].count;
        }

        /// <summary>
        /// Contains pools for different buffers (global, temporary, etc)
        /// </summary>
        private class Pools
        {
            public CBufferPoolStatic Global;

            public Pools()
            {
                Global = new CBufferPoolStatic();
            }
        }

        private Pools _pools = null;
        private CBufferDescriptor[] _descriptors;

        public int[] rawBufferHandles;
        public int[] argsBufferHandles;
        public int[] indirectBufferHandles;
        public int[] structuredBufferHandles;

        public Dictionary<int, uint> bufferClearValues;

        private void SetupBuffersSizeAsync()
        {
            // Preps: ------------------------------------------------------
            // Need to iterate on each LDObject, 
            // So we fetch the LDM component in camera first.
            gameObject.TryGetComponent(out Camera cam);
            LineDrawingMaster ldm;

            // Note: ----------------------------------
            // We need to wait for all LDOs having added
            // themselves into the LDM pool.
            // So that we can visit all LDOs in scene.
            while (!PerCameraDataFactory.TryGet(cam, out ldm))
            {
                ;
            }

            // Fetch maximum triangle & vertex count
            int maxTrianglesPerMesh = 1;
            int maxVerticesPerMesh = 1; // RenderDoc might crash if have 0 sized buffer
            int maxEdgesPerMesh = 1;
            foreach (LineDrawingObject mesh in ldm.objectPool)
            {
                maxTrianglesPerMesh = math.max(maxTrianglesPerMesh, mesh.TriangleCount);
                maxVerticesPerMesh = math.max(maxVerticesPerMesh, mesh.VertexCount);
                maxEdgesPerMesh = math.max(
                    maxEdgesPerMesh, mesh.meshBufferSrc.NumEdges);
            }

            // Setup Buffer Sizes: ---------------------------------------
            // Cache buffer & size, set them at last, once for all
            List<(int bufferHandle, int bufferSize)> bufferSizeTuples =
                new List<(int bufferHandle, int bufferSize)>();

            Action<int, int, uint> registerBufferSize =
                (bufferHandle, bufferSize, clearVal) =>
                {
                    bufferSizeTuples.Add((bufferHandle, bufferSize));
                    SetBufferDefaultValue(bufferHandle, clearVal);
                };

            int primitiveCount = 0;

            // Raw Buffers with Custom Granularity
            // ////////////////////////////////////////
            // LookBack Table Pyramid
            // ----------------------------------------
            // Maximum #group in a single scan pass is
            // limited for now(<= #threads in a group = 1024),
            // "decoupled look-back scan" is used to achieve
            // single-pass scan and segscan:
            registerBufferSize(BufferRawLookBacks, 4096 * 16, 0); // (Double-Buffered)
            registerBufferSize(BufferRawLookBacks1, 4096 * 16, 0);
            registerBufferSize(BufferRawLookBacks2, 4096 * 2, 0);
            registerBufferSize(BufferRawLookBacks3, 4096 * 2, 0);
            registerBufferSize(BufferRawLookBacks4, 4096 * 2, 0);
            registerBufferSize(BufferRawLookBacks5, 4096 * 2, 0);

            primitiveCount = maxVerticesPerMesh;
            registerBufferSize(BufferRawPerVert, primitiveCount * 5, 0);

                // Raw buffer per face
            // ----------------------------------------
            primitiveCount = maxTrianglesPerMesh;
            registerBufferSize(BufferRawPerFace, primitiveCount * 3, 0);

            // Raw buffers per edge
            // ----------------------------------------
            // Compaction will do 8 edges per thread
            const float chunkStride = 8 * 256; // group size of 256 may change later
            int chunkCount = Mathf.CeilToInt(f: (float) maxEdgesPerMesh / chunkStride);
            primitiveCount = chunkCount * (int) chunkStride;

            registerBufferSize(BufferRawPerEdge, primitiveCount, 0);
            registerBufferSize(BufferRawFlagsPerEdge, primitiveCount, 0);

            // Raw buffers per contour
            // ----------------------------------------
            primitiveCount = 512 * 512/*maxEdgesPerMesh + 512*/;

            registerBufferSize(BufferRawContourToEdge, primitiveCount, uint.MaxValue);
            registerBufferSize(BufferRawContourToSegment, primitiveCount, uint.MaxValue);
            registerBufferSize(BufferRawRasterDataPerContour,
                4 * ChunkSize * primitiveCount, 0);
            registerBufferSize(BufferRawFlagsPerContour, primitiveCount, 0);

            // Raw buffers per segment
            // -------------------------
            primitiveCount = 2048 * 2048;

            registerBufferSize(BufferRawSegmentsToContour, primitiveCount, uint.MaxValue);
            registerBufferSize(BufferRawFlagsPerSegment, primitiveCount, 0);
            registerBufferSize(BufferRawRasterDataPerSeg, primitiveCount * 4, 0);
            registerBufferSize(BufferRawVisibleSegToSeg, primitiveCount, uint.MaxValue);
            
            // Raw buffers per line-pixel(stamp)
            // --------------------------------------------------------------------
            primitiveCount = 640 * 640; 

            registerBufferSize(BufferRawStampPixels, primitiveCount * 10, uint.MaxValue);
            registerBufferSize(BufferRawStampGBuffer, primitiveCount * 30, 0);
            registerBufferSize(BufferRawStampLinkage, primitiveCount * 16, 0);
            registerBufferSize(BufferRawFlagsPerStamp, primitiveCount * 8, 0);
            registerBufferSize(BufferRawCircularStampData, 1, 0); // - deprecated -
            registerBufferSize(BufferRawPixelEdgeData, primitiveCount * 46, UInt32.MaxValue);
            registerBufferSize(BufferRawProceduralGeometry, primitiveCount * 47, 0);


            // Raw buffer per edge-loop
            primitiveCount = 8192;
            registerBufferSize(BufferRawEdgeLoopData, primitiveCount * 16, 0);


            // Raw buffers per stroke
            primitiveCount = 4096;
            registerBufferSize(BufferRawStrokeData, primitiveCount * 256, 0);


            // Raw buffers per path
            primitiveCount = 4096 * 2;
            registerBufferSize(BufferRawPathData, primitiveCount * 16, 0);


            // Raw buffers per view-edge
            // --------------------------
            primitiveCount = 512 * 512;

            registerBufferSize(BufferRawVEdgeToSegment, /*primitiveCount*/1, 0);
            registerBufferSize(BufferRawRasterDataPerVEdge,
                /*primitiveCount * ChunkSize*/1, 0);
            registerBufferSize(StructuredKeyValuePairs.handle,
                /*2 * 2 * primitiveCount*/1, // Each edge has 2 verts(key, val)
                uint.MaxValue); // 4x512x512x4B=4MB


            // Misc Granularity
            // -------------------------
            primitiveCount = 3000 * 3000;
            registerBufferSize(BufferRawDebug, primitiveCount, 0);

            primitiveCount = 512 * 4; // 8-bit digit for radix sort, 4 digits/item
            registerBufferSize(StructuredGlobalDigitStart.handle, primitiveCount, 0);

            registerBufferSize(StructuredTempBuffer.handle, 1024, 0);
            registerBufferSize(StructuredTempBuffer1.handle, 32, 0);

            // Setup buffers' sizes in a serialized fashion
            // --------------------------------------------
            foreach (var tuple in bufferSizeTuples)
            {
                // Setup buffer size
                SetDescSizeOfBuffer(tuple.bufferHandle, tuple.bufferSize);
                // Refine buffer size
                // (Round by thread group size)
                AdjustDescSizeByGranularityOfBuffer(tuple.bufferHandle);
            }
        }

        /// <summary>
        /// this is called at the 1st frame since Init() was called,
        /// in order to wait for everything is properly initialized,
        /// then setup descriptors which is related to external resources
        /// </summary>
        private void InitAsync()
        {
            // Update size for buffers which depends on other objects in scene,
            // e.g, some mesh buffers needs to meet the max #verts,
            // some buffers need to know current screen resolution
            SetupBuffersSizeAsync(); // This function updates buffer descriptors

            // Now all buffer descriptors haven been updated, if necessary;
            // use descriptors to resize & init GPU memory for buffers.
            foreach (int bufferHandle in rawBufferHandles)
            {
                InitRawBufferData(bufferHandle, GetBufferDefaultValue(bufferHandle)); // Zeros
            }

            // Structured buffers have different data types,
            // so here we init these separately.
            InitStructuredBufferData<uint>(
                StructuredTempBuffer.handle, 
                0
            ); // Zeros
            InitStructuredBufferData<uint>(
                StructuredTempBuffer1.handle,
                0
            ); // Zeros
            

            // Due to the limit of C# generics, we need to init structured buffers manually
            uint clearVal = uint.MaxValue;
            InitStructuredBufferData(StructuredKeyValuePairs.handle, ref clearVal);
            clearVal = uint.MinValue;
            InitStructuredBufferData(StructuredGlobalDigitStart.handle, ref clearVal);

            _mInitialized = true;
        }


        static LineDrawingBuffers()
        {
            Func<List<FieldInfo>, int, int> serializeBufferHandles =
                (fieldInfos, currentHandle) =>
                {
                    for (int field = 0; field < fieldInfos.Count; field++, currentHandle++)
                    {
                        fieldInfos[field].SetValue(null, currentHandle);
                    }

                    // Return starting point for next groups of handles
                    return currentHandle;
                };

            // For more complex buffer usages(e.g, structured buffers), 
            // stride is not fixed
            Func<List<FieldInfo>, int, int> serializeBufferHandleWithStride =
                (fieldInfos, currentHandle) =>
                {
                    for (int field = 0; field < fieldInfos.Count; field++, currentHandle++)
                    {
                        (int handle, int stride) defaultSetting =
                            (ValueTuple<int, int>) fieldInfos[field].GetValue(null);

                        fieldInfos[field].SetValue(
                            null, // Update handle only, keep stride as it is
                            (currentHandle, defaultSetting.stride)
                        );
                    }

                    return currentHandle;
                };

            List<FieldInfo> rawBufferFields = GetRawBufferFieldInfos();
            List<FieldInfo> argsBufferFields = GetArgsBufferFieldInfos();
            List<FieldInfo> indirectBufferFields = GetIndirectBufferFieldInfos();
            List<FieldInfo> structuredBufferFields = GetStructureBufferFieldInfos();

            // Serialize buffer handles
            int handleOffset = 0;
            handleOffset = serializeBufferHandles(rawBufferFields, handleOffset);
            handleOffset = serializeBufferHandles(argsBufferFields, handleOffset);
            handleOffset = serializeBufferHandles(indirectBufferFields, handleOffset);
            handleOffset = serializeBufferHandleWithStride(structuredBufferFields, handleOffset);
        }

        private int[] ExtractBufferHandlesFromFields(List<FieldInfo> bufferFieldInfos, bool isStructuredBuffer = false)
        {
            if (!isStructuredBuffer)
            {
                return Array.ConvertAll(
                    bufferFieldInfos.ToArray(),
                    input => (int) input.GetValue(null));
            }

            return Array.ConvertAll(
                bufferFieldInfos.ToArray(),
                input => (
                    (ValueTuple<int, int>) input.GetValue(null)
                ).Item1 // (handle, stride)
            );
        }

        private int[] ExtractStructuredBufferStrides(List<FieldInfo> bufferFieldInfos)
        {
            return Array.ConvertAll(
                bufferFieldInfos.ToArray(),
                input => (
                    (ValueTuple<int, int>) input.GetValue(null)
                ).Item2
            );
        }

        private void ExtractBufferDescAndHandles(
            List<FieldInfo> fields,
            out List<CBufferDescriptor> descs,
            out int[] handles,
            ComputeBufferType buffType,
            int defaultBufferLength = BufferCountDefault,
            int defaultBufferStride = RawBufferStride)
        {
            handles = ExtractBufferHandlesFromFields(fields);
            descs = GetBufferDescriptorsOf(
                fields,
                handles.Min(),
                buffType,
                BufferCountDefault,
                RawBufferStride
            );
        }

        private void ComputeRawBufferDescsAndHandles(
            out List<CBufferDescriptor> descs,
            out int[] rawBuffHandles)
        {
            List<FieldInfo> bufferFieldInfos = GetRawBufferFieldInfos();
            rawBuffHandles = ExtractBufferHandlesFromFields(bufferFieldInfos);

            descs = GetBufferDescriptorsOf(
                bufferFieldInfos,
                rawBuffHandles.Min(),
                ComputeBufferType.Raw,
                BufferCountDefault,
                RawBufferStride);
        }

        private void ComputeIndirectBufferDescsAndHandles(
            out List<CBufferDescriptor> descs,
            out int[] indirectHandles)
        {
            List<FieldInfo> bufferFieldInfos = GetIndirectBufferFieldInfos();
            indirectHandles = ExtractBufferHandlesFromFields(bufferFieldInfos);

            descs = GetBufferDescriptorsOf(
                bufferFieldInfos,
                indirectHandles.Min(),
                ComputeBufferType.IndirectArguments,
                4,
                sizeof(uint));
        }

        private void ComputeArgsBufferDescsAndHandles(
            out List<CBufferDescriptor> descs,
            out int[] argsHandles)
        {
            List<FieldInfo> bufferFieldInfos = GetArgsBufferFieldInfos();
            argsHandles = ExtractBufferHandlesFromFields(bufferFieldInfos);

            descs = GetBufferDescriptorsOf(
                bufferFieldInfos,
                argsHandles.Min(),
                ComputeBufferType.Structured,
                4,
                sizeof(uint));
        }

        private void ComputeStructuredBufferDescsAndHandles(
            out List<CBufferDescriptor> descs,
            out int[] handles)
        {
            List<FieldInfo> bufferFieldInfos = GetStructureBufferFieldInfos();
            handles = ExtractBufferHandlesFromFields(bufferFieldInfos, true);

            int[] strides = ExtractStructuredBufferStrides(bufferFieldInfos);

            descs = GetBufferDescriptorsOf(
                bufferFieldInfos,
                handles.Min(),
                ComputeBufferType.Structured,
                1,
                strides
            );
        }

        /// <summary>
        /// Extracts buffer descriptors for a given group of buffer field infos
        /// </summary>
        /// <param name="bufferFieldInfos">list that contains buffer field info</param>
        /// <param name="baseOffset">global offset of this type of buffers</param>
        /// <param name="computeBufferType">compute buffer type</param>
        /// <param name="bufferInitCount">initial buffer size</param>
        /// <param name="bufferStride">stride of buffer element</param>
        /// <returns></returns>
        private List<CBufferDescriptor> GetBufferDescriptorsOf(
            List<FieldInfo> bufferFieldInfos,
            int baseOffset,
            ComputeBufferType computeBufferType,
            int bufferInitCount,
            int bufferStride
        )
        {
            int fieldCount = bufferFieldInfos.Count;

            CBufferDescriptor[] bufferDescs = new CBufferDescriptor[fieldCount];

            foreach (var bufferFieldInfo in bufferFieldInfos)
            {
                bufferDescs[(int) bufferFieldInfo.GetValue(null) - baseOffset] =
                    new CBufferDescriptor(
                        computeBufferType,
                        ObjectNaming.getBufferHlslName(bufferFieldInfo.Name),
                        bufferInitCount,
                        bufferStride
                    );
            }

            return bufferDescs.ToList();
        }

        /// <summary>
        /// Variation for structured buffer, given an array of different
        /// buffer strides, instead of fixed stride(4) for raw/indirect/args buffers.
        /// </summary>
        private List<CBufferDescriptor> GetBufferDescriptorsOf(
            List<FieldInfo> bufferFieldInfos,
            int baseOffset,
            ComputeBufferType computeBufferType,
            int bufferInitCount,
            int[] bufferStride
        )
        {
            int fieldCount = bufferFieldInfos.Count;

            CBufferDescriptor[] bufferDescs = new CBufferDescriptor[fieldCount];

            foreach (var bufferFieldInfo in bufferFieldInfos)
            {
                (int handle, int stride) bufferInfo =
                    (ValueTuple<int, int>) bufferFieldInfo.GetValue(null);
                int localIndex = bufferInfo.handle - baseOffset;

                bufferDescs[localIndex] =
                    new CBufferDescriptor(
                        computeBufferType,
                        ObjectNaming.getBufferHlslName(bufferFieldInfo.Name),
                        bufferInitCount,
                        bufferStride[localIndex]
                    );
            }

            return bufferDescs.ToList();
        }

        private static List<FieldInfo> GetArgsBufferFieldInfos()
        {
            List<FieldInfo> argsBufferFieldInfos = GetBufferFieldInfos(
                fi =>
                    fi.FieldType == typeof(int) && // int field
                    fi.Name.Contains(ArgumentBufferTag) &&
                    !fi.Name.Contains(IndirectArgumentTag)
            );
            return argsBufferFieldInfos;
        }

        private static List<FieldInfo> GetIndirectBufferFieldInfos()
        {
            List<FieldInfo> indirectBufferFieldInfos = GetBufferFieldInfos(
                fi =>
                    fi.FieldType == typeof(int) && // int field
                    fi.Name.Contains(IndirectArgumentTag));
            return indirectBufferFieldInfos;
        }

        private static List<FieldInfo> GetRawBufferFieldInfos()
        {
            List<FieldInfo> rawBufferFieldInfos = GetBufferFieldInfos(
                fi =>
                    fi.FieldType == typeof(int) && // int field
                    fi.Name.Contains(RawBufferPrefix));
            return rawBufferFieldInfos;
        }

        private static List<FieldInfo> GetStructureBufferFieldInfos()
        {
            List<FieldInfo> sBufferFieldInfos = GetBufferFieldInfos(
                fi =>
                    fi.FieldType == typeof((int, int)) &&
                    fi.Name.Contains(StructuredBufferPrefix));
            return sBufferFieldInfos;
        }

        private static List<FieldInfo> GetBufferFieldInfos(Predicate<FieldInfo> predicate)
        {
            List<FieldInfo> bufferFieldInfos =
                typeof(LineDrawingBuffers).GetFields(
                    BindingFlags.Public |
                    BindingFlags.Static |
                    BindingFlags.FlattenHierarchy
                ).Where(
                    fi =>
                        // const fields detection -------
                        // fi.IsLiteral &&
                        // !fi.IsInitOnly &&
                        // static readonly detection ----
                        fi.IsInitOnly && // readonly
                        predicate(fi) // field that meets predicate
                ).ToList();
            return bufferFieldInfos;
        }

        /// <summary>
        /// Different indirect buffer may have different
        /// initial values due to different usages.
        /// </summary>
        /// <param name="bufferHandle"></param>
        private uint[] IndirectBufferDefaultData(int bufferHandle)
        {
            uint[] value;
            string bufferName = _descriptors[bufferHandle].name;

            if (bufferName.Contains(DrawArgumentTag))
            {
                // Args for Indirect Draw
                // Data layout: ---------------
                // uint NumVertsPerInst;
                // uint InstCount;
                // uint VertOffset;
                // uint InstOffset;
                value = new uint[] {0, 1, 0, 0};
            }
            else
            {
                if (bufferName.Contains(DispatchArgumentTag))
                {
                    // Args for Indirect Dispatch
                    // Data Layout: ------------------------
                    // uint NumGroups.x
                    // uint NumGroups.y
                    // uint NumGroups.z
                    // uint dummy (for 128-bit alignment)
                    value = new uint[] {1, 1, 1, 0};
                }
                else
                {
                    Debug.LogError("Ambiguous or Invalid Name '" +
                                   bufferName + "' for Indirect-Buffer:" +
                                   "a indirect buffer name should have exactly one tag.");
                    return null;
                }
            }

            return value;
        }

        /// <summary>
        /// Sets default value for initializing a raw buffer.
        /// </summary>
        /// <param name="bufferHandle"></param>
        /// <param name="clearVal"></param>
        private void SetBufferDefaultValue(int bufferHandle, uint clearVal)
        {
            if (bufferClearValues.ContainsKey(bufferHandle))
            {
                Debug.LogWarning("Trying to override default clear value of buffer "
                                 + _descriptors[bufferHandle].name + ", which is a risky behaviour.");
                bufferClearValues[bufferHandle] = clearVal;
            }
            else
            {
                bufferClearValues.Add(bufferHandle, clearVal);
            }
        }

        /// <summary>
        /// Raw buffer has default value for initialization
        /// </summary>
        /// <param name="bufferHandle"></param>
        /// <returns>If special value is assigned, then use that value to
        /// init this buffer, otherwise, raw buffer will be cleared by
        /// Uint32.MinValue == 0.</returns>
        private uint GetBufferDefaultValue(int bufferHandle)
        {
            return bufferClearValues.ContainsKey(bufferHandle)
                ? bufferClearValues[bufferHandle]
                : UInt32.MinValue;
        }

        //-//////////////////////////////////////////////////////////////////////////-//
        //                                   Events                                   //
        //-//////////////////////////////////////////////////////////////////////////-//
        public void Init(Camera cam)
        {
            _cmd = null;
            
            // Init CBuffer Descriptors & Handles
            // -----------------------------------------------------------------------------------------------
            ComputeRawBufferDescsAndHandles(out List<CBufferDescriptor> rawDescs, out rawBufferHandles);
            bufferClearValues = new Dictionary<int, uint>();
            ComputeArgsBufferDescsAndHandles(out List<CBufferDescriptor> argDescs, out argsBufferHandles);
            ComputeIndirectBufferDescsAndHandles(out List<CBufferDescriptor> indirectDescs, out indirectBufferHandles);
            ComputeStructuredBufferDescsAndHandles(out List<CBufferDescriptor> structuredDescs,
                out structuredBufferHandles);


            rawDescs.AddRange(argDescs);
            rawDescs.AddRange(indirectDescs);
            rawDescs.AddRange(structuredDescs);
            _descriptors = rawDescs.ToArray();

            // Create Buffers According to Buffer Descriptors
            // -------------------------------------------------------------------
            // Allocated Buffers    
            //      in Pool     
            // |---------------| -----------------------------------------...
            // | 0 1 2 3 4 5 6 | <== 7 8 9... Append new buffers from end ...
            // |---------------| -----------------------------------------...
            _pools = new Pools();
            _threadGroupSizes = new List<int3>();
            for (int i = _pools.Global.count; i < _descriptors.Length; i++)
            {
                _pools.Global.AppendBuffer(_descriptors[i]);
                // Init max thread group sizes as 1
                _threadGroupSizes.Add(new int3(1, 1, 1));
            }

            // Intermediate Args Buffer
            // write data into this buffer first,
            // then transfer data into multiple
            // indirect buffers
            // ----------------------------------------------------------------------
            foreach (int argsBufferHandle in argsBufferHandles)
            {
                _pools.Global.TrySetBuffer(
                    argsBufferHandle,
                    new uint[] {0, 0, 0, 0});
            }

            // Indirect Args Buffer
            // Contains indirect Draw/Dispatch args
            // ------------------------------------------------------------------------
            foreach (int indirectBufferHandle in indirectBufferHandles)
            {
                uint[] data;
                if (null != (data = IndirectBufferDefaultData(indirectBufferHandle)))
                {
                    _pools.Global.TrySetBuffer(
                        indirectBufferHandle,
                        data
                    );
                }
            }

            dispatchIndirectSwapChain = new DispatchIndirectSwapChain(
                DispatchIndirectBuffer(),
                DispatchIndirectBuffer1()
            );

            indirectDispatcher = new LineDrawingDispatchIndirectArgs();
            foreach (int handle in indirectBufferHandles)
            {
                indirectDispatcher.AddIndirectArgsBuffer(
                    handle, GetComputeBufferUnsafe(handle)
                );
            }


            // Set flag(s)
            _mInitialized = false; // Buffer size needs to be set in async manner

            ContourExtractionPass.UpdatePerCameraData += OnUpdatePerCameraData;
        }


        private void OnUpdatePerCameraData(Camera camera, CommandBuffer cmd)
        {
            gameObject.TryGetComponent(out Camera currCamera);
            if (currCamera != camera)
            {
                return;
            }

            if (!_mInitialized)
            {
                InitAsync();
            }
        }


        public void Awake()
        {
            _mInitialized = false;
        }

        public void OnDisable()
        {
            _pools.Global.ReleaseBuffers();
        }

        public void OnDestroy()
        {
            _pools.Global.ReleaseBuffers();
            _mInitialized = false;

            ContourExtractionPass.UpdatePerCameraData -= OnUpdatePerCameraData;
        }


        //-//////////////////////////////////////////////////////////////////////////-//
        //                                  utilities                                 //
        //-//////////////////////////////////////////////////////////////////////////-//
        /// <summary>
        /// Cache thread group size for a given buffer.
        /// If a buffer is bond with multiple compute kernels,
        /// then we'll choose the largest group size among them.  
        /// </summary>
        /// <param name="bufferIndex"> handle of buffer</param>
        /// <param name="size">thread group size</param>
        private void SetGroupSizeOfBuffer(int bufferIndex, int3 size)
        {
            _threadGroupSizes[bufferIndex] = math.max(
                size, GetThreadGroupSize(bufferIndex)
            );
        }

        private int3 GetThreadGroupSize(int bufferIndex)
        {
            return _threadGroupSizes[bufferIndex];
        }

        private List<int3> _threadGroupSizes;

        private void SetDescSizeOfBuffer(int bufferType, int resetSize)
        {
            _descriptors[bufferType].count = resetSize;
        }

        /// <summary>
        /// Granularity is defined by the
        /// -- maximum threadGroupSize --
        /// within all compute kernels that
        /// this buffer binds to.
        /// </summary>
        /// <param name="csKernelQueue"></param>
        public void ConfigureBufferGranularity(params CsKernel[] csKernelQueue)
        {
            foreach (CsKernel kernel in csKernelQueue)
            {
                if (kernel == null) continue;

                int3 currGroupSize;
                currGroupSize.x = kernel.ThreadsPerGroup.x;
                currGroupSize.y = kernel.ThreadsPerGroup.y;
                currGroupSize.z = kernel.ThreadsPerGroup.z;
                foreach (int bufferId in kernel.LDBufferHandles)
                {
                    SetGroupSizeOfBuffer(
                        bufferId, currGroupSize
                    );
                }
            }
        }

        private void AdjustDescSizeByGranularityOfBuffer(
            int bufferType)
        {
            int3 numThreads = GetThreadGroupSize(bufferType);
            int threadsPerGroup = numThreads.x * numThreads.y * numThreads.z;

            int elemsInBuffer = CountOf(bufferType);

            _descriptors[bufferType].count =
                CalculateBufferSizeByGroupSize(elemsInBuffer, threadsPerGroup);
        }

        private static int CalculateBufferSizeByGroupSize(int elemsInBuffer, int threadsPerGroup)
        {
            int groupsNeeded = Mathf.CeilToInt(
                (float) elemsInBuffer / (float) threadsPerGroup
            );
            return groupsNeeded * threadsPerGroup;
        }

        private void InitStructuredBufferData<T>(int buffer, ref T clearVal)
        {
            int size = _descriptors[buffer].count;

            T[] initData = new T[size];
            for (int i = 0; i < size; i++)
            {
                initData[i] = clearVal;
            }

            _pools.Global.ResizeBuffer(buffer, _descriptors[buffer]);
            _pools.Global.TrySetBuffer(buffer, initData);
        }
        
        private void InitStructuredBufferData<T>(int sbuffer, T clearVal)
        {
            int size = _descriptors[sbuffer].count;

            T[] initData = new T[size];
            for (int i = 0; i < size; i++)
            {
                initData[i] = clearVal;
            }

            _pools.Global.ResizeBuffer(sbuffer, _descriptors[sbuffer]);
            _pools.Global.TrySetBuffer(sbuffer, initData);
        }

        private void InitRawBufferData(int rawBuffer, uint clearVal)
        {
            int size = _descriptors[rawBuffer].count;

            uint[] initData = new uint[size];
            for (int i = 0; i < size; i++)
            {
                initData[i] = clearVal;
            }

            _pools.Global.ResizeBuffer(rawBuffer, _descriptors[rawBuffer]);
            _pools.Global.TrySetBuffer(rawBuffer, initData);
        }

        public void ResetArgs(int bufferType, uint[] resetData)
        {
            if (resetData.Length != 4 || CountOf(bufferType) != 4)
            {
                Debug.LogError("indirect argument buffer should have count of 4");
            }

            // _pools.Global.ReallocBuffer(bufferType, descriptors[bufferType]);
            _pools.Global.TrySetBuffer(bufferType, resetData);
        }

        public ComputeBuffer DrawArgsForContours()
        {
            return _pools.Global[ContourDrawIndirectArgs].GPUData;
        }
        public ComputeBuffer DrawArgsForStamps()
        {
            return _pools.Global[StampDrawIndirectArgs].GPUData;
        }
        public ComputeBuffer DrawArgsForFragments()
        {
            return _pools.Global[FragmentDrawIndirectArgs].GPUData;
        }

        public ComputeBuffer DrawArgsForContourCoverageTest()
        {
            return _pools.Global[ContourCoverageTestDrawIndirectArgs].GPUData;
        }

        public ComputeBuffer DrawArgsForParticleCoverageTest()
        {
            return _pools.Global[ParticleCoverageTestDrawIndirectArgs].GPUData;
        }

        public ComputeBuffer DrawArgsForFaces()
        {
            return _pools.Global[FaceDrawIndirectArgs].GPUData;
        }

        private ComputeBuffer DispatchIndirectBuffer()
        {
            return _pools.Global[DispatchIndirectArgs].GPUData;
        }

        private ComputeBuffer DispatchIndirectBuffer1()
        {
            return _pools.Global[DispatchIndirectArgs1].GPUData;
        }

        private ComputeBuffer DispatchIndirectArgsStamp()
        {
            return _pools.Global[DispatchIndirectArgsPerStamp].GPUData;
        }

        private ComputeBuffer DispatchIndirectArgsPixelEdge()
        {
            return _pools.Global[DispatchIndirectArgsPerPixelEdge].GPUData;
        }

        private ComputeBuffer DispatchIndirectArgsEdgeLoop()
        {
            return _pools.Global[DispatchIndirectArgsPerEdgeLoop].GPUData;
        }

        private ComputeBuffer GetComputeBufferUnsafe(int handle)
        {
            return _pools.Global[handle].GPUData;
        }

        public List<uint> ComputeBufferSnapshot(int bufferHandle)
        {
            uint[] tempBuff = new uint[CountOf(bufferHandle)];
            _pools.Global[bufferHandle].GPUData.GetData(tempBuff);
            return tempBuff.ToList();
        }


        // Shader Binding
        // -------------------------------------------------------------------------------
        private CommandBuffer _cmd;
        public void ConnectToCmd(CommandBuffer cmd)
        {
            _cmd = cmd;
            dispatchIndirectSwapChain.ConnectTo(cmd);
        }

        public void DisconnectCmd()
        {
            dispatchIndirectSwapChain.DisconnectFromCmd();
            _cmd = null;
        }

        public void BindBuffersWithKernelCommand(CsKernel cskernel)
        {
            ComputeShader shader = cskernel.ComputeShader;
            foreach (int bufferId in cskernel.LDBufferHandles)
            {
                if (_pools.Global.TryGetBufferInfo(
                    bufferId,
                    out int id,
                    out ComputeBuffer data)
                )
                {
                    _cmd.SetComputeBufferParam(
                        shader, cskernel.KernelIndex, id, data);
                }
            }
        }


        public void BindBuffersMatPropsBlock(
            IEnumerable<int> bufferTypes, MaterialPropertyBlock materialPropertyBlock)
        {
            foreach (int typeOfBuffer in bufferTypes)
            {
                if (_pools.Global.TryGetBufferInfo(
                    typeOfBuffer,
                    out int id, out ComputeBuffer data))
                {
                    materialPropertyBlock.SetBuffer(id, data);
                }
                else
                {
                    Debug.LogWarning("Trying to bind Wrong buffer type in " +
                                     this.name + ", please check your code.");
                }
            }
        }
    }
}