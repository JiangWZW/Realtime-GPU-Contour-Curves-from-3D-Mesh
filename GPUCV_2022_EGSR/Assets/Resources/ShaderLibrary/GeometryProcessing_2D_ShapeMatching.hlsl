#ifndef FBDBCA2F_C4E3_475E_AD88_314A43900C2E
#define FBDBCA2F_C4E3_475E_AD88_314A43900C2E

#include "./GeometryProcessing.hlsl"
#include "./GeometryUtils_2D_Orientation.hlsl"

struct arap_info
{
	float2	 pc; // center of pi
	float2	 qc; // center of qi
	uint	 num_pts; // := #pi = #qi

	float2x2 rot;// rotation matrix
	float2	 t;	 // translation vec
	float    s;	 // scale factor
	float2	 s_temp;

	void init();

	void add_center_pos(float2 pi, float2 qi);
	void compute_center();
	
	void add_scale_rotation(float2 pi, float2 qi);
	void compute_transform();
};


void arap_info::init()
{
	pc = 0;
	qc = 0;
	num_pts = 0;
	rot = float2x2(0, 0, 0, 0);
	t = 0;
	s = 0;
	s_temp = 0;
}

void arap_info::add_center_pos(float2 pi, float2 qi)
{
	pc += pi;
	qc += qi;
	num_pts += 1;
}

void arap_info::compute_center()
{
	pc /= ((float)num_pts);
	qc /= ((float)num_pts);
}


void arap_info::add_scale_rotation(float2 pi, float2 qi)
{
	float2 pi_hat = pi - pc;
	float2 pi_hat_orth = orth_vec2d(pi_hat);
	float2 qi_hat = qi - qc;

	// accumulate rotation matrix
	rot += mul(
		float2x2(
			qi_hat.x,		qi_hat.y,
			qi_hat.y,		- qi_hat.x
		), 
		float2x2(
			pi_hat.x,		pi_hat.y, 
			pi_hat.y,		- pi_hat.x
		)
	);

	// accumulate scale factor
	s_temp[0] += dot(qi_hat, pi_hat);
	s_temp[1] += dot(qi_hat, pi_hat_orth);
}

void arap_info::compute_transform()
{
	s = length(s_temp);
	rot /= s;
	t = qc - mul(rot, pc);
}




struct ShapeMatching2D
{
	float2	 mjxj;
	float2	 mjx0j;
	float2x2 Aj;	// Sum_j(mj*mul(xj, xj0_T))
	float3   A0j;	// Sum_j(mj*mul(xj0, xj0_T)),
	// since it's symmetric, store as (._11, _12, ._22)

	void initZero()
	{
		mjxj = mjx0j = 0;
		Aj = 0;
		A0j = 0;
	}
	void init(float2 xj, float2 xj0, float mj)
	{
		mjxj = mj * xj;
		mjx0j = mj * xj0;
		Aj = mj * float2x2(
			xj.x * xj0.x, xj.x * xj0.y,
			xj0.x * xj.y, xj.y * xj0.y
		);
		A0j = mj * float3(
			xj0.x * xj0.x, // ._11
			xj0.x * xj0.y, // ._12 == ._21
			xj0.y * xj0.y  // ._22
		);
	}

	float4 ASerialized()
	{
		return Aj._11_12_21_22;
	}
	void DeserializeA(float4 patch)
	{
		Aj = float2x2(
			patch.x, patch.y, 
			patch.z, patch.w
		);
	}

	float3 A0Serialized()
	{
		return A0j;
	}
	float2x2 A0ToMatrix()
	{
		return float2x2(
			A0j.x, A0j.y, 
			A0j.y, A0j.z
		);
	}
	void DeserializeA0(float3 patch)
	{
		A0j = patch;
	}

	float4 mjxj_mjx0j_Serialized()
	{
		return float4(mjxj, mjx0j);
	}
	void Deserialize_mjxj_mjx0j(float4 patch)
	{
		mjxj = patch.xy;
		mjx0j = patch.zw;
	}

	void Add(ShapeMatching2D sm)
	{
		Aj += sm.Aj;
		A0j += sm.A0j;
		mjxj += sm.mjxj;
		mjx0j += sm.mjx0j;
	}
	void Sub(ShapeMatching2D sm)
	{
		Aj -= sm.Aj;
		A0j -= sm.A0j;
		mjxj -= sm.mjxj;
		mjx0j -= sm.mjx0j;
	}
};


/**
 * \brief Optimal rigid transformation
 * from shape matching
 */
struct ShapeMatchTransformOPT
{
	float2 t;
	float2x2 r;

	void Init(float2 t0 = 0, float2x2 r0 = float2x2(0, 0, 0, 0))
	{
		t = t0;
		r = r0;
	}

	
	void Add(ShapeMatchTransformOPT sm)
	{
		t += sm.t;
		r += sm.r;
	}

	void Sub(ShapeMatchTransformOPT sm)
	{
		t -= sm.t;
		r -= sm.r;
	}
};



// Matrix symmetric in theory may be
// not so symmetric due to errors in
// floating point computation
void mat_sym_ensure_sym_2x2(inout float2x2 A)
{
	A._12 = A._21;
}

// A.xyz:=._11,._12,._22
float2x2 sym_mat_inv_2x2(float3 A)
{ // (a, c)
//   (c, b)
#define a A.x
#define b A.z
#define c A.y
	float det = a * b - c * c;
	float2x2 inv = float2x2(
			b, -c,
			-c, a
		) / det;
	return inv;
#undef a
#undef b
#undef c
}

float2x2 mat_inv_2x2(float2x2 A)
{
	float det = determinant(A);
	float2x2 inv = float2x2(
			A._22, -A._12,
			-A._21, A._11
		) / det;
	return inv;
}

// Explicit 2d Polar Decomposition.
// M = RS, R:rotation matrix
// From https://www.cs.cornell.edu/courses/cs4620/2014fa/lectures/polarnotes.pdf
void mat_polar_decomp_2x2(float2x2 M, out float2x2 S, out float2x2 R)
{
	float theta = atan2((M._21 - M._12), (M._11 + M._22));
	float s = sin(theta);
	float c = cos(theta);

	R = float2x2(
		c, -s,
		s, c
	);
	S = mul(transpose(R), M);
	mat_sym_ensure_sym_2x2(S);
}

// From http://scipp.ucsc.edu/~haber/ph116A/diag2x2_11.pdf
// And  https://lucidar.me/en/mathematics/singular-value-decomposition-of-a-2x2-matrix/
// A = U*D*UT, A must be 2x2 symmetric
void sym_mat_diag_decomp_2x2(float2x2 A, out float2x2 U, out float2x2 D)
{
#define a A._11
#define c A._12
#define d A._22
	float theta = .5f * atan2(2 * c, a - d);
	float cos_theta = cos(theta);
	float sin_theta = sin(theta);
	U = float2x2(
		cos_theta, -sin_theta,
		sin_theta, cos_theta
	);

	float2 lambda = (a + d);
	float D_ = sqrt((a-d)*(a-d) + 4.0*c*c);
	
	lambda = .5 * (lambda + float2(D_, -D_));
	D = float2x2(
		lambda[0], 0, 
		0, lambda[1]
	);
#undef a
#undef c
#undef d
}





// mul(A, mul(B, C))
float2x2 mul_x3(float2x2 A, float2x2 B, float2x2 C)
{
	return mul(A, mul(B, C));
}


#endif /* FBDBCA2F_C4E3_475E_AD88_314A43900C2E */
