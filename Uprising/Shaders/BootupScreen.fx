//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for Bootupscreen
//////////////////////////////////////////////////////////////////////////////


#include "Common.fxh"

// ----------------------------------------------------------------------------
// Textures declaration
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN(BaseTexture,
    string UIWidget = "None";
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
	float2 TexCoord0 : TEXCOORD0;
	float4 Color : COLOR0;
};

// ---------------------------------------------------------------------------

VSOutput VS(float3 Pos : POSITION, float2 Tex : TEXCOORD0, float4 color : COLOR0 )
{
	VSOutput Out;
	
    Out.Position.x  = Pos.x/1.0 - 0.0;
    Out.Position.y  = Pos.y/1.0 - 0.0;
    Out.Position.z  = 0.0;               
    Out.Position.w  = 1.0;               
    Out.TexCoord0.x = Tex.x;          
    Out.TexCoord0.y = Tex.y;          
    Out.Color = color;				
	return Out;
}

// ---------------------------------------------------------------------------

float4 PS(VSOutput In) : COLOR
{
	return tex2D(SAMPLER(BaseTexture),In.TexCoord0)*In.Color;
}

technique Blit
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		AlphaBlendEnable = true;
		AlphaTestEnable = false;
	}
}

