#ifndef FEA04F3A_5A5B_4FC5_9477_75F89E8DAE58
#define FEA04F3A_5A5B_4FC5_9477_75F89E8DAE58

// Intersection Query for 2D Geometry.
// Code migrated from CGAL.
// See "\CGAL-5.3\include\CGAL\squared_distance_2_1.h"
// Author(s) : JiangWangZiWei

#include "./GeometryProcessing.hlsl"


struct G2D_Point
{
	float2 pos;
};
struct G2D_LinearComponent_SrcDir
{
	float2 source;
	float2 direction;

	float2 PosAt(float t)
	{
		return source + t * direction;
	}
};

struct G2D_LinearComponent_SrcTrg
{
	float2 source;
	float2 target;
};


#include "./GeometryUtils_2D_Distance.hlsl"
#include "./GeometryUtils_2D_Orientation.hlsl"


// ---------- Point-Point Distance ----------- //
float G2D_SqrDistance_PtPt(float2 pt0, float2 pt1)
{
	float2 vec = pt1 - pt0;
	return dot(vec, vec);
}


// ---------- Point-Line Distance ----------- //
float G2D_SqrDistance_PtLine(
	const float2 pt,
	const float2 line_dir,
	const float2 line_src
)
{
	float2 dir_pt2src = pt - line_src;

	float sqr_proj_len = dot(dir_pt2src, line_dir);
	sqr_proj_len = 
		(sqr_proj_len * sqr_proj_len)
		/ dot(line_dir, line_dir);
	
	return dot(dir_pt2src, dir_pt2src) - sqr_proj_len;
}
float G2D_SqrDistance_PtLine(
	const float2 pt,
	const float2 line_dir,
	const float2 line_src,
	out float s
)
{
	float2 dir_pt2src = pt - line_src;

	float sqr_len_line_dir = dot(line_dir, line_dir);

	float sqr_proj_len = dot(dir_pt2src, line_dir);

	s = sqr_proj_len / sqr_len_line_dir;

	sqr_proj_len = s * sqr_proj_len;
	
	return dot(dir_pt2src, dir_pt2src) - sqr_proj_len;
}






// ---------- Ponit-Ray Distance ------------- //
float squared_distance_pt_ray(float2 pt, float2 ray_source, float2 ray_dir)
{
    float2 diff = pt - ray_source;
	float dist = G2D_SqrDistance_PtLine(
		pt, ray_dir, ray_source
	);
	
    if (!is_acute_angle(ray_dir, diff))
      dist = dot(diff, diff);

	return dist;
}
float squared_distance_pt_ray(float2 pt, G2D_LinearComponent_SrcDir ray)
{
    return squared_distance_pt_ray(pt, ray.source, ray.direction);
}





// ---------- Point-Seg Distance ----------- //
float G2D_SqrDistance_PtSeg(
	const float2 pt,
	const G2D_LinearComponent_SrcDir seg,
	out float t // seg.source + t * seg.direction
){
	// assert that the segment is valid (non zero length).
	float2 diff		= pt - seg.source;
	float2 seg_targ = seg.source + seg.direction;

	float s = 0;
	float dist = G2D_SqrDistance_PtLine(
		pt, seg.direction, seg.source,
		/*out*/ s
	);
	t = s;
	
	if (s < .0f)
	{
		dist = dot(diff, diff);
		t = .0f;
	}

	if (s > 1.0f)
	{
		dist = G2D_SqrDistance_PtPt(pt, seg_targ);
		t = 1.0f;
	}

	return dist;
}





// ------------ Seg-Ray Distance ------------- //

float squared_distance_parallel_seg_ray(
	const G2D_LinearComponent_SrcTrg seg,
	const G2D_LinearComponent_SrcDir ray
)
{
    const float2 seg_dir = seg.target - seg.source;
    const float2 ray_dir = ray.direction;

	float2 vec_dist = G2D_SqrDistance_PtLine(
		ray.source, seg_dir, seg.source
	);
	
    if (same_direction(seg_dir, ray_dir)) {
      if (!is_acute_angle(seg.source, seg.target, ray.source))
        vec_dist = seg.target - ray.source;
    } else {
      if (!is_acute_angle(seg.target, seg.source, ray.source))
        vec_dist = seg.source - ray.source;
    }
	
    return dot(vec_dist, vec_dist);
}



