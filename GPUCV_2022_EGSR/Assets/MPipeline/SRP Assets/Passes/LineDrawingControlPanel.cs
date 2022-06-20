using System;
using System.Collections;
using Assets.MPipeline.Custom_Data.TextureCurve;
using MPipeline.SRP_Assets.Passes;
using Sirenix.OdinInspector;
using Unity.Mathematics;
using UnityEngine;

namespace Assets.MPipeline.SRP_Assets.Passes
{
    public class LineDrawingControlPanel : MonoBehaviour, ILineDrawingData
    {
        //-//////////////////////////////////////////////////////////////////////////////
        // 交互面板 
        [Title("描边几何算法")]
        // -----------------------------------------------------------------------
        public (int value, int propid) RenderPass =>
        (
            ContourRenderingPass.RenderBrushPathPass,
            Shader.PropertyToID("_RenderMode")
        );


        [Title("描边绘制对象")]
        [Button(ButtonSizes.Large, ButtonStyle.Box, Name = "渲染描边线条")]
        public bool RenderVectorizedCurves = false;
        [InfoBox("Temporal Coherence Optimizer is removed in this version, \n" +
                 "which means strokes can change quickly under animation.", 
            InfoMessageType.Info)]
        [Button(ButtonSizes.Large, ButtonStyle.Box, Name = "Debug PDB线条")]
        public bool TemporalCoherentMode = false;


        [Title("线条控制")]
        // -----------------------------------------------------------------------
        // [LabelText("描边大小")]
        [PropertyRange(0.1, 25)]
        public float LineScale = 1;

        // [LabelText("描边宽度")] 
        [PropertyRange(1, 12)]
        public float LineWidth = 6;

        // [LabelText("描边长度")] 
        [NonSerialized] // Stamping is not supported in this version
        [PropertyRange(1, 12)]
        public float StampLengthSetting = 6;

        // 32 is hard-coded at shader side,
        // for details, see MAX_STAMP_QUAD_SCALE in "CustomShaderInputs.hlsl"
        // [LabelText("描边长宽区间")] 
        [MinMaxSlider(1, 32)]
        public Vector2 minMaxWidth = new Vector2(3, 16);


        // [LabelText("深度控制曲线")] 
        [PropertyTooltip("深度对线条粗细影响")]
        public MyTextureCurve DepthCurve;

        // [LabelText("深度区间")] 
        [MinMaxSlider(0f, 1f)]
        public Vector2 minMaxDepth = new Vector2(0f, 1f);

        [NonSerialized]
        [LabelText("曲率控制曲线")] [PropertyTooltip("曲率对线条粗细影响")]
        public MyTextureCurve CurvatureCurve;

        [NonSerialized]
        [LabelText("曲率区间")] [PropertyTooltip("曲率控制曲线影响到的曲率区间")] [MinMaxSlider(0f, 1.0f)]
        public Vector2 minMaxCurv = new Vector2(0f, 0.1f);

        // [LabelText("笔刷控制曲线")] 
        [PropertyTooltip("参数对线条粗细影响")]
        public MyTextureCurve CurveShape;

        [NonSerialized]
        [LabelText("密度控制曲线")] [PropertyTooltip("抑制描边密集区域的线条粗细")]
        public MyTextureCurve DensityCurve;

        [PropertyRange(0f, 1f)]
        public float OrientThreshold = 0.1f;

        /// <summary>
        /// Control line width using curvature value.
        /// <list type="bullet">
        /// <item>.xy: Range of curvature that have effect on line width</item>
        /// <item>.zw: Reserved</item>
        /// </list>
        /// </summary>
        public Vector4 CurvatureParameters => new Vector4(minMaxCurv.x, minMaxCurv.y, 0, 0);

        /// <summary>
        /// Control line width using depth value.
        /// <list type="bullet">
        /// <item>.xy: Range of depth that have effect on line width</item>
        /// <item>.zw: Reserved</item>
        /// </list>
        /// </summary>
        public Vector4 DepthParameters => new Vector4(minMaxDepth.x, minMaxDepth.y, 0, 0);


        public enum VectorizedPathStyle
        {
            Segmentation, 
            UV,
            Textured
        };


        //-/////////////////////////////////////////////////////////
        [Title("风格化示例")]
        [EnumToggleButtons] public VectorizedPathStyle Style;

        // [LabelText("笔刷 纹理")] 
        [ShowIf("Style", VectorizedPathStyle.Textured)]
        public Texture2D BrushTexture;
        
        [ShowIf("Style", VectorizedPathStyle.Textured)]
        [Range(1u, 4u)]
        public int BrushCount = 1;
        
        [ShowIf("Style", VectorizedPathStyle.Textured)]
        [LabelText("Brush Stretching")]
        [PropertyRange(0f, 1f)] public float DebugParams1;

