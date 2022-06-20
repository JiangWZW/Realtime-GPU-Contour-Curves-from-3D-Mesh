﻿using System;
 using System.Collections.Generic;
 using Assets.MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
 using Assets.MPipeline.SRP_Assets.Passes;
 using MPipeline.Custom_Data.PerCameraData;
using MPipeline.Custom_Data.PerMesh_Data;
using MPipeline.Custom_Data.PerMesh_Data.Mesh_Buffer;
using MPipeline.SRP_Assets.Features;
 using Unity.Mathematics;
 using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MPipeline.SRP_Assets.Passes
{
    class ContourRenderingPass : ScriptableRenderPass, ILineDrawingDataUser
    {
        // Command Buffer 
        private readonly string _mProfilerTag;
        private CommandBuffer _mCmd;

        // Draw Materials
        private readonly Material _mStrokeRenderingMaterial;
        private readonly Material _mFullScreenMaterial;

        private readonly MaterialPropertyBlock _mMatProps;
        private readonly int[] _mMatPropsMeshBufferBindings;
        private readonly int[] _mMatPropsBufferPoolBindings;
        private readonly int[] _mMatPropsTexturePoolBindings;
        private static readonly Matrix4x4 TransformProceduralDraw = new Matrix4x4(
            new Vector4(1.0f, 0.0f, 0.0f, 1.0f),
            new Vector4(0.0f, 1.0f, 0.0f, 0.0f),
            new Vector4(0.0f, 0.0f, 1.0f, 0.0f),
            new Vector4(0.0f, 0.0f, 0.0f, 1.0f)
        );

        // External Resources
        private LineDrawingMaster _mLdm;
        private LineDrawingBuffers _mBufferPool;
        private LineDrawingTextures _mTexturePool;
        private LineDrawingControlPanel _mControlPanel;
        private LineDrawingProps _mCameraProps;
        private bool _asyncDataLoaded;
        
        // Shader passes for different targets
        public const int RenderFacePass = 0;
        public const int RenderEdgesPass = 1;
        public const int RenderContourQuadsPass = 2;
        public const int RenderBrushPathPass = 6;

        public const int RenderBlendedStrokeStampPass = 7;

        private (int value, int propid) _renderPass;

        private uint _frameParity;

        public ContourRenderingPass(LineDrawingRenderPass.PassSetting setting)
        {
            _mProfilerTag = setting.profilerTag;
            _mCmd = null;

            renderPassEvent = setting.passEvent;

            LineDrawingMaterials.LineDrawingMaterial_Legacy();
            _mStrokeRenderingMaterial = LineDrawingMaterials.StylizedStrokeRendering();
            _mFullScreenMaterial = LineDrawingMaterials.CompositeStrokeToScreen();

            _mMatPropsMeshBufferBindings = new[]
            {
                MeshBufferPreset.BufferType.TV,
                MeshBufferPreset.BufferType.VP,
                MeshBufferPreset.BufferType.VN,
                MeshBufferPreset.BufferType.EV
            };
            _mMatPropsBufferPoolBindings = new[]
            {
                LineDrawingBuffers.BufferRawPerVert,
                LineDrawingBuffers.BufferRawPerFace,
                LineDrawingBuffers.BufferRawPerEdge,
                LineDrawingBuffers.CachedArgs,
                LineDrawingBuffers.BufferRawRasterDataPerContour,
                LineDrawingBuffers.BufferRawStampPixels,
                LineDrawingBuffers.BufferRawStampGBuffer,
                LineDrawingBuffers.BufferRawStampLinkage,
                LineDrawingBuffers.BufferRawFlagsPerStamp,

                LineDrawingBuffers.BufferRawRasterDataPerSeg,
                LineDrawingBuffers.BufferRawVisibleSegToSeg,
                LineDrawingBuffers.BufferRawFlagsPerSegment,
                LineDrawingBuffers.BufferRawProceduralGeometry,

                LineDrawingBuffers.BufferRawDebug
            };
            _mMatPropsTexturePoolBindings = new[]
            {
                LineDrawingTextures.ContourGBufferTexture
            };
            _mMatProps = new MaterialPropertyBlock();

            // Async Data
            _mLdm = null;
            _mBufferPool = null;
            _mTexturePool = null;
            _asyncDataLoaded = false;

            _frameParity = 0;
        }

        public bool AsyncDataLoaded()
        {
            return _asyncDataLoaded;
        }

        public void SetupDataAsync(
            List<ILineDrawingData> dataAsync)
        {
            _mLdm = dataAsync[LineDrawingDataTypes.Master]
                as LineDrawingMaster;
            _mBufferPool = dataAsync[LineDrawingDataTypes.Buffers]
                as LineDrawingBuffers;
            _mTexturePool = dataAsync[LineDrawingDataTypes.Textures]
                as LineDrawingTextures;
            _mControlPanel = dataAsync[LineDrawingDataTypes.ControlPanel]
                as LineDrawingControlPanel;
            _mCameraProps = dataAsync[LineDrawingDataTypes.CameraProps]
                as LineDrawingProps;

            _asyncDataLoaded = true;
        }

        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in an performance manner.
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            ConfigureClear(ClearFlag.Depth, Color.black);
            
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // Set command buffers, connect it with data pools
            _mCmd = new CommandBuffer {name = _mProfilerTag};
            _mCmd.Clear();

            _mBufferPool.ConnectToCmd(_mCmd);
            _mTexturePool.ConnectToCmd(_mCmd);
            
            // Bind Resources & Draw
            // Camera Params <== Bind ==> Draw Materials
            _mCameraProps.BindCameraVectorsAllCommand(_mMatProps);
            _mCameraProps.BindCameraMatricesAllCommand(_mMatProps);
            
            // Render Textures <== Bind ==> Global
            // (property block doesn't work here, don't know why...)
            
            // Control Params <== Bind ==> Draw Material
            _mMatProps.SetFloat(
                _mControlPanel.StrokeWidth.id,
                _mControlPanel.StrokeWidth.scale);
            _mMatProps.SetFloat(
                _mControlPanel.StrokeLength.id,
                _mControlPanel.StrokeLength.scale);

            LineDrawingObject mesh = _mLdm.ldosBatched;
            
            // Mesh Params <== Bind ==> Draw Materials
            mesh.BindMeshConstantWith(_mMatProps);
            mesh.BindMeshMatricesWith(_mMatProps);

            // Compute Buffers <== Bind ==> Draw Material
            _mBufferPool.BindBuffersMatPropsBlock(
                _mMatPropsBufferPoolBindings, _mMatProps);

            // External Textures <== Bind ==> Draw Material
            _mMatProps.SetTexture(
                _mControlPanel.BrushTexID,
                _mControlPanel.BrushTexture);
            _mMatProps.SetInteger(
                _mControlPanel.BrushCountID,
                _mControlPanel.BrushCount
            );
            // _mMatProps.SetTexture(
            //     _mControlPanel.PaperTexID,
            //     _mControlPanel.BrushPaperTexture);

            // Mesh Buffers ==> Flush ==> Draw Material
            IMeshStreamGMat.Flush(
                mesh.meshDataGPU.MeshBuffers(
                    _mMatPropsMeshBufferBindings
                ),
                _mMatProps
            );


            // Draw Procedural
            // ----------------------------------------------------
            // Buffer with arguments, bufferWithArgs, 
            // has to have four integer numbers at given argsOffset offset: 
            // vertex count per instance, 
            // instance count, 
            // start vertex location, 
            // and start instance location. 
            _renderPass = _mControlPanel.RenderPass;
            if (_renderPass.value == RenderEdgesPass)
            {
            }

            if (_renderPass.value == RenderContourQuadsPass)
            {
            }

            if (_renderPass.value == RenderFacePass)
            {
            }

            if (_renderPass.value == RenderBlendedStrokeStampPass)
            {
                // _mCmd.SetRenderTarget(Shader.PropertyToID("_CameraColorTexture"));
                // _mCmd.DrawProceduralIndirect(
                //     TransformProceduralDraw,
                //     _mStrokeRenderingMaterial,
                //     0,
                //     MeshTopology.Triangles,
                //     _mBufferPool.DrawArgsForStamps(), 0, 
                //     _mMatProps
                // );

                RenderTargetIdentifier tempPaperRT = 
                    _mTexturePool.RTIdentifier(LineDrawingTextures.ContourGBufferTexture);
                
                
                _mCmd.SetRenderTarget(tempPaperRT);
                _mCmd.ClearRenderTarget(
                    true, true, 
                    new Color(1, 1, 1, 0)
                );
                
                _mCmd.DrawProceduralIndirect(
                    TransformProceduralDraw,
                    _mStrokeRenderingMaterial,
                    0,
                    MeshTopology.Triangles,
                    _mBufferPool.DrawArgsForStamps(), 0, 
                    _mMatProps
                );
                


                RenderTargetIdentifier screenRT = 
                    new RenderTargetIdentifier(Shader.PropertyToID(
                        "_CameraColorAttachmentA"));
                _mCmd.SetRenderTarget(screenRT);
                _mCmd.SetGlobalTexture(
                    LineDrawingMaterials.BlitSourceTex, tempPaperRT
                    );
                // _mFullScreenMaterial.SetTexture(
                //     _mControlPanel.BrushTextureCurve.shaderPropertyID,
                //     _mControlPanel.BrushTextureCurve
                // );
                _mFullScreenMaterial.SetTexture(
                    _mControlPanel.BrushTexID,
                    _mControlPanel.BrushTexture
                );
                _mCmd.Blit(
                    null,
                    screenRT,
                    _mFullScreenMaterial,
                    LineDrawingMaterials.FullScreenProcessingShader_FinalComposite
                );
            }

            if (_renderPass.value == RenderBrushPathPass)
            {
                _mMatProps.SetInteger(
                    _mControlPanel.PathStyle.shaderPropId,
                    _mControlPanel.PathStyle.value
                );

                _mStrokeRenderingMaterial.SetTexture(
                    _mControlPanel.BrushTexID,
                    _mControlPanel.BrushTexture
                );
                
                _mCmd.SetRenderTarget(
                    new RenderTargetIdentifier("_CameraColorAttachmentA"), 
                    new RenderTargetIdentifier("_CameraDepthAttachment")
                );
                _mCmd.ClearRenderTarget(true, true, new Color(1, 1, 1, 0));
                
                _mCmd.DrawProceduralIndirect(
                    TransformProceduralDraw,
                    _mStrokeRenderingMaterial,
                    1,
                    MeshTopology.Triangles,
                    _mBufferPool.DrawArgsForStamps(), 0, 
                    _mMatProps
                );
            }

            _mTexturePool.DisconnectCmd();
            _mBufferPool.DisconnectCmd();

            _frameParity = (_frameParity + 1) % 2;

            context.ExecuteCommandBuffer(_mCmd);
            _mCmd.Clear();
        }

        /// Cleanup any allocated resources that were created during the execution of this render pass.
        public override void FrameCleanup(CommandBuffer cmd)
        {
            _mCmd.Dispose();
        }
    }
}