using System;
using System.Collections.Generic;
using System.Linq;
using Assets.MPipeline.SRP_Assets.Passes;
using Assets.Resources.Shaders;
using MPipeline.Custom_Data.PerCameraData;
using MPipeline.SRP_Assets.Passes;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace MPipeline.SRP_Assets.Features
{
    public static class LineDrawingDataTypes
    {
        public const int Master = 0;
        public const int Buffers = 1;
        public const int Textures = 2;
        public const int CameraProps = 3;
        public const int ControlPanel = 4;
    }

    public class ContourProcessorFeature : ScriptableRendererFeature
    {
        private static RenderPassEvent FeatureEvent =
            RenderPassEvent.BeforeRenderingSkybox;
        public static RenderPassEvent DefaultEvent = FeatureEvent;

        public static RenderPassEvent ContourRenderEvent =
            RenderPassEvent.AfterRenderingTransparents;


        //-//////////////////////////////////////////////////////////////////////////-//
        //                             Line Drawing Resource                                    //
        //-//////////////////////////////////////////////////////////////////////////-//
        private List<ILineDrawingData> _asyncResourceList;
        private bool _asyncResourceLoaded;
        // Interactive Control
        private LineDrawingControlPanel controlPanel;

        private ILineDrawingDataUser[] _lineDrawingDataUserPasses;


        //-//////////////////////////////////////////////////////////////////////////-//
        //                                   Passes                                   //
        //-//////////////////////////////////////////////////////////////////////////-//
        private ClearLineDrawingTexturePass _passClearSpinLockTexPerPixel;
        private ClearLineDrawingTexturePass _passClearSpinLockTexPerParticle;
        private ClearLineDrawingTexturePass _passClearAttributeTex;
        private ClearLineDrawingTexturePass _passClearJFATex0;
        private ClearLineDrawingTexturePass _passClearJFATex1;
        private ClearLineDrawingTexturePass _passClearTileTex;
        private ClearLineDrawingTexturePass _passClearDebugTex;
        private ClearLineDrawingTexturePass _passClearDebugTex1;

        /// <summary>
        /// Create a render pass for clearing a line drawing texture
        /// with clear color == black,
        /// with render event == (ExtractionEvent - 1)
        /// </summary>
        /// <param name="tag"> Pass name in profiler </param>
        /// <param name="lineDrawingTextureHandle"> LineDrawingTexture.type </param>
        /// <returns></returns>
        private ClearLineDrawingTexturePass CreateClearTextureRenderPassDefault(
            string tag, int lineDrawingTextureHandle, bool clearDepth = false)
        {
            ClearLineDrawingTexturePass clearPass = new ClearLineDrawingTexturePass(
                new LineDrawingRenderPass.PassSetting(tag, FeatureEvent - 12));
            
            clearPass.SetupClearTexture(
                lineDrawingTextureHandle, Color.black, clearDepth);

            return clearPass;
        }
        private ClearLineDrawingTexturePass CreateClearTextureRenderPassDefault(
            string tag, int lineDrawingTextureHandle, RenderPassEvent passEvent)
        {
            ClearLineDrawingTexturePass clearPass = new ClearLineDrawingTexturePass(
                new LineDrawingRenderPass.PassSetting(tag, passEvent));

            clearPass.SetupClearTexture(
                lineDrawingTextureHandle, Color.black);

            return clearPass;
        }


        private ContourPrepExtractionPass _passPrepExtractionPass;
        private ContourExtractionPass _passContourExtraction;
        private ContourStampInitPass _passContourStampInit;
        private ContourVectorizationPass _passContourVectorization;
        private ContourMeshingPass _passContourCoverageMeshGeneration;
        private ContourSegmentDefragmentPass _passContourDefragment_OriCull;
        private ContourSegmentationPass _passContourSegmentation_OriDefrag;
        private ContourSegmentRemergePass _passContourSegRemerge_OriCull;
        private ContourSegmentationPass _passContourSegmentation_OriSegRemerge;
        private ContourMeshingPass _passContourMeshGeneration;



        private ContourRenderingPass _passContourRendering;

        // Debug Passes
        private SwitchRenderTargetPass _passSwitchRenderTarget;




        // Initializes this feature's resources. This is called every time serialization happens.
        public override void Create()
        { 
            // -------------------------------
            // Init ScriptableRenderPass objects

            _passClearSpinLockTexPerPixel = CreateClearTextureRenderPassDefault(
                "Clear Per-Pixel Lock Texture", LineDrawingTextures.PerPixelSpinLockTexture);

            _passClearSpinLockTexPerParticle = new ClearLineDrawingTexturePass(
                new LineDrawingRenderPass.PassSetting(
                    "Clear Per-Particle Lock Texture",
                    DefaultEvent
                )
            );
            _passClearSpinLockTexPerParticle.SetupClearTexture(
                    LineDrawingTextures.PerParticleSpinLockTexture, 
                    Color.black, true
            );

            _passClearAttributeTex = new ClearLineDrawingTexturePass(
                new LineDrawingRenderPass.PassSetting(
                    "Clear Stamp Attribute Texture",
                    DefaultEvent
                )
            );
            _passClearAttributeTex.SetupClearTexture(
                LineDrawingTextures.ContourGBufferTexture, 
                Color.black, true
            );
            
            _passClearJFATex0 = CreateClearTextureRenderPassDefault(
                "Clear Flood Jumping Texture 0",
                LineDrawingTextures.FJPTexture0,
                DefaultEvent
            );
            _passClearJFATex1 = CreateClearTextureRenderPassDefault(
                "Clear Flood Jumping Texture 1",
                LineDrawingTextures.FJPTexture1,
                DefaultEvent
            );
            _passClearTileTex = CreateClearTextureRenderPassDefault(
                "Clear Flood Jumping Tiling Texture",
                LineDrawingTextures.TileTexture
            );

            _passClearDebugTex = CreateClearTextureRenderPassDefault(
                "Clear Debug Texture", LineDrawingTextures.DebugTexture);

            _passClearDebugTex1 = CreateClearTextureRenderPassDefault(
                "Clear Debug Texture", LineDrawingTextures.DebugTexture1);

            _passPrepExtractionPass = new ContourPrepExtractionPass(
                "Clear Extraction Args(only for debug perf)", DefaultEvent
            );

            _passContourExtraction = new ContourExtractionPass(
                new LineDrawingRenderPass.PassSetting(
                    "Extraction",
                    DefaultEvent,

                    new LineDrawingRenderPass.PassSetting.ComputeShaderSetting(
                        "Shaders/ContourExtraction", // Compute Shader Path
                        "ContourExtraction", // Compute Shader Prefix
                        new[] // Kernel Tags
                        {
                            "ClearArgs",
                            "VertLevel",
                            "FaceLevel",
                            "EdgeLevel"
                        }
                    ),
                    new LineDrawingRenderPass.PassSetting.ComputeShaderSetting(
                        "Shaders/ContourCompaction",
                        "ContourCompaction",
                        new[] {"Scan"}
                    ),
                    new LineDrawingRenderPass.PassSetting.ComputeShaderSetting(
                        "Shaders/ContourSetup",
                        "ContourSetup",
                        new[]
                        {
                            "Indirection",
                            "Rasterization"
                        }),
                    new LineDrawingRenderPass.PassSetting.ComputeShaderSetting(
                        "Shaders/SegmentAllocation",
                        "SegmentAllocation",
                        new[]
                        {
                            "UpSweep",
                            "Reduce",
                            "DwSweep"
                        }),
                    new LineDrawingRenderPass.PassSetting.ComputeShaderSetting(
                        "Shaders/SegmentSetup",
                        "SegmentSetup",
                        new[]
                        {
                            "CleanDataPerSeg",
                            "ContourToSegs",
                        }),
                    new LineDrawingRenderPass.PassSetting.ComputeShaderSetting(
                        "Shaders/SegmentsToContour",
                        "SegmentsToContour",
                        new[]
                        {
                            "UpSweep",
                            "Reduce",
                            "DwSweep"
                        }),
                    new LineDrawingRenderPass.PassSetting.ComputeShaderSetting(
                        "Shaders/SegmentVisibility",
                        "SegmentVisibility",
                        new[]
                        {
                            "DepthTest"
                        }),
                    new LineDrawingRenderPass.PassSetting.ComputeShaderSetting(
                        "Shaders/RadixSort",
                        "RadixSort",
                        new[]
                        {
                            "ClearGlobalHistogram",
                            "BuildGlobalHistogram"
                        }),
                    new LineDrawingRenderPass.PassSetting.ComputeShaderSetting(
                        "Shaders/ContourPixelExtraction",
                        "ContourPixelExtraction",
                        new[]
                        {
                            "SegToPixel"
                        })
                )
            );

            _passContourStampInit = new ContourStampInitPass(
                new LineDrawingRenderPass.PassSetting
                (
                    "Stamp Generation",
                    DefaultEvent,
                    new LineDrawingRenderPass.PassSetting.ComputeShaderSetting(
                        "Shaders/StampInitAttributes",
                        "StampInitAttributes",
                        new[]
                        {
                            "RPJ",
                        }
                    ),
                    new LineDrawingRenderPass.PassSetting.ComputeShaderSetting(
                        "Shaders/ResetIndirectDispatchArgs",
                        "ResetIndirectDispatchArgs",
                        new[]
                        {
                            "ToStampCount",
                            "ToHalfStampCount",
                            "ToPixelEdgeCount",
                            "ToHalfPixelEdgeCount"
                        }
                    )
                )
            );

            _passContourVectorization = new ContourVectorizationPass(
                "Contour Stylization", DefaultEvent
            );

            _passContourCoverageMeshGeneration = new ContourMeshingPass(
                "Generate Contour Coverage Mesh", DefaultEvent
            );
            _passContourCoverageMeshGeneration.VertexFormat.CurrFormat =
                ContourMeshingPass.VertexOutputFormat.CoverageTest;

            _passContourDefragment_OriCull = new ContourSegmentDefragmentPass(
                "Contout Defragment after Orient Culling", DefaultEvent,
                8 // defrag threshold
            );
            
            _passContourSegmentation_OriDefrag = new ContourSegmentationPass(
                "Segmentation for Contour Orient Defragment", DefaultEvent);
            _passContourSegmentation_OriDefrag._SegmentInput.BufferID =
                ContourSegmentationPass.InputBuffer.GPUControlled;
            _passContourSegmentation_OriDefrag._SegmentOutput.GetBufferID =
                ContourSegmentationPass.OutputBuffer.StrokeParams;

            _passContourSegRemerge_OriCull = new ContourSegmentRemergePass(
                "Contout Remerging after Orient Culling", DefaultEvent,
                6, 32 
            );
            
            _passContourSegmentation_OriSegRemerge = new ContourSegmentationPass(
                "Segmentation for Contour Orient Remerge", DefaultEvent);
            _passContourSegmentation_OriSegRemerge._SegmentInput.BufferID =
                ContourSegmentationPass.InputBuffer.GPUControlled;
            _passContourSegmentation_OriSegRemerge._SegmentOutput.GetBufferID =
                ContourSegmentationPass.OutputBuffer.StrokeParams;

            _passContourMeshGeneration = new ContourMeshingPass(
                "Generate Contour Polygons", DefaultEvent);
            _passContourMeshGeneration.VertexFormat.CurrFormat =
                ContourMeshingPass.VertexOutputFormat.ScreenStroke;



            _passContourRendering = new ContourRenderingPass(
                new LineDrawingRenderPass.PassSetting(
                    "Render Contour",
                    ContourRenderEvent
                )
            );

            _passSwitchRenderTarget = new SwitchRenderTargetPass(
                LineDrawingTextures.DebugTexture,
                "Switch To Debug Texture",
                ContourRenderEvent + 1
            );

            _lineDrawingDataUserPasses = new ILineDrawingDataUser[]
            {
                // Setup textures
                _passClearSpinLockTexPerPixel,
                _passClearSpinLockTexPerParticle, 
                _passClearAttributeTex,
                _passClearJFATex0,
                _passClearJFATex1,
                _passClearTileTex, 
                _passClearDebugTex,
                _passClearDebugTex1,

                // Setup Render Passes
                _passPrepExtractionPass, 
                _passContourExtraction, 
                _passContourStampInit,
                _passContourVectorization,
                _passContourCoverageMeshGeneration, 
                _passContourDefragment_OriCull,
                _passContourSegmentation_OriDefrag,
                _passContourSegRemerge_OriCull,
                _passContourSegmentation_OriSegRemerge,
               
                _passContourMeshGeneration,
               
                _passContourRendering,
                _passSwitchRenderTarget,  // switch output tex to debug
            };
            
            
            // Async data
            _asyncResourceLoaded = false;
            _asyncResourceList = new List<ILineDrawingData>();
        }

        // Here you can inject one or multiple render passes in the renderer.
        // This method is called when setting up the renderer once per-camera.
        public override void AddRenderPasses(
            ScriptableRenderer renderer,
            ref RenderingData renderingData
        )
        {
            Camera camera = renderingData.cameraData.camera;

            // Only inject passes after
            // related resources properly initialized in main thread: 
            if (TryLoadAsyncResources(
                    camera,
                    ref renderingData
                )
            )
            {
                List<ScriptableRenderPass> renderPasses = new List<ScriptableRenderPass>
                {
                    // ---------------------------
                    // Clear util textures
                    // yes this is not optimal
                    // but fuck it, I'm a lazy man
                    _passClearSpinLockTexPerPixel, 
                    _passClearSpinLockTexPerParticle, 
                    _passClearAttributeTex, 
                    _passClearTileTex, 
                    _passClearDebugTex, 
                    _passClearDebugTex1, 
                    
                    // ---------------------------
                    // Extact contour edges
                    _passPrepExtractionPass, 
                    _passContourExtraction, 
                    
                    // Contour-pixel("Stamp") genration
                    _passContourStampInit,
                    
                    // Pixel-edge & Stroke curves
                    _passContourVectorization,
                    _passContourDefragment_OriCull, 
                    _passContourSegmentation_OriDefrag, 

                    // Compute stroke mesh
                    _passContourMeshGeneration,

                    // Render
                    _passContourRendering
                };

                for (int i = 0; i < renderPasses.Count; i++)
                {
                    renderPasses[i].renderPassEvent = FeatureEvent + i;
                    if (renderPasses[i] == _passContourRendering)
                    {
                        _passContourRendering.renderPassEvent =
                            ContourRenderEvent;
                    }

                    renderer.EnqueuePass(renderPasses[i]);
                }


                if (controlPanel.debugOutput != -1)
                {
                    renderer.EnqueuePass(_passSwitchRenderTarget);
                }
            }
        }

        /// <summary>
        /// Loads following custom resources:  
        /// 1) LineDrawingMaster   
        /// 2) ContourExtractionBuffers
        /// 3) LineDrawingProps 
        /// If they exist.  
        /// And finally, pass their references into passes.
        /// </summary>
        /// <param name="cam"></param>
        /// <param name="renderingData"></param>
        /// <returns></returns>
        private bool TryLoadAsyncResources(
            Camera cam,
            ref RenderingData renderingData)
        {
            if (!_asyncResourceLoaded)
            {
                _asyncResourceList.Clear();
                // Make sure appending order follows enum::AsyncDataTypes
                // 1. LDM
                if (!PerCameraDataFactory.TryGet(cam, out LineDrawingMaster ldm))
                    return false;
                if (!ldm.isMeshPoolFullFilled)
                    return false;
                if (!ldm.isPerCameraDataReady)
                    return false;

                _asyncResourceList.Add(ldm);

                // 2. Pass-Specific Buffers
                PerCameraDataFactory.TryGet(cam, out LineDrawingBuffers buffers);

                _asyncResourceList.Add(buffers);

                // 3. Pass-Specific Textures
                PerCameraDataFactory.TryGet(cam, out LineDrawingTextures textures);

                _asyncResourceList.Add(textures);

                // 4. Camera Params
                PerCameraDataFactory.TryGet(cam, out LineDrawingProps cameraParams);

                _asyncResourceList.Add(cameraParams);

                // 5. Control Panel
                PerCameraDataFactory.TryGet(cam, out controlPanel);

                _asyncResourceList.Add(controlPanel);


                // Update flag
                _asyncResourceLoaded = true;
            }

            if (_asyncResourceLoaded)
            {
                // Inject Data Into Passes
                foreach (ILineDrawingDataUser dataReaderPass in _lineDrawingDataUserPasses)
                {
                    if (!dataReaderPass.AsyncDataLoaded())
                    {
                        dataReaderPass.SetupDataAsync(_asyncResourceList);
                    }
                }
            }

            return true;
        }
    }
}