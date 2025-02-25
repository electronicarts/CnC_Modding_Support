//-----------------------------------------------------------------------------
// ©2006 Electronic Arts Inc
//-----------------------------------------------------------------------------

#include "Common.fxh"
#include "Gamma.fxh"

float4x4 WorldViewProjection : WorldViewProjection;

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

//-----------------------------------------------------------------------------
// Vertex Shader structure
//-----------------------------------------------------------------------------

struct VSInput
{
    float3 Position : POSITION;
    float2 UV0      : TEXCOORD0;
    float2 UV1      : TEXCOORD1;
};

struct VSOutput
{
    float4 Position       : POSITION;
    float2 UV0            : TEXCOORD0;
    float2 UV1            : TEXCOORD1;
    float2 ShroudTexCoord : TEXCOORD2;
};

//-----------------------------------------------------------------------------
// Pixel Shader structures
//-----------------------------------------------------------------------------

struct PSOutput
{
    float4 Color : COLOR0;
};

//-----------------------------------------------------------------------------
// Vertex Shader
//-----------------------------------------------------------------------------

VSOutput VS( VSInput Input )
{
    VSOutput Output;
    
    Output.Position = mul( float4( Input.Position, 1 ), WorldViewProjection );
    Output.UV0      = Input.UV0;
    Output.UV1      = Input.UV1;

    // Calculate Shroud UVs
    float3 worldPosition = mul( float4( Input.Position, 1), World ).xyz;
	Output.ShroudTexCoord = CalculateShroudTexCoord( Shroud, worldPosition );

    return Output;
}

//-----------------------------------------------------------------------------
// Pixel Shader
//-----------------------------------------------------------------------------

PSOutput PS( VSOutput Input, uniform bool applyGammaCorrection )
{
    PSOutput Output;

    float4 texture1 = tex2D( SAMPLER(Texture1), Input.UV0 );
    float4 texture2 = tex2D( SAMPLER(Texture2), Input.UV1 );

    Output.Color = texture1 * texture2;

	if (applyGammaCorrection)
	{
		Output.Color.xyz = GammaToLinear(Output.Color.xyz);
	}

    // Apply shroud
	float shroud = tex2D( SAMPLER(ShroudTexture), Input.ShroudTexCoord ).x;
	shroud = BiasShroudValueForEffects( shroud );
	Output.Color.xyz *= shroud;

    return Output;
}

PSOutput PS_GammaCorrection( VSOutput Input )
{
	return PS(Input, true);
}

PSOutput PS_NoGammaCorrection( VSOutput Input )
{
	return PS(Input, false);
}

//-----------------------------------------------------------------------------
// Techniques
//-----------------------------------------------------------------------------

technique Default
{
    pass pass0
    {
        VertexShader = compile VS_2_0 VS();
        PixelShader  = compile PS_2_0 PS_GammaCorrection();

        ZEnable          = true;
        ZWriteEnable     = false;
        ZFunc            = ZFUNC_INFRONT;
        AlphaBlendEnable = true;
        
        CullMode         = none;
        SrcBlend         = SrcAlpha; //One;
        DestBlend        = InvSrcAlpha;
    }
}

technique Default_M
{
    pass pass0
    {
        VertexShader = compile VS_2_0 VS();
        PixelShader  = compile PS_2_0 PS_NoGammaCorrection();

        ZEnable          = true;
        ZWriteEnable     = false;
        ZFunc            = ZFUNC_INFRONT;
        AlphaBlendEnable = true;
        
        CullMode         = none;
        SrcBlend         = SrcAlpha; //One;
        DestBlend        = InvSrcAlpha;
    }
}