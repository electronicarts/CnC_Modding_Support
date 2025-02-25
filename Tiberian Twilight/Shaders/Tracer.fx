//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for simple unlit rendering
//////////////////////////////////////////////////////////////////////////////
#define SUPPORT_FOG 1

#include "Common.fxh"
#include "Gamma.fxh"

SAMPLER_2D_BEGIN( Texture_0,
	string UIWidget = "None";
	string UIName = "None";
	string SasBindAddress = "WW3D.MiscTexture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

float4 TexCoordTransform_0
<
	string UIName = "UV0 Scl/Move";
    string UIWidget = "Spinner";
	float UIMin = -100;
	float UIMax = 100;
> = float4(1.0, 1.0, 0.0, 0.0);

bool FogEnable
<
	string UIName = "Fog Enable";
> = true;

// Variationgs for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque = 1;
static const int FogMode_Additive = 2;

// ----------------------------------------------------------------------------
// Shroud
// ----------------------------------------------------------------------------

ShroudSetup Shroud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud";
> = DEFAULT_SHROUD;


SAMPLER_2D_BEGIN( ShroudTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud.Texture";
	string ResourceName = "ShaderPreviewShroud.dds";
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
#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;

float3 EyePosition
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.Position";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float4x4 GetViewProjection()
{
	return ViewProjection;
}

float3 GetEyePosition()
{
    return EyePosition;
}
#else // #if defined(_WW3D_)
float4x4 Projection     : Projection;
float4x4 View           : View;
float4x3 ViewI          : ViewInverse;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif // #if defined(_WW3D_)

float Time : Time;

// ----------------------------------------------------------------------------
// SHADER: DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float4 DiffuseColor : COLOR0;
	float Fog : COLOR1;
	float4 BaseTexCoord_ShroudTexCoord : TEXCOORD0;
};

VSOutput VS(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 Color : COLOR)
{
	VSOutput Out;

    // Position is already in world space
	Out.Position = mul( float4( Position, 1 ), GetViewProjection() );

	// Unlit colorization	
	Out.DiffuseColor = Color;
	
	// Scale with animated offset on texture coordinates 0
	Out.BaseTexCoord_ShroudTexCoord.xy = TexCoord0 * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
	
	// Calculate fog
	Out.Fog = FogEnable ? CalculateFog(Fog, Position, GetEyePosition()) : 1;

	// Calculate Shroud UVs
	Out.BaseTexCoord_ShroudTexCoord.zw = CalculateShroudTexCoord( Shroud, Position );
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform int fogMode, uniform bool applyGammaCorrection) COLORTARGET
{
	// Get vertex color
	float4 color = In.DiffuseColor*20;

	// Apply texture
	float4 textureSample = tex2D( SAMPLER(Texture_0), In.BaseTexCoord_ShroudTexCoord.xy);
	if (applyGammaCorrection)
	{
		textureSample.xyz = GammaToLinear(textureSample.xyz);
	}
	color *= textureSample;

	// Apply fog
	if (fogMode == FogMode_Opaque)
	{
		color.xyz = lerp(Fog.Color.xyz, color.xyz, In.Fog);
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		color.xyz *= In.Fog;
	}

    // Apply shroud
	float shroud = tex2D( SAMPLER(ShroudTexture), In.BaseTexCoord_ShroudTexCoord.zw ).x;
	shroud = BiasShroudValueForEffects( shroud );
	color.xyz *= shroud;
	
	return color;
}

// ----------------------------------------------------------------------------
float4 PS_XenonAlpha(VSOutput In) : COLOR
{
	return PS(In, Fog.IsEnabled ? FogMode_Opaque : FogMode_Disabled, true);
}

// ----------------------------------------------------------------------------
float4 PS_XenonAdditive(VSOutput In) : COLOR
{
	return PS(In, Fog.IsEnabled ? FogMode_Additive : FogMode_Disabled, true);
}

// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_FogMode = 1 );

#define PS_FogMode \
	compile PS_2_0 PS(FogMode_Disabled, true), \
	compile PS_2_0 PS(FogMode_Opaque, true), \
	compile PS_2_0 PS(FogMode_Additive, true)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final = PS_Multiplier_FogMode * 3 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_FogMode
};
#endif


technique Additive
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			(Fog.IsEnabled ? FogMode_Additive : FogMode_Disabled) * PS_Multiplier_FogMode,
			compile PS_VERSION PS_XenonAdditive()
		);
		
        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        CullMode = None;
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;

		SrcBlend = One;
		DestBlend = One;
	}  
}

technique Alpha
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			(Fog.IsEnabled ? FogMode_Opaque : FogMode_Disabled) * PS_Multiplier_FogMode,
			compile PS_VERSION PS_XenonAlpha()
		);
		
        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        CullMode = None;
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;

		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}  
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// Techniques: Medium LOD
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_FogMode = 1 );

#define PS_M_FogMode \
	compile PS_2_0 PS(FogMode_Disabled, false), \
	compile PS_2_0 PS(FogMode_Opaque, false), \
	compile PS_2_0 PS(FogMode_Additive, false)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_Final = PS_M_Multiplier_FogMode * 3 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_M_Array[PS_M_Multiplier_Final] =
{
	PS_M_FogMode
};
#endif


technique _Additive_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		
		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Array,
			(Fog.IsEnabled ? FogMode_Additive : FogMode_Disabled) * PS_M_Multiplier_FogMode,
			compile PS_VERSION PS_XenonAdditive()
		);
		
        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        CullMode = None;
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;

		SrcBlend = One;
		DestBlend = One;
	}  
}

technique _Alpha_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		
		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Array,
			(Fog.IsEnabled ? FogMode_Opaque : FogMode_Disabled) * PS_M_Multiplier_FogMode,
			compile PS_VERSION PS_XenonAlpha()
		);
		
        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        CullMode = None;
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;

		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}  
}

// ----------------------------------------------------------------------------
// Techniques: Low LOD
// ----------------------------------------------------------------------------

technique _Additive_L
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(FogMode_Disabled, false);
		
        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        CullMode = None;
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;

		SrcBlend = One;
		DestBlend = One;
	}  
}

technique _Alpha_L
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS(FogMode_Disabled, false);
		
        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        CullMode = None;
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;

		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}  
}

#endif // if ENABLE_LOD
