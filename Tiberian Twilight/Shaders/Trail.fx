//-----------------------------------------------------------------------------
// ©2006 Electronic Arts Inc
//-----------------------------------------------------------------------------

#include "Common.fxh"
#include "CommonParticle.fxh"

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
#if SUPPORT_FOG
    float3 Fog             : COLOR1; // This is just a scalar, but PS1.1 can't replicate-swizzle, so replicate scalar into a vector in vertex shader
#endif // #if SUPPORT_FOG
    float4 DiffuseTexCoord_ShroudTexCoord : TEXCOORD0;
};

//-----------------------------------------------------------------------------
// Vertex Shader
//-----------------------------------------------------------------------------

VSOutput VS( VSInput Input )
{
    VSOutput Output;
    
    // Input Position is already in world space
    Output.Position = mul( float4( Input.Position, 1 ), GetViewProjection() );

    Output.Color           = Input.Color;
    Output.DiffuseTexCoord_ShroudTexCoord.xy = Input.DiffuseTexCoord;
    
#if SUPPORT_FOG
    // Calculate fog
    Output.Fog = CalculateFog( Fog, Input.Position, GetEyePosition() ).xxx;
#endif // #if SUPPORT_FOG

    // Calculate Shroud UVs
    // Note: Input is already in world space
    Output.DiffuseTexCoord_ShroudTexCoord.zw = CalculateShroudTexCoord( Shroud, Input.Position );

    return Output;
}

//-----------------------------------------------------------------------------
// Pixel Shader
//-----------------------------------------------------------------------------

float4 PS( VSOutput Input, uniform int fog_mode ) COLORTARGET
{
    // Get the base color
    float4 diffuse_texture = tex2D( SAMPLER(DiffuseTexture), Input.DiffuseTexCoord_ShroudTexCoord.xy );
    float4 color = diffuse_texture * Input.Color;

#if SUPPORT_FOG
	// Apply fog
	ApplyFog(fogMode, In.Fog, Color);
#endif // #if SUPPORT_FOG

    // Apply shroud
    float shroud = tex2D( SAMPLER(ShroudTexture), Input.DiffuseTexCoord_ShroudTexCoord.zw ).x;
	shroud = BiasShroudValueForEffects( shroud );
    color.xyz *= shroud;

    return color;
}

//-----------------------------------------------------------------------------

float4 PS_Xenon( VSOutput In ) : COLOR
{
    return PS( In, GetParticleFogMode() );
}

//-----------------------------------------------------------------------------
// Techniques
//-----------------------------------------------------------------------------

#define PS_ShaderType \
    compile PS_2_0 PS(FogMode_Disabled), \
    compile PS_2_0 PS(FogMode_Opaque), \
    compile PS_2_0 PS(FogMode_Additive)

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
        USE_EXPRESSION_EVALUATOR("Particle")
    >
    {
        VertexShader = compile VS_2_0 VS();

        PixelShader = ARRAY_EXPRESSION_PS( PS_Array,
#if SUPPORT_FOG
                                           Fog.IsEnabled ? ((Draw_ShaderType == ShaderType_Additive || Draw_ShaderType == ShaderType_AdditiveAlphaTest || Draw_ShaderType == ShaderType_Multiply) ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled,
#else // #if SUPPORT_FOG
                                           FogMode_Disabled,
#endif // #if SUPPORT_FOG
                                           compile PS_VERSION PS_Xenon() );

        ZEnable      = true;
        ZWriteEnable = false;
        ZFunc        = ZFUNC_INFRONT;
        CullMode     = none;

        SETUP_ALPHA_BLEND_AND_TEST(Draw_ShaderType);
    }
}
