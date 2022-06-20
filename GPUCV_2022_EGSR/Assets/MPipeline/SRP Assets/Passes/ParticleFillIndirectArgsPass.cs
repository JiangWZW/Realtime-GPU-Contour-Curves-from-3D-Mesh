using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.Custom_Data.PerCameraData;
using MPipeline.SRP_Assets.Features;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

class ParticleFillIndirectArgsPass : LineDrawingRenderPass
{
    // Compute Shaders & Kernels
    private ComputeShader _mCsStrokeGeneratePBDData;
    private CsKernel _mCsKernelSetPBDDispatchArgs;


    public ParticleFillIndirectArgsPass(LineDrawingRenderPass.PassSetting setting)
        : base(setting.profilerTag, setting.passEvent)
    {
        SetupLineDrawingComputeShaders(this, setting);
    }

    protected override void LoadLineDrawingComputeShaders(
        LineDrawingRenderPass.PassSetting setting
    ){
        // Compute Shaders & Kernels
        var kernelHandle = 0;
        int shaderHandle = 0;
        LineDrawingRenderPass.PassSetting.ComputeShaderSetting csSetting = null;

        // ------------------------------------------------------
        csSetting = setting.computeShaderSetting[shaderHandle++];
        _mCsStrokeGeneratePBDData = ExtractComputeShader(csSetting);

        kernelHandle = 0;

        _mCsKernelSetPBDDispatchArgs = ExtractComputeKernel(
            csSetting, _mCsStrokeGeneratePBDData, kernelHandle++);
        _mCsKernelSetPBDDispatchArgs.SetLineDrawingBuffers(
            LineDrawingBuffers.StructuredTempBuffer1.handle,
            LineDrawingBuffers.DispatchIndirectArgsPBDSolver,
            LineDrawingBuffers.DispatchIndirectArgsPerPBDParticle,
            LineDrawingBuffers.DispatchIndirectArgsPBDStrainLimiting,
            LineDrawingBuffers.CachedArgs
        );
        _mCsKernelSetPBDDispatchArgs.SetupNumGroups1D(1);
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

        _mCsKernelSetPBDDispatchArgs.LineDrawingDispatch();

        context.ExecuteCommandBuffer(CMD);
        CMD.Clear();
    }


    // Cleanup any allocated resources that were created during the execution of this render pass.
    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        _mTexturePool.DisconnectCmd();
        _mBufferPool.DisconnectCmd();
        CMD.Release();

        FrameCounterIncrement();
    }
}