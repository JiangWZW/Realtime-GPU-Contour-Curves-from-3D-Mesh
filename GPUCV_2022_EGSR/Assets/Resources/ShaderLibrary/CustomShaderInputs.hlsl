#ifndef CUSTOMSHADERINPUTS_INCLUDED
#define CUSTOMSHADERINPUTS_INCLUDED


float4 _DebugParams;

#define TEX_LEN (_DebugParams.y * 1024.0f)


// ---------------------------------------------------------------------------
// Up-Sampled Contour Rasterization:
// Each contour generate segments(contour-fragments)
// in resolution HIGHER than native render res.
// 
// For instance, if the native render res == 1024 x 768, and _StampMS == 2u,
// then the segment res is 2x-up-sampled := 2048 x 1536.
//
// This will increase the SHADING quality of g-buffer, which is essential for
// later stroke extraction process. Also, this will help to get similar effect
// as "conservative rasterization", which helps to avoid complex pixel topology.
#define STAMP_MULTI_SAMPLE
uint _StampMS;      // Set as global vars -
float _RCP_StampMS; // - in "ContourExtractionPass.cs"


// ---------------------------------------------------------------------------
// Multi-Splat Per Stamp:
// Each fragment(segment) generates
#define NUM_STAR_SPLATS 4u
// a 3x3star(STAMP_SPLAT_COUNT == 4u)
//   *
// * S *
//   *
// or, a 3x3box(STAMP_SPLAT_COUNT == 8u)
#define NUM_BOX_SPLATS 8u
// * * *
// * S *
// * * *
// This will "Dilate" the contour line, which suppresses visibility aliasing
// Actually, stroke topology is simplified with line get drawn thicker,
// By doing this we can fix broken pixels & overly complicated pixel clusters.
#define STAMP_SPLAT_COUNT 0u
/**
 * \return if this splat is star-shaped, and not a center splat
 */
bool IsStarSplat(uint splatID)
{
    return ((splatID != 0u) && (splatID < NUM_STAR_SPLATS));
}
bool IsCenterSplat(uint splatID)
{
    return splatID == 0;
}

static int2 splatOffset[9] =
{ // Pixel offset for each splat
	int2(0, 0),
    int2(1, 0),
    int2(0, 1),
    int2(-1, 0),
    int2(0, -1),
    int2(1, 1),
    int2(1, -1),
    int2(-1, -1),
    int2(-1, 1)
};

// When projecting history for each center stamp (with splatID == 0),
// the first edge to pick as history (if is on stroke)
// For edge id, see ImageProcessing.hlsl, "Edge Direction Codes"
static uint splatToEdgeDir[8] =
{
    1, 0, 3, 2,
    1, 2, 3, 0
};
/**
 * \param splatId Note: splatId must be NON-ZERO
 */
uint GetFirstEdgeForHistorySample(uint splatId)
{
    return splatToEdgeDir[splatId - 1];
}


// Minimum stroke scale, used for init&reset stamp scale history
float _LineWidth;
float _StampLength;
float4 _LineWidthMinMax; // (min.xy, max.xy)
float2 MinStrokeScale()
{
    // return float2(.2, .2);
    // return float2(2.0f / _LineWidth, 2.0f / _StampLength);
    return 2 * _LineWidthMinMax.xy;
}
#define DefaultStrokeParam .0f
#define MaxStrokeParamLength 4096u

#define RenderFacePass              0
#define RenderEdgesPass             1
#define RenderContourQuadsPass      2
#define RenderContourLinesPass      3
#define RenderViewEdgeQuadsPass     4
#define RenderViewEdgeLinesPass     5
#define RenderStampPass             6
#define RenderFragmentPass          7

#define MAX_CONTOUR_COUNT (512 * 512)

#define MAX_VISIBLE_SEG_COUNT (1024 * 1024)

#define MAX_STAMP_COUNT (600 * 600)

// Deprecated --------------------------------------//XXX
#define MAX_CIRCULAR_STAMP_COUNT ((256 * 256))      //XXX
#define MAX_JUNCTION_COUNT ((2048))                 //XXX
#define MAX_TRAIL_COUNT ((MAX_JUNCTION_COUNT * 4))  //XXX
#define NUM_STAMPS_PER_TRAIL (16)                   //XXX
// -------------------------------------------------//XXX

#define MAX_STAMP_EDGE_COUNT ((600 * 600))
#define MAX_PATH_COUNT ((8192 * 2))
#define MAX_EDGE_LOOP_COUNT ((8192))


