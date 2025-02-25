//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for river rendering
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_FOG 1

#include "Common.fxh"
#include "Gamma.fxh"

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

SAMPLER_2D_BEGIN( NormalTexture,
	string UIName = "Normal Texture";
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
	string SasBindAddress = "Water.ReflectionTexture";
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

#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float3 EyePosition
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.Position";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float3 GetEyePosition()
{
    return EyePosition;
}
#else // #if defined(_WW3D_)
float4x3 ViewI                  : ViewInverse;

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif // #if defined(_WW3D_)

float Time : Time;



// ----------------------------------------------------------------------------
// SHADER: Default
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position           : POSITION;
	float4 Color              : COLOR0;
	float  Fog                : COLOR1;
	float4 RiverTexCoord      : TEXCOORD0;
	float4 NormalTexCoord     : TEXCOORD1;
	float2 ShroudTexCoord     : TEXCOORD2;
	float3 ReflectionTexCoord : TEXCOORD3;
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
	float4 color = Color * 0.75; // Darkened based on empirical testing to improve look

    // Clamp the alpha so that it's never completely opaque
    color.w *= Opacity.w;
	color.w = clamp( color.w, 0, 0.95 );

	Out.Color = color;

    // Fog
	float3 worldPosition = mul( float4(Position, 1), World );
	Out.Fog = CalculateFog( Fog, worldPosition, GetEyePosition() );

    // RiverTexCoord
    Out.RiverTexCoord.xy = NormalTexCoord * float2( 1.0, 0.5 ) + float2( 0, -0.004 * Time );
    Out.RiverTexCoord.zw = (NormalTexCoord * float2( 1.0, 1.0 ) + float2( 0, -0.016 * Time )).yx;

    // NormalTexCoord
    Out.NormalTexCoord.xy = NormalTexCoord * float2( 1.0, 0.9 ) + float2( 0,  0.03 * Time );
    Out.NormalTexCoord.zw = (NormalTexCoord * float2( 1.0, 2.0 ) + float2( 0, -0.08 * Time )).yx;

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
	float4 color = tex2D( SAMPLER(RiverTexture), In.RiverTexCoord.xy ) + tex2D( SAMPLER(RiverTexture), In.RiverTexCoord.wz );
	color.xyz = GammaToLinear(color.xyz);

	// Apply vertex color
	color *= In.Color;

	// Sample the normal map and convert to the range -1 to 1
	float2 normalMapSample1 = tex2D( SAMPLER(NormalTexture), In.NormalTexCoord.xy ) * 2 - 1;
	float2 normalMapSample2 = tex2D( SAMPLER(NormalTexture), In.NormalTexCoord.wz ) * 2 - 1;

    // Apply the reflection map
	float2 reflectionCoord = In.ReflectionTexCoord.xy / In.ReflectionTexCoord.z;
	reflectionCoord += ( normalMapSample1 + normalMapSample2 ) * .25;

	float3 reflectionColor = tex2D( SAMPLER(WaterReflectionTexture), reflectionCoord );
	color.xyz += reflectionColor * 0.75;

    // Apply fog
    color.xyz = lerp( Fog.Color, color.xyz, In.Fog );

    // Apply shroud
	float3 shroud = tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord ).xyz;
	color.xyz *= shroud;
	
	return color;
}

// ----------------------------------------------------------------------------

