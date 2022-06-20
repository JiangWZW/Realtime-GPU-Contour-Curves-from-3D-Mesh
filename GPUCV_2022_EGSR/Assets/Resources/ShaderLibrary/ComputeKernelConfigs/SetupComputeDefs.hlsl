#ifndef SETUPCOMPUTEDEFS_INCLUDED
#define SETUPCOMPUTEDEFS_INCLUDED

#define KERNEL_CONTOUR_INDIRECTION true

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

#include "../CustomComputeInputs.hlsl"
#include "../CustomShaderInputs.hlsl"
// Mesh Buffers(Raw)
#include "../ComputeBufferConfigs/MeshBuffers/CBuffer_EVList_View.hlsl"
// Raw Buffers - Per Edge Granularity
#include "../ComputeBufferConfigs/CBuffer_BufferRawPerEdge_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerEdge_View.hlsl"
// Raw Buffers - Per Contour Granularity
#include "../ComputeBufferConfigs/CBuffer_BufferRawContourToEdge_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawContourToSegment_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawFlagsPerContour_View.hlsl"
#include "../ComputeBufferConfigs/CBuffer_BufferRawRasterDataPerContour_View.hlsl"
// Raw Buffers - Per Segment Granularity
// Args Buffers
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "../ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"

#define USE_LOOK_BACK_TABLE_KERNEL_SEGMENTSCAN
#include "../ComputeBufferConfigs/CBuffer_BufferRawLookBacks_View.hlsl"


// ----------------------------------------------------------
// Functions for Rasterization
// ----------------------------------------------------------
static float4 g_HomogenousClipPlanes[6] =
{
	float4(1, 0, 0, 1), // -w <= x
	float4(-1, 0, 0, 1), // x <= w
	float4(0, -1, 0, 1), // y <= w 
	float4(0, 1, 0, 1), // -w <= y
	float4(0, 0, -1, 1), // z <= w
	float4(0, 0, 1, 0) // 0 <= z
};

float2 FrustumClipPerContour(
	float4 vposHClip0, float4 vposHClip1,
	out bool reject, out bool inside)
{
	float alpha0 = 0; // v0 = lerp(v0, v1, alpha0)
	float alpha1 = 1; // v1 = lerp(v0, v1, alpha1)
	reject = false; // Is this edge totally out of frustum
	inside = true; // Is this edge inside view frustum

	[unroll]
	for (uint i = 0; i < 6; ++i)
	{
		// Compute clip factor
		float d0 = dot(vposHClip0, g_HomogenousClipPlanes[i]);
		float d1 = dot(vposHClip1, g_HomogenousClipPlanes[i]);
		float alpha = d0 / (d0 - d1);

		// Clip edge
		bool out0 = d0 < 0; // if v0 is outside ith clip plane
		bool out1 = d1 < 0; // if v1 is outside ith clip plane
		inside = (inside && ((!out0) && (!out1)));

		if (out0 && (!out1))
		{
			// v0 outside, v1 inside, clip v0 to new position
			alpha0 = max(alpha, alpha0);
		}
		if ((!out0) && (out1))
		{
			// clip v1 to new position
			alpha1 = min(alpha, alpha1);
		}

		// Reject conditions:
		// 1. both verts of edge are on the outside of same clip plane
		// 2. verts "crosses" clip planes, 
		// -- where alpha1 > alpha0:
		//             .  V1
		//             . /
		//             X <--- alpha0
		//  alpha1   / .
		// .....->.X...+-----------------+
		//       /     |                 |
		//      V0     |  Screen Frustum |
		//             |     (in 2D)     |
		//             |                 |
		//             +-----------------+
		if ((out0 && out1) || (alpha0 > alpha1))
		{
			reject = true;
		}
	}

	return float2(alpha0, alpha1);
}


