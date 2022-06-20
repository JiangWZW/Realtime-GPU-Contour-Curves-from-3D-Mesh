using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.Custom_Data.PerCameraData;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MPipeline.SRP_Assets.Passes
{
    /// <inheritdoc cref="UnityEngine.Rendering.Universal.ScriptableRenderPass" />
    public class ContourSegmentRemergePass : LineDrawingRenderPass
    {
        // Compute Shader & Kernels
        private ComputeShader _mCsPixelEdgeFiltering;
        private CsKernel _mCsKernelSetupStrokeRemerge;

        private int _MaxSmallSegLen;
        private int _MinLargeSegLen;

        public ContourSegmentRemergePass(
            string tag, RenderPassEvent passEvent, 
            int maxSmallSegLen, int minLargeSegLen
        ) : base(tag, passEvent)
        {
            var passSetting = new PassSetting(
                tag, passEvent,
                new PassSetting.ComputeShaderSetting(
                    "Shaders/StampContourFiltering",
                    "StampContourFiltering",
                    new[]
                    {
                        "ReMergeSegments",
                    }
                )
            );
            SetupLineDrawingComputeShaders(this, passSetting);

            _MaxSmallSegLen = maxSmallSegLen;
            _MinLargeSegLen = minLargeSegLen;
        }

        protected override void LoadLineDrawingComputeShaders(
            PassSetting setting
        ) {
            // Compute Shaders & Kernels
            int kernelHandle = 0;
            int shaderHandle = 0;
            PassSetting.ComputeShaderSetting csSetting;

            
            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeFiltering = ExtractComputeShader(csSetting);

            kernelHandle = 0;

            _mCsKernelSetupStrokeRemerge = ExtractComputeKernel(
                    csSetting, _mCsPixelEdgeFiltering, kernelHandle++);
            _mCsKernelSetupStrokeRemerge.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.DispatchIndirectArgs,
                LineDrawingBuffers.StampDrawIndirectArgs,
                LineDrawingBuffers.BufferRawLookBacks,
                LineDrawingBuffers.BufferRawRasterDataPerSeg,
                LineDrawingBuffers.StructuredTempBuffer1.handle,
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels);
            _mCsKernelSetupStrokeRemerge.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1);


            // ------------------------------------------------------

        }


        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in an performance manner.
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        { }

      

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        public override void Execute(
            ScriptableRenderContext context,
            ref RenderingData renderingData
        )
        {
            // Set command buffers, connect it with data pools
            CMD = new CommandBuffer {name = MProfilerTag};
            CMD.Clear();

            ConnectCmdWithUsers();
            ConnectShaderResourceWithUsers(_mBufferPool, _mTexturePool);


            IndirectDispatcher.SetCurrent(
                LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge);
            SetParams_mCsPixelEdgeFiltering();
            _mCsKernelSetupStrokeRemerge.LineDrawingDispatchIndirect();


            // You don't have to call ScriptableRenderContext.submit,
            // the render pipeline will call it at specific points in the pipeline.
            context.ExecuteCommandBuffer(CMD);
            CMD.Clear();
        }



        /// Cleanup any allocated resources that were created during the execution of this render pass.
        public override void FrameCleanup(CommandBuffer cmd)
        {
            CMD.Dispose();

            _frameCounter++;
            if (_frameCounter >= int.MaxValue - 1)
            {
                _frameCounter = 8; // reset
            }
        }

        private void SetParams_mCsPixelEdgeFiltering()
        {
            CMD.SetComputeIntParam(
                _mCsPixelEdgeFiltering,
                "_MaxSmallSegLen", _MaxSmallSegLen
            );
            CMD.SetComputeIntParam(
                _mCsPixelEdgeFiltering,
                "_MinLargeSegLen", _MinLargeSegLen
            );
        }

    }
}