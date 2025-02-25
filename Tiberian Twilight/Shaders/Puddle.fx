//////////////////////////////////////////////////////////////////////////////
// 2008 Electronic Arts Inc
//
// FX Shader for vehicles and structures. Infantry should use Infantry.fx
//////////////////////////////////////////////////////////////////////////////

//#define SUPPORT_RECOLORING 1 // Defined only in faction specific versions
#define SUPPORT_SPECMAP 1 // Define for objects shader with specularity/envmap/self illumination map
//#define SUPPORT_LIGHTMAP 1 // Define for objects that use a lightmap (supports HDR)
//#define SPECIFY_CUSTOM_ENVMAP 1 // Define to allow environment cube map to be specified in art tool instead of taken from code binding
//#define SUPPORT_DAMAGETEXTURE 1 // Define to allow blending between a damage texture and pristine texture based on vertex or bone based alpha values
//#define SUPPORT_FILLDAMAGETEXTURE 1 // Define to allow blending between a damage texture and pristine texture based on vertex or bone based alpha values
//#define SUPPORT_JAPANBUILDUP 1 // Defined for Japanese Building Construction Shader
//#define SUPPORT_FROZEN 1 // Defined to change appearance of object to ice
//#define SUPPORT_TESLA 1
//#define SUPPORT_ALTMAPPING 1 // Defined to change mapping coords if using Iron Curtain or Chrono Rift
//#define SUPPORT_IRONCURTAIN 1 // Defined to change appearance of object to invulnerable
//#define SUPPORT_CHRONORIFT 1 // Defined to change appearance of object to phased
//#define SUPPORT_FORMATIONPREVIEW 1 // Defined to change appearance of object for formation preview
//#define SUPPORT_TREAD_SCROLLING 1 // Defined for animating the texcoord 0 based on the bone opacity, used for tank tread animation
//#define SUPPORT_SSAO

#define USE_INTERACTIVE_LIGHTS 1
#define PER_PIXEL_POINT_LIGHT
#define SUPPORT_CLOUDS 1
#define SUPPORT_FOG 1
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1
#define FIRSTPASS 0
#define FROZENPASS 1
#define TESLAPASS 2

#include "Common.fxh"
#include "Gamma.fxh"
#include "SSAO.fxh"
#include "ShadowMap.fxh"
#include "MacroTexture.fxh"

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);

#if defined(SUPPORT_FORMATIONPREVIEW)	
	string RenderBin = "StaticSort1";
#endif

	int MaxLocalLights = 8;
	int MaxSupportedInstancingMode = INSTANCING_MODE_ONE_PER_DRAW_CALL;
> = 0;

#if defined(EA_PLATFORM_WINDOWS) && defined(_3DSMAX_)
// ----------------------------------------------------------------------------
// SAMPLER : nhendricks : had to pull these in here for MAX to compile
// ----------------------------------------------------------------------------
//#define SAMPLER_2D_BEGIN(samplerName, annotations) \
//	texture samplerName \
//	< \
//		annotations \
//	>; \
//	sampler2D samplerName##Sampler = sampler_state \
//	{ \
//		Texture = < samplerName >;
//		
//#define SAMPLER_2D_END	};
//
//#define SAMPLER( samplerName )	samplerName##Sampler
//
//#define SAMPLER_CUBE_BEGIN(samplerName, annotations) \
//	texture samplerName \
//	< \
//		annotations \
//	>; \
//	samplerCUBE samplerName##Sampler = sampler_state \
//	{ \
//		Texture = < samplerName >;
//		
//#define SAMPLER_CUBE_END };
//
//#if defined(_3DSMAX_)
//
//	#define DECLARE_MAPPING_TEXCOORD(texcoordIndex) \
//		int _3DSTexcoordMapping##texcoordIndex : Texcoord \
//		< \
//			int Texcoord = texcoordIndex; \
//			int MapChannel = 1 + texcoordIndex; \
//			string UIWidget = "None"; \
//		>;
//			
//	#define DECLARE_VERTEXCOLOR_INPUT(variableName, firstTexcoordIndex, secondTexCoordIndex) \
//		float3 _3DSVertexColor : TEXCOORD##firstTexcoordIndex, \
//		float _3DSVertexAlpha : TEXCOORD##secondTexCoordIndex
//
//	#define DECLARE_VERTEXCOLOR_INPUT_STRUCT(variableName, firstTexcoordIndex, secondTexCoordIndex) \
//		float3 _3DSVertexColor : TEXCOORD##firstTexcoordIndex; \
//		float _3DSVertexAlpha : TEXCOORD##secondTexCoordIndex
//#endif

#endif


DECLARE_MAPPING_TEXCOORD(0)
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
DECLARE_MAPPING_TEXCOORD(1)
DECLARE_MAPPING_VERTEXCOLOR(2, 3)
#else
DECLARE_MAPPING_VERTEXCOLOR(1, 2)
#endif


#if defined(SUPPORT_DAMAGETEXTURE)
#define EXPRESSION_EVALUATOR_NAME "Buildings"
#else
#define EXPRESSION_EVALUATOR_NAME "Objects"
#endif

// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
#define MaxSkinningBonesPerVertex 1

#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Light sources
// ----------------------------------------------------------------------------
#define NumDirectionalLightsPerPixel	2
#define NumDirectionalLightsPerPixel_M	1

