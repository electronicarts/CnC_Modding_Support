//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// FX Shader for Ocean Water Simulation for Red Alert 3
//////////////////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------------------
// Includes and Defines
// ----------------------------------------------------------------------------

#if !defined(DONT_DO_DYNAMIC_DISPLACEMENT)
#define DO_DYNAMIC_DISPLACEMENT
#endif

#define USE_INTERACTIVE_LIGHTS 1
#define SUPPORT_GLOBAL_LIGHTS 1

#include "Common.fxh"
#include "Gamma.fxh"
#include "ShadowMap.fxh"

#if defined(EA_PLATFORM_WINDOWS) && defined(_3DSMAX_)
// ----------------------------------------------------------------------------
// SAMPLER : nhendricks : had to pull these in here for MAX to compile
// ----------------------------------------------------------------------------
#define SAMPLER_2D_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	sampler2D samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_2D_END	};

#define SAMPLER( samplerName )	samplerName##Sampler

#define SAMPLER_CUBE_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	samplerCUBE samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_CUBE_END };

#endif // defined(EA_PLATFORM_WINDOWS)

SAMPLER_2D_BEGIN( StaticDisplacementTexture,
	string SasBindAddress = "Water.StaticDisplacementTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

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

SAMPLER_2D_BEGIN( WaterRefractionTexture,
	string UIWidget = "None";
	string SasBindAddress = "Water.RefractionTexture";
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
	string SasBindAddress = "Water.LightSpaceEnvironmentMap";
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


SAMPLER_2D_BEGIN( ShroudSampler,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Editable parameters
// ----------------------------------------------------------------------------
// Material parameters
float4 MaterialColorDiffuse <
	string UIName = "Diffuse Material Color";
    string UIWidget = "Color";
> = float4(1.0, 1.0, 1.0, 0.0);

SAMPLER_2D_BEGIN( Foam,
	string UIName = "FoamMap";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

float FoamHeight
<
	string UIName = "Foam Mask Height"; 
    string UIWidget = "Slider";
	float UIMax = 25.0f;
	float UIMin = -25;
	float UIStep = 0.1f;
> = 0.0;

float FoamBlend
<
	string UIName = "Foam Mask Blend"; 
    string UIWidget = "Slider";
	float UIMax = 25.0f;
	float UIMin = .1;
	float UIStep = 0.1f;
> = 1.0;

float Foam1Scalar
<
	string UIName = "Foam 1 Scale"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

float Foam2Scalar
<
	string UIName = "Foam 2 Scale"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

float FoamSpeed
<
	string UIName = "Foam Speed"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = -50.0f;
	float UIStep = 0.01f;
> = 1.0;

float OctaveScalar
<
	string UIName = "Octave Scale"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

float OctaveDivergenceAngle
<
	string UIName = "Octave Divergence Angle"; 
    string UIWidget = "Slider";
	float UIMax = 180.0f;
	float UIMin = 0;
	float UIStep = 0.5f;
> = 0.0;

float OctaveSpeed
<
	string UIName = "Octave Speed"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

float OctaveDivergenceSpeed
<
	string UIName = "Octave Divergence Speed"; 
    string UIWidget = "Slider";
	float UIMax = 10.0f;
	float UIMin = 0;
	float UIStep = 0.001f;
> = 0.0;

float WaveAmplitude 
<
    string UIName = "Wave Amplitude";
    string UIWidget = "Slider";
    float UIMin = 0.0;
    float UIMax = 3.0;
    float UIStep = 0.1;
> =3.0;

float WaveFrequency 
<
    string UIName = "Wave frequency";
    string UIWidget = "Slider";
    float UIMin = 0.00;
    float UIMax = 6.0;
    float UIStep = 0.01;
> = 0.2;


SAMPLER_2D_BEGIN( DisplacementTexture,
	string SasBindAddress = "Water.DisplacementTexture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

float DisplacementTextureSize
<
	string SasBindAddress = "Water.DisplacementTextureSize";
> = 0;

// ----------------------------------------------------------------------------
// Wave functions
// ----------------------------------------------------------------------------
struct Wave 
{
  float frequency;   // 2*PI / wavelength
  float amplitude;   // amplitude
  float phase;       // speed * 2*PI / wavelength
  float2 direction;
};

#define NWAVES 3
Wave wave[NWAVES] = 
{
	{ 0.1,  1,  1.0, float2(0.2,  -0.7) },
	{ 0.25, .5, 0.5, float2(-1.0, -0.7) },
	{ 0.15,  .5,  1.5, float2(-1.0, 0.2) }
};

float CalculateWave(Wave w, float2 pos, float t)
{
  return w.amplitude*WaveAmplitude * sin( dot(w.direction, pos)*w.frequency*WaveFrequency + t*w.phase);
}

float CalculateWaveNormal(Wave w, float2 pos, float t)
{
  return w.amplitude*WaveAmplitude * cos( dot(w.direction, pos)*w.frequency*WaveFrequency + t*w.phase);
}

// ----------------------------------------------------------------------------
// Global Defines
// ----------------------------------------------------------------------------
float4x3 World : World;

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
float4x4 View           : View;
float4x3 ViewI          : ViewInverse;
float4x4 Projection     : Projection;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif // #if defined(_WW3D_)
    
float Time : Time;

// ----------------------------------------------------------------------------
// Shader Structure
// ----------------------------------------------------------------------------
struct VSOutputHigh
{
    float4 Position					: POSITION;
    float4 Color					: COLOR0;
    float4 FoamTexCoords			: TEXCOORD0;
    float4 nDispTexCoords			: TEXCOORD1;
    float4 ShadowMapTexCoord		: TEXCOORD2;
    float4 WorldPosition_Foam		: TEXCOORD3;
    float4 Displacement_Refraction	: TEXCOORD4;
    float2 ShroudTexCoord			: TEXCOORD5;
};

// ----------------------------------------------------------------------------
// Vertex and Pixel/Fragment Shader
// ----------------------------------------------------------------------------

VSOutputHigh VS_HIGH(float2 PositionXY : POSITION)
{
	VSOutputHigh Out;
	float3 worldPosition = ( mul( float4( PositionXY, 0, 1 ), World ) ).xyz;
	float WaterPlaneHeight = worldPosition.z;

// -------------------------------------------------------------------------------
// -- MAX Friendly Stuff  --------------------------------------------------------
// -------------------------------------------------------------------------------

// MAX and In-game handle time differently, this will allow a more WYSIWYG in Max
#if defined(_3DSMAX_)
	OctaveSpeed *= .2;
	OctaveDivergenceSpeed *= .2;
#endif

// -------------------------------------------------------------------------------
// -- Foam Rotation Matrix and Mapping Coords ------------------------------------
// -------------------------------------------------------------------------------

	// Build Foam Tex coords -----------------------------------------------------
	Foam1Scalar *= .005; // create a more managable number in MAX sliders
	Foam2Scalar *= .004; // create a more managable number in MAX sliders
	FoamSpeed *= Time * .011; // animate Foam Speed as a multiplier of Time
	float2 FoamTexCoords1 = worldPosition.xy * Foam1Scalar;
	float2 FoamTexCoords2 = worldPosition.xy * Foam2Scalar;

	// Animate Foam Texture Coords --------------------------
	FoamTexCoords1.x += FoamSpeed;
	FoamTexCoords2.x -= FoamSpeed;
	
// -------------------------------------------------------------------------------
// -- nDisp Displacment and Mapping -------------------------------------------
// -------------------------------------------------------------------------------

	// Build vDisp Tex coords and displace according to Amplitude ----------
	OctaveScalar = .0025; // create a more managable number in MAX sliders
	OctaveSpeed *= Time * .015; // animate Octave as a multiplier of Time
	OctaveDivergenceAngle = 55;
	float2 nDispTexCoords = float2(worldPosition.x * OctaveScalar, worldPosition.y * OctaveScalar);

	// Build Octave Texture Rotation Matrix And Convert Degrees to Radians --
	float cosAngle = 0;
	float sinAngle = 0;
	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
	sincos (OctaveDivergenceAngle * .017453, sinAngle, cosAngle);
	
	
	uvCoordRotate[0][0] = cosAngle;
	uvCoordRotate[0][1] = -sinAngle;
	uvCoordRotate[1][1] = uvCoordRotate[0][0];
	uvCoordRotate[1][0] = -uvCoordRotate[0][1];

	// Rotate and Animate vDisp Divergence Texture Coords --------------------
	float2 nDispTexCoordsDiverge = mul(nDispTexCoords, uvCoordRotate);
	nDispTexCoordsDiverge.x += OctaveSpeed + OctaveSpeed * OctaveDivergenceSpeed;
	float2 nDispTexCoordsDivergeInv = mul(nDispTexCoords, transpose(uvCoordRotate));	
	nDispTexCoordsDivergeInv.x += OctaveSpeed - OctaveSpeed * OctaveDivergenceSpeed;

#if defined(DO_DYNAMIC_DISPLACEMENT)

	float3 waveDisplacement = tex2Dlod(SAMPLER(DisplacementTexture), float4(PositionXY.x, 1.0 - PositionXY.y, 0, 0));

#if defined(EA_PLATFORM_XENON) // scale range on xenon
	waveDisplacement.xy = waveDisplacement.xy * 2 - 1;
#endif
	waveDisplacement = min(waveDisplacement,.13); // Hard-coded limit so the waves will not invert in the x/y axis
	waveDisplacement.x *= -1;

	// Yes its a hard coded number, this is the relationship between Vertex Displacement and
	// Normal Displacement in the pixel shader that looks correct
	worldPosition += waveDisplacement * 300;
#else
	float waveValue = 0.0;
	for(int i=0; i<NWAVES; i++) 
	{
		waveValue = CalculateWave(wave[i], worldPosition.xy, Time);
		worldPosition.z += max(waveValue, 0);
	}
#endif

	// Calculate foam mask as a function of delta z of original water plane height
	float BlendHeight = FoamBlend + FoamHeight;
	float Height = worldPosition.z - WaterPlaneHeight;
	float HeightBlendFactor = 0.0f;
	
	if (Height > BlendHeight) 
	{
		HeightBlendFactor = (Height - BlendHeight)/FoamBlend;
	}

	// Compute all remaining registers ---------------------------------------
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	Out.Color = float4(MaterialColorDiffuse.xyz, 1.0); //float4(waveDisplacement.xyz,0); // 
	Out.FoamTexCoords = float4(FoamTexCoords1, FoamTexCoords2);
	Out.nDispTexCoords = float4(nDispTexCoordsDiverge, nDispTexCoordsDivergeInv);
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition);
	Out.WorldPosition_Foam.xyz = worldPosition;
	Out.WorldPosition_Foam.w = HeightBlendFactor;
	Out.Displacement_Refraction.xy = float2(PositionXY.x, 1.0 - PositionXY.y);
	Out.Displacement_Refraction.zw = Out.Position.xy / Out.Position.w * 0.5 * float2(1, -1) + 0.5;
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);	
	return Out;
}

float4 PS_ULTRAHIGH(VSOutputHigh In, uniform bool hasShadow) COLORTARGET
{
	//return In.Color;
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	float3 worldPosition = In.WorldPosition_Foam.xyz;
	
	// Compute view direction in world space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);

	float4 color = In.Color;
	
	float3 FoamSamp = tex2D(SAMPLER(Foam), In.FoamTexCoords.xy);
	FoamSamp *= tex2D(SAMPLER(Foam), In.FoamTexCoords.zw);

	//Calculate surface normals
	float3 staticDisplacement = tex2D(SAMPLER(StaticDisplacementTexture), In.nDispTexCoords.xy) * 2 - 1;
	staticDisplacement += tex2D(SAMPLER(StaticDisplacementTexture), In.nDispTexCoords.zw) * 2 - 1;

#if defined(EA_PLATFORM_WINDOWS) // Don't displace the normals on console
	float2 PositionXY = In.Displacement_Refraction.xy;
	float heightCenter = tex2D(SAMPLER(DisplacementTexture), PositionXY).z;
	float heightX = tex2D(SAMPLER(DisplacementTexture), PositionXY + float2(1.0 / DisplacementTextureSize, 0)).z;
	float heightY = tex2D(SAMPLER(DisplacementTexture), PositionXY + float2(0, 1.0 / DisplacementTextureSize)).z;

	float3 nDisp = float3(heightX - heightCenter, heightY - heightCenter, 0.01) * 50;
	nDisp = normalize(nDisp + staticDisplacement * .2);
#else
	float3 nDisp = (staticDisplacement); //normalize
#endif

	float3 Nn = normalize(nDisp * 50 + float3(0, 0, 1));

	// Calculate Fresnel Effect
	float fresnelDiffuse = pow( 1-dot( worldEyeDir, Nn), 1.0);

	// Calculate reflection texture
	float4 hPosition = mul(float4(In.WorldPosition_Foam.xyz, 1), GetViewProjection());
 	float2 reflectionTexCoord = (0.5 * (hPosition.xy + hPosition.w * float2(1.0, 1.0)) ) / hPosition.w;
	reflectionTexCoord += Nn * .2;
	float3 reflectionColor = tex2D( SAMPLER(WaterReflectionTexture), reflectionTexCoord.xy );	

	// the cubemap is in light space so we can bake all lighting calculations to the Cube map
	float3 reflVect = -reflect(worldEyeDir,Nn);
	
	// Although not technically correct, since we use the Cubemap to fake specular, multiply against the shadow map and add to color
	float shadowMap = (hasShadow) ? shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord + float4(nDisp.xy * .01,0,0) ):1.0;
	float3 envcolor = GammaToLinear(texCUBE( SAMPLER(EnvironmentTexture), reflVect).xyz);

//			    || Refraction * Inverse fresnel       || Reflection
	FoamSamp = pow(FoamSamp,2) * clamp(In.WorldPosition_Foam.w * .2,.025,3) * DirectionalLight[0].Color;
	envcolor.xyz = envcolor.xyz * DirectionalLight[0].Color * fresnelDiffuse * 2 * shadowMap;

	// Apply shroud. Don't apply it to the refraction texture's samples, as those are already darkened
	float shroud = tex2D( SAMPLER(ShroudSampler), In.ShroudTexCoord).x;

	// Calculate refraction texture
	float2 refractionTexCoord = In.Displacement_Refraction.zw;
	refractionTexCoord += Nn * .15;
	float3 refractionColor = tex2D(SAMPLER(WaterRefractionTexture), refractionTexCoord);
	float3 baseColor = tex2D(SAMPLER(WaterRefractionTexture), In.Displacement_Refraction.zw);

	// ngavalas
	// Because we are just blindly sampling the refraction texture based on a displacement offset
	// and because objects are drawn before the water since they can be underwater, we get 
	// bleeding edges of objects in the water. In order to correct this without sampling the pixel
	// depth (requires a depth map which isn't available on medium LOD), we see how different the 
	// color of the displaced pixel is to that of the NON-displaced pixel. If there is a big difference,
	// chances are it's the pixel from an object and we don't want to use that color to computer 
	// the refraction color. In that case we just use the color of the NON-displaced pixel.
	const float maxColorDeltaToUseRefraction = .1;
	float colorDelta = distance(refractionColor, baseColor);

	float3 waterColor = baseColor;
	if (colorDelta < maxColorDeltaToUseRefraction)
	{
		waterColor = refractionColor;
	}

	color.xyz = waterColor + shroud * ((reflectionColor * .5) + FoamSamp + envcolor);

	return color;
}

// ----------------------------------------------------------------------------
// Technique Medium
// ----------------------------------------------------------------------------
struct VSOutputMedium
{
	float4 Position					: POSITION;
	float4 Color					: COLOR0;
	float4 nDispTexCoords			: TEXCOORD0;
	float4 WorldEyeDirection_Normal	: TEXCOORD1;
	float4 Displacement_Refraction	: TEXCOORD2;
	float2 ShroudTexCoord			: TEXCOORD3;
};

// ----------------------------------------------------------------------------
// Vertex and Pixel/Fragment Shader
// ----------------------------------------------------------------------------
VSOutputMedium VS_MEDIUM(float2 PositionXY : POSITION)
{
	VSOutputMedium Out;
	float3 worldPosition = ( mul( float4( PositionXY, 0, 1 ), World ) ).xyz;
	float WaterPlaneHeight = worldPosition.z;

	// -------------------------------------------------------------------------------
	// -- MAX Friendly Stuff  --------------------------------------------------------
	// -------------------------------------------------------------------------------

	// MAX and In-game handle time differently, this will allow a more WYSIWYG in Max
#if defined(_3DSMAX_)
	OctaveSpeed *= .2;
	OctaveDivergenceSpeed *= .2;
#endif

	// -------------------------------------------------------------------------------
	// -- nDisp Displacment and Mapping -------------------------------------------
	// -------------------------------------------------------------------------------

	// Build vDisp Tex coords and displace according to Amplitude ----------
	OctaveScalar = .0025; // create a more managable number in MAX sliders
	OctaveSpeed *= Time * .015; // animate Octave as a multiplier of Time
	OctaveDivergenceAngle = 55;
	float2 nDispTexCoords = float2(worldPosition.x * OctaveScalar, worldPosition.y * OctaveScalar);

	// Build Octave Texture Rotation Matrix And Convert Degrees to Radians --
	float cosAngle = 0;
	float sinAngle = 0;
	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
	sincos (OctaveDivergenceAngle * .017453, sinAngle, cosAngle);


	uvCoordRotate[0][0] = cosAngle;
	uvCoordRotate[0][1] = -sinAngle;
	uvCoordRotate[1][1] = uvCoordRotate[0][0];
	uvCoordRotate[1][0] = -uvCoordRotate[0][1];

	// Rotate and Animate vDisp Divergence Texture Coords --------------------
	float2 nDispTexCoordsDiverge = mul(nDispTexCoords, uvCoordRotate);
	nDispTexCoordsDiverge.x += OctaveSpeed + OctaveSpeed * OctaveDivergenceSpeed;
	float2 nDispTexCoordsDivergeInv = mul(nDispTexCoords, transpose(uvCoordRotate));	
	nDispTexCoordsDivergeInv.x += OctaveSpeed - OctaveSpeed * OctaveDivergenceSpeed;

	float waveValue = 0.0;
	float waveValueNormal = 0.0;
	for(int i=0; i<NWAVES; i++) 
	{
		waveValue = CalculateWave(wave[i], worldPosition.xy, Time);
		waveValueNormal += CalculateWaveNormal(wave[i], worldPosition.xy, Time);
		worldPosition.z += max(waveValue, 0);
	}

	// Compute all remaining registers ---------------------------------------
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	Out.Color = float4(MaterialColorDiffuse.xyz, 1.0);
	Out.nDispTexCoords = float4(nDispTexCoordsDiverge, nDispTexCoordsDivergeInv);
	Out.WorldEyeDirection_Normal.xyz = normalize(GetEyePosition() - worldPosition);
	Out.WorldEyeDirection_Normal.w = waveValueNormal;
	Out.Displacement_Refraction.xy = float2(PositionXY.x, 1.0 - PositionXY.y);
	Out.Displacement_Refraction.zw = Out.Position.xy / Out.Position.w * 0.5 * float2(1, -1) + 0.5;
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);	
	return Out;
}

float4 PS_MEDIUM(VSOutputMedium In) : COLOR
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	float4 color = In.Color;

	// Calculate surface normals
	float3 staticDisplacement = tex2D(SAMPLER(StaticDisplacementTexture), In.nDispTexCoords.xy) * 2 - 1;
	staticDisplacement += tex2D(SAMPLER(StaticDisplacementTexture), In.nDispTexCoords.zw) * 2 - 1;
	float3 nDisp = normalize(staticDisplacement * .2);
	float3 Nn = normalize(nDisp * 50 + (In.WorldEyeDirection_Normal.w * .5));

	// the cubemap is in light space so we can bake all lighting calculations to the Cube map
	float3 reflVect = -reflect(In.WorldEyeDirection_Normal.xyz,Nn);
	float3 envcolor = texCUBE( SAMPLER(EnvironmentTexture), reflVect).xyz;

	// Apply shroud. Don't apply it to the refraction texture's samples, as those are already darkened
	float shroud = tex2D( SAMPLER(ShroudSampler), In.ShroudTexCoord).x;

	// Calculate refraction texture
	float2 refractionTexCoord = In.Displacement_Refraction.zw;
	refractionTexCoord += Nn * .15;
	float3 refractionColor = tex2D(SAMPLER(WaterRefractionTexture), refractionTexCoord);
	float3 baseColor = tex2D(SAMPLER(WaterRefractionTexture), In.Displacement_Refraction.zw);

	// ngavalas
	// Because we are just blindly sampling the refraction texture based on a displacement offset
	// and because objects are drawn before the water since they can be underwater, we get 
	// bleeding edges of objects in the water. In order to correct this without sampling the pixel
	// depth (requires a depth map which isn't available on medium LOD), we see how different the 
	// color of the displaced pixel is to that of the NON-displaced pixel. If there is a big difference,
	// chances are it's the pixel from an object and we don't want to use that color to computer 
	// the refraction color. In that case we just use the color of the NON-displaced pixel.
	const float maxColorDeltaToUseRefraction = .15;
	float3 colorDelta = refractionColor - baseColor;

	float3 waterColor = baseColor;
	if (dot(colorDelta, colorDelta) < maxColorDeltaToUseRefraction)
	{
		waterColor = refractionColor;
	}

	color.xyz = shroud * ((waterColor * float3(.16, .57, .79)) + envcolor * DirectionalLight[0].Color);

	return color;
}

