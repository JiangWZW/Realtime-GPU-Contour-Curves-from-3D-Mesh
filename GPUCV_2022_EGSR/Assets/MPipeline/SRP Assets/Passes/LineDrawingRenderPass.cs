using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using MPipeline.Custom_Data.PerCameraData;
using MPipeline.SRP_Assets.Features;
using MPipeline.SRP_Assets.Passes;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Assets.MPipeline.SRP_Assets.Passes
{
    public class LineDrawingRenderPass : ScriptableRenderPass, ILineDrawingDataUser
    {
        // Debug Name
        protected readonly string MProfilerTag;
        
        // Command Buffer 
        protected CommandBuffer CMD;
        protected List<ICommandBufferConnected> CmdUserList;
        
        // Resource Users
        protected List<ILineDrawingShaderResourceConnected> ShaderResourceUserList;


        protected LineDrawingRenderPass(string mProfilerTag, RenderPassEvent time)
        {
            MProfilerTag = mProfilerTag;
            renderPassEvent = time;
            
            CmdUserList = new List<ICommandBufferConnected>();
            ShaderResourceUserList = new List<ILineDrawingShaderResourceConnected>();

            CmdUserList = new List<ICommandBufferConnected>();
            ShaderResourceUserList = new List<ILineDrawingShaderResourceConnected>();

            // Async Data
            _mBufferPool = null;
            _mTexturePool = null;
            _mLineDrawingMaster = null;
            _mControlPanel = null;

            _asyncDataLoaded = false;

            // Debug Utils
            _frameCounter = 0;
        }

        protected void ConnectCmdWithUsers()
        {
            foreach (var cmdUser in CmdUserList)
            {
                cmdUser.ConnectToCmd(CMD);
            }
        }

        protected void ConnectShaderResourceWithUsers(
            LineDrawingBuffers buffers = null,
            LineDrawingTextures textures = null
        ){
            foreach (var shaderRsrcUser in ShaderResourceUserList)
            {
                shaderRsrcUser.ConnectToLineDrawingResources(buffers, textures);
            }
        }

        protected static ComputeShader ExtractComputeShader(
            LineDrawingRenderPass.PassSetting.ComputeShaderSetting setting)
        {
            return UnityEngine.Resources.Load<ComputeShader>(setting.path);
        }

        protected static CsKernel ExtractComputeKernel(
            LineDrawingRenderPass.PassSetting.ComputeShaderSetting setting,
            ComputeShader computeShader,
            int kernelIndex)
        {
            return new CsKernel(
                computeShader,
                setting.kernelPrefix + "_" + setting.kernelTags[kernelIndex]
            );
        }

        protected static List<CsKernel> ExtractAllComputeKernels<T>(T passInstance)
        {
            Type type = typeof(T);
            List<FieldInfo> kernelFieldInfos =
                type.GetFields(
                    BindingFlags.NonPublic |
                    BindingFlags.Instance
                ).Where(
                    info => info.FieldType == typeof(CsKernel)
                ).ToList();
            CsKernel[] kernels = Array.ConvertAll(
                kernelFieldInfos.ToArray(),
                input => (CsKernel) input.GetValue(passInstance));

            return kernels.ToList();
        }

        protected T LoadAsyncDataOfType<T>(ILineDrawingData data)
            where T : class
        {
            return data as T;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        { }


        protected int _frameCounter;

        /// <summary>
        /// Implement this function if need to load compute shaders
        /// </summary>
        /// <param name="setting">shader setting from render feature</param>
        protected virtual void LoadLineDrawingComputeShaders(
            PassSetting setting)
        { }

        /// <summary>
        /// Call this function to setup your compute shaders
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="lineDrawingRenderPass">current render pass</param>
        /// <param name="passSetting">pass setting from render feature</param>
        protected void SetupLineDrawingComputeShaders<T>(
            T lineDrawingRenderPass,
            LineDrawingRenderPass.PassSetting passSetting
        ) where T : LineDrawingRenderPass
        {
            LoadLineDrawingComputeShaders(passSetting);

            // Use reflection to get all compute kernels defined above
            List<CsKernel> kernels =
                ExtractAllComputeKernels<T>(lineDrawingRenderPass);

            // Register kernels as resource(cmd, tex, buffer) users
            foreach (CsKernel kernel in kernels)
            {
                CmdUserList.Add(kernel);
                ShaderResourceUserList.Add(kernel);
            }
        }


        protected LineDrawingBuffers _mBufferPool;
        protected LineDrawingTextures _mTexturePool;
        protected LineDrawingMaster _mLineDrawingMaster;
        protected LineDrawingControlPanel _mControlPanel;

        private bool _asyncDataLoaded;

        protected LineDrawingDispatchIndirectArgs IndirectDispatcher
            => _mBufferPool.indirectDispatcher;

        bool ILineDrawingDataUser.AsyncDataLoaded()
        {
            return _asyncDataLoaded;
        }
        /// <summary>
        /// Can be overriden to execute more async ops,
        /// for instance bind shader to external texture(s), etc
        /// </summary>
        public virtual void SetupDataAsync(
            List<ILineDrawingData> perCameraDataList)
        {
            _mBufferPool =
                LoadAsyncDataOfType<LineDrawingBuffers>(
                    perCameraDataList[LineDrawingDataTypes.Buffers]
                );
            _mTexturePool =
                LoadAsyncDataOfType<LineDrawingTextures>(
                    perCameraDataList[LineDrawingDataTypes.Textures]
                );
            _mLineDrawingMaster =
                LoadAsyncDataOfType<LineDrawingMaster>(
                    perCameraDataList[LineDrawingDataTypes.Master]
                );
            _mControlPanel =
                LoadAsyncDataOfType<LineDrawingControlPanel>(
                    perCameraDataList[LineDrawingDataTypes.ControlPanel]
                );

            CmdUserList.Add(_mBufferPool);
            CmdUserList.Add(_mTexturePool);

            _asyncDataLoaded = true;
        }

        protected void FrameCounterIncrement()
        {
            _frameCounter++;
            if (_frameCounter >= int.MaxValue - 1)
            {
                _frameCounter = 8; // reset
            }
        }




        public class PassSetting
        {
            public string profilerTag;
            public RenderPassEvent passEvent;
            public List<ComputeShaderSetting> computeShaderSetting;

            public PassSetting(
                string profilerTag,
                RenderPassEvent passEvent,
                params ComputeShaderSetting[] computeShaderSetting)
            {
                this.profilerTag = profilerTag;
                this.passEvent = passEvent;
                this.computeShaderSetting = computeShaderSetting.ToList();
            }

            [Serializable]
            public class ComputeShaderSetting
            {
                public string path;
                public string kernelPrefix;
                public string[] kernelTags;

                public ComputeShaderSetting(
                    string computeShaderPath,
                    string prefix,
                    string[] tags = null)
                {
                    path = computeShaderPath;
                    kernelPrefix = prefix;
                    kernelTags = tags;
                }
            }
        }
    }
}