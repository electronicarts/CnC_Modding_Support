//-----------------------------------------------------------------------------
// ©2006 Electronic Arts Inc
//-----------------------------------------------------------------------------

#include "Common.fxh"
#include "CommonParticle.fxh"

float4x4 View        : View;
float4x4 Projection  : Projection;
float4x4 ViewInverse : ViewInverse;

// ----------------------------------------------------------------------------
// Diffuse Texture
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( DiffuseTexture,
    string UIWidget = "None";
    string SasBindAddress = "Particle.Draw.Texture";
    )
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU  = Clamp;
    AddressV  = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Fog
// ----------------------------------------------------------------------------

WW3DFog Fog
<
    string UIWidget = "None";
    string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;

// Variationgs for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque   = 1;
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

//-----------------------------------------------------------------------------
// Vertex Shader structure
//-----------------------------------------------------------------------------

struct VSInput
{
    float3 Position        : POSITION;
    float4 Color           : COLOR0;
    float2 DiffuseTexCoord : TEXCOORD0;
};

struct VSOutput
{
    float4 Position        : POSITION;
    float4 Color           : COLOR0;
    float3 Fog             : COLOR1; // This is just a scalar, but PS1.1 can't replicate-swizzle, so replicate scalar into a vector in vertex shader
    float2 DiffuseTexCoord : TEXCOORD0;
    float2 ShroudTexCoord  : TEXCOORD1;
};

//-----------------------------------------------------------------------------
// Vertex Shader
//-----------------------------------------------------------------------------

VSOutput VS( VSInput Input )
{
    VSOutput Output;
    
    // Input Position is already in world space
    float4x4 ViewProjection = mul( View, Projection );
    Output.Position = mul( float4( Input.Position, 1 ), ViewProjection );

    Output.Color           = Input.Color;
    Output.DiffuseTexCoord = Input.DiffuseTexCoord;
    
    // Calculate fog
    Output.Fog = CalculateFog( Fog, Input.Position, ViewInverse[3] ).xxx;

    // Calculate Shroud UVs
    // Note: Input is already in world space
    Output.ShroudTexCoord = CalculateShroudTexCoord( Shroud, Input.Position );

    return Output;
}

//-----------------------------------------------------------------------------
// Pixel Shader
//-----------------------------------------------------------------------------

float4 PS( VSOutput Input, uniform int fog_mode ) : Color
{
    // Get the base color
    float4 diffuse_texture = tex2D( SAMPLER(DiffuseTexture), Input.DiffuseTexCoord );
    float4 color = diffuse_texture * Input.Color;

    // Apply fog
    if( fog_mode == FogMode_Opaque )
    {
        color.xyz = lerp( Fog.Color, color.xyz, Input.Fog );
    }
    else if( fog_mode == FogMode_Additive )
    {
        color.xyz *= Input.Fog;
    }

    // Apply shroud
    float shroud = tex2D( SAMPLER(ShroudTexture), Input.ShroudTexCoord ).x;
	shroud = BiasShroudValueForEffects( shroud );
    color.xyz *= shroud;

    return color;
}

//-----------------------------------------------------------------------------

float4 PS_Xenon( VSOutput In ) : COLOR
{
    return PS( In, Fog.IsEnabled ? ((Draw.ShaderType == ShaderType_Additive || Draw.ShaderType == ShaderType_AdditiveAlphaTest || Draw.ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled );
}

//-----------------------------------------------------------------------------
// Techniques
//-----------------------------------------------------------------------------

#define PS_ShaderType \
    compile PS_VERSION_LOW PS(FogMode_Disabled), \
    compile PS_VERSION_LOW PS(FogMode_Opaque), \
    compile PS_VERSION_LOW PS(FogMode_Additive)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final = 3 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
    PS_ShaderType
};
#endif

//-----------------------------------------------------------------------------

technique Default
{
    pass pass0
    <
        USE_EXPRESSION_EVALUATOR("ParticleWithFog")
    >
    {
        VertexShader = compile VS_VERSION_LOW VS();

        PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
                                           Fog.IsEnabled ? ((Draw.ShaderType == ShaderType_Additive || Draw.ShaderType == ShaderType_AdditiveAlphaTest || Draw.ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled,
                                           compile PS_VERSION PS_Xenon() );

        ZEnable      = true;
        ZWriteEnable = false;
        ZFunc        = ZFUNC_INFRONT;
        CullMode     = none;

        SETUP_ALPHA_BLEND_AND_TEST(Draw.ShaderType);

#if !defined( _NO_FIXED_FUNCTION_ )
        FogEnable = false;
#endif
    }
}
