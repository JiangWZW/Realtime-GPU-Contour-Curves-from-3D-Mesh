#ifndef IMAGEPROCESSING_INCLUDED
#define IMAGEPROCESSING_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl" 

// | _11 | _12 | _13 |
// | _21 | _22 | _23 |
// | _31 | _32 | _33 |
#define TopLeft      _11
#define TopCenter    _12
#define TopRight     _13
#define CenterLeft   _21
#define CenterCenter _22
#define CenterRight  _23
#define BottomLeft   _31
#define BottomCenter _32
#define BottomRight  _33

#define  Offset_TopLeft      (int2(-1, 1))
#define  Offset_TopCenter    (int2(0, 1))
#define  Offset_TopRight     (int2(1, 1))
#define  Offset_CenterLeft   (int2(-1, 0))
#define  Offset_CenterCenter (int2(0, 0))
#define  Offset_CenterRight  (int2(1, 0))
#define  Offset_BottomLeft   (int2(-1, -1))
#define  Offset_BottomCenter (int2(0, -1))
#define  Offset_BottomRight  (int2(1, -1))

// | 7 | 0 | 1 |
// | 6 | P | 2 |
// | 5 | 4 | 3 |
static int2 Offsets_Box3x3[8] = {
    Offset_TopCenter,
    Offset_TopRight,
    Offset_CenterRight,
    Offset_BottomRight,
    Offset_BottomCenter,
    Offset_BottomLeft,
    Offset_CenterLeft,
    Offset_TopLeft
};

int2 NextNeighborCoordOffset(inout uint code){
    uint neighIndex = firstbitlow(code);
    float2 offset = Offsets_Box3x3[neighIndex];
    
    // Clear current lowest 1-bit
    // Code is set as inout, so it will change to
    // next lowest bit after function returns 
    code &= (~(1 << neighIndex));

    return offset;
}


// | _11 | _12 | _13 |
// | _21 | _22 | _23 |
// | _31 | _32 | _33 |
float3x3 SampleBox3x3_UAV_R(
    RWTexture2D<float> src,
    int2 texel
){
    float3x3 box;
 
    box.TopLeft      = src.Load(int3(texel + Offset_TopLeft, 0)).r;
    box.TopCenter    = src.Load(int3(texel + Offset_TopCenter, 0)).r;
    box.TopRight     = src.Load(int3(texel + Offset_TopRight, 0)).r;
    
    box.CenterLeft   = src.Load(int3(texel + Offset_CenterLeft, 0)).r;
    box.CenterCenter = src.Load(int3(texel, 0)).r;
    box.CenterRight  = src.Load(int3(texel + Offset_CenterRight, 0)).r;
    
    box.BottomLeft   = src.Load(int3(texel + Offset_BottomLeft, 0)).r;
    box.BottomCenter = src.Load(int3(texel + Offset_BottomCenter, 0)).r;
    box.BottomRight  = src.Load(int3(texel + Offset_BottomRight, 0)).r;

    return box;
}

#define OUT_OF_BOUND(addr, screenSize) ((((addr).x < 0) || (screenSize.x < (addr).x) || ((addr).y < 0) || (screenSize.y < (addr).y)))

float SafeLoad_R(Texture2D<float> src, int2 addr, float2 screenSize)
{
    bool outOfRange = OUT_OF_BOUND(addr, screenSize);

    return outOfRange ? 0 : src.Load(int3((addr), 0));
}
uint SafeLoad_R_U32(Texture2D<uint> src, int2 addr, float2 screenSize)
{
    bool outOfRange = OUT_OF_BOUND(addr, screenSize);

    return outOfRange ? 0 : src.Load(int3((addr), 0));
}

float4 SafeLoad_RGBA(Texture2D<float4> src, int2 addr, float2 screenSize)
{
    bool outOfRange = any(addr < float2(.0f, .0f)) || any(addr >= screenSize);

    return outOfRange ? 0 : src.Load(int3((addr), 0));
}

