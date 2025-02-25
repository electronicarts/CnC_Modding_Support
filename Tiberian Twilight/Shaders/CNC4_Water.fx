//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// FX Shader for Ocean Water Simulation for Red Alert 3
//////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////
//
// $todo (MD) -- this shader is a hacked version of the Ocean.fx shader
//               Once lookdev is complete, this should be merged back 
//               with the Ocean.fx shader, or these two shaders should
//               share common functionality through functions.
//
//////////////////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------------------
// Includes and Defines
// ----------------------------------------------------------------------------

#if !defined(DONT_DO_DYNAMIC_DISPLACEMENT)
#define DO_DYNAMIC_DISPLACEMENT
#endif

#if defined(EA_PLATFORM_WINDOWS) || defined(EA_PLATFORM_PS3) // Don't displace the normals on Xenon
	#define DO_DISPLACE_NORMAL
#endif 

#if defined(USE_SCREENSPACE_SHADOW)
	// There is a problem with using screenspace shadow with the water atm, we need to render the water surface during the screenspace shadow pass to get it correct,
	//		but then, there won't be shadows at the bottom of the ocean.  We could technically fix it by doing a real shadow calculation during ocean, rather than 
	//		looking up screen space shadow)
	#define DO_CAST_SHADOW_ON_WATER_SURFACE
#endif // #if defined(USE_SCREENSPACE_SHADOW)

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

// Water Diffuse Texture
SAMPLER_2D_BEGIN( PuddleColor,
	string UIName = "Diffuse Texture";
	)
	MipFilter = MipFilterBest;
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	AddressU = WRAP;
	AddressV = WRAP;
SAMPLER_2D_END

float ReflectionScalar
< 
	string UIName = "Reflection Color Scalar";
	string UIWidget = "Slider";
	float UIMin = 0.0f;
	float UIMax = 100.0f;
	float UIStep = 0.1f;
> = 1.0;


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

#if defined(DO_DISPLACE_NORMAL)
float OneOverDisplacementTextureSize
<
	string SasBindAddress = "Water.OneOverDisplacementTextureSize";
> = 0;
#endif // #if defined(DO_DISPLACE_NORMAL)

// ----------------------------------------------------------------------------
// Wave functions
// ----------------------------------------------------------------------------
#if !defined(DO_DYNAMIC_DISPLACEMENT) || ENABLE_LOD
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
#endif // #if !defined(DONT_DO_DYNAMIC_DISPLACEMENT)

// ----------------------------------------------------------------------------
// Global Defines
// ----------------------------------------------------------------------------

#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
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
    float4 Position					             : POSITION;
	 float2 TexCoord0										: TEXCOORD0;
#if !defined(EA_PLATFORM_PS3)
    float4 FoamTexCoords                         : TEXCOORD6;
#endif // #if !defined(EA_PLATFORM_PS3)
    float4 nDispTexCoords                        : TEXCOORD1;
#if defined(DO_CAST_SHADOW_ON_WATER_SURFACE)
    float4 ShadowMapTexCoord                     : TEXCOORD2;
#endif // #if defined(DO_CAST_SHADOW_ON_WATER_SURFACE)
    float4 WorldPosition_Foam                    : TEXCOORD3;
    float4 ShroudTexCoord_Displacement           : TEXCOORD4;
	float4 ReflectionTexCoord_RefractionTexCoord : TEXCOORD5;
};

// ----------------------------------------------------------------------------
// Vertex and Pixel/Fragment Shader
// ----------------------------------------------------------------------------

