//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for rendering the shoreline
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"
#include "Gamma.fxh"

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
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN(Texture1,
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FXDistortionFractal";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
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
	float2 BaseTexCoord : TEXCOORD0;
	float4 DiffuseColor : TEXCOORD1;
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

float4 PS(VSOutput In, uniform bool applyGammaCorrection) : COLOR
{
	// Get vertex color
	float4 color = In.DiffuseColor;

	// Apply texture
	float4 baseTexture =  tex2D(SAMPLER(Texture0), In.BaseTexCoord);
	if (applyGammaCorrection)
	{
		baseTexture.xyz = GammaToLinear(baseTexture);
	}

	color *= baseTexture;

	return color;
}

//-------------------------------------------------------------------------------------------
//-- Lightning Draw -------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------

struct VSLightningOutput
{
	float4 Position : POSITION;
	float2 BaseTexCoord : TEXCOORD0;
	float4 DistortionTexCoord : TEXCOORD1;
	float4 DiffuseColor : TEXCOORD2;
};

VSLightningOutput VSLightning(float3 Position : POSITION,
				float2 TexCoord0 : TEXCOORD0, 
				float4 VertexColor : COLOR0)
{
	VSLightningOutput Out;
	
	float DispScale = .1; //Displacement Coord Scale
	float DisplaceDivergenceAngle = 45 * .017453; //Rotation difference in degrees, convert to radians
	float DisplaceSpeed = 6; //Speed of scolling displacement texture
	
	// Build Displace Texture Rotation Matrix -----
	float cosAngle, sinAngle;
	cosAngle = 0;
	sinAngle = 0;
	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
	
	sincos (DisplaceDivergenceAngle, sinAngle, cosAngle);
					 
	uvCoordRotate[0][0] = cosAngle;
	uvCoordRotate[0][1] = -sinAngle;
	uvCoordRotate[1][1] = uvCoordRotate[0][0];
	uvCoordRotate[1][0] = -uvCoordRotate[0][1];

	// Texture coordinates for lighting have the y channel be a "world space distance" from the origin of the lighting,
	// so at the beginning y is 0, at the end it is eg 120 for one of our largest lightning weapons.
	// This can be used to use only a partial lightning texture for short lightning bolts.
	// For now we assume our lightning texture has been scaled to look "good" for the longest bolt of 120 length.
	static const float maxLightningLength = 160;
	TexCoord0.y /= maxLightningLength;

	float2 DisplaceTexCoords = TexCoord0 * DispScale;
	DisplaceTexCoords.y *= 3;

	// Rotate and Animate Displace Divergence Texture Coords --------------------
	float2 DisplaceTexCoordsDiverge = mul(DisplaceTexCoords, uvCoordRotate);
	DisplaceTexCoordsDiverge.x += float(DisplaceSpeed * Time * .005);
	float2 DisplaceTexCoordsDivergeInv = mul(DisplaceTexCoords * .5, transpose(uvCoordRotate));	
	DisplaceTexCoordsDivergeInv.x += float(DisplaceSpeed * Time * .01);		
	
	// Note: The incoming geometry is already transformed to view space, so only apply Projection, not WorldViewProjection
	Out.Position = mul(float4(Position, 1), Projection);

	Out.DiffuseColor = VertexColor;

	Out.BaseTexCoord = TexCoord0;
	Out.DistortionTexCoord = float4(DisplaceTexCoordsDiverge, DisplaceTexCoordsDivergeInv);
	
	return Out;
}

float4 PSLightning(VSLightningOutput In, uniform bool applyGammaCorrection) : COLOR
{
	// Get vertex color
	float4 color = In.DiffuseColor;

	//Setup for Lightning
	float DispAmp = .01; //Displacement amplitude

	// Get distortion coords, normalize and apply
	float2 textureDisplace = tex2D(SAMPLER(Texture1), In.DistortionTexCoord.xy);
	textureDisplace += tex2D(SAMPLER(Texture1), In.DistortionTexCoord.zw);
	textureDisplace = textureDisplace - 1;
	
	float2 displacedTextureCoords = In.BaseTexCoord.xy + (textureDisplace.xy * DispAmp);
	
	float4 baseTexture = tex2D(SAMPLER(Texture0), displacedTextureCoords);
	if (applyGammaCorrection)
	{
		baseTexture.xyz = GammaToLinear(baseTexture);
		color *= 2; // This multiply without HDR looks bad. MJ
	}

	color *= baseTexture;

	return color;
}

//
// High - UltraHigh techniques
//
technique Alpha
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(true);

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
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(true);

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


// Hi-jacked for Lightning Renderer
technique AdditiveAlphaTest
{
	pass P0
	{
		VertexShader = compile VS_2_0 VSLightning();
		PixelShader = compile PS_2_0 PSLightning(true);

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

technique AlphaTest
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(true);
		
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
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(true);

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
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(true);

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
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(true);

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}  
}

//
// Medium techniques
//

technique Alpha_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(false);

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

technique Additive_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(false);

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


// Hi-jacked for Lightning Renderer
technique AdditiveAlphaTest_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VSLightning();
		PixelShader = compile PS_2_0 PSLightning(false);

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

technique AlphaTest_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(false);

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

technique Multiplicative_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(false);

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

technique AdditiveNoDepthTest_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(false);

		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;

		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;

		AlphaTestEnable = false;
	}  
}

technique AlphaNoDepthTest_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(false);

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
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In, uniform int blendMode) COLORTARGET
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
	compile PS_2_0 CreateShadowMapPS(BLEND_MODE_ALPHA), \
	compile PS_2_0 CreateShadowMapPS(BLEND_MODE_ADDITIVE), \
	compile PS_2_0 CreateShadowMapPS(BLEND_MODE_ADDITIVE_ALPHA_TEST), \
	compile PS_2_0 CreateShadowMapPS(BLEND_MODE_ALPHA_TEST), \
	compile PS_2_0 CreateShadowMapPS(BLEND_MODE_MULTIPLICATIVE), \
	compile PS_2_0 CreateShadowMapPS(BLEND_MODE_ADDITIVE_NO_DEPTH_TEST), \
	compile PS_2_0 CreateShadowMapPS(BLEND_MODE_ALPHA_NO_DEPTH_TEST)

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
		VertexShader = compile VS_2_0 CreateShadowMapVS();
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
