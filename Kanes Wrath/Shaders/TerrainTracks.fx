//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for rendering the terrain tracks left by vehicle
//////////////////////////////////////////////////////////////////////////////


#include "Common.fxh"

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------

float4x4 View : View;
float4x4 Projection : Projection;

// ----------------------------------------------------------------------------
// Textures declaration
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN(Texture_0,
	string UIWidget = "None";
	string SasBindAddress = "WW3D.MiscTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

// ---------------------------------------------------------------------------

struct VSOutput
{
	float4 Position : POSITION;
	float4 DiffuseColor : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
};

// ---------------------------------------------------------------------------

VSOutput VS(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 color : COLOR0 )
{
	VSOutput Out;
	
	Out.Position = mul(float4(Position, 1), mul(View, Projection));

	Out.DiffuseColor = color;
	
	Out.BaseTexCoord = TexCoord0;
	
	return Out;
}

// ---------------------------------------------------------------------------

float4 PS(VSOutput In) : COLOR
{
	// Get vertex color
	float4 color = In.DiffuseColor;

	// Apply texture
	color *= tex2D(SAMPLER(Texture_0), In.BaseTexCoord);

	return color;
}

// ---------------------------------------------------------------------------

technique Default
{
	pass P0
	{
		VertexShader = compile vs_1_1 VS();
		PixelShader = compile ps_1_1 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = CW;

		ColorWriteEnable = RGB;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}  
}

