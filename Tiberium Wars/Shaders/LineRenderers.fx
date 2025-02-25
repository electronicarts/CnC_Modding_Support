//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for rendering the shoreline
//////////////////////////////////////////////////////////////////////////////


#include "Common.fxh"

// Transformations
float4x4 Projection : Projection;

float Time : Time;


SAMPLER_2D_BEGIN(Texture0,
	string UIWidget = "None";
	string SasBindAddress = "WW3D.MiscTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END


static const int BLEND_MODE_ALPHA = 0;
static const int BLEND_MODE_ADDITIVE = 1;
static const int BLEND_MODE_ADDITIVE_ALPHA_TEST = 2;
static const int BLEND_MODE_ALPHA_TEST = 3;
static const int BLEND_MODE_MULTIPLICATIVE = 4;
static const int BLEND_MODE_ADDITIVE_NO_DEPTH_TEST = 5;
static const int BLEND_MODE_ALPHA_NO_DEPTH_TEST = 6;
static const int NUM_BLEND_MODES = 7;

int BlendMode
<
	string UIName = "Blend mode";
	int UIMin = 0;
	int UIMax = NUM_BLEND_MODES - 1;
> = BLEND_MODE_ALPHA;

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

	Out.DiffuseColor = VertexColor;
	
	Out.BaseTexCoord = TexCoord0;
	
	return Out;
}

float4 PS(VSOutput In) : COLOR
{
	// Get vertex color
	float4 color = In.DiffuseColor;

	// Apply texture
	color *= tex2D(SAMPLER(Texture0), In.BaseTexCoord);

	return color;
}

technique Alpha
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

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

technique Additive
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

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

technique AdditiveAlphaTest
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

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

technique AlphaTest
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();
		
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

technique Multiplicative
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

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

technique AdditiveNoDepthTest
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		
		AlphaTestEnable = false;
	}  
}

technique AlphaNoDepthTest
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader = compile PS_VERSION_LOW PS();

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}  
}



// ----------------------------------------------------------------------------
// SHADER: CreateShadowMapStreakVS
// ----------------------------------------------------------------------------
struct VSOutput_CreateShadowMap
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
	float Depth : TEXCOORD1;
};


// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS(float3 Position : POSITION,
		float3 Normal : NORMAL, float2 TexCoord0 : TEXCOORD0, float4 VertexColor: COLOR0)
{
	VSOutput_CreateShadowMap Out;
	
	// Note: The incoming geometry is already transformed to view space, so only apply Projection, not WorldViewProjection
	Out.Position = mul(float4(Position, 1), Projection);

	Out.Color = VertexColor;
	Out.BaseTexCoord = TexCoord0;
	Out.Depth = Out.Position.z / Out.Position.w;
	return Out;
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In, uniform int blendMode) : COLOR
{
	float4 color = In.Color;

	color *= tex2D(SAMPLER(Texture0), In.BaseTexCoord);
	
	float clipValue; 
	if (blendMode == BLEND_MODE_ALPHA || blendMode == BLEND_MODE_ALPHA_TEST || blendMode == BLEND_MODE_ADDITIVE_ALPHA_TEST || blendMode == BLEND_MODE_ALPHA_NO_DEPTH_TEST)
	{
		// Simulate alpha testing for floating point render target
		clipValue = color.w - ((float)90 / 255);
	}
	else // if (blendMode == BLEND_MODE_ADDITIVE || blendMode == BLEND_MODE_ADDITIVE_NO_DEPTH_TEST || blendMode == BLEND_MODE_MULTIPLICATIVE)
	{
		// Simulate additive "alpha testing" for floating point render target
		clipValue = dot(color.xyz, float3(1, 1, 1)) - 3 * ((float)200 / 255);
	}
	
	clip(clipValue);

	return In.Depth;
}

float4 CreateShadowMapPS_Xenon(VSOutput_CreateShadowMap In) : COLOR
{
	return CreateShadowMapPS(In, BlendMode);
}

// ----------------------------------------------------------------------------
// TECHNIQUE: _CreateShadowMap
// ----------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PSCreateShadowMap_Multiplier_BlendMode = 1);

#define PSCreateShadowMap_BlendMode \
	compile PS_VERSION_HIGH CreateShadowMapPS(BLEND_MODE_ALPHA), \
	compile PS_VERSION_HIGH CreateShadowMapPS(BLEND_MODE_ADDITIVE), \
	compile PS_VERSION_HIGH CreateShadowMapPS(BLEND_MODE_ADDITIVE_ALPHA_TEST), \
	compile PS_VERSION_HIGH CreateShadowMapPS(BLEND_MODE_ALPHA_TEST), \
	compile PS_VERSION_HIGH CreateShadowMapPS(BLEND_MODE_MULTIPLICATIVE), \
	compile PS_VERSION_HIGH CreateShadowMapPS(BLEND_MODE_ADDITIVE_NO_DEPTH_TEST), \
	compile PS_VERSION_HIGH CreateShadowMapPS(BLEND_MODE_ALPHA_NO_DEPTH_TEST)

DEFINE_ARRAY_MULTIPLIER(PSCreateShadowMap_Multiplier_Final = 7 * PSCreateShadowMap_Multiplier_BlendMode);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSCreateShadowMap_Array[PSCreateShadowMap_Multiplier_Final] =
{
	PSCreateShadowMap_BlendMode
};
#endif

technique _CreateShadowMap
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW CreateShadowMapVS();
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PSCreateShadowMap_Array,
			BlendMode * PSCreateShadowMap_Multiplier_BlendMode,
			// Non-array alternative:
			compile PS_VERSION CreateShadowMapPS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = None;
		AlphaBlendEnable = false;
		AlphaTestEnable = false; // Handled in pixel shader
	}
}