VSOutputHigh VS_HIGH(	float2 PositionXY		: POSITION,
								float2 TexCoord0 : TEXCOORD0
#if defined(EA_PLATFORM_PS3)
						, float4 Displacement	: COLOR0
#endif // #if defined(EA_PLATFORM_PS3)
					)
{
	VSOutputHigh Out;
	float3 worldPosition = ( mul( float4( PositionXY, 1, 1 ), World ) ).xyz;
	float WaterPlaneHeight = worldPosition.z;

	Out.TexCoord0.xy = TexCoord0.xy;
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
	OctaveSpeed *= Time * 0.0025; //.015; // animate Octave as a multiplier of Time
	OctaveDivergenceAngle = 55;
	float2 nDispTexCoords = float2(worldPosition.x * OctaveScalar, worldPosition.y * OctaveScalar);

	// Precompute the UV coord rotation for OctaveDivergenceAngle = 55;
	// It should be uvCoordRotate = { cosAngle, -sinAngle,
	//								  sinAngle, cosAngle };
	float2x2 uvCoordRotate = {	0.573576436351f, -0.819152044288f, 
								0.819152044288f,  0.573576436351f };

	// Rotate and Animate vDisp Divergence Texture Coords --------------------
	float2 nDispTexCoordsDiverge = mul(nDispTexCoords, uvCoordRotate);
	nDispTexCoordsDiverge.x += OctaveSpeed + OctaveSpeed * OctaveDivergenceSpeed;
	float2 nDispTexCoordsDivergeInv = mul(nDispTexCoords, transpose(uvCoordRotate));	
	nDispTexCoordsDivergeInv.x += OctaveSpeed - OctaveSpeed * OctaveDivergenceSpeed;
	Out.nDispTexCoords = float4(nDispTexCoordsDiverge, nDispTexCoordsDivergeInv);

// -------------------------------------------------------------------------------
// -- Foam Rotation Matrix and Mapping Coords ------------------------------------
// -------------------------------------------------------------------------------
#if !defined(EA_PLATFORM_PS3)
	// On PS3, we are using the nDispTexCoords (which has a little bit of rotation give a pretty good result)
	float4 FoamFactors = float4((Foam1Scalar*0.005).xx, (Foam2Scalar*0.004).xx);
	// Animate Foam Texture Coords --------------------------
	float4 FoamSpeeds = FoamSpeed * Time * 0.011 * float4(1.0, 0.0, -1.0, 0.0);
	// Build Foam Tex coords -----------------------------------------------------
	Out.FoamTexCoords = (worldPosition.xyxy * FoamFactors + FoamSpeeds);
#endif // #if defined(EA_PLATFORM_PS3)

// $note (MD) -- removed all vertex displacement 


	// Calculate foam mask as a function of delta z of original water plane height
	float BlendHeight = FoamBlend + FoamHeight;
	float Height = worldPosition.z - WaterPlaneHeight;

	float HeightBlendFactor = 0.0;

	if (Height > BlendHeight) 
	{
		HeightBlendFactor = (Height - BlendHeight)/FoamBlend;
	}

#if defined(EA_PLATFORM_PS3)
	// Doing the multiplier in vertex shader rather than pixel shader
	Out.WorldPosition_Foam.w = HeightBlendFactor * 0.2;
	// Taking Square of the foam multiplier to make the foam pop out more
	Out.WorldPosition_Foam.w = Out.WorldPosition_Foam.w * Out.WorldPosition_Foam.w;
#else // #if defined(EA_PLATFORM_PS3)
	Out.WorldPosition_Foam.w = HeightBlendFactor;
#endif // #if defined(EA_PLATFORM_PS3)

	// Compute all remaining registers ---------------------------------------
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
#if defined(DO_CAST_SHADOW_ON_WATER_SURFACE)
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition, SHADOWMAP_SAMPLE_DEFAULT);
#endif // #if defined(DO_CAST_SHADOW_ON_WATER_SURFACE)
	Out.WorldPosition_Foam.xyz = worldPosition;

#if defined(DO_DISPLACE_NORMAL)
	Out.ShroudTexCoord_Displacement.zw = float2(PositionXY.x, 1.0 - PositionXY.y);
#else // #if defined(DO_DISPLACE_NORMAL)
	Out.ShroudTexCoord_Displacement.zw = 0.0;
