//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for simple unlit rendering
//////////////////////////////////////////////////////////////////////////////
#include "Common.fxh"

// ----------------------------------------------------------------------------
// MATERIAL PARAMATERS
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( RiverTexture,
    string UIName = "River Texture";
    )
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
SAMPLER_2D_END

float4 Opacity
< 
    string UIName = "Opacity";
> = float4(1, 1, 1, 1);

// ----------------------------------------------------------------------------
// Reflection
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( WaterReflectionTexture,
    string UIWidget = "None";
    string SasBindAddress = "WaterDraw.ReflectionTexture";
    )
    MipFilter = Point;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = CLAMP;
    AddressV = CLAMP;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Environment map
// ----------------------------------------------------------------------------
SAMPLER_CUBE_BEGIN( EnvironmentTexture,
    string UIWidget = "None";
    string SasBindAddress = "Terrain.EnvironmentTexture";
    string ResourceType = "Cube"; 
    )
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
    AddressW = Clamp;
SAMPLER_CUBE_END

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
float4x4 WorldViewProjection : WorldViewProjection;
float4x4 World : World;
float4x4 ViewI : ViewInverse;
float    Time  : Time;

// ----------------------------------------------------------------------------
// Fog
// ----------------------------------------------------------------------------
WW3DFog Fog
<
    string UIWidget = "None";
    string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;


// ----------------------------------------------------------------------------
// SHADER: Default (UltraHigh)
// ----------------------------------------------------------------------------
struct VSOutput
{
    float4 Position           : POSITION;
    float4 Color              : COLOR0;
    float  Fog                : COLOR1;
    float2 RiverTexCoord      : TEXCOORD0;
    float2 ShroudTexCoord     : TEXCOORD1;
    float3 ReflectionTexCoord : TEXCOORD2;
};

// ----------------------------------------------------------------------------
VSOutput VS( float3 Position       : POSITION,
             float4 Color          : COLOR0,
             float2 RiverTexCoord  : TEXCOORD0,
             float2 NormalTexCoord : TEXCOORD1 )
{
    VSOutput Out;

    // Position
    Out.Position = mul( float4(Position, 1), WorldViewProjection );

    // Color
    float4 color = Color;
    color.w *= Opacity.w;

    Out.Color = color;

    // Fog
    float3 worldPosition = mul( float4(Position, 1), World );
    Out.Fog = CalculateFog( Fog, worldPosition, ViewI[3] );

    // RiverTexCoord
    Out.RiverTexCoord = NormalTexCoord;

    // ShroudTexCoord
    Out.ShroudTexCoord = CalculateShroudTexCoord( Shroud, worldPosition );

    // ReflectionTexCoord
    Out.ReflectionTexCoord.xy = 0.5 * ( Out.Position.xy + Out.Position.w * float2(1.0, 1.0) );
    Out.ReflectionTexCoord.z = Out.Position.w;

    return Out;
}

// ----------------------------------------------------------------------------
float4 PS( VSOutput In ) : COLOR
{
    // Sample the base texture
    float4 color = tex2D( SAMPLER(RiverTexture), In.RiverTexCoord );

    // Apply vertex color
    color *= In.Color;

    // Apply the reflection map
    float2 reflectionCoord = In.ReflectionTexCoord.xy / In.ReflectionTexCoord.z;
    float3 reflectionColor = tex2D( SAMPLER(WaterReflectionTexture), reflectionCoord );

    color.xyz *= reflectionColor;

    // Apply fog
    color.xyz *= In.Fog;

    // Apply shroud
    float3 shroud = tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord ).xyz;
    color.xyz *= shroud;

    return color;
}

// ----------------------------------------------------------------------------

technique Default_U
{
    pass P0
    {
        VertexShader = compile VS_VERSION_HIGH VS();
        PixelShader  = compile PS_VERSION_HIGH PS();

        ZEnable = true;
        ZFunc = ZFUNC_INFRONT;
        ZWriteEnable = false;
        CullMode = None;
        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        ColorWriteEnable = 7;
        
        SrcBlend  = SrcAlpha;
        DestBlend = One;
    }
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: Default Medium Quality
// ----------------------------------------------------------------------------
struct VSOutput_M
{
    float4 Position           : POSITION;
    float4 Color              : COLOR0;
    float  Fog                : COLOR1;
    float2 RiverTexCoord      : TEXCOORD0;
    float2 ShroudTexCoord     : TEXCOORD1;
    float3 ReflectionTexCoord : TEXCOORD2;
};

// ----------------------------------------------------------------------------
VSOutput_M VS_M( float3 Position       : POSITION,
                 float4 Color          : COLOR0,
                 float2 RiverTexCoord  : TEXCOORD0,
                 float2 NormalTexCoord : TEXCOORD1 )
{
    VSOutput_M Out;

    // Position
    Out.Position = mul( float4(Position, 1), WorldViewProjection );

    // Color
    float4 color = Color;
    color.w *= Opacity.w;

    Out.Color = color;

    // Fog
    float3 worldPosition = mul( float4(Position, 1), World );
    Out.Fog = CalculateFog( Fog, worldPosition, ViewI[3] );

    // RiverTexCoord
    Out.RiverTexCoord = NormalTexCoord;

    // ShroudTexCoord
    Out.ShroudTexCoord = CalculateShroudTexCoord( Shroud, worldPosition );

    // Compute view direction in world space
    float3 worldEyeDir = normalize( ViewI[3] - worldPosition );

    // Compute env map reflection direction
    float3 worldNormal = float3( 0, 0, 1 ); // Rivers always face up
    Out.ReflectionTexCoord = -reflect( worldEyeDir, worldNormal );

    return Out;
}

// ----------------------------------------------------------------------------
float4 PS_M( VSOutput_M In ) : COLOR
{
    // Sample the base texture
    float4 color = tex2D( SAMPLER(RiverTexture), In.RiverTexCoord );

    // Apply vertex color
    color *= In.Color;

    // Apply the reflection map
    float3 reflectionColor = texCUBE( SAMPLER(EnvironmentTexture), In.ReflectionTexCoord );
    color.xyz *= reflectionColor;

    // Apply fog
    color.xyz *= In.Fog;

    // Apply shroud
    float3 shroud = tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord ).xyz;
    color.xyz *= shroud;
    
    return color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: High Quality
// ----------------------------------------------------------------------------
technique _Default
{
    pass P0
    {
        VertexShader = compile VS_VERSION_HIGH VS_M();
        PixelShader  = compile PS_VERSION_HIGH PS_M();

        ZEnable = true;
        ZFunc = ZFUNC_INFRONT;
        ZWriteEnable = false;
        CullMode = None;
        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        ColorWriteEnable = 7;

        SrcBlend  = SrcAlpha;
        DestBlend = One;
    }
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Low Quality
// ----------------------------------------------------------------------------
technique _Default_L
{
    // Do nothing!
}
#endif
