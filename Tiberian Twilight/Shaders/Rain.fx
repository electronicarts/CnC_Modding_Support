//-----------------------------------------------------------------------------
// ©2006 Electronic Arts Inc
//-----------------------------------------------------------------------------

#include "Common.fxh"
#include "Gamma.fxh"
#include "Random.fxh"

float4x4 View        : View;
float4x3 ViewInverse : ViewInverse;
float4x4 Projection  : Projection;

float Time : Time;

// ----------------------------------------------------------------------------
// Rain Box Size
// ----------------------------------------------------------------------------

float3 TileOffset
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Weather.TileOffset";
> = float3(0.0, 0.0, 0.0);

float3 TileBoxSize
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Weather.BoxSize";
> = float3(1000.0,1000.0,300.0);

// ----------------------------------------------------------------------------
// Size
// ----------------------------------------------------------------------------

// x = MinWidth
// y = MaxWidth
// w = MinHeight
// z = MaxHeight
float4 ParticleSizeMinMax
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Weather.ParticleSizeMinMax";
> = float4(0.5,5.0,1.5,15.0);

// ----------------------------------------------------------------------------
// Speed and Alpha
// ----------------------------------------------------------------------------

// x = MinSpeed
// y = MaxSpeed
// w = MinAlpha
// z = MaxAlpha
float4 ParticleSpeedAlpha
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Weather.ParticleSpeedAlpha";
> = float4(50.0, 150.0, 0.1, 0.5);

// ----------------------------------------------------------------------------
// Directions for particle to move
// ----------------------------------------------------------------------------

float3 ForwardDirection
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Weather.ForwardDirection";
> = float3(0.0, 0.0, 0.0);

float4 RandomDirectionStretch
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Weather.RandomDirectionStretch";
> = float4(0.0, 0.0, 0.0, 0.0);

// ----------------------------------------------------------------------------
// Diffuse Texture
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( DiffuseTexture,
    string UIName = "Diffuse Texture";
	string SasBindAddress = "WW3D.Weather.DiffuseTexture";
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
    float3 DiffuseTexCoord_RandomSeed            : TEXCOORD0;
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
    VSOutput Out;

    // Get the values for this particle based on it's random seed data
    float width_interpolant  = Input.Width_Height_Speed_Alpha_Interpolants.x;
    float height_interpolant = Input.Width_Height_Speed_Alpha_Interpolants.y;
    float speed_interpolant  = Input.Width_Height_Speed_Alpha_Interpolants.z;
    float alpha_interpolant  = Input.Width_Height_Speed_Alpha_Interpolants.w;

    float width  = lerp( ParticleSizeMinMax.x, ParticleSizeMinMax.z, width_interpolant  );
    float height = lerp( ParticleSizeMinMax.y, ParticleSizeMinMax.w, height_interpolant );
    float speed  = lerp( ParticleSpeedAlpha.x, ParticleSpeedAlpha.y, speed_interpolant  );
    float alpha  = lerp( ParticleSpeedAlpha.z, ParticleSpeedAlpha.w, alpha_interpolant  );

    // Get the center of the particle, in world space
    float3 world_pos_center = Input.Position.xyz*TileBoxSize;

	// Calculating the offset based on force and random
	float randomSeed = Input.DiffuseTexCoord_RandomSeed.z;
	float3 randomOffsets = RandomDirectionStretch.xyz;
	float3 worldOffsetDir = ForwardDirection + GetRandomFloatValues(-randomOffsets, randomOffsets, randomSeed, 5);
	
	// Calculate the simulated world position
	world_pos_center = TileOffset + fmod( world_pos_center + worldOffsetDir * speed * Time, TileBoxSize ); 
    
	// Input.DiffuseTexCoord.y = 0 ==> head
	// Input.DiffuseTexCoord.y = 1 ==> tail
	float2 DiffuseTexCoord = Input.DiffuseTexCoord_RandomSeed.xy;

	// The strecthFactor determine how much to stretch in the motion direction (mostly for rain)
	float stretchInLength_world = RandomDirectionStretch.w;
	world_pos_center += DiffuseTexCoord.y * height * worldOffsetDir * stretchInLength_world;

    // Transform the vertex into view space
    float3 vertex_view_pos = mul( float4( world_pos_center, 1 ), View ).xyz;

    // Offset the vertex vertically in world space
    float2 normalized_offset = DiffuseTexCoord * - float2( 0.5, 0.5 );

    // Offset the vertex in view space. If we already stretch in world space, we don't want to stretch in view space
	float stretchInLength_view = saturate( 1.0-stretchInLength_world );
	vertex_view_pos.xy += normalized_offset * float2(width, stretchInLength_view*height);

    // Get the final position
	Out.Position = mul( float4( vertex_view_pos, 1 ), Projection );

    // Transfer UVs
    Out.DiffuseTexCoord = DiffuseTexCoord;
    
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

float4 PS(VSOutput Input, uniform bool applyGammaCorrection) COLORTARGET
{
    float4 color = Input.Color;

    // Apply Diffuse Texture
    float4 diffuseTexture = tex2D( SAMPLER(DiffuseTexture), Input.DiffuseTexCoord );
	if (applyGammaCorrection)
	{
		diffuseTexture.xyz = GammaToLinear(diffuseTexture.xyz);
	}
    color *= diffuseTexture;

    // Apply shroud
	float shroud = tex2D( SAMPLER(ShroudTexture), Input.ShroudTexCoord ).x;
    color.w *= shroud;

    return color;
}

float4 PS_GammaCorrection( VSOutput Input ) : COLOR
{
	return PS(Input, true);
}

float4 PS_NoGammaCorrection( VSOutput Input ) : COLOR
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
		SrcBlend         = SrcAlpha;
		DestBlend        = InvSrcAlpha;
	}
}

#if ENABLE_LOD

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
        SrcBlend         = SrcAlpha;
        DestBlend        = InvSrcAlpha;
    }
}

#endif // if ENABLE_LOD