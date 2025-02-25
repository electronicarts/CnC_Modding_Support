//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for rendering the terrain tracks left by vehicle
//////////////////////////////////////////////////////////////////////////////


#include "Common.fxh"
#include "Gamma.fxh"

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------

#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float4x4 GetViewProjection()
{
	return ViewProjection;
}
#else
float4x4 View : View;
float4x4 Projection : Projection;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}
#endif

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
	
	Out.Position = mul(float4(Position, 1), GetViewProjection());

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
	float4 baseTextureColor = tex2D(SAMPLER(Texture_0), In.BaseTexCoord);
	baseTextureColor.xyz = GammaToLinear(baseTextureColor.xyz);
	color *= baseTextureColor;

	return color;
}

// ---------------------------------------------------------------------------

technique Default
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS();

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

// ---------------------------------------------------------------------------

float4 PS_M(VSOutput In) : COLOR
{
	// Get vertex color
	float4 color = In.DiffuseColor;

	// Apply texture
	float4 baseTextureColor = tex2D(SAMPLER(Texture_0), In.BaseTexCoord);
	color *= baseTextureColor;

	return color;
}

// ---------------------------------------------------------------------------

technique Default_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS_M();

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

