using MPipeline.SRP_Assets.Features;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.Universal.Internal;

namespace Assets.MPipeline.SRP_Assets.Features
{
    public class CustomPreZFeature : ScriptableRendererFeature
    {
        CustomDepthOnlyPass _mDepthPrepass;
        private RenderTargetHandle _mDepthTexture;
        private const float MMaxWidth = 1024.0f;

        public override void Create()
        {
            _mDepthPrepass = new CustomDepthOnlyPass(
                RenderPassEvent.BeforeRenderingPrePasses,
                RenderQueueRange.opaque,
                LayerMask.GetMask("Default"));
            _mDepthTexture.Init("_CustomDepthTexture");
        }

        // Here you can inject one or multiple render passes in the renderer.
        // This method is called when setting up the renderer once per-camera.
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            RenderTextureDescriptor targetDescriptor = 
                renderingData.cameraData.cameraTargetDescriptor;
            
            float aspect = (float)targetDescriptor.height / (float)targetDescriptor.width;

            int screenWidth = targetDescriptor.width;
            targetDescriptor.width = 
                screenWidth * 2 <= MMaxWidth ? screenWidth * 2 : screenWidth;
            
            float scale = (float)targetDescriptor.width / (float)screenWidth;
            targetDescriptor.height = (int)math.ceil((float) (targetDescriptor.width) * aspect);

            _mDepthPrepass.Setup(targetDescriptor, _mDepthTexture, scale);

            renderer.EnqueuePass(_mDepthPrepass);
        }
    }
}


