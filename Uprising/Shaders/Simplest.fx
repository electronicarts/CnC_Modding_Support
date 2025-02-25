//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for shadow map debugging
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

#if defined(EA_PLATFORM_WINDOWS) && defined(_3DSMAX_)
// ----------------------------------------------------------------------------
// SAMPLER : nhendricks : had to pull these in here for MAX to compile
// ----------------------------------------------------------------------------
#define SAMPLER_2D_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	sampler2D samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_2D_END	};

#define SAMPLER( samplerName )	samplerName##Sampler

#define SAMPLER_CUBE_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	samplerCUBE samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_CUBE_END };
#endif


float4 FlatColorOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FlatColor";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
>;

SAMPLER_2D_BEGIN( BaseTexture,
	string UIName = "Base Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 WorldViewProjection : WorldViewProjection;
	
// ----------------------------------------------------------------------------
struct VSOutput_FlatColor
{
	float4 Position : POSITION;
};

// ----------------------------------------------------------------------------
VSOutput_FlatColor VS_FlatColor(float3 Position : POSITION)
{
	VSOutput_FlatColor Out;
	
	Out.Position = mul(float4(Position, 1), WorldViewProjection); //float4(Position, 1);// 
	//Out.Position = mul(mul(mul(float4(Position, 1), World), View), Projection);
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_FlatColor(VSOutput_FlatColor In) : COLOR
{
	return float4(1, 0, 0, 1);
}

// ----------------------------------------------------------------------------
float4 PS_FlatColorOverride(VSOutput_FlatColor In) : COLOR
{
	return FlatColorOverride;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
struct VSOutput_Texture1
{
	float4 Position : POSITION;
	float2 BaseTexCoord : TEXCOORD0;
};

// ----------------------------------------------------------------------------
VSOutput_Texture1 VS_Texture1(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0)
{
	VSOutput_Texture1 Out;
	Out.Position = mul(float4(Position, 1), WorldViewProjection);
	Out.BaseTexCoord = TexCoord0;
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_Texture1(VSOutput_Texture1 In) : COLOR
{
	float4 color = tex2D(SAMPLER(BaseTexture), In.BaseTexCoord);
	return color;
}

// ----------------------------------------------------------------------------
technique Simplest
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColor();
		PixelShader = compile PS_2_0 PS_FlatColor();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;

		ColorWriteEnable = RGBA;

		AlphaTestEnable = false;
	}  
}

/*technique DynamicParameter
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_FlatColor();
		PixelShader = compile PS_2_0 PS_FlatColorOverride();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;

		ColorWriteEnable = RGBA;

		AlphaTestEnable = false;
	}  
}*/

technique DynamicParameter
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Simplest")
	>
	{
		VertexShader = compile VS_2_0 VS_FlatColor();
		PixelShader = compile PS_2_0 PS_FlatColor();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

#if !EXPRESSION_EVALUATOR_ENABLED		
		AlphaBlendEnable = ( FlatColorOverride.z > 0.5 );
#endif
		SrcBlend = One;
		DestBlend = One;

		ColorWriteEnable = RGBA;

		AlphaTestEnable = false;
	}  
}

technique Textured
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Texture1();
		PixelShader = compile PS_2_0 PS_Texture1();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = false;

		ColorWriteEnable = RGBA;

		AlphaTestEnable = false;
	}  
}