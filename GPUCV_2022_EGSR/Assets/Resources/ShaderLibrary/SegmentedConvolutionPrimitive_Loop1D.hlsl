#include "./ComputeAddressingDefs.hlsl"

// --- Input Example ---------------------------------

// ------------------------------------------------






// ------------------------------------------------
#ifndef CAT
// Macro expansion, for details, see
// ---------------------------------------
// https://stackoverflow.com/questions/1489932/how-to-concatenate-twice-with-the-c-preprocessor-and-expand-a-macro-as-in-arg
#define CAT_(x, y) x ## y
#define CAT(x, y) CAT_(x, y)
#endif

// Convolution Data Cache
#ifdef NUM_PATCHES_PER_GROUP
#	undef NUM_PATCHES_PER_GROUP
#endif
#define NUM_PATCHES_PER_GROUP ((2 * MAX_CONV_RADIUS))
#define CONV_LDS_LEN ((GROUP_SIZE_CONV + 2 * MAX_CONV_RADIUS))

// Data Layout
//
// Global work distribution is very simple:
// Thread #i maps to element #i(ElemIdGl)
//
// Local work distribution in thread group:
// Suppose convolution radius == 4, group size == 6:
// (1) Padding is applied to LDS_ConvData_tag[]:
groupshared T_CONV CAT(LDS_ConvData_, tag)[CONV_LDS_LEN];
//	0	1	2	3	4	5	6	7	8	9	10	11	12
//	|<-Padding->|				        |<-Padding->|
//       X4				   X6				  X4
//
//
// (2) Patching for loop segments: 
groupshared T_CONV CAT(LDS_ConvPatch_, tag)[NUM_PATCHES_PER_GROUP];
//	Padding is not enough for convolution when
//	circular segment(loop) exists.
//	FIRST-TAIL and LAST-HEAD can cause a long "jump"
//	when convolution goes across them, and the jump
//  may lead to elements far away from LDS_ConvData_tag.
//
//  FIRST-TAIL t and LAST-HEAD h have special patches,
//  stored in LDS_ConvPatch_tag.
//  For details, see "https://zhuanlan.zhihu.com/p/263566817"


/* Map a thread to its target element */

int CAT(GroupIdx_To_ElemIdLc_, tag)(uint blockId, uint groupIdx)
{
	return (blockId == 0)
		? groupIdx
		: (groupIdx + MAX_CONV_RADIUS);
}
int CAT(GroupIdx_To_ElemIdGl_, tag)(uint blockId, uint groupIdx)
{ // essentially id.x
	return (groupIdx + blockId * GROUP_SIZE_CONV);
}



/* Transfer between elem's local and global id */

int CAT(ElemIdLc_To_Gl_, tag)(int elemIdLc, uint blockId)
{
	int elemIdGlStart =
		(blockId == 0) ? 0
		: ((int)(blockId * GROUP_SIZE_CONV) - MAX_CONV_RADIUS);

	return elemIdLc + elemIdGlStart;
}
int CAT(ElemIdGl_To_Lc_, tag)(int elemIdGl, uint blockId)
{
	int elemIdGlStart =
		(blockId == 0) ? 0
		: (int)(blockId * GROUP_SIZE_CONV) - MAX_CONV_RADIUS;

	return elemIdGl - elemIdGlStart;
}


/* Patching logic for convolution */

bool CAT(IsElemIdLc_RightPatch_, tag)(int elemIdLc, uint blockId)
{
	return (elemIdLc >= (
		blockId != 0
		? ((int)CONV_LDS_LEN)
		: ((int)(CONV_LDS_LEN - MAX_CONV_RADIUS))
		));
}
bool CAT(IsElemIdLc_LeftPatch_, tag)(int elemIdLc, uint blockId)
{
	return elemIdLc < 0;
}

uint CAT(RightPatchElemId_LastHead_, tag)(
	uint segTailIdGl, uint elemIdGl
) {
	// elemIdGl | segTail-3, -2, -1, (let MAX_CONV_RADIUS==3)
	// patchId  |		  3,  4,  5
	uint dist = (segTailIdGl - elemIdGl + 1);
	return 2 * MAX_CONV_RADIUS - dist;
}
uint CAT(LeftPatchElemId_FirstTail_, tag)(
	uint segHeadIdGl, uint elemIdGl
) {
	return elemIdGl - segHeadIdGl;
}


void CAT(MoveConvElemId_, tag)(
	bool moveLeft, uint offset,
	uint blockId, uint groupIdx : SV_GroupIndex,
	uint segLen, uint segHeadId,
	out uint elemIdGl, out int elemIdLc
) {
	elemIdGl = CAT(GroupIdx_To_ElemIdGl_, tag)(blockId, groupIdx);

	offset = offset % segLen;

	elemIdGl -= segHeadId;
	elemIdGl += (moveLeft ? (segLen - offset) : offset);
	elemIdGl = elemIdGl % segLen;
	elemIdGl += segHeadId;

	elemIdLc = CAT(ElemIdGl_To_Lc_, tag)(elemIdGl, blockId);
}



