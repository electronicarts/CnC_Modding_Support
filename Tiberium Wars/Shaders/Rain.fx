//-----------------------------------------------------------------------------
// ©2006 Electronic Arts Inc
//-----------------------------------------------------------------------------

#include "Common.fxh"

float4x4 World       : World;
float4x4 View        : View;
float4x3 ViewInverse : ViewInverse;
float4x4 Projection  : Projection;

float Time : Time;

// ----------------------------------------------------------------------------
// Rain Box Size
// ----------------------------------------------------------------------------

float RainBoxHeight
<
	string UIName = "Rain Box Width";
    float UIMin = 0.0;
    float UIMax = 10000.0;
> = 200.0;

// ----------------------------------------------------------------------------
// Size
// ----------------------------------------------------------------------------

float MinWidth
<
	string UIName = "Min Width";
    float UIMin = 0.0;
    float UIMax = 10000.0;
> = 0.5;

float MaxWidth
<
	string UIName = "Max Width";
    float UIMin = 0.0;
    float UIMax = 10000.0;
> = 1.5;

float MinHeight
<
	string UIName = "Min Height";
    float UIMin = 0.0;
    float UIMax = 10000.0;
> = 5.0;

float MaxHeight
<
	string UIName = "Max Height";
    float UIMin = 0.0;
    float UIMax = 10000.0;
> = 15.0;

// ----------------------------------------------------------------------------
// Speed
// ----------------------------------------------------------------------------

float MinSpeed
<
	string UIName = "Min Speed";
    float UIMin = 0.0;
    float UIMax = 10000.0;
> = 50.0;

float MaxSpeed
<
	string UIName = "Max Speed";
    float UIMin = 0.0;
    float UIMax = 10000.0;
> = 150.0;

// ----------------------------------------------------------------------------
// Alpha
// ----------------------------------------------------------------------------

float MinAlpha
<
	string UIName = "Min Alpha";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = 0.1;

float MaxAlpha
<
	string UIName = "Max Alpha";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = 0.5;

// ----------------------------------------------------------------------------
// Wind
// ----------------------------------------------------------------------------

float WindStrength
<
	string UIName = "Wind Strength";
    float UIMin = 0.0;
    float UIMax = 10000.0;
> = 1.0;

// ----------------------------------------------------------------------------
// Diffuse Texture
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( DiffuseTexture,
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
    float3 Position                              : POSITION;
    float4 Width_Height_Speed_Alpha_Interpolants : COLOR0;
    float2 DiffuseTexCoord                       : TEXCOORD0;
};

struct VSOutput
{
    float4 Position        : POSITION;
    float4 Color           : COLOR0;
    float2 DiffuseTexCoord : TEXCOORD0;
    float2 ShroudTexCoord  : TEXCOORD1;
};

//-----------------------------------------------------------------------------
// Vertex Shader
//-----------------------------------------------------------------------------

VSOutput VS( VSInput Input )
{
/*
    // These values are just here so you can override the values in XML for rapid tweaking
    RainBoxHeight = 200;
    
    MinWidth = 0.5;
    MaxWidth = 1.5;
    
    MinHeight = 5;
    MaxHeight = 15;
    
    MinSpeed = 50;
    MaxSpeed = 150;
    
    MinAlpha = 0.1;
    MaxAlpha = 0.5;
*/
    VSOutput Out;

    // Get the values for this particle based on it's random seed data
    float width_interpolant  = Input.Width_Height_Speed_Alpha_Interpolants.x;
    float height_interpolant = Input.Width_Height_Speed_Alpha_Interpolants.y;
    float speed_interpolant  = Input.Width_Height_Speed_Alpha_Interpolants.z;
    float alpha_interpolant  = Input.Width_Height_Speed_Alpha_Interpolants.w;

    float width  = lerp( MinWidth,  MaxWidth,  width_interpolant  );
    float height = lerp( MinHeight, MaxHeight, height_interpolant );
    float speed  = lerp( MinSpeed,  MaxSpeed,  speed_interpolant  );
    float alpha  = lerp( MinAlpha,  MaxAlpha,  alpha_interpolant  );

    // Get the center of the particle, in world space
    float3 world_pos_center = mul( float4( Input.Position, 1 ), World ).xyz;
    world_pos_center.z -= speed * Time;
    world_pos_center.z = RainBoxHeight + fmod( world_pos_center.z, RainBoxHeight );
    
    // Offset the vertex vertically in world space
    float2 normalized_offset = Input.DiffuseTexCoord * - float2( 0.5, 0.5 );
    
    float vertical_offset = height * normalized_offset.y;
    world_pos_center.z += vertical_offset;

    // Transform the vertex into view space
    float3 vertex_view_pos = mul( float4( world_pos_center, 1 ), View ).xyz;

    // Offset the vertex horizontally in view space
    float horizontal_offset = width * normalized_offset.x;
    vertex_view_pos.x += horizontal_offset;

    // Get the final position
	Out.Position = mul( float4( vertex_view_pos, 1 ), Projection );

    // Transfer UVs
    Out.DiffuseTexCoord = Input.DiffuseTexCoord;
    
    // Color
    Out.Color = float4( 1, 1, 1, alpha );
    
    // Calculate Shroud UVs
    float3 world_position = mul( float4( vertex_view_pos, 1 ), ViewInverse ).xyz;
	Out.ShroudTexCoord = CalculateShroudTexCoord( Shroud, world_position );

    return Out;
}

//-----------------------------------------------------------------------------
// Pixel Shader
//-----------------------------------------------------------------------------

float4 PS( VSOutput Input ) : Color
{
    float4 color = Input.Color;

    // Apply Diffuse Texture
    float4 diffuse_texture = tex2D( SAMPLER(DiffuseTexture), Input.DiffuseTexCoord );
    color *= diffuse_texture;

    // Apply shroud
	float shroud = tex2D( SAMPLER(ShroudTexture), Input.ShroudTexCoord ).x;
    color.w *= shroud;

    return color;
}

//-----------------------------------------------------------------------------
// Techniques
//-----------------------------------------------------------------------------

technique Default
{
    pass pass0
    {
        VertexShader = compile VS_VERSION_LOW VS();
        PixelShader  = compile PS_VERSION_LOW PS();

        ZEnable          = false;
        ZWriteEnable     = false;
        ZFunc            = ZFUNC_INFRONT;
        AlphaBlendEnable = true;
        
        CullMode         = none;
        SrcBlend         = SrcAlpha;
        DestBlend        = InvSrcAlpha;

#if !defined( _NO_FIXED_FUNCTION_ )
        FogEnable = false;
#endif
    }
}
