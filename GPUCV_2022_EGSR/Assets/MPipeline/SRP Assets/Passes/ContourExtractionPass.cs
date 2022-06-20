using System;
using System.Collections.Generic;
using Assets.MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.Custom_Data.BasicDataTypes.Global_Properties;
using MPipeline.Custom_Data.PerCameraData;
using MPipeline.Custom_Data.PerMesh_Data;
using MPipeline.SRP_Assets.Features;
using MPipeline.SRP_Assets.Passes;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ContourExtractionPass : LineDrawingRenderPass, ILineDrawingDataUser
{
    //                 Compute Shader & Kernel Configurations
    // ===========================================================================
    private List<ComputeShader> _mComputeShaders;
    private int NumComputeShaders => _mComputeShaders.Count;

    // Shader Property Descriptors & Handles
    // -------------------------------------------------------
    // Camera-wise constants
    private readonly List<PropDescriptor> _mCSCameraPropDescs;
    private List<int[]> _mCSCameraVectorProps;
    private List<int[]> _mCSCameraMatrixProps;

    // Mesh-wise constants
    private List<int[]> _mCSMeshProps;

    // Compute Shader & Kernels
    // -------------------------------------------------------
    private const int ExtractionShader = 0;
    private ComputeShader _mCsExtraction;
    private CsKernel _mCsKernelClearArgs;
    private CsKernel _mCsKernelPerV;
    private CsKernel _mCsKernelPerF;
    private CsKernel _mCsKernelPerE;

    private const int CompactionShader = 1;
    private ComputeShader _mCsCompaction;
    private CsKernel _mCsKernelCompaction;

    private const int ContourSetupShader = 2;
    private ComputeShader _mCsContourSetup;
    private CsKernel _mCsKernelContourIndirection;
    private CsKernel _mCsKernelContourRasterization;
    
    private const int SegmentAllocationShader = 3;
    private ComputeShader _mCsSegmentAllocation;
    private CsKernel _mCsKernelSegmentAllocationUpSweep;
    private CsKernel _mCsKernelSegmentAllocationReduce;
    private CsKernel _mCsKernelSegmentAllocationDwsweep;

    private const int SegmentSetupShader = 4;
    private ComputeShader _mCsSegmentSetup;
    private CsKernel _mCsKernelCleanDataPerSeg;
    private CsKernel _mCsKernelContourToSegs;

    private const int SegmentToContourShader = 5;
    private ComputeShader _mCsSegmentToContourUpdated;
    private CsKernel _mCsKernelSegmentToContourUpSweep;
    private CsKernel _mCsKernelSegmentToContourReduce;
    private CsKernel _mCsKernelSegmentToContourDwsweep;

    private const int SegmentVisibilityShader = 6;
    private ComputeShader _mCsSegmentVisibility;
    private CsKernel _mCsKernelSegmentVisibility;

    private const int RadixSortShader = 7;
    private ComputeShader _mCsRadixSort;
    private CsKernel _mCsKernelClearGlobalHistogram;
    private CsKernel _mCsKernelBuildGlobalHistogram;

    private const int ContourPixelExtractionShader = 8;
    private ComputeShader _mCsPixelExtraction;
    private CsKernel _mCsKernelSegToPixel;

    //                     Asynchronous Resources
    // =================================================================
    private LineDrawingProps _mCameraProps;
    private bool _asyncDataLoaded;

    // TODO: Event System
    public static Action<Camera, CommandBuffer> UpdatePerCameraData;
    public static Action<Camera, CommandBuffer> UpdatePerMeshData;

    //             Debug
    // ===============================
    private ComputeShader CS(int handle)
    {
        return _mComputeShaders[handle];
    }

    private int[] GetCameraMatrixPropHandlesOfCS(int computeShaderHandle)
    {
        return _mCSCameraMatrixProps[computeShaderHandle];
    }

    private void BindCameraMatrixPropsWithCS(int computeShaderHandle)
    {
        if (GetCameraMatrixPropHandlesOfCS(computeShaderHandle) == null)
        {
            return;
        }

        _mCameraProps.BindCameraMatricesCommand(
            GetCameraMatrixPropHandlesOfCS(computeShaderHandle),
            CMD, CS(computeShaderHandle)
        );
    }

    private void SetCameraVectorPropHandles(int computeShaderHandle, params int[] handles)
    {
        int[] setup = new int[handles.Length];
        handles.CopyTo(setup, 0);
        _mCSCameraVectorProps[computeShaderHandle] = handles;
    }

    private int[] GetCameraVectorPropHandlesOfCS(int computeShaderHandle)
    {
        return _mCSCameraVectorProps[computeShaderHandle];
    }

    private void BindCameraVectorPropsWithCS(int computeShaderHandle)
    {
        if (GetCameraVectorPropHandlesOfCS(computeShaderHandle) == null)
        {
            return;
        }

        _mCameraProps.BindCameraVectorsCommand(
            GetCameraVectorPropHandlesOfCS(computeShaderHandle),
            CMD, CS(computeShaderHandle)
        );
    }


    public ContourExtractionPass(LineDrawingRenderPass.PassSetting setting)
    : base(setting.profilerTag, setting.passEvent)
    {
        SetupLineDrawingComputeShaders(this, setting);
    }

    protected override void LoadLineDrawingComputeShaders(
        LineDrawingRenderPass.PassSetting setting)
    {
        // Compute Shader & Kernels ---------------------------------------
        int computeShaderCount = setting.computeShaderSetting.Count;

        _mComputeShaders =
            new List<ComputeShader>(computeShaderCount);

        for (int i = 0; i < computeShaderCount; i++)
        {
            string shaderPath = setting.computeShaderSetting[i].path;
            _mComputeShaders.Add(Resources.Load<ComputeShader>(shaderPath));
        }

        _mCSCameraVectorProps = new List<int[]>(computeShaderCount);
        _mCSCameraMatrixProps = new List<int[]>(computeShaderCount);
        for (int i = 0; i < computeShaderCount; i++)
        {
            _mCSCameraVectorProps.Add(null);
            _mCSCameraMatrixProps.Add(null);
        }

        _mCSMeshProps = new List<int[]>(computeShaderCount);

        CsKernel ExtractKernel(int csHandle, ref int kernelHandle)
        {
            CsKernel res = ClearLineDrawingTexturePass.ExtractComputeKernel(
                setting.computeShaderSetting[csHandle],
                CS(csHandle),
                kernelHandle
            );
            kernelHandle++;
            return res;
        }


        // Extraction CS -- Faces to Edges
        // ----------------------------------------------------------
        int shaderHandle = ExtractionShader;
        int currentKernel = 0;
        ComputeShader currentShader = CS(shaderHandle);

        _mCsExtraction = currentShader;

        SetCameraVectorPropHandles(
            shaderHandle,
            (int)LineDrawingProps.PropTypes.CameraPositionWS
        );
        _mCSCameraMatrixProps[shaderHandle] = new[]
        {
            MatrixProps.Type.VP
        };


        _mCsKernelClearArgs = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelClearArgs.SetLineDrawingBuffers(
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.StructuredTempBuffer.handle,
            LineDrawingBuffers.StructuredTempBuffer1.handle
        );
        _mCsKernelClearArgs.SetupNumGroupsBy1D(4);

        _mCsKernelPerV = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelPerV.SetMeshBuffers(
            MeshBufferPreset.BufferType.VP
        );
        _mCsKernelPerV.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawPerVert
        );


        _mCsKernelPerF = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelPerF.SetMeshBuffers(
            MeshBufferPreset.BufferType.VP,
            MeshBufferPreset.BufferType.TV,
            MeshBufferPreset.BufferType.TN
        );
        _mCsKernelPerF.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawPerFace,
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.StructuredTempBuffer.handle
        );


        _mCsKernelPerE = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelPerE.SetMeshBuffers(
            MeshBufferPreset.BufferType.VP,
            MeshBufferPreset.BufferType.ET);
        _mCsKernelPerE.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawPerFace,
            LineDrawingBuffers.BufferRawPerEdge,
            LineDrawingBuffers.BufferRawFlagsPerEdge,
            LineDrawingBuffers.FaceDrawIndirectArgs,
            LineDrawingBuffers.StructuredTempBuffer.handle,
            // Debug
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.BufferRawLookBacks,
            LineDrawingBuffers.BufferRawLookBacks1
        );


        // Compaction CS -- Edges to Contour
        // --------------------------------------------------------
        shaderHandle = CompactionShader;
        currentKernel = 0;
        currentShader = CS(shaderHandle);

        _mCsCompaction = currentShader;

        _mCsKernelCompaction = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelCompaction.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawPerEdge,
            LineDrawingBuffers.CachedArgs,
            // Debug
            LineDrawingBuffers.BufferRawLookBacks,
            LineDrawingBuffers.BufferRawLookBacks1
        );


        // Contour Setup CS -- Initialize per-contour data
        // ----------------------------------------------------
        shaderHandle = ContourSetupShader;
        currentKernel = 0;
        currentShader = CS(shaderHandle);

        _mCsContourSetup = currentShader;

        SetCameraVectorPropHandles(
            shaderHandle,
            (int)LineDrawingProps.PropTypes.ScreenTexelSize
        );
        _mCSCameraMatrixProps[shaderHandle] = new[]
        {
            MatrixProps.Type.VP,
            MatrixProps.Type.V,
            MatrixProps.Type.P
        };

        _mCsKernelContourIndirection = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelContourIndirection.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawPerEdge,
            LineDrawingBuffers.BufferRawFlagsPerEdge,
            LineDrawingBuffers.BufferRawContourToEdge,
            LineDrawingBuffers.BufferRawFlagsPerContour,
            LineDrawingBuffers.ContourDrawIndirectArgs,
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.StructuredTempBuffer1.handle,
            // Dispatch args
            LineDrawingBuffers.DispatchIndirectArgsPerMeshContour,
            LineDrawingBuffers.DispatchIndirectArgs,
            LineDrawingBuffers.DispatchIndirectArgs1
        );


        _mCsKernelContourRasterization = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelContourRasterization.SetMeshBuffers(
            MeshBufferPreset.BufferType.EV,
            MeshBufferPreset.BufferType.VP,
            MeshBufferPreset.BufferType.VN);
        _mCsKernelContourRasterization.SetLineDrawingBuffers(
            // Major buffers
            LineDrawingBuffers.BufferRawContourToEdge,
            LineDrawingBuffers.BufferRawRasterDataPerContour,
            LineDrawingBuffers.BufferRawFlagsPerContour,
            LineDrawingBuffers.BufferRawContourToSegment,
            // Utility buffers
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.BufferRawLookBacks,
            // Dispatch args
            LineDrawingBuffers.DispatchIndirectArgs1,
            // Debug
            LineDrawingBuffers.BufferRawDebug
        );
        // _mCsKernelContourRasterization.SetExternalTextures(
        //     (HiZPass.HizTexture,
        //         new RenderTargetIdentifier(HiZPass.HizTexture))
        // );


        // Segment Allocation Shader
        shaderHandle = SegmentAllocationShader;
        currentKernel = 0;
        currentShader = CS(shaderHandle);

        _mCsSegmentAllocation = currentShader;
        SetCameraVectorPropHandles(
            shaderHandle,
            (int)LineDrawingProps.PropTypes.ScreenTexelSize
        );
        _mCsKernelSegmentAllocationUpSweep = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelSegmentAllocationUpSweep.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawContourToSegment,
            LineDrawingBuffers.BufferRawRasterDataPerSeg, // temp scan buffer
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.BufferRawLookBacks,
            // Debug
            LineDrawingBuffers.BufferRawDebug
        );

        _mCsKernelSegmentAllocationReduce = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelSegmentAllocationReduce.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawLookBacks
        );
        _mCsKernelSegmentAllocationReduce.SetupNumGroupsBy1D(1);

        _mCsKernelSegmentAllocationDwsweep = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelSegmentAllocationDwsweep.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawContourToSegment,
            LineDrawingBuffers.BufferRawRasterDataPerSeg, // temp scan buffer
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.BufferRawLookBacks,
            // Dispatch Args
            LineDrawingBuffers.DispatchIndirectArgs,
            LineDrawingBuffers.DispatchIndirectArgsPerContourSegment,
            LineDrawingBuffers.DispatchIndirectArgsTwoContourSegment,
            // Debug
            LineDrawingBuffers.BufferRawDebug
        );


        // Segment Setup CS
        // ---------------------
        shaderHandle = SegmentSetupShader;
        currentKernel = 0;
        currentShader = CS(shaderHandle);

        _mCsSegmentSetup = currentShader;

        _mCsKernelCleanDataPerSeg = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelCleanDataPerSeg.SetLineDrawingBuffers(
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.BufferRawSegmentsToContour,
            LineDrawingBuffers.DispatchIndirectArgs1
        );

        _mCsKernelContourToSegs = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelContourToSegs.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawContourToSegment,
            LineDrawingBuffers.BufferRawSegmentsToContour,
            LineDrawingBuffers.BufferRawLookBacks,
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.DispatchIndirectArgs
        );


        // Segment Setup CS
        // ---------------------
        shaderHandle = SegmentToContourShader;
        currentKernel = 0;
        currentShader = CS(shaderHandle);

        _mCsSegmentToContourUpdated = currentShader;

        _mCsKernelSegmentToContourUpSweep = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelSegmentToContourUpSweep.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawContourToSegment,
            LineDrawingBuffers.BufferRawSegmentsToContour,
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.BufferRawRasterDataPerSeg,
            LineDrawingBuffers.BufferRawLookBacks,
            // debug only
            LineDrawingBuffers.BufferRawDebug
        );

        _mCsKernelSegmentToContourReduce = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelSegmentToContourReduce.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawLookBacks
        );
        _mCsKernelSegmentToContourReduce.SetupNumGroupsBy1D(1);

        _mCsKernelSegmentToContourDwsweep = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelSegmentToContourDwsweep.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawContourToSegment,
            LineDrawingBuffers.BufferRawSegmentsToContour,
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.DispatchIndirectArgs1,
            LineDrawingBuffers.BufferRawRasterDataPerSeg,
            LineDrawingBuffers.BufferRawLookBacks,
            // debug only
            LineDrawingBuffers.BufferRawDebug
        );


        // Segment Visibility CS
        // -----------------------------
        shaderHandle = SegmentVisibilityShader;
        currentKernel = 0;
        currentShader = CS(shaderHandle);

        _mCsSegmentVisibility = currentShader;

        SetCameraVectorPropHandles(
            shaderHandle,
            (int)LineDrawingProps.PropTypes.ScreenTexelSize
        );

        _mCsKernelSegmentVisibility = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelSegmentVisibility.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawRasterDataPerContour,
            LineDrawingBuffers.BufferRawSegmentsToContour,
            LineDrawingBuffers.BufferRawContourToSegment,
            LineDrawingBuffers.BufferRawFlagsPerSegment,
            LineDrawingBuffers.BufferRawRasterDataPerSeg,
            LineDrawingBuffers.BufferRawVEdgeToSegment,
            LineDrawingBuffers.BufferRawStampPixels,
            LineDrawingBuffers.BufferRawVisibleSegToSeg,
            LineDrawingBuffers.BufferRawLookBacks1,
            LineDrawingBuffers.BufferRawLookBacks,
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            // Dispatch Args
            LineDrawingBuffers.DispatchIndirectArgs
        );
        _mCsKernelSegmentVisibility.SetLineDrawingTextures(
            LineDrawingTextures.PerPixelSpinLockTexture,
            LineDrawingTextures.ReProjectionTexture,
            // Debug only
            LineDrawingTextures.DebugTexture
        );


        shaderHandle = RadixSortShader;
        currentKernel = 0;
        currentShader = CS(shaderHandle);

        _mCsRadixSort = currentShader;

        _mCsKernelClearGlobalHistogram = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelClearGlobalHistogram.SetLineDrawingBuffers(
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.DispatchIndirectArgs,
            LineDrawingBuffers.DispatchIndirectArgs1,
            LineDrawingBuffers.StructuredKeyValuePairs.handle,
            LineDrawingBuffers.StructuredGlobalDigitStart.handle);

        _mCsKernelBuildGlobalHistogram = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelBuildGlobalHistogram.SetLineDrawingBuffers(
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.DispatchIndirectArgs,
            LineDrawingBuffers.DispatchIndirectArgs1,
            LineDrawingBuffers.StructuredKeyValuePairs.handle,
            LineDrawingBuffers.StructuredGlobalDigitStart.handle);


        shaderHandle = ContourPixelExtractionShader;
        currentKernel = 0;
        currentShader = CS(shaderHandle);

        _mCsPixelExtraction = currentShader;

        _mCsKernelSegToPixel = ExtractKernel(shaderHandle, ref currentKernel);
        _mCsKernelSegToPixel.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawFlagsPerSegment,
            LineDrawingBuffers.BufferRawStampPixels,
            LineDrawingBuffers.BufferRawVisibleSegToSeg,
            LineDrawingBuffers.BufferRawLookBacks,
            LineDrawingBuffers.BufferRawLookBacks1,
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.StampDrawIndirectArgs,
            LineDrawingBuffers.FragmentDrawIndirectArgs,
            LineDrawingBuffers.DispatchIndirectArgs1,
            LineDrawingBuffers.StructuredTempBuffer1.handle,
            // Debug
            LineDrawingBuffers.BufferRawDebug
        );
    }

    /// <summary>
    /// Setup async data.
    /// </summary>
    /// <param name="dataAsync"></param>
    public override void SetupDataAsync(
        List<ILineDrawingData> dataAsync
    ){
        // LDM --------------------------------------------
        _mLineDrawingMaster = dataAsync[LineDrawingDataTypes.Master] as LineDrawingMaster;

        // Buffer Pool ------------------------------------
        _mBufferPool = dataAsync[LineDrawingDataTypes.Buffers] as LineDrawingBuffers;
        if (_mBufferPool != null)
        {
            List<CsKernel> kernels = ExtractAllComputeKernels(this);
            // Buffers need to match with thread group sizes in 
            // kernels that they are currently bond with
            _mBufferPool.ConfigureBufferGranularity(
                kernels.ToArray()
            );
        }
        
        
        // Textures ---------------------------------------
        _mTexturePool = dataAsync[LineDrawingDataTypes.Textures] as LineDrawingTextures;

        
        // CameraProps ------------------------------------
        _mCameraProps = dataAsync[LineDrawingDataTypes.CameraProps] as LineDrawingProps;
        if (_mCameraProps != null)
        {
            // Vector Handles & Matrix handles
            for (int i = 0; i < NumComputeShaders; i++)
            {
                if (_mCSCameraVectorProps[i] != null)
                {
                    // Fetch-Swap
                    int[] vectorHandles = _mCameraProps.VectorHandles(_mCSCameraVectorProps[i]);
                    _mCSCameraVectorProps[i] = vectorHandles; // swap
                }

                if (_mCSCameraMatrixProps[i] != null)
                {
                    int[] matrixHandles = _mCameraProps.MatrixHandles(_mCSCameraMatrixProps[i]);
                    _mCSCameraMatrixProps[i] = matrixHandles;
                }
            }
        }

        // Control Panel, containing parameters to interact with
        _mControlPanel = dataAsync[LineDrawingDataTypes.ControlPanel] as LineDrawingControlPanel;

        // Append to cmd-user list, for auto cmd-connect
        CmdUserList.Add(_mBufferPool);
        CmdUserList.Add(_mTexturePool);

        // Update flag(s)
        _asyncDataLoaded = true;
    }


    // -------------------------------------------------------
    // This method is called before executing the render pass.
    // -------------------------------------------------------
    // It can be used to configure render targets and their clear state. 
    // Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // -------------------------------------------------------
    // You should never call CommandBuffer.SetRenderTarget. 
    // Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // -------------------------------------------------------
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
    }


    // -------------------------------------------------------
    // Here you can implement the rendering logic.
    // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
    // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
    // You don't have to call ScriptableRenderContext.submit, 
    // the render pipeline will call it at specific points in the pipeline.
    public override void Execute(
        ScriptableRenderContext context,
        ref RenderingData renderingData
    )
    {
        // ++Note++----------------------------------------------

        #region How to use CommandBuffer with ProfilingSampler

        // 1) Your command buffer name must match your BeginSample/EndSample name,
        // otherwise Unity will throw errors about BeginSample/EndSample must match.
        //
        // 2) If you want to nest 2-level of BeginSample/EndSamples, as in:
        //
        // BeginA
        // BeginB/EndB
        // BeginC/EndC
        // EndA
        //
        // What you need is 2 command buffer,
        // in short,
        // Unity won't allow you to nest BeginSample/EndSample in a single CB.
        //
        // 3) always ExecuteCommandBuffer() and Clear()f
        // after BeginSample as well as EndSample,
        // doing this is redundant in some cases (in some cases you can reuse CB),
        // but it's always safe to just run them.

        #endregion

        // Note: use CommandBufferPool can bring critical perf hit.
        // _mCmd = CommandBufferPool.Get(_mProfilerTag);
        CMD = new CommandBuffer {name = MProfilerTag};
        CMD.Clear();

        ConnectCmdWithUsers();
        ConnectShaderResourceWithUsers(_mBufferPool, _mTexturePool);

        bool fixExtractionResult = false;

        // -----------------------------------------
        // Update & Bind Camera Params
        Camera camera = renderingData.cameraData.camera;
        UpdatePerCameraData(camera, CMD);

        for (int i = 0; i < NumComputeShaders; i++)
        {
            if (fixExtractionResult &&
                i == ExtractionShader &&
                _frameCounter >= 1) continue;
            BindCameraVectorPropsWithCS(i);
            BindCameraMatrixPropsWithCS(i);
        }

        #region Debug Frustum Clipper

        // if (_fixCamera && _frameCounter == 0)
        {
            // Fix VP matrix for debugging frustum clipper in
            // kernel::ContourSetup_Rasterization
            Matrix4x4 V = LineDrawingProps.GetViewTransformMatrix(camera);
            Matrix4x4 P = LineDrawingProps.GetProjectionTransformMatrix(camera);
            CS(ContourSetupShader).SetMatrix(
                "CMatrix_VP_Initial", P * V);
        }

        #endregion

        // -------------------------------------------
        // Update all LDO(Line Drawing Object)s' params
        UpdatePerMeshData(camera, CMD);

        LineDrawingObject mesh = _mLineDrawingMaster.ldosBatched;
        // ----------------------------------------------
        // Mesh Params <== Bind ==> ComputeShaders
        if ((!fixExtractionResult) || _frameCounter < 1)
        {
            mesh.BindMeshConstantWith(CMD, _mCsExtraction);
            mesh.BindMeshMatricesWith(CMD, _mCsExtraction);
            mesh.BindMeshVectorsWith(CMD, _mCsExtraction);
        }

        mesh.BindMeshConstantWith(CMD, _mCsCompaction);
        mesh.BindMeshMatricesWith(CMD, _mCsContourSetup);

        // Util debug parameters
        CMD.SetGlobalVector(
            "_DebugParams", _mControlPanel.DebugParams()
        );

        // ----------------------------------------------
        // Setup Kernel Size
        int faceCount = mesh.meshBufferSrc.TriangleCount;
        int vertCount = mesh.meshBufferSrc.VertexCount;
        int edgeCount = mesh.meshBufferSrc.NumNonConcaveEdges + CanvasEdgeCount;
        int triCountRounded = // Round them by 8 by the need of compaction
            8 * Mathf.CeilToInt(faceCount / 8f);
        int workSize = 1;
        // threading per vert -----------------------
        workSize = vertCount;
        _mCsKernelPerV.SetupNumGroupsBy1D(workSize);

        // threading per face -----------------------
        workSize = triCountRounded;
        _mCsKernelPerF.SetupNumGroupsBy1D(workSize);

        // threading per internal edge / 8 -------------------------
        workSize = Mathf.CeilToInt(edgeCount / 8f);
        _mCsKernelCompaction.SetupNumGroupsBy1D(workSize);

        // threading per internal edge -----------------------------
        // Make sure this kernel cleans every slot in output buffer
        // later compaction will need it
        workSize = math.max(
            edgeCount,
            8 * _mCsKernelCompaction.GroupsPerDispatch.x *
            _mCsKernelCompaction.ThreadsPerGroup.x
        );
        _mCsKernelPerE.SetupNumGroupsBy1D(workSize);

        // threading per internal edge ---------------------
        _mCsKernelContourIndirection.SetupNumGroupsBy1D(workSize);



        // Fragments are generated in a higher resolution
        // See "CustomShaderInputs.hlsl"
        // TODO: Integrate these binding ops into control panel
        int stampMultiSample = 2;
        CMD.SetGlobalInt(
            "_StampMS",
            stampMultiSample
        );
        CMD.SetGlobalFloat(
            "_RCP_StampMS",
            1.0f / stampMultiSample
        );
        CMD.SetGlobalInt(
            "_FrameCounter",
            _frameCounter
        );
        CMD.SetGlobalFloat(
            _mControlPanel.StrokeWidth.id,
            _mControlPanel.StrokeWidth.scale
        );
        CMD.SetGlobalFloat(
            _mControlPanel.StrokeLength.id,
            _mControlPanel.StrokeLength.scale
        );
        CMD.SetGlobalVector(
            _mControlPanel.StrokeScaleRange.id,
            _mControlPanel.StrokeScaleRange.scaleMinMax
        );


        // ---------------------------------------------------
        // Bind Compute Buffers & Dispatch Compute Kernel(s)
        #region Start point of dispatches, Reset args
        // Reset argument buffers
        _mCsKernelClearArgs.LineDrawingDispatch();
        // _mBufferPool.ResetArgs(
        //     LineDrawingBuffers.StampDrawIndirectArgs,
        //     new uint[] { 0, 1, 0, 0 });
        // _mBufferPool.ResetArgs(
        //     LineDrawingBuffers.FragmentDrawIndirectArgs,
        //     new uint[] { 0, 1, 0, 0 });
        // _mBufferPool.ResetArgs(
        //     LineDrawingBuffers.ContourDrawIndirectArgs,
        //     new uint[] { 0, 1, 0, 0 });
        // _mBufferPool.ResetArgs(
        //     LineDrawingBuffers.FaceDrawIndirectArgs,
        //     new uint[] { 0, 1, 0, 0 });
        // _mBufferPool.dispatchIndirectSwapChain.ResetCommand(CMD); // ? -> 1
        // IndirectDispatcher.ResetAllArgsCommand(CMD);
        #endregion

        

        _mCsKernelPerV.BindWithMeshDataGPU(mesh.meshDataGPU);
        // _mCsKernelPerV.LineDrawingDispatch();

        { // Apply contour test for edges -----------------------
            // 1. Compute each face's orientation in object space,
            // -- back-face culling also happens here.
            _mCsKernelPerF.BindWithMeshDataGPU(mesh.meshDataGPU);
            _mCsKernelPerF.LineDrawingDispatch();
            // 2. Apply contour test for each edge
            _mCsKernelPerE.BindWithMeshDataGPU(mesh.meshDataGPU);
            _mCsKernelPerE.LineDrawingDispatch();
        } // ----------------------------------------------------
        
        
        { // Stream Reduction by only picking contour edges to process
            // A prefix-sum kernel based on if an edge is contour
            _mCsKernelCompaction.LineDrawingDispatch();
            // Build Contour to Edge Mapping
            _mCsKernelContourIndirection.LineDrawingDispatch();
        } // ----------------------------------------------------



        IndirectDispatcher.SetCurrent(
            LineDrawingBuffers.DispatchIndirectArgsPerMeshContour);
        { // Apply coord transform & culling & clipping for contours ------------
            _mCsKernelContourRasterization.BindWithMeshDataGPU(mesh.meshDataGPU);
            _mCsKernelContourRasterization.LineDrawingDispatchIndirect();
        } // --------------------------------------------------------------------
        { // Build Contour to Segment Mapping --------------------------
            _mCsKernelSegmentAllocationUpSweep.LineDrawingDispatchIndirect();
            _mCsKernelSegmentAllocationReduce.LineDrawingDispatch();
            _mCsKernelSegmentAllocationDwsweep.LineDrawingDispatchIndirect();
        } // -----------------------------------------------------------



        IndirectDispatcher.SetCurrent(
            LineDrawingBuffers.DispatchIndirectArgsPerContourSegment);
        { // Build Segments to Contour Mapping ----------------------
            // 1. Clean Segments to Contour Table
            _mCsKernelCleanDataPerSeg.LineDrawingDispatchIndirect();
            
            // 2. Seed Segment Table From Contours
            IndirectDispatcher.SetCurrent(
                LineDrawingBuffers.DispatchIndirectArgsPerMeshContour);
            _mCsKernelContourToSegs.LineDrawingDispatchIndirect();

            // 3. Build mapping segment->contour via a max-scan
            IndirectDispatcher.SetCurrent(
                LineDrawingBuffers.DispatchIndirectArgsTwoContourSegment);
            _mCsKernelSegmentToContourUpSweep.LineDrawingDispatchIndirect();
            _mCsKernelSegmentToContourReduce.LineDrawingDispatch();
            _mCsKernelSegmentToContourDwsweep.LineDrawingDispatchIndirect();
            IndirectDispatcher.SetCurrent(
                LineDrawingBuffers.DispatchIndirectArgsPerContourSegment);
        } // ---------------------------------------------------------


        { // Segment Visibility --------------------------------------
            mesh.BindMeshMatricesWith(CMD, _mCsSegmentVisibility);
            _mCsKernelSegmentVisibility.LineDrawingDispatchIndirect();
        } // ---------------------------------------------------------


        { // Utility only, set some counters & args ----------------
            // Actually, this should 've been deprecated
            _mCsKernelSegToPixel.SetupNumGroups1D(1);
            _mCsKernelSegToPixel.LineDrawingDispatch();
        } // --------------------------------------------------



        // 近实远虚、明少暗多、硬粗软�?
        #region ------ * WIP, Deactivated * Radix Sort * ------

        // _mBufferPool.dispatchIndirectSwapChain.Swap(_mCmd);
        // _mBufferPool.BindPassBuffersCommand(
        //     _mCmd,
        //     _mCsRadixSort,
        //     _mCsKernelClearGlobalHistogram);
        // _mCsKernelClearGlobalHistogram.DispatchIndirectViaCmd(
        //     _mCmd, _mBufferPool.dispatchIndirectSwapChain.Front());
        //
        // _mBufferPool.dispatchIndirectSwapChain.Swap(_mCmd);
        // _mBufferPool.BindPassBuffersCommand(
        //     _mCmd,
        //     _mCsRadixSort,
        //     _mCsKernelBuildGlobalHistogram);
        // _mCsKernelBuildGlobalHistogram.DispatchIndirectViaCmd(
        //     _mCmd, _mBufferPool.dispatchIndirectSwapChain.Front());

        #endregion


        context.ExecuteCommandBuffer(CMD);
        CMD.Clear();
    }

    private const int CanvasEdgeCount = 4;

    /// Cleanup any allocated resources that were created 
    /// during the execution of this render pass.
    public override void FrameCleanup(CommandBuffer cmd)
    {
        // Disconnect & Clear command buffer
        _mTexturePool.DisconnectCmd();
        _mBufferPool.DisconnectCmd();
        CMD.Release();
        // Debug
        FrameCounterIncrement();
    }

    bool ILineDrawingDataUser.AsyncDataLoaded()
    {
        return _asyncDataLoaded;
    }
}