// ----------------------------------------------------------------------------
// Cloud layer
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( CloudTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud.Texture";
	string ResourceName = "ShaderPreviewCloud.dds";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Environment map
// ----------------------------------------------------------------------------
SAMPLER_CUBE_BEGIN( EnvironmentTexture,
	string UIWidget = "None";
	string SasBindAddress = "Objects.LightSpaceEnvironmentMap";
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
// Japanese Building Construction Mask
// ----------------------------------------------------------------------------
#if defined(SUPPORT_JAPANBUILDUP)
SAMPLER_2D_BEGIN( JapanBuildMaskTexture,
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FXJapanBuildMask";
	)
    MipFilter = Linear;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = WRAP;
    AddressV = WRAP;
SAMPLER_2D_END
#endif

// ----------------------------------------------------------------------------
// Frozen shader ice normal map
// ----------------------------------------------------------------------------
#if defined(SUPPORT_FROZEN) || defined(SUPPORT_TESLA)
SAMPLER_2D_BEGIN( FractalNormalMap,
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FXDistortionFractal";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END
#endif

// ----------------------------------------------------------------------------
// Editable parameters
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( DiffuseTexture,
	string UIName = "Diffuse Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( NormalMap,
	string UIName = "Normal Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( SpecMap,
	string UIName = "Specular Map";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END


SAMPLER_2D_BEGIN( WaterBump,
	string UIName = "WaterBump Map";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( PerlinNoise,
	string UIName = "Perlin Noise Map";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( WaterRipple,
	string UIName = "Water Ripple Map";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( WaterFoam,
	string UIName = "Water Foam Map";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( WaterSurface,
	string UIName = "Water Surface Map";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END





// ----------------------------------------------------------------------------
// House coloring
// ----------------------------------------------------------------------------
#if defined(SUPPORT_RECOLORING)
SAMPLER_2D_BEGIN( RecolorTexture,
	string UIName = "House Color Tex";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END	
#endif 

// ----------------------------------------------------------------------------
// Light map
// ----------------------------------------------------------------------------

#if defined(SUPPORT_LIGHTMAP)
SAMPLER_2D_BEGIN( LightMap,
	string UIName = "Light Map";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END
#endif

#if defined(SUPPORT_DAMAGETEXTURE)

SAMPLER_2D_BEGIN( DamagedTexture,
	string UIName = "Damaged Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

#if defined(_3DSMAX_)

bool PreviewFullyDamaged
<
	string UIName = "Preview Fully Damaged";
	bool ExportValue = false;
> = false;

#endif // defined(_3DSMAX_)

#endif // defined(SUPPORT_DAMAGETEXTURE)


#if defined(MATERIAL_PARAMS_ALLIED)
// Fixed material parameters for ALLIED
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(0.1, 0.1, 0.1);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(0.8, 0.8, 0.8);
static const float SpecularExponent = 50.0;

#elif defined(MATERIAL_PARAMS_SOVIET)
// Fixed material parameters for SOVIET
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(0.1, 0.1, 0.1);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(0.8, 0.8, 0.8);
static const float SpecularExponent = 45.0;

#elif defined(MATERIAL_PARAMS_JAPAN)
// Fixed material parameters for JAPAN
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(0.1, 0.1, 0.1);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(0.8, 0.8, 0.8);
static const float SpecularExponent = 50.0;

#elif defined(SUPPORT_FROZEN)
// Fixed material parameters for frozen objects
static const float BumpScale = 3;
static const float3 AmbientColor = float3(1, 1, 1);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(0.8, 0.8, 0.8);
static const float SpecularExponent = 50.0;

#elif defined(MATERIAL_PARAMS_HUMAN)
// Fixed material parameters for HUMAN
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(0.3, 0.3, 0.3);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(1.0, 1.0, 1.0);
static const float SpecularExponent = 50.0;


#elif defined(MATERIAL_PARAMS_ALIEN)
// Fixed material parameters for Aliens
static const float BumpScale = 1.5;
static const float3 AmbientColor = float3(1.0, 1.0, 1.0);
static const float4 DiffuseColor = float4(1.0, 1.0, 1.0, 1.0);
static const float3 SpecularColor = float3(0.788, 0.761, 1.0);
static const float SpecularExponent = 15.0;

#else
// Material parameters defined by UI
float BumpScale
<
	string UIName = "Bump Height"; 
    string UIWidget = "Slider";
    float UIMin = 0.0;
    float UIMax = 10.0;
    float UIStep = 0.1;
> = 1.0;

float3 AmbientColor
<
	string UIName = "Ambient Color"; 
    string UIWidget = "Color";
> = float3(0.4, 0.4, 0.4);

float4 DiffuseColor
<
	string UIName = "Diffuse Color"; 
    string UIWidget = "Color";
> = float4(1.0, 1.0, 1.0, 1.0);

float3 SpecularColor
<
	string UIName = "Specular Color"; 
    string UIWidget = "Color";
> = float3(0.8, 0.8, 0.8);

float SpecularExponent
<
	string UIName = "Specular Exponent"; 
    string UIWidget = "Slider";
	float UIMax = 200.0f;
	float UIMin = 0;
	float UIStep = 1.0f;
> = 50.0;

#endif // Material parameters defined by UI

#if defined(SUPPORT_SPECMAP)

float EnvMult
<
	string UIName = "Reflection Multiplier"; 
    string UIWidget = "Slider";
	float UIMax = 1.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;
#endif

//#if defined(SUPPORT_DAMAGETEXTURE)
//// For damage texture rendering we always need alpha testing to be enabled. So don't offer it as configuration option.
//const bool AlphaTestEnable = true;
//#else
bool AlphaTestEnable
<
	string UIName = "Alpha Test Enable";
> = false;
//#endif


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
> =1.0;

float WaveFrequency 
<
    string UIName = "Wave frequency";
    string UIWidget = "Slider";
    float UIMin = 0.00;
    float UIMax = 6.0;
    float UIStep = 0.01;
> = 12.0;


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
	//{ 0.1,  1,  1.0, float2(0.2,  -0.7) },
	//{ 0.25, .5, 0.5, float2(-1.0, -0.7) },
	//{ 0.15,  .5,  1.5, float2(-1.0, 0.2) }
	{ 100.0f,  0.5f,  1.0, float2(0.2,  -0.7) },
	{ 250.5f, 0.25f, 0.5, float2(-1.0, -0.7) },
	{ 150.5f,  0.25f,  1.5, float2(-1.0, 0.2) }
};

float CalculateWave(Wave w, float2 pos, float t)
{
	WaveAmplitude = 0.5f;
	WaveFrequency = 12.0f;

  return w.amplitude*WaveAmplitude * sin( dot(w.direction, pos)*w.frequency*WaveFrequency + t*w.phase);
}

float CalculateWaveNormal(Wave w, float2 pos, float t)
{
	WaveAmplitude = 0.5f;
	WaveFrequency = 12.0f;
  return w.amplitude*WaveAmplitude * cos( dot(w.direction, pos)*w.frequency*WaveFrequency + t*w.phase);
}

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
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

#if !defined(USE_INDIRECT_CONSTANT)
float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;

float3 TintColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.TintColor";
> = float3(1, 1, 1);
#endif // #if !defined(USE_INDIRECT_CONSTANT)


// ----------------------------------------------------------------------------
// Transformations (world transformations are in skinning header)
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

// Time (ie. material is animated)
float Time : Time;

// ----------------------------------------------------------------------------
// SHADER: Default High LOD
// ----------------------------------------------------------------------------
struct VSOutput_H
{
	float4 Position : POSITION;
	float4 TexCoord0_TexCoord1 : TEXCOORD0;
	float3 TangentToViewSpace0 : TEXCOORD1_CENTROID;
	float3 TangentToViewSpace1 : TEXCOORD2_CENTROID;
	float3 TangentToViewSpace2 : TEXCOORD3_CENTROID;
	float3 WorldPosition : TEXCOORD4;
	float4 ShadowMapTexCoord : TEXCOORD5;
	float4 ShroudTexCoord_CloudTexCoord : TEXCOORD6;
	float4 Color : COLOR0;
};

VSOutput_H VS_H(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3),
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
#endif
		uniform int numJointsPerVertex,
		uniform int isMultiPass)
{
	USE_VERTEXCOLOR(VertexColor);
	USE_TEXCOORD(TexCoord0);
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
	USE_TEXCOORD(TexCoord1);
#endif

	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	VSOutput_H Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// Get the skins opacity value
	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

#if defined(_3DSMAX_) && defined(SUPPORT_DAMAGETEXTURE)
	if (PreviewFullyDamaged)
	{
		VertexColor.w = 0.0;
	}
#endif

#if defined(SUPPORT_TREAD_SCROLLING)
	// Tread scrolling uses the vertex color opacity for animating the U coordinate
	TexCoord0.x += VertexColor.w;
	// Don't use it for opacity then.
	VertexColor.w = 1.0f;
#endif

	if (isMultiPass == FROZENPASS)
	{
		// Extrude geo to create a shell for the ice
		worldPosition += worldNormal * 1.5;
	}
	
	// Build 3x3 tranform from object to tangent space
	float3x3 tangentToWorldSpace = float3x3(-worldBinormal, -worldTangent, worldNormal);

	Out.TangentToViewSpace0 = tangentToWorldSpace[0];
	Out.TangentToViewSpace1 = tangentToWorldSpace[1];
	Out.TangentToViewSpace2 = tangentToWorldSpace[2];

#if !defined(SUPPORT_ALTMAPPING)

	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);

	// Compute remaining directional lights per vertex, others will be done in pixel shader
	float3 diffuseLight = 1.0.xxx;
	if (NumDirectionalLights > 2)
	{
		diffuseLight = DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, DirectionalLight_2_Direction.xyz));
	}
	Out.Color.xyz += diffuseLight * DiffuseColor.rgb;

	Out.Color.xyz /= 2; // Prevent clamping in interpolator

	Out.Color *= VertexColor;
#endif // SUPPORT_ALTMAPPING

	////WAVE Crap begin
	//float waveValue = 0.0;
	//for(int i=0; i<NWAVES; i++) 
	//{
	//	waveValue = CalculateWave(wave[i], worldPosition.xy, Time * 6.0f);
	//	worldPosition.z += max(waveValue, 0);
	//}

	Out.WorldPosition = worldPosition;

	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition, SHADOWMAP_SAMPLE_DEFAULT);

#if defined(SUPPORT_TESLA)
	if (isMultiPass == TESLAPASS)
	{
		// Hi-jack shadow coords as we dont use them in this pass
		Out.ShadowMapTexCoord.xy = (TexCoord0 * .003) + (worldPosition.xy * .003);
		Out.ShadowMapTexCoord.wz = (TexCoord0 * .5);
		Out.ShadowMapTexCoord.wz += Time * .15;		
	}
#endif // #if defined(SUPPORT_TESLA)
	
	// pass texture coordinates for fetching the diffuse and normal maps
	Out.TexCoord0_TexCoord1.xy = TexCoord0.xy;

	if (isMultiPass == FROZENPASS)
	{
		// Use world coords when mapping
		Out.TexCoord0_TexCoord1.xy = worldPosition.xy * .015;
	}

	// transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
	float2 texCoord1 = TexCoord1;
#else
	float2 texCoord1 = TexCoord0;
#endif

	Out.TexCoord0_TexCoord1.zw = texCoord1.yx;

#if defined (SUPPORT_ALTMAPPING)
// -------------------------------------------------------------------------------
// -- Texture Coords and Mapping -------------------------------------------------
// -------------------------------------------------------------------------------

	// Build Tex coords, animate and scale ---------------------------------------
	float texScalar = .75; // Scale
	float texSpeed = Time * .3; // animate coords as a multiplier of Time
	float texDivergenceAngle = 55; // this is the angle difference between the 2 coords
	// Use the tex coords on the model but offset them slightly based on world
	// coords to keep multiple units from animating in sync
	float2 TexCoords = (TexCoord0 + (worldPosition.xy * .003)) * texScalar;

	// Build Texture Rotation Matrix And Convert Degrees to Radians --
	float cosAngle = 0;
	float sinAngle = 0;
	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
	sincos (texDivergenceAngle * .017453, sinAngle, cosAngle);
	
	// Build Rotation 	
	uvCoordRotate[0][0] = cosAngle;
	uvCoordRotate[0][1] = -sinAngle;
	uvCoordRotate[1][1] = uvCoordRotate[0][0];
	uvCoordRotate[1][0] = -uvCoordRotate[0][1];

	// Rotate and Animate Divergence Texture Coords --------------------
	float2 TexCoordsDiverge = mul(TexCoords, uvCoordRotate);
	TexCoordsDiverge.x += texSpeed;
	float2 TexCoordsDivergeInv = mul(TexCoords, transpose(uvCoordRotate));	
	TexCoordsDivergeInv.x += texSpeed;
	
	
	Out.TexCoord0_TexCoord1.xy = TexCoordsDiverge;
	Out.TexCoord0_TexCoord1.zw = TexCoordsDivergeInv;
	
	//Hi-jack shadow coords for this shader since we dont use them
	Out.ShadowMapTexCoord.xy = TexCoord0;
	
	Out.Color = 0;
	
#endif //SUPPORT_ALTMAPPING
	
	Out.ShroudTexCoord_CloudTexCoord.xy = CalculateShroudTexCoord(Shroud, worldPosition);
	Out.ShroudTexCoord_CloudTexCoord.zw = CalculateCloudTexCoord(Cloud_WorldPositionMultiplier_XYZZ, Cloud_CurrentOffsetUV, worldPosition, Time);
	
	return Out;
}


#if !defined(EA_PLATFORM_PS3)

// ----------------------------------------------------------------------------
// SHADER: VS_Xenon
// ----------------------------------------------------------------------------
VSOutput_H VS_Xenon(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3),
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
#endif
		uniform int isMultiPass)
{
    int joints = NumJointsPerVertex;

	return VS_H( InSkin, TexCoord0, 
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		TexCoord1,
#endif
		PASS_THROUGH_VERTEXCOLOR(VertexColor), min(joints, 1), isMultiPass);
}

#else // !defined(EA_PLATFORM_PS3)

// ----------------------------------------------------------------------------
// SHADER: VS_PS3_NoMultiPass
// ----------------------------------------------------------------------------
VSOutput_H VS_PS3_NoMultiPass(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3)
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2)
#endif
)
{
    int joints = NumJointsPerVertex;

	return VS_H( InSkin, TexCoord0, 
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		TexCoord1,
#endif
		PASS_THROUGH_VERTEXCOLOR(VertexColor), min(joints, 1), false);
}

// ----------------------------------------------------------------------------
// SHADER: VS_PS3_FrozenPass
// ----------------------------------------------------------------------------
VSOutput_H VS_PS3_FrozenPass(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3)
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2)
#endif
)
{
    int joints = NumJointsPerVertex;

	return VS_H( InSkin, TexCoord0, 
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		TexCoord1,
#endif
		PASS_THROUGH_VERTEXCOLOR(VertexColor), min(joints, 1), FROZENPASS);
}

// ----------------------------------------------------------------------------
// SHADER: VS_PS3_TeslaPass
// ----------------------------------------------------------------------------
VSOutput_H VS_PS3_TeslaPass(VSInputSkinningOneBoneTangentFrame InSkin, 
		float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		float2 TexCoord1 : TEXCOORD1,
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3)
#else
		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2)
