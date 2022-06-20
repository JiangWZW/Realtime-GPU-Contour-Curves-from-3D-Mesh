using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MPipeline.Custom_Data.PerCameraData
{
    public class MRenderTexture
    {
        public bool IsPermanent { get; private set; }
        public RenderTextureDescriptor TextureDescriptor { get; private set; }

        public string RTName { get; private set; }
        public int Id { get; private set; }
        public RenderTargetIdentifier Identifier { get; private set; }

        public RenderTexture Texture { get; private set; }
        
        // Variables to trace RT lifecycle
        private bool _initialized;
        private bool _allocated;


        public void Setup(
            string textureName, 
            ref RenderTextureDescriptor desc,
            bool isTemporaryRT = true)
        {
            RTName = textureName;
            // Shader.PropertyToID returns what is internally referred to as a "ShaderLab::FastPropertyName".
            // It is a value coming from an internal global std::map<char*,int> that converts shader property strings into unique integer handles (that are faster to work with).
            Id = Shader.PropertyToID(textureName);

            TextureDescriptor = new RenderTextureDescriptor();
            TextureDescriptor = desc;

            if (isTemporaryRT)
            {
                Identifier = new RenderTargetIdentifier(textureName);
            }

            _initialized = true;
            // Different between temp & non-temp RTs:
            // https://forum.unity.com/threads/access-a-temporary-rendertexture-allocated-from-previous-frame.1018573/
            IsPermanent = !isTemporaryRT;
        }

        public void Setup(
            int shaderPropId, 
            ref RenderTextureDescriptor desc,
            bool isTemporaryRT = true)
        {
            RTName = null;
            Id = shaderPropId;

            TextureDescriptor = new RenderTextureDescriptor();
            TextureDescriptor = desc;

            if (isTemporaryRT)
            {
                Identifier = new RenderTargetIdentifier(shaderPropId);
            }

            _initialized = true;
            IsPermanent = !isTemporaryRT;
        }

        public void Alloc()
        {
            if (!IsPermanent)
            {
                Texture = RenderTexture.GetTemporary(TextureDescriptor);
                _allocated = true;
            }
            else
            {
                Texture = new RenderTexture(TextureDescriptor);
                _allocated = Texture.Create();

                Identifier = new RenderTargetIdentifier(Texture);
            }
        }
        public void Dispose()
        {
            if (!_allocated) return;

            if (!IsPermanent)
            {
                RenderTexture.ReleaseTemporary(Texture);
            }
            else
            {
                Texture.Release();
            }
            _allocated = false;
        }
        public void Realloc()
        {
            if (_allocated)
            {
                Dispose();
            }

            Alloc();
        }

        public void AllocTempRTCommand(CommandBuffer cmd)
        {
            cmd.GetTemporaryRT(Id, TextureDescriptor);
            _allocated = true;
        }

        public void DisposeTempRTCommand(CommandBuffer cmd)
        {
            if (!_allocated) return;

            cmd.ReleaseTemporaryRT(Id);
            _allocated = false;
        }

        public void ReallocTempRTCommand(CommandBuffer cmd)
        {
            if (_allocated)
            {
                DisposeTempRTCommand(cmd);
            }

            AllocTempRTCommand(cmd);
        }
    }
}