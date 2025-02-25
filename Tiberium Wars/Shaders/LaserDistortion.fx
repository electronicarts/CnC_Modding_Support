//-----------------------------------------------------------------------------
// ©2006 Electronic Arts Inc
//-----------------------------------------------------------------------------

#include "Common.fxh"

//-----------------------------------------------------------------------------

float4x4 World      : World      < string UIWidget="None"; >;
float4x4 View       : View       < string UIWidget="None"; >;
float4x4 Projection : Projection < string UIWidget="None"; >;

// ----------------------------------------------------------------------------
// Texture1
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN(Texture1,
string UIWidget = "None";
)
    MinFilter     = MinFilterBest;
    MagFilter     = MagFilterBest;
    MipFilter     = MipFilterBest;
    MaxAnisotropy = 8;
    AddressU      = Wrap;
    AddressV      = Wrap;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Texture2
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN(Texture2,
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
    float3 Normal   : NORMAL;
    float3 Tangent  : TANGENT;
    float3 Binormal : BINORMAL;
    float2 UV0      : TEXCOORD0;
    float2 UV1      : TEXCOORD1;
};

struct VSOutput
{
    float4   Position           : POSITION;
    float2   UV0                : TEXCOORD0;
    float2   UV1                : TEXCOORD1;
    float2   ShroudTexCoord     : TEXCOORD2;
    float3x3 TangentToViewSpace : TEXCOORD3;
};

//-----------------------------------------------------------------------------
// Pixel Shader structures
//-----------------------------------------------------------------------------

struct PSOutput
{
    float4 Color : COLOR0;
};

//-----------------------------------------------------------------------------

void CalculatePositionAndTangentFrame( VSInput vertex,
                                       out float3 WorldPosition,
                                       out float3 WorldNormal,
                                       out float3 WorldTangent,
                                       out float3 WorldBinormal )
{
    WorldPosition = mul( float4( vertex.Position, 1 ), World );
    WorldNormal   = normalize( mul( vertex.Normal,  (float3x3)World ) );
    WorldTangent  = normalize( mul( vertex.Tangent, (float3x3)World ) );
    WorldBinormal = normalize( mul( vertex.Binormal,(float3x3)World ) );
}

//-----------------------------------------------------------------------------
// Vertex Shader
//-----------------------------------------------------------------------------

VSOutput VS( VSInput Input )
{
    VSOutput Output;
    
    float3 world_position = 0;
    float3 world_normal   = 0;
    float3 world_tangent  = 0;
    float3 world_binormal = 0;
    
    CalculatePositionAndTangentFrame( Input, world_position, world_normal, world_tangent, world_binormal );
    
    // Transform position to projection space
    Output.Position = mul( float4( world_position, 1 ), mul( View, Projection ) );

    // Build 3x3 tranform from tangent to world space
    float3x3 tangent_to_world_space = float3x3( -world_binormal, -world_tangent, world_normal );
    Output.TangentToViewSpace = mul( tangent_to_world_space, (float3x3)View );

    // Transfer UVs
    Output.UV0 = Input.UV0;
    Output.UV1 = Input.UV1;

    // Calculate Shroud UVs
	Output.ShroudTexCoord = CalculateShroudTexCoord( Shroud, world_position );

    return Output;
}

//-----------------------------------------------------------------------------
// Pixel Shader
//-----------------------------------------------------------------------------

PSOutput PS( VSOutput Input )
{
    PSOutput Output;

    float4 normal1 = tex2D( SAMPLER(Texture1), Input.UV0 );
    float4 normal2 = tex2D( SAMPLER(Texture2), Input.UV1 );
    
    float3 bump_normal1 = ( normal1 * 2.0 ) - 1.0;
    float3 bump_normal2 = ( normal2 * 2.0 ) - 1.0;

    float3 bump_normal = normalize( bump_normal1 + bump_normal2 );

    float3 normal = mul( bump_normal, Input.TangentToViewSpace );

    Output.Color = float4( ( normal * 0.5 ) + 0.5, normal1.w * normal2.w );

    // Apply shroud
	float shroud = tex2D( SAMPLER(ShroudTexture), Input.ShroudTexCoord ).x;
	shroud = BiasShroudValueForEffects( shroud );
	Output.Color.w *= shroud;

    return Output;
}

//-----------------------------------------------------------------------------
// Technique: Default (Medium and up)
//-----------------------------------------------------------------------------
technique Default_M
{
    pass pass0
    {
        VertexShader = compile vs_2_0 VS();
        PixelShader  = compile ps_2_0 PS();

        ZEnable          = true;
        ZWriteEnable     = true;
        ZFunc            = ZFUNC_INFRONT;
        AlphaBlendEnable = true;
        AlphaTestEnable  = false;
        
        CullMode         = none;
        SrcBlend         = SrcAlpha;
        DestBlend        = InvSrcAlpha;

#if !defined( _NO_FIXED_FUNCTION_ )
        FogEnable = false;
#endif
    }
}

// ----------------------------------------------------------------------------
// Technique: Default (Low)
// ----------------------------------------------------------------------------
technique Default_L
{
	// No passes. Indicates technique disabled.
}