//////////////////////////////////////////////////////////////////////////////////////////
// Line rasterization rules: more complicated than triangles.
// For details:
// "Diamond Culling for Small Primitives"
// https://patentimages.storage.googleapis.com/af/05/64/2505d2921e4771/US7307628.pdf
// DX11 line rasterization rules
// https://microsoft.github.io/DirectX-Specs/d3d/archive/images/d3d11/D3D11_3_LineRast.png
// OpenGL/Vulkan raster rules
// https://github.com/WebKit/webkit/blob/master/Source/ThirdParty/ANGLE/src/libANGLE/renderer/vulkan/doc/OpenGLLineSegmentRasterization.md
// ---------------------------------------------------------------------------------------
//  *---------*---------*---------*---------* O--------> X
//  |       ./ \.       |       ./ \.       | | (coord convention
//  |     ./     \.     |     ./     \.     | |  y increases downwards)
//  |   ./         \.   |   ./         \.   | |
//  | ./  Internal   \. | ./   Internal  \. | |
//  |/    Diamond      \|/      Diamond    \| Y
//  |\.   (Dx, Dy)    ./|\.   (Dx+1, Dy)  ./|
//  |  \.           ./  |  \.           ./  |
//  |    \.       ./    |    \.       ./    |
//  |      \.   ./   External  \.   ./      |
//  |        \ /      Diamond    \ /        |
//  *---------*---------*---------*---------*
//  |       ./ \.    (Dx+1,     ./ \.       |
//  |     ./     \.   Dy+1)   ./     \.     |
//  |   ./         \.   |   ./         \.   |
//  | ./  Internal   \. | ./   Internal  \. |
//  |/    Diamond      \|/     Diamond     \|
//  |\.   (Dx, Dy+1)  ./|\.    (Dx + 1,   ./|
//  |  \.           ./  |  \.   Dy + 1) ./  |
//  |    \.       ./    |    \.       ./    |
//  |      \.   ./      |      \.   ./      |
//  |        \ /        |        \ /        |
//  *---------*---------*---------*---------*
// (Diamond Coordinate:Dxy, Diamond Type:DType) defines an unique diamond
bool isNeighboorDiamondsExtInt(
	uint2 diamond0External,
	uint2 diamond1Internal
)
{
	uint2 dxy = diamond0External - diamond1Internal;
	return ((dxy.x == 1) || (dxy.x == 0)) &&
		((dxy.y == 1) || (dxy.y == 0));
}


// Each point can calculate the diamond it belongs to, using formulas:
// 
// Given any point on screen at (x, y)
//
// 1.Setup some util variables
// Set xp = floor(x), yp = floor(yp); --- Pixel ID
// Set xc = x - (xp + .5), yc = y - (yp + .5); --- Direction from Pixel center
// 
// 2. We Compute its manhattan distance from pixel center
// dist_MHT = |xc| + |yc|;
//  *------------------------* For points P0, P1, P2 inside pixel:
//  | M>0.5    ./\.          | p0(inside external diamond): M < .5
//  |  P0    ./    \.        | p1(at diamond boudary): M = .5
//  |  |   ./        \.      | p2(inside interial diamond): M > .5
//  | |yc|/  P2--+     \.    |
//  |  |/   M<.5 |       \.  |
//  | /|         |         \ |
//  |* +--|xc|--XX---- +    *|
//  | \.      Center   |  ./ |
//  |   \.             |./   |
//  |     \.          P1     |
//  |       \.      ./M=.5   |
//  |         \.  ./         |
//  |           \/           |
//  *------------------------*
// Use these parameters to determine the diamond. 
// For full logic see implementation below.
uint3 ComputeDiamondCoord(float2 v, bool isXMajor)
{
	float2 p = floor(v);
	float2 dc = v - (p + float2(.5, .5));
	float dist_MHT = abs(dc.x) + abs(dc.y);

	bool isInternal = dist_MHT < 0.5;
	bool isBoundary = dist_MHT == 0.5;
	// The boundary of diamond needs to be handles specifically     
	// You see, things are not that easy...
	//   *-------*V0*--------* Internal Diamond
	//   |       ./ \.       | 1. includes bottom edges E1, E2
	//   |     ./     \.     | 2. and bottom vertex V2,
	//   |   E0         E3   | when y grows upwards
	//   * ./  Internal   \. | and x grows towards right
	//  #V/    Diamond      \V#
	//  #1\.   (Dx, Dy)    ./3#
	//   *  \.           ./  | 3. What's more, when line is y-major
	//   |    E1       E2    | internal diamond also includes
	//   |      \.   ./      | right diamond vertex V3
	//   |        \ /        |
	//   *-------*V2*--------*
	bool isDiamVert = (isBoundary && (dc.x == 0 || dc.y == 0));
	bool isDiamEdge = (isBoundary && (dc.x != 0 && dc.y != 0));

	bool isAtBottom = dc.y < 0;
	bool isAtRight = dc.x > 0;

	// Rule #1 in comment above
	bool isBottomEdge = isDiamEdge && isAtBottom;
	isInternal = isInternal || isBottomEdge;
	// Rule #2
	bool isBottomVert = isDiamVert && isAtBottom;
	isInternal = isInternal || isBottomVert;
	// Rule #3
	bool isRightVert = isDiamVert && isAtRight;
	isInternal = isInternal || (isRightVert && (!isXMajor));

	// Diamond indexing mechanism see comment above this function
	uint2 externalDiamIDOffset = uint2(
		dc.x > 0 ? 1 : 0,
		dc.y > 0 ? 1 : 0
	);

	// Return value
	// .xy:= (Dx, Dy);
	// .z:= InterlalDiamond ? 1 : 0 
	return isInternal ? uint3((uint2)floor(p), 1) : uint3((uint2)floor(p) + externalDiamIDOffset, 0);
}

