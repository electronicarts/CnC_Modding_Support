//-----------------------------------------------------------------------------
// ©2006 Electronic Arts Inc
//-----------------------------------------------------------------------------

#include "Common.fxh"

//-----------------------------------------------------------------------------

float4x4 View       : View       < string UIWidget="None"; >;

#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float4x4 GetViewProjection()
{
	return ViewProjection;
}
#else
float4x4 Projection : Projection;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}
#endif

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
	float3   TangentToViewSpace0: TEXCOORD3;
	float3   TangentToViewSpace1: TEXCOORD4;
	float3   TangentToViewSpace2: TEXCOORD5;
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
    WorldPosition = mul( float4( vertex.Position.xyz, 1 ), World ).xyz;
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
    Output.Position = mul( float4( world_position, 1 ), GetViewProjection() );

    // Build 3x3 tranform from tangent to world space
	float3x3 tangentToWorldSpace = float3x3(-world_binormal, -world_tangent, world_normal);
	tangentToWorldSpace = mul(tangentToWorldSpace, (float3x3)View);

	Output.TangentToViewSpace0 = tangentToWorldSpace[0];
	Output.TangentToViewSpace1 = tangentToWorldSpace[1];
	Output.TangentToViewSpace2 = tangentToWorldSpace[2];

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
    
    float3 bump_normal1 = ( normal1.xyz * 2.0 ) - 1.0;
    float3 bump_normal2 = ( normal2.xyz * 2.0 ) - 1.0;

    float3 bump_normal = normalize( bump_normal1 + bump_normal2 );

	float3x3 TangentToViewSpace = float3x3(Input.TangentToViewSpace0, Input.TangentToViewSpace1, Input.TangentToViewSpace2);
	float3 normal = mul( bump_normal, TangentToViewSpace );

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
        VertexShader = compile VS_2_0 VS();
        PixelShader  = compile PS_2_0 PS();

        ZEnable          = true;
        ZWriteEnable     = true;
        ZFunc            = ZFUNC_INFRONT;
        AlphaBlendEnable = true;
        AlphaTestEnable  = false;
        
        CullMode         = none;
        SrcBlend         = SrcAlpha;
        DestBlend        = InvSrcAlpha;
    }
}

// ----------------------------------------------------------------------------
// Technique: Default (Low)
// ----------------------------------------------------------------------------
technique Default_L
{
	// No passes. Indicates technique disabled.
}