#endif
)
{
    int joints = NumJointsPerVertex;

	return VS_H( InSkin, TexCoord0, 
#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
		TexCoord1,
#endif
		PASS_THROUGH_VERTEXCOLOR(VertexColor), min(joints, 1), TESLAPASS);
}

#endif // !defined(EA_PLATFORM_PS3)


// ----------------------------------------------------------------------------
// SHADER: Pixel Shader - High
// ----------------------------------------------------------------------------
float4 PS_H(VSOutput_H In, uniform bool hasShadow, uniform bool recolorEnabled, 
			float2 vPos : PIXELLOC, uniform int isMultiPass) COLORTARGET
{	
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);

	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;
	float2 texCoord1 = In.TexCoord0_TexCoord1.wz;
	float2 shroudTexCoord = In.ShroudTexCoord_CloudTexCoord.xy;
	float2 cloudTexCoord = In.ShroudTexCoord_CloudTexCoord.zw;
	float3 worldEyeDir = normalize(GetEyePosition() - In.WorldPosition);




	// Get diffuse color
	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
	


	// Get default water color
	float3 waterColor = float3(0.498f, 0.404f, 0.275f);

	baseTexture.xyz = lerp(baseTexture.xyz, waterColor, 0.8f);

	
#if defined(SUPPORT_RECOLORING)
	if (recolorEnabled)
	{		
		float4 recolorColor = tex2D( SAMPLER(SpecMap), texCoord0);
		//Commenting out Primary House Color for now as they need this feature for the Video Shoot. rravin
		//baseTexture.xyz = lerp(baseTexture.xyz,	baseTexture.xyz * RecolorColor * 2, recolorColor.z);
	}
#endif 

// Primary House color
#if defined(SUPPORT_RECOLORING)
	if(recolorEnabled)
	{
		float4 recolorColor = tex2D( SAMPLER(SpecMap), texCoord0);		
		
		float3 RecolorPColor;
#if defined(_3DSMAX_)
		RecolorPColor = RecolorColor.xyz;
#else		
		RecolorPColor = RecolorColor;
#endif
		//Commenting out Primary House Color for now as they need this feature for the Video Shoot. rravin
		//baseTexture.xyz = lerp(baseTexture.xyz, baseTexture.xyz * RecolorPColor.xyz * 2 , recolorColor.z); 
	}
#endif

	baseTexture.xyz = GammaToLinear(baseTexture.xyz);

	float3 diffuse = baseTexture.xyz * DiffuseColor.rgb;

	// Get bump map normal
	float3 bumpNormal;
	//bumpNormal = (float3)tex2D(SAMPLER(WaterRipple), texCoord0) * 2.0 - 1.0;	
	
//#if defined(SUPPORT_FROZEN)
//	if (isMultiPass == FROZENPASS)
//	{
//		bumpNormal = (float3)tex2D(SAMPLER(FractalNormalMap), texCoord0) * 2.0 - 1.0;
//	}
//#endif

//#if defined(SUPPORT_ALTMAPPING)
//	bumpNormal = (float3)tex2D(SAMPLER(NormalMap), In.ShadowMapTexCoord.xy) * 2.0 - 1.0;
//#endif

	// Scale normal to increase/decrease bump effect
	//bumpNormal.xy *= 1.0f; //BumpScale;
	
	// Bring bump normal into world space
	//float3x3 TangentToViewSpace = float3x3(In.TangentToViewSpace0, In.TangentToViewSpace1, In.TangentToViewSpace2);
	//bumpNormal = mul(bumpNormal, TangentToViewSpace);
	//bumpNormal = normalize(bumpNormal);

	////FOAM
	////TEMPORARILY OFF
	//float foamIntensityScale = 0.05f;
	//float foamTextureScale = 0.5f;
	//float3 waterfoam = (float3)tex2D(SAMPLER(WaterFoam), texCoord0 * foamTextureScale) * foamIntensityScale;
	//baseTexture.xyz += waterfoam;
	
	//float4 posNoise = float4(1.0f, 1.0f, 1.0f, 1.0f); //tex2D(SAMPLER(PerlinNoise), 0.01f * In.WorldPosition.xy);
	//posNoise *= 0.75f;
	//posNoise += 0.5f;
	// perlin noise vis test
	//posNoise.a = baseTexture.a;
	//return posNoise;

	float RippleATexScale = 25.0f; //was 30
	float RippleBTexScale = 24.0f;

	//float3 RippleA = (float3)tex2D(SAMPLER(WaterRipple), float2(texCoord0.y * RippleATexScale + (Time * 0.5f), texCoord0.x * RippleATexScale));
	float3 RippleA = (float3)tex2D(SAMPLER(WaterRipple), 0.005f * float2(In.WorldPosition.x * RippleATexScale + (Time * 5.0f), In.WorldPosition.y * RippleATexScale));
	float3 RippleB = (float3)tex2D(SAMPLER(WaterRipple), float2(texCoord0.y * RippleBTexScale + (Time * 0.15f), texCoord0.x * RippleBTexScale * 0.25f));
	bumpNormal = ((RippleA + RippleB) * 0.5f);	
	//bumpNormal = RippleB;

	//dial alpha down some
	//baseTexture.a = clamp(baseTexture.a - 0.25f, 0.0f, 1.0f);


	float4 color = baseTexture;
	color.xyz *= In.Color.xyz;

	float3 specularColor = SpecularColor;
	
	float shadowSampler = 1;
	if (hasShadow)
	{
		shadowSampler = shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, vPos, SHADOWMAP_SAMPLE_DEFAULT );
	}

// RR 1/8/09: Since we commented out the setting of LightSpaceEnvironmentMap in file RotateEnvironmentMap.scrapeh we don't do any of the environment mapping calculation.
// floating point texture is not workineg yet. The envcolor would be set to random color flashes in xenon if we don't do this check.
#if defined(SUPPORT_SPECMAP) && !defined (EA_PLATFORM_XENON)
	// Read spec map
	float4 specTexture = tex2D(SAMPLER(SpecMap), texCoord0);
	float specularStrength = specTexture.x;  // Specular lighting mask
	
	if (isMultiPass == FROZENPASS)
	{
		specularStrength = 1;
		color.xyz = float3(0, 0, 0);
		diffuse.xyz = float3(.13, .33, .5);
//		color.xyz *= float3(.13, .33, .5);
	}
	
	// the cubemap is in light space so we can bake all lighting calculations to the Cube map
	
	// Compute view direction in world space
	float3 reflVect = -reflect(worldEyeDir,bumpNormal);

	// Although not technically correct, since we use the Cubemap to fake specular, multiply against the shadow map and add to color
	float3 envcolor = texCUBE( SAMPLER(EnvironmentTexture), reflVect).xyz;
	
	color.xyz += envcolor.xyz * DirectionalLight_0_Color.rgb * specularStrength * 1.0f  * shadowSampler;
#endif // SUPPORT_SPECMAP


#if !defined(SUPPORT_ALTMAPPING)

	if (isMultiPass != TESLAPASS)
	{
		float3 cloud = float3(1, 1, 1);
#if defined(_WW3D_) && !defined(_W3DVIEW_)
		cloud = GammaToLinear(tex2D( SAMPLER(CloudTexture), cloudTexCoord).xyz);
#endif
		cloud *= shadowSampler;		
		
		float3 diffuseLight = 0.0.xxx;
		if (NumDirectionalLights > 0)
		{
			diffuseLight += DirectionalLight_0_Color.rgb * cloud * (max(0, dot(bumpNormal, DirectionalLight_0_Direction.xyz)));
		}
		
		if (NumDirectionalLights > 1)
		{
			diffuseLight += DirectionalLight_1_Color.rgb * (max(0, dot(bumpNormal, DirectionalLight_1_Direction.xyz)));
		}

		#if defined(SUPPORT_LIGHTMAP)
			float3 lightMapTexture = GammaToLinear(tex2D(SAMPLER(LightMap), texCoord1).xyz);
			diffuseLight += lightMapTexture.xyz * 10;
		#endif

		color.xyz += diffuseLight * diffuse;
	} // (isMultiPass == FIRSTPASS)

#endif // SUPPORT_ALTMAPPING

#if defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
	color *= damagedTexture * (1 - In.Color.w);
#elif defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
	color *= lerp(damagedTexture, 1.0.xxxx, In.Color.w);
#elif !defined(SUPPORT_JAPANBUILDUP) && !defined(SUPPORT_ALTMAPPING)
	color.w *= In.Color.w;
#endif

	if (isMultiPass == FIRSTPASS)
	{
		color.xyz *= TintColor;
	}

// Secondary House color if Objects Human
#if defined(OBJECTS_HUMAN) && defined(SUPPORT_RECOLORING)
	if(recolorEnabled)
	{
		float3 RecolorSColor;		

#if defined(_3DSMAX_)
		RecolorSColor.xyz = RecolorSecondaryColor.xyz;
#else 		
		RecolorSColor.xyz = RecolorSecondaryColor;		
#endif

//The Secondary house color texture is stored in the alpha channel of the specular map.
		float4 specularMap = tex2D( SAMPLER(SpecMap), texCoord0);
		float houseColor2 = specularMap.w;

    	color.xyz = lerp(color.xyz, RecolorSColor.xyz, houseColor2);
	}