// Logic to cull a line primitive:
bool DiamondCulling(float2 p0, float2 p1, bool isXMajor)
{
	// Compute "Diamond Coordinates"
	uint3 diamondInfo0 = ComputeDiamondCoord(p0, isXMajor);
	uint3 diamondInfo1 = ComputeDiamondCoord(p1, isXMajor);

	// Case #0: V0, V1 in the same diamond.
	bool3 compRes = (diamondInfo0 == diamondInfo1);
	bool case0 = compRes.x && compRes.y && compRes.z;

	// Case #1: V0, V1 in different diamonds,
	// but these 2 diamonds are adjacent external & internal ones.
	// By "Diamond Exit" rule, 
	// line can survive only if it "exits" current diamond region.
	//  *---------*---------*
	//  |       ./ \.       |
	//  |     ./     \.     |
	//  |   ./         \.   |
	//  | ./             \. |
	//  |/    V1           \|
	//  |\.   /           ./|
	//  |  \./          ./  |
	//  |   /\.       ./    |
	//  |  /   \.   ./      |
	//  | V0     \ /        |
	//  *---------*---------*
	bool case1 =
		diamondInfo0.z == 0 && // p0 is inside external diamond
		diamondInfo1.z == 1 && // p1 is inside internal diamond
		isNeighboorDiamondsExtInt(p0, p1); // adjacent diamonds

	return (case0 || case1);
}

