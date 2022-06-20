#ifndef BRUSHTOOLBOX_INCLUDED
#define BRUSHTOOLBOX_INCLUDED

//
static uint DiagnalDividedQuadVertIDs[12] = {
	0, 1, 2,
	0, 2, 3,
	0, 3, 4,
	0, 4, 1
};

static float2 DiagnalDividedQuadOffets[5] = {
	float2(0, 0),
	float2(-1, 1),
	float2(-1, -1),
	float2(1, -1),
	float2(1, 1)
};

static float2 DiamondQuadOffsets[5] = {
	float2(0, 0),
	float2(-1, 0),
	float2(0, -1),
	float2(1, 0),
	float2(0, 1)
};

float2 ComputeStampPointNDC_xy(
	float2 posNDC,
	float2 tangentNormalized,
	float2 stampScale,
	uint vertIdLocal,
	out float2 baryCoords, // .x along T, .y along N
	out float2 uvCoords
)
{
	uint pointId = DiagnalDividedQuadVertIDs[vertIdLocal];
	float2 offset = DiagnalDividedQuadOffets[pointId];
	uvCoords = offset * .5 + float2(.5, .5); // [-1, 1] to [0, 1]

	float3 viewDir = float3(0, 0, 1);
	float2 normalNDC =
		stampScale.x * float2(
			// tangentNormalized.x, -tangentNormalized.y
			cross(float3(tangentNormalized.xy, 0), viewDir).xy
		);
	uint modid = vertIdLocal % 3;
	baryCoords.x = modid == 1 ? 1 : 0;
	baryCoords.y = modid == 2 ? 1 : 0;

	return (posNDC + offset.x * normalNDC + offset.y * stampScale.y * tangentNormalized);
}


// Anatomy of a round capped quad
//          P3__---P4--__P5
//         _/\     |     /\_
//     P2_/   \_   |   _/   \_P6
//     / \_     \  |  /     _/ \
//    /    \__   \ | /   __/    \
//   |        \___\|/___/        | 
//  P1____________ P0 ___________P7
//   |\            |\            |
//   | \           | \           |
//   |  \          |  \          |
//   |   \         |   \         |
//   |    \        |    \        |
//   |     \       |     \       |
//   |      \      |      \      |
//   |       \     |       \     |
//   |        \    |        \    |
//   |         \   |         \   |
//   |          \  |          \  |
//   |           \ |           \ |
//   |            \|            \|
// P15___________ P8 ____________P9
//   |        ___//|\\___        |  
//    \   ___/   / | \   \___   /   
//     \ /      /  |  \      \ /    
//    P14`\    /   |   \    /`P10
//         `\ /    |    \ /`        
//         P13--__P12__--P11        

#define CAP_ANGLE 0.52359877559829887307710723054658
#define CAP_RES 6
#define CircleCoord(n, theta) (float2(cos(n * theta), sin(n * theta)))
static float2 LUT_CosSinNTheta[CAP_RES + 1] = {
	float2(1, 0), // theta = 0
	CircleCoord(1, CAP_ANGLE),
	CircleCoord(2, CAP_ANGLE),
	float2(0, 1), // theta = pi/2
	CircleCoord(4, CAP_ANGLE),
	CircleCoord(5, CAP_ANGLE),
	float2(-1, 0) // theta = pi
};

static int CappedQuadVertIDs[42] = {
	// Cap around v0
	0, 1, 2,
	0, 2, 3,
	0, 3, 4,
	0, 4, 5,
	0, 5, 6,
	0, 6, 7,
	// Cap around v1
	8, 9, 10,
	8, 10, 11,
	8, 11, 12,
	8, 12, 13,
	8, 13, 14,
	8, 14, 15,
	// Quad
	1, 7, 15,
	15, 7, 9
	// 0, 7, 9,
	// 0, 9, 8,
	// 8, 1, 0,
	// 8, 15, 1
};