#define MAX_ANIM_VERT_COUNT (((MAX_STAMP_EDGE_COUNT * 2) / 3))
#define MAX_ANIM_LINE_COUNT (8192 * 2)

#define MAX_STAMP_QUAD_SCALE 32.0f


// PBD Macros
#define PBD_PARTICLE_DWSAMPLE 4u 
#define MAX_PBD_PARTICLE_COUNT (((MAX_STAMP_EDGE_COUNT) / PBD_PARTICLE_DWSAMPLE))


/**
 * \brief Element with (elemId % elemsPerPtcl) == 0 selected as particle, \n
 * Also the last element always get selected.
 * \param totalElems 
 * \param elemsPerPtcl 
 * \return 
 */
uint ComputeNumParticles(uint totalElems, uint elemsPerPtcl, out bool patchLast)
{
	uint numPtcls = (totalElems + elemsPerPtcl - 1) / elemsPerPtcl;

	patchLast = ((totalElems - 1) % elemsPerPtcl != 0);
	if (patchLast)
	{ // Last particle not selected by above routine 
		numPtcls++;
	}

	return numPtcls;
}


// Re-raster Constants ///////////////////////////////////////////////////
#define MAX_JFA_TEX_RES 3000
#define MAX_RES_SOFT_RASTER 4096

#define QUAD_SIZE 2
#define LOG_QUAD_SIZE 1
float2 SSToQuadCoord(float2 vPosSS)
{
    return floor(vPosSS / QUAD_SIZE);
}

#define TILE_SIZE 16
#define LOG_TILE_SIZE 4
float2 SSToTileCoord(float2 vPosSS)
{
    return floor(vPosSS / TILE_SIZE);
}

#define BIN_SIZE 128
#define LOG_BIN_SIZE 7
#define MAX_BIN_COUNT (MAX_RES_SOFT_RASTER / BIN_SIZE)
float2 SSToBinCoord(float2 vPosSS)
{
    return floor(vPosSS / BIN_SIZE);
}









#ifndef CAT
// Macro expansion, for details, see
// ---------------------------------------
// https://stackoverflow.com/questions/1489932/how-to-concatenate-twice-with-the-c-preprocessor-and-expand-a-macro-as-in-arg
#define CAT_(x, y) x ## y
#define CAT(x, y) CAT_(x, y)
#endif


// Bit field processing ///////////////////////////////////////////////////////////////////
#define GEN_BIT_CLEAR_MASK(beg, len) (~(((1u << (len)) - 1u) << (beg)))
#define EXTRACT_BITS(data, beg, len) ((data >> beg) & (((1u << len)) - 1u))
// Unsigned integer bit field extraction.
uint ExtractBitField(uint data, uint offset, uint numBits)
{
    uint mask = (1u << numBits) - 1u;
    return (data >> offset) & mask;
}   
// Extract bit fields from an integer flag
#define EXTRACT_COMPONENT(data, c) (EXTRACT_BITS(data, CAT(BIT_BEG_, c), CAT(BIT_LEN_, c)))



// Legacy. pack coordinates
uint PackPixelCoord(uint2 coord){
    const uint mask12bit = 0x00000fff;
    return ((coord.x & mask12bit) << 12) | (coord.y & mask12bit);
}

uint2 DecodePixelCoord(uint xyPacked){
    uint2 xy = uint2(
        (xyPacked >> 12) & 0x00000fff,
        (xyPacked & 0x00000fff)
    );
    return xy;
}






// Packing Functions ////////////////////////////////////////////////////////////////////////////////
// From "ShaderLibrary / Packing.hlsl"

//-----------------------------------------------------------------------------
// Mixed(fp & int) packing
//-----------------------------------------------------------------------------
// Encode a real in [0..1] and an int in [0..maxi - 1] as a real [0..1] to be store in log2(precision) bit
// maxi must be a power of two and define the number of bit dedicated 0..1 to the int part (log2(maxi))
// Example: precision is 256.0, maxi is 2, i is [0..1] encode on 1 bit. f is [0..1] encode on 7 bit.
// Example: precision is 256.0, maxi is 4, i is [0..3] encode on 2 bit. f is [0..1] encode on 6 bit.
// Example: precision is 256.0, maxi is 8, i is [0..7] encode on 3 bit. f is [0..1] encode on 5 bit.
// ...
// Example: precision is 1024.0, maxi is 8, i is [0..7] encode on 3 bit. f is [0..1] encode on 7 bit.
//...
float PackF32U32(float f, uint i, float maxi, float precision)
{
    // Constant
    float precisionMinusOne = precision - 1.0;
    float t1 = ((precision / maxi) - 1.0) / precisionMinusOne;
    float t2 = (precision / maxi) / precisionMinusOne;

    return t1 * f + t2 * float(i);
}