// ----------------------------------------------------------------------------
float4 PS_ULTRAHIGH_Xenon(VSOutputHigh In) : COLOR
{
    return PS_ULTRAHIGH( In, HasShadow);
}

#if defined(EA_PLATFORM_PS3)
// ----------------------------------------------------------------------------
float4 PS_ULTRAHIGH_PS3(VSOutputHigh In) : COLOR
{
	float4 color = In.Color;
	
	float3 FoamSamp = tex2D(SAMPLER(Foam), In.FoamTexCoords.xy);
	FoamSamp *= tex2D(SAMPLER(Foam), In.FoamTexCoords.zw);

	color.xyz = FoamSamp;
    color.w = 0.6;

	float shroud = tex2D( SAMPLER(ShroudSampler), In.ShroudTexCoord).x;

	color *= shroud;

	return color;
}
#endif // #if defined(EA_PLATFORM_PS3)

DEFINE_ARRAY_MULTIPLIER(PS_Default_Multiplier_NumShadows = 1);

#define PS_CreateWater_NumShadows \
    compile PS_3_0 PS_ULTRAHIGH(0), \
    compile PS_3_0 PS_ULTRAHIGH(1)

DEFINE_ARRAY_MULTIPLIER(PS_Default_Multiplier_NumShadows_Final = 2*PS_Default_Multiplier_NumShadows);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_WaterShadowMap_Array[PS_Default_Multiplier_NumShadows_Final] =
{
    PS_CreateWater_NumShadows
};
#endif