float4 DiamondCullLine(
	float4 begend, // Edge points on screen with CW order
	bool isXMajor,
	bool startFromP0 // Is this line start from begend.xy
)
{
	float4 res;
	bool rejectWholeLine = false;
	// Diamond test needs input point
	// to follow its original order(for contours, CW order)
	rejectWholeLine = DiamondCulling(begend.xy, begend.zw, isXMajor);
	// Reorder coordinates
	// ------------------------------------------------------
	// Reorder componets such that major coord is at .x & .z,
	// and dual coord is at .y, .w;
	begend = isXMajor ? begend.xyzw : begend.yxwz;
	// We need to make sure vertex follows
	// ascending order in major coord
	begend = startFromP0 ? begend.xyzw : begend.zwxy;

	// *-----------*-----------*-----------*-----------*
	// |           |           |           |           |
	// |           |           |  Case 1:  |           |
	// |           |           |  x-major  |           |
	// |           |   P1     Q1..P0--P1...Q0           |
	// |           |  .        |           |           |
	// *-----------*-Q1--------*-----------*-----------*
	// |           |/          |           |           |
	// | Case0:    /           |   P1      |           |
	// | y-major  /|           | _/        |           |
	// |         / |           Q1          |           |
	// |        /  |         _/|           |           |
	// *-------Q0--*-------_/--*--------(Q)P1----------*
	// |      .    |     _/    |Case3:   _/|           |
	// |     .     |   _/      |x-major_/  |           |
	// |    .      | _/ Case2: |     _/    |           |
	// |  P0    (Q)P0  x-major |   _/      |           |
	// |           |           | _/        |           |
	// *-----------*-----------Q0----------*-----------*
	// |           |         _/|           |           |
	// |           |       P0  |           |           |
	// |           |           |           |           |
	// |           |           |           |           |
	// |           |           |           |           |
	// *-----------*-----------*-----------*-----------*
	float2 p0 = begend.xy;
	float2 p1 = begend.zw;

	float2 q0, q1;
	float factor;

	q0.x = ceil(p0.x);
	factor = (q0.x - p0.x) / (p1.x - p0.x);
	q0.y = lerp(p0.y, p1.y, factor);

	q1.x = floor(p1.x);
	factor = (p1.x - q1.x) / (p1.x - p0.x);
	q1.y = lerp(p0.y, p1.y, factor);

	// If is valid to cull(head & tail long enough for culling)
	bool2 cullable = (q0.x < q1.x).xx; // See case #1 above
	cullable = cullable && bool2(
		(p0.x != q0.x), // see case #2 above
		(p1.x != q1.x) // see case #3 above
	);

	// Swap back to CW order for diamond testing
	float4 headsegment = float4(p0.xy, q0.xy);
	float4 tailsegment = float4(q1.xy, p1.xy);
	headsegment = isXMajor ? headsegment.xyzw : headsegment.yxwz;
	tailsegment = isXMajor ? tailsegment.xyzw : tailsegment.yxwz;
	// cullable.x        cullable.y
	// P0..Q0------------Q1...P1 startfromP0 == true
	// head.xyzw         tail.xyzw
	// ========== Swap ===========
	// tail.zwxy         head.zwxy
	// P1..Q1------------Q0...P0 startfromP0 == false
	// cullable.y        cullable.x
	float4 tempsegment = headsegment;
	headsegment = startFromP0 ? headsegment.xyzw : tailsegment.zwxy;
	tailsegment = startFromP0 ? tailsegment.xyzw : tempsegment.zwxy;

	cullable = startFromP0 ? cullable.xy : cullable.yx;
	cullable = cullable && bool2(
		DiamondCulling(headsegment.xy, headsegment.zw, isXMajor),
		DiamondCulling(tailsegment.xy, tailsegment.zw, isXMajor)
	);

	headsegment.xy = cullable.x ? headsegment.zw : headsegment.xy;
	tailsegment.zw = cullable.y ? tailsegment.xy : tailsegment.zw;

	// rejectWholeLine = false; // Debug        
	res = rejectWholeLine ? float4(0, 0, 0, 0) : float4(headsegment.xy, tailsegment.zw);
	// res = rejectWholeLine ? float4(0, 0, 0, 0) : begend; // Debug

	return res;
}

/////////////////////////////////////////////////////////////
// Normally, triangle rasterization follows "Diamond Rule",
// that is, we rasterize pixel for triangle
// only if pixel center is inside that triangle.
// ---------------------------------------------------------
// But there is a special case:
// When pixel center sits right at an edge of triangle,
// in DX they follow "Top-Left" rule:
// only raster pixels when they locate on a "left/top edge"
// '*' means inside triangle
// 'X' means pixel center
// V1.y > V0.y  | V1.x > V0.x && V1.y == V0.y
// Left-Edge:V1 | Top-Edge:
// V0->V1   /*  | (Horizontal in x)
//        /***  | 
//      X*****  | V0 -----X-----> V1
//    /*******  | *****************
//  V0********  | *****************
float3 ComputeEdgeFunctionParams(float2 v0, float2 v1)
{
	// --------------------------------------------------------------
	// Let edge e with 2 verts(v0, v1),
	// and v0->v1 has clockwise winding order in screen;
	// (By default, DX11 assigns verts in triangle in clockwise order)
	// ---------------------------------------------------------------
	// Then we can define edge function:
	// F_0_1(P) = (x1 - x0)(yp - y0) - (y1 - y0)(xp - x0)
	// = (y0 - y1)xp + (x1 - x0)yp + (x0y1 - y0x1)
	// =         Axp         + Byp         + C 
	// = dot((A, B, C), (xp, yp, 1));
	// ----------------------------------------------------
	// So we compute parameters:
	// A := y0 - y1;
	// B := x1 - x0;
	// C := x0y1 - y0x1;
	return float3(
		v0.y - v1.y,
		v1.x - v0.x,
		v0.x * v1.y - v0.y * v1.x
	);
}

