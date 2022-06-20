using System.Collections.Generic;
using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.SRP_Assets.Features;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MPipeline.SRP_Assets.Passes
{
    public class ClearLineDrawingTexturePass : ScriptableRenderPass, ILineDrawingDataUser
    {
        // Command Buffer
        private CommandBuffer _cmd;
        private readonly string _profilerTag;
        private int _targetHandle = -1; // handle in LineDrawingTexture
        private Color _clearColor = Color.black;
        private bool _clearDepth = false;

        // External Resources
        private LineDrawingTextures _mTexturePool;
        private bool _asyncDataLoaded;

        public ClearLineDrawingTexturePass(LineDrawingRenderPass.PassSetting passSetting)
        {
            _profilerTag = passSetting.profilerTag;

            renderPassEvent = passSetting.passEvent;

            _asyncDataLoaded = false;
        }

        /// <summary>
        /// Used to declare the texture you want to clear in this pass,
        /// </summary>
        /// <param name="lineDrawingTextureHandle">
        ///     global handle defined in class <see cref="LineDrawingTextures"/>
        /// </param>
        /// <param name="shaderPass">Which pass in material is used</param>
        public void SetupClearTexture(int lineDrawingTextureHandle,
            int shaderPass)
        {
            _targetHandle = lineDrawingTextureHandle;
            _clearColor = Color.black;
        }

        /// <summary>
        /// Used to declare the texture you want to clear in this pass,
        /// </summary>
        /// <param name="lineDrawingTextureHandle">
        ///     global handle defined in class <see cref="LineDrawingTextures"/>
        /// </param>
        /// <param name="clear">Color used to clear</param>
        public void SetupClearTexture(int lineDrawingTextureHandle,
            Color clear, bool clearDepth = false)
        {
            _targetHandle = lineDrawingTextureHandle;
            _clearColor = clear;
            _clearDepth = clearDepth;
        }
        
        public void SetupClearTexture(int lineDrawingTextureHandle,
            Color clear,
            Material clearMaterial)
        {
            _targetHandle = lineDrawingTextureHandle;
            _clearColor = clear;
        }

        public bool AsyncDataLoaded()
        {
            return _asyncDataLoaded;
        }

        /// <summary>
        /// Load external data initialized as monobehaviour module(s) 
        /// </summary>
        /// <param name="perCameraDataList"></param>
        public void SetupDataAsync(List<ILineDrawingData> perCameraDataList)
        {
            _mTexturePool =
                perCameraDataList[LineDrawingDataTypes.Textures] as LineDrawingTextures;
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
            _mTexturePool.ConnectToCmd(cmd);
            _mTexturePool.ReallocTextureCommand(_targetHandle);

            ConfigureTarget(
                _mTexturePool.RTIdentifier(_targetHandle), 
                _mTexturePool.RTIdentifier(_targetHandle)
                );
            ConfigureClear(ClearFlag.Color, _clearColor);
            
            _mTexturePool.DisconnectCmd();
        }

        // -------------------------------------------------------
        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, 
        // the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            _cmd = new CommandBuffer {name = _profilerTag};
            _cmd.Clear();

            _cmd.ClearRenderTarget(_clearDepth, true, _clearColor);

            context.ExecuteCommandBuffer(_cmd);
            _cmd.Clear();
        }

        /// Cleanup any allocated resources that were created 
        /// during the execution of this render pass.
        public override void FrameCleanup(CommandBuffer cmd)
        {
            _cmd.Dispose();
        }

        public static CsKernel ExtractComputeKernel(
            LineDrawingRenderPass.PassSetting.ComputeShaderSetting setting,
            ComputeShader computeShader,
            int kernelIndex)
        {
            return new CsKernel(
                computeShader,
                setting.kernelPrefix + "_" + setting.kernelTags[kernelIndex]
            );
        }
    }
}