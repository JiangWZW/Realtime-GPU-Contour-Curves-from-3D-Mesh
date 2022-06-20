using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.Custom_Data.PerCameraData;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MPipeline.SRP_Assets.Passes
{
    /// <inheritdoc cref="UnityEngine.Rendering.Universal.ScriptableRenderPass" />
    public class ContourVectorizationPass : LineDrawingRenderPass
    {
        // Compute Shader & Kernels
        private ComputeShader _mCsStampToPixelEdges;
        private CsKernel _mCsKernelStampToEdges;
        private CsKernel _mCsKernelCompactEdges;
        private CsKernel _mCsKernelBuildEdgeAdjacency;

        private ComputeShader _mCsPixelEdgeLinking;
        private CsKernel _mCsKernelResolveEdgeLoop;
        private CsKernel _mCsKernelInitEdgeLoopLink;
        private CsKernel _mCsKernelRankEdgeLoopList;

        private ComputeShader _mCsPixelEdgeLinkingOPT;
        private CsKernel _mCsKernelRankEdgeLoopListOPT_Reduce;
        private CsKernel _mCsKernelRankEdgeLoopListOPT_ResetDispatchArgs;
        private CsKernel _mCsKernelRankEdgeLoopListOPT_After;

        private ComputeShader _mCsPixelEdgeSerialization;
        private CsKernel _mCsKernelAllocListAddr;
        private CsKernel _mCsKernelInitEdgeLists;

        private ComputeShader _mCsEdgeLoopDespeckling;
        private CsKernel _mCsKernelEdgeLoopAreaScanUpSweep;
        private CsKernel _mCsKernelEdgeLoopAreaScanReduce;
        private CsKernel _mCsKernelEdgeLoopAreaScanDwSweep;
        private CsKernel _mCsKernelDespeckling;

        private ComputeShader _mCsInitConvolutionTables;
        private CsKernel _mCsKernelInitEdgeLoopConvData;
        private CsKernel _mCsKernelDebugEdgeLoopConvolution;

        private ComputeShader _mCsPixelEdgeCoordSmoother;
        private CsKernel _mCsKernelPixelEdgeCoordSmoothing;

        private ComputeShader _mCsPixelEdgeTangentEstimator;
        private CsKernel _mCsKernelPixelEdgeTangentFitting;

        private ComputeShader _mCsPixelEdgeTangentOptimizer;
        private CsKernel _mCsKernelPixelEdgeTangentFiltering;

        private ComputeShader _mCsPixelEdgeCurvature;
        private CsKernel _mCsKernelEdgeCurvatureSmoothing;
        private CsKernel _mCsKernelEdgeCurvatureRemapping;
        private CsKernel _mCsKernelEdgeCurvatureReSmoothing;

        private ComputeShader _mCsPixelEdgeDepth;
        private CsKernel _mCsKernelEdgeDepthSmoothing;

        private ComputeShader _mCsContourCalcArcLenParams;
        private CsKernel _mCsKernelCalcEdgeLoopArcLenParamUpSweep;
        private CsKernel _mCsKernelCalcEdgeLoopArcLenParamReduce;
        private CsKernel _mCsKernelCalcEdgeLoopArcLenParamDwSweep;
        private CsKernel _mCsKernelCalcPathArcLenParams;

        private ComputeShader _mCsPixelEdgeCulling;
        private CsKernel _mCsKernePixelEdgeCullingCurrFrame;

        private ComputeShader _mCsPixelEdgeCullingOptimize;
        private CsKernel _mCsKernelPixelEdgeCullingOptimize;

        private ComputeShader _mCsPixelEdgeFiltering;
        private CsKernel _mCsKernelSetupStrokeInitialSegmentation;
        private CsKernel _mCsKernelSetupStrokeDefragment;
        private CsKernel _mCsKernelSetupStrokeRemerge;

        private ComputeShader _mCsPixelEdgeLoopSegmentation;
        private CsKernel _mCsKernelEdgeLoopSegmentationInit;
        private CsKernel _mCsKernelEdgeLoopSegmentationStepA;
        private CsKernel _mCsKernelEdgeLoopSegmentationStepB;
        private CsKernel _mCsKernelEdgeLoopSegmentationStepC;

        private ComputeShader _mCsResetIndirectDispatchArgs;
        private CsKernel _mCsKernelResetDispatchArgsToStampCount;
        private CsKernel _mCsKernelResetDispatchArgsToHalfStampCount;
        private CsKernel _mCsKernelResetDispatchArgsToPixelEdgeCount;
        private CsKernel _mCsKernelResetDispatchArgsToHalfPixelEdgeCount;

        private ComputeShader _mCsScanTest;
        private CsKernel _mCsKernelScanTestUpsweep;
        private CsKernel _mCsKernelScanTestReduce;
        private CsKernel _mCsKernelScanTestDownsweep;

        
        
        // Debug only
        private ComputeShader _mCsDebugAABB;
        private CsKernel _mCsKernelDebugAABBSetup;
        private CsKernel _mCsKernelDebugAABBMain;

        private double dbg_contourRatio = 0;
        private double dbg_nonConcaveRatio = 0;
        private double dbg_pixelRatio = 0;
        private long dbg_aveContourPixels = 0;

        public ContourVectorizationPass(
            string tag, RenderPassEvent passEvent
        ) : base(tag, passEvent)
        {
            PassSetting setting = new PassSetting
                (
                    tag,
                    passEvent,
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampToPixelEdges",
                        "StampToPixelEdges",
                        new[]
                        {
                            "StampToEdges",
                            "CompactEdges",
                            "InitLinks"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourLinking",
                        "StampContourLinking",
                        new[]
                        {
                            "CircularPathResolve",
                            "DetectCircularStart",
                            "CircularPathRanking"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourLinkingOptimized",
                        "StampContourLinkingOptimized",
                        new[]
                        {
                            "CircularPathRanking_Reduction",
                            "CircularPathRanking_ResetDispatchArgs",
                            "CircularPathRanking_After",
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourSerialization",
                        "StampContourSerialization",
                        new[]
                        {
                            "GetListLength",
                            "BuildEdgeLists"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourDespeckling",
                        "StampContourDespeckling",
                        new[]
                        {
                            "ComputeEdgeLoopArea",
                            "DeviceScanReduce",
                            "DeviceScanDownSweep",
                            "BroadcastLoopArea"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/BuildConvolutionTable",
                        "BuildConvolutionTable",
                        new[]
                        {
                            "EdgeLoop",
                            "Test"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourCoordSmoothing",
                        "StampContourCoordSmoothing",
                        new[]
                        {
                            "CoordConvPass"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourTangentFitting",
                        "StampContourTangentFitting",
                        new[]
                        {
                            "MLS"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourTangentOptimize",
                        "StampContourTangentOptimize",
                        new[]
                        {
                            "Smooth"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourCurvature",
                        "StampContourCurvature",
                        new[]
                        {
                            "ConvPass",
                            "Remapping",
                            "RemappingConvPass"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourDepthSmoothing",
                        "StampContourDepthSmoothing",
                        new[]
                        {
                            "ZGrad",
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourCalcArcLenParam",
                        "StampContourCalcArcLenParam",
                        new[]
                        {
                            "UpSweep",
                            "Reduce",
                            "DwSweep",
                            "PathArcParam"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourCoarseCulling",
                        "StampContourCoarseCulling",
                        new[]
                        {
                            "CurrentFrame",
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourCoarseCullingOptimize",
                        "StampContourCoarseCullingOptimize",
                        new[]
                        {
                            "Filtering"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourFiltering",
                        "StampContourFiltering",
                        new[]
                        {
                            "SetupSegmentation",
                            "SetupDefragment",
                            "ReMergeSegments"
                        }
                    ),
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
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/ResetIndirectDispatchArgs",
                        "ResetIndirectDispatchArgs",
                        new[]
                        {
                            "ToStampCount",
                            "ToHalfStampCount",
                            "ToPixelEdgeCount",
                            "ToHalfPixelEdgeCount"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/TestingGround",
                        "Test",
                        new[]
                        {
                            "ScanBlock",
                            "ScanReduce",
                            "ScanDownSweep"
                        }
                    ),
                    new PassSetting.ComputeShaderSetting(
                        "Shaders/StampContourDebugAABB",
                        "StampContourDebugAABB",
                        new[]
                        {
                            "Setup",
                            "Main",
                        }
                    )
                );

            SetupLineDrawingComputeShaders(this, setting);
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
            _mCsStampToPixelEdges = ExtractComputeShader(csSetting);

            kernelHandle = 0;
            _mCsKernelStampToEdges = ExtractComputeKernel(
                csSetting, _mCsStampToPixelEdges, kernelHandle++);
            _mCsKernelStampToEdges.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.BufferRawFlagsPerStamp,
                LineDrawingBuffers.DispatchIndirectArgs1,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.CachedArgs);
            _mCsKernelStampToEdges.SetLineDrawingTextures(
                LineDrawingTextures.PerPixelSpinLockTexture,
                // Debug Only
                LineDrawingTextures.DebugTexture);

            _mCsKernelCompactEdges = ExtractComputeKernel(
                csSetting, _mCsStampToPixelEdges, kernelHandle++);
            _mCsKernelCompactEdges.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.CachedArgs,
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels);
            _mCsKernelCompactEdges.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);

            _mCsKernelBuildEdgeAdjacency = ExtractComputeKernel(
                csSetting, _mCsStampToPixelEdges, kernelHandle++);
            _mCsKernelBuildEdgeAdjacency.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.StructuredTempBuffer.handle, // test
                // Debug only
                LineDrawingBuffers.BufferRawStampGBuffer);
            _mCsKernelBuildEdgeAdjacency.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);


            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeLinking = ExtractComputeShader(csSetting);
            
            kernelHandle = 0;
            _mCsKernelResolveEdgeLoop = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeLinking, kernelHandle++);
            _mCsKernelResolveEdgeLoop.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.CachedArgs,
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels);
            _mCsKernelResolveEdgeLoop.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);

            _mCsKernelInitEdgeLoopLink = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeLinking, kernelHandle++);
            _mCsKernelInitEdgeLoopLink.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1
            );
            _mCsKernelInitEdgeLoopLink.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);

            _mCsKernelRankEdgeLoopList = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeLinking, kernelHandle++);
            _mCsKernelRankEdgeLoopList.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                // Debug only
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelRankEdgeLoopList.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);


            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeLinkingOPT = ExtractComputeShader(csSetting);

            kernelHandle = 0;

            _mCsKernelRankEdgeLoopListOPT_Reduce = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeLinkingOPT, kernelHandle++);
            _mCsKernelRankEdgeLoopListOPT_Reduce.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.DispatchIndirectArgs,
                LineDrawingBuffers.DispatchIndirectArgs1,
                LineDrawingBuffers.StructuredTempBuffer.handle,
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels);
            _mCsKernelRankEdgeLoopListOPT_Reduce.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);

            _mCsKernelRankEdgeLoopListOPT_ResetDispatchArgs = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeLinkingOPT, kernelHandle++);
            _mCsKernelRankEdgeLoopListOPT_ResetDispatchArgs.SetLineDrawingBuffers(
                LineDrawingBuffers.StructuredTempBuffer.handle,
                LineDrawingBuffers.DispatchIndirectArgsEdgeRankingOPT);
            _mCsKernelRankEdgeLoopListOPT_ResetDispatchArgs.SetupNumGroupsBy1D(1);

            _mCsKernelRankEdgeLoopListOPT_After = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeLinkingOPT, kernelHandle++);
            _mCsKernelRankEdgeLoopListOPT_After.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.DispatchIndirectArgs,
                LineDrawingBuffers.DispatchIndirectArgs1,
                LineDrawingBuffers.StructuredTempBuffer.handle,
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels);
            _mCsKernelRankEdgeLoopListOPT_After.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);

            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeSerialization = ExtractComputeShader(csSetting);

            kernelHandle = 0;

            _mCsKernelAllocListAddr = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeSerialization, kernelHandle++);
            _mCsKernelAllocListAddr.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.StructuredTempBuffer1.handle,
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampPixels);
            _mCsKernelAllocListAddr.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);


            _mCsKernelInitEdgeLists = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeSerialization, kernelHandle++);
            _mCsKernelInitEdgeLists.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.BufferRawLookBacks,
                LineDrawingBuffers.BufferRawEdgeLoopData,
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Used as scan buffer
                LineDrawingBuffers.StructuredTempBuffer1.handle,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.DispatchIndirectArgsPerEdgeLoop,
                // Debug only
                LineDrawingBuffers.BufferRawDebug
            );
            _mCsKernelInitEdgeLists.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1);

            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsEdgeLoopDespeckling = ExtractComputeShader(csSetting);

            kernelHandle = 0;

            _mCsKernelEdgeLoopAreaScanUpSweep = ExtractComputeKernel(
                csSetting, _mCsEdgeLoopDespeckling, kernelHandle++);
            _mCsKernelEdgeLoopAreaScanUpSweep.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawRasterDataPerSeg,
                LineDrawingBuffers.BufferRawLookBacks,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.DispatchIndirectArgs1,
                LineDrawingBuffers.BufferRawDebug);

            _mCsKernelEdgeLoopAreaScanReduce = ExtractComputeKernel(
                csSetting, _mCsEdgeLoopDespeckling, kernelHandle++);
            _mCsKernelEdgeLoopAreaScanReduce.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawLookBacks,
                // Debug only
                LineDrawingBuffers.BufferRawDebug);

            _mCsKernelEdgeLoopAreaScanDwSweep = ExtractComputeKernel(
                csSetting, _mCsEdgeLoopDespeckling, kernelHandle++);
            _mCsKernelEdgeLoopAreaScanDwSweep.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawRasterDataPerSeg,
                LineDrawingBuffers.BufferRawEdgeLoopData,
                LineDrawingBuffers.BufferRawLookBacks,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.StructuredTempBuffer1.handle,
                LineDrawingBuffers.DispatchIndirectArgs,
                LineDrawingBuffers.DispatchIndirectArgs1,
                // Debug only
                LineDrawingBuffers.BufferRawDebug);

            _mCsKernelDespeckling = ExtractComputeKernel(
                csSetting, _mCsEdgeLoopDespeckling, kernelHandle++);
            _mCsKernelDespeckling.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Scan Buffer
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawEdgeLoopData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.DispatchIndirectArgs,
                LineDrawingBuffers.DispatchIndirectArgs1,
                // Debug only 
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.BufferRawDebug
            );
            _mCsKernelDespeckling.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture1
            );


            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsInitConvolutionTables = ExtractComputeShader(csSetting);

            kernelHandle = 0;
            _mCsKernelInitEdgeLoopConvData = ExtractComputeKernel(
                csSetting, _mCsInitConvolutionTables, kernelHandle++);
            _mCsKernelInitEdgeLoopConvData.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                // in legacy code conv data is in this buffer,
                // to be removed
                LineDrawingBuffers.BufferRawRasterDataPerSeg,
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelInitEdgeLoopConvData.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);

            _mCsKernelDebugEdgeLoopConvolution = ExtractComputeKernel(
                csSetting, _mCsInitConvolutionTables, kernelHandle++);
            _mCsKernelDebugEdgeLoopConvolution.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                // in legacy code conv data is in this buffer,
                // to be removed
                LineDrawingBuffers.BufferRawRasterDataPerSeg,
                LineDrawingBuffers.BufferRawDebug
            );

            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeCoordSmoother = ExtractComputeShader(csSetting);

            kernelHandle = 0;
            _mCsKernelPixelEdgeCoordSmoothing = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeCoordSmoother, kernelHandle++);
            _mCsKernelPixelEdgeCoordSmoothing.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Temp buffer for tangent
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelPixelEdgeCoordSmoothing.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);


            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeTangentEstimator = ExtractComputeShader(csSetting);

            kernelHandle = 0;
            _mCsKernelPixelEdgeTangentFitting = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeTangentEstimator, kernelHandle++);
            _mCsKernelPixelEdgeTangentFitting.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Temp buffer for tangent
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelPixelEdgeTangentFitting.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture
            );


            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeTangentOptimizer = ExtractComputeShader(csSetting);

            kernelHandle = 0;
            _mCsKernelPixelEdgeTangentFiltering = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeTangentOptimizer, kernelHandle++);
            _mCsKernelPixelEdgeTangentFiltering.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Temp buffer for tangent
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelPixelEdgeTangentFiltering.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture
            );


            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeCurvature = ExtractComputeShader(csSetting);

            kernelHandle = 0;
            _mCsKernelEdgeCurvatureSmoothing = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeCurvature, kernelHandle++);
            _mCsKernelEdgeCurvatureSmoothing.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Temp buffer for curvature
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelEdgeCurvatureSmoothing.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);

            _mCsKernelEdgeCurvatureRemapping = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeCurvature, kernelHandle++);
            _mCsKernelEdgeCurvatureRemapping.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Temp buffer for curvature
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelEdgeCurvatureRemapping.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);

            _mCsKernelEdgeCurvatureReSmoothing = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeCurvature, kernelHandle++);
            _mCsKernelEdgeCurvatureReSmoothing.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Temp buffer for curvature
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelEdgeCurvatureReSmoothing.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);


            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeDepth = ExtractComputeShader(csSetting);

            kernelHandle = 0;

            _mCsKernelEdgeDepthSmoothing = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeDepth, kernelHandle++);
            _mCsKernelEdgeDepthSmoothing.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampGBuffer,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Temp buffer for curvature
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelEdgeDepthSmoothing.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture);


            // -------------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsContourCalcArcLenParams = ExtractComputeShader(csSetting);

            kernelHandle = 0;

            _mCsKernelCalcEdgeLoopArcLenParamUpSweep = ExtractComputeKernel(
                csSetting, _mCsContourCalcArcLenParams, kernelHandle++);
            _mCsKernelCalcEdgeLoopArcLenParamUpSweep.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawRasterDataPerSeg,
                LineDrawingBuffers.BufferRawProceduralGeometry,
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.BufferRawLookBacks,
                LineDrawingBuffers.BufferRawLookBacks1,
                // Debug Only
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.BufferRawDebug
            );
            _mCsKernelCalcEdgeLoopArcLenParamUpSweep.SetLineDrawingTextures(
                // Debug Only
                LineDrawingTextures.DebugTexture
            );

            _mCsKernelCalcEdgeLoopArcLenParamReduce = ExtractComputeKernel(
                csSetting, _mCsContourCalcArcLenParams, kernelHandle++);
            _mCsKernelCalcEdgeLoopArcLenParamReduce.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawLookBacks,
                LineDrawingBuffers.BufferRawLookBacks1
            );
            _mCsKernelCalcEdgeLoopArcLenParamReduce.SetupNumGroupsBy1D(1);

            _mCsKernelCalcEdgeLoopArcLenParamDwSweep = ExtractComputeKernel(
                csSetting, _mCsContourCalcArcLenParams, kernelHandle++
            );
            _mCsKernelCalcEdgeLoopArcLenParamDwSweep.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawRasterDataPerSeg,
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawProceduralGeometry,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.BufferRawLookBacks,
                LineDrawingBuffers.BufferRawLookBacks1,
                // Debug Only
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.BufferRawDebug
            );
            _mCsKernelCalcEdgeLoopArcLenParamDwSweep.SetLineDrawingTextures(
                // Debug Only
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1
            );

            _mCsKernelCalcPathArcLenParams = ExtractComputeKernel(
                csSetting, _mCsContourCalcArcLenParams, kernelHandle++);
            _mCsKernelCalcPathArcLenParams.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.CachedArgs,
                // Debug Only
                LineDrawingBuffers.BufferRawStampPixels
            );
            _mCsKernelCalcPathArcLenParams.SetLineDrawingTextures(
                // Debug Only
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1
            );

            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeCulling = ExtractComputeShader(csSetting);

            kernelHandle = 0;
            _mCsKernePixelEdgeCullingCurrFrame = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeCulling, kernelHandle++);
            _mCsKernePixelEdgeCullingCurrFrame.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.BufferRawFlagsPerStamp,
                LineDrawingBuffers.BufferRawStampGBuffer,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Temp Tangent buffer
                LineDrawingBuffers.BufferRawProceduralGeometry,
                // Clear Arg Buffers
                LineDrawingBuffers.StructuredTempBuffer1.handle,
                LineDrawingBuffers.StampDrawIndirectArgs,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.DispatchIndirectArgs, 
                // Debug Only
                LineDrawingBuffers.BufferRawDebug
            );
            _mCsKernePixelEdgeCullingCurrFrame.SetLineDrawingTextures(
                // Debug Only
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1);


            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeCullingOptimize = ExtractComputeShader(csSetting);

            kernelHandle = 0;
            _mCsKernelPixelEdgeCullingOptimize = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeCullingOptimize, kernelHandle++);
            _mCsKernelPixelEdgeCullingOptimize.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawProceduralGeometry,
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampGBuffer,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Temp Tangent buffer
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.DispatchIndirectArgs);
            _mCsKernelPixelEdgeCullingOptimize.SetLineDrawingTextures(
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1);


            // ------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsPixelEdgeFiltering = ExtractComputeShader(csSetting);

            kernelHandle = 0;
            _mCsKernelSetupStrokeInitialSegmentation = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeFiltering, kernelHandle++);
            _mCsKernelSetupStrokeInitialSegmentation.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData,
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.BufferRawFlagsPerStamp,
                LineDrawingBuffers.BufferRawStampGBuffer,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawRasterDataPerSeg, // Temp Tangent buffer
                LineDrawingBuffers.BufferRawProceduralGeometry,
                LineDrawingBuffers.StructuredTempBuffer1.handle, 
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.DispatchIndirectArgs);
            _mCsKernelSetupStrokeInitialSegmentation.SetLineDrawingTextures(
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1);

            _mCsKernelSetupStrokeDefragment = ExtractComputeKernel(
                csSetting, _mCsPixelEdgeFiltering, kernelHandle++);
            _mCsKernelSetupStrokeDefragment.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData, 
                LineDrawingBuffers.StructuredTempBuffer1.handle, 
                LineDrawingBuffers.CachedArgs,
                // Debug only
                LineDrawingBuffers.BufferRawStampPixels);
            _mCsKernelSetupStrokeDefragment.SetLineDrawingTextures(
                // Debug only
                LineDrawingTextures.DebugTexture,
                LineDrawingTextures.DebugTexture1);

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


            // -------------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsScanTest = ExtractComputeShader(csSetting);

            kernelHandle = 0;

            _mCsKernelScanTestUpsweep = ExtractComputeKernel(
                csSetting, _mCsScanTest, kernelHandle++);
            _mCsKernelScanTestUpsweep.SetLineDrawingBuffers(
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.BufferRawLookBacks,
                LineDrawingBuffers.BufferRawDebug);

            _mCsKernelScanTestReduce = ExtractComputeKernel(
                csSetting, _mCsScanTest, kernelHandle++);
            _mCsKernelScanTestReduce.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawLookBacks);
            _mCsKernelScanTestReduce.SetupNumGroupsBy1D(512);

            _mCsKernelScanTestDownsweep = ExtractComputeKernel(
                csSetting, _mCsScanTest, kernelHandle++);
            _mCsKernelScanTestDownsweep.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawDebug,
                LineDrawingBuffers.BufferRawLookBacks);


            // -------------------------------------------------------------
            csSetting = setting.computeShaderSetting[shaderHandle++];
            _mCsDebugAABB = ExtractComputeShader(csSetting);

            kernelHandle = 0;

            _mCsKernelDebugAABBSetup = ExtractComputeKernel(
                csSetting, _mCsDebugAABB, kernelHandle++);
            _mCsKernelDebugAABBSetup.SetLineDrawingBuffers(
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.CachedArgs1,
                LineDrawingBuffers.BufferRawLookBacks
            );

            _mCsKernelDebugAABBMain = ExtractComputeKernel(
                csSetting, _mCsDebugAABB, kernelHandle++);
            _mCsKernelDebugAABBMain.SetLineDrawingBuffers(
                LineDrawingBuffers.BufferRawPixelEdgeData, 
                LineDrawingBuffers.BufferRawStampPixels, 
                LineDrawingBuffers.BufferRawLookBacks,
                LineDrawingBuffers.CachedArgs, 
                LineDrawingBuffers.BufferRawDebug
            );

        }

        // in "CBuffer_BufferRawPixelEdgeData_View.hlsl"
        private int StrokeRankBuffer() => (
            // EDGE_PARAM_STROKE
            (_frameCounter % 2)
        ); 
        private int PathRankBuffer() => (
            // EDGE_PARAM_BRUSH_PATH
            2 + (_frameCounter % 2)
        );


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

            // --------------------------------------------------------------------
            { // Extract Pixel Edges from Stamps
                IndirectDispatcher.SetCurrent(
                    LineDrawingBuffers.DispatchIndirectArgsPerStamp
                );
                _mCsKernelStampToEdges.LineDrawingDispatchIndirect();

                IndirectDispatcher.SetCurrent(
                    LineDrawingBuffers.DispatchIndirectArgsTwoStamp);
                _mCsKernelCompactEdges.LineDrawingDispatchIndirect();
            }

            // Init indirect dispatch args
            _mCsKernelResetDispatchArgsToPixelEdgeCount.LineDrawingDispatch();

            { // Construct Pixel-Edge Connectivity
                IndirectDispatcher.SetCurrent(
                    LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge);
                _mCsKernelBuildEdgeAdjacency.LineDrawingDispatchIndirect();
            }


            { // Link Pixel-Edges via Parallel List Ranking
                for (int iteration = 0; iteration < _mControlPanel.ListRankingJumps; iteration++)
                {
                    CMD.SetComputeIntParam(
                        _mCsPixelEdgeLinking,
                        Shader.PropertyToID("_Iteration"),
                        iteration % 2
                    );
                    _mCsKernelResolveEdgeLoop.LineDrawingDispatchIndirect();
                }


                _mCsKernelInitEdgeLoopLink.LineDrawingDispatchIndirect();


                // Edge Ranking -----------------------------------------------
                // Original
                for (int iteration = 0; iteration < _mControlPanel.ListRankingJumps - 4; iteration++)
                {
                    CMD.SetComputeIntParam(
                        _mCsPixelEdgeLinking,
                        Shader.PropertyToID("_Iteration"),
                        iteration % 2
                    );
                    _mCsKernelRankEdgeLoopList.LineDrawingDispatchIndirect();
                }

                // Optimized
                // IndirectDispatcher.SetCurrent(
                //     LineDrawingBuffers.DispatchIndirectArgsTwoPixelEdge);
                {
                    CMD.SetComputeIntParam(
                        _mCsPixelEdgeLinkingOPT,
                        Shader.PropertyToID("_Iteration"),
                        0
                    );
                    _mCsKernelRankEdgeLoopListOPT_Reduce.LineDrawingDispatchIndirect();
                }

                _mCsKernelRankEdgeLoopListOPT_ResetDispatchArgs.LineDrawingDispatch();
                IndirectDispatcher.SetCurrent(
                    LineDrawingBuffers.DispatchIndirectArgsEdgeRankingOPT);
                for (int iteration = 1; iteration < 5; iteration++)
                {
                    CMD.SetComputeIntParam(
                        _mCsPixelEdgeLinkingOPT,
                        Shader.PropertyToID("_Iteration"),
                        iteration % 2
                    );
                    _mCsKernelRankEdgeLoopListOPT_After.LineDrawingDispatchIndirect();
                }
            } // ---------------------------------------------------------------------


            { // Serialize Edge-Loops
                IndirectDispatcher.SetCurrent(
                    LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge);
                // Edge Serialization ----------------------------------
                _mCsKernelAllocListAddr.LineDrawingDispatchIndirect();
                _mCsKernelInitEdgeLists.LineDrawingDispatchIndirect();
            } // -----------------------------------------------------
           

            { // Despeckling 
                // Compute area, aabb for each edge-loop
                IndirectDispatcher.SetCurrent(
                    LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge);
                _mCsKernelEdgeLoopAreaScanUpSweep.LineDrawingDispatchIndirect();
                
                _mCsKernelEdgeLoopAreaScanReduce.SetupNumGroupsBy1D(256);
                _mCsKernelEdgeLoopAreaScanReduce.LineDrawingDispatch();
                
                IndirectDispatcher.SetCurrent(
                    LineDrawingBuffers.DispatchIndirectArgsPerEdgeLoop);
                _mCsKernelEdgeLoopAreaScanDwSweep.LineDrawingDispatchIndirect();

                // Tag edges on very short loop as deleted
                IndirectDispatcher.SetCurrent(
                    LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge);
                _mCsKernelDespeckling.LineDrawingDispatchIndirect();
            } // ----------------------------------------------------------------

            { // Init edge-loop convolution data
                _mCsKernelInitEdgeLoopConvData.LineDrawingDispatchIndirect();
                // _mCsKernelDebugEdgeLoopConvolution.LineDrawingDispatchIndirect();
            }

            {
                // Estimate Stamp Edge Tangent & Curvature -------------------------------------
                int j = 0;
                int edgeCoordSmoothingPasses = 2;
                for (; j < edgeCoordSmoothingPasses; j++)
                {
                    CMD.SetComputeIntParam(_mCsPixelEdgeCoordSmoother, "_PingPong", j);
                    _mCsKernelPixelEdgeCoordSmoothing.LineDrawingDispatchIndirect();
                }

                CMD.SetComputeIntParam(_mCsPixelEdgeTangentEstimator, "_PingPong", edgeCoordSmoothingPasses);
                _mCsKernelPixelEdgeTangentFitting.LineDrawingDispatchIndirect();


                for (int i = 0; i < 2; i++)
                {
                    // Over smooth tangent for 2 iterations
                    CMD.SetComputeIntParam(_mCsPixelEdgeTangentOptimizer, "_PingPong", i % 2);
                    _mCsKernelPixelEdgeTangentFiltering.LineDrawingDispatchIndirect();
                }

                // Smooth Estimated Curvature
                int smoothingIterations = _mControlPanel.CurvatureSmoothingIterations;
                CMD.SetComputeIntParam(
                    _mCsPixelEdgeCurvature,
                    "_EndIteration",
                    smoothingIterations * 2
                );
                for (int i = 0; i < smoothingIterations * 2; i++)
                {
                    CMD.SetComputeIntParam(_mCsPixelEdgeCurvature, "_PingPong", i);
                    _mCsKernelEdgeCurvatureSmoothing.LineDrawingDispatchIndirect();
                }

                // Remapping & filtering curvature value
                smoothingIterations = 2 * _mControlPanel.CurvatureDerivativeSmoothingIterations;
                CMD.SetComputeIntParam(
                    _mCsPixelEdgeCurvature,
                    "_EndIteration",
                    smoothingIterations
                );
                CMD.SetComputeVectorParam(
                    _mCsPixelEdgeCurvature,
                    "_CurvatureParams",
                    _mControlPanel.CurvatureParameters
                );
                CMD.SetComputeIntParam(_mCsPixelEdgeCurvature, "_PingPong", 1);
                // _mCsKernelEdgeCurvatureRemapping.LineDrawingDispatchIndirect(); // Estimate derivative

                for (int i = 0; i < smoothingIterations; i++)
                {
                    CMD.SetComputeIntParam(_mCsPixelEdgeCurvature, "_PingPong", i);
                    // _mCsKernelEdgeCurvatureReSmoothing.LineDrawingDispatchIndirect();
                }


                smoothingIterations = 2;
                CMD.SetComputeIntParam(
                    _mCsPixelEdgeDepth,
                    "_EndIteration",
                    smoothingIterations
                );
                CMD.SetComputeFloatParam(
                    _mCsPixelEdgeDepth,
                    "_ViewDepthCutoff",
                    // Normalized view depth
                    0.001f / math.abs(Camera.main.farClipPlane - Camera.main.nearClipPlane)
                );
                for (int i = 0; i < smoothingIterations; i++)
                {
                    CMD.SetComputeIntParam(_mCsPixelEdgeDepth, "_PingPong", i);
                    _mCsKernelEdgeDepthSmoothing.LineDrawingDispatchIndirect();
                }

                // Arc-len parametrization for edge-loops
                EdgeLoopArcLenParametrization();
            } // ------------------------------------------------------------------------------



            {
                IndirectDispatcher.SetCurrent(
                    LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge);

                int strokeRankBuffer = StrokeRankBuffer(); // EDGE_PARAM_STROKE
                int pathRankBuffer = PathRankBuffer();
                //
                int flagInputBufferID = Shader.PropertyToID("_DrawFlagBufferIndex");
                int flagInputBuffer = 2;

                CMD.SetGlobalInt(
                    Shader.PropertyToID("_DebugTextureIndex"),
                    0
                );
                CMD.SetComputeFloatParam(
                    _mCsPixelEdgeCulling,
                    Shader.PropertyToID("_OrientThreshold"),
                    _mControlPanel.OrientThreshold
                );
                _mCsKernePixelEdgeCullingCurrFrame.LineDrawingDispatchIndirect();
                _mCsKernelPixelEdgeCullingOptimize.LineDrawingDispatchIndirect();

                // Segmentation based on current contour orientation
                CMD.SetComputeIntParam(
                    _mCsPixelEdgeFiltering,
                    flagInputBufferID,
                    flagInputBuffer
                );
                CMD.SetGlobalInt(
                    Shader.PropertyToID("_DebugTextureIndex"),
                    1
                );

                _mCsKernelSetupStrokeInitialSegmentation.LineDrawingDispatchIndirect();
                ExecuteEdgeLoopSegmentation(-1, 
                    strokeRankBuffer, 
                    true
                );
            }

            // -----------------------------------------------------
            #region Testing Ground

            // if (_frameCounter % 10 == 0)
            // {
            //     LineDrawingObject mesh = _mLineDrawingMaster.ldosBatched;
            //     GameObject goMesh = mesh.gameObject;
            //     string name = goMesh.name;
            //     ScreenCapture.CaptureScreenshot(
            //         "Assets/" + "rot_" + 
            //         (_frameCounter / 10) + "_" + name + ".png"
            //     );
            // }

            // if (_frameCounter % 7 == 0)
            // {
            //     LineDrawingObject mesh = _mLineDrawingMaster.ldosBatched;
            //     GameObject goMesh = mesh.gameObject;
            //     string name = goMesh.name;
            //     ScreenCapture.CaptureScreenshot(
            //         "Assets/" + name + ".png"
            //     );
            // }

            // Examine extracted geometry
            // IndirectDispatcher.SetCurrent(LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge);
            // _mCsKernelDebugAABBSetup.LineDrawingDispatchIndirect();
            // _mCsKernelDebugAABBMain.LineDrawingDispatchIndirect();
            //
            // if (100 <= _frameCounter && _frameCounter < 700)
            // {
            //     LineDrawingObject mesh = _mLineDrawingMaster.ldosBatched;
            //     int numEdges = mesh.meshBufferSrc.EdgeCount;
            //     int numNonConcaveEdges = mesh.meshBufferSrc.NumNonConcaveEdges;
            //
            //     // Debug Buffer
            //     List<uint> debugBufferRaw =
            //         _mBufferPool.ComputeBufferSnapshot(
            //             LineDrawingBuffers.BufferRawDebug);
            //     uint4 aabb = new uint4(
            //         debugBufferRaw[0],
            //         debugBufferRaw[1],
            //         debugBufferRaw[2],
            //         debugBufferRaw[3]
            //     );
            //     uint numContourEdges = debugBufferRaw[4];
            //     uint numStampPixels = debugBufferRaw[5];
            //     uint numPixelEdges = debugBufferRaw[6];
            //     
            //     dbg_nonConcaveRatio +=
            //         ((double)(numNonConcaveEdges) / (double)(numEdges));
            //     dbg_contourRatio +=
            //         ((double)(numContourEdges) / (double)(numEdges));
            //     dbg_pixelRatio +=
            //         (double)(numStampPixels) / (double)(
            //             (aabb.z - aabb.x + 1) * (aabb.w - aabb.y + 1)
            //         );
            //     dbg_aveContourPixels += numStampPixels;
            //     
            //     if (_frameCounter == 699)
            //     {
            //         dbg_nonConcaveRatio /= 600.0;
            //         dbg_contourRatio /= 600.0;
            //         dbg_pixelRatio /= 600.0;
            //         dbg_aveContourPixels /= 600;
            //         Debug.Log("NonConcaveRatio: " + dbg_nonConcaveRatio + "\n"
            //                   + "Contour Ratio: " + dbg_contourRatio + "\n"
            //                   + "Pixel Ratio: " + dbg_pixelRatio + "\n"
            //                   + "# Mesh Edges: " + numEdges + "\n"
            //                   + "# Contour Pixels: " + dbg_aveContourPixels
            //         );
            //     }
            // }

            // Examine scan result
            bool debugSegScan = true; // by default we test conventional scan
            if (_frameCounter % 21 == 0)
            {
                // float U32ToF32(uint raw)
                // {
                //     return BitConverter.ToSingle(
                //         BitConverter.GetBytes(raw),
                //         0);
                // };
                // // double U32ToD64(uint low, uint high)
                // // {
                // //     List<Byte> bytes = new List<byte>();
                // //     bytes.AddRange(BitConverter.GetBytes(low));
                // //     bytes.AddRange(BitConverter.GetBytes(high));
                // //     return BitConverter.ToDouble(bytes.ToArray(), 0);
                // // }
                // //
                // int elemCount = 0; // #PixelEdges
                // int bufferOffset = 0;
                //
                // // Debug Buffer
                // List<uint> debugBufferRaw =
                //     _mBufferPool.ComputeBufferSnapshot(
                //         LineDrawingBuffers.BufferRawDebug);

                // (1 Load element counter
                // elemCount = (int)debugBufferRaw[0];
                // bufferOffset += 1;
                //
                //
                // // (2 Read seg head flags if debugging segscan
                // List<bool> segHeadBuffer = new List<bool>(elemCount);
                // for (int elemId = 0; elemId < elemCount; elemId++)
                // {
                //     if (debugSegScan)
                //     {
                //         segHeadBuffer.Add(debugBufferRaw[bufferOffset + elemId] == 1u);
                //     }
                //     else
                //     {
                //         segHeadBuffer.Add(elemId == 0 ? true : false);
                //     }
                // }
                // if (debugSegScan)
                // {
                //     bufferOffset += elemCount;
                // }
                //
                // // 3) Read scan inputs
                // int elemStride = 1; // uint:1, uint2:2, etc.
                // List<float> inputFormatted = new List<float>(elemCount);
                // // List<uint> inputFormatted = new List<uint>(elemCount);
                // for (int elemId = 0; elemId < elemCount; elemId++)
                // { 
                //     int baseOffset = bufferOffset + elemStride * elemId;
                //     inputFormatted.Add(
                //         U32ToF32(debugBufferRaw[baseOffset])
                //     );
                // }
                // bufferOffset += elemStride * elemCount;
                //
                // // Output buffer from GPU side
                // List<float> outputFormatted = new List<float>(elemCount);
                // // List<uint> outputFormatted = new List<uint>(elemCount);
                // for (int elemId = 0; elemId < elemCount; elemId++)
                // {
                //     int baseOffset = bufferOffset + elemId * elemStride;
                //     outputFormatted.Add(
                //         U32ToF32(debugBufferRaw[baseOffset])
                //     );
                // }
                // bufferOffset += elemStride * elemCount;
                //
                // int numGroups = (int)debugBufferRaw[bufferOffset];
                // bufferOffset += 1;
                // int groupSize = (int)debugBufferRaw[bufferOffset];
                // bufferOffset += 1;
                //
                // List<List<float>> lookbackWindows = new List<List<float>>();
                // for (int blockId = 0; blockId < numGroups; blockId++)
                // {
                //     lookbackWindows.Add(new List<float>());
                //     for (int windowOffset = 0; windowOffset < 32; ++windowOffset)
                //     {
                //         int baseOffset = 
                //             bufferOffset + (32 * blockId + windowOffset) * elemStride;
                //         lookbackWindows[blockId].Add(
                //             U32ToF32(debugBufferRaw[baseOffset])
                //         );
                //     }
                // }
                // bufferOffset += 32 * numGroups * elemStride;
                //
                // List<List<float>> lookBackPrevSums = new List<List<float>>(numGroups);
                // for (int blockId = 0; blockId < numGroups; blockId++)
                // {
                //     lookBackPrevSums.Add(new List<float>());
                //     for (int windowOffset = 0; windowOffset < 32; ++windowOffset)
                //     {
                //         int baseOffset =
                //             bufferOffset + (32 * blockId + windowOffset) * elemStride;
                //         lookBackPrevSums[blockId].Add(
                //             U32ToF32(debugBufferRaw[baseOffset])
                //         );
                //     }
                // }
                //
                // bool succ = // Segmented scan validator 
                //             // can also be used to test normal scan,
                //             // just set the "debugSegScan" to false
                //     GPUScanValidator.SegmentedScan<float>(
                //         inputFormatted,
                //         segHeadBuffer,
                //         outputFormatted,
                //         elemCount, groupSize, 
                //         0, 0.001f/*0*/,
                //         (f, f1) => (f + f1),
                //         (f, f1) => (math.abs(f - f1)),
                //         // (f, f1) => (math.max(f, f1) - math.min(f, f1)), 
                //         (f, f1) => (f < f1),
                //         out string errMsg,
                //         true
                //     );
                //     // GPUScanValidator.DeviceScan<float>(
                //     //     inputFormatted,  
                //     //     outputFormatted,
                //     //     groupSize, 
                //     //     elemCount,  
                //     //     0, 
                //     //     (f, f1) => (f + f1),
                //     //     (f, f1) => (math.abs(f - f1) < 0.0001f),
                //     //     out string errMsg, 
                //     //     true
                //     // );
                // if (!succ)
                // {
                //     Debug.LogError(errMsg);
                // }
                // else
                // {
                //     Debug.Log(errMsg);
                // }
            }

            // Examine conv result
            bool debugEdgeLoopConv = true;
            if (_frameCounter % 21 == 0)
            {
                // float U32ToF32(uint raw)
                // {
                //     return BitConverter.ToSingle(
                //         BitConverter.GetBytes(raw),
                //         0);
                // };
                // int elemCount = 0; // #PixelEdges
                // int numGroups = 0;
                // int bufferOffset = 0;
                // int convRadius = 0;
                //
                // // Debug Buffer
                // List<uint> debugBufferRaw =
                //     _mBufferPool.ComputeBufferSnapshot(
                //         LineDrawingBuffers.BufferRawDebug);
                //
                // // (1 Load element counter
                // elemCount = (int)debugBufferRaw[0];
                // bufferOffset += 1;
                // numGroups = (int)debugBufferRaw[bufferOffset];
                // bufferOffset += 1;
                // convRadius = (int)debugBufferRaw[bufferOffset];
                // bufferOffset += 1;
                //
                // // (2 Read edgeloop info if debugging segscan
                // List<int> segLenBuffer = new List<int>(elemCount);
                // for (int elemId = 0; elemId < elemCount; elemId++)
                // {
                //     segLenBuffer.Add(
                //         (int)debugBufferRaw[bufferOffset + elemId]
                //     );
                // }
                // bufferOffset += elemCount;
                //
                // List<int> segHeadBuffer = new List<int>(elemCount);
                // for (int elemId = 0; elemId < elemCount; elemId++)
                // {
                //     segHeadBuffer.Add(
                //         (int)debugBufferRaw[bufferOffset + elemId]
                //     );
                // }
                // bufferOffset += elemCount;
                //
                //
                // // 3) Read scan inputs
                // int elemStride = 1; // uint:1, uint2:2, etc.
                // List<int> inputFormatted = new List<int>(elemCount);
                // for (int elemId = 0; elemId < elemCount; elemId++)
                // { 
                //     int offset = bufferOffset + elemStride * elemId;
                //     inputFormatted.Add(
                //         (int)(debugBufferRaw[offset])
                //     );
                // }
                // bufferOffset += (elemStride * elemCount);
                //
                // // Output buffer from GPU side
                // List<int> outputFormatted = new List<int>(elemCount);
                // for (int elemId = 0; elemId < elemCount; elemId++)
                // {
                //     int offset = bufferOffset + elemId * elemStride;
                //     outputFormatted.Add(
                //         (int)(debugBufferRaw[offset])
                //     );
                // }
                // bufferOffset += elemStride * elemCount;
                //
                //
                // // Debug Info
                // List<List<int>> debugBuffersU32 = 
                //     new List<List<int>>(1);
                // debugBuffersU32.Add(new List<int>());
                // for (int elemId = 0; elemId < elemCount; elemId++)
                // {
                //     int offset = bufferOffset + elemId * elemStride;
                //     debugBuffersU32[0].Add(
                //         (int)(debugBufferRaw[offset])
                //     );
                // }
                // bufferOffset += elemStride * elemCount;
                //
                // bool succ = GPUConvValidator.EdgeLoopConvolution<int>(
                //     convRadius,
                //     inputFormatted, outputFormatted,
                //     segLenBuffer, segHeadBuffer,
                //     elemCount, numGroups,
                //     ((i, i1) => { return i + i1; }),
                //     (i, i1) => { return i == i1; }, 
                //     (int)0,
                //     debugBuffersU32
                // );
                //
                // if (!succ)
                // {
                //     Debug.LogError("invalid convolution test");
                // }
                // else
                // {
                //     Debug.LogWarning("convolution test passed, " +
                //               "elem count: " + elemCount + ", " +
                //               "conv radius: " + convRadius 
                //     );
                // }
            }