float2 ComputeCappedQuadPointNDC_xy(
	float2 posNDC0, float2 posNDC1,
	uint vertIdLocal, float lineWidth
)
{
	// Anatomy of a round capped quad
	//          P3__---P4--__P5        posNDC0: P0
	//         _/\     |     /\_       posNDC1: P8
	//     P2_/   \_   |   _/   \_P6   Verts in the same triangle
	//     / \_     \  |  /     _/ \   follow CW order.
	//    /    \__   \ | /   __/    \  |P1 - P0| = lineWidth
	//   |        \___\|/___/        | 
	//  P1____________ P0 ___________P7
	//   |\            |\            |
	//   | \           | \           |
	//   |  \          |  \          |
	//   |   \         |   \         |
	//   |    \        |    \        |
	//   |     \       |     \       |
	//   |      \      |      \      |
	//   |       \     |       \     |
	//   |        \    |        \    |
	//   |         \   |         \   |
	//   |          \  |          \  |
	//   |           \ |           \ |
	//   |            \|            \|
	// P15___________ P8 ____________P9
	//   |        ___//|\\___        |  
	//    \   ___/   / | \   \___   /   
	//     \ /      /  |  \      \ /    
	//    P14`\    /   |   \    /`P10
	//         `\ /    |    \ /`        
	//         P13--__P12__--P11        

	float2 quadLen = normalize(posNDC1.xy - posNDC0.xy);
	float3 viewDir = float3(0, 0, 1);
	float2 quadWidth =
		lineWidth * (
			cross(float3(quadLen.xy, 0), viewDir).xy
		);
	quadLen *= lineWidth;

	uint pointId = CappedQuadVertIDs[vertIdLocal];

	bool isV0 = (pointId == 0);
	bool isV1 = (pointId == 8);
	bool isV0Cap = (pointId < 8) && (!isV0);
	bool isCap = !(isV0 || isV1);
	uint N = (pointId % 8 - 1);

	float2 capCenter = (pointId < 8) ? posNDC0 : posNDC1;
	float2 pointOffset = LUT_CosSinNTheta[N];
	pointOffset = isV0Cap ? -pointOffset : pointOffset;
	pointOffset = isCap ? pointOffset : float2(0, 0);

	float2 vertPosOut =
		capCenter.xy
		+ pointOffset.x * quadWidth
		+ pointOffset.y * quadLen;

	return vertPosOut;
}

static float2 quadVertOffsets[4] = {
	float2(-1, -1),
	float2(1, 1),
	float2(1, -1),
	float2(-1, 1)
};
static float2 triagVertOffsets[6] = {
	quadVertOffsets[0],
	quadVertOffsets[2],
	quadVertOffsets[3],
	quadVertOffsets[2],
	quadVertOffsets[1],
	quadVertOffsets[3],
};

float4 ComputeQuadPointNDC(
	float4 posNDC0, float4 posNDC1,
	uint vertIdLocal, float lineWidth)
{
	float2 quadCenter = (posNDC0.xy + posNDC1.xy) * 0.5;
	float2 quadDir = posNDC1.xy - posNDC0.xy;
	float2 quadDirNormalized = normalize(quadDir);

	// Note: Reversed-Z on DX platforms
	// --------------------------------------------------------------------------
	// Z is reversed in NDC space, far at z=0 & near at z=1
	// * camera at z == 1(near plane) * <--------- * Infinity at z=0(far plane) *
	// till now, we should use viewDir = (0, 0, 1)
	// --------------------------------------------------------------------------
	float3 viewDir = float3(0, 0, 1);

	float2 vecOffsetWidth =
		lineWidth * (
			cross(float3(quadDirNormalized.xy, 0), viewDir).xy
		);
	float2 vecOffsetLength = 0.5 * quadDir.xy;

	// Left handed, front-facing verts 
	// follow CW order on screen
	// QuadDir = V1 - V0
	// VecOffsetWidth = cross(QuadDir, ViewDir)
	// ----- vecOffsetWidth ---->
	// P0------ V0 ------ P2 
	// |                _/|
	// |              _/  |
	// | Tri#0      _/    |
	// |      Center      |
	// |      _/          |
	// |    _/    Tri#1   |
	// |  _/              |
	// |_/                |
	// P3------ V1 ------ P1
	float2 offset = triagVertOffsets[vertIdLocal];

	// Compute output vertex position
	float4 vertPosOut;
	vertPosOut.xy = quadCenter.xy;
	vertPosOut.xy += offset.x * vecOffsetWidth + offset.y * vecOffsetLength;
	vertPosOut.zw = ((vertIdLocal & 1) == 0) ? posNDC0.zw : posNDC1.zw;

	// [0, 1] to [-1, 1]
	vertPosOut.xy = 2 * vertPosOut.xy - 1;

	// Inversion of "Homegenous Divide" to protect values
	vertPosOut.xy *= vertPosOut.w;

	return vertPosOut;
}