technique Default
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader  = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		AlphaTestEnable = false;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
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
	float4 RiverTexCoord      : TEXCOORD0;
	float2 NormalTexCoord     : TEXCOORD1;
	float2 ShroudTexCoord     : TEXCOORD2;
	float3 ReflectionTexCoord : TEXCOORD3;
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
	float4 color = Color * 0.75; // Darkened based on empirical testing to improve look

    // Clamp the alpha so that it's never completely opaque
    color.w *= Opacity.w;
	color.w = clamp( color.w, 0, 0.95 );

	Out.Color = color;

    // Fog
	float3 worldPosition = mul( float4(Position, 1), World );
	Out.Fog = CalculateFog( Fog, worldPosition, GetEyePosition() );

    // RiverTexCoord
    Out.RiverTexCoord.xy = NormalTexCoord * float2( 1.0, 0.5 ) + float2( 0, -0.004 * Time );
    Out.RiverTexCoord.zw = (NormalTexCoord * float2( 1.0, 1.0 ) + float2( 0, -0.016 * Time )).yx;

    // NormalTexCoord
    Out.NormalTexCoord.xy = NormalTexCoord * float2( 1.0, 0.9 ) + float2( 0,  0.03 * Time );

    // ShroudTexCoord
	Out.ShroudTexCoord = CalculateShroudTexCoord( Shroud, worldPosition );

   	// Compute view direction in world space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	// Compute env map reflection direction
	float3 worldNormal = float3(0, 0, 1); // Rivers always face up
	Out.ReflectionTexCoord = -reflect(worldEyeDir, worldNormal);

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_M( VSOutput_M In ) : COLOR
{
	// Sample the base texture
	float4 color = tex2D( SAMPLER(RiverTexture), In.RiverTexCoord.xy ) + tex2D( SAMPLER(RiverTexture), In.RiverTexCoord.wz );

	// Apply vertex color
	color *= In.Color;

	// Sample the normal map and convert to the range -1 to 1
	float3 normalMapSample1 = tex2D( SAMPLER(NormalTexture), In.NormalTexCoord.xy ) * 2 - 1;

    // Apply the reflection map
	float3 reflectionDirection = In.ReflectionTexCoord + float3(normalMapSample1.xy * 0.5, 0);

	float3 reflectionColor = texCUBE(SAMPLER(EnvironmentTexture), reflectionDirection);
	color.xyz += reflectionColor * 0.75;

    // Apply fog
    color.xyz = lerp( Fog.Color, color.xyz, In.Fog );

    // Apply shroud
	float3 shroud = tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord ).xyz;
	color.xyz *= shroud;
	
	return color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Medium Quality
// ----------------------------------------------------------------------------
technique _Default_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_M();
		PixelShader  = compile PS_2_0 PS_M();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		AlphaTestEnable = false;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}
}


// ----------------------------------------------------------------------------
// SHADER: Default Low Quality
// ----------------------------------------------------------------------------
struct VSOutput_L
{
	float4 Position           : POSITION;
	float4 Color              : COLOR0;
	float2 RiverTexCoord0     : TEXCOORD0;
	float2 RiverTexCoord1     : TEXCOORD1;
	float2 ShroudTexCoord     : TEXCOORD2;
};

// ----------------------------------------------------------------------------
VSOutput_L VS_L( float3 Position       : POSITION,
             float4 Color          : COLOR0,
             float2 RiverTexCoord  : TEXCOORD0,
             float2 NormalTexCoord : TEXCOORD1 )
{
	VSOutput_L Out;

    // Position
	Out.Position = mul( float4(Position, 1), WorldViewProjection );
	float3 worldPosition = mul( float4(Position, 1), World );

    // Color
	float4 color = Color * 0.75; // Darkened based on empirical testing to improve look

	// Clamp the alpha so that it's never completely opaque
    color.w *= Opacity.w;
	color.w = clamp( color.w, 0, 0.95 );
	Out.Color = color;

    // RiverTexCoord
    Out.RiverTexCoord0 = NormalTexCoord * float2( 1.0, 0.5 ) + float2( 0, -0.004 * Time );
    Out.RiverTexCoord1 = NormalTexCoord * float2( 1.0, 1.0 ) + float2( 0, -0.016 * Time );

    // ShroudTexCoord
	Out.ShroudTexCoord = CalculateShroudTexCoord( Shroud, worldPosition );

	return Out;
}

// ----------------------------------------------------------------------------
float4 PS_L( VSOutput_L In ) : COLOR
{
	// Sample the base texture
	float4 color = tex2D( SAMPLER(RiverTexture), In.RiverTexCoord0 ) + tex2D( SAMPLER(RiverTexture), In.RiverTexCoord1 );

	// Apply vertex color
	color *= In.Color;

    // Apply shroud
	float3 shroud = tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord ).xyz;
	color.xyz *= shroud;
	
	return color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: Low Quality
// ----------------------------------------------------------------------------
technique _Default_L
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_L();
		PixelShader  = compile PS_2_0 PS_L();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = None;
		AlphaTestEnable = false;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	}
}
#endif