#endif
//#if ((defined(OBJECTS_HUMAN) || defined(EMISSIVE)) && defined(SUPPORT_RECOLORING))
//	if(recolorEnabled)
//	{
//		float3 RecolorSColor;
//		float3 EmissiveSColor;
//
//#if defined(_3DSMAX_)
//		RecolorSColor.xyz = RecolorSecondaryColor.xyz;
//		EmissiveSColor.xyz = baseTexture.xyz;
//#else 		
//		RecolorSColor.xyz = RecolorSecondaryColor;		
//		EmissiveSColor.xyz = baseTexture;
//#endif
////The Secondary house color texture is stored in the alpha channel of the specular map.
//		float4 specularMap = tex2D( SAMPLER(SpecMap), texCoord0);
//		float houseColor2 = specularMap.w;
//	
//#if (defined(EMISSIVE))
//		color.xyz = lerp(color.xyz, EmissiveSColor.xyz, houseColor2);
//#else
//    	color.xyz = lerp(color.xyz, RecolorSColor.xyz, houseColor2);
//#endif // defined(EMISSIVE)
//
//		} //if(recolorEnabled)
//#endif //defined(OBJECTS_HUMAN) etc
	

//#if defined(_WW3D_) && !defined(_W3DVIEW_)
//	color.xyz *= tex2D(SAMPLER(ShroudTexture), shroudTexCoord).x;
//#endif

#if SUPPORT_SSAO
	color.xyz *= ComputeSSAO(vPos);
#endif

	return CorrectForFrameBufferGamma(color);
}


#if !defined(EA_PLATFORM_PS3)

// ----------------------------------------------------------------------------
// SHADER: PS_Xenon
// ----------------------------------------------------------------------------
float4 PS_Xenon( VSOutput_H In, float2 vPos : PIXELLOC, uniform int isMultiPass) : COLOR
{
	return PS_H( In, HasShadow, HasRecolorColors, vPos, isMultiPass);
}

#else // !defined(EA_PLATFORM_PS3)

// ----------------------------------------------------------------------------
// SHADER: PS_PS3_NoMultiPass
// ----------------------------------------------------------------------------
float4 PS_PS3_NoMultiPass( VSOutput_H In, float2 vPos : PIXELLOC) : COLOR
{
	return PS_H( In, HasShadow, HasRecolorColors, vPos, false);
}

// ----------------------------------------------------------------------------
// SHADER: PS_PS3_FrozenPass
// ----------------------------------------------------------------------------
float4 PS_PS3_FrozenPass( VSOutput_H In, float2 vPos : PIXELLOC) : COLOR
{
	return PS_H( In, HasShadow, HasRecolorColors, vPos, FROZENPASS);
}

// ----------------------------------------------------------------------------
// SHADER: PS_PS3_TeslaPass
// ----------------------------------------------------------------------------
float4 PS_PS3_TeslaPass( VSOutput_H In, float2 vPos : PIXELLOC) : COLOR
{
	return PS_H( In, HasShadow, HasRecolorColors, vPos, TESLAPASS);
}

#endif // !defined(EA_PLATFORM_PS3)

// ----------------------------------------------------------------------------
// Arrays: Default_H
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VS_H_Multiplier_Final = 2 );

#define VS_H_NumJointsPerVertex(isMultiPass) \
	compile VS_3_0 VS_H(0, isMultiPass), \
	compile VS_3_0 VS_H(1, isMultiPass)

#if SUPPORTS_SHADER_ARRAYS
	vertexshader VS_H_Array[VS_H_Multiplier_Final] =
	{
		VS_H_NumJointsPerVertex(FIRSTPASS)
	};

	#if defined(SUPPORT_FROZEN)
		vertexshader VS_H_Frozen_Array[VS_H_Multiplier_Final] =
		{
			VS_H_NumJointsPerVertex(FROZENPASS)
		};
	#endif // SUPPORT_FROZEN
	
	#if defined(SUPPORT_TESLA)
		vertexshader VS_H_Tesla_Array[VS_H_Multiplier_Final] =
		{
			VS_H_NumJointsPerVertex(TESLAPASS)
		};
	#endif // SUPPORT_TESLA	
	
#endif // SUPPORTS_SHADER_ARRAYS

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_NumShadows = 1 );

#define PS_H_NumShadows(recolorEnabled, isMultiPass) \
	compile PS_3_0 PS_H(0, recolorEnabled, isMultiPass), \
	compile PS_3_0 PS_H(1, recolorEnabled, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_RecolorEnabled = PS_H_Multiplier_NumShadows * 2 );
	
#define PS_H_RecolorEnabled(isMultiPass) \
	PS_H_NumShadows(false, isMultiPass), \
	PS_H_NumShadows(true, isMultiPass)

DEFINE_ARRAY_MULTIPLIER( PS_H_Multiplier_Final = PS_H_Multiplier_RecolorEnabled * 2 );

#if SUPPORTS_SHADER_ARRAYS
	pixelshader PS_H_Array[PS_H_Multiplier_Final] =
	{
		PS_H_RecolorEnabled(FIRSTPASS)
	};

	#if defined(SUPPORT_FROZEN)
		pixelshader PS_H_Frozen_Array[PS_H_Multiplier_Final] =
		{
			PS_H_RecolorEnabled(FROZENPASS)
		};
	#endif // SUPPORT_FROZEN
	
	#if defined(SUPPORT_TESLA)
		pixelshader PS_H_Tesla_Array[PS_H_Multiplier_Final] =
		{
			PS_H_RecolorEnabled(TESLAPASS)
		};
	#endif // SUPPORT_TESLA	
	
#endif // SUPPORTS_SHADER_ARRAYS

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass p0
	{

#if !defined(EA_PLATFORM_PS3)
		VertexShader = ARRAY_EXPRESSION_VS( VS_H_Array,
			min(NumJointsPerVertex, 1), 
			compile VS_VERSION VS_Xenon(false) );

		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Array,
			HasShadow * PS_H_Multiplier_NumShadows
			+ HasRecolorColors * PS_H_Multiplier_RecolorEnabled,
			compile PS_VERSION PS_Xenon(false) );
#else // !defined(EA_PLATFORM_PS3)
		VertexShader = compile VS_VERSION VS_PS3_NoMultiPass();
		PixelShader = compile PS_VERSION PS_PS3_NoMultiPass();
#endif // !defined(EA_PLATFORM_PS3)

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		AlphaTestEnable = false;
		//AlphaFunc = GreaterEqual;
//
//#if defined(SUPPORT_DAMAGETEXTURE)
//		AlphaBlendEnable = false;
//		
//#elif defined(SUPPORT_CHRONORIFT)
//		AlphaBlendEnable = true;
//		SrcBlend = One;
//		DestBlend = One;
//#else
//		#if !EXPRESSION_EVALUATOR_ENABLED		
//			AlphaBlendEnable = ( OpacityOverride < 0.99);
//		#endif
//		SrcBlend = SrcAlpha;
//		DestBlend = InvSrcAlpha;
//#endif
//
//		AlphaFunc = GreaterEqual;
//		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
//
//#if defined(SUPPORT_DAMAGETEXTURE)
//		AlphaTestEnable = true;
//
//#elif defined(SUPPORT_CHRONORIFT)
//		AlphaTestEnable = false;		
//
//#else
//	#if !EXPRESSION_EVALUATOR_ENABLED		
//		AlphaTestEnable = ( AlphaTestEnable );
//	#endif
//#endif




	}

//#if defined(SUPPORT_FROZEN)
//	pass p1
//	{
//	
//#if !defined(EA_PLATFORM_PS3)
//		VertexShader = ARRAY_EXPRESSION_VS( VS_H_Frozen_Array,
//			min(NumJointsPerVertex, 1), 
//			compile VS_VERSION VS_Xenon(FROZENPASS) );
//
//		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Frozen_Array,
//			HasShadow * PS_H_Multiplier_NumShadows
//			+ HasRecolorColors * PS_H_Multiplier_RecolorEnabled,
//			compile PS_VERSION PS_Xenon(FROZENPASS) );
//#else // !defined(EA_PLATFORM_PS3)
//		VertexShader = compile VS_VERSION VS_PS3_FrozenPass();
//		PixelShader = compile PS_VERSION PS_PS3_FrozenPass();
//#endif // !defined(EA_PLATFORM_PS3)
//
//		ZEnable = true;
//		ZFunc = ZFUNC_INFRONT;
//		ZWriteEnable = false;
//		CullMode = CW;
//
//		AlphaBlendEnable = true;
//		SrcBlend = One;
//		DestBlend = One;
//
//		AlphaTestEnable = false;
//		
//		StencilEnable = false;
//	}
//#endif // SUPPORT_FROZEN
//
//
//#if defined(SUPPORT_TESLA)
//	pass p1
//	{
//
//#if !defined(EA_PLATFORM_PS3)
//		VertexShader = ARRAY_EXPRESSION_VS( VS_H_Tesla_Array,
//			min(NumJointsPerVertex, 1), 
//			compile VS_VERSION VS_Xenon(TESLAPASS) );
//
//		PixelShader = ARRAY_EXPRESSION_PS( PS_H_Tesla_Array,
//			HasShadow * PS_H_Multiplier_NumShadows
//			+ HasRecolorColors * PS_H_Multiplier_RecolorEnabled,
//			compile PS_VERSION PS_Xenon(TESLAPASS) );
//#else // !defined(EA_PLATFORM_PS3)
//		VertexShader = compile VS_VERSION VS_PS3_TeslaPass();
//		PixelShader = compile PS_VERSION PS_PS3_TeslaPass();
//#endif // !defined(EA_PLATFORM_PS3)
//
//		ZEnable = true;
//		ZFunc = ZFUNC_INFRONT;
//		ZWriteEnable = false;
//		CullMode = CW;
//
//		AlphaBlendEnable = true;
//		SrcBlend = One;
//		DestBlend = One;
//
//		AlphaTestEnable = false;
//		
//		StencilEnable = false;
//	}
//#endif // SUPPORT_TESLA

}