float3x3 SampleBox3x3_R(
    Texture2D<float> src,
    int2 texel,
    float2 screenSize
){
    float3x3 box;
 
    box.TopLeft =       SafeLoad_R(src, ((texel + Offset_TopLeft)), screenSize);
    box.TopCenter =     SafeLoad_R(src, ((texel + Offset_TopCenter)), screenSize);
    box.TopRight =      SafeLoad_R(src, ((texel + Offset_TopRight)), screenSize);
    
    box.CenterLeft =    SafeLoad_R(src, ((texel + Offset_CenterLeft)), screenSize);
    box.CenterCenter =  SafeLoad_R(src, ((texel)), screenSize);
    box.CenterRight =   SafeLoad_R(src, ((texel + Offset_CenterRight)), screenSize);
    
    box.BottomLeft =    SafeLoad_R(src, ((texel + Offset_BottomLeft)), screenSize);
    box.BottomCenter =  SafeLoad_R(src, ((texel + Offset_BottomCenter)), screenSize);
    box.BottomRight =   SafeLoad_R(src, ((texel + Offset_BottomRight)), screenSize);

    return box;
}

uint3x3 SampleBox3x3_R_U32(
    Texture2D<uint> src,
    int2 texel,
    float2 screenSize
) {
    uint3x3 box;

    box.TopLeft = SafeLoad_R_U32(src, ((texel + Offset_TopLeft)), screenSize);
    box.TopCenter = SafeLoad_R_U32(src, ((texel + Offset_TopCenter)), screenSize);
    box.TopRight = SafeLoad_R_U32(src, ((texel + Offset_TopRight)), screenSize);

    box.CenterLeft = SafeLoad_R_U32(src, ((texel + Offset_CenterLeft)), screenSize);
    box.CenterCenter = SafeLoad_R_U32(src, ((texel)), screenSize);
    box.CenterRight = SafeLoad_R_U32(src, ((texel + Offset_CenterRight)), screenSize);

    box.BottomLeft = SafeLoad_R_U32(src, ((texel + Offset_BottomLeft)), screenSize);
    box.BottomCenter = SafeLoad_R_U32(src, ((texel + Offset_BottomCenter)), screenSize);
    box.BottomRight = SafeLoad_R_U32(src, ((texel + Offset_BottomRight)), screenSize);

    return box;
}

//    *float3x3 box*            *Position*          *bit pos*
// | _11 | _12 | _13 | <<== | TL | TC | TR | =>>> | 8 | 1 | 2 |
// | _21 | _22 | _23 | <<== | CL | CC | CR | =>>> | 7 | P | 3 |
// | _31 | _32 | _33 | <<== | BL | BC | BR | =>>> | 6 | 5 | 4 |
uint ExtractNeighborBinaryCode_Box3X3_R_U32(uint3x3 box)
{
    uint binCode = 0;

    // From highest bit (box._11, Top-Left sample, 8th bit)
    binCode |= (box.TopLeft != 0u);
    binCode <<= 1;
    binCode |= (box.CenterLeft != 0u);
    binCode <<= 1;
    binCode |= (box.BottomLeft != 0u);
    binCode <<= 1;
    binCode |= (box.BottomCenter != 0u);
    binCode <<= 1;
    binCode |= (box.BottomRight != 0u);
    binCode <<= 1;
    binCode |= (box.CenterRight != 0u);
    binCode <<= 1;
    binCode |= (box.TopRight != 0u);
    binCode <<= 1;
    binCode |= (box.TopCenter != 0u);

    // Repeat, make code moudular
    // initial state:              -- -- -- XY
    binCode |= (binCode << 8);  // -- -- XY XY
    binCode |= (binCode << 16); // XY XY XY XY

    return binCode;
}

uint CountDiffBits(
    uint numbits, // highest bit to match                      // 8 
    uint bitMask, // mask unecessary bits in kernel            // 0x7D 7D 7D 7D 
    uint kernel,  // hit-miss kernel                           // 0x29 29 29 29 
    uint code     // binary code to match with hit-miss kernel // 0x37 37 37 37
){
    uint matchRes = ((code & bitMask) ^ kernel) & ((1 << numbits) - 1);
    return countbits(matchRes);
}

// 1 when hit, 0 when miss;
bool HitMiss(uint numbits, uint bitMask, uint kernel, uint code){
    return (CountDiffBits(numbits, bitMask, kernel, code) == 0);
}

bool HitMiss_RotationX4_2(
    uint numbits, 
    uint bitMask, 
    uint kernel, 
    uint code
){
    bool hit = false;
    
    [unroll]
    for (uint i = 0; i < 2; ++i){
        hit = (hit || HitMiss(numbits, bitMask, kernel, code));
        bitMask >>= 2; // Rotate by 90 degree
        kernel >>= 2;
    }

    return hit;
}

