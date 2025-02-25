//-----------------------------------------------------------------------------
// ©2006 Electronic Arts Inc
//-----------------------------------------------------------------------------

#include "Common.fxh"

#define USE_INTERACTIVE_LIGHTS 1

// ----------------------------------------------------------------------------
// Phase Offset
// ----------------------------------------------------------------------------

float3 PhaseOffset
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.PhaseOffset";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
> = float3( 0.0, 0.0, 0.0 );

// ----------------------------------------------------------------------------
// Phase Opacity
// ----------------------------------------------------------------------------

float PhaseOpacity
<
	string UIWidget = "None";
	string SasBindAddress = "Particle.Draw.PhaseOpacity";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
> = 1.0;

// ----------------------------------------------------------------------------
// FOG
// ----------------------------------------------------------------------------

WW3DFog Fog
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;

// ----------------------------------------------------------------------------
// Light sources
// ----------------------------------------------------------------------------

static const int NumDirectionalLights = 3;
SasDirectionalLight DirectionalLight[NumDirectionalLights]
<
	string SasBindAddress = "Sas.DirectionalLight[*]";
	string UIWidget = "None";
> =
{
	DEFAULT_DIRECTIONAL_LIGHT_1,
	DEFAULT_DIRECTIONAL_LIGHT_2,
	DEFAULT_DIRECTIONAL_LIGHT_3
};

// ----------------------------------------------------------------------------
// Transforms
// ----------------------------------------------------------------------------

float4x4 View        : View;
float4x3 ViewInverse : ViewInverse;
float4x4 Projection  : Projection;
float4x4 WorldViewProjection : WorldViewProjection;

// ----------------------------------------------------------------------------
// Fake motion blur opacity values
// ----------------------------------------------------------------------------

float OpaqueSpeed
< 
	string UIName = "Opaque Speed";
    float UIMin = 0.0f;
    float UIMax = 10000.0f;
> = 0.0f;

float TransparentSpeed
< 
	string UIName = "Transparent Speed";
    float UIMin = 0.0f;
    float UIMax = 10000.0f;
> = 100.0f;

// ----------------------------------------------------------------------------
// Speed Stretch Amount
// ----------------------------------------------------------------------------

float SpeedStretchAmount
< 
	string UIName = "Speed Stretch Amount";
    float UIMin = 0.0f;
    float UIMax = 10000.0f;
> = 1.0f;

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
    AddressU  = Wrap;
    AddressV  = Wrap;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Environment Texture
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( EnvironmentTexture,
    string UIWidget = "None";
    string SasBindAddress = "Particle.Draw.DetailTexture";
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
    float3 Position        : POSITION;
    float2 DiffuseTexCoord : TEXCOORD0;
    float3 Velocity        : TEXCOORD1;
};

struct VSOutput
{
    float4 Position            : POSITION;
    float4 Color               : COLOR0;
    float4 LightColor_Fog      : COLOR1;
    float2 DiffuseTexCoord     : TEXCOORD1;
    float2 EnvironmentTexCoord : TEXCOORD2;
    float2 ShroudTexCoord      : TEXCOORD3;
};

//-----------------------------------------------------------------------------
// Vertex Shader
//-----------------------------------------------------------------------------