// Quad Anatomy
// Vertex ID
// 1 --------------- 2
// | \__             |
// |    \__          |
// |       \P\__     |
// |            \__  |
// |               \ |
// 0 --------------- 3
//  ---> Tangent --->
static float2 QuadVPBuffer[4] =
{
	float2(-1, -1),
	float2(-1, 0),
	float2(1, 1),
	float2(1, -1)
};

#define VERTS_PER_STAMP_QUAD 6
static uint QuadVertexBuffer[VERTS_PER_STAMP_QUAD] =
{
	0, 1, 3,
	1, 2, 3
};

float4x2 ComputeQuadVerts(
	float2 quadCenter,
	float2 tangent,
	float2 quadScale
)
{
	float4x2 res;
	float2 normal = float2(-tangent.y, tangent.x);
	[unroll]
	for (uint i = 0; i < 4; ++i)
	{
		// .xy: -1~1 NDC coord,
		// .zw: UV
		res[i].xy = QuadVPBuffer[i].xy;
		// Scale
		res[i].xy *= quadScale.yx; // tangent(res[i].x)~length(scale.y), normal(.y)~width(.x)
		// Rotation
		res[i].xy = res[i].x * tangent + res[i].y * normal;
		// Offset
		res[i].xy += quadCenter;
	}

	return res;
}


// Wing-Quad Anatomy
// V2 --------- V5
// \7         8/10\
//  \	    _/     \	... ...
//   \	  _/		\
//    \6 /9	       11\
// ==> V1 ========= V4 ==> Stroke Dir ==>
//     |1		  2/4|  
//     |	    _/	 |
//     |	  _/	 |
//     |    _/		 |	... ...
//     |0 _/		 |
//     |_/3		    5|
//	  V0 ----------- V3
// each Pixel-Edge forms a Spine: (V1->V4)
// and spans a "wing" (V1-{V0, V2})
// each Wing has 3 vertices
// point list(x12) is generated from vertices shared by multiple quad triangles
#define POINTS_PER_WING_QUAD 12
static uint WingQuadVertexBuffer[POINTS_PER_WING_QUAD] =
{
	0, 1, 4, // v0, v1, v4
	0, 4, 3,
	1, 2, 5,
	1, 5, 4
};

uint GetWingQuadVertexIndex(uint instanceId)
{
	uint spineId = instanceId / POINTS_PER_WING_QUAD;
	uint pointId = instanceId % POINTS_PER_WING_QUAD;

	uint vertId = WingQuadVertexBuffer[pointId];
	return 3u * spineId + vertId;
}

float2 GetWingQuadVertexUV(uint vertId)
{
//V2- --------- V5
//(0,1)        /(1,1)
//  \	    _/     \	... ...
//   \	  _/		\
//    \  /9	         \
// ==> V1 ========= V4 ==> Stroke Dir ==>
//    (0,.5)       (1,.5)
//     |	    _/	 |
//     |	  _/	 |
//     |    _/		 |	... ...
//     |  _/		 |
//    (0,0)		   (1,0)
//	  V0 ----------- V3
	float offsetU = (float)(vertId / 3u);
	float offsetV = .5f * (float)(vertId % 3u);
	
	return float2(offsetU, offsetV);
}

float3x2 ComputeWingQuadVerts(
	float2 centerCoord,
	float2 normal, float width
)
{
	float3x2 verts;
	verts[0] = centerCoord - width * normal;
	verts[1] = centerCoord;
	verts[2] = centerCoord + width * normal;

	return verts;
}





#endif /* BRUSHTOOLBOX_INCLUDED */
