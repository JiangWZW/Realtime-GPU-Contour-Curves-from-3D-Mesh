using System;
using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.Custom_Data.PerCameraData;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MPipeline.SRP_Assets.Passes
{
    /// <inheritdoc cref="UnityEngine.Rendering.Universal.ScriptableRenderPass" />
    /// <remarks>
    /// TODO: Contour Segmentation Logic still remained coupled in
    /// <see cref="ContourSegmentationPass"/>. <br/>
    /// Any large change here should be applied to there also; <br/>
    /// Or, accomplish the decoupling before apply the change.
    /// </remarks> 
    public class ContourSegmentationPass : LineDrawingRenderPass
    {
        // Compute Shader & Kernels
        private ComputeShader _mCsPixelEdgeLoopSegmentation;
        private CsKernel _mCsKernelEdgeLoopSegmentationInit;
        private CsKernel _mCsKernelEdgeLoopSegmentationStepA;
        private CsKernel _mCsKernelEdgeLoopSegmentationStepB;
        private CsKernel _mCsKernelEdgeLoopSegmentationStepC;

        public class InputBuffer
        {
            public static int GPUControlled = -1;
            public int BufferID;
        }
        public InputBuffer _SegmentInput;

        // Match Definition in
        // in "CBuffer_BufferRawPixelEdgeData_View.hlsl"
        // in "ContourVectorizationPass.cs"
        public class OutputBuffer
        { // For history reason, param buffer is connected to frame counter
            // Which should be deprecated but I don't have time for this
            public static Func<int, int> GPUControlled 
                = frameCounter => -1;
            public static Func<int, int> StrokeParams // EDGE_PARAM_STROKE
                = frameCounter => (frameCounter % 2);
            public static Func<int, int> PathParams // EDGE_PARAM_BRUSH_PATH
                = frameCounter => (2 + (frameCounter % 2));

            public Func<int, int> GetBufferID;
        }
        public OutputBuffer _SegmentOutput;

        // Whether update circular topo.
        // Some segmentation wont break/retrieve loop topo
        private bool _UpdateStrokeInfoToStamps;


        public ContourSegmentationPass(
            string tag, RenderPassEvent renderEvent
        ) : base(tag, renderEvent)
        {
            PassSetting ldPassSetting =
                new PassSetting(
                    tag, renderEvent,
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/ContourEdgeLoopSegmentation",
                        "ContourEdgeLoopSegmentation",
                        new[]
                        {
                            "SetupResources",
                            "StepA",
                            "StepB",
                            "StepC"
                        }
                    )
                );
            SetupLineDrawingComputeShaders(this, ldPassSetting);


            _SegmentInput = new InputBuffer
            {
                BufferID = InputBuffer.GPUControlled
            };
            _SegmentOutput = new OutputBuffer
            {
                GetBufferID = OutputBuffer.GPUControlled
            };
            _UpdateStrokeInfoToStamps = true;
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
            _mCsPixelEdgeLoopSegmentation = ExtractComputeShader(csSetting);

            kernelHandle = 0;

            _mCsKernelEdgeLoopSegmentationInit = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeLoopSegmentation, kernelHandle++);
            _mCsKernelEdgeLoopSegmentationInit.SetLineDrawingBuffers(
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1, 
                LineDrawingBuffers.BufferRawLookBacks, 
                LineDrawingBuffers.BufferRawLookBacks1
            );
            _mCsKernelEdgeLoopSegmentationInit.SetupNumGroups1D(8); // match hlsl

            _mCsKernelEdgeLoopSegmentationStepA = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeLoopSegmentation, kernelHandle++);
            _mCsKernelEdgeLoopSegmentationStepA.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData, 
                LineDrawingBuffers.BufferRawStampLinkage, 
                LineDrawingBuffers.BufferRawLookBacks,
                LineDrawingBuffers.StructuredTempBuffer1.handle,
                LineDrawingBuffers.CachedArgs, 
                LineDrawingBuffers.CachedArgs1, 
                // Debug Only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelEdgeLoopSegmentationStepA.SetLineDrawingTextures(
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1
            );

            _mCsKernelEdgeLoopSegmentationStepB = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeLoopSegmentation, kernelHandle++);
            _mCsKernelEdgeLoopSegmentationStepB.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData, 
                LineDrawingBuffers.BufferRawStampLinkage, 
                LineDrawingBuffers.StructuredTempBuffer1.handle,
                LineDrawingBuffers.BufferRawLookBacks1,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                // Debug Only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelEdgeLoopSegmentationStepB.SetLineDrawingTextures(
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1
            );

            _mCsKernelEdgeLoopSegmentationStepC = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeLoopSegmentation, kernelHandle++);
            _mCsKernelEdgeLoopSegmentationStepC.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.StructuredTempBuffer1.handle,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                // Debug Only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelEdgeLoopSegmentationStepC.SetLineDrawingTextures(
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1
            );


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

            ExecuteEdgeLoopSegmentation();

            // You don't have to call ScriptableRenderContext.submit,
            // the render pipeline will call it at specific points in the pipeline.
            context.ExecuteCommandBuffer(CMD);
            CMD.Clear();
        }


        private void ExecuteEdgeLoopSegmentation()
        {
            IndirectDispatcher.SetCurrent(
                LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge);

            CMD.SetComputeIntParam(
                _mCsPixelEdgeLoopSegmentation,
                "_SegmentInput", _SegmentInput.BufferID
            );
            CMD.SetComputeIntParam(
                _mCsPixelEdgeLoopSegmentation,
                "_SegmentOutput", _SegmentOutput.GetBufferID(_frameCounter)
            );
            CMD.SetComputeIntParam(
                _mCsPixelEdgeLoopSegmentation,
                "_UpdateStrokeInfoToStamps", 
                _UpdateStrokeInfoToStamps ? 1 : 0
            );

            _mCsKernelEdgeLoopSegmentationInit.LineDrawingDispatch();
            _mCsKernelEdgeLoopSegmentationStepA.LineDrawingDispatchIndirect();
            _mCsKernelEdgeLoopSegmentationStepB.LineDrawingDispatchIndirect();
            _mCsKernelEdgeLoopSegmentationStepC.LineDrawingDispatchIndirect();
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
    }
}