// ----------------------------------------------------------------------------
// Technique Low
// ----------------------------------------------------------------------------

struct VSOutputLow
{
    float4 Position					: POSITION;
    float4 Color					: COLOR0;
    float3 ReflectionDirection		: TEXCOORD0;
    float4 ShroudTexCoord_Foam		: TEXCOORD1;
};

// ----------------------------------------------------------------------------
// Vertex and Pixel/Fragment Shader
// ----------------------------------------------------------------------------

VSOutputLow VS_LOW(float2 PositionXY : POSITION)
{
	VSOutputLow Out;

	float3 worldPosition = ( mul( float4( PositionXY, 0, 1 ), World ) ).xyz;

	// Compute all remaining registers ---------------------------------------
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	Out.Color = float4(.16, .47, .69, 0.6);
	float3 worldEyeDirection = normalize(GetEyePosition() - worldPosition);
	Out.ReflectionDirection = -reflect(worldEyeDirection, float3(0,0,1));
	Out.ShroudTexCoord_Foam.xy = CalculateShroudTexCoord(Shroud, worldPosition);
	Out.ShroudTexCoord_Foam.zw = (worldPosition.xy * .01 - (Time * .05)).yx;
	return Out;
}

float4 PS_LOW(VSOutputLow In) : COLOR
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	// the cubemap is in light space so we can bake all lighting calculations to the Cube map
	float3 envcolor = texCUBE( SAMPLER(EnvironmentTexture), In.ReflectionDirection).xyz;

	float4 color = float4(In.Color.xyz + (envcolor * DirectionalLight[0].Color), In.Color.w);

	float3 FoamSamp = tex2D(SAMPLER(Foam), In.ShroudTexCoord_Foam.wz);

	color.xyz += FoamSamp * .2;

	// Apply shroud
	color *= tex2D( SAMPLER(ShroudSampler), In.ShroudTexCoord_Foam.xy).x;

	return color;
}

