Shader "Custom/LineDrawingStrokeShaders"
{
    Properties
    { 
    }
    SubShader
    {
        Tags{"Queue" = "Transparent"}

        // --------------------------------------------------------------------------
        // Stamp Stylized Rendering
        // --------------------------------------------------------------------------
        Pass
        {
            Cull Off
            Lighting Off

            // Blend Modes
            // *) Multiplicative
            // Blend DstColor Zero
            
            // *) Substractive
            // BlendOp RevSub, Add
            // Blend SrcAlpha One, Zero One
            // BlendOp RevSub, RevSub
            // Blend DstAlpha One, DstAlpha One

            // *) "Source-Over"
            // BlendOp Add, Add
            // Blend One OneMinusSrcAlpha, One OneMinusSrcAlpha


            // *) Min-Darken
            // BlendOp Min
            // Blend SrcAlpha OneMinusSrcAlpha
            
             
            // *) "UV Projection"
            BlendOp Min, Add
            Blend One One, One One

            ZWrite Off
            ZTest Off
            // ZWrite On
            // Offset 1, 1
           HLSLPROGRAM
            #pragma target 4.5
            
            #pragma vertex      StrokeStamp_VS
            #pragma fragment    StrokeStamp_FS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "../ShaderLibrary/DrawIndirectPerStamp.hlsl"
            
           ENDHLSL
        }

        // --------------------------------------------------------------------------
        // Path Rendering - Simple
        // --------------------------------------------------------------------------
        Pass
        {
            Cull Off
            Lighting Off

            // BlendOp Min
            // Blend SrcAlpha OneMinusSrcAlpha
            // Blend DstColor Zero
            // ZWrite Off
            // ZTest Off
            ZWrite On
            ZTest On
            // Offset 1, 1
             HLSLPROGRAM
              #pragma target 4.5

              #pragma vertex      StrokePath_VS
              #pragma fragment    StrokePath_FS
              #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
              #include "../ShaderLibrary/DrawIndirectPerPath.hlsl"

             ENDHLSL
        }
    }
}