void CAT(PatchData_LoadDevice_StoreLDS_, tag)(
	uint blockId, uint patchIdLc, uint elemCount
) {
	if (patchIdLc < NUM_PATCHES_PER_GROUP)
	{ // load patch-edge id
		uint patchIdGl = DEVICE_LOAD_CONV_PATCH_ID(blockId, patchIdLc);
		CAT(LDS_ConvPatch_, tag)[patchIdLc] = DEVICE_LOAD_CONV_DATA(patchIdGl);
	}
}

void CAT(ConvData_LoadDevice_StoreLDS_, tag)(
	uint blockId, uint groupIdx, out T_CONV convData
) {
	int elemIdGl = CAT(GroupIdx_To_ElemIdGl_, tag)(blockId, groupIdx);
	int elemIdLc = CAT(GroupIdx_To_ElemIdLc_, tag)(blockId, groupIdx);

	convData = DEVICE_LOAD_CONV_DATA(elemIdGl);

	CAT(LDS_ConvData_, tag)[elemIdLc] = convData;
}

void CAT(Padding_LoadDevice_StoreLDS_, tag)(uint blockId, uint groupIdx)
{
	bool leftPadding =
		(0 < blockId) && (groupIdx < MAX_CONV_RADIUS);
	bool rightPadding =
		(GROUP_SIZE_CONV - MAX_CONV_RADIUS) <= groupIdx;

	int paddingIdLc =
		leftPadding ? (groupIdx) : ( /* rightPadding */
			(blockId == 0) ? (groupIdx + MAX_CONV_RADIUS)
			: (groupIdx + 2 * MAX_CONV_RADIUS));

	uint paddingIdGl = CAT(ElemIdLc_To_Gl_, tag)(paddingIdLc, blockId);

	[branch] if (leftPadding || rightPadding)
	{
		CAT(LDS_ConvData_, tag)[paddingIdLc] = DEVICE_LOAD_CONV_DATA(paddingIdGl);
	}
}


void CAT(SetupSegmentedConvolution_, tag)(
	uint3 gIdx, uint groupIdx, uint elemCount,
	out T_CONV convData)
{
	CAT(PatchData_LoadDevice_StoreLDS_, tag)(
		gIdx.x, groupIdx, elemCount
	);

	CAT(ConvData_LoadDevice_StoreLDS_, tag)(
		gIdx.x, groupIdx, /*out*/convData
	);

	CAT(Padding_LoadDevice_StoreLDS_, tag)(
		gIdx.x, groupIdx
	);
	GroupMemoryBarrierWithGroupSync();
}



/**
 * \brief Load convolution data with left offset
 * \param offset assert(offset <= MAX_CONV_RADIUS)
 */
T_CONV CAT(LoadLDSConvData_AtLeft_, tag)(
	uint offset,
	uint blockId, uint groupIdx : SV_GroupIndex,
	uint segLen, uint segHeadId
)
{
	T_CONV convData;

	uint elemIdGl = 0;
	int elemIdLc = 0;

	CAT(MoveConvElemId_, tag)(
		true, offset,
		blockId, groupIdx,
		segLen, segHeadId,
		// out -----------
		elemIdGl, elemIdLc
	);

	bool patch = CAT(IsElemIdLc_RightPatch_, tag)(elemIdLc, blockId);
	[branch] if (patch)
	{
		uint patchId = CAT(RightPatchElemId_LastHead_, tag)(
			segHeadId + segLen - 1,
			elemIdGl
		);
		convData = CAT(LDS_ConvPatch_, tag)[patchId];
	}
	else
	{
		convData = CAT(LDS_ConvData_, tag)[elemIdLc];
	}

	return convData;
}

/**
 * \brief Load convolution data with left offset
 * \param offset assert(offset <= MAX_CONV_RADIUS)
 */
T_CONV CAT(LoadLDSConvData_AtRight_, tag)(
	uint offset,
	uint blockId, uint groupIdx : SV_GroupIndex,
	uint segLen, uint segHeadId
)
{
	T_CONV convData;

	uint elemIdGl = 0;
	int elemIdLc = 0;

	CAT(MoveConvElemId_, tag)(
		false, offset,
		blockId, groupIdx,
		segLen, segHeadId,
		// out -----------
		elemIdGl, elemIdLc
	);

	bool patch = CAT(IsElemIdLc_LeftPatch_, tag)(elemIdLc, blockId);
	[branch] if (patch)
	{
		uint patchId = CAT(LeftPatchElemId_FirstTail_, tag)(
			segHeadId, elemIdGl
		);
		convData = CAT(LDS_ConvPatch_, tag)[patchId];
	}
	else
	{
		convData = CAT(LDS_ConvData_, tag)[elemIdLc];
	}

	return convData;
}