void UnpackF32U32(float val, float maxi, float precision, out float f, out uint i)
{
    // Constant
    float precisionMinusOne = precision - 1.0;
    float t1 = ((precision / maxi) - 1.0) / precisionMinusOne;
    float t2 = (precision / maxi) / precisionMinusOne;

    // extract integer part
    i = int((val / t2) + rcp(precisionMinusOne)); // + rcp(precisionMinusOne) to deal with precision issue (can't use round() as val contain the floating number
    // Now that we have i, solve formula in PackFloatInt for f
    //f = (val - t2 * float(i)) / t1 => convert in mads form
    f = saturate((-t2 * float(i) + val) / t1); // Saturate in case of precision issue
}

// Pack 2-bit integer and 30-bit(actually 22) float together
float Pack_f30_2i(float f, uint i) // at most at 24 precision, but 24 will cause error
{
    return PackF32U32(f, i, 4, 1 << 22);
}

void Unpack_f30_2i(float val, out float f, out uint i)
{
    UnpackF32U32(val, 4, 1 << 22, f, i);
}

uint PackUnitVector_2D(float2 normal)
{
    //   1		0
    // y_sign x_sign
    uint xsign = (0 < normal.x) ? 1 : 0;
    uint ysign = (0 < normal.y) ? 1 : 0;

    uint xySigns = ((ysign << 1) | (xsign));

    return asuint(Pack_f30_2i(abs(normal.x), xySigns));
}

float2 UnpackUnitVector_2D(uint data)
{
    uint xySigns = 0;
    float xAbsVal = 0;

    Unpack_f30_2i(asfloat(data), xAbsVal, xySigns);

    float2 signs = float2(
        ((xySigns & 1) == (1)) ? 1 : -1, // sign of x component
        ((xySigns >> 1) == (1)) ? 1 : -1 // sign of y component
    );

    return signs * float2(xAbsVal, sqrt(1.0 - xAbsVal * xAbsVal));
}

/**
 * \brief Pack a 2D unit vector into a 32-bit floating point
 */
float PackUnitVector_2D_ToFp(float2 normal)
{
    normal.x = normal.y > 0 ? (normal.x + 3.0) : normal.x;

    return normal.x;
}

float2 UnpackUnitVector_2D_FromFp(float packedNormal)
{
    bool negY = packedNormal < 1.5;
    packedNormal = negY ? packedNormal : packedNormal - 3.0;

	float2 normal = float2(packedNormal, sqrt(1 - packedNormal * packedNormal));
    normal.y = negY ? -normal.y : normal.y;

    return normal;
}

//-----------------------------------------------------------------------------
// Integer packing
//-----------------------------------------------------------------------------
// Unpacks a [0..1] real into an integer of size 'numBits'.
uint UnpackIntToFloat(float f, uint numBits)
{
    uint maxInt = (1u << numBits) - 1u;
    return (uint)(f * maxInt + 0.5); // Round instead of truncating
}

//-----------------------------------------------------------------------------
// Float packing
//-----------------------------------------------------------------------------
// src must be between 0.0 and 1.0
uint PackFloatToUint(float src, uint offset, uint numBits)
{
    return UnpackIntToFloat(src, numBits) << offset;
}
float UnpackUintToFloat(uint src, uint offset, uint numBits)
{
    uint maxInt = (1u << numBits) - 1u;
    return float(ExtractBitField(src, offset, numBits)) * rcp((float)maxInt);
}

uint PackR16G16(float2 d)
{
    uint p =
        PackFloatToUint(d.x, 16, 16) | // high 16 bits
        PackFloatToUint(d.y, 0, 16);	 // low 16 bits
    return p;
}
float2 UnpackR16G16(uint p)
{
    float2 d;
    d.x = UnpackUintToFloat(p, 16, 16);
    d.y = UnpackUintToFloat(p, 0, 16);

    return d;
}

uint PackR8G8B8A8(float4 d)
{
    uint p =
        PackFloatToUint(d.x, 24, 8) | 
        PackFloatToUint(d.y, 16, 8) |
        PackFloatToUint(d.z, 8, 8) |
        PackFloatToUint(d.w, 0, 8);
    return p;
}
float4 UnpackR8G8B8A8(uint p)
{
    float4 d;
    d.x = UnpackUintToFloat(p, 24, 8);
    d.y = UnpackUintToFloat(p, 16, 8);
    d.z = UnpackUintToFloat(p, 8, 8);
    d.w = UnpackUintToFloat(p, 0, 8);

    return d;
}

