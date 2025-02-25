//-----------------------------------------------------------------------------
// ©2006 Electronic Arts Inc
//-----------------------------------------------------------------------------

#include "Common.fxh"

float4x4 View       : View;
float4x4 Projection : Projection;

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
float4x3 ViewI : ViewInverse;
float Time : Time;
float4x3 World : World;

//-----------------------------------------------------------------------------
// Vertex Shader structure
//-----------------------------------------------------------------------------

struct VSInput
{
    float3 Position           : POSITION;
    float2 DiffuseTexCoord    : TEXCOORD0;
//    float2 NormalizedTexCoord : TEXCOORD1;
    float3 Normal : NORMAL;
};

struct VSOutput
{
    float4 Position            : POSITION;
    float2 DiffuseTexCoord     : TEXCOORD0;
//    float2 NormalizedTexCoord  : TEXCOORD1;
    float2 ShroudTexCoord      : TEXCOORD3;
    float3 Color			   : COLOR;
};

//-----------------------------------------------------------------------------
// Vertex Shader
//-----------------------------------------------------------------------------

VSOutput VS( VSInput Input )
{
    VSOutput Output;

    // Position is already in world space
	float4x4 ViewProjection = mul( View, Projection );
    Output.Position = mul( float4( Input.Position, 1 ), ViewProjection );

    // Copy UVs
    Output.DiffuseTexCoord    = float2(Input.DiffuseTexCoord.x, Input.DiffuseTexCoord.y);
//    Output.NormalizedTexCoord = Input.NormalizedTexCoord;

	// --------------- Fade out edges -----------------------------
	// Compute view direction in world space
	float3 worldEyeDir = normalize(ViewI[3] - Input.Position);

	float3 worldNormal = normalize(mul(Input.Normal, (float3x3)World));

	float viewingAngle = abs(dot(worldEyeDir, worldNormal));
	float fadeOut = smoothstep(0.0, 1.0, viewingAngle);

	Output.Color = fadeOut;

    // Calculate Shroud UVs
    // Note: Input is already in world space
	Output.ShroudTexCoord = CalculateShroudTexCoord( Shroud, Input.Position );

    return Output;
}

//-----------------------------------------------------------------------------
// Pixel Shader
//-----------------------------------------------------------------------------

float4 PS( VSOutput Input ) : Color
{
    float4 texture1 = tex2D( SAMPLER(Texture1), Input.DiffuseTexCoord );
    float4 texture2 = tex2D( SAMPLER(Texture2), (Input.DiffuseTexCoord * .5) + Time * .1);

//	float4 color = float4(Input.Color, 1.0);
	
//	return color;
	float4 color = float4(1.0,1.0,1.0,1.0);

//	return color;
    color *= texture1 * texture2 * .75 * Input.Color.x;

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
        VertexShader = compile VS_VERSION_HIGH VS();
        PixelShader  = compile PS_VERSION_HIGH PS();

        ZEnable          = true;
        ZWriteEnable     = false;
        ZFunc            = ZFUNC_INFRONT;
        
        AlphaBlendEnable = true;
        CullMode         = CCW;

        SrcBlend         = Zero;
        DestBlend        = InvSrcColor;

#if !defined( _NO_FIXED_FUNCTION_ )
        FogEnable = false;
#endif
    }
}

technique Additive
{
    pass pass0
    {
        VertexShader = compile VS_VERSION_HIGH VS();
        PixelShader  = compile PS_VERSION_HIGH PS();

        ZEnable          = true;
        ZWriteEnable     = false;
        ZFunc            = ZFUNC_INFRONT;
        
        AlphaBlendEnable = true;
        CullMode         = CCW;

        SrcBlend         = One;
        DestBlend        = One;

#if !defined( _NO_FIXED_FUNCTION_ )
        FogEnable = false;
#endif
    }
}