// 1 when hits >=1 of 4 kernels, 0 when misses all of them
bool HitMiss_RotationX4(
    uint numbits, 
    uint bitMask, 
    uint kernel, 
    uint code
){
    bool hit = false;
    
    [unroll]
    for (uint i = 0; i < 4; ++i){
        hit = (hit || HitMiss(numbits, bitMask, kernel, code));
        bitMask >>= 2; // Rotate by 90 degree
        kernel >>= 2;
    }

    return hit;
}

// 1 when hits >=1 of 4 kernels, 0 when misses all of them
bool HitMiss_RotationX2(
    uint numbits, 
    uint bitMask, 
    uint kernel, 
    uint code
){
    bool hit = false;
    
    [unroll]
    for (uint i = 0; i < 2; ++i){
        hit = (hit || HitMiss(numbits, bitMask, kernel, code));
        bitMask >>= 4; // Rotate by 180 degree
        kernel >>= 4;
    }

    return hit;
}

#define CROSS_MASK_LOW8     0x00000055
#define CROSS_MASK_HIGH8    0x000000aa
bool GHThinning_SubIter_0(uint code){
    uint crossOr = code | (code >> 1);

    uint code_n1 = crossOr & CROSS_MASK_HIGH8; // 1010 1010
    uint code_n2 = crossOr & CROSS_MASK_LOW8; // 0101 0101

    uint np = min(countbits(code_n1), countbits(code_n2));

    uint cp = countbits(((~code) & CROSS_MASK_LOW8) & (code_n1 >> 1));

    bool boundary = 
    (
        (0 == (1 & ((code | (code >> 1) | (~(code >> 3))) & (code >> 2))))
    );

    return ((cp == 1) && (2 <= np) && (np <= 3) && (boundary));
}

bool GHThinning_SubIter_1(uint code){
    uint crossOr = code | (code >> 1);

    uint code_n1 = crossOr & CROSS_MASK_HIGH8; // 1010 1010
    uint code_n2 = crossOr & CROSS_MASK_LOW8; // 0101 0101

    uint np = min(countbits(code_n1), countbits(code_n2));

    uint cp = countbits(((~code) & CROSS_MASK_LOW8) & (code_n1 >> 1));

    bool boundary = 
    (
        (0 == (1 & (((code >> 4) | (code >> 5) | (~(code >> 7)))) & (code >> 6)))
    );

    return ((cp == 1) && (2 <= np) && (np <= 3) && (boundary));
}

// 1st sub-iteration of a ZS-Style thinnging pass
// true if to be deleted, false otherwise
bool ZSThinning_SubIter_0(uint code){
    
    uint num1s = countbits(code & 0x000000ff);
    
    uint num01s = 0;
    uint codecpy = code;
    [unroll]
    for (uint i = 0; i < 8; i++){
        num01s += (uint)((codecpy & 3) == 2);
        codecpy >>= 1;
    }

    uint mask;
    mask = (1 << 4) | (1 << 2) | (1 << 0);
    uint num_neqz_135 = countbits(mask & code);
    mask = (1 << 6) | (1 << 4) | (1 << 2);
    uint num_neqz_357 = countbits(mask & code);

    return (
        (2 <= num1s && num1s <= 6) &&
        (num01s == 1) &&
        (num_neqz_135 < 3) &&
        (num_neqz_357 < 3)
    );
}

bool ZSThinning_SubIter_1(uint code){
    
    uint num1s = countbits(code & 0x000000ff);
    
    uint num01s = 0;
    uint codecpy = code;
    [unroll]
    for (uint i = 0; i < 8; i++){
        num01s += (uint)((codecpy & 3) == 2);
        codecpy >>= 1;
    }

    uint mask;
    mask = (1 << 6) | (1 << 2) | (1 << 0);
    uint num_neqz_137 = countbits(mask & code);
    mask = (1 << 6) | (1 << 4) | (1 << 0);
    uint num_neqz_157 = countbits(mask & code);

    return (
        (2 <= num1s && num1s <= 6) &&
        (num01s == 1) &&
        (num_neqz_137 < 3) &&
        (num_neqz_157 < 3)
    );
}

