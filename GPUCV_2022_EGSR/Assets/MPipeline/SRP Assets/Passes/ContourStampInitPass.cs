using System.Collections.Generic;
using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.Custom_Data.PerCameraData;
using MPipeline.Custom_Data.PerMesh_Data;
using MPipeline.SRP_Assets.Features;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MPipeline.SRP_Assets.Passes
{

    /// <inheritdoc cref="UnityEngine.Rendering.Universal.ScriptableRenderPass" />
    public class ContourStampInitPass : LineDrawingRenderPass
    {
        // Compute Shader & Kernels
        private ComputeShader _mCsStampInitAttribs;
        private CsKernel _mCsKernelInitStampAttribute;

        private ComputeShader _mCsResetIndirectDispatchArgs;
        private CsKernel _mCsKernelResetDispatchArgsToStampCount;
        private CsKernel _mCsKernelResetDispatchArgsToHalfStampCount;
        private CsKernel _mCsKernelResetDispatchArgsToPixelEdgeCount;
        private CsKernel _mCsKernelResetDispatchArgsToHalfPixelEdgeCount;

        protected override void LoadLineDrawingComputeShaders(LineDrawingRenderPass.PassSetting setting)
        {
            // Compute Shaders & Kernels
            int kernelHandle = 0;
            int shaderHandle = 0;

            // ----------------------------------------------------------
            LineDrawingRenderPass.PassSetting.ComputeShaderSetting
                csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsStampInitAttribs = ExtractComputeShader(csSetting);

            kernelHandle = 0;

            _mCsKernelInitStampAttribute = ExtractComputeKernel(
                csSetting, _mCsStampInitAttribs,
                kernelHandle++);
            _mCsKernelInitStampAttribute.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawRasterDataPerSeg,
                LineDrawingBuffers.BufferRawRasterDataPerContour,
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.BufferRawFlagsPerStamp,
                LineDrawingBuffers.BufferRawStampGBuffer,
                LineDrawingBuffers.BufferRawProceduralGeometry,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.DispatchIndirectArgs,
                LineDrawingBuffers.DispatchIndirectArgs1,
                LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge,
                LineDrawingBuffers.StampDrawIndirectArgs
            );
            _mCsKernelInitStampAttribute.SetLineDrawingTextures(
                LineDrawingTextures.ContourGBufferTexture,
                LineDrawingTextures.PerPixelSpinLockTexture,
                LineDrawingTextures.ReProjectionTexture,
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1
            );

            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsResetIndirectDispatchArgs = ExtractComputeShader(csSetting);

            kernelHandle = 0;

            _mCsKernelResetDispatchArgsToStampCount = ExtractComputeKernel(
                csSetting, _mCsResetIndirectDispatchArgs, kernelHandle++);
            _mCsKernelResetDispatchArgsToStampCount.SetLineDrawingBuffers(
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.DispatchIndirectArgs,
                LineDrawingBuffers.DispatchIndirectArgs1,
                LineDrawingBuffers.DispatchIndirectArgsPerStamp,
                LineDrawingBuffers.DispatchIndirectArgsTwoStamp
            );
            _mCsKernelResetDispatchArgsToStampCount.SetupNumGroupsBy1D(1);

            _mCsKernelResetDispatchArgsToHalfStampCount = ExtractComputeKernel(
                csSetting, _mCsResetIndirectDispatchArgs, kernelHandle++);
            _mCsKernelResetDispatchArgsToHalfStampCount.SetLineDrawingBuffers(
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.DispatchIndirectArgs,
                LineDrawingBuffers.DispatchIndirectArgs1,
                LineDrawingBuffers.DispatchIndirectArgsPerStamp
            );
            _mCsKernelResetDispatchArgsToHalfStampCount.SetupNumGroupsBy1D(1);

            _mCsKernelResetDispatchArgsToPixelEdgeCount = ExtractComputeKernel(
                csSetting, _mCsResetIndirectDispatchArgs, kernelHandle++);
            _mCsKernelResetDispatchArgsToPixelEdgeCount.SetLineDrawingBuffers(
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.DispatchIndirectArgs,
                LineDrawingBuffers.DispatchIndirectArgs1,
                LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge,
                LineDrawingBuffers.DispatchIndirectArgsTwoPixelEdge
            );
            _mCsKernelResetDispatchArgsToPixelEdgeCount.SetupNumGroupsBy1D(1);

            _mCsKernelResetDispatchArgsToHalfPixelEdgeCount = ExtractComputeKernel(
                csSetting, _mCsResetIndirectDispatchArgs, kernelHandle++);
            _mCsKernelResetDispatchArgsToHalfPixelEdgeCount.SetLineDrawingBuffers(
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.DispatchIndirectArgs,
                LineDrawingBuffers.DispatchIndirectArgs1,
                LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge
            );
        }


        // Material & Props for Drawing
        private Material _mDrawProceduralMaterial_Legacy;
        private MaterialPropertyBlock _mMatProps;
        private int[] _mMatPropsBufferPoolBindings;

        private static readonly Matrix4x4 DrawTransform = new Matrix4x4(
            new Vector4(1.0f, 0.0f, 0.0f, 1.0f),
            new Vector4(0.0f, 1.0f, 0.0f, 0.0f),
            new Vector4(0.0f, 0.0f, 1.0f, 0.0f),
            new Vector4(0.0f, 0.0f, 0.0f, 1.0f)
        );

        private void SetupProceduralDrawResources()
        {
            // Shader & Materials for Procedural Draw(s)
            _mDrawProceduralMaterial_Legacy = 
                LineDrawingMaterials.LineDrawingMaterial_Legacy();

            _mMatProps = new MaterialPropertyBlock();
            _mMatPropsBufferPoolBindings = new[]
            {
                LineDrawingBuffers.BufferRawRasterDataPerSeg,
                LineDrawingBuffers.BufferRawVisibleSegToSeg,
                LineDrawingBuffers.BufferRawFlagsPerSegment,
                // Debug only
                LineDrawingBuffers.CachedArgs
            };
        }

        public ContourStampInitPass(
            LineDrawingRenderPass.PassSetting setting
        ) : base(setting.profilerTag, setting.passEvent)
        {
            SetupLineDrawingComputeShaders(this, setting);
            SetupProceduralDrawResources();
        }


        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in an performance manner.
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            ConfigureTarget(
                _mTexturePool.RTIdentifier(
                    LineDrawingTextures.ContourGBufferTexture
                )
                // cameraDepth.Identifier()
            );
            ConfigureClear(ClearFlag.All, Color.black);
        }

      

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
            
            // Compute Buffers <== Bind ==> Draw Material
            _mBufferPool.BindBuffersMatPropsBlock(
                _mMatPropsBufferPoolBindings, _mMatProps
            );

            // Render
            CMD.DrawProceduralIndirect(
                DrawTransform,
                _mDrawProceduralMaterial_Legacy,
                7,
                MeshTopology.Points,
                _mBufferPool.DrawArgsForFragments(),
                0,
                _mMatProps
            );

            // Set target as globally visible
            _mTexturePool.SetGlobalTextureCommand(
                LineDrawingTextures.ContourGBufferTexture);
            
            // - Clear "_PerPixelSpinLockTex"
            CMD.SetRenderTarget(
                _mTexturePool.Texture(
                    LineDrawingTextures.PerPixelSpinLockTexture).Identifier
            );
            CMD.ClearRenderTarget(false, true, Color.black);

            // Initialize dispatch args
            _mCsKernelResetDispatchArgsToStampCount.LineDrawingDispatch();

            // ------------------------------------------------------------------
            // Initialize stamp attributes
            LineDrawingObject mesh = _mLineDrawingMaster.ldosBatched;
            IndirectDispatcher.SetCurrent(
                LineDrawingBuffers.DispatchIndirectArgsPerStamp
            );
            mesh.BindMeshMatricesWith(CMD, _mCsStampInitAttribs); // For reprojection
            _mCsKernelInitStampAttribute.LineDrawingDispatchIndirect();


            // You don't have to call ScriptableRenderContext.submit,
            // the render pipeline will call it at specific points in the pipeline.
            context.ExecuteCommandBuffer(CMD);
            CMD.Clear();
        }


        /// Cleanup any allocated resources that were created during the execution of this render pass.
        public override void FrameCleanup(CommandBuffer cmd)
        {
            CMD.Dispose();
            FrameCounterIncrement();
        }
    }
}