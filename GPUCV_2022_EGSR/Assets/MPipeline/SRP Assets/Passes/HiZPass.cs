using System.Collections.Generic;
using MPipeline.Custom_Data.PerCameraData;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.PlayerLoop;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MPipeline.SRP_Assets.Features
{
    class HiZPass : ScriptableRenderPass
    {
        private Material _depthCopyMaterial;

        private ComputeShader _hiZGenerator;

        private RenderTargetIdentifier _cameraTarget;

        private CommandBuffer _cmd;

        // Squared version of _CameraDepthTexture;
        // We need perfectly squared & power-of-2 resolution,
        // in order to build a Hi-Z pyramid.
        private MRenderTexture _depthTexCopy;

        // Temporary textures to hold down-sampled hiz results
        private List<MRenderTexture> _tempTextures;

        // Resolution of _depthCopy
        private int _hizRes;
        private const int MaxBufferSize = 2048;

        // How many levels in Hi-Z pyramid == floor(log_2(_hizRes))
        private int _numMipLevels;

        private readonly int _mainTexId = Shader.PropertyToID("_MainTex");
        public static int HizRes = Shader.PropertyToID("_HiZResolution");
        public static int HizTexture = Shader.PropertyToID("_HiZPyramidTexture");


        public HiZPass(string psPath, string csPath)
        {
            _depthCopyMaterial = new Material(Shader.Find(psPath));
            _hiZGenerator = Resources.Load<ComputeShader>(csPath);

            _depthTexCopy = new MRenderTexture();
            _tempTextures = new List<MRenderTexture>();

            _numMipLevels = 0;
        }

        /// <summary>
        /// Computes LOD level & resolution for hiz buffer.
        /// </summary>
        /// <param name="camTargetDesc"></param>
        private void SetHiZResolution(RenderTextureDescriptor camTargetDesc)
        {
            _hizRes = // Collect the maximum resolution
                Mathf.NextPowerOfTwo(
                    math.max(
                        camTargetDesc.width,
                        camTargetDesc.height));
            _hizRes = math.min(_hizRes, MaxBufferSize);
            _numMipLevels = (int) math.floor(math.log2(_hizRes));

            float hizResF = (float) _hizRes;
            Shader.SetGlobalVector(
                HizRes,
                new Vector4(
                    hizResF, hizResF,
                    1.0f / hizResF,
                    1.0f / hizResF
                )
            );
        }

        public void Setup(RenderTextureDescriptor camTargetDesc, bool fixCamera = false)
        {
            SetHiZResolution(camTargetDesc);

            // Fill Descriptors & Setup texture prop ids
            // -------------------------------------------------------
            RenderTextureDescriptor desc = new RenderTextureDescriptor
            (_hizRes, _hizRes,
                RenderTextureFormat.RFloat)
            {
                // depthBufferBits = 0,
                useDynamicScale = false,
                enableRandomWrite = true,
                useMipMap = true,
                autoGenerateMips = false
            };

            // Depth copy(from non-power-of-two res to squared,
            // power of two version.
            _depthTexCopy.Setup(HizTexture, ref desc);

            // Temporary textures to generate hi-z mip chain
            for (int mipLevel = 0; mipLevel < _numMipLevels; mipLevel++)
            {
                desc.width /= 2;
                desc.width = math.max(desc.width, 1);
                desc.height = desc.width;

                // Bad practice of handling list with structs:
                // --------------------------------------------------------------
                // "_tempTextures[mipLevel]" returns a copy of the actual element
                // so the code won't effect the "actual" _tempTextures[mipLevel].
                // _tempTextures[mipLevel].Setup("_HizTempMips_" + "i", in desc);
                // 
                // Instead, create a new struct, add replace it with the old one.
                // 
                // What more, in this way, we follow the spirit that structs should
                // be "immutable", that is, once it's constructed, it shouldn't be
                // modified.
                MRenderTexture tempTexture = new MRenderTexture();
                tempTexture.Setup("_HizTempMips_" + mipLevel, ref desc);
                // --------------------------------------------------------------
                if (_tempTextures.Count <= mipLevel)
                {
                    _tempTextures.Add(tempTexture);
                }
                else
                {
                    _tempTextures[mipLevel] = tempTexture;
                }

                // Debug
            }
        }

        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in an performance manner.
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            _cameraTarget = RenderTargetHandle.CameraTarget.Identifier();
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            _cmd = new CommandBuffer {name = "Hi-Z Pass"};

            // 0. Release & Alloc 
            _depthTexCopy.ReallocTempRTCommand(_cmd);

            foreach (var tempTexture in _tempTextures)
            {
                tempTexture.AllocTempRTCommand(_cmd);
            }

            // 1. Copy depth buffer into a squared-of-two square
            // ----------------------------------------------------------------
            Blit(_cmd, _cameraTarget, _depthTexCopy.Identifier,
                _depthCopyMaterial, 0);

            // 2. Render Hi-Z chain
            // -----------------------------------------------------------------------------
            _depthCopyMaterial.SetTexture(_mainTexId, _depthTexCopy.Texture);
            Blit(_cmd, _depthTexCopy.Identifier, _tempTextures[0].Identifier,
                _depthCopyMaterial, 1);
            for (int mip = 1; mip < _numMipLevels; mip++)
            {
                _depthCopyMaterial.SetTexture(_mainTexId, _tempTextures[mip - 1].Texture);
                Blit(_cmd, _tempTextures[mip - 1].Identifier, _tempTextures[mip].Identifier,
                    _depthCopyMaterial, 1);
            }

            // 3. Copy Hi-Z textures into mip-maps
            // ---------------------------------------------------------------
            for (int mip = 0; mip < _numMipLevels; mip++)
            {
                _cmd.CopyTexture(
                    _tempTextures[mip].Identifier, 0, 0,
                    _depthTexCopy.Identifier, 0, mip + 1);
            }


            context.ExecuteCommandBuffer(_cmd);
            _cmd.Clear();
        }

        /// Cleanup any allocated resources that were created during the execution of this render pass.
        public override void FrameCleanup(CommandBuffer cmd)
        {
            foreach (var tempTexture in _tempTextures)
            {
                tempTexture.DisposeTempRTCommand(cmd);
            }

            _cmd.Release();
        }
    }
}