//    *float3x3 box*            *Position*          *bit pos*
// | _11 | _12 | _13 | <<== | TL | TC | TR | =>>> | 8 | 1 | 2 |
// | _21 | _22 | _23 | <<== | CL | CC | CR | =>>> | 7 | P | 3 |
// | _31 | _32 | _33 | <<== | BL | BC | BR | =>>> | 6 | 5 | 4 |

// (bitmask, kernel)
// | * | 1 | * |
// | * | P | 1 |
// | 0 | * | * |
#define CONV_BITMASK_TO_STRICTLY_8_CONNECTED (0x25252525)
#define CONV_KERNEL_TO_STRICTLY_8_CONNECTED (0x05050505)

#define TYPE_CURVE (0)
#define IS_CURVE_PIXEL(flag) (((flag) == TYPE_CURVE))

// | * | 1 | * |
// | 0 | P | 0 |
// | 1 | 0 | 1 |
#define BITMASK_JUNCTION_TYPE_0 (0x7d7d7d7d)
#define KERNEL_JUNCTION_TYPE_0 (0x29292929)
#define TYPE_JUNCTION_0 (1)

// | 1 | 0 | * |
// | 0 | P | 0 |
// | 1 | 0 | 1 |
#define BITMASK_JUNCTION_TYPE_1 (0xfdfdfdfd)
#define KERNEL_JUNCTION_TYPE_1 (0xa8a8a8a8)
#define TYPE_JUNCTION_1 (2)

// | * | 0 | 1 |
// | 1 | P | 0 |
// | * | 1 | * |
#define BITMASK_JUNCTION_TYPE_2 (0x57575757)
#define KERNEL_JUNCTION_TYPE_2 (0x52525252)
#define TYPE_JUNCTION_2 (3)

#define IS_JUNCTION_PIXEL(flag) ( \
    (flag == TYPE_JUNCTION_0) || (flag == TYPE_JUNCTION_1) || (flag == TYPE_JUNCTION_2)) \

// | * | 1 | * |
// | 0 | P | 0 |
// | 0 | 0 | 0 |
#define BITMASK_LINEEND_TYPE_0 (0x7d7d7d7d)
#define KERNEL_LINEEND_TYPE_0 (0x01010101)
#define TYPE_LINEEND_0 (4)

// | 1 | 0 | 0 |
// | 0 | P | 0 |
// | 0 | 0 | 0 |
#define BITMASK_LINEEND_TYPE_1 (0xffffffff)
#define KERNEL_LINEEND_TYPE_1 (0x80808080)
#define TYPE_LINEEND_1 (5)

#define IS_LINEEND_PIXEL(flag) ( \
    (flag == TYPE_LINEEND_0) || (flag == TYPE_LINEEND_1)) \



// 1-3: junction type
// 0: not a junction
uint JunctionTest(uint code){
    if (HitMiss_RotationX4(
            8,
            BITMASK_JUNCTION_TYPE_0, 
            KERNEL_JUNCTION_TYPE_0, 
            code))
    {
            return TYPE_JUNCTION_0;
    }
    if (HitMiss_RotationX4(
            8,
            BITMASK_JUNCTION_TYPE_1, 
            KERNEL_JUNCTION_TYPE_1, 
            code))
    {
            return TYPE_JUNCTION_1;
    }
    if (HitMiss_RotationX4(
            8,
            BITMASK_JUNCTION_TYPE_2, 
            KERNEL_JUNCTION_TYPE_2, 
            code))
    {
            return TYPE_JUNCTION_2;
    }
    return 0;
}

// 4-5: line-end type
// 0: not a line-end
uint LineEndTest(uint code){
    if (HitMiss_RotationX4(
            8,
            BITMASK_LINEEND_TYPE_0, 
            KERNEL_LINEEND_TYPE_0, 
            code))
    {
            return TYPE_LINEEND_0;
    }
    if (HitMiss_RotationX4(
            8,
            BITMASK_LINEEND_TYPE_1, 
            KERNEL_LINEEND_TYPE_1, 
            code))
    {
            return TYPE_LINEEND_1;
    }
    return 0;
}


