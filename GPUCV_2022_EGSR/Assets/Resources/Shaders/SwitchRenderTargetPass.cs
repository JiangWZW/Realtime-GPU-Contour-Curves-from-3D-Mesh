using System.Collections.Generic;
using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.Custom_Data.PerCameraData;
using MPipeline.SRP_Assets.Features;
using MPipeline.SRP_Assets.Passes;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Assets.Resources.Shaders
{
    public class SwitchRenderTargetPass : ScriptableRenderPass, ILineDrawingDataUser
    {
        // Command Buffer 
        private readonly string _mProfilerTag;
        private CommandBuffer _mCmd;

        // External Resources
        private LineDrawingBuffers _mBufferPool;
        private LineDrawingTextures _mTexturePool;
        private LineDrawingControlPanel _mControlPanel;
        private bool _asyncDataLoaded;

        private int _mLineDrawingTextureRenderTarget;
        private RenderTargetIdentifier _mRenderTargetIdentifier;


        public SwitchRenderTargetPass(
            int lineDrawingTextureRenderTarget, 
            string profilerTag,
            RenderPassEvent time)
        {
            _mBufferPool = null;
            _mTexturePool = null;
            _mControlPanel = null;
            _asyncDataLoaded = false;

            _mLineDrawingTextureRenderTarget = lineDrawingTextureRenderTarget;
            _mProfilerTag = profilerTag;
            renderPassEvent = time;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            _mLineDrawingTextureRenderTarget = _mControlPanel.debugOutput;
            _mRenderTargetIdentifier = _mTexturePool.RTIdentifier(_mLineDrawingTextureRenderTarget);
            // ConfigureTarget(_mRenderTargetIdentifier);
        }

        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            _mCmd = new CommandBuffer{ name = _mProfilerTag };
            
            Blit(_mCmd, 
                _mRenderTargetIdentifier, 
                Shader.PropertyToID("_CameraColorAttachmentA")
            );
            
            context.ExecuteCommandBuffer(_mCmd);
            context.Submit();
        }

        public bool AsyncDataLoaded()
        {
            return _asyncDataLoaded;
        }

        public void SetupDataAsync(List<ILineDrawingData> perCameraDataList)
        {
            _mBufferPool = perCameraDataList[LineDrawingDataTypes.Buffers]
                as LineDrawingBuffers;
            _mTexturePool = perCameraDataList[LineDrawingDataTypes.Textures]
                as LineDrawingTextures;
            _mControlPanel = perCameraDataList[LineDrawingDataTypes.ControlPanel]
                as LineDrawingControlPanel;

            _asyncDataLoaded = true;
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            _mCmd.Dispose();
        }
    }
}