//#if ENABLE_LOD
//
//// ----------------------------------------------------------------------------
//// SHADER: DEFAULT (Medium)
//// ----------------------------------------------------------------------------
//struct VSOutput_M {
//
//	float4 Position : POSITION;
//	float4 TexCoord0_TexCoord1 : TEXCOORD0;
//	float4 LightVector[NumDirectionalLightsPerPixel_M] : TEXCOORD1_CENTROID;
//	float3 HalfEyeLightVector : TEXCOORD2_CENTROID;
//	float4 ShroudTexCoord_CloudTexCoord : TEXCOORD3;
//	float4 ShadowMapTexCoord : TEXCOORD4;
//	float2 MacroTexCoord : TEXCOORD5;
//#if defined(SUPPORT_ALTMAPPING) || defined(SUPPORT_TESLA)
//	float3 WorldTangentEyeDir : TEXCOORD6;
//#endif
//#if defined(SUPPORT_TESLA)
//	float4 TeslaTexCoord : TEXCOORD7;
//#endif
//	float4 Color : COLOR0;
//};
//
//// ----------------------------------------------------------------------------
//// SHADER: VS
//// ----------------------------------------------------------------------------
//VSOutput_M VS_M(VSInputSkinningOneBoneTangentFrame InSkin, 
//		float2 TexCoord0 : TEXCOORD0,
//#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
//		float2 TexCoord1 : TEXCOORD1,
//		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3),
//#else
//		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
//#endif
//		uniform int numJointsPerVertex,
//		uniform int isMultiPass)
//{
//	USE_VERTEXCOLOR(VertexColor);
//	USE_TEXCOORD(TexCoord0);
//#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
//	USE_TEXCOORD(TexCoord1);
//#endif
//
//	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);
//
//	VSOutput_M Out;
//
//	float3 worldPosition = 0;
//	float3 worldNormal = 0;
//	float3 worldTangent = 0;
//	float3 worldBinormal = 0;
//
//	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
//		worldPosition, worldNormal, worldTangent, worldBinormal);
//
//	// Get the skins opacity value
//	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);
//
//#if defined(_3DSMAX_) && defined(SUPPORT_DAMAGETEXTURE)
//	if (PreviewFullyDamaged)
//	{
//		VertexColor.w = 0.0;
//	}
//#endif
//
//#if defined(SUPPORT_TREAD_SCROLLING)
//	// Tread scrolling uses the vertex color opacity for animating the U coordinate
//	TexCoord0.x += VertexColor.w;
//	// Don't use it for opacity then.
//	VertexColor.w = 1.0f;
//#endif
//
//	if (isMultiPass == FROZENPASS)
//	{
//		// Extrude geo to create a shell for the ice
//		worldPosition += worldNormal * 1.5;
//	}
//	
//	// transform position to projection space
//	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
//	
//	// Compute view direction in world space
//	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
//
//	// Build 3x3 tranform from object to tangent space
//	float3x3 worldToTangentSpace = transpose(float3x3(-worldBinormal, -worldTangent, worldNormal));
//	Out.LightVector[0] = float4(mul(DirectionalLight_0_Direction.xyz, worldToTangentSpace), 0);
//
//	// Compute half direction between view and light direction in tangent space
//	Out.HalfEyeLightVector.xyz = normalize(mul(DirectionalLight_0_Direction.xyz + worldEyeDir, worldToTangentSpace));
//
//#if !defined(SUPPORT_ALTMAPPING)
//	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);
//
//	// Compute remaining directional lights per vertex, others will be done in pixel shader
//	float3 diffuseLight = 0;
//	diffuseLight += DirectionalLight_1_Color.xyz * max(0, dot(worldNormal, DirectionalLight_1_Direction.xyz));
//	diffuseLight += DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, DirectionalLight_2_Direction.xyz));
//	
//	Out.Color.xyz += diffuseLight * DiffuseColor.rgb;
//	Out.Color *= VertexColor;
//#endif // SUPPORT_ALTMAPPING
//
//	// pass texture coordinates for fetching the diffuse and normal maps
//	Out.TexCoord0_TexCoord1.xy = TexCoord0.xy;
//
//	if (isMultiPass == FROZENPASS)
//	{
//		// Use world coords when mapping
//		Out.TexCoord0_TexCoord1.xy = worldPosition.xy * .015;
//	}
//
//#if defined(SUPPORT_DAMAGETEXTURE) || defined(SUPPORT_LIGHTMAP)
//	float2 texCoord1 = TexCoord1;
//#else
//	float2 texCoord1 = TexCoord0;
//#endif
//
//	Out.TexCoord0_TexCoord1.zw = texCoord1.yx;
//	
//	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition);
//
//#if defined (SUPPORT_ALTMAPPING)
//// -------------------------------------------------------------------------------
//// -- Texture Coords and Mapping -------------------------------------------------
//// -------------------------------------------------------------------------------
//
//	// Build Tex coords, animate and scale ---------------------------------------
//	float texScalar = .75; // Scale
//	float texSpeed = Time * .3; // animate coords as a multiplier of Time
//	float texDivergenceAngle = 55; // this is the angle difference between the 2 coords
//	// Use the tex coords on the model but offset them slightly based on world
//	// coords to keep multiple units from animating in sync
//	float2 TexCoords = (TexCoord0 + (worldPosition.xy * .003)) * texScalar;
//
//	// Build Texture Rotation Matrix And Convert Degrees to Radians --
//	float cosAngle = 0;
//	float sinAngle = 0;
//	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
//	sincos (texDivergenceAngle * .017453, sinAngle, cosAngle);
//	
//	// Build Rotation 	
//	uvCoordRotate[0][0] = cosAngle;
//	uvCoordRotate[0][1] = -sinAngle;
//	uvCoordRotate[1][1] = uvCoordRotate[0][0];
//	uvCoordRotate[1][0] = -uvCoordRotate[0][1];
//
//	// Rotate and Animate Divergence Texture Coords --------------------
//	float2 TexCoordsDiverge = mul(TexCoords, uvCoordRotate);
//	TexCoordsDiverge.x += texSpeed;
//	float2 TexCoordsDivergeInv = mul(TexCoords, transpose(uvCoordRotate));	
//	TexCoordsDivergeInv.x += texSpeed;
//	
//	
//	Out.TexCoord0_TexCoord1.xy = TexCoordsDiverge;
//	Out.TexCoord0_TexCoord1.zw = TexCoordsDivergeInv;
//	
//	//Hi-jack shadow coords for this shader since we dont use them
//	Out.ShadowMapTexCoord.xy = TexCoord0;
//	Out.WorldTangentEyeDir = mul(worldEyeDir, worldToTangentSpace);
//	
//	Out.Color = 0;
//	
//#endif //SUPPORT_ALTMAPPING
//	
//#if defined(SUPPORT_TESLA)
//		Out.WorldTangentEyeDir = mul(worldEyeDir, worldToTangentSpace);
//		Out.TeslaTexCoord.xy = (TexCoord0 * .003) + (worldPosition.xy * .003);
//		Out.TeslaTexCoord.wz = (TexCoord0 * .5);
//		Out.TeslaTexCoord.wz += Time * .15;		
//#endif
//	
//	Out.ShroudTexCoord_CloudTexCoord.xy = CalculateShroudTexCoord(Shroud, worldPosition);
//	Out.ShroudTexCoord_CloudTexCoord.zw = CalculateCloudTexCoord(Cloud_WorldPositionMultiplier_XYZZ, Cloud_CurrentOffsetUV, worldPosition, Time);
//	Out.MacroTexCoord = CalculateMacroTexCoord(worldPosition);
//	
//	return Out;
//}
//
//// ----------------------------------------------------------------------------
//// SHADER: PS
//// ----------------------------------------------------------------------------
//
//// This will save us .5ms on the GPU on a 6800 card. Worth it and there is no visual difference.
//#define float4 half4
//#define float3 half3
//#define float2 half2
//#define float  half
//
//float4 PS_M(VSOutput_M In, uniform bool hasShadow, uniform bool recolorEnabled, uniform int isMultiPass) COLORTARGET
//{
//	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;
//
//#if defined(SUPPORT_JAPANBUILDUP)
//	// Get Buildup Mask. The pixel can be clipped early to save processing instead of at the end.
//	float Mask = smoothstep(.3,.51,texCoord0.y + (In.Color.w * 1.2) - .65);	
//	clip(Mask - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));	
//#endif 
//
//	float2 texCoord1 = In.TexCoord0_TexCoord1.wz;
//	float2 cloudTexCoord = In.ShroudTexCoord_CloudTexCoord.zw;
//
//	// Get diffuse color
//	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
//	
//	float3 specularColor = SpecularColor;
//
//	// ngavalas
//	// Yes there is duplicate code here, but duplicating it makes it slightly more understandable
//	// as to what is going on. Basically, if we are support recoloring and specular mapping, 
//	// we can save a texture read since they use the same texture.
//	// If we are using one or the other then we just do the texture read and calculate
//	// the values normally.
//#if defined(SUPPORT_RECOLORING) && defined(SUPPORT_SPECMAP)
//	float4 specTexture = tex2D( SAMPLER(SpecMap), texCoord0);
//	float specularStrength = specTexture.x;  // Specular lighting mask
//	specularColor = SpecularColor * specularStrength;
//
//	if (recolorEnabled)
//	{
//		baseTexture.xyz = lerp(baseTexture.xyz,	baseTexture.xyz * RecolorColor * 2, specTexture.z);
//	}
//#elif defined(SUPPORT_SPECMAP)
//	float4 specTexture = tex2D( SAMPLER(SpecMap), texCoord0);
//	float specularStrength = specTexture.x;  // Specular lighting mask
//	specularColor = SpecularColor * specularStrength;
//#elif defined(SUPPORT_RECOLORING)
//	float4 specTexture = tex2D( SAMPLER(SpecMap), texCoord0);
//	if (recolorEnabled)
//	{
//		baseTexture.xyz = lerp(baseTexture.xyz,	baseTexture.xyz * RecolorColor * 2, specTexture.z);
//	}
//#endif
//
//	float3 diffuse = baseTexture.xyz * DiffuseColor.rgb;
//
//	// Get bump map normal
//	float3 bumpNormal = (float3)tex2D( SAMPLER(NormalMap), texCoord0) * 2.0 - 1.0;
//
//#if defined(SUPPORT_FROZEN)
//	if (isMultiPass == FROZENPASS)
//	{
//		bumpNormal = (float3)tex2D(SAMPLER(FractalNormalMap), texCoord0) * 2.0 - 1.0;
//	}
//#endif
//
//#if defined(SUPPORT_ALTMAPPING)
//	bumpNormal = (float3)tex2D(SAMPLER(NormalMap), In.ShadowMapTexCoord.xy) * 2.0 - 1.0;
//#endif
//
//	// Scale normal to increase/decrease bump effect
//	bumpNormal.xy *= BumpScale;
//	bumpNormal = normalize(bumpNormal);
//	
//	float4 color = baseTexture;
//	color.xyz *= In.Color.xyz;
//
//#if defined(SUPPORT_FROZEN)
//	if (isMultiPass == FROZENPASS)
//	{
//		specularStrength = 1;
//		color.xyz = float3(0, 0, 0);
//		diffuse.xyz = float3(.13, .33, .5);
//	}
//#endif
//
//#if !defined(SUPPORT_ALTMAPPING)
//	{
//		// Compute lighting
//        float3 lightVec = In.LightVector[0].xyz;
//        float3 halfVec  = In.HalfEyeLightVector.xyz;
//
//        float4 diffuseTerm = dot( bumpNormal, lightVec );
//        float4 specularTerm = dot( bumpNormal, halfVec );
//
//		float4 lighting = lit( diffuseTerm, specularTerm, SpecularExponent );
//
//		if (hasShadow)
//		{
//			lighting.yz *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord );
//		}
//		
//		float3 cloud = float3(1, 1, 1);			
//#if defined(_WW3D_) && !defined(_W3DVIEW_)
//		cloud = tex2D( SAMPLER(CloudTexture), cloudTexCoord);
//#endif
//		color.xyz += DirectionalLight_0_Color.xyz * cloud * (diffuse * lighting.y + specularColor * lighting.z);
//	}
//#endif
//
//#if defined(SUPPORT_LIGHTMAP)
//	float3 lightMapTexture = tex2D(SAMPLER(LightMap), texCoord1).xyz;
//	float3 diffuseLight = lightMapTexture.xyz * 10;
//	color.xyz += diffuseLight * diffuse;
//#endif
//
//// this is ugly but I couldn't think of a better way to do it. -Sean
//
//#if defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)
//	// Get Damaged Texture on 2nd UV Coords
//	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
////	color *= lerp(damagedTexture,  float4(1.0, 1.0, 1.0, 0.0) , ( In.Color.w));
//	color *= damagedTexture * (1 - In.Color.w);
//#elif defined(SUPPORT_DAMAGETEXTURE)
//	// Get Damaged Texture on 2nd UV Coords
//	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
//	color *= lerp(damagedTexture, 1.0.xxxx, In.Color.w);
//#elif !defined(SUPPORT_JAPANBUILDUP)
//	color.w *= In.Color.w;
//#endif	
//
//#if defined(SUPPORT_IRONCURTAIN)
//	float3 Texture0 = tex2D( SAMPLER(IronCurtainTexture), texCoord0);
//	float3 Texture1 = tex2D( SAMPLER(IronCurtainTexture), texCoord1);
//	color.xyz = Texture0 * Texture1 * 5;
//	
//	// Compute view direction in world space
//	float fresnelDiffuse = pow( 1-dot( In.WorldTangentEyeDir, bumpNormal), 4.0);
//	color.xyz += (float3(2.0,0.05,0.025) * fresnelDiffuse);
//	color.w = 1;
//#endif // SUPPORT_IRONCURTAIN
//
//#if defined(SUPPORT_CHRONORIFT)
//	float3 Texture0 = tex2D( SAMPLER(ChronoRiftTexture), texCoord0*2);
//	float3 Texture1 = tex2D( SAMPLER(ChronoRiftTexture), texCoord1*2);
//	color.xyz = Texture0 * Texture1 * 2;
//	
//	// Compute view direction in world space
//	float fresnelDiffuse = pow( 1-dot( In.WorldTangentEyeDir, bumpNormal), 2.0);
//	color.xyz += fresnelDiffuse * float3(0.3,0.6,3.0);
//	color.xyz = min(color.xyz,2);
//	color.w = 1;
//	
//#endif // SUPPORT_CHRONORIFT
//
//#if defined(SUPPORT_FORMATIONPREVIEW)
//
//	color.xyz = float3(0.0,0.055,0.045);
//
//	// Compute view direction in world space
//	float fresnelDiffuse = pow( 1-dot( In.WorldTangentEyeDir, bumpNormal), 2.5);
//	color.xyz += (float3(0.0,1.0,0.0) * fresnelDiffuse * 3);
//	color.xyz = min(color.xyz,2);
//	color.w = OpacityOverride;
//#endif // SUPPORT_FORMATIONPREVIEW
//
//#if defined(SUPPORT_JAPANBUILDUP)
//	float buildupTexture = tex2D( SAMPLER(JapanBuildMaskTexture), texCoord0 * 50).x + .5;
//	buildupTexture = pow(buildupTexture,3)*6;
//	float3 maskColor = buildupTexture * float3(.9,3,.9);
//	color.xyz = lerp(maskColor,color.xyz, clamp(1,0,Mask));
//#endif
//
//#if defined(SUPPORT_TESLA)
//		float3 Texture0 = tex2D( SAMPLER(FractalNormalMap), In.TeslaTexCoord.xy);
//		Texture0 = Texture0 * 2 - 1;
//		float3 Texture1 = tex2D( SAMPLER(TeslaTexture), In.TeslaTexCoord.zw * 1.5 + (Texture0.xy * .04));
//		Texture1 *= tex2D( SAMPLER(TeslaTexture), In.TeslaTexCoord.wz * 3 + (Texture0.xy * .04));
//		color.xyz += Texture1 * 20;
//		
//		// Compute view direction in world space
//		float fresnelDiffuse = pow( 1-dot(In.WorldTangentEyeDir, bumpNormal), 4.0);
//		color.xyz += fresnelDiffuse * float3(0.07,0.15,.75);
//		color.xyz = min(color.xyz,4);
//		color.w = 1;
//
//#endif // SUPPORT_TESLA
//
//	if (isMultiPass == FIRSTPASS)
//	{
//		color.xyz *= TintColor;
//	}
//
//#if defined(_WW3D_) && !defined(_W3DVIEW_)
//	color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord_CloudTexCoord.xy ).x;
//#endif
//
//	return color;
//}
//
//// We only want to do this for the really expensive part. The rest of the shader can be normal.
//#undef float4
//#undef float3
//#undef float2
//#undef float
//
//
//// ----------------------------------------------------------------------------
//// Arrays: Default_M
//// ----------------------------------------------------------------------------
//DEFINE_ARRAY_MULTIPLIER( VS_M_Multiplier_Final = 2 );
//
//#define VS_M_NumJointsPerVertex(isMultiPass) \
//	compile VS_3_0 VS_M(0, isMultiPass), \
//	compile VS_3_0 VS_M(1, isMultiPass)
//
//#if SUPPORTS_SHADER_ARRAYS
//vertexshader VS_M_Array[VS_M_Multiplier_Final] =
//{
//	VS_M_NumJointsPerVertex(FIRSTPASS)
//};
//
//	#if defined(SUPPORT_FROZEN)
//	vertexshader VS_M_Frozen_Array[VS_M_Multiplier_Final] =
//	{
//		VS_M_NumJointsPerVertex(FROZENPASS)
//	};
//	#endif // SUPPORT_FROZEN
//	
//#endif
//
//DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_HasShadow = 1 );
//
//#define PS_M_HasShadow(recolorEnabled, isMultiPass) \
//	compile PS_3_0 PS_M(false, recolorEnabled, isMultiPass), \
//	compile PS_3_0 PS_M(true, recolorEnabled, isMultiPass)
//
//DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_RecolorEnabled = PS_M_Multiplier_HasShadow * 2 );
//	
//#define PS_M_RecolorEnabled(isMultiPass) \
//	PS_M_HasShadow(false, isMultiPass), \
//	PS_M_HasShadow(true, isMultiPass)
//
//DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_Final = PS_M_Multiplier_RecolorEnabled * 2 );
//
//#if SUPPORTS_SHADER_ARRAYS
//pixelshader PS_M_Array[PS_M_Multiplier_Final] =
//{
//	PS_M_RecolorEnabled(FIRSTPASS)
//};
//
//	#if defined(SUPPORT_FROZEN)
//	pixelshader PS_M_Frozen_Array[PS_M_Multiplier_Final] =
//	{
//		PS_M_RecolorEnabled(FROZENPASS)
//	};
//	#endif // SUPPORT_FROZEN
//
//#endif
//
//// ----------------------------------------------------------------------------
//// Technique: Default_M
//// ----------------------------------------------------------------------------
//technique Default_M
//{
//	pass p0
//#if !defined(SUPPORT_DAMAGETEXTURE) && !defined(SUPPORT_CHRONORIFT)
//	<
//		USE_EXPRESSION_EVALUATOR(EXPRESSION_EVALUATOR_NAME)
//	>
//#endif
//	{
//		VertexShader = ARRAY_EXPRESSION_VS( VS_M_Array,
//			min(NumJointsPerVertex, 1), 
//			NO_ARRAY_ALTERNATIVE);
//
//		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Array,
//			HasShadow * PS_M_Multiplier_HasShadow
//			+ HasRecolorColors * PS_M_Multiplier_RecolorEnabled,
//			NO_ARRAY_ALTERNATIVE);
//
//		ZEnable = true;
//		ZFunc = ZFUNC_INFRONT;
//		ZWriteEnable = true;
//		CullMode = CW;
//
//#if defined(SUPPORT_DAMAGETEXTURE)
//		AlphaBlendEnable = false;
//		
//#elif defined(SUPPORT_CHRONORIFT)
//		AlphaBlendEnable = true;
//		SrcBlend = One;
//		DestBlend = One;
//#else
//		#if !EXPRESSION_EVALUATOR_ENABLED		
//			AlphaBlendEnable = ( OpacityOverride < 0.99);
//		#endif
//		SrcBlend = SrcAlpha;
//		DestBlend = InvSrcAlpha;
//#endif
//
//		AlphaFunc = GreaterEqual;
//		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
//
//#if defined(SUPPORT_DAMAGETEXTURE)
//		AlphaTestEnable = true;
//
//#elif defined(SUPPORT_CHRONORIFT)
//		AlphaTestEnable = false;		
//
//#else
//	#if !EXPRESSION_EVALUATOR_ENABLED		
//		AlphaTestEnable = ( AlphaTestEnable );
//	#endif
//#endif
//	}
//
//#if defined(SUPPORT_FROZEN)
//	pass p1
//	{
//		VertexShader = ARRAY_EXPRESSION_VS( VS_M_Frozen_Array,
//			min(NumJointsPerVertex, 1), 
//			NO_ARRAY_ALTERNATIVE);
//
//		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Frozen_Array,
//			HasShadow * PS_M_Multiplier_HasShadow
//			+ HasRecolorColors * PS_M_Multiplier_RecolorEnabled,
//			NO_ARRAY_ALTERNATIVE);
//
//		ZEnable = true;
//		ZFunc = ZFUNC_INFRONT;
//		ZWriteEnable = false;
//		CullMode = CW;
//
//		AlphaBlendEnable = true;
//		SrcBlend = One;
//		DestBlend = One;
//
//		AlphaTestEnable = false;
//		
//		StencilEnable = false;
//	}
//#endif // SUPPORT_FROZEN
//
//}
//
//
//
//// ----------------------------------------------------------------------------
//// SHADER: Low
//// ----------------------------------------------------------------------------
//struct VSOutput_L
//{
//	float4 Position : POSITION;
//	float4 Color : COLOR0;
//	float4 TexCoord0_TexCoord1 : TEXCOORD0;
//	float2 ShroudTexCoord : TEXCOORD1;
//#if defined(SUPPORT_ALTMAPPING)
//	float3 FallOffColor : TEXCOORD2;
//#endif
//};
//
//// ----------------------------------------------------------------------------
//// SHADER: VS
//// ----------------------------------------------------------------------------
//VSOutput_L VS_L(VSInputSkinningOneBoneTangentFrame InSkin, 
//		float2 TexCoord0 : TEXCOORD0,
//#if defined(SUPPORT_DAMAGETEXTURE)
//		float2 TexCoord1 : TEXCOORD1,
//		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 2, 3),
//#else
//		DECLARE_VERTEXCOLOR_INPUT(VertexColor, 1, 2),
//#endif
//		uniform int numJointsPerVertex)
//{
//	USE_VERTEXCOLOR(VertexColor);
//	USE_TEXCOORD(TexCoord0);
//#if defined(SUPPORT_DAMAGETEXTURE)
//	USE_TEXCOORD(TexCoord1);
//#endif
//
//	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);
//
//	VSOutput_L Out;
//
//	float3 worldPosition = 0;
//	float3 worldNormal = 0;
//	float3 worldTangent = 0;
//	float3 worldBinormal = 0;
//
//	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
//		worldPosition, worldNormal, worldTangent, worldBinormal);
//
//	// Get the skins opacity value
//	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);
//
//#if defined(_3DSMAX_) && defined(SUPPORT_DAMAGETEXTURE)
//	if (PreviewFullyDamaged)
//	{
//		VertexColor.w = 0.0;
//	}
//#endif
//
//#if defined(SUPPORT_TREAD_SCROLLING)
//	// Tread scrolling uses the vertex color opacity for animating the U coordinate
//	TexCoord0.x += VertexColor.w;
//	// Don't use it for opacity then.
//	VertexColor.w = 1.0f;
//#endif
//
//	// transform position to projection space
//	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
//
//#if !defined (SUPPORT_ALTMAPPING)
//	Out.Color = float4(AmbientLightColor * AmbientColor, OpacityOverride);
//	
//	// Compute remaining directional lights per vertex, others will be done in pixel shader
//	float3 diffuseLight = 0;
//	diffuseLight += DirectionalLight_0_Color.xyz * max(0, dot(worldNormal, DirectionalLight_0_Direction.xyz));
//	diffuseLight += DirectionalLight_1_Color.xyz * max(0, dot(worldNormal, DirectionalLight_1_Direction.xyz));
//	diffuseLight += DirectionalLight_2_Color.xyz * max(0, dot(worldNormal, DirectionalLight_2_Direction.xyz));
//	
//	Out.Color.xyz += diffuseLight * DiffuseColor.rgb;
//	
//	Out.Color *= VertexColor;
//#endif // SUPPORT_ALTMAPPING
//
//	// pass texture coordinates for fetching the diffuse and normal maps
//	Out.TexCoord0_TexCoord1.xy = TexCoord0.xy;
//
//#if defined(SUPPORT_DAMAGETEXTURE)
//	float2 texCoord1 = TexCoord1;
//#else
//	float2 texCoord1 = TexCoord0;
//#endif
//
//#if defined (SUPPORT_ALTMAPPING)
//// -------------------------------------------------------------------------------
//// -- Texture Coords and Mapping -------------------------------------------------
//// -------------------------------------------------------------------------------
//
//	// Build Tex coords, animate and scale ---------------------------------------
//	float texScalar = .75; // Scale
//	float texSpeed = Time * .3; // animate coords as a multiplier of Time
//	float texDivergenceAngle = 55; // this is the angle difference between the 2 coords
//	// Use the tex coords on the model but offset them slightly based on world
//	// coords to keep multiple units from animating in sync
//	float2 TexCoords = (TexCoord0 + (worldPosition.xy * .003)) * texScalar;
//
//	// Build Texture Rotation Matrix And Convert Degrees to Radians --
//	float cosAngle = 0;
//	float sinAngle = 0;
//	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
//	sincos (texDivergenceAngle * .017453, sinAngle, cosAngle);
//	
//	// Build Rotation 	
//	uvCoordRotate[0][0] = cosAngle;
//	uvCoordRotate[0][1] = -sinAngle;
//	uvCoordRotate[1][1] = uvCoordRotate[0][0];
//	uvCoordRotate[1][0] = -uvCoordRotate[0][1];
//
//	// Rotate and Animate Divergence Texture Coords --------------------
//	float2 TexCoordsDiverge = mul(TexCoords, uvCoordRotate);
//	TexCoordsDiverge.x += texSpeed;
//	float2 TexCoordsDivergeInv = mul(TexCoords, transpose(uvCoordRotate));	
//	TexCoordsDivergeInv.x += texSpeed;
//	
//	
//	Out.TexCoord0_TexCoord1.xy = TexCoordsDiverge;
//	Out.TexCoord0_TexCoord1.zw = TexCoordsDivergeInv;
//	
//	Out.Color = 0;
//	
//	// Compute view direction in world space
//	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
//	
//#endif //SUPPORT_ALTMAPPING
//
//#if defined(SUPPORT_IRONCURTAIN)
//	float worldTangentEyeDir = 1 - dot(worldEyeDir, worldNormal);
//	
//	// Compute view direction in world space
//	Out.FallOffColor = pow(worldTangentEyeDir, 4.0) * float3(2.0,0.05,0.025);
//#endif // SUPPORT_IRONCURTAIN
//
//#if defined(SUPPORT_CHRONORIFT)
//	float worldTangentEyeDir = 1 - dot(worldEyeDir, worldNormal);
//	
//	// Compute view direction in world space
//	Out.FallOffColor = pow(worldTangentEyeDir, 2.0) * float3(0.3,0.6,3.0);
//#endif // SUPPORT_CHRONORIFT
//
//#if defined(SUPPORT_FORMATIONPREVIEW)
//	
//	float worldTangentEyeDir = 1 - dot(worldEyeDir, worldNormal);
//	
//	// Compute view direction in world space
//	Out.FallOffColor = pow(worldTangentEyeDir, 2.5) * float3(0.0,1.05,0.0);
//#endif // SUPPORT_FORMATIONPREVIEW
//
//	Out.TexCoord0_TexCoord1.zw = texCoord1.yx;
//	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
//	
//	return Out;
//}
//
//// ----------------------------------------------------------------------------
//// SHADER: PS
//// ----------------------------------------------------------------------------
//float4 PS_L(VSOutput_L In, uniform bool recolorEnabled) COLORTARGET
//{
//	float2 texCoord0 = In.TexCoord0_TexCoord1.xy;
//	float2 texCoord1 = In.TexCoord0_TexCoord1.wz;
//
//	// Get diffuse color
//	float4 baseTexture = tex2D( SAMPLER(DiffuseTexture), texCoord0);
//	
//#if defined(SUPPORT_RECOLORING)
//	if (recolorEnabled)
//	{
//		float4 recolorColor = tex2D( SAMPLER(SpecMap), texCoord0);
//		baseTexture.xyz = lerp(baseTexture.xyz,	baseTexture.xyz * RecolorColor * 2, recolorColor.z);
//	}
//#endif //defined(SUPPORT_RECOLORING)
//
//	float4 color = baseTexture;
//	color.xyz *= In.Color.xyz;
//
//// this is ugly but I couldn't think of a better way to do it. -Sean
//
//#if defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)
//	// Get Damaged Texture on 2nd UV Coords
//	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
//	color *= damagedTexture * (1 - In.Color.w);
//#elif defined(SUPPORT_DAMAGETEXTURE)
//	// Get Damaged Texture on 2nd UV Coords
//	float4 damagedTexture = tex2D(SAMPLER(DamagedTexture), texCoord1);
//	color *= lerp(damagedTexture, 1.0.xxxx, In.Color.w);
//#elif !defined(SUPPORT_JAPANBUILDUP)
//	color.w *= In.Color.w;
//#endif	
//
//#if defined(SUPPORT_IRONCURTAIN)
//	float3 Texture0 = tex2D( SAMPLER(IronCurtainTexture), texCoord0);
//	float3 Texture1 = tex2D( SAMPLER(IronCurtainTexture), texCoord1);
//	color.xyz = Texture0 * Texture1 * 5;
//	
//	// Compute view direction in world space
//	color.xyz += In.FallOffColor;
//	color.w = 1;
//#endif // SUPPORT_IRONCURTAIN
//
//#if defined(SUPPORT_CHRONORIFT)
//	float3 Texture0 = tex2D( SAMPLER(ChronoRiftTexture), texCoord0);
//	float3 Texture1 = tex2D( SAMPLER(ChronoRiftTexture), texCoord1);
//	color.xyz = Texture0 * Texture1 * 2;
//	
//	color.xyz += In.FallOffColor;
//	color.w = 1;
//#endif // SUPPORT_CHRONORIFT
//
//#if defined(SUPPORT_FORMATIONPREVIEW)
//	color.xyz = float3(0.0,0.22,0.18);
//	color.xyz += In.FallOffColor;
//	color.xyz = min(color.xyz,2);
//	color.w = OpacityOverride;
//#endif // SUPPORT_CHRONORIFT
//
//	color.xyz *= TintColor;
//
//#if defined(_WW3D_) && !defined(_W3DVIEW_)
//	color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord ).x;
//#endif
//
//#if defined(SUPPORT_JAPANBUILDUP)
//	// Get Buildup Mask
//	float Mask = smoothstep(.3,.51,texCoord0.y + (In.Color.w * 1.2) - .65);	
//	float buildupTexture = tex2D( SAMPLER(JapanBuildMaskTexture), texCoord0 * 50).x + .5;
//	buildupTexture = pow(buildupTexture,3)*6;
//	float3 maskColor = buildupTexture * float3(.9,3,.9);
//	color.xyz = lerp(maskColor,color.xyz, clamp(1,0,Mask));
//	clip(Mask - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));	
//#endif
//
//	return color;
//}
//
//// ----------------------------------------------------------------------------
//// Arrays: Default_L
//// ----------------------------------------------------------------------------
//DEFINE_ARRAY_MULTIPLIER( VS_L_Multiplier_Final = 2 );
//
//#define VS_L_NumJointsPerVertex \
//	compile VS_2_0 VS_L(0), \
//	compile VS_2_0 VS_L(1)
//
//#if SUPPORTS_SHADER_ARRAYS
//vertexshader VS_L_Array[VS_L_Multiplier_Final] =
//{
//	VS_L_NumJointsPerVertex
//};
//#endif
//
//DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_RecolorEnabled = 1 );
//	
//#define PS_L_RecolorEnabled \
//	compile PS_2_0 PS_L(false), \
//	compile PS_2_0 PS_L(true)
//
//DEFINE_ARRAY_MULTIPLIER( PS_L_Multiplier_Final = PS_L_Multiplier_RecolorEnabled * 2 );
//
//#if SUPPORTS_SHADER_ARRAYS
//pixelshader PS_L_Array[PS_L_Multiplier_Final] =
//{
//	PS_L_RecolorEnabled
//};
//#endif
//
//// ----------------------------------------------------------------------------
//// Technique: Default_L
//// ----------------------------------------------------------------------------
//technique Default_L
//{
//	pass p0
//#if !defined(SUPPORT_DAMAGETEXTURE) && !defined(SUPPORT_CHRONORIFT)
//	<
//		USE_EXPRESSION_EVALUATOR(EXPRESSION_EVALUATOR_NAME)
//	>
//#endif
//	{
//		VertexShader = ARRAY_EXPRESSION_VS( VS_L_Array,
//			min(NumJointsPerVertex, 1), 
//			NO_ARRAY_ALTERNATIVE);
//
//		PixelShader = ARRAY_EXPRESSION_PS( PS_L_Array,
//			HasRecolorColors * PS_L_Multiplier_RecolorEnabled,
//			NO_ARRAY_ALTERNATIVE);
//
//		ZEnable = true;
//		ZFunc = ZFUNC_INFRONT;
//		ZWriteEnable = true;
//		CullMode = CW;
//
//#if defined(SUPPORT_DAMAGETEXTURE)
//		AlphaBlendEnable = false;
//		
//#elif defined(SUPPORT_CHRONORIFT)
//		AlphaBlendEnable = true;
//		SrcBlend = One;
//		DestBlend = One;
//#else
//		#if !EXPRESSION_EVALUATOR_ENABLED		
//			AlphaBlendEnable = ( OpacityOverride < 0.99);
//		#endif
//		SrcBlend = SrcAlpha;
//		DestBlend = InvSrcAlpha;
//#endif
//
//		AlphaFunc = GreaterEqual;
//		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
//
//#if defined(SUPPORT_DAMAGETEXTURE)
//		AlphaTestEnable = true;
//
//#elif defined(SUPPORT_CHRONORIFT)
//		AlphaTestEnable = false;		
//
//#else
//	#if !EXPRESSION_EVALUATOR_ENABLED		
//		AlphaTestEnable = ( AlphaTestEnable );
//	#endif
//#endif
//	}
//}
//
//
//#endif // ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMapVS
// ----------------------------------------------------------------------------
struct VSOutput_CreateShadowMap
{
	float4 Position : POSITION;
	float2 TexCoord0 : TEXCOORD0;
#if defined(SUPPORT_DAMAGETEXTURE)
	float2 TexCoord1 : TEXCOORD2;
#endif
	float Depth : TEXCOORD1;
	float Opacity : COLOR0;
};

// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS(VSInputSkinningOneBoneTangentFrame InSkin,
	float2 TexCoord0 : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE)
	float2 TexCoord1 : TEXCOORD1,
#endif
	float4 VertexColor: COLOR0,
	uniform int numJointsPerVertex)
{
	VSOutput_CreateShadowMap Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;
	float3 worldTangent = 0;
	float3 worldBinormal = 0;

	CalculatePositionAndTangentFrame(InSkin, numJointsPerVertex,
		worldPosition, worldNormal, worldTangent, worldBinormal);

	// Get the skins opacity value, used later as blend factor for the damage texture
	VertexColor.w *= GetOpacity(InSkin, numJointsPerVertex);

#if defined(_3DSMAX_)
	// Default vertex color is 0 in Max, that's bad.
	VertexColor = 1.0;
#endif

#if defined(SUPPORT_TREAD_SCROLLING)
	// Tread scrolling uses the vertex color opacity for animating the U coordinate
	TexCoord0.x += VertexColor.w;
	// Don't use it for opacity then.
	VertexColor.w = 1.0f;
#endif

	// Transform position to projection space
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());	
	Out.Depth = Out.Position.z / Out.Position.w;	
	Out.Opacity = OpacityOverride * VertexColor.w;
	Out.TexCoord0 = TexCoord0;	

