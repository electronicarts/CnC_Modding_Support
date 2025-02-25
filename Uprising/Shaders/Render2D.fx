//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for Render2D
//////////////////////////////////////////////////////////////////////////////


#include "Common.fxh"

// ----------------------------------------------------------------------------
// Textures declaration
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN(BaseTexture,
	string SasBindAddress = "WW3D.MiscTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 World : World;

// ---------------------------------------------------------------------------

struct VSOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
};

// ---------------------------------------------------------------------------

VSOutput VS(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 color : COLOR0 )
{
	VSOutput Out;
	
	Out.Position = mul(float4(Position, 1), World);
	Out.Color = color;
	Out.BaseTexCoord = TexCoord0;
	
	return Out;
}

// ---------------------------------------------------------------------------

float4 PS(VSOutput In) : COLOR
{
	// Get vertex color
	float4 color = In.Color;

	// Apply texture
	color *= tex2D(SAMPLER(BaseTexture), In.BaseTexCoord);

	return color;
}

// ---------------------------------------------------------------------------

float4 PSGray(VSOutput In) : COLOR
{
	// Get vertex color
	float4 color = In.Color;

	// Get texture
	float4 textureSample = tex2D(SAMPLER(BaseTexture), In.BaseTexCoord);
	
	// Convert texture to gray scale
	float3 grayMix = float3(0.30, 0.59, 0.11);
	color.xyz *= dot(textureSample.xyz, grayMix);

	// Multiply alpha
	color.w *= textureSample.w;

	return color;
}

// ---------------------------------------------------------------------------

float4 PSIgnoreTextureAlpha(VSOutput In) : COLOR
{
	// Get vertex color
	float4 color = In.Color;

	// Apply texture
	color.xyz *= tex2D(SAMPLER(BaseTexture), In.BaseTexCoord);

	return color;
}

// ---------------------------------------------------------------------------

technique Copy
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

technique Additive
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;

		AlphaTestEnable = false;
	}
}

technique AlphaBlend
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}

technique Gray
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PSGray();
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}

technique GrayCopy
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PSGray();
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

technique AlphaTestCopy
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = false;
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}
}

technique AlphaWithSolidTexture
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PSIgnoreTextureAlpha();
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = false;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}

technique AptRendererIgnoreMask
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;

		ColorWriteEnable = RGBA;

		StencilEnable = false;
	}
}

technique AptRendererReadMask
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;

		ColorWriteEnable = RGBA;

		StencilEnable = true;
		//StencilRef = 0; // To be overridden by code
		StencilMask = 0xffffffff;
		StencilWriteMask = 0xffffffff;

		StencilFunc = Equal;
		StencilPass = Keep;
		StencilZFail = Keep;
		StencilFail = Keep;
	}
}

technique AptRendererWriteMask
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;

		ColorWriteEnable = 0;

		StencilEnable = true;
		//StencilRef = 0; // To be overridden by code
		StencilMask = 0xffffffff;
		StencilWriteMask = 0xffffffff;

		StencilFunc = Always;
		StencilPass = Replace;
		StencilZFail = Keep;
		StencilFail = Keep;
	}
}