        // [LabelText("笔刷分割")]

        public (int shaderPropId, int value) PathStyle => (
            Shader.PropertyToID("_PathStyle"),
            (int)Style
        );
        [NonSerialized] public int BrushTexID;
        [NonSerialized] public int BrushCountID;


        [Title("性能参数")]
        // --------------------------------------------------------------------
        // [LabelText("笔刷链接跳数")]
        [PropertyRange(12, 22)]
        public int ListRankingJumps = 16;

        [NonSerialized]
        [LabelText("曲率平滑迭代")] [PropertyRange(0, 12)]
        public int CurvatureSmoothingIterations = 1;

        [NonSerialized]
        [LabelText("曲率导数平滑迭代")] [PropertyRange(0, 6)]
        public int CurvatureDerivativeSmoothingIterations = 3;


        [Title("Debug")]
        // --------------------------------------------------------------------
        [NonSerialized][PropertyRange(0f, 1f)] public float DebugParams0;
        // [NonSerialized][PropertyRange(0f, 1f)] public float DebugParams1;
        [NonSerialized][PropertyRange(0f, 1f)] public float DebugParams2;
        [NonSerialized][PropertyRange(0f, 1f)] public float DebugParams3;
        [NonSerialized][LabelText("测试用曲线 I")] public MyTextureCurve DebugTextureCurve0;



        // Control which RT to display on screen
        // ----------------------------------------------------------
        [ValueDropdown("_lineDrawingTextureToPresent")]
        public int debugOutput = -1;

        private static IEnumerable _lineDrawingTextureToPresent = new ValueDropdownList<int>()
        {
            {"Camera Target", -1},
            {"Debug Texture #0", LineDrawingTextures.DebugTexture},
            {"Debug Texture #1", LineDrawingTextures.DebugTexture1},
            {"Contour GBuffer", LineDrawingTextures.ContourGBufferTexture}
        };

        public LineDrawingControlPanel(float pdBdTs)
        {
        }


        public (float scale, int id) StrokeWidth =>
        (
            LineWidth * LineScale,
            Shader.PropertyToID("_LineWidth")
        );

        public (float scale, int id) StrokeLength =>
        (
            StampLengthSetting * LineScale,
            Shader.PropertyToID("_StampLength")
        );

        public (float4 scaleMinMax, int id) StrokeScaleRange =>
        (
            new float4(
                // Min scale.xy
                minMaxWidth.x / (LineWidth * LineScale),
                minMaxWidth.x / (LineWidth * LineScale),
                // Max scale.xy
                minMaxWidth.y / (StampLengthSetting * LineScale),
                minMaxWidth.y / (StampLengthSetting * LineScale)
            ),
            Shader.PropertyToID("_LineWidthMinMax")
        );


        public float4 DebugParams()
        {
            return new float4(DebugParams0, DebugParams1, DebugParams2, DebugParams3);
        }
        //-//////////////////////////////////////////////////////////////////////////////

        public void OnEnable()
        {
            Init(Camera.main);
        }

        private void InitControlCurves()
        {
            MyTextureCurve.SetupTextureCurve(
                "CurveTextures/CurveTexture",
                "_CurveTex_0",
                ref CurvatureCurve
            );
            MyTextureCurve.SetupTextureCurve(
                "CurveTextures/ParamCurve",
                "_CurveTex_1",
                ref CurveShape
            );
            MyTextureCurve.SetupTextureCurve(
                "CurveTextures/DensityCurve",
                "_CurveTex_2",
                ref DensityCurve);
            MyTextureCurve.SetupTextureCurve(
                "CurveTextures/DepthCurve",
                "_CurveTex_3",
                ref DepthCurve);
        }

        private void InitBrushTextures()
        {
            BrushTexture ??=
                UnityEngine.Resources.Load<Texture2D>("BrushPatterns/BrushTexture");
            BrushTexID =
                Shader.PropertyToID("_BrushTex_Main");
            BrushCountID =
                Shader.PropertyToID("_BrushTexCount");

            UnityEngine.Resources.Load<Texture2D>("BrushPatterns/Noise/WhiteNoise");
            Shader.PropertyToID("_BrushTex_ColorJitter");

        }

        public void InitPaperTextures()
        {
            UnityEngine.Resources.Load<Texture2D>("BrushPatterns/PaperHeightField");
            Shader.PropertyToID("_PaperHeightMap");
        }

        public void Init(Camera cam)
        {
            InitControlCurves();

            InitBrushTextures();

            InitPaperTextures();
        }

        public void Update()
        {
            // DepthCurve.UpdateData();
            // CurvatureCurve.UpdateData();
            // ParameterCurve.UpdateData();
            // DensityCurve.UpdateData();
        }
    }
}