#define BLACK 0
#define WHITE 1
// bit: 31, 29, ... , 2, 1, 0
#define BIT_AT(code, bit) (((code >> (bit)) & 1))
// --------------------------------------------------------------------------
// Contour Tracing
// --------------------------------------------------------------------------
// a) Edge Direction
// Each edge makes sure that black(foreground) pixel'0' is on the right
// ('0':= black pixel, '1':= white pixel) 
// 1     ^                                                *-->*
// ->  1 | 0 --- that is, for a isolated pixel, we have   | P |
// 0             a CW winding order.                      *<--* 
bool HasPixelEdge(uint edgeDir, uint boxCode)
{
    return ((BIT_AT(boxCode, edgeDir << 1)) == WHITE);
}
/**
 * \brief Compute edges around a BLACK pixel
 * \param boxCode 3x3 neighbor code
 * \return .xyzw: top,right,bottom,left edges;
 */
bool4 HasPixelEdges(uint boxCode)
{
	return bool4
	(
		(BIT_AT(boxCode, 0)) == WHITE,
		(BIT_AT(boxCode, 2)) == WHITE,
		(BIT_AT(boxCode, 4)) == WHITE,
		(BIT_AT(boxCode, 6)) == WHITE
	);
}
// 
// b) Edge (Direction) Codes
//     0       |  Edge is classified & identified via STAMP ID
//   *-->*     |  and its WINDING DIRECTION around that stamp.
// 3 | P | 1   |  See graph on left, P is the central stamp.
//   *<--*     |  Direction info is encoded in 2bits.
//     2       |

// (edgeDir + 3) % 4
uint TurnLeft(uint edgeDir)
{
    return (edgeDir + 3) % 4;
}

// (edgeDir + 1) % 4
uint TurnRight(uint edgeDir)
{
    return (edgeDir + 1) % 4;
}

uint TurnBack(uint edgeDir)
{
    return (edgeDir + 2) % 4;
}

// 
// c) Path Extension 
// How each edge finds its prev & next edges
// ________________________________________
// |0     X|    |1  ^  0|    |1     1| ... These 2 bits determines path extension result
// |<--+   |    |   |   |    |   +-->|
// |1  |  0|    |1  |  0|    |1  |  0| ... Suppose current edge is going upward this line
// Turn Left----Go Forward---Turn Right---
#define GET_NEXT_2_BITS(code, dir) (((code) >> (((dir) << 1) + 1)) & 3)
uint FindNextEdgeDir(uint dir, uint boxCode)
{
	uint next2Bits = GET_NEXT_2_BITS(boxCode, dir);
	
    uint nextDir = TurnLeft(dir); // == 0 or 2
    nextDir = next2Bits == 3 ? TurnRight(dir) : nextDir;
    nextDir = next2Bits == 1 ? dir : nextDir;

    return nextDir;
}

#define GET_PREV_2_BITS(code, dir) ((code >> ((((dir) << 1) + 6) % 8)) & 3)
uint FindPrevEdgeDir(uint dir, uint boxCode)
{
    uint prev2Bits = GET_PREV_2_BITS(boxCode, dir);
	
    uint prevDir = TurnRight(dir); // == 0 or 1
    prevDir = prev2Bits == 3 ? TurnLeft(dir) : prevDir;
    prevDir = prev2Bits == 2 ? dir : prevDir;

    return prevDir;
}



// Offsets for Edge Directions
static float2 MoveDir[4] =
{
    float2(1, 0), // dir#0
	float2(0, -1), // dir#1
	float2(-1, 0), // dir#2
	float2(0, 1) // dir#3
};
// (Recall)
// Edge Direction  
//	    0
//	  *-->*
//	3 | P | 1
//	  *<--*
//	    2
float2 MoveAtOppositeStamp(uint edgeDir)
{
	// Go to stamp on the opposite side of this edge
    return MoveDir[TurnLeft(edgeDir)];
}

float2 MoveAtNextStamp(uint edgeDir, uint nextDir)
{
	// Case #1: Move Straight
    float2 offset = MoveDir[edgeDir];
	// Case #2: Move to diagonal stamp
    offset = nextDir == TurnLeft(edgeDir) ?
		offset + MoveDir[nextDir]
		: offset;
	// Case #3: Self-Crossing(around original stamp)
    offset = nextDir == TurnRight(edgeDir) ?
		float2(0, 0) // zero offsets
		: offset;
    return offset;
}

float2 MoveAtPrevStamp(uint edgeDir, uint prevDir)
{
	return MoveAtNextStamp(
		TurnBack(prevDir),
		TurnBack(edgeDir)
	);
}

#undef GET_NEXT_2_BITS
#undef BIT_AT

#endif /* IMAGEPROCESSING_INCLUDED */
