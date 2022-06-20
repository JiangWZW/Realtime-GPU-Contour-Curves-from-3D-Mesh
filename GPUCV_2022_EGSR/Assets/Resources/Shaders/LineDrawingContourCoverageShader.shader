Shader "Custom/LineDrawingContourCoverageShader"
{
    Properties
    { 
    }
    SubShader
    {
        Tags{"Queue" = "Transparent"}

        // --------------------------------------------------------------------------
        // Path Rendering - Simple
        // --------------------------------------------------------------------------
        Pass
        {
            Cull Off
            Lighting Off
            ZClip False
            // BlendOp Min
            // Blend One One

            ZWrite On
            ZTest Less
            // Offset 1, 1
             HLSLPROGRAM
              #pragma target 4.5

              #pragma vertex      ContourCoveragePath_VS
              #pragma fragment    ContourCoveragePath_FS
              #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
              #include "../ShaderLibrary/DrawIndirectPerPath.hlsl"

             ENDHLSL
        }
    }
}
