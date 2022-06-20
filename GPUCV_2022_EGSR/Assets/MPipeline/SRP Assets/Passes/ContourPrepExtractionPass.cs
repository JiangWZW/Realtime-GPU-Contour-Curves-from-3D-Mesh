using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.Custom_Data.PerCameraData;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ContourPrepExtractionPass : LineDrawingRenderPass, ILineDrawingDataUser
{
    public ContourPrepExtractionPass(string tag, RenderPassEvent passEvent)
    : base(tag, passEvent)
    {
        var setting = new PassSetting(tag, passEvent);
        SetupLineDrawingComputeShaders(this, setting);
    }

    protected override void LoadLineDrawingComputeShaders(
        PassSetting setting)
    {
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

        // ---------------------------------------------------
        // Bind Compute Buffers & Dispatch Compute Kernel(s)
        #region Start point of dispatches, Reset args
        // Reset argument buffers
        _mBufferPool.ResetArgs(
            LineDrawingBuffers.StampDrawIndirectArgs,
            new uint[] { 0, 1, 0, 0 });
        _mBufferPool.ResetArgs(
            LineDrawingBuffers.FragmentDrawIndirectArgs,
            new uint[] { 0, 1, 0, 0 });
        _mBufferPool.ResetArgs(
            LineDrawingBuffers.ContourDrawIndirectArgs,
            new uint[] { 0, 1, 0, 0 });
        _mBufferPool.ResetArgs(
            LineDrawingBuffers.FaceDrawIndirectArgs,
            new uint[] { 0, 1, 0, 0 });
        _mBufferPool.dispatchIndirectSwapChain.ResetCommand(CMD); // ? -> 1
        IndirectDispatcher.ResetAllArgsCommand(CMD);
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
}