float G2D_SqrDistance_SegRay_GTCG(
	const G2D_LinearComponent_SrcDir ray, out float t0, // p0 + t0*d0
	const G2D_LinearComponent_SrcDir seg, out float t1, // p1 + t1*d1
	out bool unique_pair, out uint code
)
{
#define sqrEpsilon 0.00001f
#define P0 ray.source
#define D0 ray.direction
#define P1 seg.source
#define D1 seg.direction

	float min_sqr_dist = 0;
	unique_pair = true;
	code = 0; // encodes the intersection states

	float2 startvec = ray.source - seg.source; // p0 - p1
	float2 endvec	= ray.source - (seg.source + seg.direction); // p0 - (p1+d1)

	float d0xd1 = wcross(D0, D1);
	float d0Dd1 = dot(D0, D1);
	float sqr_len_d0 = dot(D0, D0); // |D0|^2
	float sqr_len_d1 = dot(D1, D1); // |D1|^2
	float sqr_len_Vs = dot(startvec, startvec);
	// sin(angle(D0, D1))^2 < sqrEpsilon,
	// which means D0, D1 has a almost 0 degree angle
	bool same_dir = (d0xd1 * d0xd1) <= (sqrEpsilon * sqr_len_d0 * sqr_len_d1);

	
	if (!same_dir)
	{
		// (t0, t1) at line intersection, also the center of ellipse
		float t0_itsc = wcross(D1, startvec) / d0xd1;
		float t1_itsc = wcross(D0, startvec) / d0xd1;
		// seg src point proj at ray's line
		float t00_p1_proj2ray = dot(-startvec, D0) / sqr_len_d0;
		// seg dst point proj at ray's line
		float t01_p2_proj2ray = dot(-endvec, D0) / sqr_len_d0;
		// ray src point proj at seg's line
		float t1_p0_proj2seg  = dot(startvec, D1) / sqr_len_d1;

		// Note: these 2 conditions {e, f} must
		// be determined after {a, b, c, d} have been all checked.
		// So I put them up front.
		if (t00_p1_proj2ray < .0 && t1_p0_proj2seg < .0)
		{ // 'e' ellipse below
			t0 = .0f;
			t1 = .0f;
		}
		if (t01_p2_proj2ray < .0 && 1.0 < t1_p0_proj2seg)
		{ // 'f' ellipse below
			t0 = .0f;
			t1 = 1.0f;
		}

		if ((.0 <= t1_itsc && t1_itsc <= 1.0) 
			&& (.0 <= t0_itsc))
		{ // 'a' ellipse below
			// ray and seg intersects.
			// ellipse center(t0_itsc, t1_itsc) inside the constraint
			t0 = t0_itsc;
			t1 = t1_itsc;

			code |= G2D_X2_LINEAR_COMPS_CROSS_BIT; // 2 lines must intersect
		}
		if (t1_itsc < .0 && .0 <= t00_p1_proj2ray)
		{ // 'b' ellipse below
			t0 = t00_p1_proj2ray;
			t1 = .0f;
		}
		if (1.0 < t1_itsc && .0 <= t01_p2_proj2ray)
		{ // 'c' ellipse below
			t0 = t01_p2_proj2ray;
			t1 = 1.0f;
		}
		if ((.0 <= t1_p0_proj2seg && t1_p0_proj2seg <= 1)
			&& (t0_itsc < .0))
		{ // 'd' ellipse below
			t0 = .0f;
			t1 = t1_p0_proj2seg;
		}
		// Squared Distance can be written
		// as an covariant quadratic function
		// F(t0, t1) = || (P0 + t0*D0) - (P1 + t1*D1) ||^2,
		// 
		// F's level contours on t0-t1 plane
		// is a growing ellipse centered at (t0_itsc, t1_itsc)
		// 
		//                 t1
		//                 |                 
		//             f f |           c c          
		//           f     f         c     c
		//           f     f         c     c
		//   -  -  -   f f +-  -  -  - c c -  -  -  - t1 = 1
		//             d d |      a a  
		//           d     d    a     a                        
		//           d     d    a     a                         
		//             d d |      a a                         
		// ----------  e e-O----------------- b b -----t0
		//           e     e                b     b
		//           e     e                b     b
		//             e e |                  b b
		
	}else // Collinear or Parallel
	{
		float sqr_d0xVs = wcross(D0, startvec);
		sqr_d0xVs *= sqr_d0xVs;
		if (sqr_d0xVs < sqrEpsilon * sqr_len_d0 * sqr_len_Vs)
		{
			code |= G2D_X2_LINEAR_COMPS_COLLINEAR_BIT;
		}else
		{
			code |= G2D_X2_LINEAR_COMPS_PARALLEL_BIT;
		}

		// distance between two parallel/collinear lines
		t0 = 1.0f;
		t1 = dot(endvec, D1) / sqr_len_d1;
		unique_pair = false;

		// cases when cannot take a parallel line distance
		// when projection of seg onto ray's line is disjoint from ray.
		if (d0Dd1 < .0f && .0f <= dot(D0, startvec))
		{
			t0 = 0;
			t1 = 0;
			unique_pair = true;
		}
		if (d0Dd1 > .0f && .0f <= dot(D0, endvec))
		{
			t0 = 0;
			t1 = 1.0f;
			unique_pair = true;
		}
	}

	float2 dist_vec = ((P1 + t1 * D1) - (P0 + t0 * D0));
	min_sqr_dist = dot(dist_vec, dist_vec);
	
	return min_sqr_dist;
	
#undef D0
#undef P0
#undef D1
#undef P1
#undef sqrEpsilon
}


#endif /* FEA04F3A_5A5B_4FC5_9477_75F89E8DAE58 */
