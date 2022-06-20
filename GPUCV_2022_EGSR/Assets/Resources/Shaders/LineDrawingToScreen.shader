Shader "Custom/LineDrawingToScreen"
{
    // Full-screen shader to 
    // composite line-drawing texture and scene render texture.
    // --------------------------------------------------------

    Properties
    {
    }
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalRenderPipeline" 
        }
        
        LOD 100

        Pass // 0. Init Paper
        {

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragInitPaper

            #include "../ShaderLibrary/LineDrawingToScreen.hlsl"
            ENDHLSL
        }

        Pass // 1. Final Composite
        {
            // Blend SrcAlpha OneMinusSrcAlpha
            BlendOp Min

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragToneMapping

            #include "../ShaderLibrary/LineDrawingToScreen.hlsl"
            ENDHLSL
        }
    }
}
