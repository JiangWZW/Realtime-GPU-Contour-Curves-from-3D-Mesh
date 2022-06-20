#ifndef STAMPTHINNINGCOMPUTEDEFS_INCLUDED
#define STAMPTHINNINGCOMPUTEDEFS_INCLUDED

    // LinearEyeDepth
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl" 
// float4 _ZBufferParams;
// float4 _ScreenParams;


    #include "../ImageProcessing.hlsl"

    // Mesh Buffers(Raw)
    // Raw Buffers - Per Edge Granularity
    // Raw Buffers - Per Contour Granularity
    // Raw Buffers - Per Segment Granularity
    // Raw Buffers - Per Stamp Granularity
    #include "../ComputeBufferConfigs/CBuffer_BufferRawStampGBuffer_View.hlsl"
    #include "../ComputeBufferConfigs/CBuffer_BufferRawStampPixels_View.hlsl"
    #include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerStamp_View.hlsl"
	#include "../ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"
	#include "../ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerContour_View.hlsl"
	#include "../ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerSeg_View.hlsl"

	#include "../TextureConfigs/Texture2D_ContourGBufferTex_View.hlsl"

    // Make sure this matches GROUP_SIZE_NEXT in
    // "ContourPixelExtractionComputeDefs.hlsl"
    #define GROUP_SIZE_0 256
    
    #define GROUP_SIZE_1 256
    #define BITS_GROUP_SIZE_1 8

    // Arg Buffers
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
    #include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"

    uint SampleBoxCode_Fast(
        RWTexture2D<float> src,
        int2 texel,
        uint boxCodePrev
    ){
        boxCodePrev &= 0x000000ff; // De-moudule

        uint boxCode = 0;

        uint skeletonCount = countbits(boxCodePrev);
        uint currbit = 0;
        uint currbitVal = 0;
        int2 offset;
        for (uint i = 0; i < skeletonCount; ++i){
            // Lowest 1-valued bit
            currbit = firstbitlow(boxCodePrev);
            
            // Sample Texture with offset
            offset = Offsets_Box3x3[currbit]; // Offset for box sampling
            currbitVal = (src.Load(int3(texel + offset, 0)).r > 0.5) ? 1 : 0;
            // Cache sample
            boxCode = boxCode | (currbitVal << currbit);

            // Clear lowest 1-bit to 0 in box code
            boxCodePrev &= (~(1 << currbit));
        }

        // Repeat, make code moudular
        // initial state:              -- -- -- XY
        boxCode |= (boxCode << 8);  // -- -- XY XY
        boxCode |= (boxCode << 16); // XY XY XY XY
        
        return boxCode;
    }

	// _ZBufferParams: Unity built-in param
	// in case of a reversed depth buffer (UNITY_REVERSED_Z is 1)
	// x = f/n - 1
	// y = 1
	// z = x/f = 1/n - 1/f
	// w = 1/f
	// float4 _ZBufferParams;
	float NDCToViewZ(float zndc)
	{
		return 1.0 / dot(_ZBufferParams.zw, float2(zndc, 1));
	}

    //== Utility functions ========================
    // _ZBufferParams: Unity built-in param
    // in case of a reversed depth buffer (UNITY_REVERSED_Z is 1)
    // x = f/n - 1
    // y = 1
    // z = x/f = 1/n - 1/f
    // w = 1/f
    // float4 _ZBufferParams;
    float ViewToHClipZ(float zview)
    {
        float2 coeffs = float2(
            1.0f / _ZBufferParams.x,
            1.0f / _ZBufferParams.z
            );
        return dot(coeffs, float2(zview, 1));
    }

#endif /* STAMPTHINNINGCOMPUTEDEFS_INCLUDED */