/**
 * \brief Packs 2 f16 values into a u32, f32 value range is free
 */
uint PackF16F16(float2 d)
{
    uint p = ((f32tof16(d.x) << 16) | f32tof16(d.y));
    return p;
}
uint PackF16F16(float dx, float dy)
{
    uint p = ((f32tof16(dx) << 16) | f32tof16(dy));
    return p;
}
/**
 * \brief Unpacks 2 f16 values from a u32, value range is free
 */
float2 UnpackF16F16(uint p)
{
    float2 d;
    d.x = f16tof32(p >> 16);
    d.y = f16tof32(p & 0x0000ffff);

    return d;
}

//-----------------------------------------------------------------------------
// U24 packing
//-----------------------------------------------------------------------------
uint3 PackU24x4(uint4 u)
{
    uint3 p = 0;
    p.xyz = (u.xyz << 8);

    p.x |= (u.w & 0x000000ff);
    u.w >>= 8;
    p.y |= (u.w & 0x000000ff);
    u.w >>= 8;
    p.z |= (u.w & 0x000000ff);

    return p;
}

uint4 UnpackU24x4(uint3 p)
{
    uint4 u = 0;
    u.xyz = (p.xyz >> 8);
    p.xyz &= 0x000000ff;
    u.w = ((p.z << 16) | (p.y << 8) | p.x);

    return u;
}


//-----------------------------------------------------------------------------
// Double packing
//-----------------------------------------------------------------------------
uint2 AsUint2(double d)
{
    uint2 low_high;
    asuint( // pack double value into 2 uints
        d,
        /*low bits*/low_high.x, /*high bits*/low_high.y
    );

    return low_high;
}
double AsDouble(uint2 low_high)
{
    return asdouble(low_high.x, low_high.y);
}




// Reprojection ///////////////////////////////////////////////////
// Unified format to encode history sample
// sample si consists of
// 1) flags(8 bits) and 2) sample-index(24 bits)
// Flags are fixed, however,
// Index can be any form you like, edge id, rpj id,
// - as long as it's fast to reference history data.
// 
// high <---------------------------------------------- low
// |   8 bits	|  24 bits	|
// |Sample Flags| SampleID	|
// Sample index, pointing to the rpj-sample data, stored in buffers
#define BIT_BEG_RPJ_ID 0
#define BIT_LEN_RPJ_ID 24
// 
#define BIT_BEG_VALID_SAMPLE (BIT_BEG_RPJ_ID + BIT_LEN_RPJ_ID)
#define BIT_LEN_VALID_SAMPLE 1
// 
#define BIT_BEG_STROKE_SAMPLE (BIT_BEG_VALID_SAMPLE + BIT_LEN_VALID_SAMPLE)
#define BIT_LEN_STROKE_SAMPLE 1
//
#define BIT_BEG_COMPLEX_LINE (BIT_BEG_STROKE_SAMPLE + BIT_LEN_STROKE_SAMPLE)
#define BIT_LEN_COMPLEX_LINE 1
//
#define BIT_BEG_MULTI_STROKE (BIT_BEG_COMPLEX_LINE + BIT_LEN_COMPLEX_LINE)
#define BIT_LEN_MULTI_STROKE 1

void SetRPJSampleAttrib_Internal(
    uint attrVal, uint attrBitBeg, uint attrBitLen, inout uint sampleAttr)
{
    sampleAttr &= (GEN_BIT_CLEAR_MASK(attrBitBeg, attrBitLen));
    sampleAttr |= (attrVal << attrBitBeg);
}
#define SetRPJSampleAttr(tag, attr_val, rpj_sample) \
	SetRPJSampleAttrib_Internal(attr_val, CAT(BIT_BEG_, tag), CAT(BIT_LEN_, tag), rpj_sample) \

uint GetRPJSampleAttrib_Internal(uint attrBitBeg, uint attrBitLen, uint sampleAttr)
{
    return EXTRACT_BITS(sampleAttr, attrBitBeg, attrBitLen);
}
#define GetRPJSampleAttr(tag, rpj_sample) \
	GetRPJSampleAttrib_Internal(CAT(BIT_BEG_, tag), CAT(BIT_LEN_, tag), rpj_sample) \


