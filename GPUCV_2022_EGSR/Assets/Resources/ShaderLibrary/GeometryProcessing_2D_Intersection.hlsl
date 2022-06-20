#ifndef D09A28E0_D4F8_4980_930A_94F363DAD590
#define D09A28E0_D4F8_4980_930A_94F363DAD590

#include "./GeometryProcessing.hlsl"

// --------------------------------------------------
// 2D Intersection
// From "Geometric tools for computer graphics"
// Chapter 7.1 - Intersection of 2D linear components
// --------------------------------------------------


bool G1D_X2_LinearComponents_Intersect(uint bits)
{
	return (bits & G1D_X2_LINEAR_COMPS_TOUCH_BIT)
		|| (bits & G1D_X2_LINEAR_COMPS_OVERLAP_BIT);
}

bool G2D_X2_LinearComponents_Intersect(uint bits)
{
	return (bits & G2D_X2_LINEAR_COMPS_CROSS_BIT)
		|| ( // When two components lies on the same line,
			(bits & G2D_X2_LINEAR_COMPS_COLLINEAR_BIT)
			// problem degenerates from 2D to 1D
			&& G1D_X2_LinearComponents_Intersect(bits)
		);
}

/**
 * \brief
 * Find the intersection of two 1d intervals \n
 * [u0, u1] and [v0, v1], \n
 * where u0 < u1 and v0 < v1.
 * 
 * \param w
 * If return code has G1D_X2_LINEAR_COMPS_TOUCH_BIT, 
 * - then w[0] contains that shared point; \n
 * If return code has G1D_X2_LINEAR_COMPS_OVERLAP_BIT, 
 * - intersected interval's two end points 
 * - are stored in w[0] and w[1]. \n
 * Otherwise, then two intervals do not intersect, 
 * - w has nothing to contain.
 */
int G1D_FindIntersection(
	float u0, float u1, float v0, float v1, 
	out float2 w
){
	uint res = 0;

	bool separated = (u1 < v0 || u0 > v1);
	if (!separated)
	{
		if (u1 > v0)
		{
			if (u0 < v1)
			{
				if (u0 < v0) w[0] = v0;
				else w[0] = u0;
				if (u1 > v1) w[1] = v1;
				else w[1] = u1;
				res |= G1D_X2_LINEAR_COMPS_OVERLAP_BIT;
			}
			else
			{
				// u0 == v1
				w[0] = u0;
				res |= G1D_X2_LINEAR_COMPS_TOUCH_BIT;
			}
		}
		else
		{
			// u1 == v0
			w[0] = u1;
			res |= G1D_X2_LINEAR_COMPS_TOUCH_BIT;
		}
	}

	return res;
}


/** 
 * \brief
 * Finds intersection of 2 lines in 2D.\n
 * Parametrized as: \n
 * LINE_0 P0 + s * D0 for s in [-00,+00],\n
 * LINE_1 P1 + t * D1 for t in [-00,+00] \n
 * \return
 * --------------------------------------------------- \n
 *
 * --------------------------------------------------- \n
 * GND_TWO_LINES_ERROR if unexpected result
 */
int G2D_FindIntersection_LineLine(
	float2 P0, float2 D0, out float s, 
	float2 P1, float2 D1, out float t
)
{
	uint res = 0;
	s = t = 0;
	
#define sqrEpsilon 0.00001f
	// LINE_0	P0 + s * D0, s in [0,1],
	// LINE_1	P1 + t * D1, t in [0,1]
	float2 E = P1 - P0;
	float kross = D0.x * D1.y - D0.y * D1.x;
	float sqrKross = kross * kross;
	float sqrLen0 = dot(D0, D0);
	float sqrLen1 = dot(D1, D1);
	// sin(angle(D0, D1))^2 < sqrEpsilon,
	// which means D0, D1 has a almost 0 degree angle
	bool isCollinear = sqrKross <= (sqrEpsilon * sqrLen0 * sqrLen1);

	// A) Intersects at a point
	if (false == isCollinear)
	{ 
		s = (E.x * D1.y - E.y * D1.x) / kross;
		t = (E.x * D0.y - E.y * D0.x) / kross;
		res |= G2D_X2_LINEAR_COMPS_CROSS_BIT;
	}
	
	// B) lines of the segment and ray are parallel or overlap
	if (true == isCollinear)
	{
		float sqrLenE = E.x * E.x + E.y * E.y;
		kross = E.x * D0.y - E.y * D0.x;
		sqrKross = kross * kross;
		bool onSameLine = (sqrKross <= (sqrEpsilon * sqrLen0 * sqrLenE));

		// B.1) lines of the segments are different
		//		=> Parallel Lines 
		if (false == onSameLine)
		{
			res |= G2D_X2_LINEAR_COMPS_PARALLEL_BIT;
		}
		// B.2) Lines of the segments are the same.
		//		=> On the same line
		else
		{ 
			res |= G2D_X2_LINEAR_COMPS_COLLINEAR_BIT;
		}
	}
	
	return res;
#undef sqrEpsilon
}

/** 
 * \brief
 * Finds intersection of 2d SEGMENT & RAY.\n
 * SEG P0 + s * D0 for s in [0,1],	\n
 * RAY P1 + t * D1 for t in [0, +00] \n
 * \return
 * --------------------------------------------------- \n
 * if there is a unique intersection, 
 * - the unique intersection: 
 * - P0 + s*D0 == P1 + t*D1 \n
 * --------------------------------------------------- \n
 * if two lines are the same(overlap), 
 * The overlap segment/point is represented as:
 * - [P0 + s*D0, P0 + t*D1] (case 1: overlap segment)
 * - P0 + s*D0	          (case 2: touching point) \n
 */
int G2D_FindIntersection_SegRay(
	float2 P0, float2 D0, out float s, 
	float2 P1, float2 D1, out float t
)
{
	uint res = G2D_FindIntersection_LineLine(
		P0, D0, /*out*/s, 
		P1, D1, /*out*/t
	);

	
	if ((res & G2D_X2_LINEAR_COMPS_CROSS_BIT) 
		&& (false == (.0 <= s && s <= 1.0 && .0 <= t))
	){ // lines intersect at a point Q,
		// but Q not in the ray or segment
		res &= (~G2D_X2_LINEAR_COMPS_CROSS_BIT);
		s = t = 0;
	}

	
	if (res & G2D_X2_LINEAR_COMPS_COLLINEAR_BIT)
	{ // When two lines overlap,
	// intersection degenerates to 1D case;
	// need to determine the overlap segment, if exists
		float2 E = P1 - P0;
		float sqrLen0 = dot(D0, D0);

		// --------------------------
		// represent ray's two ends
		// P1, P1+(+00)*V1
		// as line's parametrization:
		// P1			= P0 + s0*V0
		float s0 = dot(D0, E) / sqrLen0;
		// P1+(+00)*V1	= P0 + s1*V0
		float s1 = dot(D0, D1) > 0 ? MAX_F32 : -MAX_F32;
		// --------------------------

		float2 w;
		float smin = min(s0, s1), smax = max(s0, s1);
		res |= G1D_FindIntersection(
			0.0, 1.0, smin, smax, 
			/*out*/w
		);

		s = w.x;
		t = w.y;
	}
	
	return res;
#undef sqrEpsilon
}



#endif /* D09A28E0_D4F8_4980_930A_94F363DAD590 */
