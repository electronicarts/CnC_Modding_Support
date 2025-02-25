//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for simple unlit rendering
//////////////////////////////////////////////////////////////////////////////
#include "Common.fxh"

// ----------------------------------------------------------------------------
// Material parameters
// ----------------------------------------------------------------------------
float3 ColorEmissive
<
	string UIName = "Emissive Material Color";
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);


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

bool AlphaAdditiveEnable
<
	string UIName = "Alpha Additive Enable";
> = false;

bool FogEnable
<
	string UIName = "Fog Enable";
> = true;

WW3DFog Fog
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;

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
float4x4 View : View;
float4x4 Projection : Projection;
float4x3 ViewI : ViewInverse;
float Time : Time;

// ----------------------------------------------------------------------------
// SHADER: DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float4 DiffuseColor : COLOR0;
	float Fog : COLOR1;
	float2 BaseTexCoord : TEXCOORD0;
	float2 ShroudTexCoord : TEXCOORD1;
};

VSOutput VS(float3 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 Color : COLOR)
{
	VSOutput Out;

    // Position is already in world space
	float4x4 ViewProjection = mul( View, Projection );
	Out.Position = mul( float4( Position, 1 ), ViewProjection );

	// Unlit colorization	
	Out.DiffuseColor = Color;
	
	// Scale with animated offset on texture coordinates 0
	Out.BaseTexCoord = TexCoord0 * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
	
	// Calculate fog
	Fog.IsEnabled = Fog.IsEnabled && FogEnable;
	Out.Fog = CalculateFog(Fog, Position, ViewI[3]);
	
	// Calculate Shroud UVs
	Out.ShroudTexCoord = CalculateShroudTexCoord( Shroud, Position );
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform int fogMode) : COLOR
{
	// Get vertex color
	float4 color = In.DiffuseColor;

	// Apply texture
	color *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord);

	// Apply fog
	if (fogMode == FogMode_Opaque)
	{
		color.xyz = lerp(Fog.Color, color.xyz, In.Fog);
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		color.xyz *= In.Fog;
	}

    // Apply shroud
	float shroud = tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord ).x;
	shroud = BiasShroudValueForEffects( shroud );
	color.xyz *= shroud;
	
	return color;
}

// ----------------------------------------------------------------------------
float4 PS_Xenon(VSOutput In) : COLOR
{
	return PS(In, (Fog.IsEnabled ? (AlphaAdditiveEnable ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled));
}

// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_FogMode = 1 );

#define PS_FogMode \
	compile PS_VERSION_LOW PS(FogMode_Disabled), \
	compile PS_VERSION_LOW PS(FogMode_Opaque), \
	compile PS_VERSION_LOW PS(FogMode_Additive)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final = PS_Multiplier_FogMode * 3 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_FogMode
};
#endif


technique Default
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Tracer")
	>
	{
		VertexShader = compile VS_VERSION_LOW VS();
		
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
			(Fog.IsEnabled ? (AlphaAdditiveEnable ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) * PS_Multiplier_FogMode,
			compile PS_VERSION PS_Xenon()
		);
		
        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        CullMode = None;
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;

#if !EXPRESSION_EVALUATOR_ENABLED
		SrcBlend = ( AlphaAdditiveEnable ? D3DBLEND_ONE : D3DBLEND_SRCALPHA );
		DestBlend = ( AlphaAdditiveEnable ? D3DBLEND_ONE : D3DBLEND_INVSRCALPHA );
#endif

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false; // Fog handled in pixel shader
#endif
	}  
}