Shader "Hidden/HiZInitialization"
{
    Properties {}
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        /////////////////////////////////////////////////////////
        // Pass 0: copies the depth into a squared texture
        Pass
        {   
            CGPROGRAM
            #pragma target 4.6
            #pragma vertex Vert
            #pragma fragment Blit

            #include "UnityCG.cginc"

            sampler2D _CameraDepthTexture;
            
            struct Input
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings Vert (Input v)
            {
                Varyings o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            float4 Blit (Varyings i) : SV_Target
            {
                float4 col = tex2D(_CameraDepthTexture, i.uv);
                return col;
            }
            ENDCG
        }
        

        ///////////////////////////////////////////////////////////
        // Pass 1: Generation of hi-z mip chain
        Pass
        {
            CGPROGRAM
            #pragma target 4.6
            #pragma vertex Vert
            #pragma fragment Reduce

            #include "UnityCG.cginc"

            Texture2D _MainTex;
            SamplerState sampler_MainTex;

            struct Input
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings Vert (Input v)
            {
                Varyings o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            float4 Reduce(Varyings i) : SV_Target
            {
                // GatherRed needs hw that supports shader model 4.6
                // #pragma target 4.6
                float4 r = _MainTex.GatherRed(sampler_MainTex, i.uv);

                float minimum = min(min(min(r.x, r.y), r.z), r.w);

                return float4(minimum, 1.0, 1.0, 1.0);
            }
            ENDCG
        }
    }
}