#define IS_LEFT_EDGE(DXY) ((0 < DXY.y))
#define IS_TOP_EDGE(DXY) ((DXY.y == 0 && 0 < DXY.x))

bool isTopLeft(float2 frag0, float2 frag1)
{
	float2 dxy = frag1 - frag0;
	return (IS_LEFT_EDGE(dxy) || IS_TOP_EDGE(dxy));
}

// From "com.unity.render-pipelines.core\ShaderLibrary\Common.hlsl"
// ----------------------------------------------------------------------------------
// The returned Z value is the depth buffer value (and NOT linear view space Z value).
// Use case examples:
// (position = positionCS) => (clipSpaceTransform = use default)
// (position = positionVS) => (clipSpaceTransform = UNITY_MATRIX_P)
// (position = positionWS) => (clipSpaceTransform = UNITY_MATRIX_VP)
float3 HClipToNDC(float4 positionCS)
{
#if UNITY_UV_STARTS_AT_TOP
	// Our world space, view space, screen space and NDC space are Y-up.
	// Our clip space is flipped upside-down due to poor legacy Unity design.
	// The flip is baked into the projection matrix, so we only have to flip
        // manually when going from CS to NDC and back.
        positionCS.y = -positionCS.y;
#endif

	positionCS /= (positionCS.w);
	positionCS.xy = positionCS.xy * 0.5 + 0.5;

	return positionCS.xyz;
}


// Canvas Lines: ---------------------------------------------------------------------
// To get better boundary tracing,
// we add 4 lines along screen edges to 'enclose' the whole image.
// this is done by adding following modifications:
// contour setup kernel:		inject 4 extra contour edges to raster
// segment visibility kernel:	always set fragments of these canvas edges as 'visible'
#define STAMP_MULTI_SAMPLE
#define CANVAS_OFFSET_W ((1.0))
#define CANVAS_OFFSET_H ((1.0))
#define CANVAS_LOW_W CANVAS_OFFSET_W
#define CANVAS_LOW_H CANVAS_OFFSET_H
#ifdef STAMP_MULTI_SAMPLE
#define CANVAS_HIGH_W ((((float)_StampMS) * (_ScreenParams.x) - CANVAS_OFFSET_W) + 0.5)
#define CANVAS_HIGH_H ((((float)_StampMS) * (_ScreenParams.y) - CANVAS_OFFSET_H) + 0.5)
#endif


static float2 _CanvasPointsHC[4] =
{
	float2(CANVAS_LOW_W,	CANVAS_LOW_H),
	float2(CANVAS_HIGH_W,	CANVAS_LOW_H),
	float2(CANVAS_HIGH_W,	CANVAS_HIGH_H),
	float2(CANVAS_LOW_W,	CANVAS_HIGH_H)
};

static float2 _CanvasNormalsSS[4] =
{
	float2(0, -1), float2(-1, 0), float2(0, 1), float2(1, 0)
};

