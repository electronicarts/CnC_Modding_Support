//////////////////////////////////////////////////////////////////////////////
// ©2007 Electronic Arts Inc
//
// FX Shader for missing materials
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;
	
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
};

// ----------------------------------------------------------------------------
VSOutput VS(float3 Position : POSITION)
{
	VSOutput Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{
	return float4(1, 0, 1, 1);
}

// ----------------------------------------------------------------------------
technique Default
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS();

		ZEnable = false;
		ZWriteEnable = true;
		CullMode = None;

		AlphaBlendEnable = false;

		ColorWriteEnable = RGBA;

		AlphaTestEnable = false;
	}  
}