// ----------------------------------------------------------------------------
// Technique Definitions
// ----------------------------------------------------------------------------
technique Default
{
    pass P0
    {
#if defined(EA_PLATFORM_PS3)
        VertexShader = compile VS_3_0 VS_HIGH();
        PixelShader = ARRAY_EXPRESSION_DIRECT_PS(
            PS_WaterShadowMap_Array,
            HasShadow*PS_Default_Multiplier_NumShadows,

            // Non-array alternative
            compile PS_3_0 PS_ULTRAHIGH_PS3()
        );
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
#else // #if defined(EA_PLATFORM_PS3)
        VertexShader = compile VS_3_0 VS_HIGH();
        PixelShader = ARRAY_EXPRESSION_DIRECT_PS(
            PS_WaterShadowMap_Array,
            HasShadow*PS_Default_Multiplier_NumShadows,

            // Non-array alternative
            compile PS_3_0 PS_ULTRAHIGH_Xenon()
        );
		
		AlphaBlendEnable = false;
#endif // #if defined(EA_PLATFORM_PS3)
        
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = cw;
		AlphaTestEnable = false;
    }  
}

#if ENABLE_LOD

technique Default_M
{
    pass P0
    {
        VertexShader = compile VS_2_0 VS_MEDIUM();
        PixelShader  = compile PS_2_0 PS_MEDIUM();
        
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = cw;
		AlphaTestEnable = false;
		AlphaBlendEnable = false;
    }  
}

technique Default_L
{
    pass P0
    {
        VertexShader = compile VS_2_0 VS_LOW();
        PixelShader  = compile PS_2_0 PS_LOW();
        
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = cw;
		AlphaTestEnable = false;
		AlphaBlendEnable = true;
    }  
}

#endif