#endif // #if defined(DO_DISPLACE_NORMAL)
	Out.ShroudTexCoord_Displacement.xy = CalculateShroudTexCoord(Shroud, worldPosition);	

	Out.ReflectionTexCoord_RefractionTexCoord = Out.Position.xyxy / Out.Position.w * float4(0.5, 0.5, 0.5, -0.5) + 0.5;

	return Out;
}

float4 PS_ULTRAHIGH(VSOutputHigh In, uniform bool hasShadow, float2 vPos : PIXELLOC) COLORTARGET
{
	//return In.Color;
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	float3 worldPosition = In.WorldPosition_Foam.xyz;
	
	// Compute view direction in world space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);

#if defined(EA_PLATFORM_PS3)
	// On PS3, we are using the nDispTexCoords (which has a little bit of rotation give a pretty good result)
	float4 FoamTexCoords = 4.0 * In.nDispTexCoords;
#else // #if defined(EA_PLATFORM_PS3)
	float4 FoamTexCoords = In.FoamTexCoords;
#endif // #if defined(EA_PLATFORM_PS3)

	
	//Water Diffuse Texture
	float4 PuddleColor = tex2D(SAMPLER(PuddleColor), In.TexCoord0); //puddlecoords.xy);
	PuddleColor.xyz = GammaToLinear(PuddleColor.xyz);

	//Calculate surface normals
	float3 staticDisplacement = tex2D(SAMPLER(StaticDisplacementTexture), In.nDispTexCoords.xy).xyz + 
								tex2D(SAMPLER(StaticDisplacementTexture), In.nDispTexCoords.zw).xyz;
	staticDisplacement = staticDisplacement * 2.0 - 2.0;

	//return float4(staticDisplacement.xyz, PuddleColor.w);

	float3 nDisp = (staticDisplacement); //normalize
	float3 Nn = normalize(nDisp * 50 + float3(0, 0, 1));

	//HACK-MD test using disp agains FoamTex lookup 
	FoamTexCoords.xy += nDisp.xy;
	//HACK-MD put foam tex animation in VS
	FoamTexCoords.x += Time * 0.005;
	FoamTexCoords.w -= Time * 0.0025;
	
	float3 FoamSamp = tex2D(SAMPLER(Foam), 0.5f * FoamTexCoords.xy).xyz *
					  tex2D(SAMPLER(Foam), 0.5f * FoamTexCoords.zw).xyz;

	// Calculate Fresnel Effect
	float fresnelDiffuse = pow( 1-dot( worldEyeDir, Nn), 1.0);

	// Calculate reflection texture
	float4 hPosition = mul(float4(In.WorldPosition_Foam.xyz, 1), GetViewProjection());
	float2 reflectionTexCoord = In.ReflectionTexCoord_RefractionTexCoord.xy;
	reflectionTexCoord += Nn.xy * .2;
	float3 reflectionColor = tex2D( SAMPLER(WaterReflectionTexture), reflectionTexCoord.xy ).xyz;

	//$todo (MD)
	// move max refl value to shader def in max
	float MaxReflectionIntensity = 0.15f;
	//move this value to shader def in max
	float ReflectionScalar = 0.025f;
	float ReflectionColorExp = 0.4f;
	//NOTE --> scale up lower end colors so they are visible w/ lower scalars
	//reflectionColor = saturate(reflectionColor * ReflectionScalar);
	//$note (MD) -- house color or other bright areas of units shows up much more in reflections
	//					 than the base texture color. Apply fractional exponen
	reflectionColor = pow(reflectionColor, ReflectionColorExp) * ReflectionScalar;


	// the cubemap is in light space so we can bake all lighting calculations to the Cube map
	float3 reflVect = -reflect(worldEyeDir,Nn);
	
	// Although not technically correct, since we use the Cubemap to fake specular, multiply against the shadow map and add to color
#if defined(DO_CAST_SHADOW_ON_WATER_SURFACE)
	float shadowMap = (hasShadow) ? shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord + float4(nDisp.xy * .01,0,0), vPos, SHADOWMAP_SAMPLE_DEFAULT) ):1.0;
