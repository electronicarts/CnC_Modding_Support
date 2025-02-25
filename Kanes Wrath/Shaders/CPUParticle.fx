//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for particles
//////////////////////////////////////////////////////////////////////////////


#include "Common.fxh"


SAMPLER_2D_BEGIN(ParticleTexture,
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// Transformations
float4x4 Projection : Projection;

struct VSOutput
{
	float4 Position : POSITION;
	float4 DiffuseColor : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
};

VSOutput VS(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 VertexColor : COLOR0)
{
	VSOutput Out;
	
	// Note: The incoming geometry is already transformed to view space, so only apply Projection, not WorldViewProjection
	Out.Position = mul(float4(Position, 1), Projection);

	// Unlit colorization	
	Out.DiffuseColor = VertexColor;
	
	Out.BaseTexCoord = TexCoord0;
	
	return Out;
}

float4 PS(VSOutput In) : COLOR
{
	float4 color = In.DiffuseColor;
   
   	// Apply texture
 	color *= tex2D(SAMPLER(ParticleTexture), In.BaseTexCoord);

	return color;
}



technique AdditiveSpriteShader
{
	pass P0
	{
		VertexShader = compile vs_1_1 VS();
		PixelShader = compile ps_1_1 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}	
}



technique AdditiveAlphaTestSpriteShader
{
	pass P0
	{
		VertexShader = compile vs_1_1 VS();
		PixelShader = compile ps_1_1 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}



technique AlphaSpriteShader
{
	pass P0
	{
		VertexShader = compile vs_1_1 VS();
		PixelShader = compile ps_1_1 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}  
}



technique ATestSpriteShader
{
	pass P0
	{
		VertexShader = compile vs_1_1 VS();
		PixelShader = compile ps_1_1 PS();
		
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = false;
		
		AlphaTestEnable = true;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
	}  
}



technique MultiplicativeSpriteShader
{
	pass P0
	{
		VertexShader = compile vs_1_1 VS();
		PixelShader = compile ps_1_1 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
		
		AlphaTestEnable = false;
	}  
}



technique Additive2DShader
{
	pass P0
	{
		VertexShader = compile vs_1_1 VS();
		PixelShader = compile ps_1_1 PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}  
}



technique Alpha2DShader
{
	pass P0
	{
		VertexShader = compile vs_1_1 VS();
		PixelShader = compile ps_1_1 PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}  
}