#if defined(SUPPORT_DAMAGETEXTURE)
	Out.TexCoord1 = TexCoord1;
#endif

	return Out;
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In, uniform bool alphaTestEnable) COLORTARGET
{
#if defined(SUPPORT_JAPANBUILDUP)
	// Get Buildup Mask
	float Mask = smoothstep(.4,.51,In.TexCoord0.y + (In.Opacity * 1.2) - .65);	
	clip(Mask - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
#else
	float opacity = tex2D(SAMPLER(DiffuseTexture), In.TexCoord0).w;
	
#if defined(SUPPORT_FILLDAMAGETEXTURE) && defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float damagedTexture = tex2D(SAMPLER(DamagedTexture), In.TexCoord1).w;
	opacity *= damagedTexture * (1 - In.Opacity);
#elif defined(SUPPORT_DAMAGETEXTURE)
	// Get Damaged Texture on 2nd UV Coords
	float damagedTexture = tex2D(SAMPLER(DamagedTexture), In.TexCoord1).w;
	opacity *= lerp(damagedTexture, 1.0, In.Opacity);
#elif !defined(SUPPORT_JAPANBUILDUP)
	opacity *= In.Opacity;
#endif

	if (alphaTestEnable)
	{
		// Simulate alpha testing for floating point render target
		clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
	}
#endif //SUPPORT_JAPANBUILDUP

	return In.Depth;
}

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMapVS_Xenon
// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS_Xenon(VSInputSkinningOneBoneTangentFrame InSkin,
		float2 TexCoord : TEXCOORD0,
#if defined(SUPPORT_DAMAGETEXTURE)
		float2 TexCoord1 : TEXCOORD1,
#endif
		float4 VertexColor: COLOR0)
{
	return CreateShadowMapVS( InSkin,
		TexCoord,
#if defined(SUPPORT_DAMAGETEXTURE)
		TexCoord1,
#endif
		VertexColor, min(NumJointsPerVertex, 1) );
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS_Xenon(VSOutput_CreateShadowMap In) : COLOR
{
	return CreateShadowMapPS(In, AlphaTestEnable);
}

// ----------------------------------------------------------------------------
// Technique _CreateShadowMap
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( VSCreateShadowMap_Multiplier_Final = 2 );

#define VSCreateShadowMap_NumJointsPerVertex \
	compile VS_2_0 CreateShadowMapVS(0), \
	compile VS_2_0 CreateShadowMapVS(1)

#if SUPPORTS_SHADER_ARRAYS
vertexshader VSCreateShadowMap_Array[VSCreateShadowMap_Multiplier_Final] =
{
	VSCreateShadowMap_NumJointsPerVertex
};
#endif

#define PSCreateShadowMap_AlphaTestEnable \
	compile PS_2_0 CreateShadowMapPS(false), \
	compile PS_2_0 CreateShadowMapPS(true)

DEFINE_ARRAY_MULTIPLIER( PSCreateShadowMap_Multiplier_Final = 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSCreateShadowMap_Array[PSCreateShadowMap_Multiplier_Final] =
{
	PSCreateShadowMap_AlphaTestEnable
};
#endif

// ----------------------------------------------------------------------------
#if defined(SUPPORT_FORMATIONPREVIEW) || defined(SUPPORT_CHRONORIFT)
technique _CreateDepthMap // Don't cast a shadow, but still render to the depth map
#else
technique _CreateShadowMap
#endif
{
	pass p0
	{
		VertexShader = ARRAY_EXPRESSION_VS( VSCreateShadowMap_Array,
			min(NumJointsPerVertex, 1),
			compile VS_VERSION CreateShadowMapVS_Xenon() );
			
		PixelShader = ARRAY_EXPRESSION_PS( PSCreateShadowMap_Array,
			AlphaTestEnable,
			compile PS_VERSION CreateShadowMapPS_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

#if defined(USE_HARDWARE_SHADOW)
		ColorWriteEnable = 0;
#endif // #if defined(USE_HARDWARE_SHADOW)
	}
}