#else // #if defined(DO_CAST_SHADOW_ON_WATER_SURFACE)
	float shadowMap = 1.0;
#endif // #if defined(DO_CAST_SHADOW_ON_WATER_SURFACE)
	float3 envcolor = GammaToLinear(texCUBE( SAMPLER(EnvironmentTexture), reflVect).xyz);

//			    || Refraction * Inverse fresnel       || Reflection
#if defined(EA_PLATFORM_PS3)
	// The foam looked better with no clamping on PS3
	FoamSamp = pow(FoamSamp,2) * In.WorldPosition_Foam.w * DirectionalLight_0_Color.xyz;
	// Environment map seems too bright on ps3, so skipping *2
	envcolor.xyz = envcolor.xyz * DirectionalLight_0_Color.xyz * fresnelDiffuse * shadowMap;
#else // #if defined(EA_PLATFORM_PS3)
	FoamSamp = pow(FoamSamp,2) * clamp(In.WorldPosition_Foam.w * .2,.025,3) * DirectionalLight_0_Color.xyz;
	envcolor.xyz = envcolor.xyz * DirectionalLight_0_Color.xyz * fresnelDiffuse * 2 * shadowMap;
#endif // #if defined(EA_PLATFORM_PS3)

	// Apply shroud. Don't apply it to the refraction texture's samples, as those are already darkened
	float shroud = tex2D( SAMPLER(ShroudSampler), In.ShroudTexCoord_Displacement.xy).x;

	// Calculate refraction texture
	float2 refractionTexCoord = In.ReflectionTexCoord_RefractionTexCoord.zw;
	refractionTexCoord += Nn.xy * .15;
	float3 refractionColor = tex2D(SAMPLER(WaterRefractionTexture), refractionTexCoord).xyz;
	float3 baseColor = tex2D(SAMPLER(WaterRefractionTexture), In.ReflectionTexCoord_RefractionTexCoord.zw).xyz;

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

	//For puddle
	float3 waterColor = lerp(baseColor, PuddleColor, 0.4); //baseColor; //(colorDelta < maxColorDeltaToUseRefraction)?refractionColor:baseColor;
	float4 color = float4(waterColor + shroud * (min(saturate(reflectionColor * 10.0), 0.1) + FoamSamp + envcolor), PuddleColor.w);
	//For reflection fix
	//float3 waterColor = baseColor; //(colorDelta < maxColorDeltaToUseRefraction)?refractionColor:baseColor;
	//float4 color = float4(waterColor + shroud * ((reflectionColor * 3.0) + 0 * 3 + 0), 1);

	return color;
}