// Patch configs
#ifdef NULL_LEFT_TAIL
#	undef NULL_LEFT_TAIL
#endif
#define NULL_LEFT_TAIL (0xffffffff)

#ifdef NULL_RIGHT_HEAD
#	undef NULL_RIGHT_HEAD
#endif
#define NULL_RIGHT_HEAD 0

#ifdef INVALID_PATCH_EDGE_ID
#	undef INVALID_PATCH_EDGE_ID
#endif
#define INVALID_PATCH_EDGE_ID 0xffffffff


groupshared uint CAT(LDS_LeftTailGroupId_, tag) = NULL_LEFT_TAIL;
groupshared uint CAT(LDS_RightHeadGroupId_, tag) = NULL_RIGHT_HEAD;
groupshared uint CAT(LDS_PatchElemIds_, tag)[MAX_CONV_RADIUS * 2];
// = {
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID,
// 	INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID, INVALID_PATCH_EDGE_ID
// };

uint CAT(MoveElemIdAlongLoop_, tag)(uint elemId, int offset, uint loopHeadElemId, uint loopLen)
{
	bool moveLeft = offset < 0;

	uint d = abs(offset);
	d = d % loopLen;

	elemId -= loopHeadElemId;
	elemId += (moveLeft ? (loopLen - d) : d);
	elemId = (elemId % loopLen);
	elemId += loopHeadElemId;

	return elemId;
}


/**
 * \brief
 * Computes patching info for current Thread Group,
 * and stores at group shared memory CAT(LDS_PatchElemIds_, tag)
 * For details, see "https://zhuanlan.zhihu.com/p/263566817"
 * Patch info: Global id for patched elements
 * i: left seg head id
 * j: right seg tail id
 * @: shift elem forwards, with circular jump 
 * [left_patches, right_patches] 
 * |i,i@1,i@2,i@3|j,j@1,j@2,j@3| patched elems' IDs 
 * |<conv_radius>|<conv_radius>| 
 * \param segHead head element id
 * \param segTail tail element id
 * \param segLen segment length
 */
void CAT(ComptueBlockPatchElemIds_, tag)(
	uint groupIdx, 
	bool isSegHead, bool isSegTail, 
	uint segHead, uint segTail, uint segLen
){
	GroupMemoryBarrierWithGroupSync();
	/* ------------Loading Extra Neighboring Data---------------- */
	/* Step 1. Vote for right - most head && left - most tail */
	if ((isSegHead) != 0)
	{
		InterlockedMax(CAT(LDS_RightHeadGroupId_, tag), groupIdx + 1);
	}
	if ((isSegTail) != 0)
	{
		InterlockedMin(CAT(LDS_LeftTailGroupId_, tag), groupIdx);
	}
	GroupMemoryBarrierWithGroupSync();

	/* Step 2. Compute patching data address */
	bool foundLeftTail = 
		(CAT(LDS_LeftTailGroupId_, tag) != NULL_LEFT_TAIL);
	bool foundRightHead = 
		(CAT(LDS_RightHeadGroupId_, tag) != NULL_RIGHT_HEAD);

	if ((foundLeftTail && (groupIdx == CAT(LDS_LeftTailGroupId_, tag))) ||
		((!foundLeftTail) && (groupIdx == GROUP_SIZE_CONV - 1)))
	{
		/* Patch at LEFT */
		[unroll]
		for (uint i = 0; i < MAX_CONV_RADIUS; ++i)
		{
			CAT(LDS_PatchElemIds_, tag)[i] =
				CAT(MoveElemIdAlongLoop_, tag)(
					segHead,
					(int)i, /*offset*/
					segHead, segLen
				);
		}
	}

	if ((foundRightHead && ((groupIdx + 1) == CAT(LDS_RightHeadGroupId_, tag))) 
		|| ((!foundRightHead) && (groupIdx == 0)))
	{
		uint patchStart = 
			CAT(MoveElemIdAlongLoop_, tag)(
				segTail,
				-(int)(MAX_CONV_RADIUS - 1), /* offset */
				segHead, segLen
			);
		/* Patch at RIGHT */
		[unroll]
		for (uint i = 0; i < MAX_CONV_RADIUS; ++i)
		{
			CAT(LDS_PatchElemIds_, tag)[i + MAX_CONV_RADIUS] =
				CAT(MoveElemIdAlongLoop_, tag)(
					patchStart,
					(int)i, /* offset */
					segHead, segLen
				);
		}
	}
	GroupMemoryBarrierWithGroupSync();
}




#undef tag
// #undef MAX_CONV_RADIUS
// #undef GROUP_SIZE_CONV
#undef NULL_LEFT_TAIL
#undef NULL_RIGHT_HEAD
#undef DEVICE_LOAD_CONV_DATA
#undef DEVICE_LOAD_CONV_PATCH_ID
