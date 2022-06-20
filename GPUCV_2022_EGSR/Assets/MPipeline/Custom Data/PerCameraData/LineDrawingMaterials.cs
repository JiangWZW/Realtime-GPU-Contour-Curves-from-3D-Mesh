using UnityEngine;

namespace MPipeline.Custom_Data.PerCameraData
{
    public static class LineDrawingMaterials
    {
        private const string LineDrawingMaterialPath_Legacy = 
            "Custom/LineDrawingDebug";
        private const string StrokeRenderingMaterialPath = 
            "Custom/LineDrawingStrokeShaders";
        private const string ContourCoverageTestMaterialPath =
            "Custom/LineDrawingContourCoverageShader";
        private const string ParticleCoverageTestMaterialPath = 
            "Custom/LineDrawingParticleCoverageShader";
        private const string FullScreenProcessingMatPath = 
            "Custom/LineDrawingToScreen";
        public const int FullScreenProcessingShader_InitPaper = 0;
        public const int FullScreenProcessingShader_FinalComposite = 1;

        public static Material LineDrawingMaterial_Legacy()
        {
            return new Material(
                Shader.Find(LineDrawingMaterialPath_Legacy)
            );
        }
        public static Material PaperInit()
        {
            throw new System.NotImplementedException();
        }

        public static Material StylizedStrokeRendering()
        {
            return new Material(
                Shader.Find(StrokeRenderingMaterialPath)
            );
        }
        public static Material ContourCoverageTesting()
        {
            return new Material(
                Shader.Find(ContourCoverageTestMaterialPath)
            );
        }
        public static Material ParticleCoverageTesting()
        {
            return new Material(
                Shader.Find(ParticleCoverageTestMaterialPath)
            );
        }
        public static Material CompositeStrokeToScreen()
        {
            return new Material(
                Shader.Find(FullScreenProcessingMatPath)
            );
        }

        // Utility for full-screen materials
        public static readonly int BlitSourceTex = Shader.PropertyToID("_MainTex");


        public static Material PaperlikeMaterial()
        {
            return Resources.Load<Material>("Materials/PaperMaterial");
        }

       
    }
}