VSOutput VS( VSInput Input )
{
    VSOutput Output;

    // Get the center of the particle, in view space
    float4 view_pos_center = mul( float4( Input.Position, 1), View );
    view_pos_center.w = 1;

    // Get the velocity, in view space
    float4 view_velocity_offset = float4( Input.Position + Input.Velocity, 1 );
    view_velocity_offset = mul( view_velocity_offset, View );
  
    float3 view_velocity = view_velocity_offset.xyz - view_pos_center.xyz;

    float speed = length( Input.Velocity );

    // Offset the vertex from the center based on it's size and velocity
    // We use the normalized UV space(0->1) to determine which corner
    // of the particle we're computing
    float3 velocity_vec_y = normalize( view_velocity );
    float3 velocity_vec_x = normalize( cross( velocity_vec_y, view_pos_center ) );
    
    float2 normalized_offset = ( Input.DiffuseTexCoord * float2( 2, 2 ) ) - float2( 1, 1 );
    float  half_size         = 0.5; // Size is currently set to 1 for all Swarm particle systems

    float4 vertex_view_pos = view_pos_center;
    vertex_view_pos.xyz += normalized_offset.x * half_size * velocity_vec_x;
    vertex_view_pos.xyz += ( half_size + ( speed * SpeedStretchAmount ) ) * ( normalized_offset.y * velocity_vec_y );

    vertex_view_pos.w = 1;

    // Fake motion blur by fading out the particle the faster it's moving
    float fade_interpolant = ( speed - OpaqueSpeed ) / ( TransparentSpeed - OpaqueSpeed );
    fade_interpolant = clamp( fade_interpolant, 0, 1 );

    float motion_blur_fade = 1 - fade_interpolant; //float motion_blur_fade = lerp( 1, 0, fade_interpolant );
    float opacity = motion_blur_fade * PhaseOpacity;

    // Get the final vertex position, in world space
    float3 world_position = mul( vertex_view_pos, ViewInverse );
    world_position += PhaseOffset;

    // Set basic outputs
    Output.Position           = mul( float4( world_position, 1 ), WorldViewProjection );
    Output.LightColor_Fog.xyz = float3((DirectionalLight[0].Color + DirectionalLight[1].Color + DirectionalLight[2].Color)* .7);
    Output.Color              = float4( 1, 1, 1, opacity );
    Output.DiffuseTexCoord    = Input.DiffuseTexCoord;
    
   	// Build normal for particle vertex
	static const float flattenNormal = .2; // 0 = totally flat, 1 = sphere normal
	float3 normal = float3((Input.DiffuseTexCoord - 0.5) * 2 * flattenNormal, 0);
	normal.z = sqrt(1.0 - normal.x * normal.x + normal.y * normal.y);
	
	float3x3 particleToViewSpace = float3x3(velocity_vec_x, velocity_vec_y, cross(velocity_vec_x, velocity_vec_y));
	float3 vertexWorldNormal = normalize(mul(normal, particleToViewSpace));
	
	Output.EnvironmentTexCoord = vertexWorldNormal.xy * 0.5 + 0.5;

    // Calculate Shroud UVs
	Output.ShroudTexCoord = CalculateShroudTexCoord( Shroud, world_position );

	// Calculate fog
	Output.LightColor_Fog.w = CalculateFog(Fog, world_position, ViewInverse[3]);

    return Output;
}

//-----------------------------------------------------------------------------
// Pixel Shader
//-----------------------------------------------------------------------------

float4 PS( VSOutput Input ) : Color
{
    // Get the base color
    float4 diffuse_texture = tex2D( SAMPLER(DiffuseTexture), Input.DiffuseTexCoord );
    float4 Color = diffuse_texture * Input.Color;

    // Apply environment texture
    float4 environment_texture = tex2D( SAMPLER(EnvironmentTexture), Input.EnvironmentTexCoord );
    Color.xyz += environment_texture.xyz * Input.LightColor_Fog;

	//Apply fog
	float fogStrength = Input.LightColor_Fog.w;
	Color.xyz = lerp(Fog.Color, Color.xyz, fogStrength);

    // Apply shroud
	float shroud = tex2D( SAMPLER(ShroudTexture), Input.ShroudTexCoord ).x;
	shroud = BiasShroudValueForEffects( shroud );
	Color.xyz *= shroud;

    return Color;
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

        ZEnable          = true;
        ZWriteEnable     = false;
        ZFunc            = ZFUNC_INFRONT;
        AlphaBlendEnable = true;
        
        CullMode         = none;
        SrcBlend         = SrcAlpha; //One;
        DestBlend        = InvSrcAlpha;

#if !defined( _NO_FIXED_FUNCTION_ )
        FogEnable = false;
#endif
    }
}
