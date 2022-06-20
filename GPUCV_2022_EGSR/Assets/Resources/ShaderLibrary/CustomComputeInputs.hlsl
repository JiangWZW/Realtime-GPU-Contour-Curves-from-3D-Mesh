#ifndef CUSTOM_COMPUTE_INPUTS_DEFINED
#define CUSTOM_COMPUTE_INPUTS_DEFINED

#include "./ComputeAddressingDefs.hlsl"

///////////////////////////////////////////////////////////////////////////
// Resources
// | Convention: 
// | -- Data Type
// |----------+--------------+---------------+---------------------|
// | Prefix   | Data Type    | #Elem         | Meaning             |
// |----------+--------------+---------------+---------------------|
// | CBuffer  | Buffer       | /             | ComputeBuffer       |
// | CMatrix  | float4x4     | 4x4           | matrix              |
// | CVector  | float4       | 4             | color,vector        |
// | CPos/Dir | float3       | 3             | position,direction  |
// | CVal     | float/uint   | 1             | scalar              |
// | VP       | List<float4> | #Vertex       | vertex list         |
// | VN       | List<float4> | #Vertex       | vertex normal list  |
// | TV       | List<uint>   | 3 x #Triangle | Triangle index list |


// | -- Postfix
// |-----------+---------+-------------------------------|
// | Prefix    | Postfix | Meaning                       |
// |-----------+---------+-------------------------------|
// | CMatrix   | M       | Model -> World                |
// | ~         | V       | World -> View                 |
// | ~         | P       | View -> Homogenous Clip Space |
// | ~         | I_X(Y)  | Inverse Transform             |
// |-----------+---------+-------------------------------|
// | CPos/CDir | OS      | Object Space Pos/Dir          |
// | ~         | WS      | World Space Pos/Dir           |
// | ~         | VS      | View Space Pos/Dir            |
// | ~         | CS      | Homogenous Clip Space Pos/Dir |
// | ~         | TS      | Tangent Space                 |
// | ~         | TXS     | Texture Space                 |
// |           |         |                               |

float4x4    CMatrix_M;
float4x4    CMatrix_I_M;
float4x4    CMatrix_V;
float4x4    CMatrix_P;
float4x4    CMatrix_VP;
float4x4    CMatrix_I_VP;
float4x4    CMatrix_MVP;
float4x4	CMatrix_I_TMV; // Inverse-Transpose

StructuredBuffer<float4>      CBuffer_VPList;

StructuredBuffer<float4>      CBuffer_VNList;

ByteAddressBuffer             CBuffer_TVList;

StructuredBuffer<float4>      CBuffer_TNList;

ByteAddressBuffer             CBuffer_EVList;

ByteAddressBuffer             CBuffer_ETList;

int CVal_Vertex_Count;
int CVal_Triangle_Count;
int CVal_NonConcaveEdge_Count;
int CVal_NormalEdge_Count;



float4      CVector_CameraPos_WS;
float4      CVector_CameraPos_OS;
// .xyzw == (w, h, 1 / w, 1 / h)
float4      CVector_ScreenTexelSize_SS;

Texture2D   _CameraDepthTexture;

#endif