// ----------------------------------------------------------------------------
float4 PS_ULTRAHIGH_Xenon(VSOutputHigh In, float2 vPos : PIXELLOC) : COLOR
{
    return PS_ULTRAHIGH( In, HasShadow, vPos );
}

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
// Technique Definitions
// ----------------------------------------------------------------------------
technique Default
{
    pass P0
    {
        VertexShader = compile VS_3_0 VS_HIGH();
        PixelShader = ARRAY_EXPRESSION_DIRECT_PS(
            PS_WaterShadowMap_Array,
            HasShadow*PS_Default_Multiplier_NumShadows,

            // Non-array alternative
            compile PS_3_0 PS_ULTRAHIGH_Xenon()
        );
		
		AlphaBlendEnable = true;
		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = cw;
		AlphaTestEnable = false;
    }  
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// Technique Medium
// ----------------------------------------------------------------------------
struct VSOutputMedium
{
	float4 Position					: POSITION;
	float4 Color					: COLOR0;
	float2 TexCoord0				: TEXCOORD0;
	float4 WorldEyeDirection_Normal	: TEXCOORD1;
	float4 Displacement_Refraction	: TEXCOORD2;
	float2 ShroudTexCoord			: TEXCOORD3;
	float4 nDispTexCoords			: TEXCOORD4;
};

// ----------------------------------------------------------------------------
// Vertex and Pixel/Fragment Shader
// ----------------------------------------------------------------------------
VSOutputMedium VS_MEDIUM(float2 PositionXY : POSITION, float2 TexCoord0 : TEXCOORD0)
{
	VSOutputMedium Out;
	float3 worldPosition = ( mul( float4( PositionXY, 0, 1 ), World ) ).xyz;
	float WaterPlaneHeight = worldPosition.z;

	Out.TexCoord0 = TexCoord0;

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
	OctaveSpeed *= Time * .0025; // animate Octave as a multiplier of Time
	OctaveDivergenceAngle = 55;
	float2 nDispTexCoords = float2(worldPosition.x * OctaveScalar, worldPosition.y * OctaveScalar);

	// Precompute the UV coord rotation for OctaveDivergenceAngle = 55;
	// It should be uvCoordRotate = { cosAngle, -sinAngle,
	//								  sinAngle, cosAngle };
	float2x2 uvCoordRotate = {	0.573576436351f, -0.819152044288f, 
								0.819152044288f,  0.573576436351f };

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
		worldPosition.z += 0.1f;
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
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	float4 color = In.Color;

	//Water Diffuse Texture
	float4 PuddleColor = tex2D(SAMPLER(PuddleColor), In.TexCoord0); //puddlecoords.xy);

	color = PuddleColor;

	// Calculate surface normals
	float3 staticDisplacement = tex2D(SAMPLER(StaticDisplacementTexture), In.nDispTexCoords.xy).xyz * 2 - 1;
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
	float3 refractionColor = tex2D(SAMPLER(WaterRefractionTexture), refractionTexCoord).xyz;
	float3 baseColor = tex2D(SAMPLER(WaterRefractionTexture), In.Displacement_Refraction.zw).xyz;

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

	float3 waterColor = lerp(baseColor.xyz, PuddleColor.xyz, 1.0);
	if (dot(colorDelta, colorDelta) < maxColorDeltaToUseRefraction)
	{
		waterColor = refractionColor;
	}

	
	color.xyz = 0.8 * PuddleColor + 0.5 *shroud * ((waterColor) + envcolor * DirectionalLight_0_Color.xyz);

	return color;
}

// ----------------------------------------------------------------------------
// Technique Low
// ----------------------------------------------------------------------------

struct VSOutputLow
{
    float4 Position					: POSITION;
    float4 Color					: COLOR0;
    float2 TexCoord0				: TEXCOORD0;
    float4 ShroudTexCoord_Foam		: TEXCOORD1;
	float3 ReflectionDirection		: TEXCOORD2;
};

// ----------------------------------------------------------------------------
// Vertex and Pixel/Fragment Shader
// ----------------------------------------------------------------------------

VSOutputLow VS_LOW(float2 PositionXY : POSITION, float2 TexCoord0 : TEXCOORD0)
{
	VSOutputLow Out;

	Out.TexCoord0 = TexCoord0;

	float3 worldPosition = ( mul( float4( PositionXY, 0, 1 ), World ) ).xyz;
	//HACK-MD -- avoid z-fighting w/ terrain
	worldPosition += 0.05f;

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
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	//Water Diffuse Texture
	float4 PuddleColor = tex2D(SAMPLER(PuddleColor), In.TexCoord0);

	// the cubemap is in light space so we can bake all lighting calculations to the Cube map
	float3 envcolor = texCUBE( SAMPLER(EnvironmentTexture), In.ReflectionDirection).xyz;

	float4 color = float4(PuddleColor.xyz + (envcolor * DirectionalLight_0_Color.xyz), PuddleColor.w);

	float3 FoamSamp = tex2D(SAMPLER(Foam), In.ShroudTexCoord_Foam.wz);

	color.xyz += FoamSamp * .2;

	// Apply shroud
	color *= tex2D( SAMPLER(ShroudSampler), In.ShroudTexCoord_Foam.xy).x;

	return color;
}

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
		AlphaBlendEnable = true;
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

		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
    }  
}

#endif // #if ENABLE_LOD
