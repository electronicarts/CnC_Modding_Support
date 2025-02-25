//-----------------------------------------------------------------------------
// ©2008 Electronic Arts Inc
// Never do this, this is a hard coded shader for the Desolator Toxic Streams.
//-----------------------------------------------------------------------------

#include "Common.fxh"
#include "Gamma.fxh"

// ----------------------------------------------------------------------------
// Texture1
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( Texture1,
    string UIWidget = "None";
	)
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU  = Wrap;
    AddressV  = Wrap;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Texture2
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( Texture2,
    string UIWidget = "None";
	)
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU  = Wrap;
    AddressV  = Wrap;
SAMPLER_2D_END

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
float4x3 World		: World;

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
float4x4 View           : View;
float4x3 ViewI          : ViewInverse;
float4x4 Projection     : Projection;

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

//-----------------------------------------------------------------------------
// Vertex Shader structure
//-----------------------------------------------------------------------------

struct VSInput
{
    float3 Position           : POSITION;
    float2 DiffuseTexCoord    : TEXCOORD0;
    float3 Normal : NORMAL;
};

struct VSOutput
{
    float4 Position            : POSITION;
    float4 DiffuseTexCoord     : TEXCOORD0;
    float2 ShroudTexCoord      : TEXCOORD3;
};

//-----------------------------------------------------------------------------
// Vertex Shader
//-----------------------------------------------------------------------------

VSOutput VS( VSInput Input )
{
    VSOutput Output;

    // Position is already in world space
    Output.Position = mul( float4( Input.Position, 1 ), GetViewProjection() );

    // Copy UVs
	Output.DiffuseTexCoord.xy = float2(Input.DiffuseTexCoord.x + Time, Input.DiffuseTexCoord.y + Time);
	Output.DiffuseTexCoord.zw = float2(Input.DiffuseTexCoord.x * .5 - Time, Input.DiffuseTexCoord.y * .5 + Time);

	// Calculate Shroud UVs
	// Note: Input is already in world space
	Output.ShroudTexCoord = CalculateShroudTexCoord( Shroud, Input.Position );

	return Output;
}

//-----------------------------------------------------------------------------
// Pixel Shader
//-----------------------------------------------------------------------------

float4 PS( VSOutput Input, uniform bool applyGammaCorrection ) : Color
{
	float4 texture1 = tex2D( SAMPLER(Texture1), Input.DiffuseTexCoord.xy );
	float4 texture2 = tex2D( SAMPLER(Texture1), Input.DiffuseTexCoord.zw);

	if (applyGammaCorrection)
	{
		texture1.xyz = GammaToLinear(texture1.xyz);
		texture2.xyz = GammaToLinear(texture2.xyz);
	}

	float4 color = min(texture1 * texture2,1);
	
	// Apply shroud
	float shroud = tex2D( SAMPLER(ShroudTexture), Input.ShroudTexCoord ).x;
	shroud = BiasShroudValueForEffects( shroud );
	color.xyz *= shroud;

	return color;
}

//-----------------------------------------------------------------------------
// Techniques
//-----------------------------------------------------------------------------

technique Multiply
{
	pass pass0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS(true);

		ZEnable          = true;
		ZWriteEnable     = false;
		ZFunc            = ZFUNC_INFRONT;

		AlphaBlendEnable = true;
		CullMode         = CCW;

		SrcBlend         = Zero;
		DestBlend        = InvSrcColor;
	}
}

technique Additive
{
	pass pass0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS(true);

		ZEnable          = true;
		ZWriteEnable     = false;
		ZFunc            = ZFUNC_INFRONT;

		AlphaBlendEnable = true;
		CullMode         = CCW;

		SrcBlend         = One;
		DestBlend        = One;
	}
}

#if ENABLE_LOD

technique Multiply_M
{
	pass pass0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS(false);

		ZEnable          = true;
		ZWriteEnable     = false;
		ZFunc            = ZFUNC_INFRONT;

		AlphaBlendEnable = true;
		CullMode         = CCW;

		SrcBlend         = Zero;
		DestBlend        = InvSrcColor;
	}
}

technique Additive_M
{
	pass pass0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS(false);

		ZEnable          = true;
		ZWriteEnable     = false;
		ZFunc            = ZFUNC_INFRONT;

		AlphaBlendEnable = true;
		CullMode         = CCW;

		SrcBlend         = One;
		DestBlend        = One;
	}
}

#endif // if ENABLE_LOD