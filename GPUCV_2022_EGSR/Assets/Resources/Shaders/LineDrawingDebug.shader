Shader "Custom/LineDrawingDebug"
{
    Properties
    { 
        // _MainTex("Source", 2D) = "white" {} // Activate this when blit
    }
    SubShader
    {
        Tags
        {
            "LightMode" = "UniversalForward"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "ForceNoShadowCasting" = "True"
        }

        Pass    // ----- #0 Procedural Shader Test Per Face ----- //
        {
            ZWrite Off
            // Cull Back
            Offset -1, -1 // Use this when using custom transform matrix
            Lighting Off
           HLSLPROGRAM
            #pragma target 4.5

            #pragma vertex      ExtractedFace_VS
            #pragma fragment    ExtractedFace_FS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "../ShaderLibrary/DrawIndirectPerFace.hlsl"
           ENDHLSL
        }

        Pass    // ----- #1 Procedural Shader Test Per Edge ----- //
        {
            ZWrite Off
            Cull Off
            Offset -1, -1
           HLSLPROGRAM
            #pragma target 4.5
            
            #pragma vertex      ExtractedEdge_VS
            #pragma fragment    ExtractedEdge_FS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "../ShaderLibrary/DrawIndirectPerEdge.hlsl"
            
           ENDHLSL
        }

        Pass    // ----- #2 Procedural Shader Test Per Contour(quad primitive) ----- //
        {
            ZWrite Off
            Cull Off
            Offset -1, -1
    
           HLSLPROGRAM
            #pragma target 4.5
            
            #pragma vertex      ExtractedContour_VS
            #pragma fragment    ExtractedContour_FS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "../ShaderLibrary/DrawIndirectPerContour.hlsl"
           ENDHLSL
        }

        Pass    // ----- #3 Procedural Shader Test Per Contour(line primitive) ----- //
        {
            ZWrite Off
            Cull Back
            // Offset -1, -1
           HLSLPROGRAM
            #pragma target 4.5
            
            #pragma vertex      ExtractedContour_VS_LinePrim
            #pragma fragment    ExtractedContour_FS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "../ShaderLibrary/DrawIndirectPerContour.hlsl"            
           ENDHLSL
        }

        Pass    // ----- #4 Procedural Shader Test Per View Edge(quad primitive) ----- //
        {
            ZWrite Off
            ZTest Always
            Cull Off
            Offset -1, -1

            HLSLPROGRAM
                #pragma target 4.5
                
                #pragma vertex      ViewEdge_VS
                #pragma fragment    ViewEdge_FS
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "../ShaderLibrary/LineDrawingDebugLib.hlsl"
            ENDHLSL
        }

        Pass    // ----- #5 Procedural Shader Test Per View Edge, line prim ----- //
        {
            ZWrite Off
            Cull Off
            Lighting Off
            // Offset -1, -1
           HLSLPROGRAM
            #pragma target 4.5
            
            #pragma vertex      ViewEdge_VS_LinePrim
            #pragma fragment    ViewEdge_FS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "../ShaderLibrary/LineDrawingDebugLib.hlsl"
            
           ENDHLSL
        }

        Pass    // ----- #6 Procedural Shader Test Per Pixel Stamp ----- //
        {
            ZWrite Off
            Cull Off
            Lighting Off

            // Blend Modes
            // BlendOp Sub
            Blend SrcAlpha OneMinusSrcAlpha
            // 1) Multiplicative
            // Blend DstColor OneMinusSrcAlpha
            // Blend OneMinusDstColor One

            // 2) Min-Darken
            // BlendOp Min

            ZTest Off
            // Offset 1, 1
           HLSLPROGRAM
            #pragma target 4.5
            
            #pragma vertex      Stamp_VS
            #pragma fragment    Stamp_FS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "../ShaderLibrary/DrawIndirectPerStamp.hlsl"
            
           ENDHLSL
        }

        Pass    // ----- Procedural Shader Attribute Projection ----- //
        {
            ZWrite On
            // Offset 1, 1

            // Cull Off
            Lighting Off

           HLSLPROGRAM
            // #pragma target 4.5
            #pragma use_dxc

            
            #pragma vertex      VisibleSegs_VS
            #pragma fragment    VisibleSegs_FS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "../ShaderLibrary/LineDrawingDebugLib.hlsl"
            
           ENDHLSL
        }
    }
}
