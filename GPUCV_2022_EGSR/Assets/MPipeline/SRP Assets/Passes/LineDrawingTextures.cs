using System;
using System.Collections.Generic;
using Assets.MPipeline.SRP_Assets.Passes;
using MPipeline.Custom_Data.PerCameraData;
using Unity.Mathematics;
using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

namespace MPipeline.SRP_Assets.Passes
{
    public static class BinningParameters
    {
        public const float QuadPixelSize = 2;
        public const float TilePixelSize = 16;
        public const float BinPixelSize = 128;

        private static float RoundRes(float res)
        {
            return (BinPixelSize * math.ceil(res / BinPixelSize));
        }

        public static int ComputePerQuadTextureRes(float screenRes)
        {
            float quadRes = RoundRes(screenRes) / QuadPixelSize;
            return (int) quadRes;
        }

        public static int ComputePerTileTextureRes(float screenRes)
        {
            float tileRes = RoundRes(screenRes) / TilePixelSize;
            return (int) tileRes;
        }

        public static int ComputePerBinTextureRes(float screenRes)
        {
            float binRes = RoundRes(screenRes) / BinPixelSize;
            return (int) binRes;
        }
    }
    public class LineDrawingTextures : MonoBehaviour, ILineDrawingData, ICommandBufferConnected
    {
        //                     Static Properties
        // ---------------------------------------------------------------
        public static int PerPixelSpinLockTexture = 0;

        public static int ContourGBufferTexture = 1;

        public static int ReProjectionTexture = 2;
        public static int PerParticleSpinLockTexture = 3;

        public static int FJPTexture0 = 4;
        public static int FJPTexture1 = 5;
        public static int TileTexture = 6;

        public static int DebugTexture = 7;
        public static int DebugCoverageTexture = DebugTexture;
        public static int DebugTexture1 = 8;

        // Note for adding a texture:
        // Here we only setup descriptors for textures.
        // Actual data needs to be allocated in "ContourProcessorFeature.cs"
        private const int TextureCount = 9;

        private CommandBuffer _cmd = null;



        private static readonly List<string> TextureNameList = new List<string>
        {
            // Lock per pixel, not necessary spin lock
            "_PerPixelSpinLockTex",
            // Stores Stamp Attributes
            "_ContourGBuffer0",
            // History Textures(Permanent)
            "_ReProjectionTex",
            // Lock per pixel, used by particles
            "_PerParticleSpinLockTex",
            // Ping-Pong Buffers for Flood Jumping
            "_JFATex0",
            "_JFATex1",
            "_TileTex", 
            // Debug RT
            "_DebugTexture",
            "_DebugTexture1"
        };

        private static readonly List<BuiltinRenderTextureType> TextureTypes = 
            new List<BuiltinRenderTextureType>
            {
                // PropertyName:  temp rt, only survive within a single frame
                // RenderTexture: rt with lifetime across multiple frames
                BuiltinRenderTextureType.PropertyName,
                BuiltinRenderTextureType.PropertyName,
                BuiltinRenderTextureType.RenderTexture, // Reprojection Texture
                BuiltinRenderTextureType.PropertyName,
                BuiltinRenderTextureType.PropertyName,
                BuiltinRenderTextureType.PropertyName,
                BuiltinRenderTextureType.PropertyName,
                BuiltinRenderTextureType.PropertyName,
                BuiltinRenderTextureType.PropertyName,
            };

        private static readonly List<Func<Camera, RenderTextureDescriptor>> TextureDescriptors =
            new List<Func<Camera, RenderTextureDescriptor>>
            {
                // 1. Descriptor for "Per-Pixel Spin-Lock Texture"
                // -----------------------------------------------
                camera =>
                {
                    RenderTextureDescriptor desc =
                        new RenderTextureDescriptor(
                            camera.scaledPixelWidth,
                            camera.scaledPixelHeight,
                            GraphicsFormat.R32_UInt,
                            0, 0
                        )
                        {
                            // Enable UAV
                            useDynamicScale = true,
                            enableRandomWrite = true
                        };
                    return desc;
                },
                

                // Descriptor for "Contour G-Buffer Texture"
                camera =>
                {
                    RenderTextureDescriptor desc =
                        new RenderTextureDescriptor(
                            camera.scaledPixelWidth,
                            camera.scaledPixelHeight,
                            GraphicsFormat.R32G32B32A32_UInt, 
                            32, 0
                        ){enableRandomWrite = true};
                    return desc;
                },


                // Description for Re-Projection Texture #0
                camera =>
                {
                    RenderTextureDescriptor desc =
                        new RenderTextureDescriptor(
                            camera.scaledPixelWidth,
                            camera.scaledPixelHeight,
                            GraphicsFormat.R32_UInt,
                            0, 0
                        ){enableRandomWrite = true};
                    return desc;
                },
                // Description for Particle Spin Lock Texture
                camera =>
                {
                    RenderTextureDescriptor desc =
                        new RenderTextureDescriptor(
                            camera.scaledPixelWidth,
                            camera.scaledPixelHeight,
                            GraphicsFormat.R32_UInt,
                            32, 0
                        ){enableRandomWrite = true};
                    return desc;
                },


                // Description for Flood-Jumping Texture #0
                camera =>
                {
                    RenderTextureDescriptor desc =
                        new RenderTextureDescriptor(
                            camera.scaledPixelWidth,
                            camera.scaledPixelHeight,
                            GraphicsFormat.R32_SFloat,
                            0, 0
                        ){enableRandomWrite = true};
                    return desc;
                },
                // Description for Flood-Jumping Texture #1
                camera =>
                {
                    RenderTextureDescriptor desc =
                        new RenderTextureDescriptor(
                            camera.scaledPixelWidth,
                            camera.scaledPixelHeight,
                            GraphicsFormat.R32_SFloat,
                            0, 0
                        ){enableRandomWrite = true};
                    return desc;
                },
                // Description for JFA Tiling Texture
                camera =>
                {
                    RenderTextureDescriptor desc =
                        new RenderTextureDescriptor(
                            camera.scaledPixelWidth / 8,
                            camera.scaledPixelHeight / 8,
                            GraphicsFormat.R8_SNorm,
                            0, 0
                        ){enableRandomWrite = true};
                    return desc;
                },


                // Descriptor for debug texture #0
                camera => new RenderTextureDescriptor(
                    camera.scaledPixelWidth,
                    camera.scaledPixelHeight,
                    RenderTextureFormat.ARGBFloat,
                    32, 0
                ) {enableRandomWrite = true},
                // Descriptor for debug texture #1
                camera => new RenderTextureDescriptor(
                    camera.pixelWidth,
                    camera.pixelHeight,
                    RenderTextureFormat.ARGBFloat,
                    0, 0
                ) {enableRandomWrite = true}
            };