#endregion
            // -----------------------------------------------------


            // You don't have to call ScriptableRenderContext.submit,
            // the render pipeline will call it at specific points in the pipeline.
            context.ExecuteCommandBuffer(CMD);
            CMD.Clear();
        }


        private void ExecuteEdgeLoopSegmentation(
            int SubbuffID_SegmentKeyInput = -1,
            int SubbuffID_StrokeParamOutput = -1,
            bool updateEdgeToStampStrokeInfo = false)
        {
            IndirectDispatcher.SetCurrent(
                LineDrawingBuffers.DispatchIndirectArgsPerPixelEdge);

            CMD.SetComputeIntParam(
                _mCsPixelEdgeLoopSegmentation,
                "_SegmentInput", SubbuffID_SegmentKeyInput
            );
            CMD.SetComputeIntParam(
                _mCsPixelEdgeLoopSegmentation,
                "_SegmentOutput", SubbuffID_StrokeParamOutput
            );
            CMD.SetComputeIntParam(
                _mCsPixelEdgeLoopSegmentation,
                "_UpdateStrokeInfoToStamps", 
                updateEdgeToStampStrokeInfo ? 1 : 0
            );

            _mCsKernelEdgeLoopSegmentationInit.LineDrawingDispatch();
            _mCsKernelEdgeLoopSegmentationStepA.LineDrawingDispatchIndirect();
            _mCsKernelEdgeLoopSegmentationStepB.LineDrawingDispatchIndirect();
            _mCsKernelEdgeLoopSegmentationStepC.LineDrawingDispatchIndirect();
        }


        private void EdgeLoopArcLenParametrization()
        {
            _mCsKernelCalcEdgeLoopArcLenParamUpSweep.LineDrawingDispatchIndirect();
            _mCsKernelCalcEdgeLoopArcLenParamReduce.LineDrawingDispatch();
            _mCsKernelCalcEdgeLoopArcLenParamDwSweep.LineDrawingDispatchIndirect();
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