bool ValidRPJSample(uint sampleAttr)
{
	return (1 == GetRPJSampleAttr(VALID_SAMPLE, sampleAttr));
}
bool OnStrokeRPJSample(uint sampleAttr)
{
    return (1 == GetRPJSampleAttr(STROKE_SAMPLE, sampleAttr));
}

bool ComplexRPJSample(uint sampleAttr)
{
    return (1 == GetRPJSampleAttr(COMPLEX_LINE, sampleAttr));
}
bool RPJSampleOnMultiStrokes(uint sampleAttr)
{
    return (1 == GetRPJSampleAttr(MULTI_STROKE, sampleAttr));
}



void SetRPJSampleIndex(uint sampleID, inout uint samplePtr)
{
	samplePtr &= 0xff000000;
	samplePtr |= (sampleID & 0x00ffffff);
}
uint EncodeRPJSampleAttr(uint sampleID)
{
    return (sampleID & 0x00ffffff);
}
uint DecodeRPJSampleID(uint rpjSampleAttr)
{
    return (rpjSampleAttr & 0x00ffffff);
}


// Note: encoding scheme must ensure
// samples with higher score has larger output
//
// Also, when changing the score policy,
// remember to fix MAX_SCORE in "StampThinning.compute"
uint EncodeRPJMark(uint sampleScore, uint samplePPtr)
{
    return ((sampleScore << 24) | (samplePPtr & 0x00ffffff));
}
void DecodeRPJMark(uint mark, out uint sampleScore, out uint samplePPtr)
{
    sampleScore = (mark >> 24);
    samplePPtr = (mark & 0x00ffffff);
}

uint ComputeRPJScore(uint rpjAttrs)
{
    return (
        /*(ComplexRPJSample(rpjAttrs)) |*/
        (OnStrokeRPJSample(rpjAttrs) << 1) |
		(ValidRPJSample(rpjAttrs) << 2)
    );
}








#define SCAN_MAX_NUM_BLOCKS 1024




uint WangHash(uint seed)
{
	seed = (seed ^ 61) ^ (seed >> 16);
	seed *= 9;
	seed = seed ^ (seed >> 4);
	seed *= 0x27d4eb2d;
	seed = seed ^ (seed >> 15);
	return seed;
}

float3 RandColRgb(uint seed0, uint seed1)
{
	float3 rgb;
	rgb.r = (float)(WangHash(seed0) % 256) / 256.0f;
	rgb.g = (float)(WangHash(seed1) % 256) / 256.0f;
	rgb.b = (float)(WangHash(WangHash(seed1 * seed0)) % 256) / 256.0f;

	return rgb;
}
#define COL_R float4(1, 0, 0, 1)
#define COL_B float4(0, 0, 1, 1)
#define COL_G float4(0, 1, 0, 1)




// Geometry
//============================================================
// adapted from source at:
// https://keithmaggio.wordpress.com/2011/02/15/math-magician-lerp-slerp-and-nlerp/
float2 slerp(float2 start, float2 end, float percent)
{
    // Dot product - the cosine of the angle between 2 vectors.
    float dotVal = dot(start, end);
    // Clamp it to be in the range of Acos()
    // This may be unnecessary, but floating point
    // precision can be a fickle mistress.
    dotVal = clamp(dotVal, -1.0, 1.0);
    // Acos(dot) returns the angle between start and end,
    // And multiplying that by percent returns the angle between
    // start and the final result.
    float theta = acos(dotVal) * percent;
    float2 RelativeVec = normalize(end - start * dotVal); // Orthonormal basis
    // The final result.
    return ((start * cos(theta)) + (RelativeVec * sin(theta)));
}

// Depth Utils
// _ZBufferParams: Unity built-in param
// in case of a reversed depth buffer (UNITY_REVERSED_Z is 1)
// x = f/n - 1
// y = 1
// z = x/f = 1/n - 1/f
// w = 1/f
// float4 _ZBufferParams;
// Zhclip = Zndc * (-Zview)
// ------ = [n/(f - n)] * Zview + [fn/(f - n)]
// ------ = [1/(f/n - 1)] * ZView + [1/(1/n - 1/f)]
// ------ = [1/x] * Zview + [1/z]
// ------ = A*Zview + B
// ------ A = 1/x, B = 1/z;
float ViewToHClipZ(float4 ZBufferParams, float zview) {
    float2 coeffs = float2(
        1.0 / ZBufferParams.x,
        1.0 / ZBufferParams.z
        );
    return dot(coeffs, float2(zview, 1));
}


#endif /* CUSTOMSHADERINPUTS_INCLUDED */
