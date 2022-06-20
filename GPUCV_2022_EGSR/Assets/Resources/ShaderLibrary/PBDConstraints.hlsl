#include "./CustomShaderInputs.hlsl"
#include "./JFAInputs.hlsl"
#include "./GeometryProcessing_2D_ShapeMatching.hlsl"

#include "./ComputeBufferConfigs/CBuffer_BufferRawProceduralGeometry_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawPixelEdgeData_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawStampLinkage_View.hlsl"
#include "./ComputeBufferConfigs/CBuffer_BufferRawEdgeLoopData_View.hlsl"


// Arg Buffers
#include "./ComputeBufferConfigs/ArgsBuffers/CBuffer_CachedArgs_View.hlsl"
#include "./ComputeBufferConfigs/ArgsBuffers/CBuffer_DispatchIndirectArgs_View.hlsl"


// PBD Parameters
// --------------------------------
float _PBD_Alpha;
#define alpha_hat _PBD_Alpha
float _PBD_Gamma;
#define gamma _PBD_Gamma

float _PBD_SM_Creep;
float _PBD_SM_Yield;

struct StretchingConstraint
{
	float restLen;

	void SetInvalid() { restLen = -1.0; }
	bool Invalid() { return restLen < 0; }
	float4 Solve(float2 xi, float2 xi_prev, float2 xj, float2 xj_prev);
	float4 Solve(
		float wi, float2 xi, float2 xi_prev, 
		float wj, float2 xj, float2 xj_prev, 
		float pbd_gamma, float pbd_alpha_hat
	);
};
/**
 * \brief 
 * \return dx_i, dx_j
 */
float4 StretchingConstraint::Solve(
    float wi, float2 xi, float2 xi_prev, 
	float wj, float2 xj, float2 xj_prev, 
	float pbd_gamma, float pbd_alpha_hat)
{
	float2 xij = xj - xi;
    float springLen = length(xij);
    float C = springLen - restLen;
    float2 DC_i = -normalize(xij);
    float2 DC_j = -DC_i;

	float velProjDC_i = dot(DC_i, xi - xi_prev);
	float velProjDC_j = dot(DC_j, xj - xj_prev);
	float damp  = (velProjDC_i + velProjDC_j);

	float div = (wi + wj) * (1.0f + pbd_gamma) + pbd_alpha_hat;
	float lambda = (- C - pbd_gamma * damp) / div;
	
    float2 dx_i = wi * lambda * DC_i;
    float2 dx_j = wj * lambda * DC_j;

    return Invalid() ? 0 : float4(dx_i, dx_j);
}
/**
 * \brief 
 * \return dx_i, dx_j
 */
float4 StretchingConstraint::Solve(
    float2 xi, float2 xi_prev, float2 xj, float2 xj_prev)
{
    return Solve(1.0, xi, xi_prev, 1.0, xj, xj_prev, 
		/*gamma*/0, /*alpha_hat*/0);
}