// Note on max & min ops:
// In later boundary following process,
// if we don't cull fragments at screen texture boundary,
// for instance, stamp with coord of (x, 768) in 1024X768 render,
// which is possible 'cause of our frustum clipper is not that smart;
// the boundary tracing(linking) process will fuck itself up
float2 NDCToViewport(float2 coordNDC)
{
	float2 coordVP =
		max(
			float2(0.5, 0.5),
			min(
#ifdef STAMP_MULTI_SAMPLE
				((float)_StampMS) * coordNDC * CVector_ScreenTexelSize_SS.xy,
				((float)_StampMS) * CVector_ScreenTexelSize_SS.xy - 1.0f
#else
				coordNDC * CVector_ScreenTexelSize_SS.xy,
				CVector_ScreenTexelSize_SS.xy - 1
#endif
			)
		);

	return coordVP;
}
float2 ViewportToNDC(float2 coordSS)
{
	float2 coordNDC =
#ifdef STAMP_MULTI_SAMPLE
		(_RCP_StampMS * coordSS) / (CVector_ScreenTexelSize_SS.xy);
#else
		coordSS / CVector_ScreenTexelSize_SS.xy;
#endif

	return saturate(coordNDC);
}

bool OcclusionCullPerContour(
	float2 posNDC0, float2 posNDC1,
	float maxZBufferVal,
	float2 hizTexRes,
	Texture2D<float> hizTex
)
{
	// Bounding box in NDC space
	float4 bbox = float4(
		min(posNDC0, posNDC1).xy,
		max(posNDC0, posNDC1).xy
	);
	bbox = saturate(bbox);
	// Compute mip map level via boundingn box size
	float2 boxSize = (bbox.zw - bbox.xy) * hizTexRes;
	float mip = ceil(log2(max(boxSize.x, boxSize.y)));
	mip = clamp(mip, 0, 11); // Match MaxBufferSize = 2048 in HizPass.cs;
	float2 mipRes = floor(exp2(-mip) * hizTexRes);

	// If in lower mip level(which mean better depth precision), 
	// bbox only covers < x2 texels along each axis,
	// then sample the lower mip instead.
	// +---------------+----------------+
	// |               |                |
	// |      ****************          |
	// |      ******** | *****          |
	// |      ******** | *****          |
	// |      ******** | *****          |
	// +------********-+-*****----------+
	// |      ******** | *****          |
	// |      ******** | *****          |
	// |      ****************          |
	// |               |                |
	// |               |                |
	// +---------------+----------------+
	float mipLower = max(mip - 1, 0);
	float2 mipResLower = mipRes * 2;
	float2 maxCorner = ceil(mipResLower * bbox.zw);
	float2 minCorner = floor(mipResLower * bbox.xy);
	float2 pixelCoverageLower = maxCorner - minCorner;
	bool useFinerGrainedMip =
		(pixelCoverageLower.x <= 2.1 && pixelCoverageLower.y <= 2.1);
	mip = useFinerGrainedMip ? mipLower : mip;
	mipRes = useFinerGrainedMip ? mipResLower : mipRes;

	// NDC -> Mip-Map texture space
	bbox.yw = float2(1, 1) - bbox.yw; // flip y in texture space
	bbox *= mipRes.xyxy; // texel coordinate
	// Adjust sample positions when they are near texel boundary 
	bbox.xy += lerp(float2(0, 0), float2(0.5, 0.5), frac(bbox.xy) > 0.999);
	bbox.zw -= lerp(float2(0, 0), float2(0.5, 0.5), frac(bbox.zw) < 0.001);
	// Sample x4
	float4 zSamples = float4(
		hizTex.Load(uint3(bbox.xy, mip)).r,
		hizTex.Load(uint3(bbox.xw, mip)).r,
		hizTex.Load(uint3(bbox.zw, mip)).r,
		hizTex.Load(uint3(bbox.zy, mip)).r
	);
	zSamples.xy = min(zSamples.xy, zSamples.zw); // Reversed-Z, use min depth
	zSamples.x = min(zSamples.x, zSamples.y);

	// TODO: Further Investigation!!!
	// Due to some mysterious reason, hiz occlusion will 
	// "over-cull" some pixels, which is bad for later 
	// pixel chaining process...
	return (zSamples.x > maxZBufferVal + 0.001);
}


#define GROUP_SIZE_0 128

#define GROUP_SIZE_1 256
#define BITS_GROUP_SIZE_1 8

// Match with GROUP_SIZE_1 in SegmentAllocationComputeDefs.hlsl
#define GROUP_SIZE_NEXT 256
#define BITS_GROUP_SIZE_NEXT 8
#endif /* SETUPCOMPUTEDEFS_INCLUDED */
