using System;
using System.Collections.Generic;
using Assets.MPipeline.SRP_Assets.Passes;
using Assets.Resources.Shaders;
using MPipeline.Custom_Data.PerCameraData;
using MPipeline.Custom_Data.PerMesh_Data;
using MPipeline.SRP_Assets.Features;
using MPipeline.SRP_Assets.Passes;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

class ContourMeshingPass : LineDrawingRenderPass
{
    // Compute Shaders & Kernels
    private ComputeShader _mCsSpawnContourVertices;
    private CsKernel _mCsKernelPathRegistration;
    private CsKernel _mCsKernelSetupStrokeVerts;

    public class VertexOutputFormat
    { // Match "_VertexOutputFormat" in <<_mCsSpawnParticleVertices>>
        public static int ScreenStroke = 0; // OUT_VERTS_CONTOUR_SCREEN
        public static int CoverageTest = 1; // OUT_VERTS_CONTOUR_COVERAGE

        public int CurrFormat;
    }
    public VertexOutputFormat VertexFormat;


    public ContourMeshingPass(string tag, RenderPassEvent passEvent)
        : base(tag, passEvent)
    {
        var passSetting = new PassSetting
        (
            tag, passEvent,

            new PassSetting.ComputeShaderSetting(
                "Shaders/StampVertexGenerator",
                "StampVertexGenerator",
                new[]
                {
                    "PathRegistration",
                    "EdgeStylization",
                }
            ),
            new PassSetting.ComputeShaderSetting(
                "Shaders/ParticleVertexGenerator",
                "ParticleVertexGenerator",
                new[]
                {
                    "PathRegistration",
                    "ComputePathVerts",
                }
            ),
            new PassSetting.ComputeShaderSetting(
                "Shaders/ResetIndirectDispatchArgs",
                "ResetIndirectDispatchArgs",
                new[]
                {
                    "ToStampCount",
                }
            )
        );

        SetupLineDrawingComputeShaders(this, passSetting);

        VertexFormat = new VertexOutputFormat
        {
            CurrFormat = VertexOutputFormat.ScreenStroke
        };
    }

    protected override void LoadLineDrawingComputeShaders(
        LineDrawingRenderPass.PassSetting setting
    ){
        // Compute Shaders & Kernels
        int kernelHandle = 0;
        int shaderHandle = 0;
        LineDrawingRenderPass.PassSetting.ComputeShaderSetting csSetting = null;

        // ------------------------------------------------------
        csSetting = setting.computeShaderSetting[shaderHandle++];
        _mCsSpawnContourVertices = ExtractComputeShader(csSetting);

        kernelHandle = 0;

        _mCsKernelPathRegistration = ExtractComputeKernel(
            csSetting, _mCsSpawnContourVertices, kernelHandle++);
        _mCsKernelPathRegistration.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawPixelEdgeData,
            LineDrawingBuffers.BufferRawStampLinkage,
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.StructuredTempBuffer1.handle
        );


        _mCsKernelSetupStrokeVerts = ExtractComputeKernel(
            csSetting, _mCsSpawnContourVertices, kernelHandle++);
        _mCsKernelSetupStrokeVerts.SetLineDrawingBuffers(
            LineDrawingBuffers.BufferRawProceduralGeometry,
            LineDrawingBuffers.BufferRawPixelEdgeData,
            LineDrawingBuffers.BufferRawStampPixels,
            LineDrawingBuffers.BufferRawFlagsPerStamp,
            LineDrawingBuffers.BufferRawStampLinkage,
            LineDrawingBuffers.BufferRawStampGBuffer,
            LineDrawingBuffers.CachedArgs,
            LineDrawingBuffers.CachedArgs1,
            LineDrawingBuffers.StructuredTempBuffer1.handle,
            LineDrawingBuffers.StampDrawIndirectArgs, 
            LineDrawingBuffers.ContourCoverageTestDrawIndirectArgs
        );
        _mCsKernelSetupStrokeVerts.SetLineDrawingTextures(
            LineDrawingTextures.ReProjectionTexture,
            // Debug only
            LineDrawingTextures.DebugTexture);
    }


    public override void SetupDataAsync(
        List<ILineDrawingData> perCameraDataList
    )
    {
        base.SetupDataAsync(perCameraDataList);
        
        // Setup interactive textures from control panel
        _mCsKernelSetupStrokeVerts.SetExternalTextures(
            (
                _mControlPanel.CurvatureCurve.shaderPropertyID, 
                _mControlPanel.CurvatureCurve
            ),
            (
                _mControlPanel.CurveShape.shaderPropertyID, 
                _mControlPanel.CurveShape
            ),
            (
                _mControlPanel.DepthCurve.shaderPropertyID, 
                _mControlPanel.DepthCurve
            ), 
            (
                Shader.PropertyToID("_CameraColorAttachmentA"),
                "_CameraColorAttachmentA"
            )
        );
    }


    // This method is called before executing the render pass.
    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in a performant manner.
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    { 
    }

    // Here you can implement the rendering logic.
    // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
    // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
    // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        // Set command buffers, connect it with data pools
        CMD = new CommandBuffer {name = MProfilerTag};
        CMD.Clear();
        ConnectCmdWithUsers(); // Users: kernel, texture/buffer-pools
        ConnectShaderResourceWithUsers(_mBufferPool, _mTexturePool);


        IndirectDispatcher.SetCurrent(
            LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge);
        SetParams_mCsSpawnContourVertices();
        _mCsKernelPathRegistration.LineDrawingDispatchIndirect();
        // if ((VertexFormat.CurrFormat != VertexOutputFormat.CoverageTest))
        SetParams_mCsSpawnContourVertices();
        _mCsKernelSetupStrokeVerts.BindExternalTexturesCommand();
        _mCsKernelSetupStrokeVerts.LineDrawingDispatchIndirect();
        


        context.ExecuteCommandBuffer(CMD);
        CMD.Clear();
    }

    // Cleanup any allocated resources that were created during the execution of this render pass.
    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        CMD.Dispose();

        FrameCounterIncrement();
    }

    private void SetParams_mCsSpawnContourVertices()
    {
        CMD.SetComputeFloatParam(_mCsSpawnContourVertices,
            _mControlPanel.StrokeLength.id, _mControlPanel.StrokeLength.scale
        );
        CMD.SetComputeFloatParam(_mCsSpawnContourVertices,
            _mControlPanel.StrokeWidth.id, _mControlPanel.StrokeWidth.scale
        );
        CMD.SetComputeVectorParam(_mCsSpawnContourVertices,
            "_CurvatureParams", _mControlPanel.CurvatureParameters
        );
        CMD.SetComputeVectorParam(_mCsSpawnContourVertices,
            "_DepthParams", _mControlPanel.DepthParameters
        );
        
        CMD.SetComputeIntParam(
            _mCsSpawnContourVertices,
            "_RenderPath",
            (VertexFormat.CurrFormat == VertexOutputFormat.ScreenStroke) 
                ? (_mControlPanel.RenderVectorizedCurves ? 1 : 0)
                : 1
        );
        CMD.SetComputeIntParam(
            _mCsSpawnContourVertices,
            "_VertexOutputFormat",
            VertexFormat.CurrFormat
        );

        CMD.SetComputeFloatParam(
            _mCsSpawnContourVertices,
            "_CoverageRadius",
            10.0f // TODO: match against particle coverage verts
        );
    }
}