        private List<MRenderTexture> _texturePool;

        public void Init(Camera cam)
        {
            // Init Textures
            _texturePool = new List<MRenderTexture>();
            for (int handle = 0; handle < TextureCount; handle++)
            {
                // Compute texture descriptor
                RenderTextureDescriptor desc = TextureDescriptors[handle].Invoke(cam);
                bool isTempRT = TextureTypes[handle] == BuiltinRenderTextureType.PropertyName;
                
                // Initialize render texture info
                MRenderTexture mRenderTexture = new MRenderTexture();
                mRenderTexture.Setup(TextureNameList[handle], ref desc, isTempRT);
                
                // Allocate non-temp textures
                if (!isTempRT)
                {
                    mRenderTexture.Alloc();
                }

                // Append new MRenderTexture object
                _texturePool.Add(mRenderTexture);
            }

            // Load Compute Shaders
            
            _cmd = null;
        }

        /// <summary>
        /// Returns size of a texture in pixels.
        /// </summary>
        /// <param name="handle">handle of that texture</param>
        /// <returns>int2(width, height)</returns>
        public int2 TextureSize(int handle)
        {
            return new int2(
                _texturePool[handle].TextureDescriptor.width,
                _texturePool[handle].TextureDescriptor.height
            );
        }
        public MRenderTexture Texture(int handle)
        {
            return _texturePool[handle];
        }

        public RenderTargetIdentifier RTIdentifier(int handle)
        {
            return Texture(handle).Identifier;
        }

        private void OnDestroy()
        {
            ReleaseAllTextures();
        }

        private void OnDisable()
        {
            ReleaseAllTextures();
        }

        private void ReleaseAllTextures()
        {
            for (int texture = 0; texture < TextureCount; texture++)
            {
                _texturePool[texture].Dispose();
            }
        }

        public void ConnectToCmd(CommandBuffer cmdToConnect)
        {
            _cmd = cmdToConnect;
        }

        public void DisconnectCmd()
        {
            _cmd = null;
        }

        public void ReallocTextureCommand(int handle)
        {
            Texture(handle).ReallocTempRTCommand(_cmd);
        }
        
        public void ReallocTexture(int handle)
        {
            Texture(handle).Realloc();
        }


        public void BindTexturesWithKernelCommand(
            CsKernel kernel)
        {
            foreach (int handle in kernel.LDTextureHandles)
            {
                MRenderTexture texture = Texture(handle);
                if (!texture.IsPermanent)
                {
                    _cmd.SetComputeTextureParam(
                        kernel.ComputeShader, kernel.KernelIndex,
                        texture.Id, texture.Identifier
                    );
                }
                else
                {
                    _cmd.SetComputeTextureParam(
                        kernel.ComputeShader, kernel.KernelIndex,
                        texture.RTName, // Permanent texture doesn't have valid id(all equals -2)
                        texture.Texture
                    );
                }
            }
        }

        public void BindTexturesMatPropsBlock(
            IEnumerable<int> handles, MaterialPropertyBlock props)
        {
            foreach (int handle in handles)
            {
                MRenderTexture tex = Texture(handle);
                props.SetTexture(tex.Id, tex.Texture);
            }
        }

        public void SetGlobalTexturesCommand(
            IEnumerable<int> handles)
        {
            foreach (int handle in handles)
            {
                MRenderTexture tex = Texture(handle);
                _cmd.SetGlobalTexture(tex.Id, tex.Identifier);
            }
        }

        public void SetGlobalTextureCommand(
            int handle)
        {
            MRenderTexture tex = Texture(handle);
            _cmd.SetGlobalTexture(tex.Id, tex.Identifier);
        }
    }
}