// using UnityEngine;
// using UnityEngine.Rendering.Universal;
//
// namespace MPipeline.SRP_Assets.Features
// {
//     public class HiZFeature : ScriptableRendererFeature
//     {
//         private RenderTextureDescriptor _mHiZPyramid;
//         private RenderTextureDescriptor[] _mTempTextures;
//
//         HiZPass _hiZPass;
//
//         public override void Create()
//         {
//             _hiZPass = new HiZPass(
//                 "Hidden/HiZInitialization",
//                 "Shaders/HiZGenerator"
//             );
//
//             // Configures where the render pass should be injected.
//             _hiZPass.renderPassEvent = ContourProcessorFeature.ExtractionEvent - 5;
//         }
//
//         // Here you can inject one or multiple render passes in the renderer.
//         // This method is called when setting up the renderer once per-camera.
//         public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
//         {
//             RenderTextureDescriptor screenDesc =
//                 renderingData.cameraData.cameraTargetDescriptor;
//             _hiZPass.Setup(screenDesc, true);
//
//             renderer.EnqueuePass(_hiZPass);
//         }
//     }
// }